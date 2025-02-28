// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "./myToken.sol";

// 目标合约需要实现的接口
interface ITokenReceiver {
    function tokensReceived(address sender,address tokenAddress, uint256 amount) external returns (bool);
}
/**
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback,
在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
**/
contract ERC20WithCallback is MyToken {
    constructor(uint256 initialSupply) MyToken(initialSupply) { }
    // 带回调的转账函数
    function transferWithCallback(address recipient,address tokenAddress, uint256 amount) external returns (bool) {
        // 转账
        bool success = transfer(recipient, amount);
        require(success, "Transfer failed");

        // 如果目标地址是合约，调用其 tokensReceived 方法
        if (isContract(recipient)) {
            bool callbackSuccess = ITokenReceiver(recipient).tokensReceived(msg.sender,tokenAddress, amount);
            require(callbackSuccess, "Callback failed");
        }
        return true;
    }

    // 检查地址是否为合约
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}