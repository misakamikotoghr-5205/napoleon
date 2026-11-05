# M4 审计：第二天中午哥哥告别

Spec: /workspace/gamejev-docs/story_sub2_剧本提示词.md 655–677（中午：哥哥告别）、人物表 207、数值表 833。
Scope: data/story/d2_farewell.json, data/story/day2.json, data/items/practice.json, scripts/core/director.gd, scripts/ui/counter_view.gd, scripts/ui/sidebar.gd, scripts/core/ledger.gd, scripts/core/session.gd. Read-only. `godot --headless -s scripts/tests/validate_data.gd` = DATA OK.

## Beat table

| # | Beat | Status | Evidence | Fix |
|---|---|---|---|---|
| 1 | 哥哥回来，翻账点头（narr） | OK | d2_farewell.json:6 | — |
| 2 | 陈叔那边都说好了…电报（say） | OK | d2_farewell.json:7 (text matches) | — |
| 3 | 上午这几笔做得都对 | OK | d2_farewell.json:11 | — |
| 4 | 破旧variant "……只是林嫂那张当票。算了，你自己想想。" | WRONG | d2_farewell.json:8-12: `if/else` REPLACES the praise line. Spec 655-677 writes it as a continuation ("上午这几笔，你做得都对。（若…）"), so the 破旧 branch loses the praise and the "……只是" opens cold. Trigger `is('lin_ticket_old')` is correct: lin_ticket_old set from ticket_old_last (d2_linsao.json:152-160; director.gd:530), which is only the 林嫂 ticket. | Keep line 11 unconditional, then add a second `if` say with the variant line after it. |
| 5 | 小秤和库房钥匙 (say) | OK text / MISSING objects | d2_farewell.json:13. No item for 小秤 or 库房钥匙 is created. Spec gives no 【实现】 for them. | Optional: add `item` ops (scale, stock key) or document as narrative-only in README. |
| 6 | 小银元 "放在柜台上" (narr + on counter) | PARTIAL | d2_farewell.json:14-15 creates it straight into location "drawer". It never appears on the counter. "drawer" has no UI: book_panel.gd:155 lists only stock/pawnbox/trash, and main.gd:462 toast omits it. The player cannot see or inspect the 银元. | `item` location "counter" (magnifier/nose work), then `move_item` to "drawer" once the scene ends, and add a "抽屉（自用，不卖）" row to 账簿 库存 (book_panel.gd:152). |
| 7 | 银元 line (say) | OK | d2_farewell.json:16 | — |
| 8 | 选项 A + reply | OK | d2_farewell.json:18-20 | — |
| 9 | 选项 B 0/50/100 蚨 | PARTIAL | Mechanics OK: director.gd:915-929 offers 50/100 only if cash >= amt; transfer player→brother; flag = a. Journal row "−50 给哥哥路上用（哥哥）" shows in 账簿 全部流水 (book_panel.gd:118-122) and in 今日付 (ledger.gd:88-103). Gaps: (a) A/C never set brother_money, so the flag is absent instead of 0. (b) Nothing reads brother_money; spec says it changes later 家书 (spec 833). | (a) `set brother_money 0` before the choice (d2_farewell.json:17). (b) Add a reader in the first 家书 script, or mark the TODO in README. |
| 10 | 选项 B: cash < 50 | PARTIAL (spec silent) | director.gd:917: only the "还是算了" option is shown. | Acceptable. Note in README. |
| 11 | 选项 C narr | OK | d2_farewell.json:24-26 | Spec label is `“……”` with no extra quotes; fine. |
| 12 | Exit narr | OK | d2_farewell.json:28 | — |
| 13 | 哥哥 sprite gone after farewell | OK | d2_farewell.json:29 `scene brother:false` → director.gd:140 → counter_view.gd:172 gate. No later brother say/scene in day2 afternoon/evening or night2. | — |
| 14 | No tutorial hints after farewell | PARTIAL | (a) sidebar.gd:284 hint gated on `director.brother`: OK. (b) sidebar.gd:289 shows "（哥哥：先别急，还有该看的地方没看。）" UNCONDITIONALLY. Latent, since no post-farewell session has require/min_inspect (d2_sunyoung, d2_ma, d2_sunyoung_real all 0 or absent). (c) sidebar.gd:288 gate text "先用放大镜多看几处" also unconditional. (d) session.gd:332-336 and director.gd:486-489: the teaching gate `needs_more_inspection` is not conditioned on brother presence, although the comment says it is. (e) night2.json:9 `tutorial` "（打开右下角的柜子。）" fires after farewell. Spec 775 mandates this as a 强制教学 event, so this conflicts with spec 668 "从此刻起不再有教学提示". Decision needed. | Gate sidebar.gd:288-289 and the session gate on `main.director.brother` (or on the flag below). For (e), either reword to plain narration, or record the exception in the README. |
| 15 | flag tutorial_over | WRONG (dead) | d2_farewell.json:31 set; nothing reads it (grep). | Read it in sidebar.gd:284-289 and session.gd:334 as the single "teaching over" gate, or delete it. |
| 16 | flag brother_gone | LOW (dead) | d2_farewell.json:30; no reader. | Delete or read it with (15). |
| 17 | todo 家书 | OK | d2_farewell.json:32 | — |
| 18 | 人物表：之后只通过家书出现 | OK | No brother say lines after d2_farewell. | — |
| 19 | Every 蚨 to brother is a ledger entry | OK | ledger.transfer (ledger.gd:31-48) creates a journal row; transfer is 0 if cash is short, and the flag follows the transfer result (director.gd:927-929). | — |
| 20 | brother_money 0/50/100 consistent with cash | OK | Flag set to the amount actually transferred (a set to 0 on failure). Options check cash first. | — |
| 21 | 银元 owned by player, not sellable | OK | Owner "player" (d2_farewell.json:15). Drawer is not in stock: session.gd:87 and cond.gd:40 read only "stock". d2_ma.json:36 gift list uses stock_cat, so it cannot reach the silver. Caveat: #6 must keep it in a non-stock location. | — |
| 22 | silver_keepsake def | OK | practice.json:87-120; art/items/silver_keepsake.png exists. Category "keepsake" is not validated anywhere, so typos would pass silently. | Optional: add cat to validate_data.gd. |
| 23 | day2.json flow | OK | day2.json:12-14: 中午 slot, run d2_farewell, then 下午. d2_morning.json:55-59 sets brother false before 中午. | — |

## Fix list
1. d2_farewell.json:8-12 — keep "上午这几笔，你做得都对。" unconditional; then add `if is('lin_ticket_old')` → say "……只是林嫂那张当票。算了，你自己想想。" (beat 4).
2. d2_farewell.json:14-15 — 银元 to location "counter", then `move_item` to a non-stock "drawer" at the end of the scene. Add a 账簿 库存 row for it (beat 6, 21).
3. d2_farewell.json:17 — add `set brother_money 0` before the choice. Add a reader for brother_money in the first 家书 script, or log it as a TODO (beat 9).
4. sidebar.gd:288-289 — gate both hint strings on `main.director.brother`. Session gate (session.gd:334 / director.gd:486) must also check brother presence (beat 14 c, d).
5. Decide the night2.json:9 telegraph tutorial versus spec 668 "不再有教学提示" (beat 14e). Recommended: keep as narration and document the exception.
6. Either read tutorial_over and brother_gone as the single gate (sidebar and session), or delete them (beats 15-16).
7. Decide on 小秤 and 库房钥匙 as items or as narration only (beat 5).
8. Optional: validate item `cat` values in validate_data.gd (beat 22).
