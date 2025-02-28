// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 导入 OpenZeppelin 提供的 ERC20 标准合约

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// 已经部署在sepolia地址: 0x1Cd149D60b15cD3F654f382F5f26D1FeDd225F82
contract TokenBank {
    // 存储每个地址的 Token 余额
    mapping(address => mapping(address => uint256)) public balances;

    event PermitDeposited(address indexed user, address indexed token, uint256 amount);
    // 事件：记录存款和取款操作
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    struct Permit {
        address tokenAddress;
        uint256 amount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // 初始化
    constructor() { }

    // 存入 Token
    function deposit(address tokenAddress,uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(tokenAddress != address(0), "Invalid token address");

        // 从用户地址转移 Token 到合约地址
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        // 更新用户的余额
        balances[msg.sender][tokenAddress] += amount;
        
        emit Deposited(msg.sender, tokenAddress, amount);
    }

    // 提取 Token
    function withdraw(address tokenAddress, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        // 更新用户的余额
        balances[msg.sender][tokenAddress] -= amount;

        // 从合约地址转移 Token 到用户地址
        bool success = IERC20(tokenAddress).transfer(msg.sender, amount);
        require(success, "Transfer failed");
        emit Withdrawn(msg.sender, tokenAddress, amount);
    }

    /**
     * 增加 permit 离线签名授权的存款函数
     *  data:
        *  token：代币地址。
            amount：存款数量。
            deadline：签名有效截止时间。
            v, r, s：离线签名的组成部分。
     */
    function permitDeposit(Permit calldata data) external {
        require(data.amount > 0, "Amount must be greater than 0");
        require(data.tokenAddress != address(0), "Invalid token address");

        // permit 使用离线签名授权 TokenBank 转移代币 
        IERC20Permit(data.tokenAddress).permit(msg.sender, address(this), data.amount, data.deadline, data.v, data.r, data.s);
        IERC20 token = IERC20(data.tokenAddress);
        // 从调用者转移代币到合约
        require(token.transferFrom(msg.sender, address(this), data.amount), "Transfer failed");
        // 更新用户在该代币中的余额
        balances[msg.sender][data.tokenAddress] += data.amount;
        emit PermitDeposited(msg.sender, data.tokenAddress, data.amount);
    }

    function tokensReceived(address sender,address tokenAddress, uint256 amount) external returns (bool) {
        require(msg.sender == address(tokenAddress),"Invaild Token");
        // 记录用户的存款
        balances[sender][tokenAddress] += amount;
        return true;
    }

    // 获取用户的 Token 余额
    function getBalance(address user, address tokenAddress) external view returns (uint256) {
        return balances[user][tokenAddress];
    }
}
