// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// 导入 OpenZeppelin 提供的 ERC20 标准合约
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TokenBank {
    // 存储每个地址的 Token 余额
    mapping(address => mapping(address => uint256)) public balances;

    // Token 合约地址
    address public tokenAddress;

    // 初始化时设置 Token 合约地址
    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    // 存入 Token
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // 从用户地址转移 Token 到合约地址
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        // 更新用户的余额
        balances[tokenAddress][msg.sender] += amount;
    }

    // 提取 Token
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[tokenAddress][msg.sender] >= amount, "Insufficient balance");

        // 更新用户的余额
        balances[tokenAddress][msg.sender] -= amount;

        // 从合约地址转移 Token 到用户地址
        bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

}