# K18 · apprentice · 收徒

- **执行者**：Grok（#182 第 3 条；合同 1.4 见 #187）
- **依赖**：W0 引擎；不改发牌器。家人看铺不做。
- **分支**：`cards/K18-apprentice`
- **目标**：1939 收一个会成长的徒弟。忠心藏着。你不在时他看铺，回来翻账。可能偷当、给胡二通风，也可能接班。不挡下一天。台词由人写。

## 要做的事

- [x] 第 11 天 `p.tudi.1939.ask`：留下 / 话硬 / 不收 / 不理
- [x] 人脉 `ct.tudi`，月底本事 +1，上限在 `rules/apprentice.json`
- [x] 隐藏 `apprentice_loyalty`、`apprentice_skim_pending`
- [x] 街头或牢房：看铺；回来 `ev.any.apprentice_audit`
- [x] 月底按阈值排队偷、通风、接班，每条一次
- [x] 末关接班走结局前受控窗口（`CardDayLoop.open_pre_ending_window`，G02×K18 共享，#187）：`month_pending` 或 short 面板时不开；短款和抵押（含铺面丢失）走完原来的 `close_month` 之后才开窗口。打烊不请空 short、不硬写 `month_pending`，也不重跑同日 day_end/夜牌/settle。成长仍每关一次。
- [x] 机制 `apprentice`，步骤 `gd.apprentice`，规矩页仍是 `rule.contact`
- [x] 徒弟小牌用 `jade`

## 只能改这些文件

`ownership.json` 里 K18 的路径，加上每条线默认的测试、标签、界面键。

## 不能做的事

不写玩家正文。不改 `card_composer.gd`。不新加效果 op。不把忠心画出来。不局终。

## 新手指引

第一次发到带 `apprentice` 标签的人物牌时记 `apprentice`。步骤 `gd.apprentice`：账簿批注，锚点 `a.contacts`，备用 `a.tab.contacts`，做完是选一条或超时。

## 测试

`scripts/tests/cards/suites/K18.txt`

## 需要主创 / 编排决定

- 阈值（偷 25、通风 12、接班 80、老实 50、每天克扣 6、本事上限 5、至少 2 个月）都是起步数。
- 家人看铺没有人脉标签可挂，这次不做。
- 立绘暂用 `portrait.ex_shopboy`。称呼由 A 定。

## 审核（GPT 代 Claude）

隐藏数不进视图。`day.end` 确认后一定往前。first 只发一次。
