# G06 模拟与平衡证据

W2 真数据报告见 [#198 改前/改后对比](report_2026-10-18_w2_198.md)。复跑用
`bash tools/cards/balance/w2_run.sh before /tmp/dh198-before` 和
`bash tools/cards/balance/w2_run.sh after /tmp/dh198-after`，默认每批种子 1–20、七策略连续三关。
两批均复制当前 `data/cards` 真内容；before 仅替换回记录的基线空覆盖，after 使用当前覆盖。
每批保留输入文件 SHA-256、真实数据库哈希、Godot 版本、覆盖内容、逐局 JSON 与日志。
运行前需标准 Godot 导入；如果导入报错，必须单独报告，不能由模拟通过推断导入通过。

肉鸽 v1 开 / 关对照（`docs/cards/rogue/ROGUE_V1.md` §14 RG6）用
`GODOT=<4.7.1> SEEDS=20 JOBS=2 bash tools/cards/balance/rogue_ab.sh <新的输出目录> [候选覆盖.json]`：
`data/cards` 拷两份，off 份的 `balance_overrides.json` 加 `{"relics": {"enabled": false}, "stock": {"enabled": false}}`，
两份各跑 strict 校验，种子 1–20 × `refuser,fair,trader,idle` × 三关（on 份另跑 `random`，供 A7），
最后 `aggregate.py --ab-on/--ab-off/--ab-data` 出 `ab_<日期>.{json,md}`（A1–A7）。`XDG_DATA_HOME` 不设时放在输出目录里。
2026-10-25 的四批（基线与三批调数）证据在 `rogue_v1/b0`–`b3/`，报告见 `report_2026-10-25_rogue_v1.md`。

`aggregate.py` 输出的 `inputs` 记录实际覆盖；`pass_rate.reached` 区分未到达后关的样本，
`month_money.samples` 仅计算完成结账的局，`street.affected_rate` 包含跨关延续的街头状态。
条子的类别和当前档位取公开 `card.demand`；失败局与无样本指标不记作通过或零值。
验证采集/分母可运行 `python3 tools/cards/balance/test_aggregate.py` 和 G06 suite 的 `G06_report_schema`。

`tools/cards/balance/run.sh` 拆分独立种子进程。每次使用新的 `.parts.*` 目录，保留逐局进度和原始 JSON，避免旧批次混入新报告。日期、数据根和报告标签由命令行传入；引擎不读取墙钟。`JOBS` 默认 2，合同预算批次使用 6。

```sh
XDG_DATA_HOME=/workspace/scratch/userdata-G06 GODOT=/workspace/tools/godot-4.7.1/godot JOBS=6 \
  tools/cards/balance/run.sh --seeds=200 --policies=fair,greedy,kind,random,refuser,wheel,hoarder \
  --stages=3 --data=examples --out=/workspace/scratch/policy-report --date=2026-10-13
XDG_DATA_HOME=/workspace/scratch/userdata-G06 GODOT=/workspace/tools/godot-4.7.1/godot JOBS=6 \
  tools/cards/balance/run.sh --fuzz=1000 --stages=3 --data=examples \
  --out=/workspace/scratch/fuzz-report --date=2026-10-13
```

每局跑到三关、给定天数或真实局终。局终原因保留原样，不能将拘留失败算作三关通过。自动策略不会处理的状态经确认打烊继续；确认打烊失败或最大步数耗尽判失败。`refuser` 在每个阶段只发确认打烊。

1000 局全长 fuzz 单独统计。动作使用纯可见的 `view/query`，混合合法指令、错误指令、约 15% 随机确认/不确认打烊及早上存读。生产 runner 核对预览、清单、隐藏键和最多八步进入下一天；清单内的 1000 种子测试另检查状态整数与抽样回放，不靠墙钟通过。正常局终还验证重来本关返回开月。

`aggregate.py` 可重复传 `--parts=<目录>`，把策略与 fuzz 的独立批次合成一个最终报告。所有未观测比率写 `null`，分母包含没到达后续关卡的局。运行文件记录数据库哈希和数据标签；策略指标与 fuzz 的验收分母分开。

例子集缺少后两年的轮盘与部分签数据（共享问题 #49）。`scripts/tests/cards/G06/scenario.gd` 的 `build(destination)` 在指定目录复制例子并补齐 G06 的测试数据，不修改共享例子、不跨年代复用生产扇区。使用该数据必须传 `--data-root=<目录> --label=examples_with_G06_test_completion`。原例子集的 30 天黄金种子不使用补齐数据。最终报告包含完整的测试根生成与三批次复现命令。

求签隐藏预测不在公开门面中（#41）。报告的运行时准确率无观测时为 `null`；G05 的独立认证以外部证据列出，并保留 W0 与真实组装各自的范围，不伪称运行时测得。状态哈希与指令日志使用父线许可的只读诊断函数；不公开隐藏内容。存读后的系统 resume/retry 标记差异只在测试比较中按合同剔除，生产哈希不归一化。

`bench_main.gd` 不进入测试清单。它记录墙钟、存档大小和完整拒绝策略的一关/三关耗时；`project_fixture` 使用独立只读上下文，不能冒充真实预测预算。原始测量值写入报告和 PR，超预算也如实记录。

CLI 的 `cached_api.gd` 仅缓存每次指令间的公开 `view()`，返回深副本并读取当前 busy；变更指令前失效，`query` 与总线原样透传。真实等价测试核对公开返回、事件、日志、状态哈希和 Telemetry，不改引擎或策略。报告区分正常模拟结束、三关通关和过程中被拒绝的指令；月底钱款分位数的样本仅为实际月底，阶段通过率分母包含未到达该关的种子。
