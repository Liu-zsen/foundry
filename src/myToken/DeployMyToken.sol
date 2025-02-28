// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title 使用Foundry部署和开源合约
    将下方合约部署到 https://sepolia.etherscan.io/ ，要求如下：
    要求使用你在 Metamask 的钱包来部署合约
    要求贴出编写 forge script 的脚本合约
    并给出部署后的合约链接地址
 * 
 */

contract MyToken is ERC20, ERC20Permit {
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(msg.sender, initialSupply);
    }
}