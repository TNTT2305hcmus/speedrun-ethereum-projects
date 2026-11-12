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
    error InsufficientLiquidity(uint256 available, uint256 required);

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
    event LiquidityProvided(address liquidityProvider, uint256 liquidityMinted, uint256 ethInput, uint256 tokensInput);
    event LiquidityRemoved(address liquidityRemover, uint256 liquidityWithdrawn, uint256 tokensOutput, uint256 ethOutput);

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

    // Checkpoint 5
    /**
     * @notice Thêm thanh khoản bằng ETH và BAL theo tỷ lệ hiện tại của pool đã được init.
     * @dev Người dùng gửi ETH qua msg.value và phải approve đủ BAL cho DEX trước khi gọi.
     * Reserve ETH trước khi nạp = balance - msg.value, vì ETH đã vào contract khi hàm chạy.
     * BAL cần nạp = msg.value * tokenReserve / ethReserve + 1; cộng 1 đơn vị nhỏ nhất
     * của BAL để bù phép chia nguyên làm tròn xuống, tránh nạp thiếu token theo tỷ lệ.
     * LP được cấp = msg.value * totalLiquidity / ethReserve, tính theo reserve trước khi nạp.
     * Hàm kiểm tra số dư/allowance, cập nhật LP, thu BAL bằng transferFrom và phát event.
     * @return tokensDeposited Lượng BAL thực tế nạp vào pool, tính theo đơn vị nhỏ nhất.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        if (msg.value == 0) revert InvalidEthAmount();

        // ETH has already arrived, so use the reserve before this deposit.
        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));
        tokensDeposited = (msg.value * tokenReserve / ethReserve) + 1;

        uint256 userBalance = token.balanceOf(msg.sender);
        if (userBalance < tokensDeposited) revert InsufficientTokenBalance(userBalance, tokensDeposited);
        uint256 userAllowance = token.allowance(msg.sender, address(this));
        if (userAllowance < tokensDeposited) revert InsufficientTokenAllowance(userAllowance, tokensDeposited);

        uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        if (!token.transferFrom(msg.sender, address(this), tokensDeposited)) revert TokenTransferFailed();
        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokensDeposited);
        return tokensDeposited;
    }

    /**
     * @notice Rút thanh khoản bằng cách đổi LP đang sở hữu lấy cả ETH và BAL trong pool.
     * @dev Kiểm tra người gọi có đủ LP, rồi tính tài sản theo tỷ lệ amount / totalLiquidity:
     * ETH nhận = amount * ethReserve / totalLiquidity; BAL nhận tương tự với tokenReserve.
     * Các phép tính dùng reserve và tổng LP trước khi rút, với kết quả làm tròn xuống.
     * Giảm LP của người gọi và tổng LP trước khi chuyển tài sản để không dùng lại số LP đó.
     * Chuyển ETH bằng call, chuyển BAL bằng transfer, kiểm tra kết quả và phát event.
     * @param amount Số LP muốn rút, không phải lượng ETH; dùng đơn vị LP nhỏ nhất.
     * @return ethAmount Lượng ETH nhận được, tính bằng wei.
     * @return tokenAmount Lượng BAL nhận được, tính theo đơn vị nhỏ nhất của token.
     */
    function withdraw(uint256 amount) public returns (uint256 ethAmount, uint256 tokenAmount) {
        uint256 availableLp = liquidity[msg.sender];
        if (availableLp < amount) revert InsufficientLiquidity(availableLp, amount);

        ethAmount = amount * address(this).balance / totalLiquidity;
        tokenAmount = amount * token.balanceOf(address(this)) / totalLiquidity;

        // Burn shares before transferring assets to the caller.
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        (bool sent, ) = msg.sender.call{ value: ethAmount }("");
        if (!sent) revert EthTransferFailed(msg.sender, ethAmount);
        if (!token.transfer(msg.sender, tokenAmount)) revert TokenTransferFailed();

        emit LiquidityRemoved(msg.sender, amount, tokenAmount, ethAmount);
        return (ethAmount, tokenAmount);
    }
}
