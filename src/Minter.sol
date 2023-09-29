// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/ITico.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IRewardDistributor.sol";
import "@openzeppelin-contracts/contracts/utils/math/Math.sol";

interface IMinter {
    function update_period() external returns (uint);
}
interface IVoter {
    function _ve() external view returns (address);
    function governor() external view returns (address);
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
}

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 86400 * 7; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant EMISSION = 990;
    uint internal constant TAIL_EMISSION = 2;
    uint internal constant PRECISION = 1000;
    ITico public immutable _tico;
    IVoter public immutable _voter;
    IVotingEscrow public immutable _ve;
    IRewardsDistributor public immutable _rewards_distributor;
    uint public weekly = 15_000_000 * 1e18; // represents a starting weekly emission of 15M VELO (VELO has 18 decimals)
    uint public active_period;
    uint internal constant LOCK = 86400 * 7 * 52 * 4;

    address internal initializer;
    address public team;
    address public pendingTeam;
    uint public teamRate;
    uint public constant MAX_TEAM_RATE = 50; // 50 bps = 0.05%

    event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);

    constructor(
        address __voter, // the voting & distribution system
        address __ve, // the ve(3,3) system that will be locked into
        address __rewards_distributor // the distribution system that ensures users aren't diluted
    ) {
        initializer = msg.sender;
        team = msg.sender;
        teamRate = 30; // 30 bps = 0.03%
        _tico = ITico(IVotingEscrow(__ve).token());
        _voter = IVoter(__voter);
        _ve = IVotingEscrow(__ve);
        _rewards_distributor = IRewardsDistributor(__rewards_distributor);
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    function initialize(
        address[] memory claimants,
        uint[] memory amounts,
        uint max // sum amounts / max = % ownership of top protocols, so if initial 20m is distributed, and target is 25% protocol ownership, then max - 4 x 20m = 80m
    ) external {
        require(initializer == msg.sender);
        _tico.mint(address(this), max);
        _tico.approve(address(_ve), type(uint).max);
        for (uint i = 0; i < claimants.length; i++) {
            _ve.create_lock_for(amounts[i], LOCK, claimants[i]);
        }
        initializer = address(0);
        active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions THIS Thursday
    }

    function setTeam(address _team) external {
        require(msg.sender == team, "not team");
        pendingTeam = _team;
    }

    function acceptTeam() external {
        require(msg.sender == pendingTeam, "not pending team");
        team = pendingTeam;
    }

    function setTeamRate(uint _teamRate) external {
        require(msg.sender == team, "not team");
        require(_teamRate <= MAX_TEAM_RATE, "rate too high");
        teamRate = _teamRate;
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return _tico.totalSupply() - _ve.totalSupply();
    }

    // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return (weekly * EMISSION) / PRECISION;
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return (circulating_supply() * TAIL_EMISSION) / PRECISION;
    }

    // calculate inflation and adjust ve balances accordingly
    function calculate_growth(uint _minted) public view returns (uint) {
        uint _veTotal = _ve.totalSupply();
        uint _veloTotal = _tico.totalSupply();
        return
            (((((_minted * _veTotal) / _veloTotal) * _veTotal) / _veloTotal) *
                _veTotal) /
            _veloTotal /
            2;

    // The initial supply of $TICO is 400M.

    // Weekly emissions started at 15M $TICO (3.75% of the initial supply) on June 4th 2022 and decay at 1% per week (epoch).

    // (veVELO.totalSupply ÷ VELO.totalsupply)³ × 0.5 × Emissions
    
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + WEEK && initializer == address(0)) { // only trigger if new week
            _period = (block.timestamp / WEEK) * WEEK;
            active_period = _period;
            weekly = weekly_emission();

            uint _growth = calculate_growth(weekly);
            uint _teamEmissions = (teamRate * (_growth + weekly)) /
                (PRECISION - teamRate);
            uint _required = _growth + weekly + _teamEmissions;
            uint _balanceOf = _tico.balanceOf(address(this));
            if (_balanceOf < _required) {
                _tico.mint(address(this), _required - _balanceOf);
            }

            require(_tico.transfer(team, _teamEmissions));
            require(_tico.transfer(address(_rewards_distributor), _growth));
            _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

            // _tico.approve(address(_voter), weekly);
            // _voter.notifyRewardAmount(weekly);

            emit Mint(msg.sender, weekly, circulating_supply(), circulating_emission());
        }
        return _period;
    }
}