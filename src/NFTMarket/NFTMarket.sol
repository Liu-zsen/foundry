// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarket {
    // 扩展的 ERC20 Token 合约地址
    address public tokenAddress;

    // NFT 合约地址
    address public nftAddress;

    // 上架的 NFT 信息
    struct Listing {
        uint256 price; // NFT 的价格（以 ERC20 Token 为单位）
        address seller; // NFT 的卖家
    }

    // 记录每个上架的 NFT 信息
    mapping(uint256 => Listing) public listings;

    // 事件：NFT 上架
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);

    // 事件：NFT 购买
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    // 初始化时设置 ERC20 Token 和 NFT 合约地址
    constructor(address _tokenAddress, address _nftAddress) {
        tokenAddress = _tokenAddress;
        nftAddress = _nftAddress;
    }

    // 上架 NFT
    function list(uint256 tokenId, uint256 price) external {
        // 检查调用者是否是 NFT 的所有者
        require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, "Not the owner");

        // 检查价格是否大于 0
        require(price > 0, "Price must be greater than 0");

        // 检查 NFT 是否已上架
        require(listings[tokenId].seller == address(0), "NFT already listed");

        // 记录上架信息
        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        // 触发上架事件
        emit Listed(tokenId, msg.sender, price);
    }

    // 购买 NFT
    function buyNFT(uint256 tokenId) external {
        // 检查 NFT 是否已上架
        require(listings[tokenId].seller != address(0), "NFT not listed");

        // 获取上架信息
        Listing memory listing = listings[tokenId];

        // 检查调用者是否有足够的 ERC20 Token
        uint256 allowance = IERC20(tokenAddress).allowance(msg.sender, address(this));
        require(allowance >= listing.price, "Insufficient allowance");

        // 转移 ERC20 Token 给卖家
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "Token transfer failed");

        // 转移 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 删除上架信息
        delete listings[tokenId];

        // 触发购买事件
        emit Bought(tokenId, msg.sender, listing.seller, listing.price);
    }

    // 实现 ERC20 扩展 Token 的接收者方法
    function tokensReceived(address sender, uint256 amount, bytes memory data) external returns (bool) {
        // 检查调用者是否是 ERC20 Token 合约
        require(msg.sender == tokenAddress, "Invalid token");

        // 解码 data 获取 tokenId
        uint256 tokenId = abi.decode(data, (uint256));

        // 检查 NFT 是否已上架
        require(listings[tokenId].seller != address(0), "NFT not listed");

        // 获取上架信息
        Listing memory listing = listings[tokenId];

        // 检查支付的 Token 数量是否足够
        require(amount >= listing.price, "Insufficient payment");

        // 转移 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(listing.seller, sender, tokenId);

        // 删除上架信息
        delete listings[tokenId];

        // 触发购买事件
        emit Bought(tokenId, sender, listing.seller, listing.price);

        return true;
    }
}