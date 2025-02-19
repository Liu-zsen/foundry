// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./tokenBank.sol";
import "./ERC20WithCallback.sol";

/**
继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，
用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中
**/
contract TokenBankV2 is TokenBank ,ITokenReceiver {
    // 初始化时设置 Token 合约地址 并调用 TokenBank 的构造函数
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {
        tokenAddress = _tokenAddress;
    }
    
    function tokensReceived(address sender, uint256 amount) external override returns (bool) {
        require(msg.sender == address(tokenAddress),"Invaild Token");
        // 记录用户的存款
        balances[tokenAddress][sender] += amount;
        return true;
    }
}



