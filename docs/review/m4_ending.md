# M4 结尾审计：德字第一九六号 / 第一章 · 未完

Scope: data/story/ending.json, data/story/flow.json, data/story/night2.json, scripts/core/director.gd, scripts/ui/main.gd, plus world.gd / ledger.gd where the ticket touches them. Static read only; headless run not performed.
Spec: story_sub2 lines 785-798 (ending), 23-37 (timeline), 美术 当票.

## Beat table

| # | Beat (spec) | Status | Evidence | Note |
|---|---|---|---|---|
| 1 | Fires after 吹灯, regardless of choices | OK | flow.json chapters run linearly; night2.json:24-25 `night` then `narr`, no branch/end op; director.gd:70-77 run() has no early exit except stop_at (test only) | |
| 2 | Knock: three, pause, two | OK | ending.json:6 matches prologue.json:52 ("三声轻敲，停一下，再两声") | |
| 3 | "陈叔？" | OK | ending.json:7 say who=you | |
| 4 | Blue cloth bundle through door gap | OK | ending.json:8; main.gd dialogue line ~620 | |
| 5 | Ticket 「德字第一九六号」 in father's hand | OK | ending.json:9; director.gd:229 `no`; main.gd:609 | Hardcoded in director.gd:229, ignores ending.json ticket data |
| 6 | Date = day parents left | PARTIAL | director.gd:229 `date: "爸妈离家那天"`; main.gd:611 prints "日期：爸妈离家那天" | Placeholder text, not a date. See proposal below |
| 7 | 当户 blank | OK | main.gd ~612 "当户：　　（空）" | Hardcoded, fine |
| 8 | Caption order: ticket then 字幕 | OK | ending.json:12 ending op precedes :13 caption; main.gd:361 opens card and waits for button | |
| 9 | 字幕 「第一章 · 未完。」 | OK | ending.json:13 | |
| 10 | Clear end state, returns to title | MISSING | main.gd:264-272 `_on_finished` does nothing unless --quit; caption click (main.gd:188-191) just clears the layer | Screen is left blank with no input target. No "v0.1 完 · 待续", no return to title |
| 11 | Ticket recorded in 档案簿 | OK (caveat) | ending.json:11 note kind 线索 source seen -> director.gd:177-178 world.note | Note text carries the placeholder date |
| 12 | Ticket in ledger as unknown contract | MISSING | ledger.gd:113 issues ids only via open-contract path; nothing records 196; ledger.gd:13 next_ticket starts at 1 | Must not add 蚨 (pillar 5). Needs a no-money record |
| 13 | flag ticket196 | OK | ending.json:10 sets world.flags | Never read anywhere; fine as save hook |
| 14 | Timeline consistency | PARTIAL | design line 24 "约三周前" vs line 27 "已十五天没有音信" | Doc conflict, see date proposal |
| 15 | Date helper | WRONG if reused | world.gd:77-81 date_text(-15) yields "二月-11" (negative mod) | Do not compute the ticket date with date_text; use literal |

## Date proposal (ticket 日期)

- 序章 = 二月初四 = 3 月 5 日 1938. 15 days earlier = 正月十九 = 2 月 18 日 1938. Matches "十五天没有音信" (line 27).
- If "约三周前" (line 24) is authoritative instead: 21 days earlier = 正月十三 = 2 月 12 日.
- Recommended card text: `日期：民国二十七年 正月十九`  (same style as world.gd:76 date_text output).
- Also fix the design doc: change line 24 to "约半个月前" or line 27 to match.

## Fix list

1. director.gd:229 — read ticket from the step: `"ending": await _wait({"type": "ending", "ticket": st.get("ticket", {})})`, and add to ending.json: `"ticket": {"no": "德字第一九六号", "date": "民国二十七年 正月十九", "borrower": ""}`.
2. ending.json:9 and :11 — replace "日期是爸妈离家的那一天" / "日期是爸妈离家那天" with the concrete date (narration can keep "离家那天" as a wink, but the card and 档案簿 note should show the date).
3. ending.json:13 — keep the caption, then add a second caption step `{"op":"caption","style":"date","text":"v0.1 完 · 待续"}`. Alternatively add an `end_card` op.
4. main.gd:264-272 `_on_finished` — in the non-quit branch, show the end card (caption layer with "回到标题" button) and on click call `get_tree().reload_current_scene()` so the title screen returns (no --skip-title). Keep the --quit path unchanged.
5. ledger.gd — add `foreign_tickets: Dictionary` (id -> {date, note}) with NO 蚨 movement. Call it from a new op (e.g. `"ledger_foreign"`) in ending.json. Also set `next_ticket = max(next_ticket, 197)` if 196 is ever issued by the shop, to avoid id collision.
6. world.gd:77-81 — date_text breaks for negative day offsets. Guard with `if d < 0:` or do not reuse for past dates.
7. Design doc story_sub2 line 24 vs 27 — reconcile timeline (see proposal).
8. scripts/tests/autoplayer.gd:81 — add assertions: after finish, notebook contains "德字第一九六号", flags.ticket196 == true, and the end card is shown (not blank).

Verdict: story beats and knock/order are correct. The cliffhanger is NOT yet a clean end: no 未完/待续 end state, no return to title, placeholder date on the card, and no ledger record. Blocking fixes: items 3, 4 and 2.
