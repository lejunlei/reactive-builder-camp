# Reactive Builder Camp 学习记录

- [D1 用例拆解卡](notes/d1-use-case.md) · 将 Sepolia 测试代币的大额充值记录到 Base Sepolia。
- [Lasna 系统合约费用笔记](notes/lasna-fees.md) · 使用 Foundry 的 cast 在指定区块查询并解释三个参数。

## 首次部署练习

`CampTestToken` 用于在 Sepolia 产生可控的 ERC-20 转账事件。`SepoliaTransferMonitor` 在 Lasna 订阅指定测试代币的转账，忽略铸币、销毁和阈值以下的转账，达到处理上限后取消订阅。监控结果通过 `TransferObserved` 写入 Lasna 交易日志。

从项目根目录构建。所用 Omni 依赖版本为 `3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8`。

```powershell
git clone https://github.com/Reactive-Network/reactive-lib-omni.git lib/reactive-lib-omni
git -C lib/reactive-lib-omni checkout 3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8
forge build
```

测试网验收顺序如下。

1. 用仅供测试的钱包在 Ethereum Sepolia 部署 `CampTestToken`，保留合约地址。
2. 在 Lasna 部署 `SepoliaTransferMonitor`，传入该地址、最小数量（例如 `1000000000000000000`，即 1 RCTT）和处理上限（例如 1）。部署交易需为监控合约附带 lREACT 余额。
3. 订阅生效后，在 Sepolia 将至少 1 RCTT 转给另一非零地址。在 Lasna Reactscan 上核对 `TransferObserved` 和成功调用 `react()` 的交易。上限为 1 时首次计数后自动退订。
4. 提交 Lasna 监控合约链接、成功的 `react()` 交易链接，以及一句话说明代币地址与金额过滤条件。
