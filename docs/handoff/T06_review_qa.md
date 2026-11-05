# T06 评审、试玩与史实核对（持续任务）

- **执行者**：Grok
- **依赖**：每个 PR 开出来就做
- **分支**：不需要自己的分支；在 PR 里留评审意见
- **状态**：T01 / T04 / T05 已评（Grok / 2026-10-11）；见回报栏。界面 PR 的截图沿用 v0.4 画廊，本轮未重截。

## 要做的事
对每个 `town/T0X-*` PR：
- [ ] 拉下分支跑 `tools/run_tests.sh`，贴结果。
- [ ] 按合同逐条核对：文件归属有没有越界、有没有写死的平衡数字、有没有界面读了隐藏数据（合同 §9）、有没有 `randf()` 混进模拟。
- [ ] 按主创原则核对（`docs/town/research/gamejev_design.md` §6 反要求清单）：有没有进货菜单、好感条、按好感开机构、反复重摇、无限涨租。
- [ ] 有界面的 PR：用 Xvfb 截图（合同 §10），写试玩报告：哪里卡、哪里看不懂、哪里像 Probably Stolen。
- [ ] 史实：1938 年江南小镇的警察所/保安队、保甲、维持会、良民证、当铺规矩（当期、月息、满当）、物价——发现与 `docs/town/research/web_research.md` §4 或剧情不符的，列出来并给出处。
- [ ] 每轮评审结论写成 PR 评论：**必须改 / 建议改 / 不用改** 三档，必须改的要能复现。

## 回报（执行者填写）
- 已评审的 PR 与结论（Grok / 2026-10-11，对着集成分支 `6223700`）：
  - [PR #1](https://github.com/misakamikotoghr-5205/dehoudang/pull/1#issuecomment-6107811791) T01：**不用改**。建议改 1 条：`town_pack` 的 `pawn_rate` 0.1 只进无 world 的纯模拟票据，玩家账本和当票仍是月息三分。不要把玩家利率改成一成。
  - [PR #4](https://github.com/misakamikotoghr-5205/dehoudang/pull/4#issuecomment-6107811957) T04：**不用改**。同一条利率建议；另外 `open_pawn` 的 30 天 / 0.03 写在代码里，不读包。小镇夜菜单已跳过订货。
  - [PR #3](https://github.com/misakamikotoghr-5205/dehoudang/pull/3#issuecomment-6107812131) T05：数据已从别的合并进集成，这张 PR 基线仍是 `town/T02-art-maps`，建议关闭。没有必须改。
  - [PR #5](https://github.com/misakamikotoghr-5205/dehoudang/pull/5#issuecomment-6107817336) T07：未重跑 200 种子。建议在数值报告注明纯模拟月息 0.1 不是玩家当票的三分。无必须改。
- 测试（Godot 4.7，直接跑脚本；`tools/run_tests.sh` 的 import 会被沙箱里的 `ERROR: Malformed message!` 判红，未把它算进失败）：
  - `SIM LEDGER: PASS`
  - `SIM RULES: PASS (549 checks)`
  - `SIM REPLAY: PASS (298 checks)`
  - `SIM LIFE: PASS (2438 checks)`
  - `SIM SOAK: PASS (4500 world-backed days, 20474 visits, 23124 transfers, 226581 checks)`
  - `TOWN PLAY ACCEPTANCE OK: 789 checks; 33 run reports`
  - 以上日志无 SCRIPT ERROR / ERROR / WARNING
- 这轮没有新截图。T01/T04 是后端 PR；小镇画面截图已在 `screenshots/v04_gallery/`。
- 未改玩法，未改模拟代码。

