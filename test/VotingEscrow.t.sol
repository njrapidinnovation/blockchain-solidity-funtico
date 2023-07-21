// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";

contract VotingEscrowTest is Test {
    VotingEscrow escrow;
    Tico TICO;
    address owner = makeAddr("owner");
    uint internal constant MAXTIME = 4 * 365 * 86400;
    uint internal constant WEEK = 1 weeks;

    struct Checkpoint {
        uint timestamp;
        uint[] tokenIds;
    }

    function setUp() public {
        // mintTico(owners, amounts);
        // VeArtProxy artProxy = new VeArtProxy();
        TICO = new Tico();
        address[] memory accounts = new address[](1);
        accounts[0] = owner;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e21;
        mintTico(accounts, amounts);
        escrow = new VotingEscrow(address(TICO));
    }

    /* CREATE LOCK TESTS */

    function testZeroAmount() public {
        vm.prank(owner);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.expectRevert();
        escrow.create_lock(0, lockDuration);
    }

    function testUnlockTimeLessThanCurrentTime() public {
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 0; // 1 week
        vm.expectRevert("Can only lock until time in the future");
        escrow.create_lock(1e21, lockDuration);
    }

    function testUnlockTimeMoreThanMaxLockTime() public {
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = MAXTIME + WEEK;
        vm.expectRevert("Voting lock can be 4 years max");
        escrow.create_lock(1e21, lockDuration);
        vm.stopPrank();
    }

    function testTicoTokenSupply() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        uint preSupply = escrow.supply();
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        assertEq(escrow.supply(), preSupply + 1e21);
    }

    function testLatestCheckpointData() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        uint32 latestCheckpoint = escrow.numCheckpoints(owner);
        assertEq(latestCheckpoint, 1);
    }

    function testTokenOfOwnerByIndex() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        uint token_id = escrow.create_lock(1e21, lockDuration);
        uint nft_bal = escrow.balanceOf(owner);
        assertEq(nft_bal,1);
        assertEq(escrow.tokenOfOwnerByIndex(owner,nft_bal-1), token_id);
        assertEq(escrow.tokenOfOwnerByIndex(owner,nft_bal), 0);
    }
    
    function testCheckMintedNftOwner() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        uint tokenId = escrow.create_lock(1e21, lockDuration);
        address nft_owner = escrow.ownerOf(tokenId);
        assertEq(owner, nft_owner);
    }

    function testLockedParams() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        (int128 amount,uint end) = escrow.locked(1);
        assertEq(amount, 1e21);
        assertEq(end, ((block.timestamp + lockDuration) / WEEK) * WEEK);
    }

    function testCheckTokenBal() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        assertEq(TICO.balanceOf(owner), 0);
        assertEq(TICO.balanceOf(address(escrow)) - 1e21, 0);
    }


    function testCreateLock() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // Balance should be zero before and 1 after creating the lock
        assertEq(escrow.balanceOf(address(owner)), 0);
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        assertEq(escrow.ownerOf(1), address(owner));
        assertEq(escrow.balanceOf(address(owner)), 1);
    }

    function testCreateLockWithMultipleLocks() public {
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        escrow.create_lock(1e15, lockDuration);

        lockDuration = 12 * 4 * 7 * 24 * 3600;
        escrow.create_lock(1e6, lockDuration);
        vm.stopPrank();

        assertEq(escrow.ownerOf(2), address(owner));
        assertEq(escrow.balanceOf(address(owner)), 2);
    }

    function mintTico(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) public {
        for (uint256 i = 0; i < _amounts.length; i++) {
            TICO.mint(_accounts[i], _amounts[i]);
        }
    }
}
