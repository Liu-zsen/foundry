// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract CheckBalance is Script {
    function run() external view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Balance (ETH):", deployer.balance / 1e18);
    }
} 