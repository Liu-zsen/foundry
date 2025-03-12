// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// sepolia: 0x17688ebea116f0ccdd068bf45e248777bc895900
contract NFTMarket is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address public tokenAddress;

    address public nftAddress;

    // 签名者地址/项目方地址
    address public signerAddress;

    uint256 private nonce;

    // 上架的 NFT 信息
    struct Listing {
        uint256 price; 
        address seller;
    }

    // 记录每个上架的 NFT 信息
    mapping(uint256 => Listing) public listings;

    // 记录已使用的签名，防止重复使用
    mapping(bytes => bool) public usedSignatures;
    

    // 事件：NFT 上架
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    // 事件：NFT 购买
    event Bought(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // 替换构造函数为初始化函数
    function initialize(address _tokenAddress, address _nftAddress, address _signerAddress) public initializer {
        __ERC721_init("NFTMarket", "NFTM");
        __Ownable_init(msg.sender);
        tokenAddress = _tokenAddress;
        nftAddress = _nftAddress;
        signerAddress = _signerAddress;
    }

    // 离线签名上架 NFT
    function listWithSignature(uint256 tokenId, uint256 price, bytes memory signature) external {
        // 验证签名
        require(verifySignature(tokenId, price, signature), "Invalid signature");
        // 标记签名已使用
        usedSignatures[signature] = true;

        // 检查调用者是否是 NFT 的所有者
        require(IERC721(nftAddress).isApprovedForAll(msg.sender, address(this)), "Marketplace not approved");
        require(price > 0, "Price must be greater than 0");
        require(listings[tokenId].seller == address(0), "NFT already listed");

        // 记录上架信息
        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        emit Listed(tokenId, msg.sender, price);
    }

    // 购买 NFT
    function buyNFT(uint256 tokenId) public {
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
        emit Bought(tokenId, msg.sender, listing.seller, listing.price);
    }

    // 实现 ERC20 扩展 Token 的接收者方法
    function tokensReceived(address sender, uint256 amount, bytes memory data) external returns (bool) {
        // 检查调用者是否是 ERC20 Token 合约
        require(msg.sender == tokenAddress, "Invalid token");

        uint256 tokenId = abi.decode(data, (uint256));
        require(listings[tokenId].seller != address(0), "NFT not listed");
        // 获取上架信息
        Listing memory listing = listings[tokenId];

        // 检查支付的 Token 数量是否足够
        require(amount >= listing.price, "Insufficient payment");
        // 转移 NFT 给买家
        IERC721(nftAddress).safeTransferFrom(listing.seller, sender, tokenId);

        delete listings[tokenId];
        emit Bought(tokenId, sender, listing.seller, listing.price);

        return true;
    }

    // 白名单用户购买NFT的函数
    function permitBuy(uint256 tokenId, bytes memory signature) external {
        Listing memory listing = listings[tokenId];
        require(verifySignature(tokenId, listing.price, signature), "Invalid signature");
        // 标记签名已使用
        usedSignatures[signature] = true;
        buyNFT(tokenId);
    }

    //验证签名
    function verifySignature(
        uint256 tokenId,
        uint256 price,
        bytes memory signature
    ) public returns (bool) {
        // 1. 检查签名是否已经被使用
        if (usedSignatures[signature]) return false;
        // 检查签名者是否是签名者地址
        // 构建消息哈希
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId,price,nonce));
        // 2. 添加以太坊签名前缀
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        nonce++;
        // 3. 从签名中恢复地址
        address recoveredSigner = recoverSigner(ethSignedMessageHash, signature);
        // 4. 验证恢复的地址是否为授权签名者
        return recoveredSigner == signerAddress;
    }

    // 从签名中恢复签名者地址
    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature 'v' value");
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    // 修改函数名从 nonce 到 getNonce
    function getNonce() external view returns (uint256) {
        return nonce;
    }

    // 取消上架
    function cancelListing(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not the seller");
        delete listings[tokenId];
    }

    // 更新合约地址（仅管理员）
    function updateAddresses(address _tokenAddress, address _nftAddress) external onlyOwner {
        require(_tokenAddress != address(0) && _nftAddress != address(0), "Invalid address");
        tokenAddress = _tokenAddress;
        nftAddress = _nftAddress;
    }

    // 更新签名者地址（仅管理员）
    function updateSignerAddress(address _signerAddress) external onlyOwner {
        require(_signerAddress != address(0), "Invalid address");
        signerAddress = _signerAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}