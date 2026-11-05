# 德厚当 v0.1 — FROZEN INTERFACES (owner: Opus orchestrator)

Workers: follow this exactly. Do not edit core files (`scripts/core/*`, `scripts/ui/*`, `scripts/tests/*`, this doc) unless told.
Design source of truth: `/workspace/gamejev-docs/story_sub2_剧本提示词.md` (quoted lines must be copied VERBATIM).
All data files are UTF-8 JSON, 2-space indent, no comments, no trailing commas. Validate with `python3 -m json.tool <file> >/dev/null`.

## 0. Directory layout
```
data/
  cast.json                 # characters (§2)
  items/<group>.json        # item definitions (§3)  groups: practice, rice, medicine, scrap, gold, deed
  medbook.json              # 《沈记药材鉴别录》 pages (§3.3)
  pages.json                # 档案簿 knowledge pages (§4)
  factions.json             # six factions + chess pieces (§4.2)
  codebook.json             # telegraph words + codes (§8)
  night.json                # night action labels (§7)
  layout.json               # counter hotspots (§9)  [owner: Opus]
  palette.json              # 32-colour palette (§10) [owner: Opus]
  story/flow.json           # chapter order [owner: Opus]
  story/<script_id>.json    # story scripts (§5)
  sessions/<session_id>.json# counter sessions (§6)
art/portraits/<npc_id>.png  # 48x64 RGBA
art/bg/<name>.png           # 320x180
art/tools/<tool_id>.png     # size = layout rect
art/items/<def_id>.png      # 64x64 RGBA
art/ui/*.png
tools/art/pixlib.py         # shared pixel helpers + palette [owner: Opus]
tools/art/gen_<group>.py    # one generator per art group (workers)
```

## 1. IDs
NPC ids: `brother`(沈如松 哥哥) `chen`(陈文庭 陈叔叔) `xiaoding` `zhang`(张慧娟 张护士) `wangshan`(王山) `li`(李敬之) `linsao`(林嫂) `zhouma`(周妈) `zhao`(赵老三) `sunyoung`(孙富贵 孙少爷) `ma`(马万利 马保长) `sunlaoye`(孙德昌 孙老爷, never at counter).
Special speakers: `you` (沈如花, never drawn), `narr` (stage direction / 旁白).
Factions (internal keys, Chinese): `城里的兵` `维持会` `湖上的人` `山里的人` `孙府` `水路上的` `王山那边` (王山's side is deliberately undecided → use `王山那边`).
Stats: `koubei`(口碑 0-100, start 50, shown) `benxin`(本心 0-100, 50, hidden) `suspicion`(维持会怀疑 0-10, 0, hidden) `chen_trust`(-20..20) `faction:<key>` (-20..20) `favor:<npc_id>` (-20..20 → mapped onto GameJev multi-dim relation).
Times of day (slots): `清晨` `上午` `中午` `下午` `傍晚` `夜`. Day 0 = 序章夜 (二月初四), Day 1 = 二月初五 星期日, Day 2 = 二月初六 星期一.
Item locations: `counter` (on counter, customer's), `npc:<id>`, `stock` (bought out, ours), `pawnbox` (active pawn, still customer's), `trash`, `burned`, `drawer` (practice/keepsake), `lost`.

## 2. data/cast.json
```json
{
  "npcs": {
    "<npc_id>": {
      "name": "沈如松", "label": "哥哥", "age": 19,
      "identity": "德厚当少东家", "look": "短发，藏青长衫，左眉一道旧疤。",
      "personality": "稳重、护妹妹、话不多，爱讲规矩",
      "secret": "（玩家逐步发现的真相；游戏里不直接显示）",
      "portrait": "art/portraits/brother.png",
      "color": "#2f4670",            // nameplate colour (palette)
      "voice_pitch": 0.9,             // 0.6..1.6, beep pitch for 嘀嘀 dialogue SFX
      "mbti": "ISTJ", "ennea": [1, 9], "instincts": [0.6, 0.5, 0.4],
      "traits": {12 keys, 0..1}, "values": {8 keys, 0..1},
      "needs": {optional}, "emotions": {optional}, "goals": {optional},
      "cash": 20,                     // starting 蚨 in their own ledger account
      "sched": {"default": [6 locations by slot], "<day>": [6 locations]},
      "lines": {                      // bargaining reactions; %d = number
        "accept_happy": "...", "accept": "...", "counter": "...%d...", "counter_sell": "...%d...",
        "plead": "...", "leave": "..."
      }
    }
  },
  "edges": [["zhouma", "xiaoding", 0.5], ...],     // acquaintance graph for rumor spread
  "outside_accounts": {"米行": 2000, ...}          // off-screen accounts (money is conserved)
}
```
trait keys: openness conscientiousness sociability compassion emotional_reactivity honesty assertiveness impulsivity patience risk_tolerance attachment_security adaptability
value keys: autonomy fairness loyalty achievement security benevolence order novelty
needs keys: safety resources rest belonging status control information meaning
emotion keys: anger fear sadness joy shame guilt disgust surprise hope arousal
goal keys: acquire avoid_loss connect understand defend_boundary repair_relation fulfill_duty explore

## 3. data/items/<group>.json
```json
{ "items": { "<def_id>": {
    "name": "奈宁片（一瓶）",
    "cat": "medicine",              // practice|rice|medicine|scrap|contraband_paper|gold|deed|keepsake
    "cat_cn": "药品",
    "market": 100,                  // TRUE market value 蚨 (0 for fakes/worthless)
    "claimed": 0,                   // what a fake pretends to be worth (0 if genuine)
    "fake": false,
    "grade": "",                    // e.g. "乙" for rice
    "origin": "normal",             // normal|stolen|contraband
    "contraband": false,            // 管制/违禁 (medicine with risk, 禁报)
    "est": [60, 140],               // fuzzy initial estimate shown BEFORE any inspection
    "suggest": 60,                  // suggested buy price (doc table), 0 if none
    "ask_w": 1.0,                   // weight when a bundle ask is split per item
    "weight": "",                   // display weight e.g. "十二斤" / "三钱二分" (only after scale)
    "tags": [],                     // e.g. ["孙记"]
    "sprite": "art/items/<def_id>.png",
    "ticket_condition": "",         // truthful 成色 text for 当票 (gold/deed)
    "parts": [ {
        "id": "batch", "label": "看批号",          // button label (verb phrase)
        "text": "批号：HC 26·10 0517",             // finding written to 档案簿 (verbatim from doc)
        "tool": "magnifier",                       // magnifier|scale|book|hand|nose  (scale needs 小秤 unlocked, book needs 鉴别录)
        "rect": [x, y, w, h],                      // hotspot on the 64x64 closeup sprite
        "est": [lo, hi],                           // optional: narrows mental estimate
        "flag": "found_sunji",                     // optional: story flag set true when revealed
        "tell": false,                             // true = reveals a forgery/defect clue
        "event": ""                                // optional: event id → session.on_inspect[event]
    } ]
} } }
```
Required def_ids (exact): practice: `coin` `handwarmer` `silver_keepsake`; rice: `rice_sunji` (+ generic `rice_jing_a`,`rice_xian_b`,`rice_nuo_c`,`rice_mold_d` for 定货/variety); medicine: `quinine` `mercuro` `sulfa_fake` (+ `aspirin`,`iodine`,`sulfa`,`morphine` reference/orderable); scrap: `newspapers` `ciyuan` `tabloid`; gold: `hairpin`; deed: `deed_zhao` `deed_fake` `deed_sun_real`.

### 3.3 data/medbook.json
```json
{ "rules": "批号规则… (verbatim)", "fake_batches": ["HC 26·09 0311", "RH 25·12 1180", "DT 26·08 0007"],
  "pages": [ {"id": "quinine", "name": "奈宁片（金鸡纳霜，治疟疾）", "maker": "海昌药厂", "code": "HC",
              "real": "...", "fake": "...", "life": "3 年", "value": "100 / 瓶", "risk": "中：游击队急需",
              "sprite": "art/items/book_quinine.png"} ] }
```

## 4. data/pages.json (档案簿 knowledge pages, unlocked by `page` op)
```json
{ "pages": { "<page_id>": {"title": "商品六类", "body": "multi-line text"} } }
```
Page ids: `six_cats` `factions` `rice_grades` `med_rules` `pawn_rates` `scrap_rules` `gold_rules` `deed_rules` `door_flags` `ticket_rules`.

### 4.2 data/factions.json
```json
{ "factions": [ {"key": "城里的兵", "piece": "黑子", "color": "#0d0a08", "line": "城里那些人…(verbatim)", "wants": "粮食、药品、铜铁、情报"} ... 6 entries in doc order ],
  "door_flags": [ {"id": "none", "label": "不挂", "public": "照常营业", "secret": "—", "unlock": "default"},
                  {"id": "blue", "label": "蓝布旗", "public": "一切如常", "secret": "店里安全，可以来", "unlock": "prologue"},
                  {"id": "white", ...}, {"id": "red", ...} ],
  "signs": [ {"id": "rice", "label": "收米粮"}, {"id": "books", "label": "收旧书报"}, {"id": "gold", "label": "金银首饰"} ] }
```

## 5. Story scripts — data/story/<script_id>.json
```json
{ "id": "prologue", "title": "序章", "steps": [ <step>, ... ] }
```
Every step is an object with `"op"`. Any step may carry `"when": "<cond>"` → skipped if cond is false.
Text fields may contain `{var}` placeholders resolved from session/script vars then flags (e.g. `{fee}`).

| op | fields | effect |
|---|---|---|
| `caption` | `text`, `style`: `date`\|`chapter` | black full-screen caption card, click to continue |
| `narr` | `text` | stage direction (【…】 content, without the brackets) |
| `say` | `who`, `text` | dialogue line; logged to 档案簿 as 亲耳 (heard) |
| `choice` | `who`?, `text`?, `store`?: flag name, `options`: [{`id`,`label`,`when`?,`steps`:[...]}] | player choice; chosen option's steps run; if `store`, flag ← id |
| `tutorial` | `target` (hotspot id, §9), `who`, `text`, `unlock`?: true | highlight hotspot; wait until player clicks it |
| `practice` | `kind`: `inspect`\|`abacus`\|`ticket`, `item`?: def_id | inspect: closeup of item, ≥1 part; abacus: set any number, confirm; ticket: full 登记→当票→盖章→收物 walkthrough with the item, NO money moves (第二天铜手炉) |
| `scene` | `bg`?: `dark`\|`candle`\|`day`\|`dusk`\|`night`, `brother`?: bool, `lamp`?: bool | change backdrop / brother beside counter |
| `enter` | `who` | customer appears behind counter |
| `leave` | — | customer leaves |
| `set` | `flag`, `value` | world.flags[flag] = value |
| `var` | `name`, `value` or `expr` | local var (script/session scope) |
| `stat` | `stat`, `delta`, `why` | change stat (§1 names) |
| `if` | `cond`, `then`: [...], `else`?: [...] | branch |
| `session` | `id` | run counter session data/sessions/<id>.json (§6) |
| `run` | `script` | run another story script inline |
| `call` | `fn`, `args`?: {} | whitelisted GDScript hook (§5.2) |
| `unlock` | `target` | unlock tool/hotspot (§9) |
| `page` | `id` | add 档案簿 knowledge page (§4) |
| `note` | `kind`, `text`, `source`: `seen`\|`heard`\|`inferred`, `via`? | 档案簿 entry. kind: 对话 鉴定 商品 势力 人物 消息 线索 借条 |
| `rumor` | `key`, `origin` | plant a rumor fact (world/rumors) at npc `origin` |
| `slot` | `to`: slot name, `day`?: int | advance world time (world wheel ticks each slot) |
| `item` | `def`, `owner`, `location`, `as`?: var name | create item instance |
| `move_item` | `def` or `var`, `to`: location, `note`? | move first matching instance |
| `money` | `from`, `to`, `amount`, `reason` | ledger transfer (accounts: `player`, npc ids, outside accounts). Fails silently if insufficient → sets var `money_ok`=false |
| `debt` | `debtor`, `creditor`, `amount`, `cash`: bool, `note`, `due_day`?: int | 借据/借条 (cash=true moves money creditor→debtor) |
| `todo` | `who`, `text`, `due_day`?, `countdown`?: bool | 账簿 待办; countdown=true shows "距缴费还有 N 天" in HUD |
| `summary` | `title` | day-close 账目 panel (income/expense/balance/stock computed) |
| `ledger` | — | open ledger view (read-only), click to close |
| `night` | `night`: 1\|2, `max_actions`?: int | night menu loop (§7) |
| `telegraph` | `incoming`: [words], `prompt`, `replies`: [{`words`:[...], `when`?, `steps`:[...]}], `default_steps`, `skip_steps`, `allow_skip` | telegraph minigame (§8) |
| `chess` | — | 陈叔叔's six pieces: player clicks each; its `line` is said by chen; then `page factions` |
| `door_flag` | `options`: [flag ids] | choose door flag (takes effect next day) |
| `ending` | — | final 当票 reveal card; game over screen |

### 5.1 Conditions (`cond`, `when`) — Godot `Expression` strings, evaluated on a context object exposing:
`flag(name)` (value or null) · `is(name)` (truthy) · `stat(name)` · `cash()` · `day()` · `stock_has(def_id)` · `stock_cat(cat)` (count in stock by cat) · `trash_has(def_id)` · `inspected(def_id, part_id)` · `var(name)` · session-only: `price()` `ask()` `floor()` `suggest()` `selected(def_id)` `tells(def_id)` (number of tell parts inspected) `judged_fake(def_id)` `rounds()`.
Examples: `"flag('xiaoding_rice') == 'fair'"`, `"price() >= 35 and price() <= 50"`, `"stock_has('quinine')"`, `"is('found_sunji')"`.
Strings use single quotes. Booleans: `true` / `false`. Use `and`/`or`/`not`.

### 5.2 Hooks (`call` op) available: 
`swap_rice_bag` (remove 孙记 tag from rice in stock; flag rice_bag_swapped) · `give_item` args {`to`, `cat`?, `def`?, `pick`?: bool, `reason`} (player picks stock item if pick) · `burn_trash` · `ma_fee` (computes var `fee` per doc) · `brother_money` args {} (choice 0/50/100 → transfer to brother, flag brother_money) · `day_close_lines` (brother's 3 closing lines for day 1 table) · `share_rumors` args {`who`} (customer may tell what they heard) · `sun_real_deed` (孙少爷 pulls out real deed → new pawn session `d2_sunyoung_real`).
If you need another hook, DO NOT invent it silently: use `call` with a descriptive snake_case `fn` and list it in your report under "HOOKS NEEDED" with exact semantics.

## 6. Counter sessions — data/sessions/<session_id>.json
One customer transaction at the counter. Runs inside a story script via `{"op":"session","id":...}`.
```json
{
  "id": "d1_xiaoding", "npc": "xiaoding",
  "mode": "buy",                 // buy (收购/买断) | pawn (活当) | sell (卖给客人)
  "items": [ {"def": "rice_sunji"} ],            // buy/pawn: items the customer brings (created on counter, owner=npc)
  "stock": ["quinine", "sulfa_fake", "mercuro"], // sell only: which stock def_ids this buyer wants (only those in stock are offered)
  "buyer_prices": {"quinine": {"offer": 80, "max": 90}}, // sell only: buyer's opening price and max he'll pay per item
  "ask": 50, "floor": 25, "suggest": 40,         // buy/pawn: customer's ask, hidden floor, rule-based suggestion (蚨, whole bundle)
  "est": [40, 90],                               // initial fuzzy estimate (bundle)
  "show_floor": true,                            // day 1 only: show 底价 under the customer (doc requirement)
  "hard_floor": false,                           // true = won't go below floor at all (赵老三)
  "fund_button": false,                          // 算盘 "资助" button (李敬之)
  "min_inspect": 0,                              // tutorial: require N inspected parts before first offer
  "split": false,                                // may toggle individual items in/out of the deal (张护士)
  "hint": "",                                    // brother's tutorial hint shown in the bargain panel (empty after brother leaves)
  "pre": [steps],                                // BEFORE the customer enters (brother's teaching lines, scene/slot changes)
  "intro": [steps],                              // lines when customer arrives (engine does `enter` first)
  "on_inspect": {"<event>": [steps]},            // fired when a part with matching "event" is revealed
  "extras": [ {"id": "ask_origin", "label": "追问来路", "when": "is('found_sunji')", "once": true, "steps": [...] } ],
  "deals": [ {"id": "refuse_return", "label": "拒收，劝他送回去", "when": "...", "steps": [...] } ],
                                                 // deals END the session (no default price transfer) — use for refuse/loan/give-away
  "on_accept": [steps],                          // after price accepted & money/items moved; price() available
  "on_leave": [steps],                           // customer walked away (lowball / refused)
  "outro": [steps],                              // always at end (after accept/deal/leave), before `leave`
  "post": [steps]                                // after the customer has left (e.g. 哥哥压低声音的评论)
}
Engine order: pre → enter(npc) → intro → [counter loop: inspect / offer / extras / deals] → (on_accept | deal.steps | on_leave) → outro → leave → post.
```
Session-local ops (valid inside session step lists): `reprice` {`ask`,`floor`,`suggest`?} · `end` {`result`: string → var `result`} · `set_judged` {`def`, `value`: 'fake'} · `select` {`def`, `on`: bool} · plus all §5 ops.
Engine behaviour on accept: buy → money player→npc, items → `stock` (owner player); pawn → 当票 beat (成色: 如实 `ticket_condition` / 照老规矩写“破旧”) then contract opened, money player→npc, items → `pawnbox`; sell → items stock→npc, money npc→player. Then `on_accept`, then `outro`. Then a `stow` beat (player clicks 典当盒 or 垃圾箱) for buy/pawn.
NPC acceptance/counter/plead/leave decisions are made by the NPC brain (PersonaResidual) from `ask`/`floor`; use `cast.json` lines for the generic replies.
Price-branch outcomes go in `on_accept` with `if` on `price()` (e.g. 压价 <30 → benxin -3).

## 7. Night (data/night.json)
```json
{ "lamps": 3, "actions": [ {"id": "ledger", "label": "对账", "star": true, "cost": 0, "desc": "查看当日收支、库存、到期当票。不消耗灯油"}, ... ] }
```
Action ids (engine-implemented): `ledger` `tidy` `burn` `nightsell` `order` `flag` `telegraph` `letter` `diary` `sleep`. Night 1: only ★ actions; night 2: all.

## 8. Telegraph (data/codebook.json)
```json
{ "words": [ {"word": "平安", "code": "0417"}, ... 20 initial words in doc order ],
  "locked": [ {"word": "山", "code": "...", "unlock": "story"}, {"word": "湖", ...} ],
  "callsign": "陈 · 七一三" }
```
Codes: 4 digits, unique. Incoming message = list of codes; player decodes with codebook, replies by picking 1–4 words then pressing 发报键 (key).

## 9. Hotspots (data/layout.json, coordinates in the 320x180 scene)
ids: `pawnbox` `magnifier` `abacus` `scale` `ledger` `notebook` `medbook` `trash` `telegraph` `door_flag` `sign` `lamp` `counter_item` (inspection area) `customer`. Tool sprites are drawn at these rects.

## 10. Pixel art rules (palette in tools/art/pixlib.py == data/palette.json)
- ONLY the 32 palette colours (+ fully transparent). No anti-aliasing, no gradients except ordered dithering between palette colours.
- Portraits 48x64, transparent background, half-body (head+shoulders+chest), facing the player, 1px dark outline (palette 1 or 0). Lit from upper-right (oil lamp). Character must match the doc's 外形 description (e.g. 哥哥 left-brow scar, 王山 bandaged left hand + 蓑衣, 马保长 礼帽+小胡子+白布臂章).
- Item closeups 64x64 transparent; part rects in item JSON must line up with the drawn feature.
- Backgrounds 320x180 opaque. Tools: transparent, exact rect size from layout.json.
- Generators are Python 3 + Pillow, import `tools/art/pixlib.py`, deterministic (no randomness without fixed seed), runnable as `python3 tools/art/gen_<group>.py` from project root, write PNGs only into `art/<group>/`.

## 11. Beat protocol (Director → UI / Autoplayer)
Director emits `beat(b: Dictionary)`; waiting beats need `director.submit(response)`. Types:
`caption{text,style}`→{} · `say{who,name,text,expr}`→{} · `narr{text}`→{} · `choice{who,name,text,options[{id,label}]}`→{id} · `tutorial{target,who,name,text}`→{target} · `practice{kind,iid}`→{value?} · `counter{session}`→{action:offer|extra|deal|event|refuse, value?, id?} · `ticket{draft}`→{condition:'true'|'old'} · `stow{iids}`→{to:'pawnbox'|'trash'} · `ledger{}`→{} · `summary{title,rows,stock,journal}`→{} · `night{night,lamps,actions}`→{id} · `pick_item{text,iids}`→{id} · `telegraph{incoming_codes,prompt,allow_skip,codebook}`→{words:[..]}|{skip:true} · `chess{pieces,remaining}`→{piece} · `door_flag{options}`→{id} · `ending{}`→{}.
Non-waiting (b.nowait=true): `scene{bg,customer,brother,lamp}` · `hud{}`.

## 12. M3 additions (frozen 2026-10-10)
- Session fields: `"require": ["<def_id>.<part_id>", ...]` — while these parts are not inspected, offers are refused with a hint (teaching; use only while 哥哥 is present). `"no_gossip": true` — suppress the automatic end-of-visit gossip (by default, after `outro` the customer's mind decides whether to pass on rumors it has heard; they are logged as 听说 with the teller and distortion level).
- Engine: buy-mode `suggest` is now COMPUTED = Σ round(market_now × 0.6) over selected items, valuing unjudged fakes at `claimed`, judged-fakes at 0 (doc: 第一天收购建议价 = 市价×60%). The `suggest` field in buy sessions is ignored (keep it for documentation). `market_now` follows the world wheel (米价 / 药价).
- Engine: a part with `"tool": "book"` whose text contains a batch number is automatically checked against data/medbook.json (fake list, 4-digit serial) and the verdict appended to the finding.
- Engine: `reprice` respects the current split selection.
- New op `{"op":"sfx","name":"door_open|door_close|coins|stamp|page|boots"}` (non-blocking sound).
- The generic “推回去（不收）” button is hidden when a session defines `deals` — so every session with deals MUST include its own refusal deal(s).
- Night action `ledger` (对账) now shows the day summary (收支、库存、借据、活当到期).

## 13. Test plans — scripts/tests/plans.json
```json
{ "plans": { "<plan_name>": {
    "until": "day1_done",              // checkpoint to stop at (flow.json checkpoints)
    "base": "fair",                    // fallback policy: fair | greedy | random1..3
    "choices": ["swap", "returned"],   // queue of option ids; head is used when a choice beat offers it, then popped
    "ticket": "true|old", "stow": "pawnbox|trash", "telegram": ["平安"] | ["skip"],
    "night1": ["burn", "tidy"],        // preferred night action order
    "sessions": { "<session_id>": {
        "inspect": "all" | "none" | ["<def>.<part>", ...],
        "extras": ["<extra_id>", ...],   // taken in order when available
        "deal": "<deal_id>",             // take this deal (ends session) once available (after extras)
        "offer": "suggest|ask|floor|low|fund|<int>" or "refuse",  "offers": [<int|name>, ...],
        "deselect": ["<def_id>"], "select": ["<def_id>"], "keep_fake": true } },
    "expect": { "<flag>": <value or null> },          // checked at the end; null = must be unset
    "expect_stats": { "benxin": ">=52", "suspicion": "==0" }
} } }
```
Run one: `godot --headless -s res://scripts/tests/run_playthrough.gd -- --plan=<name>` (add `--ui` for the UI path). tools/run_tests.sh runs every plan.

## 14. M4 additions (frozen 2026-10-10)
- `rumor` op: optional `"told": true` → the player already knows this rumor (she caused/witnessed it), so nobody will "tell" it back to her.
- `todo` op: optional `"amount": "<int or {var}>"`, `"pay_to": "<account>"`, `"what": "<text>"` → also records a LIABILITY (应付, not money) shown in 账簿/日结 and the sidebar countdown (e.g. 维持费).
- Item part: optional `"highlight_if": "<flag>"`, `"highlight_note": "（…）"` → the part is auto-highlighted in the inspection panel when the flag is set (e.g. 孙少爷伪契 四至 after seeing 赵老三's deed).
- Hook `set_door_flag` args `{"id": "none|blue|white|red"}` → tomorrow's door flag (e.g. 陈叔叔 telegraph “明日 / 蓝”).
- Engine: pawn tickets written “破旧” create a pending RISK (shown in 账簿; fires 口碑 -3 on redemption via world.redeem_contract). 满当 items move to stock. 当票 如实成色 text reflects how much the player actually inspected. Night actions that do nothing (no stock picked, buyer can't pay, telegraph skipped) don't consume 灯油; each lamp spent ticks the world (rumors spread, possible 巡夜/卡车 street lines). Orders show as 在途 todos. Suspicion ≥5 shows a shadow at the door. After the ending: end card “第一章 · 未完 / v0.1 完 · 待续” → 回到标题.
- night.json action descs must NOT print hidden numbers (怀疑/好感/本心 values) — describe effects qualitatively.
- Session fields (M4): `"accept_all_cash": true, "min_cash": N, "accept_all_cash_line": "…"` — a con-man buyer accepts an offer equal to the player's entire cash box (≥ min_cash) even below his floor (孙少爷伪契: 收下（钱匣允许的最高价）).

## 15. M5 UI API changes (frozen 2026-10-10, R2 playtest fixes)
### scripts/ui/dialogue_box.gd (PanelContainer)
- Existing API kept: `show_line(who_name, text, color, is_narr, click_to_continue, voice)`, `show_options(prompt_name, text, opts)`, `clear_options()`, `option_button(id)`, `set_hint(t)`, `finish_typing()`, `is_typing()`, `click()`, signals `advanced`, `option_picked(id)`, vars `instant`, `beeper`.
- NEW: `var typing: bool` — true from show_line until the whole line is revealed (own state; do NOT rely on RichTextLabel.get_total_character_count(), which is 0 until layout).
- NEW click rule: `click()` → if typing: finish_typing() and return; else if waiting_click AND at least 180 ms since the line finished typing (or since show_line when instant): emit advanced. (First click completes the line; a second deliberate click advances. Rapid double-clicks cannot skip lines.)
- NEW: `show_actions(actions: Array)` / `clear_actions()` / `action_button(kind, id) -> Button`; actions = [{"kind": "extra"|"deal", "id": String, "label": String}], rendered as a wrapped row of buttons (max 3 per row) BELOW the text inside the box; signal `action_picked(kind: String, id: String)`. Independent of options; cleared by show_line? NO — actions persist until clear_actions() (the counter beat refreshes them).
- NEW readable name plate: name label colour = speaker colour lightened until relative luminance ≥ 0.6, with a 2 px dark outline (font_outline_color #0d0a08, outline_size 4).
- Options: no empty rows/space; text area min height 28 when options are shown.
### scripts/ui/counter_view.gd (Control, 320×180 scaled ×3)
- REMOVE all use of Control.tooltip_text. NEW signal `hover_text(text: String, global_pos: Vector2)` emitted on every hover change and on mouse exit (text "" → caller hides its hover label).
- NEW signal `item_dropped(iid: String, hotspot_id: String)`: press on a counter item, drag, release over a visible/highlighted hotspot → emitted (no item_clicked in that case). A press+release on the same item without moving > 3 px still emits `item_clicked(iid)`.
- NEW var `selected_item: String` — drawn with a pulsing yellow 1px frame; while dragging, draw the item sprite following the cursor (in scene coords, half alpha).
- Highlighted hotspots additionally get a bouncing ▼ arrow (small filled triangle, lamp yellow, 2 px dark outline) drawn just above the rect; plain hover outline becomes thin and grey (Color(1,1,1,0.35)) so it can't be confused with a tutorial highlight.
- Chess pieces: drawn 20×20 (texture scaled), on a dark backing disc radius 11 (Color(0,0,0,0.55)) with a 1 px gold rim; pending pieces pulse; done pieces 35 % alpha. Keep `pieces`, `pieces_done`, `piece_clicked`.

## 16. v0.2 additions (frozen 2026-10-10) — real branches, exits
### New ops
- `{"op":"repay","debtor":"<npc>","amount":N,"note":"…"}` — the debtor pays back up to N 蚨 of their active debt to the player FROM THEIR OWN ACCOUNT (ability ≠ willingness: pays min(N, outstanding, their cash)); sets var `repaid` = amount actually paid (0 if none). Ledger entry, never invents money.
- `{"op":"give_stock","def":"<def_id>","from":"<npc>","note":"…"}` — an NPC gives the player an item (e.g. a thank-you gift): creates the item owned by the player in stock (the NPC's own goods; no money moves).
### New story hooks into the flow (orchestrator inserts these `run`/`session` steps; workers only create the target files)
| where | step | condition (when) |
|---|---|---|
| day2.json after d2_morning (清晨) | `run d2_dawn_news` | always (script decides internally what news arrives) |
| day2.json 上午, before d2_linsao | `session d2_xiaoding_return` | `flag('xiaoding_rice') == 'fair' or flag('xiaoding_loan') == 20` |
| day2.json 下午, before d2_sunyoung | `session d2_guanjia` | `is('sun_rice_rumor') or (stock_has('rice_sunji') and not is('rice_bag_swapped'))` |
| day2.json 中午, after d2_farewell | `run d2_noon_li` | `flag('li_fund') == 'high' or flag('li_paper') == 'reported' or flag('li_paper') == 'kept'` |
| night1.json, before the night menu | `run n1_backdoor` | `flag('wangshan') == 'refused' or flag('wangshan') == 'nostock'` |
| night2.json, after the first telegram, before the night menu | `run n2_backdoor` | `flag('wangshan_iou') == 60 or is('sold_fake_to_wangshan') or flag('xiaoding_loan') == 20` |
### New NPC
- `guanjia` 孙府管家 (孙福, ~50, 孙老爷 的老管家, 圆滑、客气里带刺；灰长衫、瓜皮帽、算盘珠子似的眼睛) — cast.json entry (same schema as others, portrait art/portraits/guanjia.png 48×64).
### Branch outcome flags (new, set by the branch content)
`xiaoding_returned` (true), `xiaoding_repaid` (int), `guanjia_visit` ('paid'|'denied'|'returned_rice'|'bribed'), `wangshan_backdoor` ('sold'|'gave'|'turned_away'|'ignored'), `n2_visitor` ('repaid'|'warned'|'thanked'), `li_noon` ('newspaper'|'arrested_seen'|'search_warning'), `zhang_note` (true).
