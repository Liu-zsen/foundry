// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/IDO/IDO.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract IDOTest is Test {
    IDO public ido;
    MockToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署合约
        ido = new IDO();
        token = new MockToken();

        // 转移代币到 IDO 合约
        token.transfer(address(ido), 100000 * 10**18);

        // 给测试用户一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testStartSale() public {
        uint96 tokenPrice = uint96(0.1 ether);
        uint96 minTarget = uint96(50 ether);
        uint96 maxCap = uint96(100 ether);
        uint64 duration = uint64(7 days);

        ido.startSale(
            address(token),
            tokenPrice,
            minTarget,
            maxCap,
            duration
        );

        (
            address saleToken,
            uint96 saleTokenPrice,
            uint96 saleMinTarget,
            uint96 saleMaxCap,
            ,,,
        ) = ido.getSaleInfo();

        assertEq(saleToken, address(token));
        assertEq(saleTokenPrice, tokenPrice);
        assertEq(saleMinTarget, minTarget);
        assertEq(saleMaxCap, maxCap);
    }

    function testInvestment() public {
        // 开启预售
        ido.startSale(
            address(token),
            uint96(0.1 ether),
            uint96(50 ether),
            uint96(100 ether),
            uint64(7 days)
        );

        // 用户1投资
        vm.prank(user1);
        ido.invest{value: 1 ether}();

        // 验证投资金额
        assertEq(ido.investments(user1), uint96(1 ether));
    }

    function testSuccessfulSale() public {
        // 开启预售
        ido.startSale(
            address(token),
            uint96(0.1 ether),
            uint96(50 ether),
            uint96(100 ether),
            uint64(7 days)
        );

        // 用户投资
        vm.prank(user1);
        ido.invest{value: 30 ether}();
        
        vm.prank(user2);
        ido.invest{value: 30 ether}();

        // 时间前进到预售结束
        vm.warp(block.timestamp + 7 days + 1);

        // 用户1领取代币
        vm.prank(user1);
        ido.claimTokens();

        // 验证用户1获得的代币数量
        assertEq(token.balanceOf(user1), 300 * 10**18); // 30 ETH / 0.1 ETH = 300 tokens
    }

    function test_RevertSale() public {
        // 开启预售
        ido.startSale(
            address(token),
            uint96(0.1 ether),
            uint96(50 ether),
            uint96(100 ether),
            uint64(7 days)
        );

        // 用户1投资不足最小目标
        vm.prank(user1);
        ido.invest{value: 20 ether}();

        // 时间前进到预售结束
        vm.warp(block.timestamp + 7 days + 1);

        // 用户1申请退款
        vm.prank(user1);
        ido.claimRefund();

        // 验证用户1收到退款
        assertEq(user1.balance, 100 ether);
    }

    function testOwnerClaimFunds() public {
        // 开启预售
        ido.startSale(
            address(token),
            uint96(0.1 ether),
            uint96(50 ether),
            uint96(100 ether),
            uint64(7 days)
        );

        // 用户投资达到目标
        vm.prank(user1);
        ido.invest{value: 60 ether}();

        // 时间前进到预售结束
        vm.warp(block.timestamp + 7 days + 1);

        // 项目方提取资金
        uint256 initialBalance = address(this).balance;
        ido.claimFunds();
        
        // 验证收到募集资金
        assertEq(address(this).balance - initialBalance, 60 ether);
    }

    receive() external payable {}
}
