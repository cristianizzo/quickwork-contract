// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WorkContract
 * @dev This contract allows a payer to manage tasks and their associated payments.
 */
contract QuickWork is ReentrancyGuard {
    address public payer;  // Address of the payer
    address public tokenAddress;  // Address of the ERC20 token (e.g., USDC)
    uint256 public unallocatedFunds = 0;  // Funds that are not allocated to any task

    // Enumeration for task statuses
    enum TaskStatus {Pending, Approved, Rejected, Disputed}

    // Struct for payee details
    struct Payee {
        address payable payeeAddress;  // Address of the payee
        uint256 balance;  // Balance of the payee
    }

    // Struct for task details
    struct Task {
        uint256 id;  // Unique identifier for the task
        uint256 amount;  // Amount allocated for the task
        address payeeAddress;  // Address of the payee for the task
        TaskStatus status;  // Status of the task
    }

    // Struct for task update requests
    struct TaskUpdateRequest {
        uint256 newAmount;  // Proposed new amount for the task
        bool payerApproved;  // Whether the payer has approved the update
        bool payeeApproved;  // Whether the payee has approved the update
    }

    // Mapping to store update requests by task ID
    mapping(uint256 => TaskUpdateRequest) public updateRequests;
    // Mapping to store payee details by address
    mapping(address => Payee) public payees;
    // Mapping to store task details by task ID
    mapping(uint256 => Task) public tasks;

    // Events
    event PayeeAdded(address indexed payeeAddress);
    event TaskAdded(uint256 indexed taskId, address indexed payeeAddress, uint256 amount);
    event TaskApproved(uint256 indexed taskId, address indexed payeeAddress);
    event TaskRejected(uint256 indexed taskId, address indexed payeeAddress);
    event FundsWithdrawn(address indexed payeeAddress, uint256 amount);
    event PayerFundsRetrieved(address indexed payer, uint256 amount);
    event TaskUpdateProposed(uint256 indexed taskId, uint256 newAmount, address proposer);
    event TaskUpdateApproved(uint256 indexed taskId, uint256 newAmount, address approver);

    // Modifiers
    modifier onlyPayer() {
        require(msg.sender == payer, "Only the payer can call this function");
        _;
    }

    modifier onlyPayee(address _payeeAddress) {
        require(msg.sender == _payeeAddress, "Only the payee can call this function");
        _;
    }

    /**
     * @dev Constructor to set the initial payer and token address.
   * @param _payer Address of the payer.
   * @param _tokenAddress Address of the ERC20 token.
   */
    constructor(address _payer, address _tokenAddress) {
        payer = _payer;
        tokenAddress = _tokenAddress;
    }

    /**
     * @dev Function to add a new payee.
   * @param _payeeAddress Address of the new payee.
   */
    function addPayee(address payable _payeeAddress) public onlyPayer {
        require(payees[_payeeAddress].payeeAddress == address(0), "Payee already exists");
        payees[_payeeAddress] = Payee(_payeeAddress, 0);
        emit PayeeAdded(_payeeAddress);
    }

    /**
     * @dev Function to add a new task.
   * @param _taskId Unique identifier for the task.
   * @param _amount Amount allocated for the task.
   * @param _payeeAddress Address of the payee for the task.
   */
    function addTask(uint256 _taskId, uint256 _amount, address _payeeAddress) public onlyPayer {
        require(tasks[_taskId].id == 0, "Task ID already exists");
        require(payees[_payeeAddress].payeeAddress != address(0), "Payee does not exist");
        require(_amount > 0, "Amount should be greater than 0");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Transfer of tokens failed");

        tasks[_taskId] = Task(_taskId, _amount, _payeeAddress, TaskStatus.Pending);
        emit TaskAdded(_taskId, _payeeAddress, _amount);
    }

    /**
     * @dev Function for the payer to approve a task.
   * @param _taskId Unique identifier for the task.
   * @param _payeeAddress Address of the payee for the task.
   */
    function approveTask(uint256 _taskId, address _payeeAddress) public onlyPayer {
        require(tasks[_taskId].id != 0, "Task ID does not exist");
        require(tasks[_taskId].payeeAddress == _payeeAddress, "Payee address mismatch");
        require(tasks[_taskId].status == TaskStatus.Pending, "Task is not in a pending state");
        require(tasks[_taskId].status != TaskStatus.Disputed, "Task is currently under dispute");

        payees[_payeeAddress].balance += tasks[_taskId].amount;
        tasks[_taskId].status = TaskStatus.Approved;
        emit TaskApproved(_taskId, _payeeAddress);
    }

    /**
     * @dev Function for the payee to reject a task.
   * @param _taskId Unique identifier for the task.
   */
    function rejectTask(uint256 _taskId) public onlyPayee(msg.sender) {
        require(tasks[_taskId].id != 0, "Task ID does not exist");
        require(tasks[_taskId].status == TaskStatus.Pending, "Task is not in a pending state");
        require(tasks[_taskId].status != TaskStatus.Disputed, "Task is currently under dispute");

        tasks[_taskId].status = TaskStatus.Rejected;
        unallocatedFunds += tasks[_taskId].amount;
        emit TaskRejected(_taskId, msg.sender);
    }

    /**
     * @dev Function for the payer to withdraw unallocated funds.
   * @param _amount Amount to withdraw.
   */
    function withdrawUnallocatedFunds(uint256 _amount) public nonReentrant onlyPayer {
        require(unallocatedFunds >= _amount, "Insufficient balance");

        unallocatedFunds -= _amount;
        IERC20(tokenAddress).transfer(payer, _amount);
        emit PayerFundsRetrieved(payer, _amount);
    }

    /**
     * @dev Function for the payee to withdraw their funds.
   * @param _amount Amount to withdraw.
   */
    function withdrawFunds(uint256 _amount) public nonReentrant onlyPayee(msg.sender) {
        require(payees[msg.sender].balance >= _amount, "Insufficient balance");

        payees[msg.sender].balance -= _amount;
        IERC20(tokenAddress).transfer(msg.sender, _amount);
        emit FundsWithdrawn(msg.sender, _amount);
    }

    /**
     * @dev Function to propose an update to a task's amount.
   * @param _taskId Unique identifier for the task.
   * @param _newAmount Proposed new amount for the task.
   */
    function proposeTaskUpdate(uint256 _taskId, uint256 _newAmount) public nonReentrant {
        require(tasks[_taskId].id != 0, "Task ID does not exist");
        require(tasks[_taskId].status == TaskStatus.Pending, "Task is not in a pending state");
        require(_newAmount > 0 && _newAmount != tasks[_taskId].amount, "New amount should be greater than 0 and different from the current amount");
        require(msg.sender == payer || msg.sender == tasks[_taskId].payeeAddress, "Only payer or payee can propose an update");
        require(updateRequests[_taskId].newAmount == 0, "Update for this task is already proposed");

        updateRequests[_taskId] = TaskUpdateRequest({
        newAmount: _newAmount,
        payerApproved: msg.sender == payer,
        payeeApproved: msg.sender == tasks[_taskId].payeeAddress
        });

        emit TaskUpdateProposed(_taskId, _newAmount, msg.sender);
    }

    /**
     * @dev Function to approve a proposed task update.
   * @param _taskId Unique identifier for the task.
   */
    function approveTaskUpdate(uint256 _taskId) public nonReentrant {
        require(tasks[_taskId].id != 0, "Task ID does not exist");
        require(tasks[_taskId].status == TaskStatus.Pending, "Task is not in a pending state");
        require(msg.sender == payer || msg.sender == tasks[_taskId].payeeAddress, "Only payer or payee can approve an update");
        require(updateRequests[_taskId].newAmount != 0, "No update proposed for this task");

        if(msg.sender == payer) {
            require(!updateRequests[_taskId].payerApproved, "Payer has already approved this update");
            updateRequests[_taskId].payerApproved = true;
        } else {
            require(!updateRequests[_taskId].payeeApproved, "Payee has already approved this update");
            updateRequests[_taskId].payeeApproved = true;
        }

        emit TaskUpdateApproved(_taskId, updateRequests[_taskId].newAmount, msg.sender);

        // If both parties have approved, apply the update
        if(updateRequests[_taskId].payerApproved && updateRequests[_taskId].payeeApproved) {
            tasks[_taskId].amount = updateRequests[_taskId].newAmount;
            // Set the update request's newAmount to its default value (0) instead of using delete
            updateRequests[_taskId].newAmount = 0;
        }
    }
}
