# 德厚当 v0.4 小镇版 —— 任务交接板

仓库：https://github.com/misakamikotoghr-5205/dehoudang
集成分支：`claude/festive-ride-vud32a`（每个任务从这里切分支，做完 PR 回这里）

## 先读
1. `docs/town/DESIGN_v04_town.md` —— 小镇版玩法设计（为什么改、怎么改）
2. `docs/handoff/TOWN_INTERFACES.md` —— **接口合同**（目录归属、数据格式、`TownSim` / `TownGame` 接口、画面规格、测试与 Git 流程）
3. `docs/town/mockups/` —— 主创选定的画风：A1 小镇 + A2 当铺内部 + B2 店内侧视特写（C 方案 2.5D 已否决，仅存档）
4. `docs/town/research/` —— 调研报告（现有代码、剧情、GameJev 设计与源码、参考游戏、美术采购成本）
5. `docs/town/prototype/` —— 已跑通的生成器原型（GDScript）

## 任务板

| 编号 | 任务 | 执行者 | 依赖 | 状态 |
|---|---|---|---|---|
| [T01](T01_sim_core.md) | 生成器核心（GameJev → `scripts/sim/`） | **GPT** | 无 | ✅ 已合并 |
| [T02](T02_art_maps.md) | 小镇美术管线与地图 | **Grok** | 无 | ✅ 已合并；当铺内部返工 → T02b |
| [T03](T03_town_frontend.md) | 小镇前端（走动、门、时钟、特写、柜台衔接） | **Claude** | 合同；T01/T02 合并后最省事 | ✅ 已合并（含暂停菜单/设置/返回标题、配乐接入、评审修复） |
| [T04](T04_gameplay_story.md) | 玩法与主线接入（卖货、活当、家用账、存档） | **GPT** | T01、T03 | ✅ 后端已合并；界面联调随 T03 |
| [T05](T05_shop_content.md) | 店铺特写内容（六家店的菜单与对白） | **Grok** | 先写数据；联调等 T02、T03 | ✅ 已合并；联调随 T03 |
| [T06](T06_review_qa.md) | 评审、试玩、史实核对（持续） | **Grok** | 每个 PR | T01/T04/T05 已评（2026-10-11）；无必须改。PR #3 建议关闭 |
| T02b（见 T02 卡文末） | 当铺内部按示意图 A2 返工 | **Grok** | 无 | ✅ 已合并 |
| [T07](T07_balance.md) | 数值平衡（蒙特卡洛） | **GPT** | T01 | ✅ 已合并（报告 `docs/town/balance_report.md`） |

**并行顺序**：第一批 T01（GPT）＋ T02（Grok）＋ T05 写数据（Grok）同时开 → 第二批 T03（Claude）、T07（GPT）→ 第三批 T04（GPT）→ T06 全程。
**额度分配（建议）**：GPT 约 45%（T01、T04、T07 都是后端与数值）；Grok 约 35%（美术、内容、评审）；Claude 约 20%（T03 前端＋合并时的集成审查）。

## 交接规则
1. 领任务：在任务卡把“状态”改成“进行中（执行者/日期）”，提交到自己的任务分支。
2. 只改任务卡“只能改这些文件”列出的路径。必须越界时，写进回报栏，交编排处理。
3. 做完：`tools/run_tests.sh` 全绿 → 开 PR 到 `claude/festive-ride-vud32a` → 在任务卡“回报”栏填分支、PR 链接、测试结果、遗留问题。
4. T06（Grok）评审每个 PR；“必须改”的修完才合并。
5. 不确定的设计问题不要自己拍板：写在回报栏的“需要主创/编排决定的事”。

## 给 GPT 的开场提示（复制粘贴）
> 你接手 GitHub 仓库 misakamikotoghr-5205/dehoudang（Godot 4.7 + GDScript 的民国当铺游戏）。从分支 `claude/festive-ride-vud32a` 开始。先读 `docs/handoff/README.md`、`docs/handoff/TOWN_INTERFACES.md`，再读你的任务卡 `docs/handoff/T01_sim_core.md`（之后是 T07、T04）。严格遵守合同里的目录归属、确定性随机（JevRng）、隐藏信息白名单和测试红线。在 `town/T01-sim-core` 分支上开发，`tools/run_tests.sh` 全绿后开 PR 回 `claude/festive-ride-vud32a`，并在任务卡回报栏填写结果。有设计疑问写进回报栏，不要擅自改玩法。

## 给 Grok 的开场提示（复制粘贴）
> 你接手 GitHub 仓库 misakamikotoghr-5205/dehoudang（Godot 4.7 + GDScript 的民国当铺游戏）。从分支 `claude/festive-ride-vud32a` 开始。先读 `docs/handoff/README.md`、`docs/handoff/TOWN_INTERFACES.md`，再读你的任务卡 `docs/handoff/T02_art_maps.md`（同时可做 `T05_shop_content.md` 的数据部分；另外负责 `T06_review_qa.md` 评审所有 PR）。美术用 Python 代码画（从 `docs/town/mockup_src/` 的示意图生成器改起），严格按合同 §2 的尺寸和文件名。在 `town/T02-art-maps` 分支开发，`tools/run_tests.sh` 全绿后开 PR 回 `claude/festive-ride-vud32a`，并在任务卡回报栏填写结果。

## 环境
- Godot 4.7 Linux：`https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip`，设 `GODOT=<路径>` 再跑 `tools/run_tests.sh`
- 截图要 Xvfb：见合同 §10
- 当前基线：`tools/run_tests.sh` 63 项全绿（2026-10-11 复测）
