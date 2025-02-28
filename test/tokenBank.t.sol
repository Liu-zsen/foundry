// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokenBank/tokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenBankTest is Test{
    // 存储每个地址的 Token 余额
    TokenBank public bank;
    TestToken public token;
    address public user;
    
    function setUp() public {
        // 部署测试代币
        token = new TestToken();
        // 部署 TokenBank
        bank = new TokenBank();
        // 设置测试用户
        user = address(0x1);
        
        // 给测试用户转一些代币
        token.transfer(user, 1000 * 10**18);
    }
    // 存款测试
    function test_Deposit() public {
        uint256 depositAmount = 100 * 10**18;
        
        // 切换到用户身份
        vm.startPrank(user);
        
        // 授权 TokenBank 合约使用代币
        token.approve(address(bank), depositAmount);
        
        // 存款
        bank.deposit(address(token),depositAmount);
        
        // 验证余额
        assertEq(bank.balances(address(token), user), depositAmount, "Deposit amount incorrect");
        
        vm.stopPrank();
    }
    // 取款测试
    function test_Withdraw() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 withdrawAmount = 50 * 10**18;
        
        // 先存款
        vm.startPrank(user);
        token.approve(address(bank), depositAmount);
        bank.deposit(address(token),depositAmount);
        
        // 记录提款前的余额
        uint256 balanceBefore = token.balanceOf(user);
        
        // 提款
        bank.withdraw(address(token),withdrawAmount);
        
        // 验证银行中的余额
        assertEq(bank.balances(address(token), user), depositAmount - withdrawAmount, "Bank balance incorrect");
        
        // 验证用户钱包中的余额
        assertEq(token.balanceOf(user), balanceBefore + withdrawAmount, "Wallet balance incorrect");
        
        vm.stopPrank();
    }

    function test_RevertWithdrawInsufficientBalance() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 withdrawAmount = 200 * 10**18;
        
        // 先存款
        vm.startPrank(user);
        token.approve(address(bank), depositAmount);
        bank.deposit(address(token),depositAmount);
        
        // 设置余额不足是的的错误捕获
        vm.expectRevert("Insufficient balance");

        // 尝试提取超过存款金额的代币（应该失败）
        bank.withdraw(address(token),withdrawAmount);
        
        vm.stopPrank();
    }
}

// 创建一个测试用的 ERC20 代币
contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18); // 铸造 1000000 个代币
    }
}