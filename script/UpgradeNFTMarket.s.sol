// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address adminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署新的实现合约
        NFTMarket newImplementation = new NFTMarket();

        // 2. 升级代理合约
        ProxyAdmin proxyAdmin = ProxyAdmin(adminAddress);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxyAddress),
            address(newImplementation),
            ""
        );

        console.log("Upgraded implementation to:", address(newImplementation));

        vm.stopBroadcast();
    }
}
