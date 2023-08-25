// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";

import "src/utils/SigUtils.sol";

contract VotingEscrowTest is Test {
    VotingEscrow escrow;
    Tico TICO;

    address owner;
    address bob = makeAddr("0x01");
    address alice = makeAddr("0x02");
    uint internal constant MAXTIME = 4 * 365 * 86400;
    uint internal constant WEEK = 1 weeks;

    uint256 internal ownerPrivateKey;

    struct Checkpoint {
        uint timestamp;
        uint[] tokenIds;
    }

    function setUp() public {
        // mintTico(owners, amounts);
        // VeArtProxy artProxy = new VeArtProxy();

        ownerPrivateKey = 0xA11CE;
        owner = vm.addr(ownerPrivateKey);

        TICO = new Tico();
        address[] memory accounts = new address[](3);
        accounts[0] = owner;
        accounts[1] = alice;
        accounts[2] = bob;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e21;
        amounts[1] = 1e21;
        amounts[2] = 1e21;
        mintTico(accounts, amounts);
        escrow = new VotingEscrow(address(TICO));
    }

    function mintTico(address[] memory _accounts, uint256[] memory _amounts)
        public
    {
        for (uint256 i = 0; i < _amounts.length; i++) {
            TICO.mint(_accounts[i], _amounts[i]);
        }
    }

    function testFuzz_create_lock(uint _value, uint _lock_duration) external {
        uint ownerBalance = TICO.balanceOf(address(owner));
        vm.assume(_value > 0);
        vm.assume(_value <= ownerBalance);

        vm.assume(_lock_duration > WEEK);
        vm.assume(_lock_duration < MAXTIME);

        vm.startPrank(owner);
        TICO.approve(address(escrow), ownerBalance);
        escrow.create_lock(_value, _lock_duration);
        vm.stopPrank();
    }

    function testFuzz_create_lock_for(
        uint _value,
        uint _lock_duration,
        address _to
    ) external {
        uint ownerBalance = TICO.balanceOf(address(owner));
        vm.assume(_value > 0);
        vm.assume(_value <= ownerBalance);

        vm.assume(_lock_duration > WEEK);
        vm.assume(_lock_duration < MAXTIME);

        vm.startPrank(owner);
        TICO.approve(address(escrow), ownerBalance);
        escrow.create_lock_for(_value, _lock_duration, _to);
        vm.stopPrank();
    }

    function testFuzz_deposit_for(uint _tokenId, uint _value) external {
        uint ownerBalance = TICO.balanceOf(address(owner));

        vm.startPrank(owner);
        TICO.approve(address(escrow), ownerBalance);
        uint tokenId = escrow.create_lock(1e18, MAXTIME);
        vm.stopPrank();

        uint aliceBalance = TICO.balanceOf(address(alice));

        vm.assume(_value > 0);
        vm.assume(_value < aliceBalance);
        vm.assume(_tokenId == tokenId);

        vm.startPrank(alice);
        TICO.approve(address(escrow), aliceBalance);
        escrow.deposit_for(_tokenId, _value);
        vm.stopPrank();
    }

    function testFuzz_increase_amount(uint _tokenId, uint _value) external {
        uint ownerBalance = TICO.balanceOf(address(owner));

        vm.startPrank(owner);
        TICO.approve(address(escrow), ownerBalance);
        uint tokenId = escrow.create_lock(1e15, MAXTIME);
        uint ownerCurBalance = TICO.balanceOf(address(owner));

        vm.assume(_value > 0);
        vm.assume(_value < ownerCurBalance);
        vm.assume(_tokenId == tokenId);

        escrow.increase_amount(_tokenId, _value);
        vm.stopPrank();
    }

    function testFuzz_increase_unlock_time(
        uint8 _tokenId,
        uint32 _lock_duration
    ) external {
        uint ownerBalance = TICO.balanceOf(address(owner));

        vm.startPrank(owner);
        TICO.approve(address(escrow), ownerBalance);

        uint tokenId = escrow.create_lock(1e18, WEEK);
        //bcoz, the lock duration will be rounded off to WEEK
        vm.assume(_lock_duration > WEEK * 2);
        vm.assume(_lock_duration <= MAXTIME);
        vm.assume(_tokenId == tokenId);

        escrow.increase_unlock_time(_tokenId, _lock_duration);
        vm.stopPrank();
    }
}
