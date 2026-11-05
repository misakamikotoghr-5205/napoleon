# M3 审计：顾客一小丁（收米，第一天）

审计范围（只读，未改游戏文件）：data/sessions/d1_xiaoding.json、data/items/rice.json（rice_sunji）、data/story/day1.json、data/story/day1_close.json（相关打烊台词）、data/cast.json（xiaoding）、data/pages.json（rice_grades）、scripts/core/{session,director,cond,ledger,world}.gd、scripts/ui/{main,sidebar}.gd。
设计依据：/workspace/gamejev-docs/story_sub2_剧本提示词.md 第一天小丁段（约 L343–393）、打烊（L520–535）、一、米（L110–134）、数值与状态变量（L799–817）。
方法：静态通读 + 无头探针。/tmp/xdprobe/probe.gd、probe2.gd 直接调用 Session.offer；/tmp/xdprobe/drive.gd 用 Director.run_session("d1_xiaoding") 跑完整会话（场景 A–I，真实 on_accept/deal/choice/stow 流程），未报告脚本错误。

## 逐拍对照

| # | 设计稿拍点 | 状态 | 证据 / 说明 |
|---|---|---|---|
| 1 | 哥哥教学台词（收米先问…） | OK | d1_xiaoding.json `pre[0]` 文字与设计稿逐字一致 |
| 2 | 档案簿新增“米的等级”表 | OK | `pre[1]` page rice_grades → data/pages.json:11；档案簿分页读取 world.pages |
| 3 | 放大镜高亮 | MISSING | main.gd:511-529 `_open_counter` 从不设置 `view.highlight`；会话里没有任何高亮（只有教学与 stow 会设） |
| 4 | 放大镜至少检查三处 | OK | `min_inspect: 3`；director.gd:481 拦截谈价；sidebar.gd:276-277 显示进度（已探针验证） |
| 5 | 入场旁白（瘦高后生、米袋） | OK | `intro[0]` |
| 6 | 小丁两句台词 | OK | `intro[1]`、`intro[2]` 逐字一致 |
| 7 | 真实物品：粳米乙等，市价 68 | OK | rice.json rice_sunji：grade 乙，market 68（90×75%） |
| 8 | 初始模糊估价 40–90 | OK | rice_sunji.est [40,90]；session est 同 |
| 9 | 要价 50 / 底价 25，底价可见 | OK | d1_xiaoding.json ask 50, floor 25, show_floor true；sidebar.gd:273 显示“客人底价” |
| 10 | 建议收购价 约 40（市价×60%） | PARTIAL | `"suggest": 40` 硬编码（session 与 rice.json:suggest 都是）。68×0.6=40.8，四舍五入应为 41；【实现】要求用公式算 |
| 11 | 检查：捧一把 → 短圆半透明，本地粳米 | OK | parts.grain.text 逐字一致 |
| 12 | 检查：放大镜 → 碎米三成，乙等 | OK | parts.broken.text 逐字一致 |
| 13 | 检查：闻气味 → 干爽无霉味 | OK | parts.smell.text 逐字一致 |
| 14 | 检查：翻米袋 → 孙记 + 标记“发现赃物” | PARTIAL | 文字 OK；标记实际是 flag `found_sunji`（rice.json parts.bag.flag），不叫“发现赃物”，命名不一致 |
| 15 | （设计稿结果表没有）对光看颜色 | EXTRA | rice.json parts.color 是第 5 处检查。与米章节的检查方法一致，可保留，但设计稿结果列表里没有它 |
| 16 | 追问来路（发现孙记后可选，只一次）+ 哥哥小声“赃物…” | OK | extras[0]，when is('found_sunji')，once；两句台词逐字一致（场景 I 验证） |
| 17 | 行 1：公道 35–50 → 口碑+2，xiaoding_rice=fair，米入库带孙记 | OK | on_accept[0]、[1]；场景 A（40）口碑 +2；场景 B 保留 孙记 标签 |
| 18 | 行 2：压价 <30 → 本心−3，xiaoding_rice=low | PARTIAL | 场景 B（25）本心 −3、low 正确。但只能成交在 25–29：Session._offer_buy 的 `v >= floor_v` 门槛使 <25 永不成交（20 只会 plead） |
| 19 | 行 3：收下但拆“孙记”袋 → 风险−1，rice_bag_swapped=true | PARTIAL | 标记与去标签 OK（场景 A）。“风险−1”无效：suspicion 初始 0，world.gd:98-101 clamp 到 0，场景 A 结束仍为 0 |
| 20 | 行 4：拒收劝送回 → 本心+1，xiaoding_rice=refused，米还给小丁 | OK | 场景 D：benxin +1，refused，米 → npc:xiaoding |
| 21 | 行 5：拒收另借 20 → 钱−20，本心+4，口碑+2，xiaoding_loan=20 | OK | 场景 C：钱 600→580，本心 +4，口碑 +2，债 D01，小丁账户 20（ledger.open_debt 真实转账）。gate `cash() >= 20` |
| 22 | 成交台词“多谢小掌柜……你别跟别人说” | OK | on_accept 末条；场景 A/B/G/H 均出现；拒收路线不出现（正确） |
| 23 | 伏笔：第 3 天小丁回来买药（看 xiaoding_rice） | MISSING | v0.1 范围外，没有第三天会话。flag 会保留，可接受，记入 README 的 TODO |
| 24 | 打烊：“孙家的米…别拿出去卖”“借出去的钱，就当没借” | OK | day1_close.json 两条，条件与设计稿一致（var said<3） |
| 25 | 数值：xiaoding_loan 0/20，rice_bag_swapped true/false | PARTIAL | 未设置时为 null 而非 0/false。c_is 能处理，但 `flag()==0` 类判断不稳 |

## 可达性模拟（探针结果）

- 公道价 35–50：可达。40 成交，口碑 +2。
- 收下但换袋：可达，任何成交价都会弹出（on_accept choice 不受价格限制，场景 A 用 40）。前提是检查过“翻米袋”（found_sunji）。如果玩家用其他三处凑够 3 次检查，就看不到换袋选项，该行不可达。
- 压价 <30：只能在 25–29 成交（场景 B 25 直接成交）。20 → plead（无状态变化，可再出价）。5/10/14 → 小丁走人（场景 F）。
- 拒收+借钱：当 cash()>=20 时可见。第一天钱匣恒为 600，所以一直可见；钱不足 20 时隐藏，不报错，只剩“劝送回”。
- 30–34（设计稿没有这一档）：30 与 34 成交，标记 fair，口碑 0（场景 G）。32 → plead。
- 高于要价（55）：小丁照收，付 55，口碑 +2（场景 H）。设计稿没有 >50 这一档，这是可以刷口碑的漏洞。
- 侧边栏“推回去（不收）”按钮（sidebar.gd:141,154 → director.gd:445-448）绕过 refuse_return：标记 refused，本心 +0，没有借钱选项（场景 E）。
- NPC 走人（场景 F，出价 10）也把 xiaoding_rice 设为 refused（on_leave，director.gd:502），和“拒收”无法区分。

## Fix list（按优先级）

1. [High] 推回去按钮绕过“劝送回”的本心+1，并把走人标记为拒收。director.gd:445-448 的 `refuse` 分支：若会话有 deals，执行 deals 中 refuse_return 的 steps；或在 sidebar.gd:254/280 对带 deals 的会话隐藏 refuse_btn。
2. [High] 走人与拒收混淆。d1_xiaoding.json `on_leave` 改为 `[{"op":"set","flag":"xiaoding_walked","value":true}]`，不再写 xiaoding_rice；第三天若需要，把 walked 视为 refused。
3. [High] 超过要价仍全额付款，并给口碑。session.gd `offer()` 在 buy 模式下令 `v = mini(v, ask)`（价格记 ask），并删除 d1_xiaoding.json on_accept 中 `price() > 50` 的两条（koubei +2 那条）。
4. [Medium] “风险−1”无效。d1_xiaoding.json choice.keep.steps 加 `{"op":"stat","stat":"suspicion","delta":1,"why":"原样收着孙家的赃米"}`，让换袋相对原样有差别；或与设计师确认后在 notes 里说明。
5. [Medium] 米被当作收购品后，stow 提示给出“扔进垃圾箱”。director.gd:548-552 与 main.gd:337-339：食物类（cat rice）的买断品不弹 stow，直接留在 stock；同时把“推进典当盒”的提示文字改为买断品不适用。
6. [Medium] 放大镜未高亮。main.gd:511-529 `_open_counter`：`view.highlight = ["magnifier"] if s.needs_more_inspection() else []`，并在 inspect 后刷新。
7. [Medium] 30–34 档没有设计依据。需要设计师确认：建议写成“30–34 fair，口碑 0”，并写进设计稿与 d1_xiaoding.json 的注释。
8. [Low] suggest 硬编码 40。session.gd setup 对 buy 模式用 `round(market * 0.6)`（得 41），或把 d1_xiaoding.json 与 rice.json 的 suggest 改为 41。
9. [Low] 标记默认值。world.gd 初始化 flags：`xiaoding_loan = 0`、`rice_bag_swapped = false`，`xiaoding_rice` 设 `""`。
10. [Low] 标记名对齐。rice.json parts.bag.flag `found_sunji` 与设计稿“发现赃物”之间，加一个 `found_stolen` 别名，或改名。

探针结论：9 个场景都没有脚本错误。进程退出时的 ObjectDB 泄漏警告来自探针本身，与游戏无关。

## Re-check (M3 after fixes)

复核方法：静态读当前文件；无头探针 /tmp/recheck/probe.gd；plans d1_fair_swap、d1_low_keep_iou_burned 均 PLAYTHROUGH OK、exit 0。

- Fix 1 推回去 绕过 — RESOLVED。sidebar.gd:292 `refuse_btn.visible = not has_deals`，d1_xiaoding 有 deals，通用按钮不可见。
- Fix 2 走人 = 拒收 — STILL OPEN。d1_xiaoding.json on_leave 仍 set xiaoding_rice=refused（_note 也写明“走人仍记 refused”）。改为 xiaoding_walked。
- Fix 3 超价照收 + 口碑 — STILL OPEN。探针 offer(55) → result accept, price=55；session.gd 的 offer/_offer_buy 无钳制；on_accept 仍有 price()>50 的口碑 +2 与 fair。
- Fix 4 风险-1 — ACCEPTED-AS-DECISION（风险-1 = suspicion -1）。注意：当日 suspicion 为 0，world.gd:116 clamp 使其成空操作，换袋在“怀疑”上无可见差别。
- Fix 5 买断米弹 stow — STILL OPEN。director.gd:548-555 买断后对 stock 中所有物品弹 stow（pawnbox/trash），未对 cat rice 豁免。
- Fix 6 放大镜高亮 — STILL OPEN。main.gd:294 每拍清空 highlight；_open_counter（main.gd:511-529）从不设 highlight=["magnifier"]。
- Fix 7 30–34 档 — ACCEPTED-AS-DECISION（价格分档保留）。d1_xiaoding.json _note 已记录 30–34 fair、口碑 0。
- Fix 8 suggest 硬编码 — RESOLVED。session.gd:66 buy 模式 `suggestion = calc_buy_suggest()`；探针 suggest=41（68×0.6）。json 的 40 仅为文档。
- Fix 9 标记默认值 — PARTIAL。d1_xiaoding.json pre 设 xiaoding_loan=0、rice_bag_swapped=false；world.gd:26 flags 无默认值，xiaoding_rice 仍未初始化。
- Fix 10 标记别名 — RESOLVED。on_inspect bag_sunji（d1_xiaoding.json）设 found_stolen；plan 结束标记 found_stolen=true。

NEW defects:
- N1 [Low] 换袋 suspicion -1 在 0 时无效（见 Fix 4），若设计要“风险”有感，需 Fix 4 的 keep 侧 +1 或设计确认。
- N2 [Low] 小丁走人后 xiaoding_rice=refused 与拒收不可区分（同 Fix 2），第三天若接入会误判。
