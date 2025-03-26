// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/FlashSwap/FlashSwapArbitrage.sol";
import "../src/FlashSwap/MockUniswap.sol";
import "../src/FlashSwap/flashToken.sol";

contract DeployFlashSwapArbitrage is Script {
    // Initial parameters
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether; // Initial supply for each token
    uint256 constant POOL_A_LIQUIDITY_A = 100 ether;   // Initial TokenA liquidity in PoolA
    uint256 constant POOL_A_LIQUIDITY_B = 200 ether;   // Initial TokenB liquidity in PoolA
    uint256 constant POOL_B_LIQUIDITY_A = 100 ether;   // Initial TokenA liquidity in PoolB
    uint256 constant POOL_B_LIQUIDITY_C = 150 ether;   // Initial TokenC liquidity in PoolB
    
    function run() public {
        // Get private key for deployment
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
        console.log("Deploying contracts from address:", deployer);
        
        vm.startBroadcast(privateKey);
        
        // 1. Deploy ERC20 tokens
        MyToken tokenA = new MyToken("Token A", "TKA", INITIAL_SUPPLY);
        MyToken tokenB = new MyToken("Token B", "TKB", INITIAL_SUPPLY);
        MyToken tokenC = new MyToken("Token C", "TKC", INITIAL_SUPPLY);
        
        console.log("Deployed Token A at:", address(tokenA));
        console.log("Deployed Token B at:", address(tokenB));
        console.log("Deployed Token C at:", address(tokenC));
        
        // 2. Deploy Uniswap factory
        MockUniswapV2Factory factory = new MockUniswapV2Factory();
        console.log("Deployed Uniswap Factory at:", address(factory));
        
        // 3. Create trading pairs
        address pairAAddress = factory.createPair(address(tokenA), address(tokenB));
        address pairBAddress = factory.createPair(address(tokenA), address(tokenC));
        
        MockUniswapV2Pair poolA = MockUniswapV2Pair(pairAAddress);
        MockUniswapV2Pair poolB = MockUniswapV2Pair(pairBAddress);
        
        console.log("Deployed Pool A at:", address(poolA));
        console.log("Deployed Pool B at:", address(poolB));
        
        // 4. Add liquidity to pools
        // PoolA: Price ratio 1 TKA = 2 TKB
        tokenA.transfer(address(poolA), POOL_A_LIQUIDITY_A);
        tokenB.transfer(address(poolA), POOL_A_LIQUIDITY_B);
        poolA.sync();
        
        // PoolB: Price ratio 1 TKA = 1.5 TKC (different price creates arbitrage opportunity)
        tokenA.transfer(address(poolB), POOL_B_LIQUIDITY_A);
        tokenC.transfer(address(poolB), POOL_B_LIQUIDITY_C);
        poolB.sync();
        
        console.log("Added liquidity to pools");
        
        // 给部署者（作为profit receiver）一些代币用于闪电贷还款
        tokenA.transfer(deployer, 50 ether);
        tokenB.transfer(deployer, 50 ether);
        tokenC.transfer(deployer, 50 ether);
        
        // 5. Deploy FlashSwapArbitrage contract
        FlashSwapArbitrage arbitrage = new FlashSwapArbitrage(
            address(factory),
            address(poolA),
            address(poolB),
            deployer  // Set deployer as profit receiver
        );
        
        // 授权arbitrage合约从deployer转移代币
        tokenB.approve(address(arbitrage), 100 ether);
        
        console.log("Deployed FlashSwapArbitrage at:", address(arbitrage));
        
        // Print initial reserves for verification
        {
            (uint112 reserve0A, uint112 reserve1A, ) = poolA.getReserves();
            console.log("Pool A reserves - TokenA:", reserve0A, "TokenB:", reserve1A);
            
            (uint112 reserve0B, uint112 reserve1B, ) = poolB.getReserves();
            console.log("Pool B reserves - TokenA:", reserve0B, "TokenC:", reserve1B);
        }
        
        vm.stopBroadcast();
        
        // Output instructions for executing the flash swap
        console.log("===========================================================");
        console.log("Deployment completed! To execute a flash swap arbitrage:");
        console.log("1. Get the token order from each pool");
        console.log("2. Call arbitrage.startArbitrage() with appropriate parameters");
        console.log("Example:");
        console.log("arbitrage.startArbitrage(address(tokenA), 10 ether, <amount0Out>, <amount1Out>)");
        console.log("===========================================================");
    }
} 