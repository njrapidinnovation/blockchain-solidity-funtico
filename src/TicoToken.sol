// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract Tico is ERC20, Ownable {
    mapping(address => bool) public isMinter;

    bool public initialMinted;

    constructor() ERC20("Funtico", "TICO") {
        isMinter[msg.sender] = true;
        _mint(msg.sender, 0);
    }

    // No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        require(msg.sender == owner() || isMinter[msg.sender]);
        isMinter[_minter] = true;
    }

    // // Initial mint: total 82M
    // //  4M for "Genesis" pools
    // // 30M for liquid team allocation (40M excl init veNFT)
    // // 48M for future partners
    // function initialMint(address _recipient) external {
    //     require(msg.sender == minter && !initialMinted);
    //     initialMinted = true;
    //     _mint(_recipient, 82 * 1e6 * 1e18);
    // }

    function mint(address account, uint amount) external returns (bool) {
        require(msg.sender == owner() || isMinter[msg.sender]);
        _mint(account, amount);
        return true;
    }
}
