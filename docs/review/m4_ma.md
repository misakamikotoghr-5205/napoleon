# M4 审计：傍晚·马保长（d2_ma）

范围：data/story/d2_ma.json；scripts/core/director.gd（ma_fee 约 912，give_item 约 880，money 204，todo 214，stat 159）；scripts/core/world.gd（add 106，suspicion 118，add_todo 233，countdown_text 237，add_liability 196）；scripts/ui/sidebar.gd（countdown 188，待办 210-216）；scripts/ui/book_panel.gd（待办 144-151）。
对照：story_sub2_剧本提示词.md 712-740、808、840。

## 节拍表

| 节拍 | 结论 | 证据 / 说明 |
|---|---|---|
| 皮靴声进门（礼帽、白布臂章） | OK | json:5-6 narr + enter |
| 金额 100/150/120 随标记 | PARTIAL | director ma_fee 先判 li_paper=reported 再判 sun_young=exposed。两者可同时成立（d1 与 d2 都会发生），设计稿未定优先级，需拍板。 |
| 三句台词（沈家丫头 / 友邦 / 礼拜六还有五天） | OK | json:8-10，{fee_cn} 由 vars 替换 |
| 药分支仅库存有奈宁/磺胺时出现 | OK | json:11 stock_has('quinine'|'sulfa_fake'|'sulfa')，与设计稿一致 |
| 上交一件：怀疑 -2，维持费 -20 | PARTIAL | json:14-17。-20 与 -2 无条件执行，give_item 找不到药（cands 空）时 gave=false 仍扣费 |
| 说已经卖了：怀疑 +1 | OK | json:19-20 |
| li_paper=kept 的目光停留 | OK | json:24-26 |
| 回应 “知道了” | OK | json:28-29 |
| 当场先交一半：钱 -60，怀疑 -1 | PARTIAL | json:31-34。money 结果 vars.money_ok 从未检查，钱不够时仍扣怀疑、仍减费用。ledger 有 journal 记录（transfer，cast.json 维持会公账存在），OK 部分。 |
| 见面礼：怀疑 -2，费用 -20 | OK（有小缺口） | json:36 when=stock_cat 之和>0，库存空时隐藏，正确。give 失败时仍扣 -2/-20（同上，缺 gave 判断）。 |
| 少一点：口碑≥60 降到 100，否则冷笑怀疑 +1 | WRONG | json:44-45 用 `var fee value 100` 直接赋值。若先上交药（fee 100→80）再“少一点”，费用被抬回 100。应改为“仅当 fee>100 时置 100”。冷笑分支 OK。 |
| 哥哥出镇 / 通行证台词 | OK | json:52 |
| 账簿待办 “礼拜六：交维持费 X 蚨” | PARTIAL | json:53 todo；world.gd:233 写入 todos，文本取最终 fee（OK）。但待办不会被标记为已了/逾期，周六后仍显示“未了”。半付 60 也不在待办里体现。 |
| 上方倒计时 “距缴费还有 5 天”（周一=day2） | OK | world.gd:237-241 文案正确；due_day=7，weekday((7-1)%7)=6=星期六（world.gd:86）；day2 得 5。小问题：周六当天显示“还有 0 天”，应显示“今天缴费”。 |
| 应付（ledger 知道 120 欠着，不是钱） | PARTIAL | world.gd:31,196 已有 liabilities/add_liability，但 d2_ma.json 与 director 都没有调用它（无 op / hook）。账本里目前只有待办，没有应付。 |
| 上门板，进入夜晚 | OK | json:54 leave + narr |
| 数值：怀疑 0-10 钳制 | OK | world.gd:118 clampi(0,10) |
| 怀疑 ≥5 门外“影子”提示 | MISSING | 全仓库无“影子”字样，无任何 ≥5 判断 |
| 怀疑 ≥10 搜铺（铺子查封） | MISSING | 设计稿 840 行要求；全仓库无“搜铺/查封”逻辑 |
| 缴费日 周六 3 月 12 日 | PARTIAL | due_day 7 正确；界面日期只显示农历“二月十一”（sidebar.gd:216 split 取第 1 段，book_panel 显示整段农历），没有 3 月 12 日公历标注 |
| 费用不为负 | OK（无 clamp） | 最坏路径 100-20-60=20，不会为负；但没有 max(0,…) 保护，改动后易出错 |

## 额外发现
- 待办 status 只在 world.gd:234 创建时写入“未了”，没有任何地方改成“已了”，半付/全付都不会关闭它。
- director.gd 的 money/give 失败不会中断后续步骤（exec 不检查 vars），这是通用问题，马保长脚本是首个暴露点。

## Fix list
1. json:44-45 haggle：改为 `{"op":"if","cond":"var('fee') > 100","then":[{"op":"var","name":"fee","value":100}]}`，防止抬高费用。
2. json:31-34 half_now：加 `"when": "cash() >= 60"`；或在 money 后 `{"op":"if","cond":"var('money_ok')","then":[扣怀疑, 扣费]}`。
3. json:14-17 与 json:36-39 gift：把 give_item 后的 stat/var 包进 `if var('gave') == true`。
4. director.gd:912 ma_fee：明确优先级（建议 sun_young=exposed 150 优先或取 max），并在 d2 设计稿里注明。
5. 应付：director 新增 hook 或 op（如 `call add_liability`，args to=维持会公账, what=维持费, amount=fee, due_day=7），把 fee 减免同步到 liability.amount（半付时 amount -= 60），待办文本读 liability。world.gd:196 已存在，只缺调用。
6. 待办关闭：半付/全付/周六结算时把 todo status 设为“已了”；周六未付则 status=“逾期”，并调用 add_liability 的后续逻辑。
7. world.gd:237 countdown_text：due_day==day 返回“今天缴费”。
8. sidebar.gd:216 与 book_panel.gd：待办期限同时显示公历（3 月 12 日）与农历。
9. 怀疑 ≥5 影子：在 world.add（world.gd:118）之后或夜晚开始处理：若 suspicion>=5 且 flag shadow_shown 未设，播放“门外有个影子，停了一会儿才走。”并设 flag。
10. 怀疑 ≥10 搜铺：suspicion 达到 10 时触发一个新 session/script（查封，设计稿 840），至少结束当晚流程并记 note。
11. world.gd:237 与 ma_fee：全部费用加 max(0, …) 保护。
