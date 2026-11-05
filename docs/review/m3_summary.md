# M3 审查：第一天开场 / 打烊总结 / 第一晚（haiku-reviewer，静态审查；由主控转存）

| # | 节拍 | 状态 | 处理 |
|---|---|---|---|
| 1 | 开场：卸门板、告示红印、哥哥台词 | OK | — |
| 2 | 卸门板 / 上门板 音效 | MISSING | 新增 sfx 操作 + 程序合成门板声（主控） |
| 3 | 哥哥只在教学节点出声 | OK | — |
| 4 | 时段：上午 小丁+张护士、下午 王山、傍晚 李敬之 | OK | — |
| 5 | 二月初五 星期日 | OK | — |
| 6 | 收购建议价 = 市价×60% | PARTIAL→已修 | session.calc_buy_suggest 按实时行情计算 |
| 7 | 卖出建议价 = 市价 | OK | — |
| 8 | 底价写在顾客下方 | OK | — |
| 9 | 小丁 30–34、>50 价段（设计稿未定义） | PARTIAL | 记为假设：30–34 公道无口碑加成；>50 公道 +口碑 2 |
| 13 | 王山白送奈宁“钱 −60（成本）” | 决定 | 账本不凭空花钱：成本即该瓶奈宁的进价（库存出库并记入档案簿），不另做现金支出 |
| 17 | “上门板”重复 | MINOR→已修 | — |
| 18 | 哥哥三句话的优先级 | PARTIAL | 按设计稿表格顺序；在 day1_close.json 注明 |
| 21 | “收了孙记的米”在换袋后是否还说 | 决定 | 保留“没换袋才说”：换了袋，哥哥不必再提醒别拿出去卖 |
| 25 | 夜里“对账”应显示当日收支、库存、到期当票 | PARTIAL→已修 | 夜里对账改为弹日结账目 + 活当到期 |
| 26 | 第一晚哥哥对账时总结后离开 | PARTIAL | 采用打烊段落的读法（总结在上门板时说完） |
| 27–29 | 两件事后吹灯、★、烧垃圾旁白 | OK | — |
| 30 | 不烧垃圾被翻走只看违禁品 | MINOR | 保留：只有违禁品才招惹人 |

## Re-check (M3 after fixes)

证据：data/story/day1.json、day1_close.json、night1.json、data/sessions/d1_wangshan.json、d1_li.json、scripts/core/director.gd、session.gd、beeper.gd、README_CN.md。headless：--until=day1_done PLAYTHROUGH OK；night1_burn_tabloid PLAYTHROUGH OK。

| # | 节拍 | 复核状态 | 证据 |
| --- | --- | --- | --- |
| 2 | 卸/上门板音效 | RESOLVED | sfx door_open/door_close 在 day1.json、day1_close.json:7、night1.json:6 使用；beeper.gd:56 已实现 |
| 6 | 收购建议价 = 市价×60% | RESOLVED | session.gd:270-296 calc_buy_suggest 按 market_now×0.6 逐件求和（假货按 INTERFACES §12 规则） |
| 9 | 小丁价段 | NOT RE-CHECKED | 不在本次范围（d1_xiaoding 未读） |
| 13 | 王山白送 -60 | ACCEPTED-AS-DECISION | 白送=库存出库，d1_wangshan.json gift_quinine 无 money；README_CN.md:34 已记 |
| 17 | 上门板重复 | RESOLVED | day1_close.json:12 仅一处“上门板”，day1.json 为“卸门板” |
| 18 | 哥哥三句优先级 | ACCEPTED（文档化） | day1_close.json:4 note 写明优先级；said<3 上限在 :33-:111 |
| 21 | 孙记米“没换袋才说” | ACCEPTED-AS-DECISION | day1_close.json:33 `not is('rice_bag_swapped')` |
| 25 | 夜里对账显示日结 | RESOLVED | 夜间 ledger 动作（director.gd:621-622）调用 day_summary，含库存、借据、活当到期（:586） |
| 26 | 第一晚哥哥对账后离开 | STILL OPEN（低） | night1.json 无哥哥收尾台词；仅采用打烊读法，未写入设计稿 |
| 27-29 | 吹灯、★、烧垃圾旁白 | RESOLVED | night1.json:11-14 自动烧 + 吹灯；director.gd:899-901 旁白 |
| 30 | 垃圾翻走只看违禁品 | ACCEPTED-AS-DECISION | director.gd:787-797 仅 contraband 参与 |

决定核对汇总：白送=库存出库 ACCEPTED；本心-6 仅明知卖出 NOT MET（见 m3_wangshan.md 第 2a/7 条，告知后仍可卖且不扣）；孙记 line 仅未换袋 ACCEPTED；垃圾翻走仅违禁品 ACCEPTED。

NEW：
- NEW：无新增缺陷（day1_close 与 night1 本次无回归）。

