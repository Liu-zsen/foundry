# 闪电兑换套利项目

本项目是使用 Foundry 框架实现的闪电兑换套利演示。项目模拟了在两个价格不同的 Uniswap V2 流动池之间进行套利的过程，利用闪电贷获取无风险利润。

## 项目结构

- `src/FlashSwap/FlashSwapArbitrage.sol` - 闪电兑换套利合约
- `src/FlashSwap/MockUniswap.sol` - 模拟 Uniswap V2 工厂和交易对合约
- `src/FlashSwap/flashToken.sol` - ERC20 代币合约
- `test/FlashSwapArbitrageTest.t.sol` - 测试套利功能的单元测试
- `script/DeployFlashSwapArbitrage.s.sol` - 部署脚本

## 工作原理

闪电兑换套利的基本步骤：

1. 从 PoolA 借入 TokenA
2. 在 PoolB 中使用 TokenA 兑换为 TokenB（利用价格差）
3. 返还贷款给 PoolA（包括 0.3% 的手续费）
4. 保留剩余的利润

在本项目中，我们设置了两个价格不同的交易对：
- PoolA: 1 TokenA = 2 TokenB
- PoolB: 1 TokenA = 1.5 TokenB

这个价格差异创造了套利机会。

## 安装依赖

确保已安装 Foundry：

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

然后安装项目依赖：

```bash
forge install
```

## 本地测试

运行测试套件：

```bash
forge test -vvv
```

这将执行 `FlashSwapArbitrageTest.t.sol` 中的测试，模拟完整的套利过程并验证利润。

## 部署到本地测试网

1. 启动本地测试网：

```bash
anvil
```

2. 创建 `.env` 文件并添加私钥（Anvil 会提供测试私钥）：

```
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

3. 部署合约：

```bash
source .env
forge script script/DeployFlashSwapArbitrage.s.sol --rpc-url http://localhost:8545 --broadcast -vvv
```

## 执行套利交易

部署后，您可以通过以下步骤执行套利交易：

1. 确定代币在池中的排序（token0 和 token1）
2. 调用 `startArbitrage` 函数：

```solidity
arbitrage.startArbitrage(
    address(tokenA),  // 要借入的代币
    10 ether,         // 借入金额
    amount0Out,       // 如果 tokenA 是 token0，则为借入金额，否则为 0
    amount1Out        // 如果 tokenA 是 token1，则为借入金额，否则为 0
);
```

## 核心代码说明

`FlashSwapArbitrage.sol` 合约中的主要组件：

1. `startArbitrage` - 启动闪电贷
2. `uniswapV2Call` - 被 Uniswap 回调，在这里执行套利逻辑
3. `getOptimalAmount` - 计算最佳兑换金额

## 注意事项

- 这是一个教育性演示，使用的是模拟的 Uniswap 合约
- 在真实环境中，您需要连接到实际的 Uniswap 合约并考虑 gas 费用和滑点
- 在生产环境中使用前请确保进行充分的安全审计

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
