// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public user;

    // 在每个测试之前初始化 Bank 合约和用户地址
    function setUp() public {
        bank = new Bank();
        user = address(0x456); // 假设的用户地址
    }

    // 测试 depositETH 方法
    function testDepositETH() public {
        uint256 depositAmount = 1 ether;
         // 给测试用户一些 ETH
        vm.deal(user, depositAmount);
        
        
        // 记录存款前用户的余额
        uint256 initialBalance = bank.balanceOf(user);

        // 先设置事件期望 断言 Deposit 事件已被触发
        vm.expectEmit(true, true, true, true);
        emit Bank.Deposit(user, depositAmount);

        // 执行存款
        vm.prank(user); // 模拟用户调用
        (bool success, ) = address(bank).call{value: depositAmount}(abi.encodeWithSignature("depositETH()"));
        assertTrue(success, "Deposit should succeed");

        // 断言用户余额更新正确
        uint256 finalBalance = bank.balanceOf(user);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should be updated correctly");

        
    }

}
