// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署实现合约
        NFTMarket implementation = new NFTMarket();

        // 2. 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            address(0xa39812b7e716e8B6CbbE018954A0A88C780360fa),    // 替换为实际的 token 地址
            address(0xeAbB786c1a08815C6Edb3B9041fF77eebC342Cd9),      // 替换为实际的 NFT 地址
            address(0x10d8278A429bb03e9F2C05F72EdF9d6F50b06888)    // 替换为实际的签名者地址
        );

        // 3. 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        console.log("Proxy deployed to:", address(proxy));
        console.log("Implementation deployed to:", address(implementation));

        vm.stopBroadcast();
    }
}