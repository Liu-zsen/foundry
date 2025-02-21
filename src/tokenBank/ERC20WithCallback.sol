// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./tokenBank.sol";

// 创建一个新的合约，继承自 OpenZeppelin 的 ERC20 合约
contract MyToken is ERC20 {
    // 构造函数将初始化 ERC20 供应量和代币名称
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        // 通过 _mint 函数铸造初始供应量的代币到部署合约的地址
        _mint(msg.sender, initialSupply);
    }
}
// 目标合约需要实现的接口 记录用户存款
// 将接口声明为独立的接口
interface ITokenReceiver {
    function tokensReceived(address sender, uint256 amount, bytes memory data) external returns (bool);
}
/**
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback,
在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
**/
contract ERC20WithCallback is MyToken {
    constructor(uint256 initialSupply) MyToken(initialSupply) { }
    // 带回调的转账函数  
    // 修改带回调的转账函数，添加 data 参数
    function transferWithCallback(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        // 转账
        bool success = transfer(recipient, amount);
        require(success, "Transfer failed");

        // 如果目标地址是合约，调用其 tokensReceived 方法
        if (isContract(recipient)) {
            bool callbackSuccess = ITokenReceiver(recipient).tokensReceived(msg.sender, amount, data);
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

    // 给测试用户铸造代币
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}