// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract MyDex {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable router;
    address public immutable WETH;

    constructor(address _factory, address _router, address _WETH) {
        factory = _factory;
        router = _router;
        WETH = _WETH;
    }

    // 创建交易对
    function createPair(address tokenA) external returns (address pair) {
        pair = IUniswapV2Factory(factory).createPair(tokenA, WETH);
    }

    // 添加流动性 ETH
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountTokenDesired);
        IERC20(token).forceApprove(router, amountTokenDesired);
        
        (amountToken, amountETH, liquidity) = IUniswapV2Router02(router).addLiquidityETH{value: msg.value}(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
        
        // 如果有剩余token，返还给用户
        if (amountToken < amountTokenDesired) {
            IERC20(token).safeTransfer(msg.sender, amountTokenDesired - amountToken);
        }
    }

    // 移除流动性 ETH
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        address pair = IUniswapV2Factory(factory).getPair(token, WETH);
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity);
        IERC20(pair).forceApprove(router, liquidity);
        
        return IUniswapV2Router02(router).removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // 使用token兑换ETH
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).forceApprove(router, amountIn);
        
        return IUniswapV2Router02(router).swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    // 使用ETH兑换token
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        return IUniswapV2Router02(router).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    // 获取交易对地址
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return IUniswapV2Factory(factory).getPair(tokenA, tokenB);
    }

    receive() external payable {}
} 