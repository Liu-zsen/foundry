// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/tokenBank/tokenBankV2.sol";
import "../src/tokenBank/ERC20WithCallback.sol";

contract TokenBankV2Test is Test {
    TokenBankV2 public bank;
    ERC20WithCallback public token;
    address public alice = makeAddr("alice");
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        // 部署带回调功能的ERC20代币
        token = new ERC20WithCallback(1000000 * 10**18); // 铸造 1000000 个代币
        // 部署TokenBankV2
        bank = new TokenBankV2(address(token));
        
        // 给测试用户铸造代币
        token.mint(alice, INITIAL_BALANCE);
        
        // 模拟alice的操作
        vm.startPrank(alice);
        // 授权银行合约
        token.approve(address(bank), type(uint256).max);
    }

    function test_Deposit() public {
        // 测试普通存款
        uint256 depositAmount = 100 ether;
        bank.deposit(depositAmount);
        
        assertEq(bank.balances(address(token), alice), depositAmount, "The deposit amount is incorrect");
        assertEq(token.balanceOf(address(bank)), depositAmount, "Incorrect bank balance");
    }

    function test_TransferWithCallback() public {
        // 测试通过transferWithCallback存款
        uint256 depositAmount = 100 ether;
        bytes memory data = abi.encode(0);
        token.transferWithCallback(address(bank), depositAmount, data);
        
        assertEq(bank.balances(address(token), alice), depositAmount, "Incorrect deposit amount for callback");
        assertEq(token.balanceOf(address(bank)), depositAmount, "Incorrect bank balance");
    }

    function test_Withdraw() public {
        // 先存款
        uint256 depositAmount = 100 ether;
        bank.deposit(depositAmount);
        
        // 测试提款
        bank.withdraw(depositAmount);
        
        assertEq(bank.balances(address(token), alice), 0, "The balance after withdrawal is not 0");
        assertEq(token.balanceOf(alice), INITIAL_BALANCE, "The user's balance is incorrect after withdrawal");
    }

    function test_FailInvalidToken() public {
        // 部署另一个代币来测试无效代币调用
        ERC20WithCallback invalidToken = new ERC20WithCallback(1000000 * 10**18); // 铸造 1000000 个代币
        vm.expectRevert("Invaild Token");

        bytes memory data = abi.encode(0);
        invalidToken.transferWithCallback(address(bank), 100 ether, data);
    }
}