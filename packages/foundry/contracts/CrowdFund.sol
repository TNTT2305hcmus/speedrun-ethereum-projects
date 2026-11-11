// SPDX-License-Identifier: MIT
pragma solidity 0.8.20; // Do not change the solidity version as it negatively impacts submission grading

import "./FundingRecipient.sol";

contract CrowdFund {
    /////////////////
    /// Errors //////
    /////////////////

    // Errors go here...
    
    // Checkpoint 2
    error NotOpenToWithdraw();
    error WithdrawTransferFailed(address to, uint256 amount);

    // Checkpoint 3
    error TooEarly(uint256 deadline, uint256 currentTimestamp);

    // Checkpoint 4
    error AlreadyCompleted();

    //////////////////////
    /// State Variables //
    //////////////////////

    FundingRecipient public fundingRecipient;

    // Checkpoint 1
    mapping(address => uint256) public balances;

    // Checkpoint 2
    bool public openToWithdraw;
    
    // Checkpoint 3
    uint256 public deadline = block.timestamp + 30 seconds; 
    uint256 public constant threshold = 1 ether;

    ////////////////
    /// Events /////
    ////////////////

    // Events go here...
    
    // Checkpoint 1
    event Contribution(address, uint256);

    ///////////////////
    /// Modifiers /////
    ///////////////////

    // Checkpoint 4
    modifier notCompleted() {
        if (fundingRecipient.completed()) revert AlreadyCompleted();
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address fundingRecipientAddress) {
        fundingRecipient = FundingRecipient(fundingRecipientAddress);
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    // Checkpoint 1
    function contribute() public payable notCompleted { 
        balances[msg.sender] += msg.value;
        emit Contribution(msg.sender, msg.value);
    }

    // Checkpoint 2
    function withdraw() public notCompleted {
        if (!openToWithdraw) {
            revert NotOpenToWithdraw();
        }

        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawTransferFailed(msg.sender, amount);
    }

    // Checkpoint 3
    function execute() public notCompleted {
        if (block.timestamp < deadline) {
            revert TooEarly(deadline, block.timestamp);
        }

        if (address(this).balance >= threshold) {
            fundingRecipient.complete{value: address(this).balance}();
        } else {
            openToWithdraw = true;
        }
    }

    // Checkpoint 4
    receive() external payable {
        contribute();
    }

    ////////////////////////
    /// View Functions /////
    ////////////////////////
    
    // Checkpoint 3
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }
}
