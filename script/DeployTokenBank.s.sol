// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenBank} from "../src/tokenBank/tokenBank.sol";

contract SimulateDeposit is Script {
    function run() external {


        TokenBank tokenBank = TokenBank(0x1Cd149D60b15cD3F654f382F5f26D1FeDd225F82);
        TokenBank.PermitTransferFrom memory permit = TokenBank.PermitTransferFrom({
            amount: 1000000000000000000, // 1 ETH
            nonce: 0,
            deadline: 1838417200, // 更新为未来时间
            token: 0xa39812b7e716e8B6CbbE018954A0A88C780360fa,
            signature: hex"ff2e44f471e6840cfe4c55a4c813577cb06560e9f8960788dd224d2c3c1a167310440b7db4ae244c42590cbae4e9bd1602653a69789dd8df607c088765ce304b1b"
        });

        vm.startPrank(msg.sender);
        try tokenBank.depositWithPermit2(permit) {
            console.log(unicode"调用成功");
        } catch Error(string memory reason) {
            console.log(unicode"调用失败，原因:", reason);
        }
        vm.stopPrank();
    }
}