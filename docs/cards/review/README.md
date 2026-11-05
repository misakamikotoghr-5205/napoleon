# K13 史实与敏感审读

> 2026-10-18 W2-6 #199：当前真数据修正、逐条对照和验证见 [W2-199-content-closeout.md](W2-199-content-closeout.md)。下文 2026-10-13 的扫描及分线占位报告保留为历史，不代表当前数据状态。

工具先能跑。逐份审读等 K01–K11、K16 的 PR 合入并写了“交付”再做。K13 不改别人的数据（合同 §2.6）。

## 怎么跑

```bash
python3 tools/cards/review/wording_lint.py --scope=all
python3 tools/cards/review/wording_lint.py data/cards/_examples --scope=all
python3 -m unittest discover -s tools/cards/review/tests
```

不给路径时扫 `data/cards/**`（不含 `_examples/`）的 brief——含演出块 `stage.brief`、`stage.cast[i].brief`、`stage.props[i].brief`、`stage.intro[i].brief`、`stage.after.<键>[i].brief`——以及 `data/cards/text/**` 的正文、`docs/cards/post1949/**`。字段路径用方括号写下标，例如 `stage.intro[0].brief`。按文件、牌 id、路径排序。

K15 发行审核第 6 项的调用不要改：

```bash
python3 tools/cards/review/wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must
```

规则在 `data/cards/rules/wording.json`（中文只在 `_` 开头的键里）。发行包不带这个文件。一行一个 `LINT MUST|SHOULD|HINT`，最后 `LINT DONE <n> must, <n> should, <n> hint`。给了 `--fail-on` 且有该级别或更严重的问题，退出码 1。

## 规则

| id | 级别 | 查什么 | 依据 |
|---|---|---|---|
| `puppet_prefix` | must | 维持会、维新政府、中储券、商统会、清乡委员会前面要有“伪”或“汪伪”；1938–1945 的县政府、区公所同样；国民政府只在 1940–1945 | era.json notes 第 1 条；年表 |
| `year_1945` | must | 1945 年的胜利写“抗战胜利”，不用光复、日本战败等顶替 | era.json notes 第 1 条；stage 8 |
| `year_1949` | must | 1949 年写“解放”，不用易帜、建国等顶替 | era.json notes 第 1 条；stage 12 |
| `war_length` | must | 不写“八年抗战”，写“十四年抗战” | era.json notes 第 1 条 |
| `fifties_no_punish` | must | 1950 年代不写斗争会、批斗；`weight>0` 的坏命运/坏事件不做随机惩罚 | era.json notes 第 2 条；`branch_end`；DESIGN §六 |
| `no_violence_detail` | must | 不写暴力细节（词表） | era.json notes 第 2 条 |
| `brief_no_dialogue` | must | brief / 指引 brief 里，引号超过 12 字或含。！？当成对白 | 合同 §11.2 |
| `guide_no_hidden` | must | 指引步骤、规矩页的 brief，以及它们的正文，不提概率、点数、本心、权重、%、底价、真假 | 红线 3；§7.10.1 第 8 条 |
| `no_percent` | must | 正文里没有 `%` | §11.4 第 6 项；V27 |

每条规则在 `tools/cards/review/tests/fixtures/` 里有一个会报 MUST 的例子和一个不报的例子。清单里的测试只跑夹具。

## 本轮扫描（2026-10-13，尚无 K 数据交付）

默认扫描（真数据 + 空的 post1949）：

```text
LINT DONE 0 must, 0 should, 0 hint
```

例子集（会报，但不崩；默认扫描不含它）：

```text
LINT MUST data/cards/_examples/demand/demands.json:dm.1938.money.t1:brief puppet_prefix 日方扶植的政权前面要有“伪”或“汪伪”：维持会
LINT DONE 1 must, 0 should, 0 hint
```

这一条是 W0 例子 brief 开头少了“伪”，不是某个 K 任务的交付文件。不开修正 issue，也不改例子。

本轮无演出块。`data/cards/**`（不含 `_examples/`）里还没有 `stage`，不编造拍子上的问题。

## 报告索引

| 报告 | 数据 | 审读 | 修正 issue |
|---|---|---|---|
| [K01.md](K01.md) | 1938 人物 | 待交付 | 未开 |
| [K02.md](K02.md) | 1938 世界 | 待交付 | 未开 |
| [K03.md](K03.md) | 1939 人物 | 待交付 | 未开 |
| [K04.md](K04.md) | 1939 世界 | 待交付 | 未开 |
| [K05.md](K05.md) | 1940 人物 | 待交付 | 未开 |
| [K06.md](K06.md) | 1940 世界 | 待交付 | 未开 |
| [K07.md](K07.md) | 条子 | 待交付 | 未开 |
| [K08.md](K08.md) | 消息与档案 | 待交付 | 未开 |
| [K09.md](K09.md) | 通用牌 | 待交付 | 未开 |
| [K10.md](K10.md) | 签与轮盘 | 待交付 | 未开 |
| [K11.md](K11.md) | 物品 | 待交付 | 未开 |
| [K16.md](K16.md) | 指引与解放后 | 待交付 | 未开 |
| [stages_1939.md](stages_1939.md) | 1939 腊月公历 | 已核对 | [issue 54](https://github.com/misakamikotoghr-5205/dehoudang/issues/54) 交给 G02，不改数字 |
| [STATUS.md](STATUS.md) | 处理状态 | | |

每份 `<ID>.md` 单列「演出块」：哪张牌、哪一拍（字段写成 `stage.intro[0].brief` 这种路径）、规则、依据、建议改法。没有演出块时只写「本轮无演出块」，不编造。

## “必须改”怎么处理

1. 问题写进 `docs/cards/review/<ID>.md`（牌 id、字段、规则、依据、给主人的改法。字段是 `brief` / `tags`，1.3 起还有演出块里的 `stage.….brief`，演出块单独一节。不写成品正文、不写台词）。
2. 对方 PR 合入并写了“交付”之后，开 `[K13→K0x]`。对方在自己的分支改。
3. 合入后再跑 `wording_lint.py`，结论写回本表，issue 里确认。没改的标 `blocked`。

当前一行都还没进第 2 步。
