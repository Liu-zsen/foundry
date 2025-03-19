// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDex/MyDex.sol";
import "../src/MyDex/RNTToken.sol";
import "../src/MyDex/WETH9.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyDexTest is Test {
    MyDex public dex;
    RNTToken public rnt;
    WETH9 public weth;
    address public factory;
    address public router;
    address public owner;
    address public user;
    address public pair;

    function setUp() public {
        // 设置测试地址
        owner = address(this);
        user = makeAddr("user");
        pair = makeAddr("pair");
        
        // 部署 WETH
        weth = new WETH9();
        
        // 使用 Sepolia 测试网的地址
        factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        
        // 部署 RNT 代币
        rnt = new RNTToken();
        
        // 部署 MyDex
        dex = new MyDex(
            factory,
            router,
            address(weth)
        );
        
        // 给用户转一些 RNT 和 ETH
        rnt.transfer(user, 10000 * 10**18);
        vm.deal(user, 100 ether);

        // 模拟所有合约调用
        mockContractCalls();
    }

    function mockContractCalls() private {
        // 模拟 createPair
        vm.mockCall(
            factory,
            abi.encodeWithSignature("createPair(address,address)"),
            abi.encode(pair)
        );

        // 模拟 getPair
        vm.mockCall(
            factory,
            abi.encodeWithSignature("getPair(address,address)"),
            abi.encode(pair)
        );

        // 模拟 pair 的 transferFrom
        vm.mockCall(
            pair,
            abi.encodeWithSignature("transferFrom(address,address,uint256)"),
            abi.encode(true)
        );

        // 模拟 pair 的 approve
        vm.mockCall(
            pair,
            abi.encodeWithSignature("approve(address,uint256)"),
            abi.encode(true)
        );

        // 模拟 pair 的 balanceOf
        vm.mockCall(
            pair,
            abi.encodeWithSignature("balanceOf(address)"),
            abi.encode(100 * 10**18)
        );

        // 模拟 Router 的所有调用
        mockRouterCalls();
    }

    function mockRouterCalls() private {
        // 模拟 addLiquidityETH
        vm.mockCall(
            router,
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)"
            ),
            abi.encode(1000 * 10**18, 1 ether, 100 * 10**18)
        );

        // 模拟 removeLiquidityETH
        vm.mockCall(
            router,
            abi.encodeWithSignature(
                "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)"
            ),
            abi.encode(1000 * 10**18, 1 ether)
        );

        // 模拟 swapExactTokensForETH
        uint[] memory amounts = new uint[](2);
        amounts[0] = 100 * 10**18;
        amounts[1] = 1 ether;
        vm.mockCall(
            router,
            abi.encodeWithSignature(
                "swapExactTokensForETH(uint256,uint256,address[],address,uint256)"
            ),
            abi.encode(amounts)
        );

        // 模拟 swapExactETHForTokens
        vm.mockCall(
            router,
            abi.encodeWithSignature(
                "swapExactETHForTokens(uint256,address[],address,uint256)"
            ),
            abi.encode(amounts)
        );
    }

    function testCreatePair() public {
        address newPair = dex.createPair(address(rnt));
        assertEq(newPair, pair);
    }

    function testAddLiquidity() public {
        // 创建交易对
        dex.createPair(address(rnt));
        
        // 授权 DEX 使用 RNT
        vm.startPrank(user);
        rnt.approve(address(dex), 1000 * 10**18);
        
        // 添加流动性
        (uint amountToken, uint amountETH, uint liquidity) = dex.addLiquidityETH{value: 1 ether}(
            address(rnt),
            1000 * 10**18, // 1000 RNT
            1000 * 10**18, // 最小 1000 RNT
            1 ether,       // 最小 1 ETH
            user,
            block.timestamp
        );
        
        vm.stopPrank();
        
        assertEq(amountToken, 1000 * 10**18);
        assertEq(amountETH, 1 ether);
        assertEq(liquidity, 100 * 10**18);
    }

    function testRemoveLiquidity() public {
        // 创建交易对
        dex.createPair(address(rnt));
        
        vm.startPrank(user);
        
        // 移除流动性
        (uint amountToken, uint amountETH) = dex.removeLiquidityETH(
            address(rnt),
            100 * 10**18,
            0, // 最小 token 数量
            0, // 最小 ETH 数量
            user,
            block.timestamp
        );
        
        vm.stopPrank();
        
        assertEq(amountToken, 1000 * 10**18);
        assertEq(amountETH, 1 ether);
    }

    function testSwapExactTokensForETH() public {
        // 创建交易对
        dex.createPair(address(rnt));
        
        vm.startPrank(user);
        // 授权 DEX 使用 RNT
        rnt.approve(address(dex), 100 * 10**18);
        
        address[] memory path = new address[](2);
        path[0] = address(rnt);
        path[1] = address(weth);
        
        // 用 100 RNT 换 ETH
        uint[] memory amounts = dex.swapExactTokensForETH(
            100 * 10**18,
            0, // 最小获得的 ETH 数量
            path,
            user,
            block.timestamp
        );
        
        vm.stopPrank();
        
        assertEq(amounts[0], 100 * 10**18);
        assertEq(amounts[1], 1 ether);
    }

    function testSwapExactETHForTokens() public {
        // 创建交易对
        dex.createPair(address(rnt));
        
        vm.startPrank(user);
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(rnt);
        
        // 用 1 ETH 换 RNT
        uint[] memory amounts = dex.swapExactETHForTokens{value: 1 ether}(
            0, // 最小获得的 RNT 数量
            path,
            user,
            block.timestamp
        );
        
        vm.stopPrank();
        
        assertEq(amounts[0], 100 * 10**18);
        assertEq(amounts[1], 1 ether);
    }

    receive() external payable {}
} 