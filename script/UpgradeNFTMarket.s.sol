// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket/NFTMarketV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967Upgrade.sol";

contract UpgradeNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署新的实现合约
        NFTMarket newImplementation = new NFTMarket();

        // 2. 升级代理合约
        ERC1967Upgrade(payable(proxyAddress)).upgradeToAndCall(
            address(newImplementation),
            "" // 如果新版本不需要初始化，则传空字节
        );

        console.log("Upgraded implementation to:", address(newImplementation));

        vm.stopBroadcast();
    }
}
