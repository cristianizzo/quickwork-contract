// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {QuickWork} from "../src/QuickWork.sol";

contract QuickWorkTest is Test {
    QuickWork public quickWork;

    function setUp() public {
        counter = new QuickWork();
        counter.setNumber(0);
    }

    function testIncrement() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
