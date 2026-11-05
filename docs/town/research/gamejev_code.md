# GameJev Living World v0.5: how the code works, and how to port it to the 德厚当 town (GDScript)

Source read in full: `03_CODE/gamejev_living_world_v05/src/gamejev_living/{randomness,world,pack,session,ports}.py`, `src/gamejev_world/{bundle,ports,session}.py` (+ the head of `reference.py`), `src/gamejev_persona/*.py`, `livingpacks/{workshop,orbital_station}/*.json`, `DESIGN_v0.5.zh-CN.md`, `README.md`, `examples/living_world_demo.py`, and the key tests in `tests/test_living_world.py`.
Already in the game: `scripts/persona/PersonaResidual.gd`, `scripts/core/mind.gd`, `scripts/core/world.gd`.

**Verified by running code:**
- Python demo (`living_world_demo.py`, workshop, 48 h, seed 42), run with `python3 -I` from my own runner script.
- A **GDScript port of `draw()` / `weighted_choice()` / `replay_draw()`**. It matches Python exactly, including Chinese strings in keys. Tested in headless Godot 4.7.
- A **GDScript town-generator prototype** that reads a draft `town_pack.json`. Tests passed: same seed gives the same output, save/load at day 10 continues identically, a different seed gives different output, and climate/market draws do not change with player behaviour.

Prototype files (all under `scratchpad/understand/godot_draw_test/`): `jev_rng.gd`, `town_sim.gd`, `town_pack.json`, `test.gd`, `test_town.gd`, `project.godot`.
Run with: `Godot_v4.7-stable_linux.x86_64 --headless --path <dir> --script res://test_town.gd`.

---

## 0. Summary

GameJev v0.5 has four layers:

1. **A world clock that processes events one at a time.** A heap of `(due_hour, priority, seq, event)`. The event kinds are `wheel`, `body`, `schedule`, `task_due`, `norm`, `influence`, `message` and `npc`. Time only advances to the next due event. There is no per-frame tick.
2. **Separate random streams with no shared state.** Every random number is `sha256(json([seed, domain, key]))` turned into a 53-bit uniform value. Because no random generator object is shared, a player action can never use up a weather draw. Saves stay reproducible, and advancing 24 h in one call or in 48 half-hour calls gives the same state.
3. **A world wheel** (a weighted random pick among outcomes). Each wheel spins on a fixed period with an always-available `quiet` outcome. Each outcome weight is:
   `weight × cooldown gate × (endogenous only: pressure gate and (1 + bias·pressure)) × season weight`.
   Endogenous pressure comes only from large, material events. Those events must pass a magnitude threshold, a per-actor daily cap, a probabilistic channel, attenuation, a delay and a global daily cap, and they decay with a half-life.
4. **NPCs that run a persona model:** a 96-dimensional state and 32-dimensional actions. Each candidate's score is readable rule-based utility plus 0.35 × a small residual neural network. Candidates are sampled in two levels (first the action family, then the action within it), using a per-agent replay draw. Severe actions are possible, but their total probability is capped by a hazard that depends on simulation time.

   NPCs live on schedules. They have bodies (consumption, fatigue), commitments with escrow and a grace period, and they see only local events. News of an event spreads only along social links, with hop count, delay, confidence decay, TTL and de-duplication.

For the town game:

- **Port as-is:** the randomness, the wheel maths, the rumor relay, the norm/sanction formula, commitments (live pawns), and the persona sampler.
- **Simplify:** time (use days and slots), regional influence (replace with a few named town pressures), the body model (replace with daily ledger needs), and transactions (snapshot once per day).
- **Drop:** the revision/ticket/digest machinery.

---

## 1. Seeding and how each random number is derived

### 1.1 The function (`gamejev_living/randomness.py`)

```python
def draw(seed: int, domain: str, *key) -> float:
    raw = json.dumps([int(seed), domain, key], ensure_ascii=False,
                     separators=(',', ':'), allow_nan=False).encode()
    return (int.from_bytes(hashlib.sha256(raw).digest()[:8], 'big') >> 11) / (1 << 53)
```

- `key` is a Python tuple, so it serialises as a nested JSON array. Example: `draw(42,'wheel:climate',1)` hashes the UTF-8 string `[42,"wheel:climate",[1]]`.
- The output is in [0,1) and is exactly representable as a double, with 53 bits of entropy.
- `weighted_choice(rows, u)` is a cumulative pick: threshold = `u × Σw`, return the first key with `threshold < cumulative`. As a fallback it returns the last key with positive weight. It rejects empty rows, duplicate keys, negative/NaN weights, a total of zero, and u outside [0,1).

The persona model has its own stream (`selection.replay_draw`):

`sha256("gamejev-persona-v03|{seed}|{agent_id}|{decision_counter}")`, top 53 bits.

So each NPC's n-th committed decision always gets the same random value, whatever else happens in the world.

### 1.2 Domains and keys used

| Domain | Key | Used for |
|---|---|---|
| `wheel:<wheel_id>` | `(index,)`, where index = ⌊t/period⌋+1 counts spins | which wheel outcome happens |
| `message_relay` | `(root_event_id, relayer, recipient, hop)` | whether a rumor passes along one social link |
| `physical_influence` | `(root_event_id, from_area, to_area, hop)` | whether pressure passes along one trade/region link |
| `norm_detection` | `(root_event_id, rule_id)` | whether the local authority notices a violation |
| persona `replay_draw` | `(agent_id, decision_counter)` | which action an NPC picks |

### 1.3 Why it is built this way

1. **Player actions cannot shift other random streams.** The test `test_weather_trajectory_unaffected_by_player_operations` runs two worlds, one where the player does extra actions, and checks that the exogenous wheel logs are identical. `test_rng_streams_do_not_consume_each_other` makes 100 persona draws and checks that `draw(4,'weather',8)` is unchanged.
2. **Resume is exact.** A save stores `seed`, `wheel_indices`, the queue, the de-duplication sets and every counter. Because the random numbers are pure functions of (seed, domain, key), there is no generator state to save.
   - `test_running_world_save_restores_full_random_trajectory`: save at 11 h, restore, advance to 48 h, and the snapshot digest is identical.
   - `test_chunked_time_and_long_time_advance_same_causal_result`: one `advance_to(24)` equals 48 half-hour steps.
3. **Keys describe meaning, not call order.** The key is "which event, which edge, which spin". So previewing a decision, calling a function twice, or changing the frame rate changes nothing. `preview()` does not spin wheels or touch any random stream (`test_preview_does_not_spin_world_or_mutate_rng`).
4. **Saves are tied to their content.** The pack hash and model hash are checked on restore. A mismatch raises `explicit migration required`.

### 1.4 GDScript port (verified bit-exact)

`scratchpad/understand/godot_draw_test/jev_rng.gd`:

```gdscript
class_name JevRng
const TWO_53 := 9007199254740992.0
static func draw(seed: int, domain: String, key: Array) -> float:
    return _u53(sha256_bytes(canon([seed, domain, key])))
static func _u53(b: PackedByteArray) -> float:          # == (u64 >> 11) / 2^53
    var v := 0
    for i in range(6): v = (v << 8) | int(b[i])
    v = (v << 5) | (int(b[6]) >> 3)
    return float(v) / TWO_53
static func sha256_bytes(t: String) -> PackedByteArray:
    var c := HashingContext.new(); c.start(HashingContext.HASH_SHA256)
    c.update(t.to_utf8_buffer()); return c.finish()
static func replay_draw(seed: int, agent_id: String, counter: int) -> float
static func weighted_choice(rows: Array, u: float) -> String   # rows = [[id, weight], ...]
```

`canon()` is a JSON writer that matches Python's `separators=(',',':'), ensure_ascii=False` output for ints, strings, bools and nested arrays.

Godot-specific detail: after a JSON round-trip, ints come back as floats. So `canon()` prints whole-number floats as ints. Without this, a loaded save would hash `3.0` instead of `3` and every draw would change.

Results compared with Python (all identical to 17 significant digits):

| Domain | Key | Value |
|---|---|---|
| `wheel:climate` | `[1]` | 0.06858027750188644 |
| `message_relay` | `["event:7","zhouma","linsao",1]` | 0.23250702028586301 |
| `轮盘:米价` | `[5,"德厚当"]` | 0.95322003511406195 |
| `replay_draw` | `(42,"A",0)` | 0.6700750373336426 |

`weighted_choice` with weights 8/3/2/0.5 and u=0.9 returns `rain`, same as Python.

The current game uses `RandomNumberGenerator.seed = hash("%d|%s|%d|%d")` in `world.gd::_rng`, and `hash(world_seed|npc|semantic_key)` in `mind.gd`. That is already keyed by meaning, which is the right idea. But it is a 32-bit `String.hash()` feeding a PCG generator: there is more risk of collisions, and it cannot be checked against Python. **Replace both with `JevRng.draw`.**

---

## 2. World wheels, the clock, pressure and consequences

### 2.1 Clock (`LivingWorld` + `LivingSession.advance_to`)

- **Queue rows** are `(due_hours, PRIORITY[kind], queue_sequence, {'kind','payload'})`, using `heapq`. The priorities break ties at the same hour in this order:
  `wheel 0 < body 1 < schedule 2 < task_due 3 < norm 4 < influence 5 < message 6 < npc 7`.
  So the world changes first, then routines, then messages are delivered, and NPC decisions come last.
- **`advance_to(t)`:** while `peek_due() ≤ t`:
  - `pop_event()` sets `time = due` and runs `process_event()`.
  - If the result is a message, it is delivered to the recipient's persona (`engine.observe`).
  - If the event is an `npc` wake, the NPC is not resting, and it has not decided at this time yet, then `preview()` and `commit()` run immediately. Commit executes the command and then drains any messages that became due.
  - At the end, `set_time(t)`.
  - The whole call is transactional: the world, agents and tickets are rolled back if any step fails, and there is an `event_budget`.
- **Initial scheduling (`_initialize_events`):**
  - Each wheel's first spin is at `(⌊t/period⌋+1)·period`. After each spin, the next one is pushed at `(index+1)·period`. This is an absolute grid, so it never drifts.
  - Body metabolism runs every `metabolism_period_hours` (4 h).
  - Each NPC wakes every `npc_period_hours` (2 h).
  - Each schedule slot fires at `day_start + at_hour`, then again 24 h later.

### 2.2 Wheel algorithm (`_spin_wheel`)

```
season   = ⌊now / season_hours⌋ mod 4
pressure = world_pressure() if mode == 'endogenous' else None    # exogenous wheels never read it
for e in outcomes:
    w = e.weight
    if now - wheel_last[wheel:e] < e.cooldown_hours: w = 0
    if pressure is not None and pressure < e.pressure_min (default 0): w = 0
    if pressure is not None: w *= max(0, 1 + e.pressure_bias · pressure)
    w *= e.season_weights[season]   (default [1,1,1,1])
u = draw(seed, 'wheel:'+id, index);  choice = weighted_choice(rows, u)
wheel_last[wheel:choice] = now
wheel_log.append({wheel, index, time, mode, outcome, draw:u, pressure_input, probabilities, season})  # debug only
apply effects; push next spin at (index+1)·period
```

**Rules enforced when a pack is loaded (`pack.py`):**
- Every wheel must have an outcome with id `quiet`, weight > 0, no effects, cooldown 0 and no `pressure_min`. This "always-eligible quiet" outcome means most spins nothing happens, and that is intended.
- An exogenous wheel may not declare `pressure_bias` or `pressure_min`.
- Season weights must be a list of four numbers ≥ 0.
- Effect ops are restricted to a whitelist: `weather, supply, danger, publicness, norm_strength`.

**What effects do (`_wheel_effect`):**

| Op | What it changes |
|---|---|
| `weather` | Sets the global axis `axes.weather`. This adds 0.3·weather to every area's perceived `local.danger`. |
| `supply` | Adds or removes the resource in an area (or all areas with `"*"`). It is clamped so stock cannot go negative and is recorded as produced/consumed in the ledger. |
| `danger`, `publicness` | Sets an area signal. |
| `norm_strength` | Sets how strictly local rules are enforced in an area. |

Every effect creates a receipt (`world.<wheel>.<choice>`, with no source actor). The receipt is published as a direct observation to everyone in that area, with relay off ("a storm has no blamed actor"), using the appraisal `block .2 if loss/heavy weather, threat .2·value, help .2 if supply>0`. It also leaves a trace in the area.

**Example wheels in the workshop pack (day = 24 h, season = 96 h):**

| Wheel | Period | Mode | Outcomes (weight; cooldown) |
|---|---|---|---|
| climate | 6 h | exogenous | quiet 8; clear 3; rain 2 (cd 6, seasons [2,1,1,.5]); gale 0.5 (cd 18) |
| logistics | 8 h | endogenous | quiet 6; delivery 2 (cd 8, bias −0.5, supply +4 to all areas); shortfall 1 (cd 16, bias +8, supply −2) |
| civic | 12 h | endogenous | quiet 8; tighten 0.5 (cd 24, pressure_min .05, bias 4, norm_strength 1.0); ease 1 (cd 24, norm_strength .6) |
| calendar | 24 h | exogenous | quiet 8; gathering 2 (cd 48, publicness .9); ordinary_day 3 (publicness .5) |

**Actual run (workshop, seed 42, 48 h):**
- 20 spins. For example, climate#1 at t=6: draw 0.0686 → quiet, with probabilities quiet .516 / clear .194 / rain .258 / gale .032. Climate#4 at t=24: draw 0.9975 → **gale**. At t=30 gale had probability 0 because of its cooldown.
- Logistics produced delivery four times, all with pressure 0.
- 54 NPC decisions, 5 commitments fulfilled, 97 receipts, 63 delivered observations.
- Ledger: initial 36, produced 60, consumed 10.32.
- One influence attempt (C took 8 units in the isolated area) gave strength 0.4 locally, then stopped with `no_transmission_channel`.

### 2.3 Endogenous pressure: how actions reach the world (`_offer_influence`, `_transmit_influence`)

1. Only these handlers are eligible: `withdraw_shared, deposit_shared, work, repair, damage`. Signs: withdraw and damage push +1, everything else −1. A successful commitment pushes −1. Everything else stops here: greetings and small talk never reach the world.
2. If `magnitude < min_magnitude` (6 units in the workshop), log `blocked below_material_threshold`.
3. `strength = min(magnitude/normalizer, per_actor_daily_cap − spent_today[actor])`. The cap is charged for the *attempt*, which prevents retry spam. If strength < `min_signal`, it is blocked.
4. The area's `regional_pressure` becomes `decayed(value) + sign·strength`, clamped to [−1,1].
5. For each `trade_links[area]` edge, an `influence` event is pushed at `+delay_hours` with `signal·attenuation`, `hops=1`.
6. When it arrives:
   - It is de-duplicated per `root|dst`.
   - It is dropped if `|signal| < min_signal` or `hops > max_hops`.
   - It passes only if `draw('physical_influence', root, from, dst, hops) < transmission_probability` (0.35).
   - If `dst == '__world__'`: the signal is clipped by `global_daily_cap` (0.2/day) and `axes.resource_pressure = bounded(decayed(old) + accepted)`.
   - Otherwise it updates that region's pressure and continues to unvisited next edges with further attenuation.
7. Decay: `world_pressure() = value · 2^(−Δt / half_life_hours)` (24 h), computed lazily from the time it was last set.

The design doc reports that in 80 seeds, 11 runs reached world level after one large take. `regional_pressure` is stored but **only `axes.resource_pressure` is read by the wheels** in v0.5.

### 2.4 Time scales and thresholds (workshop pack)

| Item | Value |
|---|---|
| day / season | 24 h / 96 h |
| wheels | 6 / 8 / 12 / 24 h |
| NPC wake | 2 h |
| body metabolism | 4 h |
| commitments: promise / work / repair | 1.5 / 1 / 0.75 h |
| commitment grace | 0.25 h |
| message relay delay | 0.5 h (orbital: 0.05 h) |
| message TTL | 12 h |
| norm detection → sanction | +0.05 h |
| influence delay | 1 h per hop |
| influence half-life | 24 h |

Emotion half-lives are in hours: anger 1.5, fear 0.8, joy 3, sadness 6, hope 8.

The orbital_station pack is the same world with resources scaled 100× (`charge_units`), a different bindings range (`maximum` 1000/2000) and a 0.05 h relay delay. The persona model produces the same decisions in both because the bindings normalise the units.

### 2.5 Data format: three files per world

**`worldpack.json` (v0.4 ports layer):**

| Field | Contents |
|---|---|
| `manifest` | api/model/schema hashes, `resource_key`, time unit `game_hour`, 96/32 dimensions |
| `knowledge.actions` | Base action templates. Each has `id, family, scope self/others/objects, features{32-dim subset}, event_id, capabilities, requires_reach, target_tags, severity 0..3, cooldown_hours, optional parameter grid`. |
| `knowledge.events` | Effects are empty: effects are executed by the host. |
| `bindings` | Map world signals onto persona features, e.g. `{"destination":"needs.resources","source":"self.inventory","minimum":0,"maximum":10,"invert":true,"missing":0.5,"saturation":"clamp"}`. Only `context.*`, `needs.*` and `regulation.*` may be written. |
| `executions` | `{handler, amount, appraisal{7 fields}, role_multipliers}` |
| `facts` | Public or role-gated facts |
| `presentation` | `{text_id, animation_id, audio_id}` |

**`living.json` (v0.5 extension):** `version:"gamejev-living-world/1"`, plus:
- `actions` (more templates) and `executions` (handlers `greet, move, promise, work, repair, damage, cancel_task, withdraw_shared, deposit_shared, wait`, with `duration_hours`, `output_amount`, `tool_tag`, `required_role`), and `presentation`.
- `identity{restricted_objects{obj:role}, groups{g:{grants_roles}}}`
- `norms[]`, `communication{}`, `influence{}`, `wheels[]`
- `routine{npc_period_hours, metabolism_period_hours, schedule{npc:[{at_hour, area, activity: work|rest|social|free, obligation?:event_id}]}}`
- `limits`, `tasks{max_open_per_actor:1, deadline_grace_hours}`, `time{day_hours, season_hours}`, `bodies{consumption_per_hour, fatigue_per_hour, rest_recovery_per_hour}`

Wheel snippet:

```json
{"id":"civic","period_hours":12.0,"mode":"endogenous","outcomes":[
  {"id":"quiet","weight":8,"cooldown_hours":0,"effects":[]},
  {"id":"tighten","weight":0.5,"cooldown_hours":24,"pressure_min":0.05,"pressure_bias":4.0,
   "effects":[{"op":"norm_strength","value":1.0,"area":"local"}]},
  {"id":"ease","weight":1,"cooldown_hours":24,"effects":[{"op":"norm_strength","value":0.6,"area":"local"}]}]}
```

Norm and communication snippet:

```json
"norms":[{"id":"shared_stock_permission","area":"local","handlers":["withdraw_shared","damage"],
          "required_role":"steward","fine":1.0,"detect_probability":0.45,"forgiveness":0.4,"informal_disapproval":0.12}],
"communication":{"delay_hours":0.5,"confidence_decay":0.65,"relay_probability":0.4,"max_hops":3,"ttl_hours":12.0,"min_confidence":0.2}
```

**`initial_world.json`:**
- `areas{id:{holdings{res}, context{exit_access, enforcement}, signals{danger, publicness}, allow_extreme}}`
- `entities{id:{area, holdings, controller npc|player, roles, capabilities, tags, public_self_signals{fatigue}, memberships}}`
- `links{npc:[npc...]}` (the social graph for rumors)
- `routes{area:[area...]}` (where actors can walk)
- `trade_links{area:[area | "__world__"]}` (the material influence graph)
- `objects{id:{area, owner, tags, condition}}`
- `private_facts`

### 2.6 How an event turns into consequences

Every executed action or world event goes through `_new_receipt`. That writes a history row:
`{id:"event:N", cause_id, time, source, target, area, event_id, handler, magnitude, details, cause_semantics}`.

`cause_id` is explicitly **not** a claim that one thing counterfactually caused another.

Then:
1. `_publish` sends direct observations to everyone in the same area, except the source and unconscious actors. Greetings and promises are private: they go only to the target, with no relay.
2. `_trace` adds a public or private visual trace to the area, kept in a rolling cache of 128.
3. `_norms` may queue a sanction.
4. `_offer_influence` may start a pressure signal.
5. Cooldowns are set on the actor.

---

## 3. NPC life away from the player, commitments, encounters, rumors

### 3.1 Schedules (`_routine_slot`)

At each `at_hour` slot:
- If the actor has a `busy_task`, the result is `busy`: they stay where they are.
- Else, if the target area is neither the current area nor directly reachable via `routes`, the result is `unreachable`. Nobody teleports.
- Otherwise the body is updated, the actor moves to the area, and `activity` is set to work, rest, social or free.

A routine receipt is published with `help .04` and no relay: small habits are visible locally but are not gossip.

If the slot has an `obligation` (e.g. `living_work`) and it applied, a `duty:{npc}:{day}:{slot}` record is created. The matching candidate is executed **directly, without the persona model**. A duty is a real commitment: the material is reserved, the machine is locked, and output appears later.

The slot repeats every `day_hours`. Resting NPCs skip persona decisions, and `_ready` only allows `wait/move/greet/cancel` while resting or busy.

### 3.2 Autonomous decisions

Every 2 h each NPC wakes. If it is not resting:
1. `perceive()` builds a local view: actors and objects in the same area, `place:` destinations, its own `task:` entry, and `exec_ready:<action>` flags. Readiness is checked per target: holdings, role permission, tool availability and machine condition.
2. The world signals are: `self.inventory, local.inventory, self.fatigue, self.hunger, self.reputation, local.publicness, local.danger(+.3 weather)`.
3. The bindings turn these into the 96-dim state.
4. The persona model decides (section 4).
5. `validate_and_execute` runs, using the **same rules as for player commands**.

The demo produced 54 NPC decisions in 48 h for 3 NPCs.

### 3.3 Body and needs (`_update_body`, every 4 h and on every move)

```
demand = dt · consumption_per_hour
consumed = min(holdings, demand)        # taken from the actor's own holdings and recorded in the ledger
hunger  += (demand − consumed) / max(1, demand)  −  (0.025·dt if fully fed)
fatigue += fatigue_per_hour·dt   (or −rest_recovery_per_hour·dt while resting)
```

Fatigue feeds `regulation.fatigue` and `needs.rest`. Holdings feed `needs.resources`. Hunger is tracked but not bound into the persona state in these packs. The player's body is updated the same way, but the player's mood is never decided by the AI.

### 3.4 Commitments (W07: the template for live pawns and appointments)

`promise`, `work` and `repair` immediately move `amount` out of the actor into `escrow`. They create a task `{id, actor, target, area, kind, status:"pending", escrow, created, due, output, tool_id, aux_tool, root}`, lock the tools, and push `task_due`.

At `task_due` (`_finish_task`), the task is valid only if:
- the actor is in the task's area;
- for a promise, the target is in the same area;
- for work/repair, the tool is still locked by this task, and for work the machine condition is > 0.3.

If it is invalid and not cancelled, one retry is pushed at `due + grace`, marked `grace_pending`.

| Outcome | Effect |
|---|---|
| promise succeeds | escrow goes to the target |
| work succeeds | escrow is consumed; output goes to the area; machine wear −0.03 |
| repair succeeds | condition = 1 |
| fails or cancelled | escrow refunded; status `missed` or `cancelled` |

Area reputation changes by +0.10 on success and −0.12 on failure. The result is published: on success help 0.8; on failure block 0.4 and unfair 0.2. A cancel action (`living_cancel`) also refunds and releases the locks. There is never a double payout.

### 3.5 Encounters and reunions

There is no separate "encounter" system. **Being in the same area is the encounter**:
- `perceive` lists only actors in the same area.
- `greet`, `share` and `promise` require same-area targets.
- Direct observation goes to everyone in the area.
- Sanctions need an authority present.

**Reunions are commitment checks.** A promise pays out only if both parties are in the same area at `due` (or within grace); otherwise it is missed. A sanction for a violator who has left becomes `notice_pending` (`actor_no_longer_present`) and is not collected.

The design deliberately has no forced revisits: no rule makes an NPC come back for the player's story.

### 3.6 Norms and institutions (W06)

`_norms(receipt)` checks every rule whose `area` and `handlers` match and where the actor lacks `required_role`:

```
officers = sorted(actors in the same area with role 'authority', conscious, not the actor)
if none: nothing happens            # no witnessing authority, no "world fine"
officer  = officers[0]
rapport  = max(0, known_reputation[officer][actor])
chance   = detect_probability · area.norm_strength · (1 − forgiveness · rapport)
if draw(seed, 'norm_detection', root, rule_id) < chance: push 'norm' event at +0.05 h
```

Sanction:
- `paid = min(holdings, fine)`. The fine is never more than the actor has.
- `paid` goes to the area treasury.
- Area reputation −0.2.
- A notice is published to the violator only.

Separately, *informal disapproval* is applied per observer when the message is enqueued: unfairness rises by `informal_disapproval`, or by half that if the observer holds the required role. It is local, not global karma.

The civic wheel changes `norm_strength` (ease 0.6 or tighten 1.0), so how strict the authorities are is itself driven by the world.

### 3.7 Rumors and knowledge (`_enqueue_observation`, `_deliver_message`)

- **Message:** `{event_id(root), recipient, origin_time, delivery_time, channel: direct|relay, reporter_id, hops, base_appraisal, confidence, relay_allowed, visited, observation{... appraisal × confidence}}`.
- **Enqueue rules:**
  - Drop if `due − origin_time > ttl_hours` or `confidence < min_confidence`.
  - **De-duplicate on `root|recipient` at enqueue time.** The first path to reach someone wins, and loops cannot multiply evidence (`test_message_loop_cannot_multiply_single_source_evidence`).
- **Delivery:**
  - Mark delivered and append to `known_events[recipient]`.
  - Update the recipient's view of the source: `known_reputation[recipient][src] += .15·conf·(help − unfairness)`.
  - Then, if relay is allowed and `hops < max_hops`, for each sorted `links[recipient]` that is not visited and not the source: pass if `draw('message_relay', root, recipient, dst, hops+1) < relay_probability`. Enqueue at `+delay_hours` with `confidence·confidence_decay`, `hops+1`, reporter = recipient.
- **The NPC's mind:** `session._deliver` passes `observation` to `engine.observe` → `affect.appraise`. That updates emotions, goals, the relation toward the *source*, and episodic memory with tags `betrayal` (unfair·intent > .35), `humiliation` and `help`. Evidence IDs are de-duplicated.
- **Player:** gets `player_feed()` (delivered messages only) and `visible_world()` (local objects, public or known traces, own `known_reputation`, own commitments). Never `wheel_log`, `axes`, the queue or `private_facts` (`test_player_perception_never_contains_future_wheel_or_hidden_ledger`).
- **Tested numbers:** with `relay 1.0, decay .8`, C hears at hop 2 with confidence 0.64, 1 h after A saw it directly. TTL 0.6 h stops hop 2.
- **Not implemented** (the doc says so): content distortion, lying, and combining evidence from several sources. The game's `world.gd FACTS` text variants that change by hop count are a game-side addition worth keeping.

---

## 4. Persona model (`gamejev_persona`)

### 4.1 State: 96 dimensions in 12 groups (`schema.py`; order matters)

| Group | Count | Features |
|---|---|---|
| traits | 12 | openness, conscientiousness, sociability, compassion, emotional_reactivity, honesty, assertiveness, impulsivity, patience, risk_tolerance, attachment_security, adaptability |
| values | 8 | autonomy, fairness, loyalty, achievement, security, benevolence, order, novelty |
| cognition | 8 | Se Si Ne Ni Te Ti Fe Fi (MBTI preset: stack .85/.65/.45/.25 blended with .5 at type_strength .7) |
| motives | 9 | Enneagram core = .35+.5·s, wing = .35+.25·s |
| instincts | 3 | preservation, social, intensity |
| emotions | 10 | anger fear sadness joy shame guilt disgust surprise hope arousal |
| needs | 8 | safety resources rest belonging status control information meaning |
| relation (per target) | 8 | trust affection respect fear resentment indebtedness familiarity dependence (default .5/.35/.5/0…) |
| context | 10 | time_pressure publicness enforcement exit_access support ambiguity norm_pressure threat stakes opportunity |
| memory (per target, computed) | 8 | positive negative betrayal help humiliation success failure recency |
| goals | 8 | acquire avoid_loss connect understand defend_boundary repair_relation fulfill_duty explore |
| regulation | 4 | self_control reappraisal flexibility fatigue |

**Actions: 32 features.** Each candidate is a 32-dim vector in [0,1]:
gain, safety, information, affiliation, autonomy, status, fairness, care, order, novelty, effort, delay, risk, harm, deception, confrontation, withdrawal, disclosure, repair, commitment, evidence, intuition, planning, immediacy, dignity, resource_cost, uncertainty, social_exposure, reversibility, norm_violation, target_benefit, intensity.

### 4.2 Candidates (`knowledge.py`)

For each template:
1. Check `requires_flags` ⊆ flags; `forbids_flags`; capabilities; the agent's cooldown; and `severity ≥ 3` only if `scene.allow_extreme`.
2. Expand targets by scope (others = visible, reachable actors with `target_tags`; objects = objects), then by the optional parameter grid (1..16 values of `intensity`, `gain` or `resource_cost`).
3. De-duplicate on a semantic key.

A `noop@self` withdraw candidate is always added. Candidates are sorted by id. At most 256.

The living packs add `exec_ready:<id>` and `ready_for:<id>` tags, so **only actions the world can actually execute are candidates**.

### 4.3 Score (`engine.decide`, `utility.py`)

For each candidate:
1. `state` = the agent's 96 features, with relation and memory filled in for that candidate's *target*. The optional `belief_projections` can blend beliefs into relation/context.
2. Utility terms:
   - Per group, `Σ s ⊙ (MATRIX @ a)`. `MATRIX[96×32]` comes from the readable `LINKS` table, e.g. `emotions.anger → confrontation .9, dignity .4`; `context.enforcement → norm_violation −1.6, harm −.6`; `needs.resources → gain 1.1, resource_cost −.7`. Scaled by group strength: traits/values .7, cognition .35, motives .45, instincts .4, memory .7, others 1.
   - `base = BASE @ a`: gain .25, info .15, effort −.35, delay −.2, risk −.5, harm −.65, deception −.2, resource_cost −.25.
   - `interaction`: six hand-written nonlinear terms, e.g. `+.45·anger·(1−self_control)·confrontation` and `−.6·fear·(1−exit_access)·risk`.
   - `inertia = .2·(1−flexibility)·exp(−dt/.1)` if the action is in the same family as the last one.
   - `learned_residual = residual_weight(.35, max .5) × PersonaResidual(state, action)` in [−1,1].

   The residual is a 2,737-parameter attention scorer:
   - 12 group projections to 16 dims, then LayerNorm.
   - The action goes through a projection to 16 dims, LayerNorm, and a query (rank 8).
   - The query attends over the 12 group tokens via keys/values.
   - Output: `score = q·attended/√8 + option_bias(a)`, then `tanh`.

   It was trained on a synthetic teacher (`residual_teacher`), not on human data. The game's `PersonaResidual.gd` is **byte-identical** to the archive's Godot port, and `model/persona_residual.json` has the same SHA-256 (`19863076…`).
3. `logit = Σ terms`.
4. `temperature = .85 + .4·adaptability + .15·ambiguity`.

### 4.4 Sampling and how extreme actions become possible (`selection.py`)

**Two-level sampling (`hierarchical`):**
- Families are `acquire`, `cooperate`, `affiliate`, `explore`, `conflict`, `withdraw`, …
- A family's score is the **max** of its members' logits, so cloning weak variants cannot inflate a family.
- `p(family) = softmax(family scores / T)`, then `p(candidate) = p(family) · softmax within the family`.

**Severe-action cap:**
- `rate/h = .01 + 1.49 · max(reactive, instrumental) · opportunity · (1 − .5·enforcement)`, where
  - `reactive = anger · (1 − self_control·(1−.5·fatigue)) · (.35 + .65·impulsivity)`
  - `instrumental = .45 · defend_boundary · stakes · risk_tolerance`
- `cap = 1 − exp(−rate · exposure_hours)`, where exposure = simulation hours since the last committed decision (1/60 h for the first one). It is never based on how many times the function was called.
- If the raw probability of all `severity ≥ 3` candidates exceeds `cap`, those candidates are scaled down to `cap` and the rest are renormalised. A non-severe alternative must exist; `noop` guarantees it.
- So an extreme act needs: `allow_extreme` in the area, a severity-3 template that is executable, its softmax mass, **and** the time budget.

Worked numbers:
- **Calm NPC:** anger at baseline .02, `stakes ≈ .4`, `opportunity .6`, `enforcement .5`. Rate ≈ 0.028/h, so the cap over 2 h is about 5.5%. In the demo, A's first decision gave `damage@machine_local` p = 0.00049, about the cap at 1/60 h of exposure (1 − e^(−0.029/60)).
- **Furious, impulsive NPC:** anger .8, self_control .3, impulsivity .8, opportunity .9, enforcement .1. Rate ≈ 0.65/h, so the cap over 2 h is about 73%.

Because anger halves every 1.5 h, these windows close quickly; flashes of passion emerge without any scripting.

**Pick:** `draw = replay_draw(seed, agent_id, decision_counter)`, then `choose_index = searchsorted(cumsum(p), draw, 'right')`.

**Output:** `{choice, command{template_id, target, parameters, event_id}, probabilities, family_probabilities, severe_probability, severe_raw_probability, severe_probability_cap, exposure_hours, draw, temperature, attitude, chosen_score_terms, candidate_scores}`.

### 4.5 Affect, memory, expression

- **`advance(now)`:** each emotion moves toward its baseline with `half_life / (1 + .5·reappraisal)`.
  - Baselines: anger .02, fear .03, sadness .04, joy .18, hope .3, arousal .1.
  - Half-lives (h): anger 1.5, fear .8, sadness 6, joy 3, shame 4, guilt 6, disgust 2, surprise .1, hope 8, arousal .5.
- **`appraise(event)`:**
  - `reactivity = .5 + .5·emotional_reactivity`; `coping = .3 + .7·self_control·(1 − .6·fatigue)`.
  - `anger = cf · reactivity · (.42·block·intent + .48·unfair·(.3+fairness)) · (1 − .35·coping)`.
  - `fear = cf · reactivity · threat · (.45 + .55·(1 − exit_access))`.
  - Also updates shame, joy, sadness, hope, disgust, surprise and arousal.
  - Goals: `avoid_loss += .12·threat`, `defend_boundary += .12·unfair`, …
  - Relation to the source: `trust += cf·(.2·help − .22·unfair·intent)`, `resentment += .4·anger`, `familiarity += .04`, …
  - Episodic memory: at most 64 entries; the least salient non-critical entry is evicted first.
- **`memory_features(target)`:** sums `salience · confidence · 2^(−age/72h)` into positive, negative and tag buckets, applies `1 − e^(−x)`, and sets `recency = max e^(−age/6)`.
- **`expression()`** gives a separate display channel: `tone_id ∈ {restrained, sharp, guarded, warm, neutral}`, plus warmth, openness, tension, masking and display_anger. Cooperating does not imply liking. This maps directly onto portrait expressions and dialogue tone.

### 4.6 What the game's current port does differently (`mind.gd`)

The game encodes 96 dims correctly and reuses the residual. It differs in these ways:

1. **Utility:** each call site writes a hand-made `utility` per candidate instead of using `utility_terms` (the LINKS matrix, base and interactions).
2. **Residual weight and temperature:** residual weight 0.8 (GameJev allows at most 0.5) and a flat softmax at **T = 0.35**, instead of the trait-based temperature and two-level sampling.
3. **No severe cap** and no inertia.
4. **Random number:** `RandomNumberGenerator` seeded with a 32-bit `hash()`.
5. **Emotion decay:** `decay()` moves emotions 25% toward baseline per slot, ignoring hours and half-lives.
6. **Memory:** stored as a static group, not computed from episodes.
7. **Relations:** `relate()` adds familiarity +0.05 on every call.

In `world.gd`:
- `_wheel` has hard-coded weights, no cooldown except a patrol counter, no season and no pressure input.
- `_offscreen_life` is scripted by `(day, slot)`.
- `_propagate_rumors` relays along `rel.familiarity` with `p = fam · sociability · conf · .7`, `hops < 3`, `conf ≥ .3`, decay .75 and a one-slot delay. It de-duplicates per (npc, rumor key) for all time, so a rumor type can only happen once. It has no TTL.

These are reasonable approximations, but they are not the GameJev algorithms.

---

## 5. Porting plan for the town game

### 5.1 What to port as-is, simplify or drop

| GameJev piece | Decision | Notes |
|---|---|---|
| `draw`, `weighted_choice`, `replay_draw` | **Port as-is (done, verified)** | `JevRng.gd`. Replaces every `hash()`/`RandomNumberGenerator` in the simulation. |
| Wheel spin maths, `quiet` rule, exogenous/endogenous split, cooldowns, season weights, `pressure_min`/`pressure_bias` | **As-is** | Units become days, slots or weeks. Add a `when` condition and `requires_building`. |
| Pack validation (unknown field = error, effect whitelist) | **As-is in spirit** | `TownPack.validate()`. Wheel effects become a whitelist of town ops. |
| Rumor relay: hops, delay, confidence decay, TTL, min confidence, first-path de-dup per root\|recipient, `visited` | **As-is** | Root = `rumorkey@day` so the same kind of rumor can happen again. Relay probability may be multiplied by link strength. Keep the game's text variants per hop. |
| Norm detection (`detect_probability · norm_strength · (1 − forgiveness·rapport)`, needs a witnessing authority) + sanction (`min(cash, fine)`) | **As-is** | This is the police/维持会 core. Add "authority *hears* the rumor → heat" (an indirect witness). |
| Commitments (escrow, due, grace, missed/cancelled, reputation ±) | **As-is** | This is exactly the live-pawn mechanic (issue #10): first week sell, second week buy back, extension requests, and appointments that require both people at the shop. |
| Persona `decide` (LINKS utility + base + interaction + residual + two-level sampling + severe cap), `appraise`, `advance`, `expression`, `memory_features` | **Port as-is** into `PersonaEngine.gd` | Replace `mind.decide`'s ad-hoc utility; keep the authored `utility` as an optional bias term. Scale the emotion half-lives (e.g. ×4) if a game hour is short. |
| Event queue with priorities | **Simplify** | Phase 1: a fixed per-day and per-slot pipeline (the prototype). Phase 2 (when NPCs walk in real time like Stardew): keep `(due_hour, priority, seq)` and call `advance_to(clock_hours)` from the game clock. Both are deterministic if keys are semantic. |
| Region `trade_links` influence graph, `regional_pressure` | **Simplify** | Replace with named town pressures (`heat`, `unrest`, …) that keep: material threshold, per-source and daily caps, half-life decay, optional delay. |
| Body metabolism (holdings consumption, hunger, fatigue) | **Simplify** | NPC needs come from ledger cash vs. their own daily costs; player survival comes from `LivingCosts`. |
| Objects, tools, machine work/repair | **Optional** | Useful later for workshop buildings (tailor, smith). Not needed for v1. |
| Transactions (deepcopy rollback), revision tickets, view digests, idempotent `request_id` | **Drop or reduce** | Snapshot once per day for autosave. Keep `request_id` only for UI double-click protection. |

### 5.2 Proposed GDScript classes and signatures

```gdscript
# res://scripts/sim/jev_rng.gd           (done)
class_name JevRng
static func draw(seed: int, domain: String, key: Array) -> float
static func weighted_choice(rows: Array, u: float) -> String          # rows [[id, w], ...]
static func replay_draw(seed: int, agent_id: String, counter: int) -> float
static func tri(seed: int, domain: String, key: Array, jitter: float) -> float   # 1 + j·(u1+u2−1)
static func randint(seed: int, domain: String, key: Array, lo: int, hi: int) -> int

# res://scripts/sim/town_pack.gd
class_name TownPack extends RefCounted
var data: Dictionary
var content_hash: String                        # sha256(canon json) -> stored in saves
func load_file(path: String) -> Error
func validate() -> PackedStringArray            # quiet rule, exogenous-reads-endogenous, unknown ops/fields

# res://scripts/sim/cond.gd   (data conditions, no Expression eval)
class_name TownCond
static func eval(c, st: Dictionary, pack: Dictionary) -> bool
# {all:[]}, {any:[]}, {not:{}}, {day_gte:n}, {weekday:n}, {season:n}, {weather:"雨"}, {flag:"x"},
# {stat_gte:["koubei",60]}, {pressure_gte:["heat",.3]}, {building:"police"}, {npc_rel_gte:["chen","trust",.6]}

# res://scripts/sim/pressure_model.gd
class_name PressureModel
static func step_day(st: Dictionary, pack: Dictionary) -> void        # exo: mean-revert + noise(draw "pressure:k",[day]); endo: half-life
static func add_influence(st: Dictionary, pack: Dictionary, key: String, amount: float, source: String) -> float  # caps + min magnitude

# res://scripts/sim/world_wheel.gd
class_name WorldWheel
static func spin(st: Dictionary, pack: Dictionary, wheel: Dictionary, index: int) -> Dictionary  # {choice, draw, probs}
static func apply(st: Dictionary, pack: Dictionary, outcome: Dictionary, src: String) -> Array   # receipts

# res://scripts/sim/living_costs.gd
class_name LivingCosts
static func bills_for_day(st: Dictionary, pack: Dictionary) -> Array  # [{id,label,amount,payee,due}]

# res://scripts/sim/npc_life.gd
class_name NpcLife
static func location(st, pack, npc_id: String, slot: int) -> String   # weather > weekday > default variants
static func present(st, pack, npc_id: String) -> bool
static func plan_pawnshop_visits(st, pack, persona: PersonaEngine) -> Array  # [{who,intent,slot,item,tone}]

# res://scripts/sim/rumor_net.gd
class_name RumorNet
static func plant(st, pack, key: String, origin: String, conf := 1.0) -> String   # returns root id
static func deliver_due(st, pack) -> Array
static func tell_player(st, pack, npc_id: String, persona: PersonaEngine) -> Dictionary

# res://scripts/sim/institutions.gd
class_name Institutions
static func on_act(st, pack, act: String, building: String, actor: String) -> Array   # norms: witness/hear -> heat
static func perform(st, pack, inst: String, act: String, target: String) -> Dictionary # raid/inspect/levy

# res://scripts/sim/unlocks.gd
class_name Unlocks
static func check(st, pack) -> Array            # newly opened buildings (+ news)

# res://scripts/persona/persona_engine.gd   (replaces mind.decide internals; keeps PersonaResidual.gd)
class_name PersonaEngine
func utility_terms(state: PackedFloat64Array, action: PackedFloat64Array) -> Dictionary   # LINKS, BASE, interactions
func decide(agent: Dictionary, cands: Array, ctx: Dictionary, now_hours: float, key: Array) -> Dictionary
static func extreme_rate_per_hour(agent: Dictionary, ctx: Dictionary) -> float
static func hierarchical(cands: Array, logits: Array, temp: float, cap: float) -> Array
static func appraise(agent: Dictionary, obs: Dictionary, ctx: Dictionary) -> void
static func advance(agent: Dictionary, now_hours: float) -> void
static func expression(agent: Dictionary, target: String, ctx: Dictionary) -> Dictionary  # tone_id → portrait/line set

# res://scripts/sim/town_sim.gd   (orchestrator; prototype = town_sim.gd in scratchpad)
class_name TownSim extends RefCounted
signal news(entry)
func new_game(pack: TownPack, seed: int) -> void
func advance_day() -> Dictionary       # pressures → exo wheels → endo wheels → building decks → feeds → unlocks → bills → visit plan
func advance_slot() -> Array           # deliver rumors → schedule moves → due visits/commitments → NPC wakes
func player_act(act: String, args: Dictionary) -> Dictionary   # same norm/influence rules as NPCs
func player_feed() -> Array            # only delivered / witnessed info (no wheel log, no hidden pressure)
func dev_log() -> Array                # omniscient log incl. wheel probabilities (developer panel only)
func save() -> Dictionary              # {pack_hash, seed, state}; reject other pack hash on load
func load(d: Dictionary) -> Error
```

All state lives in one JSON-safe `st` Dictionary, so saving is just writing it out. Re-cast ints after load.

Recommended per-NPC state:

```
npc_state[id] = {cash, location, activity, busy_commitment, persona, rel{}, memories[], known{},
                 decision_counter, last_decision_hours, cooldowns{}}
```

### 5.3 The "town pack" JSON format

A complete draft is in `scratchpad/understand/godot_draw_test/town_pack.json` and runs in the prototype. Its sections:

```jsonc
{
  "version": "dehoudang-townpack/1",
  "time": {"slots": ["清晨","上午","中午","下午","傍晚","夜"], "slot_hours": [6,9,12,15,18,21],
           "season_days": 28, "start_weekday": 0},

  // survival-pressure variables: exogenous = world's own random walk; endogenous = only via influence
  "pressures": {
    "rice_price": {"kind":"exogenous","base":1.0,"min":0.8,"max":1.8,"revert":0.12,"noise":0.04},
    "med_price":  {"kind":"exogenous","base":1.0,"min":0.8,"max":2.0,"revert":0.10,"noise":0.05},
    "rent_index": {"kind":"exogenous","base":1.0,"min":1.0,"max":1.6,"revert":0.0,"noise":0.0},
    "heat":       {"kind":"endogenous","base":0.0,"min":0,"max":1,"half_life_days":5},   // police suspicion of the shop
    "unrest":     {"kind":"endogenous","base":0.0,"min":0,"max":1,"half_life_days":7}
  },
  "influence": {"daily_cap": {"heat":0.35,"unrest":0.25},
                "feeds": [{"from":"rice_price","above":1.25,"to":"unrest","gain":0.10}]},

  // daily VARIABLE living costs (owner request): base × pressure × season × triangular jitter
  "living_costs": [
    {"id":"food","label":"伙食","period":"daily","base":4,"scale":"rice_price","jitter":0.15,"payee":"米行柜"},
    {"id":"fuel","label":"柴炭","period":"daily","base":1,"season_mult":[1.0,0.3,0.8,2.0],"jitter":0.3,"payee":"柴炭铺"},
    {"id":"rent","label":"铺租","period":"weekly","weekday":6,"base":30,"scale":"rent_index","payee":"保长"},
    {"id":"mother_med","label":"娘的药","period":"daily","base":3,"scale":"med_price","jitter":0.2,
     "payee":"济生堂柜","when":{"flag":"mother_sick"}}
  ],

  // buildings with unlock triggers (data conditions) and an opening news line
  "buildings": {
    "pawnshop": {"name":"德厚当","unlocked":true,"tags":["shop","player"]},
    "pharmacy": {"name":"济生堂","unlock":{"any":[{"day_gte":3},{"flag":"met_chen"}]},"news":"济生堂重新开了门…"},
    "police":   {"name":"警察所","unlock":{"any":[{"day_gte":6},{"pressure_gte":["unrest",0.2]}]},"tags":["authority"]},
    "mansion":  {"name":"孙府","unlock":{"stat_gte":["koubei",60]}}
  },

  // NPCs: schedule per slot with weather/weekday variants, social links (rumor graph), visit propensities
  "npcs": {
    "zhouma": {"home":"teahouse","roles":[],"cash":20,"links":{"xiaoding":0.7,"linsao":0.9,"laowang":0.5},
               "schedule":{"default":["teahouse","ricehall","teahouse","teahouse","pawnshop","teahouse"]},
               "visit":{"base":0.35,"need_scale":80,"intents":{"gossip":2.0,"buy":0.5}}},
    "officer_qian": {"roles":["authority"],"requires_building":"police","links":{"laowang":0.6},
               "schedule":{"default":[...],"weekday:6":["police","pawnshop","teahouse","police","police","police"]},
               "visit":{"base":0.02,"need_scale":100,"intents":{"inspect":1.0,"buy":0.2},"heat_gain":1.5}}
  },
  "strangers": {"per_day":{"base":1.0,"unrest_gain":2.0,"market_day_bonus":1.0,"max":4},
                "archetypes":[{"id":"refugee","weight":1.0,"unrest_bias":3.0,"intents":{"pawn":3,"sell":1}},
                              {"id":"fence","weight":0.4,"unrest_bias":2.0,"intents":{"sell_stolen":1},"norm":"fence_goods"},
                              {"id":"collector","weight":0.3,"requires_building":"dock","intents":{"buy":2}}]},

  // town-wide wheels (GameJev semantics, day units)
  "wheels": [
    {"id":"climate","period":"day","mode":"exogenous","outcomes":[
      {"id":"quiet","weight":5,"cooldown_days":0,"effects":[]},
      {"id":"雨","weight":2,"cooldown_days":1,"season_weights":[2,1.5,1,0.5],"effects":[{"op":"weather","value":"雨"}]},
      {"id":"大风","weight":0.3,"cooldown_days":6,"effects":[{"op":"weather","value":"大风"},
                                                            {"op":"bill","label":"修瓦","min":5,"max":15,"payee":"泥瓦匠"}]}]},
    {"id":"civic","period":"day","mode":"endogenous","outcomes":[
      {"id":"quiet","weight":6,"cooldown_days":0,"effects":[]},
      {"id":"raid_pawnshop","weight":0.4,"cooldown_days":6,"requires_building":"police",
       "pressure":{"heat":{"bias":6.0,"min":0.3}},
       "effects":[{"op":"institution","id":"police","act":"raid","target":"pawnshop"},
                  {"op":"pressure_add","key":"heat","value":-0.2}]}]}
  ],
  // per-building event decks (only spin while the building is unlocked)
  "building_decks": {"ricehall": {"period":"day","outcomes":[
      {"id":"quiet","weight":6,"cooldown_days":0,"effects":[]},
      {"id":"rice_theft","weight":0.5,"cooldown_days":8,"effects":[
         {"op":"rumor","key":"rice_stolen","origin":"laowang"},
         {"op":"spawn_visit","who":"stranger:fence","intent":"sell_stolen","item":"rice","delay_days":1}]}]}},

  "communication": {"delay_slots":1,"confidence_decay":0.7,"relay_probability":0.45,"max_hops":3,"ttl_slots":18,"min_confidence":0.2},
  "rumors": {"rice_stolen": ["米行丢了两袋米","有人偷了米行的米去当","德厚当收贼赃"]},   // text variant per hop
  "norms": [{"id":"fence_goods","act":"accept_stolen","building":"pawnshop","detect_probability":0.35,
             "forgiveness":0.4,"heat":0.25,"rumor":"pawnshop_fenced"}],
  "institutions": {"police":{"building":"police","acts":{
      "raid":{"fine_min":10,"fine_max":40,"confiscate":"stolen","news":"警察所的人进了德厚当，翻了半个时辰。"},
      "inspect":{"news":"钱巡官在柜台前转了一圈，什么也没说。"}}}}
}
```

**Effect op whitelist (v1):** `weather, pressure_add, news, flag_today, flag_set, bill, rumor, spawn_visit, npc_feel, institution, unlock, item_drop`.

Use `item_drop` to put an heirloom or rare item into a visit later in the game (issue #13). It should use `when: {day_gte: …}`.

### 5.4 What the generator produces each day, with the exact random keys

| Output | How | Random key(s) |
|---|---|---|
| Exogenous pressure walk | `x += revert·(base−x) + noise·(2u−1)`, then clamp | `pressure:<k>`, `[day]` |
| Endogenous pressure | `x ← base + (x−base)·2^(−1/half_life)`; plus `add_influence` with per-key daily cap | none |
| Wheel outcome | GameJev spin (section 2.2), `cooldown_days`, `requires_building`, `when`, `pressure{k:{bias,min}}`, `season_weights` | `wheel:<id>`, `[day]` (or `[day*6+slot]` for per-slot wheels) |
| Building events | Same spin, only for unlocked buildings | `wheel:deck:<building>`, `[day]` |
| Variable living costs | `round(base · scale_pressure · season_mult · (1 + j·(u1+u2−1)))`; weekly items on their weekday; `when` gates | `cost:<id>`, `[day,0]` and `[day,1]` |
| One-off bills from events | `min + ⌊u·(max−min+1)⌋` | `bill:<wheel/outcome>`, `[day]` |
| Named NPC visits | `p = base + .25·need + .08·unknown_rumors + heat_gain·heat + .4·has_ticket + market/weather modifiers`; visit if `u < p`. Intent chosen from feasible intents (redeem needs a ticket, gossip needs an unknown rumor, pawn is weighted by need, buy by 1−need, inspect by heat). Use the PersonaEngine instead of a plain weighted pick in the final game. | `visit`, `[day,npc]`; `intent`, `[day,npc]`; slot: `visit_slot`, `[day,npc]` (×3 weight for slots where the schedule already says pawnshop) |
| Strangers | `count = min(max, ⌊base + unrest_gain·unrest + market_bonus + u⌋)`; archetype weight `× (1 + unrest_bias·unrest)` | `stranger_count`, `[day]`; `stranger`, `[day,k]`; `stranger_intent`, `[day,k]`; `stranger_slot`, `[day,k]` |
| Rumors | GameJev relay (section 3.7) over slots | `relay`, `[root, from, to, hop]` |
| Police/维持会 | Witness detection; or the authority *hears* the rumor → `heat += rule.heat · conf`; `raid` outcome biased by heat; fine `min(cash, fine)` | `norm_detection`, `[event_id, rule]`; `raid_fine`, `[day]` |
| Building unlocks | Conditions checked after the wheels each morning; emits news | none |
| NPC decisions | `PersonaEngine.decide` | `replay_draw(seed, npc, counter)` or `draw('persona:'+npc, [semantic_key])` |

For NPC decisions, prefer the semantic key. In a branching story it is more stable than the decision counter: an NPC who decided once more on one branch would otherwise shift all their later draws.

### 5.5 Rules that keep GDScript deterministic

1. No `randf()`, `randi()` or shared `RandomNumberGenerator` anywhere in the simulation. Only `JevRng.draw(seed, domain, semantic_key)`. Visual-only randomness (dust particles) may use anything.
2. Keys contain only ints and strings; `int()` everything after JSON load. `canon()` already treats whole-number floats as ints.
3. Iterate dictionaries in **sorted key order** wherever the order changes state (GameJev sorts everywhere).
4. Fixed processing order:
   - Morning: pressures → exogenous wheels → endogenous wheels → building decks → feeds → unlocks → bills → visit plan.
   - Each slot: deliver due messages → schedule moves → due visits/commitments → NPC decisions.
5. Player actions may only affect endogenous pressures, flags, relations, ledger and commitments. Exogenous draws therefore stay identical; test this like GameJev does.
6. Saves store `{pack_hash, seed, state}`. Refuse a different pack hash, or migrate explicitly.
7. Keep a developer-only log (wheel probabilities, draws, pressures) separate from `player_feed` (only what was seen or heard, with source, number of hands and confidence).

### 5.6 Prototype results (Godot 4.7 headless, `test_town.gd`)

21 days, seed 1938, player accepts every offer:

```
D01 wd1 雾 rice=1.14 heat=0.00 | bills=6 伙食5,柴炭1 | ev=climate/雾, market/no_boat, civic/patrol | visits=xiaoding:pawn@2, zhouma:buy@4, stranger:refugee#0:pawn@4
D03 ... unlock=[pharmacy]
D05 ... ev=deck:ricehall/rice_theft            (spawns a fence visit for the next day)
D06 wd6 雨 | bills=35 伙食4,柴炭1,铺租30 | visits=…, stranger:fence:sell_stolen@2 | unlock=[police] | heard: zhouma 说：德厚当收了来路不明的东西（1 手，可信 0.80）
D07 heat=0.09   (rumor pawnshop_fenced relayed along links (…→ laowang → officer_qian) on D06; authority heard it → heat)
D08 visits=officer_qian:inspect@2 … | unlock=[dock]
D14 ev=market/rice_boat, civic/levy   rice 0.82  → food bill drops to 3
D20 bills=38 … 铺租33  (rent_index raised by the levy)
```

| Check | Result |
|---|---|
| Same seed run twice | identical |
| Save at day 10 (JSON round-trip) and resume to day 21 | identical to the continuous run |
| Seed 7 | different run |
| Player refuses stolen goods | climate and market outcomes, weather and rice price identical every day; only `heat` (endogenous) changes |

Tuning needed: `unrest` never rose because rice never passed 1.25, and no raid fired because heat stayed below its 0.3 minimum. Lower the feed threshold or the raid's `pressure.min` to see those paths.

### 5.7 Suggested order of work

1. Add `JevRng.gd` and switch `world.gd::_rng`, `_propagate_rumors` and `mind.decide` to it. Re-baseline the 63 tests, because their random outcomes will change.
2. Add `TownPack`, `TownCond`, `PressureModel`, `WorldWheel` and `LivingCosts`, using the prototype as the reference. Replace the hard-coded `_wheel` and the fixed rent with pack data.
3. Add `NpcLife` + `RumorNet`, with schedules from pack data. This replaces `cast.json sched` and `_offscreen_life`'s per-day scripts, except for authored story beats, which stay as flagged events in the director.
4. Add `Institutions` + `Unlocks` (police station, etc.) and connect commitments to live pawns (escrow / due / grace / extension).
5. Port `PersonaEngine` (LINKS matrix, two-level sampling, severe cap, appraise, advance, expression) and use it for visit intents, bargaining moves and tell/keep rumor decisions. Feed `expression().tone_id` to the portrait dialogue box.
6. Tests to add: determinism, save/resume equality, exogenous independence, every wheel has quiet, cooldowns respected, probabilities sum to 1, bills vary within bounds, unlock conditions, rumor TTL/hops/de-dup.
