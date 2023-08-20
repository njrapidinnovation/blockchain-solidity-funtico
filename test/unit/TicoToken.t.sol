// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "src/TicoToken.sol";
import "forge-std/console2.sol";

contract TicoTokenTest is Test {
    Tico TICO;

    function setUp() public {
        TICO = new Tico();
    }

    function testNameAndSymbol() public {
        assertEq(TICO.name(), "Funtico");
        assertEq(TICO.symbol(), "TICO");
    }

    function testMint() public {
        address account = makeAddr("account");
        uint amount = 1e18;
        vm.prank(account);
        vm.expectRevert();
        TICO.mint(account, amount);

        vm.prank(address(this));
        TICO.mint(account, amount);
        assertEq(TICO.balanceOf(account), 1e18);
    }
}
