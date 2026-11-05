# M4 Audit: 第一晚 / 夜晚系统 / 打烊 (read-only review)

Spec: story_sub2_剧本提示词.md L741–769 (夜晚), L520–538 (打烊).
Scope: data/story/night1.json, data/night.json, data/story/day1_close.json, scripts/core/director.gd, scripts/core/world.gd, scripts/ui/main.gd.
Checks run: headless `run_playthrough.gd` to night1_done (default, exit 0), `--plan=night1_burn_tabloid` (exit 0, tabloid_burned true), `--until=day2_done` (exit 0). Wheel roll probe at /tmp/m4audit/probe/probe.gd.

## Beat table

| # | Beat | Status | Evidence |
|---|------|--------|----------|
| 1 | 3 盏灯油, each action -1 | OK | director.gd:623,675; main.gd:578 (● ○ re-rendered per action) |
| 2 | ★ marks shown | OK | main.gd:582; night.json ledger/tidy/burn star=true |
| 3 | 第一晚只开放 ★ | WRONG | night.json:98 diary nights [1,2], star=false; director.gd:630 gates only on benxin, so 写日记 (non-★) appears on night 1 whenever 本心<40 |
| 4 | Max 2 cost actions on night 1, then 吹灯 | OK | night1.json:10 max_actions 2; director.gd:675 `if cost > 0: used += 1`. Note: loop exits with 1 lamp still lit and no message; 对账 is unreachable after the 2nd action (see Fix 6) |
| 5 | 对账 free, not counted | OK | night.json:5 cost 0; director.gd:675 |
| 6 | 对账 shows 收支/库存/到期当票 | OK | director.gd:601 (market_now), day_summary 597–617 |
| 7 | 整理库房 +5% on one item | PARTIAL | effect real: world.gd:173 market_now, director.gd:707; visible in 对账 stock list (director.gd:601). But tidy action gives no numeric feedback (director.gd:702–712 narration only), and tidy_bonus stacks without cap (repeat on same item = +10%, +15%) |
| 8 | 烧垃圾 ★ burns trash | OK | director.gd:650 → call_hook burn_trash (917); plan night1_burn_tabloid passes |
| 9 | 烧垃圾 旁白 if li_paper=burned OR trash has 小报 | PARTIAL | director.gd:925 checks only had_tabloid; li_paper=='burned' alone (e.g., tabloid rummaged to 'lost') gets no narration |
| 10 | Tabloid-in-trash auto burn | WRONG (serious) | night1.json:11–13: after the night menu, `if trash_has('tabloid')` calls burn_trash, which burns ALL trash, costs no lamp, needs no choice, and bypasses 烧垃圾 and the 翻走 risk. It fires whenever the player never chose 烧垃圾 and the tabloid survived _trash_risk (65%). Not exercised by the test plans (they burn in-menu, so trash is empty at the if) |
| 11 | 吹灯睡觉 ends night | OK | director.gd:643 `if id == "sleep": break`; night1.json:16 narr 你吹灭了灯 |
| 12 | 写日记 only when 本心<40 | OK | director.gd:630; benxin starts 50 (world.gd:22), runs show 51–54 so diary hidden |
| 13 | Diary text from today's choices | PARTIAL | director.gd:807–815: 3 canned branches (li reported / fake sold / default); no 'li_paper=burned/returned' or xiaoding branch |
| 14 | 哥哥在, 收拾行李 | OK | night1.json:4–6 (brother true → false, narr 哥哥说完，就去后屋收拾行李了) |
| 15 | 对账 lets 哥哥 speak summary before leaving | PARTIAL | the 3-line speech is in day1_close (打烊) only; night 对账 is a bare summary. Acceptable if intended; otherwise add a brother say before summary |
| 16 | 打烊 summary before 哥哥's 3 lines | OK | day1_close.json:17–26 (narr → scene → summary → var said) |
| 17 | 打烊: 3-line cap, priority order | OK | day1_close.json `var('said') < 3` on every say; priority order matches L520–538 |
| 18 | 打烊 "收到假磺胺" line | WRONG | day1_close.json:56–63 uses is('fake_sulfa_in_stock'); d1_zhang.json:140 sets it on purchase and nothing clears it on sale, so after 卖给王山 the 'recheck' line fires for a sold item |
| 19 | 打烊 "卖假药给王山" line | WRONG | day1_close.json:80–87 requires found_fake_sulfa too; spec row has no such condition, so sold-without-found gets the wrong line (see 18) |
| 20 | 打烊 "孙记米" line | PARTIAL | day1_close.json:33–39 uses stock_has('rice_sunji') (current stock), not "收了". Pawning/selling it silently drops the line |
| 21 | 打烊 "借钱给小丁" line | OK | flag xiaoding_loan==20 set at d1_xiaoding.json:153 |
| 22 | 打烊 "资助李敬之" / "举报" | PARTIAL | li_fund=='high' set d1_li.json:72 OK. 举报 line (day1_close.json:103–111) is priority 7, so with 3 earlier matches it is cut while the transition line is also suppressed (its condition is li_paper!='reported'). The note says 举报 is always last |
| 23 | 打烊 "其它" when nothing matched | OK | day1_close.json `var('said') == 0` |
| 24 | Wheel ticks night → 第二天清晨 (prices/news) | OK (probabilistic) | world.gd:219–229 advance_slot runs _wheel at slot 0; director.gd:327–345 narrates world.news as （听X说）. Probe: day 2 logistics roll 0.012 = quiet (no rice change); medicine roll 0.822 = smuggle, med_mod -5%, news "有船从上海带了一批药回来，药价松了点。" So a visible tick is guaranteed only on the medicine track, and some mornings produce nothing |
| 25 | Rummaged trash visible next morning | MISSING | director.gd:817–827 sets flags.trash_rummaged and moves item to 'lost', suspicion +2 (hidden). Nothing reads trash_rummaged (grep: only the setter); day2.json and sessions have no trash reference. The player never learns of it |
| 26 | Trash risk only for 禁报 | PARTIAL | director.gd:818 `if contraband`; only tabloid and some medicine are contraband. Spec says "垃圾箱可能被人翻走" generically. Probably intended; state it in README |

## Fix list

1. (WRONG, 10) Delete night1.json lines 11–13 (the `if trash_has('tabloid')` → call burn_trash block). Keep the narration in the hook. Add a test: plan with 'burned' choice and no burn action, expect trash still holding tabloid or 'lost', with no auto-burn.
2. (WRONG, 3) night.json:98 diary: either set nights [2], or in director.gd:630 also `if night == 1 and not a.star: continue`.
3. (WRONG, 18–19) day1_close.json: line 81/87 condition → `var('said') < 3 and is('sold_fake_to_wangshan')`. Lines 57/63 → add `and not is('sold_fake_to_wangshan')`. Either way check the spec row order: 收到 → 发现 → 卖王山.
4. (MISSING, 25) Add a morning beat: in day2.json after the 清晨 slot (or in advance_to when slot==0 and flags.trash_rummaged): `narr "后门的垃圾箱空了，昨晚没烧的那张纸不见了。"`, and a note in 档案簿. Clear flag after showing.
5. (PARTIAL, 9) director.gd:925: `if had_tabloid or world.flags.get("li_paper","") == "burned":` for the 旁白.
6. (PARTIAL, 7) director.gd:707 area: after tidy, toast `市价 %d → %d 蚨` (market_now before/after). Cap per item per night: `if it.get("tidy_night") == world.day: say "今晚已经擦过了"; return`.
7. (PARTIAL, 4) director.gd:623 loop condition: when used == max_actions, keep the menu open with only free actions (对账) and 吹灯, rather than exiting. Also toast "油灯只够再做 X 件事" when lamps>0 at exit.
8. (PARTIAL, 20) Set flag rice_sunji_taken at the moment of receipt (d1_xiaoding.json:132/175), and use is('rice_sunji_taken') instead of stock_has in day1_close.json:33/39.
9. (PARTIAL, 22) Reorder or reserve a slot for 举报 so it is not cut by the cap; or drop the note's claim.
10. (PARTIAL, 13) Diary: add branches for li_paper=burned/returned and xiaoding_loan>0.
11. (PARTIAL, 24) Consider guaranteeing a morning news on day 2 (e.g. rice quiet → force one line) so the overnight tick is always visible; or keep it and document as probabilistic.
