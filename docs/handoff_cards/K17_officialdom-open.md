# K17 `officialdom-open` · 官场开头：1940 金色牌“请你当保长”（合同 1.4）

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K17 的展开。**优先级：主创原话 > 合同 > 本卡**。设计出处：`docs/cards/DESIGN_cards.md` §九.7（主创 10-15 确认），issue #182 第 5 条。

## 执行者与线号

- 执行者：**Grok**（Owner：K17）
- 线号：1.4 跨线新增（不占 K01–K16 线号）

## 跨线授权

- 合同 1.4 的接口改动走 `[api]` issue **#183**（#182 授权各线自补合同与任务卡）。
- 本卡涉及别人的文件，只做 #183 列明的最小改动：K16 `data/cards/guide/steps.json` 加一步 `gd.office`、`rule_pages.json` 的 `rule.gold.unlock_first` 加 `office`；G03 `rules_install.gd` 发牌钩子对 `office` 标签记 first；`CardIds.FIRSTS` 加 `office`；`ownership.json` 与合同 §2 登记 `officialdom.json`。

## 依赖与波次

| 依赖 | 什么 |
|---|---|
| G02 | `schedule.stage_day` 发日程牌；`day.end` 对没处理的金色牌走 `on_expire` |
| G03 | 公开指令 `card.choose`、发牌钩子 `deal_composed`、`story`/`flag`/`counter`/`dossier_gap` 等效果 |
| K05/K06 | 1940 其他金色牌的日子（本牌第 14 天，不撞） |
| K16 / C16 | 指引步骤与规矩页数据；指引引擎 |

## 只能改这些文件

- `data/cards/era/1940/officialdom.json`（自己的）
- `scripts/tests/cards/K17/**`、`scripts/tests/cards/suites/K17.txt`、`data/cards/tags/K17.json`
- 以及上面“跨线授权”列出的几处最小改动

## 要做的事

- [x] 金色牌 `p.ma.1940.baozhang`：`weight: 0`、`schedule {stage_day: 14, once: true}`、标签 `office`；四个选项 `take` `nominal` `buy_off` `refuse`，没有检定、没有 `game_over`
- [x] 打烊没理 `on_expire`：`story=ignored`、`office_baozhang_ignored`、风声 +1、`dossier_gap df.ma.1940.baozhang_ask`
- [x] 档案碎片 `df.ma.1940.baozhang_*`
- [x] 旗标与计数照合同 §3.4 K17（后续官场线、1945 肃奸只读这些键）
- [x] first `office` + 指引 `gd.office`（规矩页 `rule.gold`）
- 只写 `brief`，不写正文、不写血腥；“下一天”永远能按

## 新手指引

- 机制 `office`：G03 在发牌钩子里对带 `office` 标签的牌记 first；它在状态里，存→读后不再发、不再教。
- 步骤 `gd.office`：`trigger {first: office, phase: day}`，锚点 `a.card.gold@{uid}`（备用 `a.hand.gold`），`done_when` `cmd:card.choose` / `timeout`。

## 测试与验收标准（真数据）

`scripts/tests/cards/K17/` 进 `suites/K17.txt`：

1. `test_baozhang.gd`：数据形状、每个走向的旗标与计数（例子集桩，只算局部效果）。
2. `test_baozhang_real.gd`（**真数据验收**，`only_examples: false`）：
   - 1940 关（stage 2）新局，第 1–13 天手上没有这张牌；第 14 天 `day.begin` 自然发到手上，且只发一次；第 15 天及以后不再发。
   - 公开指令 `card.choose` 走四个分支，核对钱款与旗标；`buy_off` 覆盖钱够（扣 60）与钱不够（付光为止）。
   - 不处理直接 `day.end`：牌离手，`story.s1940.baozhang = ignored`，档案出现缺口 `df.ma.1940.baozhang_ask`，并能进入下一天。
   - 发牌时 first `office` 发出一次；存档→读档后不再发 first。
3. `test_baozhang_guide.gd`（**真实指引链**，真牌库 + 真 `CardEngine` + 真 `GuideOverlay`/`CardGuide` + 真 `CardWidget` 锚点）：
   - 第 1–13 天 `gd.office` 不亮；第 14 天 `CardGuide` 收到带 uid 的 first `office`，`gd.office` 亮在 `a.card.gold@<uid>` 上，引擎 `guide_progress` 记 `shown`/`shows=1`。
   - 公开 `card.choose` 完成该步，引擎进度变 `done`；存档→新引擎读档→新 `CardGuide` 绑定后进度仍 `done`，兜底锚点 `a.hand.gold`、firsts、白天都在，后续三天每天评一次都不再亮，`shows` 仍为 1。
   - 对照：同一读档清掉进度的 `CardGuide` 会亮（证明“不亮”只因读回的进度）。
4. card + legacy 回执贴精确 SHA。
