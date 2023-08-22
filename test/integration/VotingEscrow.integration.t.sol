// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "src/TicoToken.sol";
import "src/VotingEscrow.sol";

// import "src/utils/SigUtils.sol";
contract VotingEscrowIntegrationTest is Test {
    VotingEscrow escrow;
    Tico TICO;

    address owner;
    address bob = makeAddr("0x01");
    address alice = makeAddr("0x02");
    uint internal constant MAXTIME = 4 * 365 * 86400;
    uint internal constant WEEK = 1 weeks;

    uint256 internal ownerPrivateKey;

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
    }

    function mintTico(address[] memory _accounts, uint256[] memory _amounts)
        public
    {
        for (uint256 i = 0; i < _amounts.length; i++) {
            TICO.mint(_accounts[i], _amounts[i]);
        }
    }

    // Helper function to calculate the expected voting power for a given lock at a specific timestamp
    function calculateExpectedVotingPower(
        uint256 initialAmount,
        uint256 lockDuration,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 unlockTime = ((block.timestamp + lockDuration) / WEEK) * WEEK; // Locktime is rounded down to weeks
        int128 slope = int128(int256(initialAmount / MAXTIME));
        uint contribution = uint(
            int256(slope * int128(int256(unlockTime - timestamp)))
        );
        return (contribution);
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
        // console.log(votesBalance, totalExpectedVotes);
        assertEq(
            votesBalance,
            totalExpectedVotes,
            "Votes balance should match the expected total voting power"
        );
    }

    // Test case: Re-delegation of votes
    function testDelegateRedelegation() public {
        // Delegate votes from the owner to delegatee1

        address delegatee1 = address(0x456);
        address delegatee2 = address(0x789);
        vm.prank(owner);
        escrow.delegate(delegatee1);

        assertEq(
            escrow.delegates(owner),
            delegatee1,
            "Votes should be delegated to delegatee1"
        );

        // Delegate votes from the owner to delegatee2 (re-delegation)
        vm.prank(owner);
        escrow.delegate(delegatee2);

        assertEq(
            escrow.delegates(owner),
            delegatee2,
            "Votes should be re-delegated to delegatee2"
        );
    }
}
