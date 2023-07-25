// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";

contract VotingEscrowTest is Test {
    VotingEscrow escrow;
    Tico TICO;
    address owner = makeAddr("owner");
    address bob = makeAddr("0x01");
    address alice = makeAddr("0x02");
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
        assertEq(nft_bal, 1);
        assertEq(escrow.tokenOfOwnerByIndex(owner, nft_bal - 1), token_id);
        assertEq(escrow.tokenOfOwnerByIndex(owner, nft_bal), 0);
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
        (int128 amount, uint end) = escrow.locked(1);
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

    function testNftTransfer() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.safeTransferFrom(owner, bob, 1, "");
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testNftTransferRevert() public {
        vm.startPrank(owner);
        vm.expectRevert();
        escrow.transferFrom(owner, bob, 1);
        vm.stopPrank();
    }

    function testNftSafeTransferWithApprove() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.approve(bob, 1);

        bool isApprovedOrOwner = escrow.isApprovedOrOwner(bob, 1);
        assertEq(isApprovedOrOwner, true);

        address getApprovedAddress = escrow.getApproved(1);
        assertEq(getApprovedAddress, bob);
        vm.prank(bob);
        escrow.safeTransferFrom(owner, bob, 1, "");
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testWrongId() public {
        vm.startPrank(owner);
        vm.expectRevert();
        escrow.approve(bob, 1);
    }

    function testApproveForMyself() public {
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);
        vm.expectRevert();
        escrow.approve(owner, 1);
        vm.stopPrank();
    }

    function testApproveByApproved() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        // vm.prank(owner);
        // escrow.setApprovalForAll(bob, true);
        vm.startPrank(bob);
        vm.expectRevert();
        escrow.approve(alice, 1);
        vm.stopPrank();
    }

    function testApproveAllForMyself() public {
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);
        vm.expectRevert();
        escrow.setApprovalForAll(owner, true);
        vm.stopPrank();
    }

    function testNftSafeTransferWithApproveForAllWithCallData() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.setApprovalForAll(bob, true);
        bool getApprovedAll = escrow.isApprovedForAll(owner, bob);
        assertEq(getApprovedAll, true);
        vm.prank(bob);
        escrow.safeTransferFrom(owner, bob, 1, "");
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testNftSafeTransferWithApproveForAllWithoutCallData() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.setApprovalForAll(bob, true);
        bool getApprovedAll = escrow.isApprovedForAll(owner, bob);
        assertEq(getApprovedAll, true);
        vm.prank(bob);
        escrow.safeTransferFrom(owner, bob, 1);
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testNftTransferWithApprove() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.approve(bob, 1);
        vm.prank(bob);
        escrow.transferFrom(owner, bob, 1);
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testNftTransferWithApproveForAll() public {
        vm.prank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        vm.prank(owner);
        escrow.create_lock(1e21, lockDuration);
        vm.prank(owner);
        escrow.setApprovalForAll(bob, true);
        vm.prank(bob);
        escrow.transferFrom(owner, bob, 1);
        address newOwner = escrow.ownerOf(1);
        assertEq(newOwner, bob);
    }

    function testSupportInterfaces() public {
        bool support = escrow.supportsInterface(0x01ffc9a7);
        assertTrue(support == true);
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

    function testIncreaseAmount() public {
        // 1. Prepare test data
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        uint256 initialAmount = 1e19; // Initial locked amount
        uint256 increaseAmount = 1e18; // Amount to be added to the existing lock

        // 2. Create a new lock with an initial amount
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, lockDuration);

        // 3. Increase the locked amount
        TICO.approve(address(escrow), increaseAmount);
        escrow.increase_amount(tokenId, increaseAmount);
        vm.stopPrank();

        // 4. Check the updated locked amount
        (int128 updatedAmount, uint updatedEnd) = escrow.locked(tokenId);
        uint256 expectedEnd = ((block.timestamp + lockDuration) / WEEK) * WEEK;

        assertEq(
            updatedAmount,
            int128(int256(initialAmount + increaseAmount)),
            "Unexpected updated locked amount"
        );
        assertEq(
            updatedEnd,
            expectedEnd,
            "Unexpected updated lock end timestamp"
        );
    }

    function testIncreaseAmountExpiredLock() public {
        // 1. Prepare test data
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        uint256 initialAmount = 1e19; // Initial locked amount
        uint256 increaseAmount = 1e18; // Amount to be added to the existing lock

        // 2. Create a new lock with an initial amount and make it expired
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount + increaseAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, lockDuration);

        // 3. Fast forward time to make the lock expired using vm.warp
        vm.warp(MAXTIME + WEEK + 1);

        // 3. Try to increase the locked amount (should revert)
        vm.expectRevert("Cannot add to expired lock. Withdraw");
        escrow.increase_amount(tokenId, increaseAmount);
        vm.stopPrank();
    }

    function testIncreaseAmountWithoutLock() public {
        // 1. Prepare test data
        uint256 increaseAmount = 5e20; // Amount to be added to the non-existing lock

        // 2. Try to increase the locked amount for a non-existing lock (should revert)
        vm.expectRevert();
        escrow.increase_amount(9999, increaseAmount); // Using a non-existing token ID
    }

    function testIncreaseAmountWithZeroValue() public {
        // 1. Prepare test data
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // 2. Create a new lock with an initial amount
        vm.startPrank(owner);
        TICO.approve(address(escrow), 1e21);
        uint256 tokenId = escrow.create_lock(1e21, lockDuration);

        // 3. Try to increase the locked amount with zero value (should revert)
        vm.expectRevert();
        escrow.increase_amount(tokenId, 0);
        vm.stopPrank();
    }

    // Test case: Attempt to increase amount with an invalid token ID
    function testIncreaseAmountInvalidTokenId() public {
        uint256 invalidTokenId = 9999; // Using an invalid token ID

        // Attempt to increase the locked amount with an invalid token ID (should revert)
        vm.expectRevert();
        escrow.increase_amount(invalidTokenId, 1e18);
    }

    function testGetVotes() public {
        vm.startPrank(owner);
        // create a lock, estimate the getVotss
    }

    // Test case: Get votes balance for an account with no locked tokens
    function testGetVotesNoLockedTokens() public {
        uint256 votesBalance = escrow.getVotes(owner);
        assertEq(
            votesBalance,
            0,
            "Votes balance should be zero for an account with no locked tokens"
        );
    }

    // Test case: Get votes balance for an account with locked tokens
    // function testGetVotesWithLockedTokens() public {
    //     vm.startPrank(owner);
    //     // 1. Prepare test data
    //     uint256 initialAmount = 1e18; // Initial locked amount
    //     uint lock_duration = MAXTIME;
    //     uint unlock_time = ((block.timestamp + lock_duration) / WEEK) * WEEK; // Locktime is rounded down to weeks

    //     uint observedVotingPower = (unlock_time * initialAmount) /
    //         lock_duration;

    //     // console.log(block.timestamp, unlock_time, _maxtime, MAXTIME);
    //     // 2. Create a new lock with an initial amount and unlock time
    //     TICO.approve(address(escrow), initialAmount);
    //     vm.warp(1);
    //     console.log(block.timestamp, unlock_time);
    //     uint256 tokenId = escrow.create_lock(initialAmount, lock_duration);
    //     vm.stopPrank();

    //     // 3. Get the votes balance for the account
    //     uint256 votesBalance = escrow.getPastVotes(owner, 1);

    //     // 4. Check if the votes balance matches the initial locked amount
    //     assertEq(
    //         votesBalance,
    //         observedVotingPower,
    //         "Votes balance should match the initial locked amount"
    //     );
    // }
}
