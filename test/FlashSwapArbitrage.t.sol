// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FlashSwap/flashToken.sol";
import "../src/FlashSwap/MockUniswap.sol";
import "../src/FlashSwap/FlashSwapArbitrage.sol";

contract FlashSwapArbitrageTest is Test {
    // 代币
    MyToken public tokenA;
    MyToken public tokenB;
    MyToken public tokenC; // 添加第三个代币用于第二个池子

    // Uniswap 合约
    MockUniswapV2Factory public factory;
    MockUniswapV2Pair public poolA;
    MockUniswapV2Pair public poolB;

    // 套利合约
    FlashSwapArbitrage public arbitrage;

    // 测试账户
    address public owner = address(this);
    address public profitReceiver = address(0x123);

    // 初始设置
    function setUp() public {
        // 部署三个 ERC20 代币
        tokenA = new MyToken("Token A", "TKA", 1000000 ether);
        tokenB = new MyToken("Token B", "TKB", 1000000 ether);
        tokenC = new MyToken("Token C", "TKC", 1000000 ether); // 新增代币C

        // 部署 Uniswap Factory
        factory = new MockUniswapV2Factory();

        // 创建 PoolA (TokenA/TokenB) 和 PoolB (TokenA/TokenC)
        address poolAAddress = factory.createPair(address(tokenA), address(tokenB));
        address poolBAddress = factory.createPair(address(tokenA), address(tokenC));

        // 转换为 MockUniswapV2Pair 类型
        poolA = MockUniswapV2Pair(poolAAddress);
        poolB = MockUniswapV2Pair(poolBAddress);

        // 向 PoolA 添加流动性 - 价格比例为 1:1
        tokenA.transfer(address(poolA), 100 ether);
        tokenB.transfer(address(poolA), 100 ether);
        poolA.sync();

        // 向 PoolB 添加流动性 - 价格比例为 1:1.1 (创造套利机会)
        tokenA.transfer(address(poolB), 100 ether);
        tokenC.transfer(address(poolB), 110 ether);
        poolB.sync();

        // 部署套利合约
        arbitrage = new FlashSwapArbitrage(
            address(factory),
            address(poolA),
            address(poolB),
            profitReceiver
        );

        // 确认池子有足够的流动性
        (uint112 reserve0A, uint112 reserve1A, ) = poolA.getReserves();
        (uint112 reserve0B, uint112 reserve1B, ) = poolB.getReserves();
        
        console.log("PoolA reserves - TokenA: %s, TokenB: %s", reserve0A, reserve1A);
        console.log("PoolB reserves - TokenA: %s, TokenC: %s", reserve0B, reserve1B);
    }

    // 测试套利
    function testArbitrage() public {
        // 记录套利前的余额
        uint256 receiverBalanceTokenABefore = tokenA.balanceOf(profitReceiver);
        uint256 receiverBalanceTokenBBefore = tokenB.balanceOf(profitReceiver);
        uint256 receiverBalanceTokenCBefore = tokenC.balanceOf(profitReceiver);

        console.log("Profit receiver balance before - TokenA: %s, TokenB: %s, TokenC: %s", 
                   receiverBalanceTokenABefore, receiverBalanceTokenBBefore, receiverBalanceTokenCBefore);

        // 执行套利 - 从 PoolA 借 TokenA，在 PoolB 兑换为 TokenC，然后再兑换回 TokenB
        address token0 = poolA.token0();

        uint256 borrowAmount = 10 ether;

        if (token0 == address(tokenA)) {
            arbitrage.startArbitrage(
                address(tokenA),
                borrowAmount,
                borrowAmount,
                0
            );
        } else {
            arbitrage.startArbitrage(
                address(tokenA),
                borrowAmount,
                0,
                borrowAmount
            );
        }

        // 记录套利后的余额
        uint256 receiverBalanceTokenAAfter = tokenA.balanceOf(profitReceiver);
        uint256 receiverBalanceTokenBAfter = tokenB.balanceOf(profitReceiver);
        uint256 receiverBalanceTokenCAfter = tokenC.balanceOf(profitReceiver);

        console.log("Profit receiver balance after - TokenA: %s, TokenB: %s, TokenC: %s", 
                   receiverBalanceTokenAAfter, receiverBalanceTokenBAfter, receiverBalanceTokenCAfter);

        // 计算利润
        uint256 profitTokenA = receiverBalanceTokenAAfter - receiverBalanceTokenABefore;
        uint256 profitTokenB = receiverBalanceTokenBAfter - receiverBalanceTokenBBefore;
        uint256 profitTokenC = receiverBalanceTokenCAfter - receiverBalanceTokenCBefore;

        console.log("Arbitrage profit - TokenA: %s, TokenB: %s, TokenC: %s", 
                   profitTokenA, profitTokenB, profitTokenC);
        
        // 验证套利是否成功
        assertTrue(profitTokenA > 0 || profitTokenB > 0 || profitTokenC > 0, "Arbitrage should generate profit");
    }

    // 测试不同借款金额对套利的影响
    function testDifferentBorrowAmounts() public {
        // 测试不同的借款金额
        uint256[] memory borrowAmounts = new uint256[](3);
        borrowAmounts[0] = 5 ether;
        borrowAmounts[1] = 10 ether;
        borrowAmounts[2] = 20 ether;

        address token0 = poolA.token0();
        bool isTokenAToken0 = token0 == address(tokenA);

        for (uint i = 0; i < borrowAmounts.length; i++) {
            // 重置收益接收者余额
            vm.prank(profitReceiver);
            if (tokenA.balanceOf(profitReceiver) > 0) {
                tokenA.transfer(address(0), tokenA.balanceOf(profitReceiver));
            }
            if (tokenB.balanceOf(profitReceiver) > 0) {
                tokenB.transfer(address(0), tokenB.balanceOf(profitReceiver));
            }
            if (tokenC.balanceOf(profitReceiver) > 0) {
                tokenC.transfer(address(0), tokenC.balanceOf(profitReceiver));
            }

            uint256 borrowAmount = borrowAmounts[i];
            console.log("\nTesting borrow amount: %s", borrowAmount);

            if (isTokenAToken0) {
                arbitrage.startArbitrage(
                    address(tokenA),
                    borrowAmount,
                    borrowAmount,
                    0
                );
            } else {
                arbitrage.startArbitrage(
                    address(tokenA),
                    borrowAmount,
                    0,
                    borrowAmount
                );
            }

            uint256 profitTokenA = tokenA.balanceOf(profitReceiver);
            uint256 profitTokenB = tokenB.balanceOf(profitReceiver);
            uint256 profitTokenC = tokenC.balanceOf(profitReceiver);

            console.log("Borrow amount %s - Profit: TokenA: %s, TokenB: %s, TokenC: %s",
                profitTokenA, profitTokenB, profitTokenC);

        }
    }
}