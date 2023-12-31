// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {QuickWork} from "../src/QuickWork.sol";
import "openzeppelin-contracts/lib/forge-std/src/console.sol";

contract QuickWorkTest is Test {
  QuickWork public quickWork;
  address payable manager;
  address payable payer;
  address payable payee;
  address payable approver;

  function setUp() public {
    manager = payable(address(0xABCD));
    payer = payable(address(0xABC));
    payee = payable(address(0x123));
    approver = payable(address(0xDEF));
    quickWork = new QuickWork(address(this));
  }

  // Test adding a task
  function testAddTask() public {
    uint256 taskId = 1;
    uint256 amount = 1 ether;

    // Set the manager as the caller and send ether when adding the task
    quickWork.addTask{value : amount}(taskId, payer, payee, approver);

    // Assertions
    (uint256 returnedTaskId, uint256 returnedAmount, address returnedPayer, address returnedPayee, address returnedApprover) = quickWork.tasks(taskId);
    assertEq(returnedTaskId, taskId);
    assertEq(returnedAmount, amount);
    assertEq(returnedPayer, payer);
    assertEq(returnedPayee, payee);
    assertEq(returnedApprover, approver);
  }

  // Test approving a task
  function testApproveTask() public {
    uint256 taskId = 2;
    // Using a different taskId to avoid conflicts with the previous tests
    uint256 amount = 1 ether;

    // Set the manager as the caller and send ether when adding the task
    quickWork.addTask{value : amount}(taskId, payer, payee, approver);

    // Impersonate the approver for the next call
    vm.prank(approver);

    // Approve task as the approver
    quickWork.approveTask(taskId);

    // Check that the payee's balance in QuickWork is updated
    uint256 payeeBalanceInContract = quickWork.balances(payee);
    assertEq(payeeBalanceInContract, amount, "Payee balance mismatch in contract after task approval");

    // Impersonate the payee for the next call
    vm.prank(payee);

    // Payee withdraws the funds
    quickWork.withdraw(amount);

    // Check that the payee's balance in QuickWork is now 0
    uint256 payeeBalanceAfterWithdrawal = quickWork.balances(payee);
    assertEq(payeeBalanceAfterWithdrawal, 0, "Payee balance in contract should be 0 after withdrawal");

    // Check that the contract's balance is also 0
    uint256 contractBalance = address(quickWork).balance;
    assertEq(contractBalance, 0, "Contract balance should be 0 after payee's withdrawal");
  }

  // Test rejecting a task
  function testRejectTask() public {
    uint256 taskId = 3; // Using a different taskId to avoid conflicts with the previous tests
    uint256 amount = 1 ether;

    // Set the manager as the caller and send ether when adding the task
    quickWork.addTask{value : amount}(taskId, payer, payee, approver);

    // Impersonate the approver for the next call
    vm.prank(approver);

    // Reject task as the approver
    quickWork.rejectTask(taskId);

    // Check that the payee's balance in QuickWork is 0
    uint256 payeeBalanceInContract = quickWork.balances(payee);
    assertEq(payeeBalanceInContract, 0, "Payee balance should remain 0 after task rejection");

    // Check that the payer's balance in QuickWork is updated correctly
    uint256 payerBalanceInContract = quickWork.balances(payer);
    assertEq(payerBalanceInContract, amount, "Payer balance mismatch in contract after task rejection");

    // Impersonate the payer for the next call
    vm.prank(payer);

    // Payer withdraws the funds
    quickWork.withdraw(amount);

    // Check that the payer's balance in QuickWork is now 0
    uint256 payerBalanceAfterWithdrawal = quickWork.balances(payer);
    assertEq(payerBalanceAfterWithdrawal, 0, "Payer balance in contract should be 0 after withdrawal");

    // Check that the contract's balance is also 0
    uint256 contractBalance = address(quickWork).balance;
    assertEq(contractBalance, 0, "Contract balance should be 0 after payer's withdrawal");
  }

  // Test that only the manager can add a task
  function testOnlyManagerCanAddTask() public {
    uint256 taskId = 4; // Using a different taskId to avoid conflicts
    uint256 amount = 1 ether;

    // Send funds to the payer address
    payable(payer).transfer(amount);

    // Check payer's balance to ensure funds were transferred
    uint256 payerBalance = address(payer).balance;
    assertEq(payerBalance, amount, "Payer did not receive the funds");

    // Impersonate a random address that is not the manager
    vm.prank(payer);

    // Try to add a task as a non-manager
    try quickWork.addTask{value : amount}(taskId, payer, payee, approver) {
      fail("Non-manager was able to add a task");
    } catch Error(string memory reason) {
      assertEq(reason, "Only the manager can call this function");
    }
  }

  // Test that only the approver can approve a task
  function testOnlyApproverCanApproveTask() public {
    uint256 taskId = 5; // Using a different taskId to avoid conflicts
    uint256 amount = 1 ether;

    // Add a task as the manager
    quickWork.addTask{value : amount}(taskId, payer, payee, approver);

    // Impersonate a random address that is not the approver
    vm.prank(payer);

    // Try to approve a task as a non-approver
    try quickWork.approveTask(taskId) {
      fail("Non-approver was able to approve a task");
    } catch Error(string memory reason) {
      assertEq(reason, "Only the designated approver can call this function");
    }
  }

  // Test that only the approver can reject a task
  function testOnlyApproverCanRejectTask() public {
    uint256 taskId = 6; // Using a different taskId to avoid conflicts
    uint256 amount = 1 ether;

    // Add a task as the manager
    quickWork.addTask{value : amount}(taskId, payer, payee, approver);

    // Impersonate a random address that is not the approver
    vm.prank(payee);

    // Try to reject a task as a non-approver
    try quickWork.rejectTask(taskId) {
      fail("Non-approver was able to reject a task");
    } catch Error(string memory reason) {
      assertEq(reason, "Only the designated approver can call this function");
    }
  }
}
