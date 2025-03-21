// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StakingPool/StakingPool.sol";
import "../src/StakingPool/IStaking.sol";

contract MockKKToken is IToken {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function mint(address to, uint256 amount) external override {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        return true;
    }
}

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    MockKKToken public kkToken;
    address public alice = address(1);
    address public bob = address(2);

    function setUp() public {
        // 部署 KK Token
        kkToken = new MockKKToken();
        // 部署质押池
        stakingPool = new StakingPool(address(kkToken));
        
        // 给测试账户一些 ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 50 ether);
    }

    function testStakingRewards() public {
        // Alice 质押100 ETH
        vm.startPrank(alice);
        stakingPool.stake{value: 100 ether}();
        vm.stopPrank();

        // 移动到下一个区块
        vm.roll(block.number + 1);

        // Bob 质押50 ETH
        vm.startPrank(bob);
        stakingPool.stake{value: 50 ether}();
        vm.stopPrank();

        // 检查总质押量
        assertEq(stakingPool.totalStaked(), 150 ether);

        // 移动10个区块
        vm.roll(block.number + 10);

        // 检查Alice的预期收益
        uint256 aliceEarned = stakingPool.earned(alice);
        uint256 bobEarned = stakingPool.earned(bob);

        // Alice应该得到总奖励的2/3
        // Bob应该得到总奖励的1/3
        assertApproxEqRel(aliceEarned * 1, bobEarned * 2, 1e16); // 允许0.1%的误差

        // Alice领取奖励
        vm.prank(alice);
        stakingPool.claim();

        // 检查Alice的代币余额
        uint256 aliceBalance = kkToken.balanceOf(alice);
        assertEq(aliceBalance, aliceEarned);

        // Bob领取奖励
        vm.prank(bob);
        stakingPool.claim();

        // 检查Bob的代币余额
        uint256 bobBalance = kkToken.balanceOf(bob);
        assertEq(bobBalance, bobEarned);
    }

    function testUnstakeAndRewards() public {
        // Alice 质押100 ETH
        vm.prank(alice);
        stakingPool.stake{value: 100 ether}();

        // 移动5个区块
        vm.roll(block.number + 5);

        // 记录Alice的预期收益
        uint256 aliceEarnedBefore = stakingPool.earned(alice);

        // Alice赎回50 ETH
        vm.prank(alice);
        stakingPool.unstake(50 ether);

        // 检查Alice的代币余额（应该收到之前的收益）
        uint256 aliceBalance = kkToken.balanceOf(alice);
        assertEq(aliceBalance, aliceEarnedBefore);

        // 移动另外5个区块
        vm.roll(block.number + 5);

        // 检查新的收益（应该是之前的一半速率）
        uint256 aliceEarnedAfter = stakingPool.earned(alice);
        assertApproxEqRel(aliceEarnedAfter * 2, aliceEarnedBefore, 1e16); // 允许0.1%的误差
    }

    receive() external payable {}
} 