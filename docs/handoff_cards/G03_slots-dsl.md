# G03 `slots-dsl` · 放格子与掷铜钱、效果/条件 DSL、属性与三项名声、条子、档案簿

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G03 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] G03: …` issue。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 3**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 你的全部类、指令、查询、效果/条件 op 都已按合同登记成桩；`all/any/not` 与 `CardCoins.toss` 已能用；op 形状在 `scripts/cards/api/dsl_shapes.gd`（冻结） | W0（已完成） |
| G01 | `CardPiles`（spawn/move/resolve/keep）、`CardFirsts`、`deal_composed` 钩子（W0 已能用） | W1（G01 先合） |
| G04 | 钱（`money`/`pay` op、`money_gte` 条件、`CardCurrency.money`）——W1 还是桩 | W1（G04 在你之后合） |
| G06 | `arrest` op（风声到顶、条子要命档）——W1 还是桩 | W1 |

- **你所在的波次**：W1；合并顺序第二（G01 → **G03** → G04/G05 → …）。依赖钱的地方对着桩和测试替身先做（见“测试”里的 W1 测试替身）。
- **W2**：真引擎整局里条子、格子、档案簿的集成；K07/K08/K09 的真数据合进来后跑 strict 校验与 K13 的措辞修正。

## 分支

`cards/G03-slots-dsl`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase` 跟上。

## 目标

做出卡牌版的“规则内核”：DSL 里归 G03 的全部效果 op 与条件 op（§5）的执行；放格子与掷铜钱（看得见的随机）；选项与选项里的检定；口碑、风声（五档文字）、本心（永不显示）、属性；留着的牌进格子的加成与风险；条子（每周一张、七天、拖一拖、六种办法、四档吃亏阶梯）；档案簿（碎片、永久缺口、一年后、补齐解锁）。全部确定、可存读、不泄露隐藏数值。

## 必读

1. 合同 §0、§2.2、§3.2 G03、§4.3–§4.4（公共字段、Slot、Check、Choice、效果钩子名）、§4.6（`slots.json` `meters.json` `demand_rules.json`）、§4.7.3 事件、§4.7.4 命运、§4.7.6 **条子**、§4.7.8 消息（`on_inform`）、§4.7.9 留着的牌（`slot_bonus` `risk` `consumed_on_use`）、§4.7.10 人脉、§4.7.14 牢房、§4.7.19 档案簿、§5 全章（**总规则、来源路径、每个 op 的语义**）、§6（CardState 的 `rules` 命名空间、随机写法、域表）、§7.3（修正项表与钩子表里归 G03 的行）、§7.4（指令/查询表、§7.4.3 来意与面板）、§7.5（SlotView、DossierView、黑名单）、§7.9 G03 段、§7.10.10（你发的 first）、§12、§13–§14、**§7.5 的 1.3 增补（CardView 的 `demand`）**。
2. `docs/cards/DESIGN_cards.md` §三.3（条子）、§三.4（放格子、掷铜钱）、§三.5（留着的牌）、§三.9（口碑、风声、本心）、§三.10（人脉）、§三.11（档案簿）、§九.3（金色牌没理他 → 缺口）、文末“实现时的理解”。
3. W0 代码：`scripts/cards/rules/*.gd`（你的起点）、`scripts/cards/api/dsl_shapes.gd`（形状，**登记时传 `CardDslShapes.shape(op)` / `shape(op, true)`，不另写**）、`scripts/cards/core/card_ops.gd`（`run` 怎么给来源路径）、`card_conds.gd`、`card_piles.gd`、`card_composer.gd`（`deal_composed` 在哪触发）、`scripts/cards/loop/view_model.gd`（`card_view_part`、`view_section` 怎么合并）。
4. 只读参考：`scripts/core/protection.gd` 与 `data/town/protection.json`（保护费的升级阶梯就是条子的前身——**只看做法，不改、不实例化、不拷文字**）、`scripts/sim/town_cond.gd`（条件的形状）、`scripts/core/cond.gd`（条件词汇对照，§5.3 末）。
5. 数据：`data/cards/rules/{slots,meters,demand_rules}.json`（你的）、`data/cards/_examples/{demand,dossier,common,era}/**`（单测用）。

## 要做的事

### A. 效果 op（`effects_core.gd`，§5.2 里归 G03 的全部）
- [ ] `rep` `heat`（`delta` 或 `tier`；`tier:+1` 升到上一档门槛，已在最高档不动）· `conscience` · `attr {who, attr, delta, days?}`（有 `days` 记进 `rules.attr_mods`，到期在 `day_start` 20 还原）· `flag` `flag_clear` `counter` · `story {node, outcome}`（同时设旗标 `story.<node>`）· `dossier` `dossier_gap` · `notice {key, args?}`（只 `ctx.emit(&"notice", [key, args])`；告示栏由 G02 收）· `if {cond, then, else?}` · `coin_check {coins, need, then, else?}` · `person_state {person, state, days?}` · `contact_gain` `contact_lose` · `demand_tier {delta}` · `kept_risk {tags_any}`。
- [ ] **来源路径**（§5.1）：嵌套的 `then`/`else`/`on_success`/`on_fail` 往后接 `/then/<i>` 这类再交给 `ctx.run`；`coin_check` 用来源路径进随机键（`c.coin [abs_day, <来源路径>, attempt, i]`），同一张牌同一天两个 `coin_check` 掷出不同的铜钱。
- [ ] `heat` 到 `meters.json.heat.arrest_at` → 立即经 `ctx.run([{"op": "arrest", "reason": …}], …)` 执行 G06 的 `arrest`（不直接调 G06 的函数）。
- [ ] `contact_gain`：发对应的人脉牌（`ct.<person>`）进 `contacts` 区；满了（`deal.json.caps.contacts` + 修正项 `cap`）→ 新的先进 `pending`，`CardDayLoop.request_panel(ctx, &"contacts_full", {"new_uid": uid})`，第一次记 first `contacts_full`；`contact.release {uid}` 让出一个后新的进来；`contact.release {uid: new_uid}` = 新来的不留（关面板、打烊时没选都走这个，§7.4.7）。
- [ ] 每个 op：正例单测 + 形状反例（`ctx.ops.validate()` 非空）。

### B. 条件 op（`conds_core.gd`，§5.3 里归 G03 的全部）
- [ ] `flag flag_eq counter_gte story rep_tier_gte rep_tier_lte heat_tier_gte heat_tier_lte conscience_gte conscience_lte attr_gte has_contact has_kept person_state dossier_has dossier_page_complete demand_open`；`all/any/not` 已有。`conscience_*` 只在引擎里用。

### C. 放格子与掷铜钱（`slots.gd`、`coins.gd`）
- [ ] **放了什么、选了哪个选项、已读、掷了几次都记在你自己的 `rules` 命名空间里**（例：`rules.cards[uid] = {placed, choice, read}`、`rules.attempts[uid]`、`rules.demand.issued[uid] = {due_abs_day, tier, kind, delays, mode}`）。`core.cards[uid]` 里的 `placed`/`choice` 两个字段是 G01 命名空间的，你不写（合同 §6.1 的例子把它们画在 `core` 里，但命名空间只有主人写——已作为合同缺口报给 Claude，PR 里写明）。
- [ ] `slots_of(uid)`：牌面格子；选了带 `check` 的选项后是那个选项的检定格子；条子按所选办法给格子（`pay` 的 `pay:true` 格子、`haggle` 的格子……）。
- [ ] `can_place(uid, slot, source)` 返回错误码：`accepts` 不收 → `slot_reject`；满了 `max` → `slot_full`；同一人一天只能放一次（`slots.json.person_once_per_day`，人脉和你自己都算）→ `person_busy`；人物 `away/hurt/jailed` 期间 → `person_busy`；钱不够 → `insufficient_money`；不能放的牌、不在手上/不在留着的区 → `unknown_uid`/`not_allowed`。
- [ ] `place` → `{coins}`；`remove` 还回去。**钱什么时候花**（合同没写死，按这个做并写进 PR）：放进格子时只“占着”（同一时刻占着的总数不能超过手上的钱），`slot.roll` 时不论成败一次付掉（经 `ctx.run([{"op":"pay", …, "short":"fail"}])`，原因键 `g03.reason.slot_money`）；条子 `pay:true` 格子里的钱在 `demand.submit` 时交。
- [ ] 铜钱数（§4.4.2）：人 = 那项属性点（`CardMeters.attr`，含临时修正、受伤）+ 修正项 `coins {uid, slot_id, source}`；钱 = 数目 ÷ `money_per_coin`（格子上的或 `slots.json` 默认，向下取整）；物品、消息 = `item_coins` / `news_coins`；留着的牌 = `CardKeptRules.bonus()`（`coins` 加铜钱、`heads` 直接算正面、`auto_pass` 直接过）；上限 `max_coins`。
- [ ] `preview(uid)` → `{coins, auto_heads, need, auto_pass, ready}`（`ready` = 必填格子都放了）；查询 `slots {uid}` → `{slots:[SlotView], coins, auto_heads, need, auto_pass, ready}`，SlotView 里格子的性质叫 `wants`（不叫 `tags`）。
- [ ] `roll(uid)`：`auto_pass` 直接成、不掷；否则 `CardCoins.toss(ctx, uid, attempt, n)`（`attempt` 来自 `rules.attempts[uid]`，每掷一次 +1）；成功 = 掷出的正面 + 直接算数的正面 ≥ `need`；发 `coins_tossed(uid, faces, need, success)`；执行 `on_success`/`on_fail`；用掉 `consumed_on_use` 的留牌、人记“今天用过”（`rules.persons[p].used_abs_day`）；牌 `CardPiles.resolve`（`extra.almanac`：放过人脉的带 `meet`，选项的 `almanac` 字段原样带上）。返回 `{faces, heads, need, success}`。
- [ ] **新公开函数**（列进 PR）：`static func mark_person_used(ctx, person: String) -> void`——G05 的香案上放了人脉时要“当天算用过”（§9.1），它没有别的路能写你的 `rules` 命名空间。

### D. 选项（`choices.gd`）
- [ ] `options(uid)` → `[{id, enabled, reason_key, has_check}]`：`conditions` 不满足或 `cost.money` 付不起 → 变灰（原因键 `g03.reason.money` 等）。人物牌的 `choices`（柜台上的额外按钮，G04 显示）、事件/命运/生活/街头/大赌的选项、条子的办法（数据里不写，按 `kind` 和 `resolve` 生成保留 id：`pay` `haggle` `substitute` `fabricate` `send_person` `inform`）都从这里出。
- [ ] `choose(uid, choice)`（指令 `card.choose`）：先付 `cost.money`；有 `check` → 返回 `{needs_slots: true}`，等放格子、`slot.roll`；没有 → 执行 `effects`、`CardPiles.resolve(…, {"almanac": choice.almanac})`；条子的办法 → 记下所选办法，等 `demand.submit`。
- [ ] 指令 `card.read {uid}`（消息、当票）：第一次读执行 `on_read`（只执行一次，已读记在 `rules` 命名空间里）；牌留在手上（能留的可以 `card.keep`，交给条子用）。读完以后的去留合同没写——保守做法：留在手上，标 `# TODO(design)`、写进 PR。

### E. 属性与名声（`meters.gd`）
- [ ] `rules.meters {rep, heat, conscience}` 与 `rules.attrs`：`stage_start` 20 填首局初值（`meters.json` 的 `start`、`self.ruhua` 的 `attrs`）；跨关保留。
- [ ] `value tier add bump_tier attr add_attr`；档位按 `meters.json` 的 `tiers`；**只有口碑、风声发 `tier_changed(meter, old, new)`**，第一次换档各记 first `tier_rep` / `tier_heat`；本心永不进视图、事件。
- [ ] 人脉（§4.7.10）：`passives`/`downsides` 按钩子（`day_start` `deal` `demand_issue` `settle`）执行；`leave_when` 满足就离开；常驻 `mods`（同家当 `while_mortgaged` 的格式）里 `shelf_cap`/`kept_cap` → 修正项 `cap`、`deal_count` → `deal_count`；`no_intake_cat`、`pool_weight` 要提供 `intake_blocked`/`pool_pct`，合同 §7.3 没把这两个给 G03——先不支持，开 `[api] G03: 人脉常驻修正 no_intake_cat/pool_weight` 等 Claude 定。
- [ ] `settle` 40：风声每天回落 `decay_per_day`、到顶被抓（经 `arrest` op）。
- [ ] 修正项提供：`patience_pct {uid}`（口碑高客人更有耐心，数写进 `meters.json`）、`coins`（临时属性、受伤）、`appraise_pct {cat, item_id}`（人脉被动，例：陈文庭让书画、药材的线索更清楚）、`deal_count`（人脉被动）、`cap`（人脉被动，如有）。
- [ ] `view_section`：`rep_tier` `heat_tier`（只给档位整数，界面用 `g03.tier.rep.<n>` / `g03.tier.heat.<n>` 的文字）、`self`（`{uid, def, attrs, used_today}`）、`dossier_new`；`card_view_part`：格子、选项、条子的 `days_left`、人物的 `used_today` `away_days`。

### F. 留着的牌（`kept_rules.gd`）
- [ ] `bonus(kept_uid, slot)`：按 `slot_bonus[].slot_tags_any` 与格子 `tags` 匹配 → `{coins, heads, auto_pass}`。
- [ ] `run_risk(tags_any, source)`：手上（留着的区）带这些标签的牌依次执行它们的 `risk`（例：箱子被翻出来 → `arrest`）。

### G. 条子（`demands.gd`，§4.7.6、`demand_rules.json`）
- [ ] `issue()`（`day_start` 30，`issue_weekday` 那天）：类 `c.demand.kind [stage, week]`、张 `c.demand.pick [stage, week, kind]`、数目浮动 `c.demand.amt [stage, week]`；档 = `tier_by_stage[stage]` + `rules.demand.tier_bias`（人脉被动的 `demand_tier`）+ 风声档按 `tier_heat_step` 加，夹到 `max_tier`；进 `demands` 区；第一次记 first `demand`、`demand_delay`（见“新手指引”）；第一张“要消息”的条子记 `demand_inform`、`demand_fabricate`。脚本日照发（§7.4.6），街头时照发【主创已确认 10-13】。
- [ ] `days_left(uid)`、`delay(uid)`（拖一拖：+`delay.days` 天、升 `tier_up` 档、最多 `max` 次）、`submit(uid)`（按已选办法结算：交钱/交货/顶替/讲价成了降档再交/编一个掷胆量/派人/交消息）。
- [ ] 要人：放你自己或一个人脉 → 他 `away_days` 天不能用（`person_state away`）；回来那天发系统牌 `ev.any.demand_return`（K07 定义）进手牌，当场按他的属性掷（看得见的铜钱）；不成 → `person_state gone`。第一次发它记 first `demand_people_return`。
- [ ] 要消息：交一张留着的消息牌 → 执行那张消息的 `on_inform`（伤到那个人），牌 `card_left(uid, &"informed")`；“编一个” → 掷胆量，不成按 `resolve.fabricate.on_fail`。
- [ ] `on_settle`（`settle` 30）：剩几天减一；到期没办成 → 按档执行 `demand_rules.json.fail.t<档>`（或牌自己的 `on_fail`），第一次记 first `demand_fail`；结果用 `notice` 事件报（G02 收进日结报告）。

### H. 档案簿（`dossier.gd`，§4.7.19、§7.5 DossierView）
- [ ] `rules.dossier[person] = {have, gaps, new}`；`add(frag)`：已是缺口的不能补、重复补无效；`gap(frag)`：永久；发 `dossier_changed(person, frag, &"added"/&"gap")`；第一块碎片记 first `dossier`、第一次缺口记 `dossier_gap`。
- [ ] 页补齐 → 执行页的 `on_complete`（如 `contact_gain`）。
- [ ] `year_after()`（`year_jump` 30）：`kind: year_after` 的碎片，玩家拿到了它的 `year_after_of` 才补；第一块记 first `year_after`。
- [ ] `view(person)` → DossierView：只列见过的人；**没拿到的碎片不出现**，缺口出现（`state:"gap"`）；不泄露碎片内容以外的东西。查询 `dossier {person?}`。

- [ ] **查询结果的形状和 Mock 一样**：界面任务是对着 `MockCardEngine`（`scripts/cards/mock/mock_scenario.gd` 的 `query()` 与十个夹具）写的，W2 换真引擎时形状必须一致。`slots` → `{slots, coins, auto_heads, need, auto_pass, ready}`、`dossier` → DossierView。
- [ ] **界面在等你的（C05、C10 卡里列为合同缺口，你来补，PR 里列出）**：~~条子牌的 CardView 经 `card_view_part` 加两个看得见的字段 `tier`（int，0–3）和 `kind`（`money/goods/people/info`），名字就用这两个（C05 已按它写）~~（10-13 作废，合同 1.3：改成一个字段 `demand: {kind, tier}`，见下方“10-13 变更二”）；档案簿的 `new` 只标“今天新得到的”，`settle` 30 时清掉（合同没有“标为已读”的指令）。

### I. 数据与键
- [ ] `data/cards/rules/{slots,meters,demand_rules}.json`：只改数，结构不变；新加的数（如口碑→耐心的百分比）加键时同步请 G01 更新 `RULE_KEYS`（`[shared] G03→G01`）。
- [ ] `data/cards/ui_keys/G03.json`：`g03.tier.rep.0`–`g03.tier.rep.4`、`g03.tier.heat.0`–`g03.tier.heat.4`、`g03.reason.*`（`money` `fine` `slot_money` `person_busy` …）、`g03.arrest.demand`、`g03.demand.*`；每个只写 `brief`；`_meta._provenance = {"by":"ai","task":"G03","date":"<提交当天>"}`。条子名目的 brief 按 era.json notes 写（伪维持会等加“伪”字）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `day_end` 6：人脉满了没选 → 新来的不留（同 `contact.release {uid: new_uid}`）；格子里放了还没掷的东西还回来（钱没花、留着的牌还在、放进去的人今天算用过）。
- [ ] 修正项 `end_rows`：人脉满没选一行 `release`（`g03.end.release`）；条子板上每张条子一行 `wait`（`g03.end.demand {days}`，`days` = 打烊后还剩几天，0 = 今晚到期）。键登记在 `ui_keys/G03.json`。
- [ ] 打烊时没处理的事件、命运、街头牌由 G02 执行它们的 `on_expire` 或 `check.on_fail`——你的效果执行器照常跑，`check.on_fail` 当作“没过”执行（不掷铜钱、不发 `coins_tossed`）。
- [ ] 条子照旧：不在手牌，打烊不影响它的倒计时（`settle` 30）。
- [ ] 测试 `test_end_day.gd`（清单 `G03_end_day`）：人脉满没选打烊后新来的不在人脉区；格子里放了钱和留着的牌、没掷就打烊 → 钱没少、留着的牌还在；条子行的天数和 `days_left` 一致；`end_rows` 交的行和 `day_end` 做的一致。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**（合同 §7.5 的 1.3 增补；签名一个不改）

- [ ] `card_view_part` 给 `type == "demand"` 的牌加 `"demand": {"kind": <kind>, "tier": <当前档位>}`（`kind` ∈ `money` `goods` `people` `info`；`tier` 0–3，是拖一拖、人脉被动之后的当前档）；别的类型不给这个键。1.2 的缺口“条子的档位 / 类别”就此关闭，C05 的条子抽屉和胡二那一出读它。
- 1.3 只改界面这一层：选项成了对话框里的回话、格子摆到了柜台上（C03），但发的还是 `card.choose` `slot.place` `slot.remove` `slot.roll` `demand.submit` `demand.delay`，`slots` 查询的形状不变。

**新增 / 作废的交付**

- 新增：CardView 的 `demand {kind, tier}`。
- 作废：上文 H 节说的“条子牌的 CardView 加两个顶层字段 `tier` 和 `kind`”——改成一个 `demand` 字典（上文已就地标出）。

**锚点、界面事件、要证明的步骤**

- 引擎照旧不登记锚点。上文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`gd.demand` → 墙上的条子 `a.scene.notewall`、备 `a.tab.demands`；`gd.dossier` → 柜台上的档案簿 `a.scene.notebook`、备 `a.tab.dossier`；`gd.contact` / `gd.person_state` → `a.contacts`；`gd.kept_risk` → `a.hand.kept`；`a.top.notice` → `a.scene.notice`），你发的 first 和测试不用为此改。

**测试与截图**

- `G03_view` 加一条：条子牌的 CardView 有 `demand`，`kind` 对、`tier` 是拖一拖 / 人脉被动之后的档；非条子牌没有这个键；`leaks()` 为空。
- 截图：无（本任务无界面）。

**已经做了的哪些还有效**

- 全部有效。

**日期**：跟你 10-20 合入的 PR 一起交（来不及就紧接着一个小 PR）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/rules/**`（含 `.uid`）
- `data/cards/rules/slots.json`、`data/cards/rules/meters.json`、`data/cards/rules/demand_rules.json`
- 默认拥有：`scripts/tests/cards/G03/**`、`scripts/tests/cards/suites/G03.txt`、`data/cards/tags/G03.json`、`data/cards/ui_keys/G03.json`

## 不能做的事

- **不写玩家最终内容**：不碰 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`palette.json`、`legal/**`、`fonts/**`；档位文字、原因、条子台词都由人写，你只登记键和 brief；测试夹具“正文”只用 ASCII 假字。
- **不改 `scripts/core/protection.gd`、`data/town/protection.json`、`scripts/sim/town_cond.gd`、`scripts/core/cond.gd`**（只读参考）；不改 `api/**`（含 `dsl_shapes.gd`——形状要改走 `[api]` issue）、`mock/**`、`tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`。
- 只写 `rules` 命名空间；钱、物品、家当、牌堆一律经 `ctx.run` 的效果 op 或主人的公开函数，不直接改 `econ`/`ladder`/`core`。
- 效果不偷偷掷随机：要随机就用看得见的 `coin_check` / 格子检定；`ctx.draw` 只用 `c.coin` `c.demand.kind` `c.demand.pick` `c.demand.amt`。不用 `randf/Time/OS.get_ticks*`；状态里没有浮点。
- 视图、查询、事件里不出现口碑/风声/本心的点数、`tags`、`risk`、`conscience`、`rep`、`heat` 这些键（§7.5 黑名单）；SlotView 用 `wants`。
- 引擎代码不连 `ui_event`；不加 `class_name`（冻结表以外）；不自己加玩法。

## 接口

**提供（冻结签名，§7.9 G03 段）**：`CardSlots`（`slots_of can_place place remove preview roll`，新加 `mark_person_used`）· `CardCoins.toss` · `CardChoices`（`options choose`）· `CardMeters`（`value tier add bump_tier attr add_attr`）· `CardKeptRules`（`bonus run_risk`）· `CardDemands`（`issue submit delay days_left on_settle`）· `CardDossier`（`add gap year_after view`）· `CardEffectsCore.run_op` · `CardCondsCore.test_op` · `CardRulesInstall.install`。

**登记（`CardRulesInstall.install`）**：
- 指令：`card.read` `card.choose` `slot.place` `slot.remove` `slot.roll` `demand.submit` `demand.delay` `contact.release`
- 查询：`slots` `dossier`
- 效果 op：`rep heat conscience attr flag flag_clear counter story dossier dossier_gap notice if coin_check person_state contact_gain contact_lose demand_tier kept_risk`
- 条件 op：`all any not flag flag_eq counter_gte story rep_tier_gte rep_tier_lte heat_tier_gte heat_tier_lte conscience_gte conscience_lte attr_gte has_contact has_kept person_state dossier_has dossier_page_complete demand_open`
- 修正项提供：`coins` `patience_pct` `appraise_pct` `deal_count`（人脉被动）`cap`（如有）`view_section` `card_view_part`
- 钩子监听（§7.3）：`stage_start` 20 · `day_start` 20（临时属性还原、人物回来）· `day_start` 30（周一发条子）· `day_start` 50（人脉被动 `day_start`）· `deal_composed` 20（人脉被动 `deal`；first `slots` `choice` `coins`）· `settle` 30（条子）· `settle` 40（风声回落、到顶被抓）· `year_jump` 30（一年后）
- 随机数域：`c.coin` `[abs_day, uid 或来源路径, attempt, i]` · `c.demand.kind` `[stage, week]` · `c.demand.pick` `[stage, week, kind]` · `c.demand.amt` `[stage, week]`

**用到**：G01 `CardPiles.*`、`CardFirsts.mark`；G02 `CardDayLoop.request_panel`、`CardCalendar.week_of/today`；G04 的 `money`/`pay` op 与 `money_gte`、`CardCurrency.money`（经 `ctx.run` / `ctx.test` / 公开函数，W1 是桩）；G06 的 `arrest` op（经 `ctx.run`）。

**与别的线的约定（写进 PR）**：G05 合入时调你的 `mark_person_used`（G05 卡里写了，等你合入后它 rebase 接上）；条子吃亏、风声被抓等要进日结报告的事用 `notice` 事件发（G02 收）。

## 新手指引

- **锚点**：引擎不登记锚点；你给的 SlotView（`a.slots.first` `a.slots.coins` `a.slots.money`）、选项（`a.slots.choices`）、条子的 `days_left` 与档位（`a.demand.days` `a.demand.tier`；1.3 起档位经 CardView 的 `demand {kind, tier}`）、DossierView（`a.dossier.page` `a.dossier.gap`）要准确，C03/C05/C10 的锚点靠它们。
- **你必须发的 first-time**（§7.10.10；“打开面板”引擎看不到、查询又不许改状态，所以这几个在引擎能看到的最早时刻记，步骤靠锚点只在面板开着时可见来对上时机——PR 里写明）：

| 机制 | 什么时候 mark | args | 对应步骤（教的人 · 锚点） |
|---|---|---|---|
| `choice` | 第一张带选项的牌进手牌（`deal_composed` 20；`card.choose` 时再兜一次） | `{uid, def}` | `gd.choice`（brother · `a.slots.choices`） |
| `slots` | 第一张带格子（或选项带检定）的牌进手牌（同上） | `{uid, def}` | `gd.slots`（obj.brother_ledger · `a.slots.first` 备 `a.card@{uid}`） |
| `coins` | 和 `slots` 同时（“看到 N 枚铜钱要 M 个正面”的那块面板一打开就可见） | `{uid}` | `gd.coins`（obj.brother_ledger · `a.slots.coins`） |
| `demand` | 第一张条子发下来 | `{uid, def, kind}` | `gd.demand`（hu2 · `a.scene.notewall` 备 `a.tab.demands`） |
| `demand_delay` | 和 `demand` 同时（面板里才看得到“拖一拖”） | `{uid}` | `gd.demand_delay`（hu2 · `a.demand.delay`） |
| `demand_people_return` | 第一张 `ev.any.demand_return` 进手牌 | `{uid, person}` | `gd.demand_people`（obj.brother_ledger · `a.card@{uid}`） |
| `demand_inform` / `demand_fabricate` | 第一张“要消息”的条子发下来 | `{uid}` | `gd.demand_inform`（obj.brother_ledger · `a.demand.modes`） |
| `demand_fail` | 第一次条子到期没办成 | `{uid, kind}` | `gd.demand_fail`（hu2 · `a.demand.tier` 备 `a.scene.notice`） |
| `dossier` | 第一块档案碎片 | `{person}` | `gd.dossier`（zhouma · `a.scene.notebook` 备 `a.tab.dossier`） |
| `dossier_gap` | 第一次留缺口 | `{person}` | `gd.dossier_gap`（obj.brother_ledger · `a.dossier.gap` 备 `a.scene.notebook`） |
| `year_after` | 第一块“一年后”碎片 | `{person}` | `gd.year_after`（obj.brother_ledger · `a.year.after` 备 `a.dossier.page`） |
| `contact` | 第一次得到人脉 | `{uid, person}` | `gd.contact`（zhouma · `a.contacts` 备 `a.tab.contacts`） |
| `contacts_full` | 第一次人脉满了 | `{uid}` | `gd.contacts_full`（obj.brother_ledger · `a.slots.release`） |
| `tier_rep` / `tier_heat` | 第一次口碑 / 风声换档 | `{kind}` | `gd.tiers`（zhouma · `a.top.rep`；步骤按第 7 天亮，不等换档） |
| `person_state` | 第一次有人受伤、被扣、走了（`hurt/jailed/away/gone`） | `{person}` | `gd.person_state`（obj.brother_ledger · `a.contacts` 备 `a.hero`） |
| `kept_risk` | 第一次手上（留着的区）有带 `risk` 的牌——牌进 `kept` 没有钩子，所以在你的每个钩子监听和每条指令结束前检查一次 | `{uid, def}` | `gd.kept_risk`（obj.brother_ledger · `a.hand.kept`） |

- **你支持的步骤**：上表全部；第 2 天的 `gd.choice`、第 3 天的 `gd.slots` `gd.coins` 在 `_test.d1_3` 里（第 2 天哥哥告别是带选项的金色牌，第 3 天是 K16 的带格子教学事件）。
- **指引验收（必须有测试）**：上表每个机制恰好一次、第二次不发、存→读后不发、`args` 只含白名单键；第 2 天带选项的牌发下来后 `choice` 在当天的 first 串里，第 3 天带格子的牌发下来后 `slots`、`coins` 在当天的串里（G02 的 `G02_firsts_d1_3` 会整串比对，你的记录点要让它过）。
- **截图**：本任务无界面，不交截图（步骤截图由 C16、K14 出）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G03.txt`：

```
# 名字|脚本|超时秒|参数
G03_ops|res://scripts/tests/cards/G03/test_ops.gd|120|
G03_conds|res://scripts/tests/cards/G03/test_conds.gd|120|
G03_slots|res://scripts/tests/cards/G03/test_slots.gd|120|
G03_coins|res://scripts/tests/cards/G03/test_coins.gd|120|
G03_choices|res://scripts/tests/cards/G03/test_choices.gd|120|
G03_meters|res://scripts/tests/cards/G03/test_meters.gd|120|
G03_kept_rules|res://scripts/tests/cards/G03/test_kept_rules.gd|120|
G03_demands|res://scripts/tests/cards/G03/test_demands.gd|240|--seeds=20
G03_dossier|res://scripts/tests/cards/G03/test_dossier.gd|120|
G03_view|res://scripts/tests/cards/G03/test_view.gd|120|
G03_determinism_save|res://scripts/tests/cards/G03/test_determinism_save.gd|180|
G03_firsts|res://scripts/tests/cards/G03/test_firsts.gd|120|
G03_end_day|res://scripts/tests/cards/G03/test_end_day.gd|120|
```

**每条必须证明的事（合同 §3.2 G03 验收 + §12.2）**：
- [ ] §5 每个归 G03 的效果 op、条件 op 都有正例单测和形状错误反例。
- [ ] 铜钱数 = 属性点 + 钱/档 + 物品 + 留牌（逐项单测），上限 `max_coins`；`auto_pass` 不掷直接成；`heads` 直接算正面。
- [ ] 同一人一天只能放一次；人物 `away/hurt/jailed` 期间不能放。
- [ ] 同一天两个 `coin_check` 掷出的是不同的铜钱（来源路径不同）；同一张牌重掷用 `attempt` 计数，读档后不能刷（同键同数）。
- [ ] 条子：7 天到期；拖一拖 +3 天升一档、最多一次；四档吃亏阶梯（t0 罚钱、t1 查封三天、t2 拿走一件家当、t3 被抓，按 `demand_rules.json`）各走一遍；六种办法都经 `card.choose` 走通，再 `demand.submit`；要消息条子交出消息 → 执行那张消息的 `on_inform`；要人条子：回来那天发 `ev.any.demand_return`、当场掷，不成 `gone`。
- [ ] 档案簿：缺口不能再补；重复补无效；“一年后”只在拿到前一块时补；补齐执行 `on_complete`；DossierView 不列没见过的人、不出现没拿到的碎片、出现缺口。
- [ ] 视图/查询/事件递归无黑名单键（`CardViewModel.leaks()`）；`tier_changed` 只有 `rep`、`heat`；本心从不出现。
- [ ] 确定性：同种子同指令两遍哈希一样；格子放了一半时（`morning`/`month_open` 才能存，所以在这两个阶段）存→读→继续，哈希和连续跑一样；`find_floats` 为空；随机域只用 G03 的四个。
- [ ] “新手指引”一节的验收。

**W1 测试替身**：G04 的钱、G06 的 `arrest` 在 W1 还是桩（`money_gte` 返回假、`money` 什么都不做）。单测里另建一份 `CardCtx`（参照 W0 `scripts/tests/cards/W0/test_engine.gd` 的 `_ctx_with()`），只登记你的 op/条件和测试用的假 `money`/`pay`/`money_gte`/`arrest`，把状态直接摆好；不要等 G04/G06。它们合入后，在 `G03_determinism_save` 里用真引擎再走一遍条子与格子的整条路。

**性能**（bench `scripts/tests/cards/G03/bench_rules.gd`，不进清单，数贴进 PR）：`slot.place`/`slot.roll`/`card.choose` 普通 `send()` ≤ 2 ms；`settle` 里你那两个监听加起来 ≤ 2 ms。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G03 tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；G06 的黄金种子（合入后）不变，变了解释。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G03] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G03] 效果与条件 op、属性与口碑风声本心`
  2. `[G03] 放格子、掷铜钱、选项、留牌加成与风险`
  3. `[G03] 条子：每周发、七天、拖一拖、六种办法、吃亏阶梯`
  4. `[G03] 档案簿与 first-time 收尾`
- **PR 描述**按模板填满，另外必须有：改动路径；用到的随机域；发的 first-time 及位置（含“打开面板类的 first 在哪个引擎时刻记”的说明）；新加的公开函数（`mark_person_used`）；“格子里的钱什么时候花”“读过的消息去留”两条实现理解；对 `protection.gd` 只读参考了哪些做法；黄金哈希变化说明；bench 数；需要主创/编排决定的事；完成时写“交付”。

## 审核（Claude 会逐条看）

1. 越界：只动 G03 路径；没改 `protection.gd`、`dsl_shapes.gd`。
2. 每个 op 的主人与形状来自 `CardDslShapes`；没有自己写的形状函数。
3. 来源路径：嵌套 op 的路径正确，`coin_check` 的随机键里有它；同牌同日不同铜钱。
4. 看得见的随机：效果里没有偷偷的 `ctx.draw`（只有四个登记过的域）。
5. 只写 `rules` 命名空间；钱和家当都经 op。
6. 条子：六种办法、拖一拖、四档阶梯、要人回来、要消息 `on_inform` 都有测试。
7. 隐藏信息：口碑/风声只给档位、本心不出现、SlotView 用 `wants`。
8. 档案簿缺口永久、DossierView 不泄露。
9. 新手指引：18 个 first 的记录点合理、各一次；打开面板类的处理写清楚。
10. 免 AI 声明：只有键和 brief；brief 不写台词；`.gd` 字面量无中文。
11. 确定性、无浮点、存读一致；函数 ≤ 80 行。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| bench 数 | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue | |
| 悬空依赖（等 G04 的钱、G06 的 arrest……） | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
