// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// 已经部署在sepolia地址: 0xa39812b7e716e8B6CbbE018954A0A88C780360fa
// 创建一个新的合约， 继承支持标准 ERC20 和 EIP-2612 的 permit 功能
contract MyToken is ERC20, ERC20Permit {
    // 构造函数将初始化 ERC20 供应量和代币名称
    constructor(uint256 initialSupply) 
        ERC20("MyToken2", "MTK2") 
        ERC20Permit("MyToken2") 
    {
        _mint(msg.sender, initialSupply);
    }
}

