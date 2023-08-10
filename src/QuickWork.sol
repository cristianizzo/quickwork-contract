// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/**
 * @title QuickWork
 * @dev This contract allows a manager to manage tasks and their associated payments using native ether.
 */
contract QuickWork is ReentrancyGuard {
  address public manager;  // Address of the manager

  // Struct for task details
  struct Task {
    uint256 id;  // Unique identifier for the task
    uint256 amount;  // Amount allocated for the task in wei
    address payable payerAddress;  // Address of the payer for the task
    address payable payeeAddress;  // Address of the payee for the task
    address approverAddress;  // Address of the approver
  }

  // Mapping to store balances by address
  mapping(address => uint256) public balances;
  // Mapping to store task details by task ID
  mapping(uint256 => Task) public tasks;

  // Events
  event TaskAdded(uint256 indexed taskId, address indexed payeeAddress, uint256 amount, address indexed approverAddress);
  event TaskApproved(uint256 indexed taskId, address indexed payeeAddress);
  event TaskRejected(uint256 indexed taskId, address indexed payerAddress);
  event FundsWithdrawn(address indexed addressWithdrawn, uint256 amount);

  // Modifiers
  modifier onlyManager() {
    require(msg.sender == manager, "Only the manager can call this function");
    _;
  }

  modifier onlyApprover(uint256 taskId) {
    require(msg.sender == tasks[taskId].approverAddress, "Only the designated approver can call this function");
    _;
  }

  /**
   * @dev Constructor to set the initial manager.
     * @param _manager Address of the manager.
     */
  constructor(address _manager) {
    manager = _manager;
  }

  /**
   * @dev Function to add a new task.
     * @param _taskId Unique identifier for the task.
     * @param _payerAddress Address of the payer for the task.
     * @param _payeeAddress Address of the payee for the task.
     * @param _approverAddress Address of the approver for the task.
     */
  function addTask(uint256 _taskId, address payable _payerAddress, address payable _payeeAddress, address _approverAddress) public payable onlyManager {
    require(_payerAddress != address(0) && _payeeAddress != address(0), "Payer and Payee addresses must not be zero");
    require(_payerAddress != _payeeAddress, "Payer and Payee addresses must be distinct");
    require(tasks[_taskId].id == 0, "Task ID already exists");
    require(msg.value > 0, "Amount should be greater than 0");

    tasks[_taskId] = Task(_taskId, msg.value, _payerAddress, _payeeAddress, _approverAddress);
    emit TaskAdded(_taskId, _payeeAddress, msg.value, _approverAddress);
  }

  /**
   * @dev Function for the approver to approve a task.
     * @param _taskId Unique identifier for the task.
     */
  function approveTask(uint256 _taskId) public onlyApprover(_taskId) {
    require(tasks[_taskId].id != 0, "Task ID does not exist");
    require(tasks[_taskId].amount != 0, "Task has already been approved or rejected");

    balances[tasks[_taskId].payeeAddress] += tasks[_taskId].amount;
    tasks[_taskId].amount = 0;
    emit TaskApproved(_taskId, tasks[_taskId].payeeAddress);
  }

  /**
   * @dev Function for the approver to reject a task.
     * @param _taskId Unique identifier for the task.
     */
  function rejectTask(uint256 _taskId) public onlyApprover(_taskId) {
    require(tasks[_taskId].id != 0, "Task ID does not exist");
    require(tasks[_taskId].amount != 0, "Task has already been approved or rejected");

    balances[tasks[_taskId].payerAddress] += tasks[_taskId].amount;
    tasks[_taskId].amount = 0;
    emit TaskRejected(_taskId, tasks[_taskId].payeeAddress);
  }

  /**
   * @dev Function for anyone to withdraw their funds.
     * @param _amount Amount to withdraw in wei.
     */
  function withdraw(uint256 _amount) public nonReentrant {
    require(balances[msg.sender] >= _amount, "Insufficient balance");

    balances[msg.sender] -= _amount;
    payable(msg.sender).transfer(_amount);
    emit FundsWithdrawn(msg.sender, _amount);
  }
}
