# 合同 1.2 黄金种子变更（2026-10-13）

保留原用例：原始例子集、seed 7、fair、30 天。它实际到达第 30 天（818 条指令），三个检查点均存在；没有使用后两年测试补齐数据。

此前基线来自旧合同。598d1e1 更新例子的 fate/big_fate 未处理后果，新增合同 1.2 打烊清单、生命周期与拘留规则。G06 增加必需规则 prison.max_days，数据库机械哈希也随规则变化。这些变化会改变机械状态；本次以最新版真实六模块重新生成，不把旧哈希静默当作通过。已修正的付款失败/待付款清理和月结续接纳入该真实组装版本。

| 日 | 旧哈希 | 新哈希 |
|---:|---|---|
| 10 | `b4140cbd075159f3a805d5b8f25ab8c84c3c77b3a581e6b63aa0688bdeb78d83` | `aa0846ef00d684d480d955e4d5761b05f26796c9f94e4d6008235ab79676f08f` |
| 20 | `6d0fa278107d8206f5e2b1c292f937b9c76e70704a4137f3f00472d32b8ae7f2` | `d1c853aa2e1a178c6d84a0f0aeb15f9e2914c0bbd28722655de6b618574e0e46` |
| 30 | `bf6a44bba281e8eddb1b7dff3d5649cc0ac983a188a030d4f5bbd6dfb34d62a2` | `c727c12954a9044240f2565a5258e4e4be634b5a9a2c3ee4abde507e5795c36c` |

生成命令：

```sh
XDG_DATA_HOME=/workspace/scratch/userdata-G06 /workspace/tools/godot-4.7.1/godot --headless \
  --path /workspace/cards-assembled -s res://scripts/cards/sim/balance_main.gd -- \
  --seed_from=7 --seeds=1 --policies=fair --days=30 --stages=0 --data=examples \
  --update-golden --golden-out=/workspace/scratch/G06-contract12-final-golden.json \
  --out=/workspace/scratch/G06-contract12-final-golden-run --date=2026-10-13
```

生成工具和黄金测试均拒绝遗漏 10/20/30 检查点的用例。提交这组新哈希供 Claude 审核，PR 标记 golden-change；最终验收同时跑两遍并重放失败指令在内的完整日志。

随后修正自动策略的公开 `self.used_today` 过滤：已经用过自己时不再提出必被拒绝的放格子动作。原用例实际重算为 803 条指令（原 818，少 15 条失败指令），三个检查点哈希仍完全相同。失败指令日志不在机械状态里；保留原新版哈希，不为减少拒绝日志制造新黄金。
