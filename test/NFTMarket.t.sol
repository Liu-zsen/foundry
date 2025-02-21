// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarket/NFTMarket.sol";
import "../src/tokenBank/ERC20WithCallback.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// 创建一个简单的 NFT 合约用于测试
contract TestNFT is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract NFTMarketTest is Test {
    NFTMarket public market;
    ERC20WithCallback public token;
    TestNFT public nft;
    
    address public seller = address(1);
    address public buyer = address(2);
    uint256 public constant TOKEN_AMOUNT = 1000 ether;
    uint256 public constant NFT_ID = 1;
    uint256 public constant PRICE = 100 ether;

    // 初始化测试环境
    function setUp() public {
        // 部署合约
        token = new ERC20WithCallback(1000000 * 10**18); // 铸造 1000000 个代币
        nft = new TestNFT();
        market = new NFTMarket(address(token), address(nft));

        // 为测试账户铸造代币和 NFT
        token.mint(buyer, TOKEN_AMOUNT);
        nft.mint(seller, NFT_ID);

        // 模拟seller和buyer的操作
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        vm.stopPrank();

        vm.startPrank(buyer);
        token.approve(address(market), TOKEN_AMOUNT);
        vm.stopPrank();
    }

// 测试 NFT 上架功能
    function testList() public {
        vm.startPrank(seller);
        market.list(NFT_ID, PRICE);
        
        (uint256 listedPrice, address listedSeller, , ) = market.listings(NFT_ID);
        assertEq(listedPrice, PRICE);
        assertEq(listedSeller, seller);
        vm.stopPrank();
    }

// 测试非 NFT 所有者无法上架
    function testListFailNotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert("Not the owner");
        market.list(NFT_ID, PRICE);
        vm.stopPrank();
    }

// 测试常规购买 NFT 功能
    function testBuyNFT() public {
        // 首先上架 NFT
        vm.prank(seller);
        market.list(NFT_ID, PRICE);

        // 买家购买 NFT
        vm.startPrank(buyer);
        market.buyNFT(NFT_ID);

        // 验证 NFT 所有权已转移
        assertEq(nft.ownerOf(NFT_ID), buyer);
        // 验证代币已转移
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), TOKEN_AMOUNT - PRICE);
        // 验证上架信息已删除
        (uint256 listedPrice, address listedSeller, , ) = market.listings(NFT_ID);
        assertEq(listedPrice, 0);
        assertEq(listedSeller, address(0));
        vm.stopPrank();
    }
// 测试通过 token 回调函数购买 NFT
    function testTokensReceived() public {
        // 首先上架 NFT
        vm.prank(seller);
        market.list(NFT_ID, PRICE);

        // 准备购买数据
        // bytes memory data = abi.encode(NFT_ID);

        // 买家通过 token 转账购买 NFT
        vm.startPrank(buyer);
        token.transferWithCallback(address(market), PRICE, abi.encode(NFT_ID));

        // 验证 NFT 所有权已转移
        assertEq(nft.ownerOf(NFT_ID), buyer);
        // 验证代币已转移
        assertEq(token.balanceOf(seller), PRICE);
        assertEq(token.balanceOf(buyer), TOKEN_AMOUNT - PRICE);
        vm.stopPrank();
    }
// 测试支付金额不足的情况
    function test_RevertInsufficientPayment() public {
        // 首先上架 NFT
        vm.prank(seller);
        market.list(NFT_ID, PRICE);

        // 尝试用更少的代币购买
        vm.startPrank(buyer);

        // 确保使用正确的 revert 消息  
        // 确保这个消息与合约中的实际错误消息匹配
        vm.expectRevert(bytes("Insufficient payment"));
        
        token.transferWithCallback(address(market), PRICE - 1 ether, abi.encode(NFT_ID));
        vm.stopPrank();
    }
    // 模糊测试
    function testFuzz_ListAndBuyNFT(uint256 price, address randomBuyer) public {
        // 约束价格范围在 0.01-10000 Token之间
        price = bound(price, 0.01 ether, 10000 ether);
        
        // 约束随机地址不能为零地址或已使用的地址
        vm.assume(randomBuyer != address(0));
        vm.assume(randomBuyer != seller);
        vm.assume(randomBuyer != address(market));
        vm.assume(randomBuyer != address(token));
        vm.assume(randomBuyer != address(nft));

        // 给随机买家铸造足够的代币
        token.mint(randomBuyer, price * 2); // 铸造2倍价格的代币，确保足够支付

        // 设置买家授权
        vm.startPrank(randomBuyer);
        token.approve(address(market), type(uint256).max);
        vm.stopPrank();

        uint256 tokenId = NFT_ID; // 使用第一个NFT
        uint256 buyerInitialBalance = token.balanceOf(randomBuyer);

        // 卖家上架NFT
        vm.startPrank(seller);
        market.list(tokenId, price);
        vm.stopPrank();

        // 验证上架信息
        (uint256 listedPrice, address listedSeller, , ) = market.listings(tokenId);
        assertEq(listedPrice, price);
        assertEq(listedSeller, seller);

        // 随机买家购买NFT
        vm.startPrank(randomBuyer);
        market.buyNFT(tokenId);
        vm.stopPrank();

        // 验证NFT所有权转移
        assertEq(nft.ownerOf(tokenId), randomBuyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(randomBuyer), buyerInitialBalance - price);

        // 验证上架信息已被清除
        (uint256 newListedPrice, address newListedSeller, , ) = market.listings(tokenId);
        assertEq(newListedPrice, 0);
        assertEq(newListedSeller, address(0));
    }
}