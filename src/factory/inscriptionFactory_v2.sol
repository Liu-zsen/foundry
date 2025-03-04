// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

// V2的InscriptionToken实现
contract InscriptionTokenV2 is ERC20 {
    uint256 public perMint;
    uint256 public maxSupply;
    uint256 public mintedSupply;
    uint256 public price;
    address public factory;
    bool public initialized;

    constructor() ERC20("", "") {
        // 构造函数仅用于模板合约，代理实例不会执行此逻辑
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _maxSupply,
        uint256 _perMint,
        uint256 _price
    ) external {
        require(!initialized, "Already initialized");
        factory = msg.sender; // 设置 factory 为调用者（即工厂合约）
        initialized = true;
        _name = name_;
        _symbol = symbol_;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
    }

    function mint(address to) external payable returns (bool) {
        require(msg.sender == factory, "Only factory can mint");
        require(mintedSupply + perMint <= maxSupply, "Exceeds max supply");
        mintedSupply += perMint;
        _mint(to, perMint);
        return true;
    }

    string private _name;
    string private _symbol;

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
// 工厂合约 V2
contract InscriptionFactoryV2 {
    event InscriptionDeployed(address indexed tokenAddr, string symbol);
    
    address public immutable implementation;
    mapping(address => bool) public isInscription;

    constructor() {
        implementation = address(new InscriptionTokenV2());
    }

    function deployInscription(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        address proxy = Clones.clone(implementation);
        InscriptionTokenV2(proxy).initialize(name, symbol, totalSupply, perMint, price);
        isInscription[proxy] = true;
        emit InscriptionDeployed(proxy, symbol);
        return proxy;
    }

    function mintInscription(address tokenAddr) external payable {
        require(isInscription[tokenAddr], "Not a valid inscription");
        uint256 price = InscriptionTokenV2(tokenAddr).price();
        uint256 requiredPayment = price * InscriptionTokenV2(tokenAddr).perMint();
        require(msg.value >= requiredPayment, "Insufficient payment");
        
        InscriptionTokenV2(tokenAddr).mint(msg.sender);
        
        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}