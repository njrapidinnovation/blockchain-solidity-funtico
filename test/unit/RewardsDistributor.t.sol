// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
// import "forge-std/console.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";
import "src/RewardsDistributor.sol";

import "src/Minter.sol";

import "src/utils/SigUtils.sol";

contract RewardsDistributorTest is Test {
    VotingEscrow escrow;
    RewardsDistributor rewardsDistributor;
    Minter minter;
    Tico TICO;
    SigUtils internal sigUtils;

    address owner;
    address bob = makeAddr("0x01");
    address alice = makeAddr("0x02");
    uint internal constant MAXTIME = 4 * 365 * 86400;
    uint internal constant WEEK = 1 weeks;
    uint256 constant TOKEN_1 = 1e18;
    uint256 constant TOKEN_1M = 1e24; // 1e6 = 1M tokens with 18 decimals

    uint256 internal ownerPrivateKey;

    struct Checkpoint {
        uint timestamp;
        uint[] tokenIds;
    }

    function mintTico(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) public {
        for (uint256 i = 0; i < _amounts.length; i++) {
            TICO.mint(_accounts[i], _amounts[i]);
        }
    }

    function deployBase() public {
        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);

        TICO = new Tico();
        address[] memory accounts = new address[](1);
        accounts[0] = owner;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e21;
        mintTico(accounts, amounts);

        escrow = new VotingEscrow(address(TICO));

        vm.startPrank(owner);
        TICO.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);
        vm.stopPrank();

        rewardsDistributor = new RewardsDistributor(address(escrow));

        minter = new Minter(
            address(0),
            address(escrow),
            address(rewardsDistributor)
        );

        rewardsDistributor.setDepositor(address(minter));
        TICO.setMinter(address(minter));

        // sigUtils = new SigUtils(escrow.DOMAIN_TYPEHASH());
    }

    function initializeVotingEscrow() public {
        deployBase();

        address[] memory claimants = new address[](1);
        claimants[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOKEN_1M;
        minter.initialize(claimants, amounts, 2e25);
        assertEq(escrow.ownerOf(2), address(owner));
        assertEq(escrow.ownerOf(3), address(0));
        vm.roll(block.number + 1);
        assertEq(TICO.balanceOf(address(minter)), 19 * TOKEN_1M);
    }

    function testMinterWeeklyDistribute() public {
        initializeVotingEscrow();

        minter.update_period();
        assertEq(minter.weekly(), 15 * TOKEN_1M); // 15M
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        minter.update_period();
        assertEq(rewardsDistributor.claimable(1), 0);
        assertLt(minter.weekly(), 15 * TOKEN_1M); // <15M for week shift
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        
        minter.update_period();
        uint256 claimable = rewardsDistributor.claimable(1);
        assertGt(claimable, 128115516517529);
        rewardsDistributor.claim(1);
        assertEq(rewardsDistributor.claimable(1), 0);

        uint256 weekly = minter.weekly();
        console2.log(weekly);
        console2.log(minter.calculate_growth(weekly));
        console2.log(TICO.totalSupply());
        console2.log(escrow.totalSupply());

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(rewardsDistributor.claimable(1));
        rewardsDistributor.claim(1);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(rewardsDistributor.claimable(1));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        rewardsDistributor.claim_many(tokenIds);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(rewardsDistributor.claimable(1));
        rewardsDistributor.claim(1);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(rewardsDistributor.claimable(1));
        rewardsDistributor.claim_many(tokenIds);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(rewardsDistributor.claimable(1));
        rewardsDistributor.claim(1);
    }
}
