// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";

contract CounterTest is Test {
    SimpleBank public simpleBank;

    function setUp() public {
        simpleBank = new SimpleBank();
    }


}
