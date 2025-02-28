// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarket/NFTMarket_v2.sol";
import "../src/myToken/myToken.sol";
import "../src/myToken/myNFT.sol";

contract NFTMarket_v2Test is Test {
    NFTMarket market;
    MyToken token;
    MyNFT nft;
    
    address owner = address(1);
    address buyer = address(2);
    address seller = address(3);
    address signer;
    
    uint256 signerPrivateKey = 0x123456;

    function setUp() public {
        // 从私钥计算对应的地址
        signer = vm.addr(signerPrivateKey);
        
        vm.startPrank(owner);
        token = new MyToken(1000000 * 10**18);
        nft = new MyNFT();
        market = new NFTMarket(address(token), address(nft), signer);
        vm.stopPrank();
    }

    function test_ListNFT() public {
        vm.startPrank(seller);
        
        // 先mint一个NFT给seller 
        // 授权market操作NFT
        uint256 tokenId = nft.mint(seller);
        nft.setApprovalForAll(address(market), true);
        
        uint256 price = 100 * 10**18;
        market.list(tokenId, price);
        
        // 验证上架信息
        (uint256 listedPrice, address listedSeller) = market.listings(tokenId);
        assertEq(listedPrice, price);
        assertEq(listedSeller, seller);
        
        vm.stopPrank();
    }

    function test_BuyNFT() public {
        test_ListNFT();
        
        vm.startPrank(owner);
        token.transfer(buyer, 1000 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        uint256 tokenId = 1;
        uint256 price = 100 * 10**18;
        
        // 授权market使用代币
        token.approve(address(market), price);
        
        market.buyNFT(tokenId);
        
        // 验证购买结果
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        
        vm.stopPrank();
    }

    function test_PermitBuy() public {
        uint256 currentNonce = market.getNonce();
        
        // 生成签名
        bytes32 messageHash = keccak256(abi.encodePacked(buyer, currentNonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        test_ListNFT();
        
        vm.startPrank(owner);
        token.transfer(buyer, 1000 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        uint256 tokenId = 1;
        uint256 price = 100 * 10**18;
        
        token.approve(address(market), price);
        market.permitBuy(tokenId, signature);
        
        // 验证购买结果
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        
        vm.stopPrank();
    }

    function test_RevertInvalidSignature() public {
        test_ListNFT();
        vm.startPrank(buyer);
        uint256 tokenId = 1;
        // 使用错误的签名
        bytes memory invalidSignature = new bytes(65);
        // 这个调用应该失败
        vm.expectRevert("Invalid signature");
        market.permitBuy(tokenId, invalidSignature);
        
        vm.stopPrank();
    }
} 