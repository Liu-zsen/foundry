// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FlashSwap/FlashSwapArbitrage.sol";
import "../src/FlashSwap/MockUniswap.sol";
import "../src/FlashSwap/flashToken.sol";

contract FlashSwapArbitrageTest is Test {
    // Tokens
    MyToken tokenA;
    MyToken tokenB;
    MyToken tokenC;
    
    // Uniswap factory and pairs
    MockUniswapV2Factory factory;
    MockUniswapV2Pair poolA;
    MockUniswapV2Pair poolB;
    
    // Flash swap arbitrage contract
    FlashSwapArbitrage arbitrage;
    
    // Test accounts
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address profitReceiver = makeAddr("profitReceiver");
    
    // Initial test parameters
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether; 
    uint256 constant POOL_A_LIQUIDITY_A = 100 ether;  
    uint256 constant POOL_A_LIQUIDITY_B = 200 ether;
    uint256 constant POOL_B_LIQUIDITY_A = 100 ether;   
    uint256 constant POOL_B_LIQUIDITY_C = 150 ether;
    
    // 存储测试前的余额
    uint256 profitReceiverBalanceA_Before;
    uint256 profitReceiverBalanceB_Before;
    uint256 profitReceiverBalanceC_Before;
    
    function setUp() public {
        // Set account balances
        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        
        // Deploy tokens
        tokenA = new MyToken("Token A", "TKA", INITIAL_SUPPLY);
        tokenB = new MyToken("Token B", "TKB", INITIAL_SUPPLY);
        tokenC = new MyToken("Token C", "TKC", INITIAL_SUPPLY);
        
        // Deploy Uniswap factory
        factory = new MockUniswapV2Factory();
        
        // Create pairs - 使用不同的代币对
        address pairAAddress = factory.createPair(address(tokenA), address(tokenB));
        address pairBAddress = factory.createPair(address(tokenA), address(tokenC)); // 使用TokenA/TokenC创建第二个交易对
        
        poolA = MockUniswapV2Pair(pairAAddress);
        poolB = MockUniswapV2Pair(pairBAddress);
        
        // Add liquidity to pairs
        // PoolA: Price ratio 1 TKA = 2 TKB
        tokenA.transfer(address(poolA), POOL_A_LIQUIDITY_A);
        tokenB.transfer(address(poolA), POOL_A_LIQUIDITY_B);
        poolA.sync();
        
        // PoolB: Price ratio 1 TKA = 1.5 TKC (different price creates arbitrage opportunity)
        tokenA.transfer(address(poolB), POOL_B_LIQUIDITY_A);
        tokenC.transfer(address(poolB), POOL_B_LIQUIDITY_C); // 使用TokenC添加流动性
        poolB.sync();
        
        // 给profit receiver一些代币用于闪电贷还款
        tokenA.transfer(profitReceiver, 50 ether);
        tokenB.transfer(profitReceiver, 50 ether);
        tokenC.transfer(profitReceiver, 50 ether);
        
        // Deploy flash swap arbitrage contract
        arbitrage = new FlashSwapArbitrage(
            address(factory),
            address(poolA),
            address(poolB),
            profitReceiver
        );
        
        // Transfer some tokens to the user for testing
        tokenA.transfer(user, 10 ether);
        tokenB.transfer(user, 10 ether);
        tokenC.transfer(user, 10 ether);
        
        vm.stopPrank();
        
        // 授权arbitrage合约从profit receiver转移代币 - 移到stopPrank之后
        vm.prank(profitReceiver);
        tokenB.approve(address(arbitrage), 100 ether);
    }
    
    // 打印池中的储备量
    function logPoolReserves() internal {
        console.log("PoolA reserves:");
        (uint112 reserveA0, uint112 reserveA1, ) = poolA.getReserves();
        console.log("TokenA:", reserveA0);
        console.log("TokenB:", reserveA1);
        
        console.log("PoolB reserves:");
        (uint112 reserveB0, uint112 reserveB1, ) = poolB.getReserves();
        console.log("TokenA:", reserveB0);
        console.log("TokenC:", reserveB1);
    }
    
    // 计算并打印利润
    function calculateAndLogProfit() internal returns (uint256) {
        uint256 profitReceiverBalanceA_After = tokenA.balanceOf(profitReceiver);
        uint256 profitReceiverBalanceB_After = tokenB.balanceOf(profitReceiver);
        uint256 profitReceiverBalanceC_After = tokenC.balanceOf(profitReceiver);
        
        uint256 profitA = profitReceiverBalanceA_After > profitReceiverBalanceA_Before ? 
                         profitReceiverBalanceA_After - profitReceiverBalanceA_Before : 0;
        uint256 profitB = profitReceiverBalanceB_After > profitReceiverBalanceB_Before ? 
                         profitReceiverBalanceB_After - profitReceiverBalanceB_Before : 0;
        uint256 profitC = profitReceiverBalanceC_After > profitReceiverBalanceC_Before ? 
                         profitReceiverBalanceC_After - profitReceiverBalanceC_Before : 0;
        
        console.log("Profit Receiver earnings:");
        console.log("TokenA:", profitA);
        console.log("TokenB:", profitB);
        console.log("TokenC:", profitC);
        
        return profitA + profitB + profitC;
    }
    
    function testFlashSwapArbitrage() public {
        // Record balances before arbitrage
        profitReceiverBalanceA_Before = tokenA.balanceOf(profitReceiver);
        profitReceiverBalanceB_Before = tokenB.balanceOf(profitReceiver);
        profitReceiverBalanceC_Before = tokenC.balanceOf(profitReceiver);
        
        console.log("Initial state:");
        logPoolReserves();
        
        // Execute flash swap arbitrage
        // Here we borrow 10 TokenA (token0) from PoolA
        uint256 borrowAmount = 10 ether;
        
        // Determine if tokenA is token0 or token1
        address token0 = poolA.token0();
        bool isTokenA_token0 = token0 == address(tokenA);
        
        uint256 amount0Out = isTokenA_token0 ? borrowAmount : 0;
        uint256 amount1Out = isTokenA_token0 ? 0 : borrowAmount;
        
        // Execute arbitrage
        vm.prank(user);
        arbitrage.startArbitrage(
            address(tokenA),
            borrowAmount,
            amount0Out,
            amount1Out
        );
        
        // Calculate and log profits
        uint256 totalProfit = calculateAndLogProfit();
            
        assertTrue(totalProfit > 0, "No profit was made");
        
        console.log("Final state:");
        logPoolReserves();
    }
} 