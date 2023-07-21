// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Tico is ERC20 {
    address owner;

    constructor() ERC20("Funtico", "TICO") {
        owner = msg.sender;
    }

    function mint(address account, uint amount) public {
        require(msg.sender == owner);
        _mint(account, amount);
    }
}
