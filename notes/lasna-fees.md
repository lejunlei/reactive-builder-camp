# Lasna 系统合约费用笔记

使用 Windows 版 cast 1.7.1 查询 Lasna 测试网。RPC 返回链 ID `5318007`。三个参数都读取同一区块 `8649349`，方便复核。

```powershell
$rpc = 'https://lasna-rpc.rnk.dev/'
$systemContract = '0x8888888888888888888888888888888888888888'
$block = 8649349

cast call $systemContract '_gasPriceCoeffPer1000()(uint256)' --rpc-url $rpc --block $block
# 1000

cast call $systemContract '_extraGas()(uint256)' --rpc-url $rpc --block $block
# 100000 [1e5]

cast call $systemContract '_maxChargeGas()(uint256)' --rpc-url $rpc --block $block
# 50000 [5e4]
```

## 一次 react() 怎么收费

`费用 = max(tx.gasprice, block.basefee) × (_gasPriceCoeffPer1000 / 1000) × (实际执行消耗的 gas + _extraGas)`。本次读取的价格系数是 `1000 / 1000 = 1`，固定附加为 100,000 gas。假设计费用 gas 价格为 100 gwei，且执行消耗 50,000 gas，费用就是 0.015 lREACT。查询到的 `_maxChargeGas = 50000` 是系统执行扣款时的 gas 预算，与这个例子假设的执行消耗是两个独立的量。

## balance、reserves 和 debt

- **balance** 是合约账户实际持有的原生币余额，可用于支付。
- **reserves** 是系统合约账本中为该合约预存的费用额度，计费时优先扣减它。
- **debt** 是未结清的费用。系统在调用 `react()` 之前先查欠款，哪怕欠 1 wei，也会暂停投递，直到欠款清零。普通转账提高合约余额，结清欠款可通过系统合约的 `depositTo()` 或合约暴露的还款入口。

## 回滚还收费吗

收费。系统捕获 `react()` 的回滚后，仍按已产生的 gas 计算费用。设计上我会把常见的无关事件尽量过滤在订阅层，在 `react()` 中对不符业务条件的事件提前 `return`，并避免重复请求回调。提前返回依然消耗本次执行费用，因此订阅范围应尽量窄。

参考 [Reactive Economy & System Interactions](https://dev.reactive.network/economy) 和 [Lasna 测试网参数](https://dev.reactive.network/reactive-mainnet)。
