# QuickWork Smart Contract

## Overview

The `QuickWork` contract is a decentralized application built on the Ethereum blockchain. It allows a manager to manage tasks and their associated payments using native ether. The contract ensures that tasks are uniquely identified, and payments are securely handled using the Ethereum blockchain.

## Features

- **Task Management**: Allows the addition of tasks with unique identifiers, associated payment amounts, payer, payee, and an approver.

- **Secure Payments**: Payments are held within the contract until tasks are either approved or rejected. Once approved, the payee can withdraw their funds. If rejected, the payer can reclaim their funds.

- **Reentrancy Protection**: The contract uses the `ReentrancyGuard` from OpenZeppelin to prevent reentrancy attacks, ensuring that functions cannot be interrupted and invoked again before they complete their initial execution.

- **Role-Based Access Control**: Only the designated manager can change certain parameters, and only the designated approver for a task can approve or reject it.

## Functions

### Constructor

- `constructor(address _manager)`: Sets the initial manager of the contract.

### Task Management

- `addTask(uint256 _taskId, uint256 _amount, address payable _payerAddress, address payable _payeeAddress, address _approverAddress)`: Adds a new task to the contract. Requires the sent ether value to match the task amount.

- `approveTask(uint256 _taskId)`: Allows the approver of a task to approve it. The associated payment is then made available to the payee.

- `rejectTask(uint256 _taskId)`: Allows the approver of a task to reject it. The associated payment is then made available to the payer.

### Withdrawal

- `withdraw(uint256 _amount)`: Allows an address to withdraw their available funds from the contract.

## Events

- `TaskAdded`: Emitted when a new task is added.

- `TaskApproved`: Emitted when a task is approved.

- `TaskRejected`: Emitted when a task is rejected.

- `FundsWithdrawn`: Emitted when funds are withdrawn.

## Modifiers

- `onlyManager`: Ensures that only the manager can execute the function.

- `onlyApprover`: Ensures that only the designated approver for a task can execute the function.

## Dependencies

- The contract uses the `ReentrancyGuard` from the [OpenZeppelin](https://openzeppelin.com/) library to prevent reentrancy attacks.

