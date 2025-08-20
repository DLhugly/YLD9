// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract RouterExecutor {
    address public owner;
    uint16 public feeBps; // e.g., 5 = 0.05%
    address public feeRecipient;

    mapping(address => bool) public allowedRouters;
    mapping(address => bool) public allowedTokens;

    error NotAllowed();
    error MinOutNotMet();

    constructor(uint16 _feeBps, address _feeRecipient) {
        owner = msg.sender;
        feeBps = _feeBps;
        feeRecipient = _feeRecipient;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    function setAllowed(address router, bool ok) external onlyOwner {
        allowedRouters[router] = ok;
    }

    function setToken(address token, bool ok) external onlyOwner {
        allowedTokens[token] = ok;
    }

    function setFee(uint16 _bps) external onlyOwner {
        feeBps = _bps;
    }

    function setFeeRecipient(address _r) external onlyOwner {
        feeRecipient = _r;
    }

    /// @notice Executes calldata to an allowlisted router, takes fee on success, enforces minOut.
    function execute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        address router,
        bytes calldata data
    ) external payable {
        if (!allowedRouters[router] || !allowedTokens[tokenIn] || !allowedTokens[tokenOut]) revert NotAllowed();

        // pull funds
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER_FROM_FAIL");
        require(IERC20(tokenIn).approve(router, amountIn), "APPROVE_FAIL");

        // call router
        (bool ok, ) = router.call(data);
        require(ok, "ROUTER_CALL_FAIL");

        // post-swap accounting
        uint256 outBal = IERC20(tokenOut).balanceOf(address(this));
        uint256 fee = (outBal * feeBps) / 10_000;
        uint256 sendAmt = outBal - fee;
        if (sendAmt < minOut) revert MinOutNotMet();

        if (fee > 0) require(IERC20(tokenOut).transfer(feeRecipient, fee), "FEE_TRANSFER_FAIL");
        require(IERC20(tokenOut).transfer(msg.sender, sendAmt), "OUT_TRANSFER_FAIL");
    }
}



