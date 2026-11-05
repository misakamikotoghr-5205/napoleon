# 发行审核（增量 · 当前集成 tip）

这次只审**当前集成分支 tip**，不是「未合并 W2 修复的组合 SHA」。那个组合 SHA **还不存在**，不能把各 PR 上分开的 PASS 加成一次全绿。

| | |
|---|---|
| 集成分支 | `claude/festive-ride-vud32a` |
| 本次 tip | `97fe4ee1bf982b1a999d4593d73a83af388f056e`（#147 #163 #156 #160 #173 已在上面；再往前的 tip 是 `8d8ca97`） |
| 本分支跑审核时的 HEAD | `2aa1d58dc4a5ba6a1da613c6a92bd309f94a3e58`（把上面的 tip 合进 `cards/K15-audit-followup`） |
| 暂存目录相对 tip 多出来的东西 | 没有。`tools/**`、`docs/**` 不进暂存。本分支多的是审核工具的 else 守卫（`audit.py` 与夹具），只影响第 5 项怎么扫，不改变被审的牌数据 |
| 不在这次树上的 | K12 #161、K10 #162、C01 #42、C08 #37、G01 的 V11 白名单实现、G01 schema 中日韩、C12 的 `pages.json` 依赖、配色 #74。都还没合进 tip，**这次数字不含它们** |

- time: 2026-10-15T08:17:35Z
- staging: `/tmp/k15-tip-staging`
- stage: `STAGED 419 files, 7601262 bytes`（上次 `8d8ca97` 是 419 个文件、7598546 字节）
- godot: Godot Engine v4.7.stable.official.5b4e0cb0f
- 命令：`python3 tools/cards/audit/stage_ship.py /tmp/k15-tip-staging`，然后 `audit.py` 对这个暂存目录、`--godot=/tmp/godot/Godot_v4.7-stable_linux.x86_64`，**没有** `--pck`
- pck: 未传 `--pck`。第 9 项按工具约定不跑，记 OK。**不代表包已复查。**

`audit.py` 标准输出每项最多 80 条。第 2 项实际 7501 条，stdout 是前 80 条加 `… and 7421 more`。下面的条数来自同一次运行的完整问题列表，不是那 80 条。

## 结论

**W2 完成条件仍未满足。** 合同要的是演练之后只剩「正文/美术未写」。这次不是。也还不是「代码/引用/路径/工具类为 0」——那是等获准修复都进**同一个**组合 SHA 之后才谈的门，这个 SHA 现在没有。

`audit.py` 退出码 **1**，最后一行：

`AUDIT FAILED: 7520 problems`

上次对 `8d8ca97` 是 `AUDIT FAILED: 7529 problems`。少了 9 条，因为 tip 上已经合入的 #147 / #163 消掉 19 条引用问题，#163 新碎片又添了 10 条正文未写。没有把 V27 / V12 / V16 / V36 / V11 / 第 5 项中日韩或颜色改成跳过。

| 类 | 上次 | 这次 | 差 | 算不算「正文/美术未写」 |
|---|---:|---:|---:|---|
| 正文未写（V27） | 7282 | 7292 | +10 | 是。人（A/B）还没写 `data/cards/text/**` |
| 正文目录不存在，第 2 项另计 | 1 | 1 | 0 | 是。同一件事 |
| 第 6 项因没有正文跑不了判词、百分号、措辞 | 1 | 1 | 0 | 是。不是措辞工具缺失 |
| 第 7 项因没有正文跑不了字体覆盖 | 1 | 1 | 0 | 是 |
| 第 3 项来源表不在 | 1 | 1 | 0 | 是。`legal/**` 归人 |
| 第 4 项暂存目录没有图片或音频 | 1 | 1 | 0 | 是。`art/cards/**`、`audio/cards/**` 还没有可进包的文件 |
| 第 8 项正式配色不在 | 1 | 1 | 0 | 是人还没交的内容（A，`palette.json`） |
| V12 美术 id 不在清单 | 190 | 190 | 0 | **否。归 K12。#161 未合，本任务不改清单** |
| V16 weight 0 发不出来 | 21 | 8 | −13 | **否。剩下 8 条都是大命运，归 K10（#162 未合）。13 张留牌已由 tip 上的 #147 清掉** |
| V36 大命运没有扇区引用 | 8 | 8 | 0 | **否。归 K10。#162 未合** |
| V11 引用不存在 | 7 | 1 | −6 | **否。剩下的是 `'{person}'`。#173 只写了合同，校验器还没实现白名单。本任务不放宽 V11** |
| 第 5 项骨架 JSON 里有中日韩 | 11 | 11 | 0 | **否。归 G01。允许表不改** |
| 第 5 项 `data/pages.json` 有中日韩 | 1 | 1 | 0 | **否。归 Claude；C12 的 preload 把它带进发行图** |
| 第 5 项颜色字面量 | 2 | 2 | 0 | **否。归 C01。#42 未合。颜色检查不放宽** |
| 第 2 项校验进程非零的汇总行 | 1 | 1 | 0 | 不是独立的一类 |
| **合计** | **7529** | **7520** | **−9** | |

非「正文/美术未写」一共 **221** 条（V12 190 + V16 8 + V36 8 + V11 1 + 第 5 项 14）。上次是 240。少掉的 19 条是 tip 上已经合入的引用修复，不是这次把检查关掉。剩下的 221 条仍然失败，审核退出码保持 1。

第 1 项 OK。第 9 项未跑（没有 `--pck`），OK，不代表包已复查。第 10 项报告写得出，OK。

校验器另有一行 NOTE，**没有**算进 7520：`NOTE: -: -: V01 docs/cards/ownership.json not found; owner check skipped`。`docs/**` 不进暂存目录。不是失败。

## tip 上已经发生的，和还没发生的

已经在 `97fe4ee` 里，并且这次数字对得上：

- **#147（K09）**：`common/kept.json` 的 V16 从 13 条变成 0。`kp.sunfu_intro` 的 V11 没有了（现在引用 `kp.sunfu_letter`）。
- **#163（K08）**：1939 那 5 条悬空碎片的 V11 没有了（`df.guanjia.1939.snub`、`df.ma.1939.grudge`、`df.ma.1939.grudge_refused`、`df.nf1939d.1939.return`、`df.wu.1939.cold`）。这 5 张新碎片各有一条缺 `body` 和一条来源不合格，所以 V27 +10，都落在 K08 / `dossier/`。校验器牌数 1086 → 1091。
- **#173**：合同写下 V11 只对完整等于 `{person}` / `{uid}` / `{item}` 的值做引擎代入。`scripts/cards/core/validate_main.gd` **没有**在这次 tip 里改。`ev.any.demand_return` 的 `'{person}'` 仍是 `V11 person reference '{person}' does not exist`。不把文档合入当成实现已完成，也不在 K15 里跳过它。
- **#156、#160**：测试夹具和上一份审核报告。`scripts/tests/**`、`docs/**` 不进暂存，不改变这 7520 条。

还没有合进来，所以对应失败还在：

- V12 190：K12 #161
- V16 8 与 V36 8：K10 #162（同一批大命运）
- V11 的 `'{person}'`：G01 实现，不是 K15
- 骨架中日韩 11：G01
- `data/pages.json`：Claude / C12
- `card_theme.gd` 两处颜色：C01 #42
- 正文、图、来源表、正式配色：人（A/B）

## 工具各节

| 项 | 结果 | 条数 |
|---|---|---:|
| 1 草稿键与不该进包的路径 | OK | 0 |
| 2 validate --mode=ship 与正文来源 | FAIL | 7501 |
| 3 被引用的美术 id | FAIL | 1 |
| 4 图片音频白名单与旧素材哈希 | FAIL | 1 |
| 5 中日韩、颜色字面量、占位音频守卫 | FAIL | 14 |
| 6 判词、百分号、措辞检查 | FAIL | 1 |
| 7 字体覆盖 | FAIL | 1 |
| 8 正式配色来源 | FAIL | 1 |
| 9 .pck 复查 | OK（未传 --pck，包未审） | 0 |
| 10 报告 | OK | 0 |

第 2 项的 7501 = 7499 条 `DATA ERROR` + `data/cards/text is missing; human provenance cannot be checked` + `validate --mode=ship failed (exit 1, last line 'CARDS VALID 1091 cards, 7499 errors')`。

`DATA ERROR` 按规则号：

| 规则 | 上次 | 这次 |
|---|---:|---:|
| V27 | 7282 | 7292 |
| V12 | 190 | 190 |
| V16 | 21 | 8 |
| V36 | 8 | 8 |
| V11 | 7 | 1 |

没有别的规则号。

## 正文未写（human，A/B）

7292 条 V27 仍然是一对一对的：每条缺正文配一条来源不合格。

| 句子 | 条数 |
|---|---:|
| `text provenance must be human:A\|B:date` | 3646 |
| `missing human text '<字段>'` | 3646 |

没有第三种 V27。第 6 项没能开跑，是因为正文目录不存在，不是 `wording_lint.py` 缺失。

缺的字段（次数是 V27 的一半）：

| 字段 | 上次 | 这次 |
|---|---:|---:|
| `body` | 844 | 849 |
| `t` | 766 | 766 |
| `title` | 544 | 544 |
| `lines.greet` | 159 | 159 |
| `outcomes.ignored` | 92 | 92 |
| `name` | 88 | 88 |
| `outcomes.success` | 74 | 74 |
| `outcomes.fail` | 74 | 74 |
| `word` | 72 | 72 |
| `say` | 66 | 66 |
| `bubble` | 66 | 66 |
| `lines.issue` | 48 | 48 |
| `desc` | 41 | 41 |
| `slots.man` | 40 | 40 |
| `verse` | 35 | 35 |
| `gloss` | 35 | 35 |
| `choices.refuse` | 30 | 30 |
| `choices.pay` | 24 | 24 |
| `slots.cash` | 23 | 23 |
| `slots.talker` | 21 | 21 |
| `choices.endure` | 19 | 19 |
| `done` | 18 | 18 |
| `failed` | 18 | 18 |
| `choices.tell` | 16 | 16 |
| `slots.favor` | 15 | 15 |
| 其余 165 种字段 | 413 | 413 |

只多了 5 个 `body`，就是上面那 5 块新碎片。

骨架归属（人写覆盖层，不把骨架任务当成正文作者）。只有 K08 变了：

| 骨架归属 | 上次 | 这次 |
|---|---:|---:|
| K08 | 966 | 976 |
| K07 | 646 | 646 |
| K04 | 554 | 554 |
| K01 | 518 | 518 |
| K06 | 462 | 462 |
| K05 | 460 | 460 |
| K02 | 458 | 458 |
| K16 | 450 | 450 |
| K10 | 440 | 440 |
| K03 | 390 | 390 |
| K09 | 364 | 364 |
| K11 | 308 | 308 |
| C15 | 180 | 180 |
| Claude | 136 | 136 |
| C03 | 112 | 112 |
| human | 94 | 94 |
| C04 | 88 | 88 |
| C02 | 66 | 66 |
| G02 | 66 | 66 |
| C05 | 48 | 48 |
| G04 | 48 | 48 |
| C12 | 46 | 46 |
| C10 | 44 | 44 |
| G03 | 44 | 44 |
| C11 | 38 | 38 |
| C16 | 38 | 38 |
| C06 | 36 | 36 |
| G05 | 36 | 36 |
| C13 | 32 | 32 |
| C14 | 30 | 30 |
| G06 | 30 | 30 |
| C07 | 28 | 28 |
| C09 | 22 | 22 |
| G01 | 4 | 4 |

按目录，只有 `dossier/` 从 786 到 796，其余与上次相同：`era/` 2634、`ui_keys/` 1310、`demand/` 636、`minigames/` 530、`fortune/` 424、`guide/` 368、`common/` 328、`news/` 172、`text/` 94。

`missing_text.py` 是给 A/B 的清单，不是审核门禁，退出码 0。上次提交里的 `missing_text.md` 只有 101 条，而且没有牌面 id，和现在的校验对不上。这次按工具在本 tip 上重跑：

`MISSING TEXT 1976 entries, A=1327 B=649`

写入 `docs/cards/audit/missing_text.md` 和 `missing_text.json`。按类型：ui_key 652、dossier_fragment 362、person 159、obs 111、codebook 72、guide_step 66，其余见文件头。抽了一条真 brief（新手指引步骤那句）对这两个文件做子串检查，不在里面。本任务没有写 `data/cards/text/**`，也没有写玩家能读到的句子。

## 美术、音频、配色还没交（human）

- 第 3 项只报了 `legal/ASSET_PROVENANCE.csv is missing` 就返回。来源表归人。没跑到的逐条哈希不算额外失败，也不算通过。
- 第 4 项：`staging has no image or audio file to whitelist`。
- `data/cards/art/manifest.json` 仍是 235 个 id，其中 `legacy: true` 114 个；每条都有 `human` 路径，磁盘上存在的是 0 个。正式图还没进 `art/cards/**`。清单这次没改。
- 第 8 项：`data/cards/theme/palette.json is missing`。开发配色不进包。

## 不是正文/美术未写（仍然失败，不要在 K15 里改掉）

### V12：190，与上次相同（主人 K12，#161 未合）

句子全是 `V12 unknown art id`。归属计数与上次相同：K04 44、K02 36、K06 36、K10 27、K09 25、K08 22。

### V16：8（主人 K10）

`common/kept.json` 上一次的 13 条留牌这次没有了。剩下的和 V36 是同一批大命运：

- `era/1938/big_fate.json: bf.1938.bail_shop: V16 weight-zero card is unreachable`
- `era/1938/big_fate.json: bf.1938.night_cargo: V16 weight-zero card is unreachable`
- `era/1939/big_fate.json: bf.1939.gate_passage: V16 weight-zero card is unreachable`
- `era/1939/big_fate.json: bf.1939.rice_hoard: V16 weight-zero card is unreachable`
- `era/1940/big_fate.json: bf.1940.night_road: V16 weight-zero card is unreachable`
- `era/1940/big_fate.json: bf.1940.yamen_crate: V16 weight-zero card is unreachable`
- `era/common/big_fate.json: bf.any.quiet_fee: V16 weight-zero card is unreachable`
- `era/common/big_fate.json: bf.any.street_bed: V16 weight-zero card is unreachable`

### V36：8（主人 K10，#162 未合）

句子是 `V36 big fate needs weight zero and a wheel-segment reference`，id 与上面 8 条 V16 相同（K02 的 `bf.1938.bail_shop`、`bf.1938.night_cargo`、`bf.any.quiet_fee`、`bf.any.street_bed`；K04 的 `bf.1939.gate_passage`、`bf.1939.rice_hoard`；K06 的 `bf.1940.night_road`、`bf.1940.yamen_crate`）。扇区文件这次没改。

### V11：1（不是 K15 的跳过）

- `demand/demand_return.json: ev.any.demand_return: V11 person reference '{person}' does not exist`（文件归属 K07；白名单实现归 G01）

上次另外 6 条（5 块 1939 碎片、`kp.sunfu_intro`）在 tip 上已经不报。

### 第 5 项：14，与上次相同

没有占位音频守卫失败。else 守卫的修正还在工具里（同缩进的 `if CardShip.is_ship():` / `else` 不再被当成没守卫；别的 `else` 仍然失败）。这 14 条都不是那一类误报，没有为了消掉它们去改允许表或颜色名单。

骨架说明里的中文不在 `cjk_allowlist.json`，文件归 G01：

- `data/cards/_schema/big_fate.json`
- `data/cards/_schema/demand.json`
- `data/cards/_schema/event.json`
- `data/cards/_schema/fate.json`
- `data/cards/_schema/life.json`
- `data/cards/_schema/news.json`
- `data/cards/_schema/night.json`
- `data/cards/_schema/pawn_ticket.json`
- `data/cards/_schema/person.json`
- `data/cards/_schema/prison.json`
- `data/cards/_schema/street.json`

`data/pages.json` 有中日韩。文件归 Claude。它进暂存目录，是因为 C12 的 `scripts/cards/minigames/spot/spot_game.gd` preload 了 `res://scripts/core/appraise.gd`，那个脚本读 `res://data/pages.json`。

颜色字面量在 C01 的 `scripts/cards/ui/common/card_theme.gd`：

- 第 21 行 `Color.MAGENTA`
- 第 64 行 `Color.html(str(d["colors"][k]))`

放过名单仍然只有 `Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1[, a])`。

## 本任务没有做的事

- 没有改 `cjk_allowlist.json`、牌数据、美术清单、签文扇区、`palette.json`、`card_theme.gd`、夜牌或牌桌界面、法律来源表。
- 没有把 V11 / V12 / V16 / V36 / 第 5 项改到绿，也没有让 `audit.py` 靠跳过这些检查退出 0。
- 没有出 `.pck`，没有声称包已复查。
- 没有把未合并的 W2 修复合成一个 SHA。上面的 7520 只描述 `97fe4ee` 这个 tip。

AUDIT FAILED: 7520 problems
