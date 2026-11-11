// SPDX-License-Identifier: MIT
pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {
    /////////////////
    /// Errors //////
    /////////////////

    error DexAlreadyInitialized();
    error TokenTransferFailed();

    // Checkpoint 4
    error InvalidEthAmount();
    error InvalidTokenAmount();
    error InsufficientTokenBalance(uint256 available, uint256 required);
    error InsufficientTokenAllowance(uint256 available, uint256 required);
    error EthTransferFailed(address to, uint256 amount);

    //////////////////////
    /// State Variables //
    //////////////////////

    IERC20 public immutable token;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    ////////////////
    /// Events /////
    ////////////////

    // Events go here...
    // Checkpoint 4
    event EthToTokenSwap(address swapper, uint256 tokenOutput, uint256 ethInput);
    event TokenToEthSwap(address swapper, uint256 tokensInput, uint256 ethOutput);

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address tokenAddr) {
        token = IERC20(tokenAddr);
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    function init(uint256 tokens) public payable returns (uint256 initialLiquidity) {
        // Pool can only be initialized once.
        if (totalLiquidity != 0) revert DexAlreadyInitialized();

        // ETH arrives before function execution, so balance includes msg.value here.
        initialLiquidity = address(this).balance;
        totalLiquidity = initialLiquidity;
        liquidity[msg.sender] = initialLiquidity;

        if (!token.transferFrom(msg.sender, address(this), tokens)) revert TokenTransferFailed();
        return initialLiquidity;
    }

    function price(uint256 xInput, uint256 xReserves, uint256 yReserves) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput * 997;
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = (xReserves * 1000) + xInputWithFee;
        return numerator / denominator;
    }

    function getLiquidity(address lp) public view returns (uint256 lpLiquidity) {
        return liquidity[lp];
    }

    // Checkpoint 4
    function ethToToken() public payable returns (uint256 tokenOutput) {
        // Your code here...
        if (msg.value == 0) revert InvalidEthAmount();

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));

        tokenOutput = price(msg.value, ethReserve, tokenReserve);

        if (!token.transfer(msg.sender, tokenOutput)) revert TokenTransferFailed();
        
        emit EthToTokenSwap(msg.sender, tokenOutput, msg.value);
        return tokenOutput;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        // Your code here...
        if (tokenInput == 0) revert InvalidTokenAmount();

        uint256 userBalance = token.balanceOf(msg.sender);
        if (userBalance < tokenInput) revert InsufficientTokenBalance(userBalance, tokenInput);

        uint256 userAllowance = token.allowance(msg.sender, address(this));
        if (userAllowance < tokenInput) revert InsufficientTokenAllowance(userAllowance, tokenInput);


        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        ethOutput = price(tokenInput, tokenReserve, ethReserve);

        if (!token.transferFrom(msg.sender, address(this), tokenInput)) revert TokenTransferFailed();

        (bool sent, ) = msg.sender.call{ value: ethOutput }("");
        if (!sent) revert EthTransferFailed(msg.sender, ethOutput);

        emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
        return ethOutput;
    }

    function deposit() public payable returns (uint256 tokensDeposited) {
        // Your code here...
    }

    function withdraw(uint256 amount) public returns (uint256 ethAmount, uint256 tokenAmount) {
        // Your code here...
    }
}
