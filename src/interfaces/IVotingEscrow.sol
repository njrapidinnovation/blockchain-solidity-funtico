// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVotingEscrow {
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function token() external view returns (address);

    // function team() external returns (address);

    function epoch() external view returns (uint);

    function getPointHistory(uint loc) external view returns (Point memory);

    function getUserPointHistory(uint tokenId, uint _epoch)
        external
        view
        returns (Point memory);

    function getUserPointEpoch(uint tokenId) external view returns (uint);

    function ownerOf(uint) external view returns (address);

    function isApprovedOrOwner(address, uint) external view returns (bool);

    function transferFrom(
        address,
        address,
        uint
    ) external;

    function voting(uint tokenId) external;

    function abstain(uint tokenId) external;

    function attach(uint tokenId) external;

    function detach(uint tokenId) external;

    function checkpoint() external;

    function deposit_for(uint tokenId, uint value) external;

    function create_lock_for(
        uint,
        uint,
        address
    ) external returns (uint);

    function balanceOfNFT(uint) external view returns (uint);

    function totalSupply() external view returns (uint);
}
