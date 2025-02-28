// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import "forge-std/Script.sol";
import { MyToken } from "../src/myToken/DeployMyToken.sol";

// 使用 Solidity 编写部署脚本
contract DeployMyToken is Script {
    function deploy() external {
        {
            // 获取部署者私钥
            uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            
            // 开始记录部署操作
            vm.startBroadcast(deployerPrivateKey);

            // 部署合约
            MyToken token = new MyToken(10 ** 18);

            address alice = makeAddr("alice");
            token.transfer(alice, 100 ether);

        }

        vm.stopBroadcast();
    }
} 