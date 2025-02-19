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

    // 获取用户的 Token 余额
    // function getBalance(address user) external view returns (uint256) {
    //     return balances[tokenAddress][user];
    // }
}


// 创建一个新的合约，继承自 OpenZeppelin 的 ERC20 合约
contract MyToken is ERC20 {
    // 构造函数将初始化 ERC20 供应量和代币名称
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        // 通过 _mint 函数铸造初始供应量的代币到部署合约的地址
        _mint(msg.sender, initialSupply);
    }
}