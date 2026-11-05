# 德厚当 core logic map, for the town-game redesign

Repo: `/home/user/dehoudang` (Godot 4.7, GDScript, commit `a358b49`, v0.3b). Every file listed in the brief was read in full. No repo file was changed.
To test runtime behaviour I made a scratch copy (`scratchpad/understand/repo_copy/`) and ran a probe there: `scratchpad/understand/repo_copy/scripts/tests/probe_town.gd`. Its results are in §6.

---

## 0. Summary

* The core is **already layered**. Content is data (`data/**/*.json`). The code interprets it in layers:
  `DB` (loader) → `World` (state + simulation) → `Ledger` (money/items/contracts) + `Mind` (NPC brain) → `Session` (one negotiation) → `Director` (script VM + linear flow + many feature modules) → UI or Autoplayer, which talk to the Director through a **beat protocol** (signal `beat(dict)` + `submit(dict)`).
* **Reusable as is for a town:** `ledger.gd`, `mind.gd`, `PersonaResidual.gd`, `cond.gd`, `db.gd`, most of `session.gd`, the generic half of `world.gd` (stats, relationships, schedules, rumor propagation engine, seeded RNG helpers, notebook with seen/heard/inferred sources), the script VM part of `director.gd`, and the whole test approach (beat-driven autoplayer, plans with expectations, ledger invariants checked on every beat).
* **Tied to the current 2-day prologue → day1 → night1 → day2 → night2 → ending script:** `flow.json` plus `Director.run()`. Time only advances when a script runs `{"op":"slot"}`. `world.gd` hard-codes per-day off-screen events, street sightings, rumor texts and their consequences, the opening rent and the `price_board` reference prices. `director.gd` hard-codes the night menu, story hooks, the brother/lamp scene state and the single `customer` at a single counter.
* **Gaps that matter for the new direction.** Each was checked in code or in the probe.
  1. Every new game uses the **same seed** (`main.gd:409`, default `19380306`), so randomness does not differ between playthroughs.
  2. **Bills never settle.** `liabilities` and `todos` have no paid/done path; status is never changed anywhere. So the "survival pressure" is only shown on screen and never enforced.
  3. The **price wheel ratchets upward** (positive drift, no mean reversion). It pins at the caps (rice 1.30, medicine 1.40) after about 30–40 days.
  4. There is **no procedural content**: no random customers, items, rumors or off-screen routines. After the authored days the world goes static (the probe found 4 rumor keys after 60 days).
  5. **Selling is only scripted.** Players can sell only in authored `mode:"sell"` sessions (owner issue #7).
  6. **Pawn renewal, NPC-initiated redemption and liability payment** have data fields or functions but are never driven. `renewals` is unused, and `redeem_contract` has no caller.
  7. `door_flag`, `sign_board` and `cast.roles` have **no gameplay effect** yet. They are ready-made hooks for customer generation.

---

## 1. Modules

### 1.0 Call graph and lifetime

```
                    data/*.json, data/items/*.json, data/story/*.json, data/sessions/*.json
                                   │  (static singleton, loaded once)
                                   ▼
                       DB  (scripts/core/db.gd, class_name DB, DB.get_db())
                                   │
     ┌─────────────────────────────┼──────────────────────────────────────────┐
     ▼                             ▼                                          ▼
 Director (Node) ──owns──► World (RefCounted) ──owns──► Ledger (RefCounted)    tests/validate_data.gd
   │  ├─ ctx: Cond(world, director)      └──owns──► Mind (RefCounted) ──owns──► PersonaResidual
   │  ├─ session: Session (per customer; Session.world = World)
   │  └─ signals: beat(b) / input_received(r) / checkpoint(name) / finished
   ▼
 UI (scripts/ui/main.gd: start_game() creates Director, routes beats to panels, calls director.submit)
 or Autoplayer (scripts/tests/autoplayer.gd: connects to director.beat, answers with director.submit)
```

* **No autoloads.** `project.godot` has no `[autoload]` section. The only singleton is the static `DB._inst` in `db.gd`, reached through `DB.get_db()` and released with `DB.shutdown()`, which also clears the static `Cond` expression cache. Everything else is created by `Director.setup(seed)` (`director.gd:41-45`) or directly by tests (`World.new(); w.setup(seed)`).
* Ownership: `Director.world`, `World.ledger`, `World.mind` and `World.db`. `Session.world` points back at the World. `Cond.world`, `Cond.director` and `Cond.session` are set by the Director while a session runs.
* Direction of calls: **Director → World/Ledger/Mind/Session** (never the reverse). **Session → World/Ledger/Mind**. **World → Ledger/Mind**. World emits signals `changed` and `observed(entry)` for the UI. The UI reads World/Ledger/Session fields directly, and the UI and Autoplayer also **mutate the live Session object directly** (`s.inspect()`, `s.set_judged()`, `s.set_selected()`), outside the beat protocol. The Director learns about those mutations through the `{"action":"event"}` response.

### 1.1 `scripts/core/db.gd`: data loader (`class_name DB`, 133 lines)

| | |
|---|---|
| Responsibility | Load every JSON once. Collect parse errors in `errors` (tests fail on them). Small lookups. |
| Owns | `cast` (npc_id→def), `edges` (acquaintance graph), `outside_accounts`, `items` (def_id→def, merged from `data/items/*.json` with duplicate detection), `pages`, `factions`, `medbook`, `codebook`, `night`, `layout`, `palette`, `flow`, `scripts` (script id→`{id,title,steps}` from `data/story/*.json` except flow.json), `sessions` (session id→def). |
| API | `static get_db() -> DB`, `static reload() -> DB`, `static shutdown()`, `load_all()`, `npc_label(id) -> String` (`you`→"你", `narr`→""), `npc_color(id) -> Color`, `hotspot(id) -> Rect2`, `hotspot_label(id)`, `code_of(word)`, `word_of(code)`, `static tex(path) -> Texture2D`. |
| Town notes | Reusable. To support new data such as `data/town/buildings.json`, `data/events/*.json` and `data/bills.json`, add a loader per type, or load a generic directory into a dictionary keyed by `id`. Loading is order-stable because `_list` sorts the file names. |

### 1.2 `scripts/core/world.gd`: world state and autonomous simulation (RefCounted, 669 lines)

**Responsibility.** Holds all mutable game state apart from money, items and contracts (which live in the Ledger). Advances time and runs the "living world": world wheel, schedules, off-screen life, rumor spreading and emotion decay. It also keeps the information boundary: the notebook records where each piece of information came from.

**State it owns** (lines 14-46):
`db, world_seed, ledger, mind, npcs{}, day (0 = prologue night), slot (0..5 = 清晨,上午,中午,下午,傍晚,夜; starts at 5), koubei (public 0-100), benxin (hidden 0-100), suspicion (hidden 0-10), faction_trust{key:-20..20}, chen_trust (-20..20), flags{}, notebook[], pages[], todos[], risks[], liabilities[], unlocked{}, rumors{}, street_log[], world_log[] (dev only), weather, rice_mod, med_mod, prev_*_mod, patrol_cooldown, news[], door_flag, door_flag_next, sign_board, day_journal_start`.

Each NPC runtime record (`setup`, l.56) has this shape:
`{"id","def"(cast entry),"name","label","persona"(Mind.make_persona),"rel"{target: 8-dim rel},"location","present","knows"{rumor_key:{hops,conf,via,day,slot}},"log", optional "loc_override"{"day_slot":loc}, "at_counter", "last_decision"}`.

**Public API (signatures):**

| function | purpose |
|---|---|
| `setup(p_seed:int=19380306)` | Creates the Ledger and Mind. Opens the `player` account with 600 and one account per NPC (`cast.cash`) and per outside account (`outside_accounts`). Builds personas, seeds relationships from `edges`, places NPCs, plants 2 opening rumors, adds the rent liability and todo (l.48-75). |
| `date_text(d=-1)->String`, `weekday(d=-1)->int`, `slot_name()`, `days_to_saturday()` | Calendar. Day 0 is 二月初四. Months are approximated as 30 days. The year is fixed at "民国二十七年", and the month index is clamped at 12, so the calendar breaks after about 300 days (l.78-106). |
| `add(stat:String, delta:int, why="")` | Changes a stat. Names: `koubei`, `benxin`, `suspicion`, `chen`/`chen_trust`, `faction:<key>`, `favor:<npc>`, or a bare faction key. Unknown names call `push_error`. A `koubei` change also writes an "inferred" notebook line (l.109-133). |
| `stat(name)->int` | Reads a stat. `favor:<npc>` = `round((rel.player.affection-0.3)*40)`. `cash` = `cash()` (l.135-150). |
| `favor(npc_id, delta:int)` | Maps a scalar favor change onto the multi-dimensional relationship (trust/affection/respect/indebtedness or resentment) plus emotions and memory (l.153-161). |
| `fuzzy_trust(v)->String` | Turns a faction value into "亲近/一般/冷淡" for display. |
| `price_mod(it)->float`, `market_now(it)->int` | Today's price: `market × price_mod(cat) × (1 + tidy_bonus + market_bonus)`. Only the `rice` and `medicine` categories have modifiers (l.169-176). |
| `cash()->int` | `ledger.balance("player")`. |
| `note(kind, text, source="seen", via="", conf=1.0)` | Adds a notebook entry `{day,slot,kind,source(seen/heard/inferred),via,conf,text}` and emits `observed`. |
| `add_page(id)`, `add_risk(kind, ref, text)`, `add_liability(to, what, amount, due_day)`, `add_todo(who, text, due_day=-1, countdown=false)`, `countdown_text()` | Knowledge pages; pending risks; payable obligations (no money moves); todos and the HUD countdown. |
| `redeem_contract(tid)->bool` | Calls `ledger.redeem` and fires any pending `ticket_old` risk (koubei -3). **No code calls it.** |
| `night_tick(night_no, step)->Array[String]` | Runs once per lamp of oil spent at night: spreads rumors and rolls a quiet/boots/truck/dog street line. |
| `advance_slot()->Array[String]` | **The world clock tick** (see §3.3). Returns the street lines the player can see. |
| `where(npc_id)->String` | Location, or "（不在镇上）" when absent. |
| `plant_rumor(key, origin)`, `rumor_text(key, hops)`, `share_rumors(npc_id)->Array[String]` | Rumor engine (see §3.3). |
| `price_board()->String` | Sidebar text built from hard-coded reference prices 68 and 100. |
| `backend_simulate(until_day)->Array`, `_backend_day_events()`, `_debtor_turn(did, d)` | Dev "what happens after day 2" simulation. **Nothing in the game or the tests calls it.** |

Signals: `observed(entry)` (notebook / page) and `changed` (refreshes the HUD).

### 1.3 `scripts/core/ledger.gd`: objective ledger (RefCounted, 250 lines)

**Header invariants (l.1-3).** The total of all accounts is conserved, so the ledger never creates money. Each item is in exactly one location. No item is pledged twice. Each `request_id` is applied at most once (idempotency).

**Owns:** `accounts{name:int}`, `journal[]` (`{id:"J0001",from,to,amount,reason,ref}`), `items{iid: item}`, `contracts{tid: contract}`, `debts{did: debt}`, `seen_requests{}`, `foreign_tickets[]`, `initial_total`, `next_ticket`, `next_item`, `next_journal`.

| function | semantics |
|---|---|
| `open_account(name, amount)` | Creates or adds to an account. Increases `initial_total`; this is the only place money enters the system. |
| `balance(name)->int`, `total()->int` | |
| `transfer(from, to, amount, reason, ref="", request_id="")->String` | Returns a journal id, or `""` on failure (amount ≤ 0, unknown account, or insufficient funds; no overdraft allowed). A repeated `request_id` returns the earlier journal id without moving money again. |
| `add_item(def:Dictionary, owner, location)->String` | Instance id `I001…`. Deep-copies the def and adds `id, owner, location, pledged_to:"", history:["来自<owner>"]`. |
| `move_item(id, location, new_owner="", note="")`, `items_at(location)->Array`, `find_item(def_id, location="")->String` | Locations used: `counter`, `npc:<id>`, `stock`, `pawnbox`, `trash`, `burned`, `drawer`, `lost`, `sold:<acct>`. |
| `day_flows(from_index)->{income, expense, rows}` | Only counts `player` in and out. |
| `open_pawn(borrower, item_ids, principal, day, term_days, condition_text, ticket_old)->String` | Refuses if any item is already pledged. Moves `player → borrower` (request id `pawn|…`). Creates contract `德字第<cn>号` with `rate_month:0.03, signed_day, due_day, status:"active", condition, ticket_old, unauthorized_disposal:false, renewals:[], journal[]`. Items move to `pawnbox` and keep their owner (the pledgor). |
| `redeem_amount(tid, day)->int` | `principal + round(principal×0.03×max(1, ceil((day-signed)/30)))`. |
| `redeem(tid, day)->bool` | Atomic: refuses if any item has left the pawnbox. Moves borrower → player, then items move to `npc:<borrower>` and the status becomes `redeemed`. |
| `tick_contracts(day, grace=5)->Array` | `active` becomes `overdue` after `due_day`. `overdue` becomes `forfeited` after `due_day+grace`; the items then become the player's and move to `stock`. |
| `open_debt(kind, debtor, creditor, principal, day, due_day, cash_moves, note)->String` | `D01…`. If `cash_moves`, money goes creditor → debtor. |
| `pay_debt(did, amount, payer="")->int` | Pays `min(amount, outstanding, payer balance)`. Separates ability from willingness. |
| `set_guarantee(did, guarantor, limit)`, `call_guarantee(did)->int` | The guarantor pays up to the limit, after which a `recourse` debt is opened (guarantor → debtor). |
| `tick_debts(day)` | `active` becomes `overdue`. |
| `check_invariants()->Array[String]` | Total conserved; no negative account; no double pledge across active/overdue contracts; for each debt, payments + outstanding = principal. |
| `static _cn_num(n)` | Digits written as Chinese numerals (〇一二…). |

Hard-coded assumptions: the lender in `open_pawn` and `redeem` is always `"player"`; the ticket prefix is `德字`; the rate is 3%/month; the grace period is 5 days; forfeited goods go to `stock` and become the player's.

### 1.4 `scripts/core/mind.gd`: NPC brain adapter (RefCounted, 217 lines)

GameJev "FeaturePort", simplified. Encodes a persona into a frozen 96-dim state and an action into a 32-dim vector. Then: **rule utility + 0.8 × PersonaResidual residual → softmax(T=0.35) → a draw from a per-character deterministic random stream**. Probabilities are dev-only and never shown to the player.

* Constants: `TRAITS`(12) `VALUES`(8) `COGN`(8) `MOTIVES`(9) instincts(3) `EMOTIONS`(10) `NEEDS`(8) `REL`(8) `CONTEXT`(10) `MEMORY`(8) `GOALS`(8) `REGUL`(4) = 96. `ACTION_FEATURES`(32). `STACKS` (MBTI → cognitive stack). `RESIDUAL_WEIGHT=0.8`, `TEMPERATURE=0.35`.
* `_init(p_seed)`: loads `res://model/persona_residual.json` and sets `model_ok`.
* `static make_persona(def)->Dictionary`: builds traits/values, cognition from MBTI, motives from enneagram, instincts, plus emotions/needs/memory/goals/regulation with defaults overridden by the cast def.
* `static fresh_rel()`: `{trust .4, affection .3, respect .4, fear .1, resentment 0, indebtedness 0, familiarity 0, dependence .1}`.
* `encode(npc, ctx)->Array[96]`: uses `npc.rel[ctx.target or "player"]` and `ctx.context` overrides on context defaults.
* `static action_vec(attrs)->Array[32]`.
* **`decide(npc, cands:[{id, utility, attrs}], ctx, semantic_key)->{id, probs, residuals, key}`.** Seeds the RNG with `hash(str(world_seed)+"|"+npc.id+"|"+semantic_key)` and stores the result in `npc.last_decision`.
* `static feel(npc, deltas)`: deltas go to whichever of emotions/memory/needs/goals has the key. `static relate(npc, target, deltas)`: also adds +0.05 familiarity. `static expression(npc)->String`: the visible mood prefix, e.g. "（脸色沉下来）". `static decay(npc)`: emotions move 25% back toward baseline each slot; recency ×0.7.
* Cost (probe): **about 2.9 ms per decide() with 3 candidates**, i.e. about 1 ms per candidate-state pair. That is fine for event-driven decisions in a town, but not for per-frame use or for calling every NPC every slot without a cap.

### 1.5 `scripts/persona/PersonaResidual.gd` (class_name PersonaResidual, 93 lines)

A pure numerical scorer (GameJev Persona v0.3, MIT-attributed). `load_model(path)->bool` validates format `gamejev-persona-0.3`, width 16, rank 8, 96 state and 32 action features. `score_pairs(states, actions)->{"residuals":[tanh scores]}` or `{"error":…}`. The model is a 12-group token projection → layer norm → key/value; option projection → query → attention → `tanh(q·attended/√8 + bias)`. It has no game coupling and is fully reusable.

### 1.6 `scripts/core/cond.gd`: condition evaluation context (RefCounted, 131 lines)

* Constructed as `Cond.new(world, director)`; `session` is set by the Director during a counter session.
* Exposed functions, each implemented as `c_<name>`: `flag(name)` (raw value or null), `is(name)` (truthy: bool, non-zero number, or non-empty string that is not "false"), `stat(name)`, `cash()`, `day()`, `stock_has(def_id)`, `stock_cat(cat)` (count), `stock_count()`, `trash_has(def_id)`, `inspected(def_id, part_id)` (current session, or flag `_insp_<def>_<part>`), `var(name)` (`result` comes from the session; then session.vars, then director.vars; default `""` for `result`, otherwise `0`). Session-only: `price()`, `ask()`, `floor()`, `suggest()`, `selected(def)`, `tells(def)`, `judged_fake(def)`, `rounds()`. These return 0/false outside a session.
* `static rewrite(expr)`: a regex `(?<![A-Za-z0-9_.])(flag|is|…|rounds)\s*\(` → `c_$1(`. This works around `is`, `var` and `floor` colliding with GDScript keywords and built-ins.
* `eval(expr)`: parses a Godot `Expression` once and caches it in the static `_cache[expr_text]`, then `execute([], self, false)` with the Cond object as base instance. Parse or execution failure calls `push_error` and returns `null`. `test(expr)->bool` treats null as false. An empty string is true.
* Syntax: Godot Expression with `and/or/not`, single-quoted strings, `true/false`, arithmetic and comparisons.
* Town notes: reusable. To extend, add `c_*` methods and add the names to `FUNCS`, for example `here()`, `building_open(id)`, `weekday()`, `slot()`, `rel(npc,dim)`, `knows(npc,rumor)`, `bill_due(id)`, `contract_status(tid)`, `price_mod(cat)`.

### 1.7 `scripts/core/session.gd`: one counter transaction (RefCounted, 473 lines)

**Responsibility.** Holds the state of one negotiation with one NPC over one or more items, in mode `buy` (we buy outright), `pawn` (live pawn: we lend against the item) or `sell` (we sell to the NPC). Also handles limited-information inspection and price suggestions. A special `mode:"practice"` is built by hand by the Director, which only calls `_add`.

State (l.9-38): `world, def, npc_id, mode, item_ids[], selected{iid:bool}, judged{iid:"fake"/""}, inspected{iid:{part:true}}, base_ask, base_floor, ask, floor_v (hidden), suggestion, show_floor, hard_floor, fund_button, split, min_inspect, hint, est_lo/hi, rounds, last_offer, price, used_extras{}, pending_events[], closed, result, last_npc_line, vars{}`. Signal `changed`.

| function | notes |
|---|---|
| `setup(world, def)` | For buy/pawn, creates items on `counter` owned by the NPC via `ledger.add_item`; ask/floor/suggest come from the def. For buy, `suggestion = calc_buy_suggest()`. For sell, `_setup_sell()` picks matching `stock` instances and calls `_rescale_sell()`. |
| `inspect(iid, pid)->String` | Reveals one part. Gated by tool: `scale` needs `world.unlocked.scale`, `book` needs `world.unlocked.medbook`. Writes a "鉴定" seen note. May narrow `est`, set a `flag`, queue an `event`, and mark `weighed`. Tell parts add an "inferred" note. `book` tool runs `_check_batch` against `medbook`. |
| `is_inspected(def, pid)`, `inspected_total()`, `tells_found(def)` | |
| `set_judged(iid, v)`, `set_selected(iid, on)`, `toggle_selected`, `withdraw(iid)`, `selected_ids()`, `any_selected()` | Player-side decisions; these trigger a reprice. |
| `calc_buy_suggest()->int` | `Σ round(0.6 × value)` over selected items, where value = 0 if judged fake, `claimed × price_mod` for an unjudged fake, and `market_now` otherwise. |
| `reprice(new_ask, new_floor, new_suggest=-1)` | Used by the `reprice` op. Respects the split ratio. |
| `needs_more_inspection()`, `missing_required()` | Tutorial gates (`min_inspect`, `require`). |
| **`offer(v:int)->{result: accept/counter/plead/leave, text}`** | Increments `rounds`, then dispatches to `_offer_buy` or `_offer_sell` (§3.1). Sets `price` on accept. |
| `_line(kind)` | NPC reply from `cast[npc].lines[kind]`. |
| `visible_view()`, `unit_price_of(iid)` | Player-visible summary; per-item display price for sell. |

Couplings: `MAX_ROUNDS = 5` is a constant. `can_use_tool` uses story unlock keys. `_check_batch` is medicine-specific. `accept_all_cash` is a con-man special case.

### 1.8 `scripts/core/director.gd`: story VM + flow + feature modules (Node, 1043 lines)

The biggest file. It mixes four concerns:

1. **Script VM (generic):** `exec(steps)`, `do_step(st)` (one large `match` over 38 ops, `KNOWN_OPS` l.16-18), `fmt(text)` (`{var}` substitution: session.vars → director.vars → world.flags), `say/narr/_choice/enter/leave`, `new_item`, `_find_movable`, `call_hook(fn, args)`.
2. **Beat transport:** `_wait(b)` adds `date` and `slot`, emits `beat`, then `await input_received`. `_show(b)` is non-blocking (`nowait:true`). `submit(r)` emits `input_received`. Signals `beat`, `input_received`, `checkpoint(name)`, `finished`.
3. **Flow (linear, story-specific):** `run()` iterates `db.flow.chapters`, emits checkpoints, and honours `stop_at`. `run_script(id)`. `advance_to(slot_name, target_day)` loops `world.advance_slot()`, narrates street lines and news, delivers night orders, and handles the trash-rummage narration.
4. **Feature modules (mostly story-specific):** counter `run_session/_offer/_accept`; `_practice` (inspect/abacus/ticket tutorial); `_ticket_draft` and `_true_condition` (truthful pawn ticket condition depends on how much was inspected); `day_summary`; `night_menu` with `_night_enabled`, `_night_tidy`, `_night_sell`, `_night_order`, `door_flag_choice`, `_sign_choice`, `_free_telegraph`, `_diary_text`, `_trash_risk`; `telegraph`; `chess`.

Director state: `db, world, ctx, vars{}` (script-scope, **never cleared**), `customer` (single), `brother`, `bg`, `lamp`, `session`, `queued_sessions[]`, `done, stop_at, stopped, beats_emitted, current_script, night_no, lamps, _halt` (set by `end` to skip the rest of the current session step list), `_action_ok`, `_last_expr{}`.

Public entry points: `setup(seed)`, `run()`, `run_script(id)`, `run_session(id)`, `submit(r)`, `exec(steps)`, `fmt(text)`, `say(who, text)`, `narr(text)`, `enter(who)`, `leave()`, `new_item(def, owner, loc)->iid`, `advance_to(slot, day)`, `day_summary(title)`, `night_menu(night, max_actions)`, `door_flag_choice(opts)`, `telegraph(st)`, `chess()`, `call_hook(fn, args)`.

### 1.9 UI seam (only what concerns the core)

`scripts/ui/main.gd:421 start_game(seed)` creates the Director, connects `beat` to `_on_beat`, and connects `world.changed` to the sidebar refresh. `_on_beat` (l.473-570) routes each beat type to a panel (dialogue box, counter view, inspect panel, ticket panel, book, telegraph, generic summary/night panel). `_respond(r)` calls `director.submit(r)`. `auto_apply(b, r)` lets the Autoplayer drive through the UI (`--ui` tests). The UI reads `world.ledger.items`, `world.notebook`, `world.todos`, `world.liabilities`, `world.price_board()`, `world.countdown_text()` and `world.fuzzy_trust()`, plus `cast.roles` (sidebar, display only). **`main.gd:409` starts every game with seed `19380306`** unless `--seed` is passed.

---

## 2. Story and beat interpreter format

### 2.1 Files

* `data/story/flow.json`: `{"chapters":["prologue","day1","night1","day2","night2","ending"], "checkpoints":{"prologue":"prologue_done",…}}`. `Director.run()` runs the chapters in order and emits each checkpoint after its chapter.
* `data/story/<id>.json`: `{"id","title","steps":[<step>…], "note"?}`. There are 14 scripts. The top-level days (`day1.json`, `day2.json`) are **timelines**: `slot` ops advance the clock and `session` ops queue customers at fixed times. `when` guards add branch customers.
* `data/sessions/<id>.json`: one counter visit (§2.3). There are 11.

Example (abridged `day2.json`):
```json
{"id":"day2","steps":[
  {"op":"slot","to":"清晨","day":2},
  {"op":"run","script":"d2_morning"},
  {"op":"slot","to":"上午"},
  {"op":"session","id":"d2_xiaoding_return","when":"flag('xiaoding_rice') == 'fair' or flag('xiaoding_loan') == 20"},
  {"op":"session","id":"d2_linsao"},
  {"op":"slot","to":"下午"},
  {"op":"session","id":"d2_guanjia","when":"is('sun_rice_rumor') or (stock_has('rice_sunji') and not is('rice_bag_swapped'))"},
  {"op":"slot","to":"傍晚"},
  {"op":"run","script":"d2_ma"},
  {"op":"summary","title":"第二天 · 账目"}]}
```

### 2.2 Step schema

Every step is `{"op": <name>, "when"?: <cond>, …}`. If `when` is present and false, `exec` skips the step. `exec` stops early when `stopped` (test stop point) or `_halt` (after an `end` op) is set.

Op usage across all story and session JSON (counted): say 136, set 106, stat 87, narr 77, if 54, note 46, scene 16, move_item 15, var 13, slot 11, call 11, end 11, session 10, enter 10, leave 10, tutorial 10, sfx 9, choice 9, page 9, run 8, telegraph 6, rumor 6, money 4, todo 4, item 4, unlock 4, practice 3, give_stock 3, caption 3, debt 3, night 2, summary 2, repay 2, ending/ledger/chess/door_flag/reprice/set_judged/select 1 each.

The ops fall into groups:

| group | ops (fields) | engine |
|---|---|---|
| Presentation (blocking beat) | `caption{text,style}`, `narr{text}`, `say{who,text}`, `choice{who?,text?,store?,options:[{id,label,when?,steps}]}`, `tutorial{target,who,text,unlock?}`, `ledger`, `summary{title}` | `_wait` beat |
| Presentation (non-blocking) | `scene{bg?,brother?,lamp?}`, `enter{who}`, `leave`, `sfx{name}` | `_show` beat |
| State | `set{flag,value}`, `var{name,value|expr}`, `stat{stat,delta,why}`, `unlock{target}`, `page{id}`, `note{kind,text,source,via?}`, `rumor{key,origin,told?}`, `todo{who,text,due_day?,countdown?,amount?,pay_to?,what?}` | world |
| Control | `if{cond,then,else?}`, `run{script}`, `session{id}`, `call{fn,args}` | VM |
| Time | `slot{to,day?}` | `advance_to` → `world.advance_slot()` loop |
| Economy | `item{def,owner,location,as?}`, `move_item{def|var,to,note?}`, `money{from,to,amount,reason}` → var `money_ok`, `debt{debtor,creditor,amount,cash,note,due_day?}`, `repay{debtor,amount,note}` → var `repaid`, `give_stock{def,from,note}` | ledger |
| Session-only | `reprice{ask,floor,suggest?}`, `end{result}`, `set_judged{def,value}`, `select{def,on}` | session |
| Feature modules | `practice{kind,item?}`, `night{night,max_actions?}`, `telegraph{incoming,prompt,replies[{words,when?,steps}],default_steps,skip_steps,sent_steps,allow_skip}`, `chess`, `door_flag{options}`, `ending{no,date}` | director |

Hooks (`call` op, whitelisted in `validate_data.gd:8`): `swap_rice_bag`, `give_item{to,cat?,def?,pick?,reason}` (sets var `gave`, `gave_name`), `burn_trash`, `ma_fee` (sets var `fee` = 100/120/150 from flags, plus `fee_cn`), `brother_money`, `day_close_lines` (no-op), `share_rumors{who}`, `sun_real_deed` (queues session `d2_sunyoung_real`), `set_door_flag{id}`.

### 2.3 Session schema (`data/sessions/*.json`)

```jsonc
{ "id":"d1_xiaoding", "npc":"xiaoding", "mode":"buy|pawn|sell",
  "items":[{"def":"rice_sunji"}],               // buy/pawn: customer's items (created on counter)
  "stock":["rice_sunji"], "buyer_prices":{"rice_sunji":{"offer":55,"max":75}},   // sell
  "ask":50, "floor":25, "suggest":40, "est":[40,90],
  "show_floor":true, "hard_floor":false, "fund_button":false, "min_inspect":3, "split":false,
  "require":["newspapers.weigh"], "hint":"…", "no_gossip":false,
  "accept_all_cash":false, "min_cash":100, "accept_all_cash_line":"…",
  "pre":[…], "intro":[…], "on_inspect":{"<event>":[…]},
  "extras":[{"id","label","when"?,"once"?:true,"steps"}],    // non-terminal side actions (ask origin…)
  "deals":[{"id","label","when"?,"steps"}],                  // terminal alternatives (refuse, loan, gift)
  "on_accept":[…], "on_leave":[…], "outro":[…], "post":[…] }
```

Engine order (`run_session`, `director.gd:456-539`):
1. Run `pre`. Build a `Session` and set `ctx.session`.
2. `enter(npc)`, then `intro`.
3. **Counter loop** until `s.closed`. Each turn emits beat `counter{session, extras(filtered by when/once), deals(filtered)}`. The response is one of:
   * `{"action":"event"}`: drain `pending_events` through `on_inspect[ev]`.
   * `offer{value}`: run `_offer`.
   * `extra{id}`: mark used, then run its steps.
   * `deal{id}`: close with result `deal:<id>`, then run its steps.
   * `refuse`: close with result `refused`, say a line, then run `on_leave`.
4. Run `outro`.
5. Unless `no_gossip`, the NPC's mind decides whether to share rumors.
6. Leftover counter items go back to the NPC. `leave()`. Var `result` is set.
7. Run `post`, then any queued sessions.

`_offer` guards (l.541-565), in order: inspection gate, cash available, something selected. Then say the offer, call `s.offer(v)`, say the reply, and on `accept` run `_accept`; on `leave` run `on_leave`.

`_accept` (l.567-627):
* **buy:** money `player→npc` (request id), items to `stock`, `cost` recorded per item.
* **pawn:** `ticket` beat (condition `true|old`), then `open_pawn(…, 30 days, …)`. Fake collateral and a "破旧" condition each record a risk; "破旧" also costs benxin -2 and sets `market_bonus .15`.
* **sell:** money `npc→player` (if the NPC cannot pay, they leave), items to `npc:<id>`.

Then the `coins` sfx, `on_accept`, and a `stow` beat (pawnbox or trash) for buy/pawn.

### 2.4 Flags, vars, stats: where state lives

| kind | storage | written by | read by |
|---|---|---|---|
| Story flags | `world.flags{}` (Variant values: bool, int, String). Keys starting with `_` are internal (`_orders`, `_insp_*`, `_seen_zhao_sold`). | `set`, `choice.store`, item part `flag`, world internals | `flag()`, `is()`, `{key}` in fmt, autoplayer `expect` |
| Script vars | `director.vars{}`: global, **never reset between scripts** (only overwritten) | `var`, `item.as`, `money`→`money_ok`, `debt`, `repay`→`repaid`, hooks (`fee`, `gave`…), `result` after each session | `var()`, fmt |
| Session vars | `session.vars{}` (the `var` op writes to both session and director) | same | `var()` first, fmt first |
| Stats | `world.koubei/benxin/suspicion/chen_trust/faction_trust{}`; `favor:<npc>` is derived from `npcs[n].rel.player.affection` | `stat` op → `world.add` | `stat()`, `expect_stats` |
| Unlocks | `world.unlocked{target:true}` | `tutorial`, `unlock` | `Session.can_use_tool`, `_night_enabled`, UI hotspots |
| Knowledge | `world.notebook[]`, `world.pages[]`, `world.rumors{key:{origin,truth,player_knows}}` plus `npc.knows{}` | `note`, `page`, `rumor`, `say` (logs "对话"), inspect | UI book |

### 2.5 Beat protocol (Director ↔ UI/Autoplayer), `INTERFACES.md §11`

Waiting beats, with the expected response:

| beat | response |
|---|---|
| `caption` | `{}` |
| `say{who,name,text,expr}` | `{}` |
| `narr` | `{}` |
| `choice{who,name,text,options[{id,label}]}` | `{id}` |
| `tutorial{target}` | `{target}` |
| `practice{kind,session?}` | `{value?}` |
| `counter{session,extras,deals}` | `{action,value?,id?}` |
| `ticket{draft}` | `{condition}` |
| `stow{iids,pawn?,practice?}` | `{to}` |
| `ledger` | `{}` |
| `summary{title,income,expense,balance,rows,stock,debts}` | `{}` |
| `night{night,lamps,max_lamps,actions,used,max_actions}` | `{id}` |
| `pick_item{text,iids}` | `{id}` |
| `telegraph{incoming_codes,_answer,prompt,allow_skip,reply,codebook,callsign}` | `{words}` or `{skip:true}` |
| `chess{pieces,remaining}` | `{piece}` |
| `door_flag{options,current}` | `{id}` |
| `ending{ticket}` | `{}` |

Non-waiting (`nowait:true`): `scene{bg,customer,brother,lamp}`, `sfx{name}`.

Every beat also carries `date` and `slot`. This one seam is what lets the same content run headless (Autoplayer) and through the real UI (`--ui`). Keep it in the town game.

---

## 3. Mechanics in detail

### 3.1 Bargaining (`session.gd:356-449`, decided by `mind.decide`)

The NPC's state comes from its persona: `t = persona.traits`, `need = persona.needs.resources`.

**Buying from an NPC** (`buy` and `pawn` use the same logic), `_offer_buy(v)`:
1. If `v ≥ ask`, accept "happily" (feel joy +0.2, hope +0.1).
2. Con-man rule: if `accept_all_cash` and `v ≥ cash()` and `v ≥ min_cash`, accept.
3. `hard_floor` and `v < base_floor`: the first time, counter at `base_floor`. From round 2, leave (favor -1).
4. From round 5 (`MAX_ROUNDS`): accept if `v ≥ floor_v`, otherwise leave (favor -1).
5. Otherwise the brain picks. With `gap = (v-floor)/(ask-floor)`, `lowball = v < 0.6×floor` (lowball also feels anger +.3, humiliation +.15, shame +.1) and `below = max(0, (floor-v)/floor)`, the candidates are:
   * `accept` (only if `v ≥ floor`): `U = .25 + .9·gap + .55·need − .7·assert + .12·rounds − .15·patience`
   * `counter`: `U = .25 + .5·assert − .12·rounds`
   * `plead` (only if `need > .6`): `U = .1 + .4·need − .15·rounds`
   * `leave`: `U = −.5 + 1.6·below + .25·rounds − .3·need + (.4 if lowball)`

   Each candidate has 32-dim `attrs` (gain, dignity, withdrawal…) that feed the neural residual. Context is `{stakes .7, time_pressure .5, publicness .2}` and the key is `"haggle_<npc>_<round>_<v>"`.
6. If the brain picks `counter`: `concede = clamp(.5 − .3·assert + .2·need, .1, .8)`, then `ask = max(floor, round(ask − (ask − max(floor, v))·concede))`. If it picks `leave`: close, favor −3 if lowball, else −1.

**Selling to an NPC**, `_offer_sell(v)`. Here `ask` is the buyer's current offer and `floor_v` is the most they will pay.
1. If `v ≤ ask`, accept. Let `over = (v-ask)/(floor-ask)`.
2. From round 5: leave if `v > floor`, otherwise accept.
3. Candidates:
   * `accept` (only if `v ≤ floor`): `U = .75 − .45·over + .12·rounds`
   * `counter`: `U = .3 + .4·assert − .1·rounds`
   * `leave`: `U = −.6 + 1.5·max(0, over−1) + .2·rounds`
4. If the brain picks `counter`: `ask = min(floor, round(ask + (min(v, floor) − ask)·.5))`.

**Sell prices** (`_rescale_sell`, v0.3 "unified pricing"). For each selected item: `market = market_now(it)`, `offer_ratio = clamp(bp.offer / item.market or .85, .5, 1.2)`, `max_ratio = clamp(max(bp.max / item.market or 1.05, offer_ratio), .55, 1.35)`. Then `ask = Σ market·offer_ratio·tidy_m` and `floor = Σ market·max_ratio·tidy_m`, both capped by the buyer's own cash.
* ⚠ **Bug:** `market_now` already includes `tidy_bonus + market_bonus`, and `tidy_m = 1 + tidy_bonus + market_bonus` multiplies it again, so the bonus is applied twice. `unit_price_of` does not apply `tidy_m`, so the displayed unit price and the real ask disagree.

**Buy prices.** `ask` and `floor` come from the authored session (scaled by the split weight `ask_w`). Only `suggestion` is computed (60% of the believed value). A town game needs a **generated** ask/floor, e.g. `floor = believed_value × f(need, persona, desperation, rumors about you)` and `ask = floor × g(assertiveness, honesty, fake?)`.

Tests: `test_bargain.gd` checks that every NPC finishes within 6 rounds and that fair mid prices close in at least 5 of 10 seeds. `test_minds.gd` checks that different personas produce different reaction signatures, that the same seed reproduces, and that the residual is non-zero.

### 3.2 Ledger

* **Accounts**: `player` (600 at the start), one per NPC (`cast.cash`), and the outside accounts `米行 2000, 济生堂柜 500, 废品摊 300, 保安队 0, 银楼 500, 维持会公账 1000, 市场 3000, 船行 800`. These outside accounts **are already "other buildings in town" in economic form**.
* **Pawn contracts.** Created → `active` → (`redeem` → `redeemed`) or (`tick_contracts`: after `due_day` → `overdue`; after `due_day+5` → `forfeited`, and the items become the player's `stock`). `tick_contracts` and `tick_debts` run on each day rollover inside `world.advance_slot`. Unused or missing: `renewals[]` (needed for owner #10 "extension"), `unauthorized_disposal`, `fake_collateral` (set by the Director), redemption visits (nothing ever calls `world.redeem_contract`).
* **Debts.** `iou` (no cash moves) and `loan` (cash moves). `pay_debt` pays only up to the payer's cash. Guarantees can be set and called, and create a recourse debt. Debt status changes come only from `tick_debts` and `pay_debt`.
* **Liabilities** (`world.liabilities`, not in the ledger): `{to, what, amount, due_day, status:"未付"}`. Created by `setup` (rent 30 due on day 7) and by the `todo` op with `amount` (the weekly fee in `d2_ma`). **Nothing ever pays them or changes their status**, and there is no consequence when they go unpaid. The weekly fee `ma_fee` is a fixed 100/120/150 chosen from flags.
* **Risks** (`world.risks`): delayed consequences, e.g. `ticket_old` fires koubei -3 on redemption.
* **Invariants** (`check_invariants`): checked by the Autoplayer **before every beat** and at the end of every run. Any violation fails the test.

### 3.3 World

**`advance_slot()` order** (l.269-301):
1. `slot += 1`. On rollover: `day += 1`, the door flag swaps in, then `ledger.tick_contracts(day)` and `tick_debts(day)`.
2. `_place_everyone()`: location = `def.sched[str(day)] or sched.default`, indexed by slot, overridden by `loc_override["day_slot"]`.
3. `_wheel()`: exogenous events (below).
4. `_offscreen_life()`: hard-coded story events.
5. `_propagate_rumors()`.
6. `Mind.decay` for every NPC.
7. `_street_view()`: what the player sees from the door (only NPCs in `桥头街`, plus scripted lines).
8. The `zhouma_news` daily news item.
9. Street lines go into `street_log` and the notebook; emit `changed`.

**World wheel** (`_wheel`, l.319-360). It never reads player actions ("exogenous"), and every wheel has a quiet outcome.

| wheel | RNG domain | outcomes (weights) | effect |
|---|---|---|---|
| climate | `climate` | quiet 6 / 薄雾 1 / 细雨 1 / 放晴 1 | Weather plus a street line. Day 1 清晨 is forced quiet. |
| order | `order` | quiet 8 / patrol 1, then a 4-slot cooldown | Street line; NPCs at 桥头街/街上/茶馆 get fear +0.2. |
| logistics | `logistics`, at slot 0 only | quiet 2 / boat 1 / noboat 1 | rice_mod −0.05 (floor 0.85) or +0.08 (cap 1.30), plus news |
| medicine | `medicine`, at slot 0 only | quiet 2 / requisition 1 / smuggle 1 | med_mod +0.10 (cap 1.40) or −0.05 (floor 0.85), plus news |

⚠ **Ratchet.** The expected daily change is +0.0075 for rice and +0.0125 for medicine, and there is no mean reversion. The probe saw rice_mod reach the 1.30 cap and med 1.35 by day 60, i.e. prices end up pinned high.

**Off-screen life** (`_offscreen_life`, l.380-445) is entirely `if day == N and slot == M` story code: Xiaoding buys herbs, Zhang decides to leave (`mind.decide`), Wangshan leaves town, Zhao sells land to the Sun family, Zhao ransoms his son, Linsao's deposit, Sunyoung complains. Money moves for real through the ledger. **None of this generalizes**; it should become data-driven NPC routines and goals.

**Rumors** (l.471-579):
* `FACTS` is a hard-coded `key → [text at hop 0, hop 1, hop 2+]` table (distortion grows with hops).
* `_plant(key, origin)` → `_learn(npc, key, via, hops, conf)` records `npc.knows[key]`, then runs `_on_learn`, a hard-coded `match [npc,key]` consequence table (sets flags, stats, relationships).
* `_propagate_rumors` runs each slot. For each present NPC and each known key (not learned this same slot, `hops < 3`, `conf ≥ 0.3`), and for each acquaintance `other` with `familiarity > 0` who does not yet know it: with probability `familiarity × sociability × conf × 0.7`, `other` learns it next slot with `hops+1` and `conf × 0.75`.
* `share_rumors(npc)`: at the end of a counter visit the NPC's mind decides tell or keep (`tell U = .3 + .6·sociability`). If told, the notebook gets a "听说" (heard) line with the via-NPC and the confidence. A hard-coded exclusion list keeps an NPC from telling the player about their own embarrassing rumors.
* The player only learns rumors through `share_rumors`, Zhouma's daily news, or a `rumor{told:true}` op.

**Information boundary.** The notebook keeps the `source` of everything (seen/heard/inferred, with `via` and `conf`). Street sightings are limited to the street in front of the shop. Hidden stats (benxin, suspicion, favor values) are never printed.

**Stats**: koubei (public, logged), benxin (hidden), suspicion (hidden, 0-10), chen_trust, faction_trust per faction (6 factions plus `王山那边`), and favor/relationships as an 8-dim relation per NPC→target.

**Schedules**: `cast[npc].sched` = `{"default":[6 locations], "<day>":[6 locations]}`. The locations used today already sketch a town map: 桥头街 (the street outside the pawnshop), 茶馆, 济生堂, 银楼, 维持会, 保安队, 孙府 (+厨房), 商会, 赌坊, 码头, 客栈, 县立中学, 田里, 家, 街上, 镇外, 县城路上, 铺子.

**Night**: `night_tick(night_no, step)` runs per lamp spent. `night.json` defines lamps (3) and actions. The engine implements ledger, tidy (+5% value, stored on the item), burn, nightsell (70–85% to the buyer account for the category), order (delivered next morning at 80% of market), flag/sign, telegraph (+1 suspicion), tell_sun, diary (only when benxin < 40), and sleep. Doing nothing costs no oil. After the night menu, `_trash_risk` gives a 35% chance per contraband item in the trash that it is stolen (suspicion +2).

### 3.4 Randomness and seeding

All randomness is **stateless and counter-based**: every roll creates a fresh `RandomNumberGenerator` with `seed = hash(<string key>)`. Nothing needs saving, and outcomes do not depend on call order (good for replays and saves).

| where | seed string | used for |
|---|---|---|
| `world._rng(domain)` | `"%d|%s|%d|%d" % [seed, domain, day, slot]` | climate, order, logistics, medicine, remit (backend) |
| `world._propagate_rumors` | `"%d|rumor|key|from|to|day|slot"` | each spread attempt |
| `world.night_tick` | `"%d|night|night_no|step"` | night street event |
| `mind.decide` | `str(seed)+"|"+npc_id+"|"+semantic_key` | every NPC decision (haggle, share, debt, leave…) |
| `director._night_sell` | `"%d|nightsell|day|iid"` | buyer rate 0.70–0.85 |
| `director._trash_risk` | `"%d|trash|day|iid"` | trash rummage (35%) |
| autoplayer | `hash(policy + str(seed))` | test policy only |

Problems for a game built around randomness:
1. **The seed is fixed for real play** (`main.gd:409`, `director.setup(19380306)`), so every new game is identical.
2. **Some semantic keys do not include a day or visit counter**, so repeated situations reuse the same uniform roll: `"share_"+key` (same NPC, same rumor, always the same roll), `"haggle_<npc>_<round>_<v>"` (the same offer on a different day draws the same number), `"zhang_leave"`, `"zhao_noon"`. Over a long town game this produces identical repeats. Add `day`, a visit counter or a session id to the key.
3. **The content is almost all authored**: no random customers, items, item conditions, rumors, events, bills or NPC goals. The only stochastic systems are the wheel (4 wheels), rumor spread, NPC decisions, night-sell rate and trash risk.

---

## 4. Reuse vs coupling for a town game (pawnshop = one building)

### 4.1 Cleanly reusable (keep, maybe rename)

| # | piece | why it transfers | small changes needed |
|---|---|---|---|
| R1 | `ledger.gd` (accounts, journal, idempotent `transfer`, items with history and locations, pawn contracts, debts, guarantees, invariants) | Already models a multi-account town economy. Outside accounts (米行, 银楼, 保安队…) map onto buildings. | Parameterize `lender` (default `"player"`), ticket prefix, rate, term and grace. Implement `renew(tid, day, fee)`. Add `liabilities` as ledger objects with `pay_liability`. Make `day_flows(account)` take an account. |
| R2 | `mind.gd` + `PersonaResidual.gd` | Generic utility + residual + softmax chooser with per-NPC deterministic streams; personas from MBTI/enneagram/traits. | Add a `day`/visit to semantic keys. Mind the cost (≈1 ms per candidate); cap decisions per tick. |
| R3 | `cond.gd` | Generic expression context with caching and keyword-safe rewriting. | Add town functions (`here()`, `slot()`, `weekday()`, `building_open()`, `rel()`, `knows()`, `bill_due()`…). |
| R4 | `db.gd` | Generic JSON loader with error collection and font-glyph-safe tests. | Add loaders for new data directories. |
| R5 | `session.gd` | A negotiation over items with inspection, split, judgement and persona-driven offers. It can run in **any** building: player buys at 米行, sells to 银楼, pawns at our counter. | Generated ask/floor; reverse roles (player as customer); configurable `MAX_ROUNDS`; tool-unlock and medbook checks moved into item or tool data; fix the tidy double count. |
| R6 | Generic half of `world.gd` | Stats (`add`, `stat`, `favor`), notebook with sources, pages, risks, schedules (`_place_everyone`, `where`), `_rng`/`_pick`, `price_mod`/`market_now`, the rumor engine (`_plant`, `_learn`, `_propagate_rumors`, `share_rumors`, `rumor_text`), `Mind.decay` per slot, `night_tick`, contract/debt ticks on rollover. | Move tables into data (see 4.3). |
| R7 | Director **script VM** (`exec`, `do_step` for the generic ops, `fmt`, `when`, `if`, `choice`, `say`, `narr`, `set`, `var`, `stat`, `money`, `debt`, `repay`, `item`, `move_item`, `give_stock`, `note`, `rumor`, `page`, `unlock`, `sfx`, `run`, `session`) | Exactly what a building or NPC interaction needs ("enter a shop → pixel portrait dialogue"). | Split out of the Director; register ops in a table (see 4.3). |
| R8 | Beat protocol + Autoplayer + plans + invariant checks + `--ui` dual path | Lets the town run headless and through the UI from one codebase. | Add `town`/`move` beats (see §5). |
| R9 | Item def format (`parts` with tool, est, flag, tell, event, highlight_if) | A fine format for "player appraises manually" (owner #5). | Add templates and random instantiation. |
| R10 | Cast format (persona, `lines`, `sched`, `roles`) | NPCs can live in a town. | `sched` by weekday or routine instead of by absolute day; `roles` should drive behaviour (middleman, double agent, owner #18). |

### 4.2 Tightly coupled to the linear prologue→day1→night1→day2→night2→ending script

| # | coupling | where | what breaks in a town |
|---|---|---|---|
| C1 | Linear chapters + checkpoints | `data/story/flow.json`; `director.gd:70-79 run()` | The game is one fixed sequence with no free roaming and no open-ended days. |
| C2 | Time only moves when a script says so | `slot` op → `advance_to` (`director.gd:365-388`); day scripts `day1.json` and `day2.json` place sessions at fixed slots | In a town, time has to be driven by player actions (walking, entering, talking, sleeping). |
| C3 | The day starts with the prologue at slot 5; day 1 is special-cased | `world.gd:19-20`, `_wheel` l.322-323 (`day==1 and slot==0 → quiet`), `date_text` base date | Needs a real calendar start and year (owner #3, #9). |
| C4 | Hard-coded off-screen events per day/slot | `world.gd:380-445 _offscreen_life` (xiaoding/zhang/wangshan/zhao/linsao/sunyoung) | The world goes static after day 2 (the probe confirmed it). Wangshan is permanently absent. |
| C5 | Hard-coded street sightings, and only one street is visible | `world.gd:448-468 _street_view` (`桥头街`, day==2 lines) | Visibility should follow the player's location. |
| C6 | Rumor texts and consequences in code | `world.gd:471-484 FACTS`; `_on_learn` l.507-524; exclusion list l.566 | Cannot add rumors as data, and no procedural rumors. |
| C7 | Opening plants, starting cash, rent | `world.gd:53, 71-75` | Starting conditions should be data (owner #8: starting items and bills). |
| C8 | Price board reference prices; only 2 price categories | `world.gd:367-370 price_board` (68, 100); `price_mod` l.169-173 | Every category needs a market. |
| C9 | Zhouma daily news special case | `world.gd:285-296` | Should be a "newsmonger role" behaviour. |
| C10 | Dev backend sim is hard-coded per day | `world.gd:590-669` | Replace with routines. |
| C11 | Single counter, single `customer`; brother, lamp and bg scene state | `director.gd:24-27, 66-67, 328-342` | Several buildings and several NPCs present at once. |
| C12 | Story hooks | `director.gd:958-1043 call_hook` (`swap_rice_bag`, `ma_fee` fixed 100/120/150, `brother_money`, `sun_real_deed`, …); whitelist in `validate_data.gd:8` | Hooks should be a registry. |
| C13 | Night menu specifics | `director.gd:668-732` (diary needs benxin < 40, `tell_sun` gated on specific flags, max_actions per night), `_night_order` hard-codes `rice_jing_a` / `mercuro` and `chen_trust ≥ 2` (l.801-827), `_buyer_for` category→account (l.771-775), `_free_telegraph` inline JSON (l.871-879), `_diary_text` (l.881-889) | The night becomes "home" or "after hours", with a data-driven action list. |
| C14 | Ticket draft: fixed 30 days and 3%/month, `德字` prefix | `director.gd:434-440`, `_accept` l.583 (`30`), `ledger.gd:114-116` | Variable terms, renewals (#10). |
| C15 | `ending` op default ticket; chess = Chen's six factions; telegraph = Chen | `director.gd:235-240, 941-955, 902-927` | Fine as a story module; not a town primitive. |
| C16 | Session specifics | `session.gd:151-155` (tool unlock keys), `199-214` (medbook regex), `373` (`MAX_ROUNDS`), `380-381` (con-man), `290-304` (0.6 suggestion) | Make these data-driven per building or NPC archetype. |
| C17 | Stats fixed in code | `world.gd:118-127`, `validate_data.gd:9` | Town reputation per district or faction, police "heat", etc. |
| C18 | Tutorial targets = counter hotspots | `validate_data.gd:10 TARGETS`, `data/layout.json` | The town has map hotspots. |
| C19 | Fixed seed in the shipped game | `main.gd:409` | Randomness between runs (owner's key requirement). |
| C20 | Autoplayer defaults that assume the story | `autoplayer.gd:239-243` (keep 120 for Saturday's fee), `_telegraph` words, `_night` order | A town autoplayer needs its own policies. |

### 4.3 Concrete refactor plan (minimal-risk order)

**Step 0: Bug fixes worth doing regardless (each is a few lines).**
* (a) Random seed per new game; keep `--seed` for tests and show the seed in a debug overlay.
* (b) Add `day` and a visit counter to `mind.decide` semantic keys for repeatable situations.
* (c) Mean-reverting price walk: `mod += k·(1−mod) + shock`.
* (d) Tidy bonus double count in `_rescale_sell`.
* (e) Liabilities and todos get a payment/settlement path.

**Step 1: Split `director.gd` into four pieces without changing behaviour.**
* `script_vm.gd`: exec/do_step/fmt plus an **op registry** (`var ops := {"say": Callable(self, "_op_say"), …}`; `register_op(name, callable)`). `KNOWN_OPS` becomes `ops.keys()`, so `validate_data` stays in sync automatically. Same for hooks: `register_hook(fn, callable)`.
* `counter_module.gd`: `run_session`, `_offer`, `_accept`, `_ticket_draft`, `stow`.
* `night_module.gd`, `telegraph_module.gd`, `chess_module.gd`, `summary_module.gd`: register their ops.
* `story_flow.gd`: today's `run()` over `flow.json`, kept for the prologue or for scripted chapters inside the town.

Regression gate: all 63 existing tests must stay green.

**Step 2: Town layer (new modules, data-driven).**
* `data/town/buildings.json`:
  ```json
  {"buildings":{"dehoudang":{"name":"德厚当","kind":"pawnshop","account":"player","owner":"player","map":{"door":[12,7]},
     "hours":[1,2,3,4],"unlock":"","services":["buy","pawn","sell","redeem","renew"],"interior":"counter"},
   "police":{"name":"警察局","kind":"police","account":"保安队","owner":"ma","hours":[1,2,3,4],
     "unlock":"day() >= 7 or is('police_open')","services":["report_stolen","wanted_list","bail","fine"]},
   "rice":{"name":"米行","kind":"shop","account":"米行","services":["buy_from","sell_to"],"cats":["rice"]}}}
  ```
  Buildings unlock gradually through `unlock` conditions or an `unlock_building` op. Names are aligned with the existing schedule locations, so NPC routines work immediately.
* `town.gd` (World extension or a sibling): `player_loc`, `open_buildings()`, `npcs_at(loc)`, `move_player(to)` (costs time), and `observe_here()`, which replaces `_street_view` with "the player sees NPCs at the player's location".
* `town_loop.gd`: replaces `Director.run()` for town mode:
  ```
  while not over:
      r = await _wait({"type":"town","loc":…,"slot":…,"buildings":open,"npcs_here":…})
      match r.action:
          "go"    -> time cost, advance_slot as needed
          "enter" -> storylets for (building, slot) + walk-in queue → counter sessions
          "talk"  -> NPC dialogue storylet
          "sleep" -> night module → advance to 清晨
  ```
  For a real-time Stardew-like overworld, the overworld scene handles movement locally and only sends the discrete actions `go`/`enter`/`talk`/`sleep` as responses. Headless tests answer the same `town` beat.
* **Storylets** replace `day1.json` and `day2.json` timelines (`data/events/*.json`):
  ```json
  {"id":"zhao_needs_ransom","where":"dehoudang","slots":["上午","下午"],"when":"day() >= 2 and not is('zhao_done')",
   "weight":3,"once":true,"priority":10,"session":"d2_zhao"}
  {"id":"walkin_rice","where":"dehoudang","slots":["上午","中午","下午"],"weight":"2 + stat('koubei') / 25",
   "cooldown_days":1,"cast":{"pool":"townsfolk","need":"resources > 0.5"},"session_template":"tpl_sell_rice"}
  ```
  Selection: filter by `where`/`slot`/`when`/cooldown/once, then a weighted pick with `_rng("storylet|"+building)`. Authored story beats become high-priority `once` storylets.
* **Generated sessions** (fixes owner #7, #14 and adds randomness): `session_template` + `cast` pick + item template produce a concrete session dict (ask/floor from need, persona and market; sell-intent customers who want items currently in `stock`). Then reuse `Session.setup(world, def)` unchanged.
* **Item templates**: `{"tpl":"hairpin_gold","name_pool":[…],"market":[80,160],"fake_p":0.15,"condition_p":{…},"parts":[…with {grade} slots]}` instantiated with `_rng("item|tpl|day|n")`. Parents' heirlooms (owner #13) are authored unique items released by late-game storylets.
* **NPC routines** replace `_offscreen_life`. Per-NPC goals in `data/routines.json`, e.g. `{"npc":"zhao","when":"cash < 300 and is('son_taken')","options":[{"id":"pawn_deed","utility":…,"attrs":…,"steps":[…]},{"id":"sell_to_sun",…}]}`, decided by `mind.decide`. Steps run through the same VM (money moves through the ledger). Includes NPC-initiated `redeem` and `renew` visits for live pawns (owner #10), and sell-back or buy visits (owner #7).
* **Rumors as data** (`data/rumors.json`): `{key, texts:[hop0, hop1, hop2], on_learn:[{"npc":"ma","steps":[…]}], origin_rules}`, plus procedural rumors generated from ledger events: "X pawned Y", "the pawnshop bought stolen Z" (this ties into the police station).
* **Variable survival pressure** (`data/bills.json`, replaces fixed rent and `ma_fee`):
  ```json
  {"bills":[{"id":"rent","to":"保长","every":"month","due_dom":1,"base":30,"jitter":[0.9,1.3],
     "mods":[{"when":"stat('suspicion') >= 5","mul":1.25},{"when":"flag('door_flag') == 'white'","add":5}],
     "on_unpaid":[{"op":"stat","stat":"suspicion","delta":1},{"op":"debt","debtor":"player","creditor":"保长","amount":"{amount}"}]},
   {"id":"weichi_fee","to":"维持会公账","every":"week","weekday":6,"base":100,"jitter":[0.8,1.5],"wheel":"order"},
   {"id":"food","to":"市场","every":"day","base":3,"index":"rice_mod"}]}
  ```
  Amounts are drawn with `_rng("bill|id|period")`, and bills get a ledger-level `pay_liability(id)` with real settlement. This makes the daily pressure a variable, as the owner asked.
* **Police station** (owner's example): implement GameJev `Institution/Case` (`07_PLANNED_SPECS/DOMAIN_CONTRACTS_DRAFT.md`). It keeps a `wanted` list of stolen items (items with `origin:"stolen"` get a true owner), accepts reports (suspicion and favor trade-offs), runs searches (a wheel `order` plus a suspicion-weighted event) and handles fines and bail through the ledger (`保安队` account). It uses the existing `suspicion` stat and `faction_trust` for 维持会 and 城里的兵.
* **Calendar** (owner #3, #9): replace `date_text` with a real lunar/solar table or keep the 30-day approximation, but add a year rollover and a `year()` cond for the "continue the pawnshop or change profession" decision.
* **Make the effect-less levers real**: `door_flag` and `sign_board` change the walk-in storylet weights. `roles` (中间人, 双面, 口舌, 黑市) drive routines: a double agent (#18) shares rumors with two factions, and a 口舌 role is the news source in place of the `zhouma_news` special case.

**Step 3: Save/load.** World, Ledger and NPC records are plain dictionaries and arrays, so `to_dict()`/`from_dict()` is straightforward. Coroutine state inside the VM is not serializable, so the town loop should save only at `town` beats (between interactions) or at day rollover.

---

## 5. Tests: how they work today, and how to test town mode headlessly

### 5.1 Current harness

* `tools/run_tests.sh` (needs `GODOT=…`). Runs, in order:
  * `--headless --import`
  * `validate_data.gd`
  * the unit scenes: `test_dialogue`, `test_tidy`, `test_bargain`, `test_minds`, `test_v03`
  * in parallel with `xargs -P 6`: every plan in `plans.json` (39) plus a subset again through `--ui`; full playthroughs with policies `fair`/`greedy`/`random1-3` (core) and `fair`/`greedy`/`random2` (UI); anti-stuck runs (`--say-mode=esc|scene|skip`, `refuser` core and UI).

  A test fails on a non-zero exit **or on any log line matching** `SCRIPT ERROR|ERROR|WARNING|Parse Error|PLAYTHROUGH FAILED|DATA ERROR|FAIL:`. That means a `push_error` anywhere (unknown op, failed condition) fails the run.
* `run_playthrough.gd` (a SceneTree script):
  * args: `--until=`, `--policy=`, `--seed=`, `--plan=`, `--ui`, `--say-mode=`
  * either builds `Director` directly or instantiates `scenes/Main.tscn` and drives it through `auto_apply`
  * connects checkpoints and `director.finished`, with a 240 s timeout
  * at the end it checks autoplayer errors, plan expectations (`check_expectations`), `ledger.check_invariants()` and that the target checkpoint was reached
  * prints stats and flags, then cleans up `DB.shutdown()` to avoid ObjectDB leak warnings.
* `autoplayer.gd`:
  * subscribes to `beat` with `CONNECT_DEFERRED`, so it answers on the next frame
  * counts beats (max 6000, against infinite loops) and **checks ledger invariants on every beat**
  * `respond(b)` covers every beat type; the counter policy inspects parts one per beat, takes extras and deals, makes offers (`fair`/`greedy`/`random`/plan-specified named values `suggest|ask|floor|low|fund|<int>`), and judges fakes
  * plan fields: `until, base, choices (queue), ticket, stow, telegram, night1/night2, sessions{id:{inspect, extras, deal, offer(s), deselect, select, keep_fake}}, expect{flag:value|null}, expect_stats{stat:">=N"}`; by default every session listed in a plan must actually occur
* `validate_data.gd` statically checks: flow chapters exist; every step op is in `Director.KNOWN_OPS`; `when`/`cond`/`expr` parse (after `Cond.rewrite`); session-only functions are not used outside sessions; speakers, sessions, scripts, hooks, pages, items, stats and slots are valid; telegraph words are in the codebook; sprites and portraits exist; every CJK glyph in the data is present in the subset font.
* Unit-style scenes (`test_bargain`, `test_minds`, part of `test_v03`) build `World.new(); w.setup(seed)` plus `Session.new(); s.setup(w, {…inline def…})` **without a Director**. This is the cheapest way to test core logic.

### 5.2 Proposed town-mode tests, in the same style

1. **Core sim tests** (no Director, like `test_bargain`): `test_town_sim.gd -- --days=60 --seeds=1..50`:
   * **determinism**: the same seed gives an identical hash of `world_log + ledger.journal`
   * **variety**: different seeds produce different storylet, customer and price sequences, e.g. at least 80% distinct day-1..7 storylet sequences over 50 seeds
   * **invariants** after every slot
   * **price bands**: every `price_mod` stays in [0.7, 1.5] and does not sit at a cap for more than N days
   * **bills**: every due liability ends `paid` or fires `on_unpaid`; none is left stale
   * **contract lifecycle**: across seeds, `redeemed`, `renewed` and `forfeited` all occur
   * **unlock pacing**: the police station opens by day N in at least X% of seeds

   Measured cost: 60 days of `advance_slot` took 73 ms, so 50 seeds × 60 days runs in seconds. `decide()` costs about 1 ms per candidate, so budget for it.
2. **Town playthroughs** (Director/TownLoop + Autoplayer). Add a `town` beat response policy: `route` (`[[day, slot, "go"|"enter"|"talk"|"sleep", target]…]`) or `wander` (seeded random over open buildings). Reuse the existing counter, choice and night responders unchanged, because sessions and VM ops are reused. Extend `plans.json` with `town_plans`:
   ```json
   {"town_week1_police":{"mode":"town","days":7,"base":"fair","seed":11,
     "route":[[1,"上午","enter","dehoudang"],[3,"下午","enter","police"]],
     "expect":{"police_open":true},"expect_stats":{"suspicion":"<=3"},
     "expect_ledger":{"bills_unpaid":"==0","contracts_active":">=1"}}}
   ```
   `run_playthrough.gd` gains `--mode=town --days=N`; checkpoints become `day_<n>_done` (emitted at the 清晨 rollover).
3. **Anti-stuck in town**: `refuser` (enters every building and refuses everything) and `sleeper` (only sleeps) must reach day N with no errors, and the player is never left with an empty action list.
4. **Monte-Carlo balance** (not a pass/fail gate, but printed): over 200 seeds × 30 days with policies `fair`/`greedy`/`sleeper`, report the cash distribution, bankruptcy (unpayable bills) rate and koubei/suspicion spread. Assert loose bands, e.g. `sleeper` goes bankrupt in more than 50% of seeds (pressure exists) and `fair` survives in more than 70%.
5. **`validate_data.gd` extensions**: schemas for buildings, storylets, bills, routines, rumors and item templates; every `where` names a building; every `cast` pool filter, `when` and `weight` expression parses; every `session_template` instantiates with a few seeds without `push_error`.
6. **UI path**: the same plans with `--ui` once the overworld scene exists. The overworld's `auto_apply` turns a `town` response into "walk to door → enter" so the UI code path is exercised.

---

## 6. Probe results (scratch copy, not committed)

Script: `scratchpad/understand/repo_copy/scripts/tests/probe_town.gd`. Run with `Godot --headless --path <copy> -s res://scripts/tests/probe_town.gd`, about 1.0 s in total.

* **60 days of `advance_slot` without a Director: 73 ms**, no errors, ledger invariants OK. Street lines: 93; news items: 54.
* **Calendar:** day 26 = 二月三十, 27 = 三月初一, 56 = 三月三十, 57 = 四月初一. Weekdays are correct. The year never changes.
* **Prices:** rice_mod ranged [1.03, 1.30], reaching the cap; med_mod was 1.35 at day 60. This confirms the upward ratchet.
* **Rumors:** after 60 days only 4 keys exist (`liangmin_notice`, `hospital_requisition`, `zhao_sold_land`, `zhao_son_free`), with 39 knowledge entries. There is no new content after day 2.
* **NPC locations at day 60** follow the `default` schedules. `wangshan` is permanently absent (hard-coded day-1 exit).
* **`backend_simulate(30)`** works: Xiaoding repays a loan in halving instalments; the weekly fee note appears every Saturday; there is a random remittance.
* **Pawn lifecycle without a Director:** a contract opened on day 1 (30-day term) became `forfeited` by day 37, and the item moved to `stock`.
* **Mind cost:** 200 × `decide()` with 3 candidates = 571 ms, about 2.9 ms per call.
* **`Cond.new(world, null)`** works without a Director for non-`var()` functions.
* **Starting state:** the rent liability `{保长, 铺租, 30, due 7, 未付}` and its countdown todo. Nothing ever settles them.

---

## 7. How the owner's issue list maps onto the core

| owner issue | core status / where to change |
|---|---|
| #3 perpetual calendar | `world.date_text` (30-day months, fixed year); add `year()` and a real table |
| #5 manual appraisal / certificate | `items/*.json parts` + `Session.inspect` (tool-gated, notes, est narrowing) are the base; add appraisal-certificate objects on the item (`history`) |
| #7 never selling | sell sessions exist only when authored; needs walk-in buyer storylets plus `stock`-aware generated sell sessions |
| #8 starting items and bills | `world.setup` rent + `give_stock` op; move to `data/start.json` + `bills.json` |
| #9 year-end career choice | needs a year and a storylet with `when: "year() == 1939 and slot() == …"` |
| #10 live pawn with extension | `ledger.contracts.renewals` exists but is unused; add `renew()`, NPC routine visits, and custom terms (the 1-week sell / 2-week buy window rule) via parameterized `open_pawn` |
| #13 late-game valuables / heirlooms | authored unique items + storylets gated on `day()`/`year()` |
| #14 buy high / sell low; single item | v0.3 unified sell pricing (`_rescale_sell`) + `set_selected`; fix the tidy double count; generate the buy ask/floor from market too |
| #15/#16 interaction during bargaining, player chooses | `extras` + `deals` in sessions; generic templates for negotiation extras (ask origin, show certificate, threaten police) |
| #17 relationship visualization | `npcs[n].rel[target]` has 8 dimensions + `faction_trust`; `favor:` mapping; gifts via `give_item`; telegrams via the telegraph module |
| #18 double agent / middleman / spy | `cast.roles` is display-only today; make roles drive routines and rumor routing (sharing with multiple factions) |
| randomness (key) | fix the seed (C19), keys (§3.4), procedural storylets, items, customers, bills and rumors (§4.3) |
