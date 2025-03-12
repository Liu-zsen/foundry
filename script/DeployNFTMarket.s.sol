// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

//   == Logs ==
//   Implementation deployed to: 0x17688EBEa116f0ccdD068BF45E248777Bc895900 实现合约地址
//   ProxyAdmin deployed to: 0x7b01FAF95c663A2CCde7Ac1E4A8078520b486C4A 代理管理员合约地址 
//   Proxy deployed to: 0x904e8cA0EC6573B99D72ce230ebb0c953E5c5954 代理合约地址(这就是用户将要交互的地址)

contract DeployNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address signerAddress = vm.envAddress("SIGNER_ADDRESS");
        
        // 设置 gas 相关参数
        vm.setEnv("FOUNDRY_GAS_PRICE", "2000000000");         // 2 gwei
        vm.setEnv("FOUNDRY_GAS_LIMIT", "8000000");           // 8M gas limit
        vm.setEnv("FOUNDRY_PRIORITY_GAS_PRICE", "100000000"); // 0.1 gwei priority fee
        
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        
        // 1. 部署实现合约
        NFTMarket implementation = new NFTMarket();
        console.log("Implementation deployed to:", address(implementation));
        console.log("Implementation deployment gas used:", gasleft());

        // 2. 部署代理管理员合约
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);
        console.log("ProxyAdmin deployed to:", address(proxyAdmin));
        console.log("ProxyAdmin deployment gas used:", gasleft());

        // 3. 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            tokenAddress,
            nftAddress,
            signerAddress
        );

        // 4. 部署代理合约
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );
        console.log("Proxy deployed to:", address(proxy));
        console.log("Proxy deployment gas used:", gasleft());

        vm.stopBroadcast();
    }
}