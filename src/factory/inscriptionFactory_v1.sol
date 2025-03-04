// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 简单ERC20实现
contract InscriptionToken is ERC20 {
    uint256 public perMint;
    uint256 public maxSupply;
    uint256 public mintedSupply;

    constructor(string memory symbol, uint256 _maxSupply, uint256 _perMint) ERC20(symbol, symbol) {
        perMint = _perMint;
        maxSupply = _maxSupply;
    }

    function mint(address to) external returns (bool) {
        require(mintedSupply + perMint <= maxSupply, "Exceeds max supply");
        mintedSupply += perMint;
        _mint(to, perMint);
        return true;
    }
}

// 工厂合约 V1
contract InscriptionFactoryV1 {
    event InscriptionDeployed(address indexed tokenAddr, string symbol);
    
    mapping(address => bool) public isInscription;

    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address) {
        InscriptionToken token = new InscriptionToken(symbol, totalSupply, perMint);
        isInscription[address(token)] = true;
        emit InscriptionDeployed(address(token), symbol);
        return address(token);
    }

    function mintInscription(address tokenAddr) external {
        require(isInscription[tokenAddr], "Not a valid inscription");
        InscriptionToken(tokenAddr).mint(msg.sender);
    }
}