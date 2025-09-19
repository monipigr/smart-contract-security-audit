// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";
import {Attacker} from "../src/Attacker.sol";

contract ReentrancyAttack is Test {
    SimpleBank public simpleBank;
    Attacker public attacker;

    address public user = vm.addr(1);

    function setUp() public {
        simpleBank = new SimpleBank();
        attacker = new Attacker(address(simpleBank));
    }

    /**
     * @notice Ensures that the user can deposit ETH in SimpleBank
     */
    function test_depositETH() public {
        vm.deal(user, 20 ether);
        vm.startPrank(user);

        uint256 userBalanceBefore = simpleBank.userBalance(user);
        uint256 bankBalanceBefore = simpleBank.totalBalance();

        simpleBank.deposit{value: 20 ether}();

        uint256 userBalanceAfter = simpleBank.userBalance(user);
        uint256 bankBalanceAfter = simpleBank.totalBalance();

        assert(userBalanceBefore + 20 ether == userBalanceAfter);
        assert(bankBalanceBefore + 20 ether == bankBalanceAfter);

        vm.stopPrank();
    }

    function test_deposit_revertIfNotMinimumDeposit() public {
        vm.deal(user, 100 wei);
        vm.startPrank(user);

        vm.expectRevert("Minimum deposit is 1 ether");
        simpleBank.deposit{value: 100 wei}();

        vm.stopPrank();
    }

    /**
     * @notice Ensures that the user can withdraw ETH from SimpleBank
     */

    function test_withdraw() public {
        vm.deal(user, 20 ether);
        vm.startPrank(user);

        uint256 userBalanceBefore = simpleBank.userBalance(user);
        uint256 bankBalanceBefore = simpleBank.totalBalance();

        simpleBank.deposit{value: 20 ether}();
        simpleBank.withdraw();

        uint256 userBalanceAfter = simpleBank.userBalance(user);
        uint256 bankBalanceAfter = simpleBank.totalBalance();

        assert(userBalanceAfter == userBalanceBefore);
        assert(bankBalanceAfter == bankBalanceBefore);

        vm.stopPrank();
    }   

    /**
     * @notice Ensures that the user cannot withdraw ETH if has not enough balance
     */
    function test_withdraw_revertIfUserNotEnoughBalance() public {
        vm.deal(user, 100 wei);
        vm.startPrank(user);

        vm.expectRevert("User has not enough balance");
        simpleBank.withdraw();

        vm.stopPrank();
    }

    /**
     * @notice Simulates a reentrancy attack
     * @dev Steps: 
     * 1. User deposits 20 ether in SimpleBank
     * 2. Attacker deposits 2 ether in SimpleBank
     * 3. Attacker executes the attack
     * 4. Ensures that the attack was successful and that all funds have been drained
     */
    function test_attack() public {
        // User deposits 20 ether
        vm.deal(user, 20 ether);
        vm.startPrank(user);

        simpleBank.deposit{value: 20 ether}();

        vm.stopPrank();

        // Ensures balance before the attack is 20 ether
        assert(simpleBank.totalBalance() == 20 ether);

        // Attacker executes the attack depositing 2 ethers
        vm.deal(address(attacker), 2 ether);
        vm.startPrank(address(attacker));

        attacker.attack{value: 2 ether}();

        vm.stopPrank();

        // Notices the balance after the attack is 0 and all funds have been drained
        assert(simpleBank.totalBalance() == 0);
    }   
}
