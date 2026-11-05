# M4 审计：顾客一 林嫂（活当金簪）

审计对象：data/sessions/d2_linsao.json, data/items/gold.json, data/cast.json (linsao), data/story/day2.json, data/story/d2_farewell.json, scripts/core/director.gd, scripts/core/session.gd, scripts/core/ledger.gd, docs/INTERFACES.md。
设计依据：story_sub2_剧本提示词.md 572–606 行，568 行（写破旧规则），660–661 行（哥哥告别），799–830 行（状态变量）。
方法：逐行对照文本；无头探针 /tmp/linprobe/probe.gd（不在仓库内）调用 Session.offer 测试各价位。

## 节拍表

| # | 节拍 | 判定 | 证据 / 说明 |
|---|---|---|---|
| 1 | 入场旁白“一个怀孕的年轻妇人…” | OK | d2_linsao.json:23-25 (pre) 原文一致 |
| 2 | 林嫂 3 句台词（爸妈/满月金锁/丈夫汇款） | OK | json:29-45 逐字一致 |
| 3 | 要价 150 / 底价 100（底价隐藏） | OK | json:10-11；show_floor=false (json:15) |
| 4 | 建议当本 160，市价 200 | OK | json:12；gold.json "market":200, "suggest":160 |
| 5 | 检查结果 4 部位逐字（戳记/成色/称重/珍珠） | OK | gold.json parts 逐字一致；weigh 需小秤，day1.json:6 已解锁 |
| 6 | 检查前不许谈价（教学门槛） | MISSING | json 无 "require"/"min_inspect"（session.gd:333-344 不生效）。探针：未看任何部位即可出价 |
| 7 | 成色栏选项须“从鉴定结果里选” | PARTIAL | director.gd:396 无论是否验过，都把真值“足金，珠有小缺”放在选项里（剧透） |
| 8 | 当票重量：仅称重后显示“三钱二分” | OK | session.gd:179 设 weighed；director.gd:395 |
| 9 | 出价 ≥160（口碑+3，本心+1，fair） | OK | 探针：160/170/200 均 accept；json:100-121 |
| 10 | 出价 150–159 与 131–159 | DESIGN GAP | 探针：131–150 accept；json:123-132 设 fair 但无任何数值变化。设计稿没写 131–159 的效果 |
| 11 | 压价 100–130（本心-2，low） | OK（概率） | 探针：110 accept；100 只得 counter 到 124。成交与否由 NPC 大脑决定（session.gd:388），不保证一次出价即成 |
| 12 | 破旧：本心-2，lin_ticket_old=true | OK | director.gd:533 benxin -2；json:151-158 flag；ledger.gd:116 合同记 ticket_old |
| 13 | 破旧 → 哥哥“只是林嫂那张当票”台词 | OK | d2_farewell.json:8-10 |
| 14 | 赎当时她发现 → 口碑-3 | MISSING | 全仓库无 redeem 操作/界面：ledger.gd:129 的 redeem() 无调用方；data/story 无赎当节拍。spec 568 行要求口碑-3 |
| 15 | 拒收（口碑-2，lin_pawn=refused） | OK | json:74-96 deals.refuse；可达（按钮常驻） |
| 16 | 压价走人（session leave） | PARTIAL | session.gd:401 好感-1/-3；json:174-178 on_leave 置 refused；但不扣口碑-2，与“拒收”不一致。设计稿未规定 |
| 17 | 成交台词“红蛋先给你送来” | OK（无后续） | json:170-172；之后无红蛋/满月节拍 |
| 18 | 伏笔线索 第32天 | OK | json:162-168 note inferred；world.gd:573 也提示“当期到第32天” |
| 19 | 到期日 = 第 32 天 | OK | day2.json 第二天 → open_pawn(day 2, 30) → due_day 32（ledger.gd:116）；探针：date_text(32)=三月初六。逾期从第33天起（ledger.gd:152，符合“到期日”） |
| 20 | 丈夫汇款 150（船行） | OK | world.gd:570-573；cast.json:969 船行账户存在，守恒 |
| 21 | 金锁定钱 100 给银楼 | OK | world.gd:372-373；林嫂 cash=30，若当 ≥100 则能付 |
| 22 | 林嫂好感（favor）是否变化 | 未规定 | 成交：不变；拒收：不变；压价走人：-1/-3（session.gd:401）；进场：仅 familiarity +0.05（director.gd:297）|
| 23 | 追问丈夫 extra（非设计稿内容） | WRONG（措辞） | json extras 第一句“三个月没音信”与设计稿“三个月没汇钱回来”不符；且整段为新增，未标注 |
| 24 | 出价≥150 正好等于要价时台词 | WRONG（小） | cast.json linsao.accept_happy“比我要的还多”；探针 150 时也说此句（session.gd:366-368） |

## 关键结论
- 破旧的“口碑-3 当户发现”没有任何实现，活当赎回整条链路（ledger.redeem、赎当 UI、到期处理的剧情钩子）都缺。合同上的 ticket_old 字段已记录（ledger.gd:116），只差消费者。
- 检查门槛缺失：林嫂可以不看一个部位就谈价，且成色选项泄露真值。
- 价格分支 131–159 在设计稿中没有定义，代码自行判为 fair 且无数值变化。
- lin_pawn 与 lin_ticket_old 目前只被 d2_farewell 读取一次（lin_pawn 完全无读取方），属于写入但不消费的标记。

## Fix list
1. d2_linsao.json：加 `"require": ["hairpin.stamp", "hairpin.color", "hairpin.weigh", "hairpin.pearl"]`（session.gd:340 已支持），让检查先于议价，也保证称重后才有重量。
2. director.gd:396：成色选项的真值文字仅在 color 与 pearl 两部位已验后显示；否则显示“如实：（未鉴定）”或隐藏该选项。
3. 新增赎当节拍（建议 day 2 之后的 day_flows 或一个 redeem 操作）：调用 ledger.redeem；若 contract.ticket_old 为真，执行 stat koubei -3 并 note“林嫂发现当票写了破旧”；同时补红蛋/满月后续（可先留 TODO，写进 README_CN.md）。
4. 补 INTERFACES.md §12：新增 `redeem` 操作与口碑-3 规则，否则无人实现。
5. 设计决定：131–159 段是否需要效果（建议：不变；在 json:123 注释写明），以及压价走人是否扣口碑-2（建议：与拒收统一，或在设计稿里写明）。
6. session.gd:366-368 或 cast.json linsao.accept_happy：仅当 v > ask 时用“比我要的还多”，等于 ask 时用 accept。
7. d2_linsao.json extras（ask_husband）：把“三个月没音信”改为“三个月没汇钱回来”，并在 README 标注为新增对话。
8. 好感：在设计稿或 INTERFACES 中明确林嫂好感是否随成交/拒收变化，并让 session.gd:401 的处理与拒收一致。
9. director.gd:453 的 "refuse" 动作分支无人产生，可删除以免误导。
