// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
// import "forge-std/console.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";

import "src/utils/SigUtils.sol";

contract VotingEscrowTest is Test {
    VotingEscrow escrow;
    Tico TICO;
    SigUtils internal sigUtils;

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
        address[] memory accounts = new address[](1);
        accounts[0] = owner;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e21;
        mintTico(accounts, amounts);
        escrow = new VotingEscrow(address(TICO));

        sigUtils = new SigUtils(escrow.DOMAIN_TYPEHASH());
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

    function testIncreaseUnlockTime() public {
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // 2. Create a new lock with an initial amount and unlock time
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, lockDuration);
        vm.stopPrank();

        // 3. Increase the unlock time by 1 week
        uint256 newUnlockTime = block.timestamp + 2 * lockDuration;
        vm.startPrank(owner);
        escrow.increase_unlock_time(tokenId, newUnlockTime);
        vm.stopPrank();

        // 4. Check the updated unlock time
        (int128 updatedAmount, uint updatedEnd) = escrow.locked(tokenId);
        uint256 expectedEnd = ((block.timestamp + 2 * lockDuration) / WEEK) *
            WEEK;

        assertEq(
            updatedAmount,
            int128(int256(initialAmount)),
            "Locked amount should remain unchanged"
        );
        assertEq(
            updatedEnd,
            expectedEnd,
            "Unexpected updated lock end timestamp"
        );
    }

    function testIncreaseUnlockTimeExpiredLock() public {
        // 1. Prepare test data
        uint256 initialAmount = 1e19; // Initial locked amount
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // 2. Create a new lock with an initial amount and make it expired
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, lockDuration);

        // 3. Fast forward time to make the lock expired using vm.warp
        vm.warp(MAXTIME + WEEK + 1);

        // 4. Try to increase the unlock time (should revert)
        vm.expectRevert("Lock expired");
        escrow.increase_unlock_time(
            tokenId,
            block.timestamp + 2 * lockDuration
        );
        vm.stopPrank();
    }

    function testIncreaseUnlockTimeExistingLockWithZeroValue() public {
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // 2. Create a new lock with an initial amount and unlock time
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, lockDuration);

        // 3. Try to increase the unlock time with zero value (should revert)
        vm.expectRevert("Can only increase lock duration");
        escrow.increase_unlock_time(tokenId, 0);
        vm.stopPrank();
    }

    function testIncreaseUnlockTimeNonExistingLock() public {
        // 1. Prepare test data
        uint256 unlockTime = block.timestamp + 2 * WEEK;

        // 2. Try to increase the unlock time for a non-existing lock (should revert)
        vm.prank(owner);
        vm.expectRevert();
        escrow.increase_unlock_time(9999, unlockTime); // Using a non-existing token ID
    }

    function testIncreaseUnlockTimeMultipleLocks() public {
        // 1. Prepare test data
        uint256[] memory initialAmounts = new uint256[](3);
        uint256 lockDuration = WEEK;
        uint256[] memory newUnlockTimes = new uint256[](3);
        uint256 totalExpectedVotes = 0;

        vm.startPrank(owner);
        for (uint256 i = 0; i < initialAmounts.length; i++) {
            initialAmounts[i] = (i + 1) * 1e18; // Initial locked amount for each lock

            // Create multiple locks with different initial amounts
            TICO.approve(address(escrow), initialAmounts[i]);
            uint256 tokenId = escrow.create_lock(
                initialAmounts[i],
                lockDuration
            );
            newUnlockTimes[i] = block.timestamp + (i + 2) * lockDuration; // Increase unlock time for each lock
            escrow.increase_unlock_time(tokenId, newUnlockTimes[i]);
            totalExpectedVotes += calculateExpectedVotingPower(
                initialAmounts[i],
                newUnlockTimes[i],
                block.timestamp
            );
        }
        vm.stopPrank();

        // 2. Get the votes balance for the account
        uint256 votesBalance = escrow.getVotes(owner);

        // 3. Check if the votes balance matches the expected total voting power
        assertEq(
            votesBalance,
            totalExpectedVotes,
            "Votes balance should match the expected total voting power"
        );
    }

    function testWithdrawWithoutExpiredLock() public {
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount

        // 2. Create a new lock with an initial amount and make it expired
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, WEEK);

        // 3. Try to withdraw from the expired lock (should revert)
        vm.expectRevert("The lock didn't expire");
        escrow.withdraw(tokenId);
        vm.stopPrank();
    }

    function testWithdrawValidLock() public {
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount

        // 2. Create a new lock with an initial amount and make it expired
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock(initialAmount, WEEK);
        vm.stopPrank();

        // 3. Fast forward time to make the lock expired
        vm.warp(MAXTIME + WEEK + 1);

        // 4. Get the token balance of the owner before withdrawal
        uint256 balanceBefore = TICO.balanceOf(owner);

        // 5. Withdraw from the lock
        vm.startPrank(owner);
        escrow.withdraw(tokenId);
        vm.stopPrank();

        // 6. Get the token balance of the owner after withdrawal
        uint256 balanceAfter = TICO.balanceOf(owner);

        // 7. Check if the lock is deleted and token balance is updated
        // assertEq(
        //     escrow.locked(tokenId).amount,
        //     int128(0),
        //     "Lock should be deleted after withdrawal"
        // );
        assertEq(
            balanceAfter - balanceBefore,
            initialAmount,
            "Unexpected token balance after withdrawal"
        );
    }

    /** testcases for supplyAt function */
    function testSupplyAt() public {
        // 1. Prepare test data
        uint256 lockDuration = MAXTIME;
        uint256 initialAmount = 1e19; // Initial locked amount

        // 2. Create a new lock with an initial amount and unlock time
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        escrow.create_lock(initialAmount, lockDuration);
        vm.stopPrank();

        // 4. Calculate total voting power at the time of expiration
        uint totalSupply = escrow.getPastTotalSupply(block.timestamp);
        uint expectedSupply = calculateExpectedVotingPower(
            initialAmount,
            lockDuration,
            block.timestamp
        );
        // uint256 totalSupplyAtHalftime = escrow.totalSupplyAtT(
        //     (block.timestamp + MAXTIME) / 2
        // );
        // uint expectedSupplyAtHalftime = calculateExpectedVotingPower(
        //     initialAmount,
        //     lockDuration,
        //     (block.timestamp + MAXTIME) / 2
        // );
        // 5. Check if the calculated total voting power matches the initial locked amount
        assertEq(totalSupply, expectedSupply, " voting power should match");
        // assertEq(
        //     totalSupplyAtHalftime,
        //     expectedSupplyAtHalftime,
        //     "Total voting power should match the initial locked amount"
        // );
    }

    // testcase for create_lock_for

    function testCreateLockFor() public {
        // 1. Prepare test data
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        uint256 initialAmount = 1e19; // Initial locked amount
        address recipient = address(0x123); // Replace with the desired recipient address

        // 2. Create a new lock with an initial amount and lock duration for the recipient
        vm.startPrank(owner);
        TICO.approve(address(escrow), initialAmount);
        uint256 tokenId = escrow.create_lock_for(
            initialAmount,
            lockDuration,
            recipient
        );
        vm.stopPrank();

        // 3. Get the locked details for the created token ID
        (int128 lockedAmount, uint256 unlockTime) = escrow.locked(tokenId);

        // 4. Check if the locked amount and unlock time match the provided values
        assertEq(
            lockedAmount,
            int128(int256(initialAmount)),
            "Unexpected locked amount"
        );

        uint256 expectedUnlockTime = ((block.timestamp + lockDuration) / WEEK) *
            WEEK;
        assertEq(unlockTime, expectedUnlockTime, "Unexpected unlock time");

        // 5. Check if the voting power has been assigned to the recipient
        uint256 votesBalanceRecipient = escrow.getVotes(recipient);
        uint256 votesBalanceOwner = escrow.getVotes(owner);

        uint256 expectedVoteBalance = calculateExpectedVotingPower(
            initialAmount,
            lockDuration,
            block.timestamp
        );
        assertEq(
            votesBalanceRecipient,
            expectedVoteBalance,
            "Unexpected voting power for the recipient"
        );
        assertEq(votesBalanceOwner, 0, "Unexpected voting power for the owner");

        // testing the delegation logic
        address t = escrow.delegates(recipient);
        console.log(t);
        vm.prank(recipient);
        escrow.transferFrom(recipient, owner, tokenId);
        address a = escrow.delegates(recipient);
        console.log(a);
        address currentOwnerOfToken = escrow.ownerOf(tokenId);
        console.log(currentOwnerOfToken);
        assertEq(currentOwnerOfToken, owner);
    }

    // Helper function to calculate the expected voting power for a given lock at a specific timestamp
    function calculateExpectedVotingPower(
        uint256 initialAmount,
        uint256 lockDuration,
        uint256 timestamp
    ) internal pure returns (uint256) {
        uint256 unlockTime = ((timestamp + lockDuration) / WEEK) * WEEK; // Locktime is rounded down to weeks
        int128 slope = int128(int256(initialAmount / MAXTIME));
        uint contribution = uint(
            int256(slope * int128(int256(unlockTime - timestamp)))
        );
        return (contribution);
    }

    // Test case: Get past votes balance for an account with no locked tokens
    function testGetPastVotesNoLockedTokens() public {
        uint256 timestamp = block.timestamp; // Current timestamp

        // 1. Get the past votes balance for the account
        uint256 pastVotesBalance = escrow.getPastVotes(owner, timestamp);

        // 2. Check if the past votes balance is zero
        assertEq(
            pastVotesBalance,
            0,
            "Past votes balance should be zero for an account with no locked tokens"
        );
    }

    // Test case: Get past votes balance for an account with locked tokens
    function testGetPastVotesWithLockedTokens() public {
        vm.startPrank(owner);
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount
        uint256 lockDuration = MAXTIME;
        uint256 timestamp = block.timestamp;

        // 2. Create a new lock with an initial amount and unlock time
        TICO.approve(address(escrow), initialAmount);
        escrow.create_lock(initialAmount, lockDuration);
        vm.stopPrank();

        // 3. Get the past votes balance for the account at the current timestamp
        uint256 pastVotesBalance = escrow.getPastVotes(owner, timestamp);

        // 4. Calculate the expected past votes balance
        uint256 expectedPastVotes = calculateExpectedVotingPower(
            initialAmount,
            lockDuration,
            timestamp
        );

        // 5. Check if the past votes balance matches the expected value
        assertEq(
            pastVotesBalance,
            expectedPastVotes,
            "Past votes balance should match the expected value"
        );
    }

    // Test case: Get votes balance for an account with multiple locked tokens
    // function testGetPastVotesWithMultipleLocks() public {
    //     // 1. Prepare test data
    //     uint256[] memory initialAmounts = new uint256[](3);
    //     uint256 lockDuration = WEEK;
    //     uint totalExpectedVotes = 0;

    //     vm.startPrank(owner);

    //     // 2. Create multiple locks with different initial amounts
    //     for (uint i = 0; i < initialAmounts.length; i++) {
    //         initialAmounts[i] = (i + 1) * 1e18; // Initial locked amount for each lock
    //         TICO.approve(address(escrow), initialAmounts[i]);
    //         vm.warp(block.timestamp + lockDuration);
    //         escrow.create_lock(initialAmounts[i], lockDuration);
    //     }
    //     for (uint i = 0; i < initialAmounts.length; i++) {
    //         totalExpectedVotes += calculateExpectedVotingPower(
    //             initialAmounts[i],
    //             lockDuration,
    //             block.timestamp
    //         );
    //     }
    //     vm.stopPrank();

    //     // 3. Get the votes balance for the account
    //     uint votesBalance = escrow.getPastVotes(owner, block.timestamp);

    //     // 4. Check if the votes balance matches the expected total voting power
    //     console.log(votesBalance, totalExpectedVotes);
    //     assertEq(
    //         votesBalance,
    //         totalExpectedVotes,
    //         "Votes balance should match the expected total voting power"
    //     );
    // }

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
    function testGetVotesWithLockedTokens() public {
        vm.startPrank(owner);
        // 1. Prepare test data
        uint256 initialAmount = 1e18; // Initial locked amount
        uint lockDuration = MAXTIME;
        uint expectedVotingPower = calculateExpectedVotingPower(
            initialAmount,
            lockDuration,
            block.timestamp
        );

        // 2. Create a new lock with an initial amount and unlock time
        TICO.approve(address(escrow), initialAmount);

        // console.log(block.timestamp, unlock_time);
        escrow.create_lock(initialAmount, lockDuration);
        vm.stopPrank();

        // 3. Get the votes balance for the account
        uint votesBalance = (escrow.getPastVotes(owner, 1));

        console.log(votesBalance, expectedVotingPower);

        // 4. Check if the votes balance matches the initial locked amount
        assertEq(
            votesBalance,
            expectedVotingPower,
            "Votes balance should match the initial locked amount"
        );
    }

    // Test case: Get votes balance for an account with multiple locked tokens
    function testGetVotesWithMultipleLocks() public {
        // 1. Prepare test data
        uint256[] memory initialAmounts = new uint256[](3);
        uint256 lockDuration = WEEK;
        uint totalExpectedVotes = 0;

        vm.startPrank(owner);
        for (uint i = 0; i < initialAmounts.length; i++) {
            initialAmounts[i] = (i + 1) * 1e18; // Initial locked amount for each lock
            totalExpectedVotes += calculateExpectedVotingPower(
                initialAmounts[i],
                lockDuration,
                block.timestamp
            );
        }

        // 2. Create multiple locks with different initial amounts
        for (uint i = 0; i < initialAmounts.length; i++) {
            TICO.approve(address(escrow), initialAmounts[i]);
            escrow.create_lock(initialAmounts[i], lockDuration);
        }
        vm.stopPrank();

        // 3. Get the votes balance for the account
        uint votesBalance = escrow.getVotes(owner);

        // 4. Check if the votes balance matches the expected total voting power
        console.log(votesBalance, totalExpectedVotes);
        assertEq(
            votesBalance,
            totalExpectedVotes,
            "Votes balance should match the expected total voting power"
        );
    }

    function testDelegateBySig() public {

        address delegatee = makeAddr("Delegatee");
        SigUtils.Delegation memory delegation = SigUtils.Delegation({
            delegatee:delegatee,
            nonce:0,
            expiry:10e9
        });

        bytes32 digest = sigUtils.getTypedDataHash(delegation);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.prank(delegatee);
        escrow.delegateBySig(delegatee, 0, 10e9, v, r, s);
    }
}