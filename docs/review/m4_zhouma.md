# M4 审计：顾客二 周妈（买米）

审计范围：data/sessions/d2_zhouma.json、data/items/rice.json、data/cast.json、scripts/core/{director,world,session,cond}.gd。未改游戏文件。
行号为审计时（world.gd 664 行、director.gd 951 行，审计期间有并行改动，以当前为准）。
探针（只读，/tmp/zm_audit/probe.gd、probe2.gd）：`godot --headless -s` 直接跑 World。

## 节拍表（对照剧本 story_sub2 607–623 行）

| 节拍 | 状态 | 证据 | 修法 |
|---|---|---|---|
| 入场 narr + 台词 | OK | d2_zhouma.json:29-40 | — |
| 库存有米→卖货；没米只闲聊 | PARTIAL | intro 条件 d2_zhouma.json:43 `stock_cat('rice') == 0`（cond.gd:38）算了库存里全部米；但 `stock` 列表(:5-10) 不含 rice_mold_d（粳米丁，rice.json）。只剩霉米时不进闲聊，柜台打开却无可卖物（_setup_sell 只收 stock 列表，session.gd:84-94）。 | 把 :43 和 :61 的条件改成 `stock_has('rice_sunji') or stock_has('rice_jing_a') or stock_has('rice_xian_b') or stock_has('rice_nuo_c')`；director.gd:880-900 的 pick 候选也要排除霉米。 |
| 乙等粳米 市价 68 / 开口 55 / 最高 75 | OK（数值）/ WRONG（机制） | rice.json:7 market 68；d2_zhouma.json:12-15 offer 55 max 75。但 session.gd:108-115 的 offer/max 是静态表，不乘世界轮盘 `price_mod`（world.gd:166-170，rice_mod 由 world.gd:336 起的逻辑改）。建议价（session.gd:112）却乘了 mod，两者不一致；米价一涨，她还按 55 还。 | session.gd `_rescale_sell`：`o += round(offer * world.price_mod(it))`，`m += round(max * world.price_mod(it))`。 |
| 孙记袋：台词 + sun_rice_rumor=true | OK（当场） | d2_zhouma.json:89-101 | — |
| 孙府三天内派人来问 | MISSING（可玩路径） | 唯一后果在 world.gd:613-616，且只在 `_backend_day_events`（world.gd:597）里；`backend_simulate`（world.gd:585）无任何调用方。第二晚即结局，玩家永远看不到。判断 `d <= 5` 是绝对天数，不是“卖出后三天内”。 | 在 d2_zhouma.json on_accept 加 `set sun_rice_day = day`；world.advance_slot 里（非后台）若 `sun_rice_rumor` 且 `day` 在 sun_rice_day+1…+3 内，写一条街景/消息“孙府管家派人到桥头街打听米袋”；night2.json 加一句伏笔 narr（条件 flag）。删掉 world.gd:613 的 d<=5。 |
| 换过袋/其它米 顺利成交 | OK | 条件 d2_zhouma.json:90 `not is('rice_bag_swapped')`；flag 初始 d1_xiaoding.json:41，换袋 director.gd:873-879 | 可选：改成检查 tags 含“孙记”的单件物品，而不是全局 flag（全局 flag 下，未换的孙记米被误判为已换也会漏发）。 |
| 白送 → 好感 +5 | OK | gift deal d2_zhouma.json:57-86；`favor:` 前缀 world.gd:105/133 | 若 give_item 找不到米，deal 仍会 +5（director.gd:880-886 只 return）。建议 gift 的 steps 前加 `when` 检查 vars.gave。 |
| 便宜卖 → 好感 +5 | PARTIAL | d2_zhouma.json:111 `price() <= 55`。sunji 的开口价恰好是 55，所以“按她开口价成交”也算便宜卖；xian_b(43)、nuo_c(32) 任何成交都自动 +5。 | 改为相对市价：`price() < 55`，或 `price() <= 0.75 * 市价合计`（需新 cond 函数）。 |
| 白送/便宜卖 → 她每天带一条镇上新闻（zhouma_news） | PARTIAL（进行中，不在可玩路径） | 标志在 :81、:121 设置。新增 world.gd:282-292：slot==0 时把她“知道而玩家不知道”的第一条 rumor 放进 world.news；director.gd:351-353 念出“（听周妈说）…”。问题：①只在 slot 0 触发，v0.1 在 day2 夜（slot 5）结束，day3 早晨永远不到（flow.json，night2.json）；②取到的第一条是 sunji_rice（她自己 on_accept 种的），变成“（听周妈说）德厚当卖的米，袋子上印着‘孙记’”，玩家自己卖的事被当成听说，标签错；③她的已知条目用完后就没有新闻，不满足“每天”。 | 见下“每天新闻的最小机制”。 |
| 必触发告示/良民证/维持费/马保长新闻 | OK（内容）/ WRONG（重复、标签） | 硬编码 d2_zhouma.json:127-139（say + note heard via zhouma）。四个要素都在。但探针：周妈会知道 liangmin_notice（ma→zhouma 边 0.6，经 world.gd:71 开局种下，由传播得到），随后 share_rumors（d2_zhouma.json:140-146，world.gd:554）会再说一遍“办良民证…（周妈也是听别人讲的）”。玩家同一晚听两次，且第二次丢了“维持费/马保长”。另：告示贴在墙上，她是指给你看的，记成“听说”不准确。 | 给 liangmin_notice 标记已告知：在 outro 加 `{"op":"call","fn":"mark_told","args":{"key":"liangmin_notice"}}`，director.call_hook 新增 mark_told → `world.rumors[key].player_knows = true`。note 的 source 改 "seen"（或保留 heard 但文案写“贴在墙上”）。 |
| 人物表：周妈 45 岁 / 桥头茶馆厨娘 / 嘴碎热心爱打听 / 镇上消息中心 | OK | cast.json:520（sociability 0.95）；边 cast.json:901-919（zhouma→sunlaoye 0.45、→ma 0.6 等） | — |
| 孙记消息沿关系图传播 | OK | 探针：8 个时段内 sunlaoye、xiaoding 都知道 sunji_rice，sun_rice_rumor=true；world.gd:504-506 与 :462-520 传播。 | — |
| 档案簿 听说 标签 + 转述变样 | PARTIAL | share_rumors 记 source heard（world.gd:554-575）；变样文本 FACTS 466-480 OK，hop>0 带“也是听别人讲的”。但 world.gd:561 的排除列表没有 sunji_rice，周妈可能把“自家卖的米”当传闻讲给玩家（本次探针大脑选了 keep，未出现，属潜在问题）。 | 在 `plant_rumor` 加 `told` 参数，d2_zhouma.json:102-106 的 rumor op 传 `"told": true`，直接标记 player_knows。 |
| 状态变量 sun_rice_rumor / rice_bag_swapped | OK | flags 已存在（world.gd:505、director.gd:867） | sun_rice_day 需新增（见上）。 |

## 回答关键问题

1. “每天带一条镇上新闻”：原先完全没有读取 zhouma_news（grep 只在 d2_zhouma.json）。现在有 world.gd:282 的实现，但在 v0.1 可玩路径里不触发（只在 slot 0），且会先念出玩家自己的孙记事。
2. 孙记传闻：确实沿 zhouma→sunlaoye(0.45) 传开，并设 sun_rice_rumor；但“派人来问”没有可玩后果。
3. 价格：55/75 对乙粳米正确，其余米的 offer/max 与市价比例一致（约 0.8/1.1），但都是手写常数，不随米价轮盘变。
4. 玩家第一天把孙记米卖给别人、或送人、或换袋、或没米：卖给别人/送人/换袋 → 周妈看不到孙记米，不设 sun_rice_rumor（正确）。送人（白送）同样不设（剧本只写“卖”，可接受，但建议注明）。没米 → 闲聊，不设（正确，但霉米有 bug，见表）。

## 每天新闻的最小机制（建议）

- 新增 data/news/zhouma.json：`[{"day":2,"text":"告示…维持费…马保长…","key":"liangmin_notice"}, ...]`，按天索引，保证每天一条。
- world.advance_slot：触发点从 `slot == 0` 改为 `slot == 0 or slot == 5`（夜里也报一次），或在 night2.json 开头加 `{"op":"call","fn":"zhouma_news"}`。
- 取“固定日程条目”优先，没有时才回落到 rumor 池；池里跳过 `told` 的（孙记 rice 种下即 told）。
- 玩家可见：news 经 director.gd:351 念出；档案簿已由 world.gd note 记录。

## Fix list

1. d2_zhouma.json:43 与 :61 库存判断排除霉米（改为检查 4 个 stock 条目）。
2. session.gd `_rescale_sell`：offer/max 乘 world.price_mod(it)。
3. d2_zhouma.json:111 “便宜卖”阈值改为相对市价或 `< 55`。
4. d2_zhouma.json:102-106 rumor 加 `told: true`；world.gd plant_rumor 接收并写入 player_knows。
5. d2_zhouma.json:127-146：加 mark_told(liangmin_notice)，避免告示说两遍；note source 改 seen。
6. world.gd:282-292 每天新闻：改用 data/news/zhouma.json 固定条目，触发点加上夜里；跳过已 told。
7. 孙府来人：on_accept 写 sun_rice_day；world.gd 增加 3 天窗口的街景/消息；night2.json 伏笔；删 world.gd:613 的 d<=5 后台分支（或保留给后台但不作为唯一后果）。
8. world.gd:561 排除列表或 told 机制，避免周妈讲玩家自己卖出的米。
9. director.gd:880-886 gift 在 give 失败时不加好感（gave 检查）；pick 候选排除霉米。
10. 设计确认（需 Hengrui 决定，可记 HELP）：白送孙记米是否也触发 sun_rice_rumor（剧本只写“卖”）。
