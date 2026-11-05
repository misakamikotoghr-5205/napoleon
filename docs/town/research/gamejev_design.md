# GameJev archive: the owner's design intent and hard constraints

Sources read in full: `00_README_FIRST.md`, `06_AI_HANDOFF/START_HERE_FOR_AI.md`, `06_AI_HANDOFF/OWNER_DECISIONS_QUOTES.md` (U01–U29), `02_MASTER/Master_Design_and_Technical_Handoff_CN.md`, `02_MASTER/FEATURE_MATRIX.md`, `01_WRITER/Writer_Gameplay_Design_CN.md`, and `07_PLANNED_SPECS/DOMAIN_CONTRACTS_DRAFT.md`. I also checked these for concrete wheel and propagation numbers: `03_CODE/gamejev_living_world_v05/DESIGN_v0.5.zh-CN.md` §2–5 and `livingpacks/workshop/living.json`.

The archive sets its own order of authority: **the owner's latest explicit instruction > owner quotes U01–U29 and the master doc > the actual source code and tests > older docs > early assistant suggestions.** The new town / Stardew / progressive-unlock direction is the owner's latest instruction, so it wins where it conflicts. Everything else in the archive still holds unless the owner overrides it explicitly.

Status of the archive itself: the design is locked, but almost none of the pawnshop, finance or institution systems are implemented. GameJev v0.5 is a Python reference "living world" with a tiny numeric persona model (96-dim state, 32-dim action, 2737 parameters). Its two demo worldpacks (workshop, orbital station) each track one abstract resource. **Nothing in it is a 民国 pawnshop yet.** The `07_PLANNED_SPECS` folder holds unimplemented contracts only.

---

## 1. Core pillars and non-negotiable decisions

### 1.1 Identity statement (the line that separates this game from Probably Stolen)

> "你经营的是财物，更是在一个不由自己掌控的时代中，与具体的人打交道。"

> "世界自己运行，人有自己的人生。主角主要改变身边的人和事，少数后果才可能传得更远。"

The archive says what sets it apart from Probably Stolen (called 深空当铺/可能是偷的 in the chat): "真正被确认的是本作**不展示心理数值**、**以活当与信用区别于纯商品鉴定**。" It also says "借鉴作品也不是要复制其全部规则". The listed reference works are Witchbrook, *Can You Cook My Last Meal?*, Probably Stolen and **Stardew Valley**. They were used for belonging, professional operations, irreversible encounters, risk/reward and daily rhythm. Stardew is already a sanctioned reference.

The player looks forward to three things each day:
- 今天会遇到谁
- 手里这份当物与承诺以后怎样收场
- 熟悉的人和地方又发生了什么变化

The archive is explicit that ordinary days are content: "普通日子是重要内容，不是等待灾难的空白". It also says "游戏不保证善良必有回报，也不为了表现残酷，让每次善意必然吃亏".

### 1.2 Non-negotiable decisions (START_HERE §2: "不得悄悄改掉的要求")

| # | Decision | Owner quote / archive wording |
|---|---|---|
| 1 | The setting is a 民国 pawnshop, not a mix with the earlier ideas (star-ship worker, painter, animal talker). City and month are still undecided. | U09 "按 民国时期 当铺" |
| 2 | **No general store and no restocking. Dead-pawn (死当/绝当) goods are the shelf stock.** The early "3 daily goods / 10% general store" idea is abolished. | U24 "那就不卖百货 死当当百货 然后活当赌一手" |
| 3 | **Live-pawn gamble.** The player may sell a 活当 item without authorisation while it is still redeemable. The contract, the duty to return the original item, and the consequences once it is discovered all survive. It is "not laundered into a normal legal good". | U23 "可以赌一手卖别人的 活当 来赌利益" |
| 4 | **Inspection is a limited information tool**, not the main gameplay of repeatedly hunting flaws. | U23 "单独验货是不是没啥意思" |
| 5 | **Life pressure comes from natural living**: food, rest, cash flow (周转), social obligations (人情). It must not come from endlessly rising rent that forces crime. | U25 "生存压力就来自自然生活 吃饭啥的 哦对了还有人情社交 得打交道 讨价还价系统" |
| 6 | **Bargaining is two-way and covers more than price** (terms, duration, fees, guarantees). Several people can visit at once, plead, stay silent, object or change sides. | U25, U27 "一次可以不只来一个人 还可以来好几个 帮忙说话的之类的" |
| 7 | **The player never sees** probabilities, affection, personality labels, true reserve price, future draws or omniscient secrets. Money, items and contracts stay objectively clear. | U26 "这个概率和好感度是代码内而玩家看不见的" |
| 8 | Every person has a multi-dimensional personality and per-person relationships. MBTI and Enneagram are creation presets only, never real-world prediction and never mapped to good or evil. | U14 |
| 9 | People may appear once or come back. Absence ≠ death. The world does not force every thread to close. | U01 "可能见到一次就永别可能再次见到" |
| 10 | **Finance is in the design**: 金圆券, stocks, bonds and IOUs, debt collection, guarantees, and the player pawning their own things for loans. Finance does not replace daily life and relationships. | U21, U22 |
| 11 | **The four institutions are in: 法庭, 警局, 军队, 官场.** Private identity, office authority and institutional responsibility are kept separate. Historical rules still need research. | U28 "加入 法庭 警局 军队和官场" |
| 12 | **An independent world wheel runs continuously.** The protagonist mainly affects people in direct contact. Distant effects need a channel, a delay and a threshold, and stay uncertain. | U17 "整个世界观的轮盘随机转动 主角的某些行为可能会影响世界 但不是所有的 主要影响直接接触的人 可能间接影响世界但不一定" |
| 13 | **Local, offline, tiny numeric model** with fixed semantics, swappable knowledge packs and executor adapters. "不要默认加入大LLM服务". | U07, U08, U10, U16 |
| 14 | No promise of a Steam AI-disclosure exemption. "Hard to detect" or "AI wrote code that draws it" is not an exemption. Formal assets and text need provenance review. | U02 "要ai驱动而且不能有ai标注的", U07 |

`00_README_FIRST` restates the minimum set to never lose: "不另进百货，死当旧货承担货架；活当允许冒险提前出售但义务不消失。生活压力来自吃饭、休息、周转、人情。双方议价，允许多人到场说情。心理和概率藏后台。世界自己运行，主角主要影响身边人。金融与四类机构都已列入设计，不得无说明删除。"

### 1.3 Other owner quotes that shape the design

- **U04** "其实主要还是玩法和剧情": gameplay and characters come first; model architecture is not a substitute for a game.
- **U06** "还有随机性和不可控性吧": randomness, incomplete information, and outcomes the player can judge but not guarantee.
- **U12** "行动能不能不只是四种呢": actions are a dynamic candidate set, not four fixed choices.
- **U13** "顾客为什么不会做极端动作呢？": extreme acts such as conflict, robbery and damage are possible. They need real conditions and real consequences, never a hidden "go-crazy roll".
- **U15** "玩家会影响环境NPC 环境影响NPC NPC和环境影响玩家 这几种嵌套影响做了么": the influence loops must be genuinely multi-directional.
- **U16**: swappable knowledge interface; the same model can be reused with a different knowledge pack.

### 1.4 The main business loop (locked)

接触来客 → 判断物与人 → 议价与签约 → 放款或拒绝 → 保管与周转 → 赎当／续当／死当 → 旧货出售 → 回收资金

Normal safekeeping must also be attractive: stable fees, a reputation for keeping contracts, repeat business, and seeing a customer finally redeem an important item. "冒险可以很赚钱，也可以亏损，但不能成为唯一能活下去的玩法。" A voluntary buy-out or consignment is a legitimate separate contract. It must not be used to rename secret live-pawn sales.

Worked example the owner endorsed: the player lends 250 and sells the item early for 600. The customer returns with the agreed 280. The player has to pay 750 to buy the item back. Net cash is −120, before search, delay and dispute costs. The 600 is not profit.

---

## 2. Randomness

The owner asked for it directly: U06 "随机性和不可控性" and U17 "整个世界观的轮盘随机转动". The archive gives randomness structure. It must be **independent, conditional, quiet-heavy, never targeted at the player, and never re-rollable by clicking.**

### 2.1 The world wheel (世界轮盘)

The wheel is a discrete event scheduler, not a visual spinner: "这里'轮盘'是离散事件调度器，不是已制作好的视觉转盘UI".

**Two kinds of wheel, outer and inner:**
- **Exogenous (外生) wheels**, e.g. climate and calendar. They never read player actions or endogenous pressure. They use only an independent random key, the season and declared parameters. "多聊一句话也不应该改变本来独立的下一场天气。玩家做好事，不会因此被系统故意安排坏天气来'平衡'。"
- **Endogenous (内生) wheels**, e.g. logistics/supply and civic/order. They read only pressure that has actually arrived through the propagation rules (§2.4). They never read "what the protagonist just did".

**Time scales in the demo pack** (marked as test values, not final):

| Wheel | Mode | Demo period | Outcomes (demo) |
|---|---|---|---|
| climate | exogenous | every 6 game-hours | quiet (w8), clear (w3), rain (w2, cooldown 6h, season weights [2,1,1,0.5]), gale (w0.5, cooldown 18h) |
| logistics | endogenous | every 8h | quiet (w6), delivery (w2, supply +4, pressure_bias −0.5), shortfall (w1, supply −2, cooldown 16h, pressure_bias +8) |
| civic | endogenous | every 12h | quiet (w8), tighten (w0.5, norm strength up, needs pressure ≥ 0.05, bias +4, cooldown 24h), ease (w1) |
| calendar | exogenous | every 24h | quiet (w8), gathering (w2, publicness 0.9, cooldown 48h), ordinary_day (w3) |

Demo day = 24h. Seasons rotate every 96h, for accelerated testing only.

**Weight formula:**

`有效权重 = 基础权重 × 条件许可 × 冷却许可 × 季节系数 × 情境修正`

For endogenous wheels, `情境修正 = max(0, 1 + pressure_bias × 已送达压力)`.

- Every wheel **must have a positive-weight `quiet` outcome**.
- Cooldowns, preconditions and condition filters apply.
- There is no per-frame drawing and no infinite recursion at one timestamp.
- Events come from a finite whitelist. They are not freely generated laws or plot.

**RNG discipline:**
- Every draw is `draw(world_seed, domain, semantic_key)` via SHA256. Domains include `wheel:climate`, `wheel:logistics`, `message_relay`, `physical_influence`, `norm_detection`.
- The climate key is its round number, not a global event counter. So clicking dialogue, opening previews or changing frame rate does not consume the next weather draw.
- Each NPC's personality uses its own independent random stream.
- **Previews never consume official randomness.**
- Save files store the seed and round numbers.
- Verified in v0.5: with and without the player's local actions, 15 exogenous draws were identical.

**Preparation cannot be punished.** Holding reserves, stockpiling, booking backup help and adjusting commitments improve the player's ability to cope. They never change future draws: "准备改变应对能力，不改变未来抽签来克制玩家；没发生灾难也不意味着准备是错误。" This is EXT09.

Big events affect schedules, transport, living and enterprises, but not everyone in the same way. Calm, recovery and ordinary business must exist.

### 2.2 People-level randomness

- NPC choice works in layers: limited observation → update emotion, goals, relations and memory → filter by knowledge conditions → per-candidate inputs → rule utility plus a small neural residual → **behaviour-family distribution → candidate within family** → serious-behaviour cap by game time → independent RNG pick → action request plus a separately computed outward attitude → host validates and executes.
- Duplicating variants of one action type must not raise that type's total probability.
- Serious acts are capped per game time. Repeated previews do not add chances. A non-serious wait or exit option must always exist, so the system never renormalises to 100% serious.
- "极端反应不能是每次交谈都偷偷掷一次的'发疯概率'". Triggers depend on stimulus, perceived situation, whether there is a way out, how public it is, who is involved, and what the NPC can afford. Poverty, personality type or profession must never equal danger.
- Inner evaluation, actual action and outward attitude are three separate outputs: "合作不代表喜欢，客气不代表原谅，沉默不代表同意".
- A personality is a slow variable. It must not reroll per visit; change must link to experience.

### 2.3 Encounters and reunions

- A customer may appear once, pass by occasionally, or become a regular. **The player cannot see which in advance, nor know which goodbye is the last.**
- No guaranteed quest line just because someone talked to the protagonist. The system "没有为了主角戏份而强行让同一个人回访".
- On return, a person's clothes, companions, form of address, spending, topics and items may have changed, sometimes because of the player and sometimes not.
- Absence ≠ death. Possible causes: moved, changed job, nothing to pawn, unwilling, missed the time slot, finances changed.
- **A reunion may be indirect**: their left-behind item, someone they referred, a family member fulfilling a promise, or a letter. Some parts of a life stay forever unknown.
- EXT07 "从缺席发现变化": once the player learns routines, they notice who is missing and may ask around, leave a note, or carry on. The design must not turn every acquaintance into a daily check task.

### 2.4 Rumours, information and material propagation (three separate chains)

1. **Material chain.** A successful action really moves goods or changes an item. There is no second roll to decide whether "taking it counted".
2. **Information chain.** Observations spread only along explicit social edges, with delay, confidence decay, TTL, hop limit and source de-duplication. Demo `communication` values: delay 0.5h, confidence decay 0.65 per hop, relay probability 0.4, max hops 3, TTL 12h, min confidence 0.2. Some limits are not implemented yet: complex lying, content distortion and true/false evidence fusion.
3. **Macro chain.** Only whitelisted outcomes above a size threshold travel along the region graph (`local → remote → __world__`, plus an unconnected `isolated` area). Demo values:
   - min magnitude 6, normaliser 20
   - 0.35 chance per edge, 1h delay per hop, ×0.5 attenuation per hop
   - max 2 hops, min signal 0.025
   - per-actor daily cap 0.5, global daily cap 0.2
   - pressure half-life 24h
   - In an 80-seed test, 11 runs reached the world layer and the rest did not. That demonstrates "may or may not", not a balance target.

- "**没听说，也可能已经被后果影响**": message spread and material effect are different paths.
- Hearing the same source many times is not independent proof. Eyewitness, hearsay, inference and deliberate concealment are distinguished.
- Private talks are not broadcast to everyone present. People who leave do not hear what follows.
- Someone who overhears in the room may carry the information into their own network later.
- A greeting stays between the two parties by default. Penalties and reputation stay where they happened: there is no global notoriety and no nationwide sync.

### 2.5 Uncertainty the player lives with

- Inspection takes time, tools, fees and sometimes the owner's consent. The player may quote with incomplete information.
- Inspection reveals authenticity, usability, condition, likely buyers and storage difficulty. It never reveals "this person will come back" or "this person is a fraud".
- Debtors fall into distinct cases: able and willing; willing but no cash; assets that are hard to liquidate; able but stalling; disputing the contract; temporarily unreachable. "逾期不直接等于骗子，守约人格也不能凭空变出钱".
- Outcomes of kindness and leniency are not predetermined to teach a moral lesson.

### 2.6 What the player MAY and MAY NOT see

**MAY see, clearly:**
- own cash and possessions
- contracts, due dates and terms
- public quotes (with source and timestamp)
- completed trades
- documents obtained
- where items are
- the player's own ledger, keeping lent-out money, expected receipts and cash-on-hand as separate figures
- public expressions, forms of address and actions of others, as *clues*
- a note/journal of what was seen and heard, with dates, sources and contradictions (EXT04). It must not auto-certify truth.

**MAY NOT see:**
- personality types or labels, traits, motives
- true trust or resentment, deception tendency
- redemption probability, success rate, patience bar, reserve price, "best option" hint
- world-event weights, future wheel draws
- omniscient causal judgement, private facts
- candidate scores

Forbidden fields in any player payload: `traits, motives, relations, probabilities, candidate_scores, future_wheel_draws, private_facts`. The internal preview/JSON shows probabilities for debugging only. Integration needs a visibility whitelist.

Hiding numbers does not license arbitrary rules: "已经存在的事实不能在玩家选择后被偷偷改掉". Item locks, ledgers and contract authenticity are deterministic and are never rewritten by a later random draw.

---

## 3. What maps to a TOWN with buildings and institutions

### 3.1 Locations and places the archive mentions

**Inside the pawnshop:**
- the counter (柜台)
- a private talk spot (私下谈话处)
- a waiting area (等候位置)
- partitions (隔断)
- a public notice board (公开告示)
- the dead-pawn shelf (旧货架)
- storage for pledged goods (保管)
- the cash box (钱匣)

EXT06 "空间影响社交": layout decides who sees, who hears and who is willing to speak. "装修不只是舒适度加成；容量、隐私和公开见证之间有取舍。" This argues strongly for a walkable interior (top-down or 2.5D) where position matters.

**In the town:**

| Place type | Purpose / evidence in the archive |
|---|---|
| Home / residence (住处) | Housing is part of life pressure. Whether the protagonist owns the shop or is a hired manager, and where they live, is undecided. |
| Eating places (饭馆/吃饭) | "吃简单一点可以省钱"; 请客 (treating people) costs time and cash; meal prices show inflation. |
| Acquaintances' homes | 拜访, 探望 (visit, call on the sick); EXT01 "安排相遇" needs time, place and who is present. |
| Market / quotes | 货价, 进货报价 that expire; price records carry place, item, time and source. |
| Enterprises / factories / suppliers | Stocks: the player can visit, check orders, ask whether wages arrived, verify deliveries. Enterprises have their own cash, wages, raw materials, orders and debts. |
| Workers' lives | Linked to enterprise health. |
| Transport / logistics | Logistics wheel; "远处发生的运输变化已经影响某家企业". |
| 法庭 (court) | Contract and pawn-ticket disputes, evidence, witnesses, mediation, ruling and enforcement. |
| 警局 (police) | Reports, theft, false claims, suspected stolen goods, questioning, physical evidence, investigation. |
| 军队 (army) | Soldiers' private pawns and debts, authorised procurement, transport and troop movements. |
| 官场 (officialdom) | Business paperwork, accounts, taxes and fees, licences, inspections, public notices, local enforcement. |
| Mediation / third-party appraiser | "请熟人帮忙鉴定", 委托鉴定, 调解. |
| Gatherings (calendar wheel) | Public events raise publicness. |

### 3.2 How institutions must work (hard rules)

The archive says: "四类机构…不是四种随机罚款，**也不是四个用好感度打通的商店**。人物有私人身份，也有职务、权限、义务和组织内部关系。"

- **Court:** a favourable ruling ≠ money received immediately. Liking someone cannot decide who wins.
- **Police:** not omniscient. An ordinary debt does not automatically become a criminal case. Not a universal debt-collection tool.
- **Army:** a private debt is not the army's debt. Rank grants no disposal authority.
- **Officialdom:** relationships ease communication and help, but do not cancel all rules.
- **One person, two roles.** A policeman can first appear as an ordinary customer and later act on duty. A soldier buying a live-pawn item does not mean the army joins the dispute.
- Institutions can refer cases to each other and influence each other, but cannot replace each other.
- Visits can be multi-party: the parties themselves, relatives, police officers, clerks, agents, witnesses.
- Institutions are busy offscreen and do not clear their queue for the player.
- Case records keep evidence sources, stages, visibility and enforcement. A judgment does not create assets that are not there. Investigators cannot solve a case by reading the global truth.
- Do not paint any whole profession as corrupt or abusive.
- Do not apply modern procedure to history. Details must match the final city and year.
- **Suggested first cases (§9.1):** one contract dispute, one physical-evidence investigation, one soldier's private loan or one authorised procurement, and one business-licence procedure. Not every matter has to go through all four institutions.
- Data model: `Institution` (type, jurisdiction, posts, authorisations, schedule, to-dos, public rules), `OfficeRole` (separate from `Person`), `Case`.

### 3.3 NPC daily schedules and offscreen life

- "NPC同样工作、吃饭、休息、照顾自己的事情。主角没到场，日程、运输、到期任务和个人需要仍会变化。**玩家错过一次见面，不能让对方永远在门口等待。**"
- Implemented in v0.5 (W02):
  - schedules with work, social and rest nodes in discrete areas
  - accepted jobs progress even when the player is absent
  - a missing route marks a trip as impossible
  - an NPC busy with a reserved task does not teleport to the next activity
  - periodic autonomous wake-ups
- Demo schedule format: `{at_hour, area, activity, obligation}`. Example: A works at 1h locally, socialises at 8h remotely, rests at 16h locally. `npc_period_hours` = 2, `metabolism_period_hours` = 4.
- NPCs have the same right to change the world: they work, borrow, pass on news, default or cooperate offscreen without the protagonist's involvement.
- Commitments reserve real stock immediately (escrow). At the due time the system checks the place, tools and task state. A grace period applies, then the commitment is marked as broken.

### 3.4 Progressive unlocking (owner's new idea): what the archive allows

The archive has no unlock mechanic. It does constrain one:
- Institutions must **not** be "shops unlocked by affection".
- Unlocking should come from **real relationships, events and needs** through actual channels. Examples:
  - the first dispute brings you to the court
  - a suspected stolen item brings in the police
  - a soldier customer introduces army procurement
  - a licence inspection brings officialdom
  - an acquaintance introduces you to an enterprise that issues shares
- The handoff's build order maps naturally to staged openings: 账本/合同 → 活当与死当闭环 → 双向多人议价+UI → 日常社交 → 金圆券与债务/担保/抵押 → 股票企业 → 四机构案例 → 完整Godot宿主.
- EXT10 "制定身边的小规则": the player sets rules for their own premises (appointments, credit, grace, guarantees, queueing). "塑造的是地方办事风格，不是统治全国" — the player shapes local practice, not national power. The player's sphere is local.
- Undecided items (§15) relevant to the town:
  - city and month, and the historical-vs-fictional ratio
  - whether the protagonist owns the shop or is a hired manager; family; residence
  - "终局与是否继续经营" (endgame, and whether play continues after the ending)

  The owner's docx item 9 ("choose to continue the pawnshop or change profession") fills exactly this open slot.

---

## 4. Daily survival pressure (吃饭 / 休息 / 周转 / 人情)

### 4.1 Components named by the archive

| Component | How it creates pressure | Required variability / nuance |
|---|---|---|
| **Food (吃饭)** | Daily cost. "吃简单一点可以省钱" lets the player trade quality for cash. | Meal prices move with 金圆券 purchasing power, supply (logistics wheel) and local stock. Prices differ by item, never "one uniform multiplier". Missing a meal must not mean death by default. |
| **Rest (休息)** | Staying up lets the player handle one more matter but hurts the next day's state. | Fatigue is a real variable (v0.5 W03: consumption 0.03/h, fatigue 0.025/h, rest recovery 0.08/h, demo values). Energy and fatigue persist. |
| **Housing (住处)** | Part of basic living. | Must **not** be an ever-rising forced rent curve. |
| **Business consumables (经营消耗)** | Running costs of the shop. | Vary with supply and prices. |
| **Cash flow (周转)** | Cash tied up in active loans; redemption timing; due dates of the player's own debts; expected vs. actual receipts. | Shown as separate numbers (cash / lent out / expected / frozen). Depends on which customers actually return and when. Quotes expire. Wages and debts may be due at once. |
| **Social obligations (人情)** | Invitations, visits, treating people (请客), visiting the sick (探望), introductions, errands, serving as a witness, asking for leniency. They cost time (away from the counter) and cash. | Driven by calendar gatherings and NPC events. A treat is "正常交往而不是换任务奖励". Missing one social call must not end a relationship forever. Refusing once ≠ breaking up. |
| **Commitments already made (已承诺支出)** | Reserved goods, promised deliveries, guarantees the player signed, the player's own pawned items (FIN05). | Generated by earlier play, not by a scripted rent table. |

### 4.2 Design rules for the pressure

- "不靠一条不断暴涨的强制租金曲线，逼玩家只能坑骗顾客。" The pressure must not push the player toward crime as the only path.
- **Basic living and quality of life are separate.** Normal business, thrift and planning can sustain daily life. Good judgement improves it. Risk opens bigger opportunities and bigger liabilities, but is never the only way out.
- Under 金圆券 the nominal cash balance need not be deducted daily. The player *feels* inflation through meal prices, wages, supply quotes, quote expiry and the real value of debts. "钱匣里的纸币没少，能办成的事却少了。"
- There is no infinite, free, always-safe value-preservation button. Converting all cash into goods carries storage, wear, unsellability and liquidity risk.
- Failure brings loss, but must not silently and permanently lock every income source. Costly recoveries are allowed: low-pay work, renting substitute tools. Free bail-outs are not.
- **Sources of variance the archive already provides:**
  - currency/purchasing-power drift from the world process (not from single player trades)
  - logistics wheel delivery/shortfall
  - calendar wheel gatherings
  - climate
  - NPC life events and invitations
  - which pawns are redeemed and when
  - debtors' ability vs. willingness
  - institutions' taxes, fees and inspections (官场)

  Concrete balance numbers are **not** locked: "物价曲线…尚未锁死".
- §22 shows the intended rhythm of a day:
  - morning: a simple meal; seeing an expired supply quote; deciding how much cash to keep in reserve
  - noon: a friend's invitation that costs counter time
  - afternoon: a dead-pawn buyer and a redemption at the same moment
  - evening: a loan falls due, and the player may have to explain themselves to their own lender
  - next day: no shocking twist needed

---

## 5. Expansion ideas (U20) and finance (U21/U22)

### 5.1 The ten expansion gameplay ideas (U20, §20, all "retained design")

1. **安排相遇 (arrange meetings).** The player sets the time, place and who attends, bringing together people who distrust, missed, or avoid each other. Public or private, who witnesses and who speaks first change the scene. The outcome may be cooperation, a fight or a partial deal, and they may bypass the player afterwards.
2. **有边界的委托 (bounded delegation).** The player hands a goal to someone with a money cap, acceptable terms and contingency rules. The delegate has their own judgement and time and is not a remote-control arm. They cannot touch assets beyond their authority, and breaking verbal preferences leaves liability.
3. **为别人担保 (guarantee for others).** The player vouches with limited assets, their judgement or a specific promise. Credibility is per-matter and per-person, not a universal pass. Paying as guarantor reduces the debt. Speaking up for someone ≠ formal guarantee.
4. **消息与证据工作台 (news/evidence workbench).** The player sorts eyewitness, hearsay and inference with dates and sources, and decides what to verify and what to pass to whom. Same-source rumours do not add up. The notebook helps judgement but never gives the final answer.
5. **物件自己的经历 (item's own life).** Keeping engravings, repairing old parts, re-casing, consigning or passing items on changes who can later recognise an item and how it is used. Handling objects changes story conditions.
6. **空间影响社交 (space shapes social life).** The counter, private corner, waiting seats, partitions and notices decide who sees and hears and who will speak. Layout is a trade-off between capacity, privacy and public witnessing.
7. **从缺席发现变化 (notice change through absence).** Learning routines lets the player notice who did not come. They may inquire, leave word, or carry on. The cause may be ordinary or serious, and it is never a mandatory daily check.
8. **给冲突一个退路 (give conflict an exit).** Pause, verify, let someone leave, change the audience, bring a witness. An outcome can be a postponement rather than reconciliation. No button-mashing to re-roll success.
9. **为不确定的明天准备 (prepare for an uncertain tomorrow).** Cash reserves, materials, substitute tools, backup help and conditional plans. Preparation has a cost but is never targeted by the wheel.
10. **制定身边的小规则 (set small local rules).** House rules for appointments, credit, grace, guarantees and queueing change how customers visit and cooperate, and opinions differ. Local style, not national rule.

These are not ten separate big models. The first playable does not need all ten at once.

### 5.2 金圆券 (U21, §13, FIN01)

- An unstable *purchasing power and credit*, felt through meal prices, wages, quotes, quote expiry and the real value of debts. The nominal balance is not auto-deducted.
- A debtor can repay in full on paper while the lender loses real value. That is purchasing-power loss, not default. NPCs differ: some think face value is enough, others top up for old ties.
- Old contracts' currency, amount, term and settlement rule can never be silently changed. Change requires negotiation or pre-declared, historically researched rules.
- The macro currency state comes from the world process, never from one player trade.
- There is no free, safe value-preservation button.

### 5.3 Stocks (U21, §14, FIN02)

- The player deals with enterprises and people, not a line chart. Before trading they visit, check obtained orders and news, ask whether wages were paid, and verify deliveries.
- Shares are not loans: no principal guarantee, no guaranteed dividend.
  - Buying old shares pays the seller, not the company. Only subscribing to a new issue funds the company.
  - Quotes, settlement time and limited counter-party willingness apply, with partial fills.
  - The last trade price ≠ the price at which the whole holding can be sold.
  - A rise may only track the currency's fall.
- A small holding gives no control. One NPC can be a shareholder, a creditor and an employee's friend at the same time, creating conflicts between dividends, repayment, wages and survival of the business.
- No per-second ticker, no high leverage, no guaranteed insider tips. Stocks are optional and must not replace the counter.

### 5.4 Bonds, IOUs and debt collection (U22, §15, FIN03/FIN04)

- Enterprise bonds face an issuer and a group of holders. Private IOUs face a specific borrower, witnesses and guarantors. The player cannot collect from employees or family who carry no liability.
- Terms: amount and currency, schedule, interest/fees, collateral, guarantee scope, grace, dispute handling. Borrowers negotiate too.
- Ability, willingness, dispute and unreachability are separate states. The model may never create cash from a "repay probability".
- **Collection is not a repeated "pressure" button.** Options, each costing time, cash, goodwill and evidence:
  - private reconciliation meeting
  - accept a partial payment
  - reschedule
  - verify incoming funds
  - introduce a buyer for the debtor's goods
  - invoke a limited guarantee
  - seek mediation
  - dispose of collateral per contract
- Possible outcomes: full recovery but a broken relationship; partial recovery but continued dealings; leniency that saves someone or still fails. Never predetermined.
- No one-click intimidation or public shaming as a high-success collector. Conflict and illegality may exist, with consequences.

### 5.5 Player pawns own items for loans (U22, §16, FIN05)

- The player is not always the creditor. When short of cash they can pledge their own items (keepsakes, main tools, spare equipment), then face redemption, a request for leniency, or losing the item.
- A main tool raises cash but cannot be used while pledged. A spare looks unimportant until an emergency.
- Sentimental value ≠ what a lender will advance.
- Explicit reminders, negotiation and grace, then disposal and settlement. Items never vanish unannounced. No double pledging, no charges after full repayment.
- Pawn-style (hand over the item) comes first. Non-possessory pledge needs separate rules.

### 5.6 Guarantees (FIN06 / EXT03)

- A guarantee is a three-party relation: guarantor, guaranteed obligation, liability cap, trigger, release.
- Paying as guarantor reduces the original receivable. No double collection.
- Standing beside someone and speaking up ≠ guaranteeing.

### 5.7 Finance invariants (§8.6 and DOMAIN_CONTRACTS)

- Double-entry by currency, with integer minor units or a Decimal.
- Unique payment IDs. A retried payment never pays twice.
- Company and personal accounts are separate. Share counts are conserved.
- An item has one physical location and explicit rights records.
- Economic results are executed first, then mapped to each person's perceived relationship and emotion. Never rewrite equity, balances or ticket authenticity to trigger a story beat.

---

## 6. Anti-requirements: things that must NOT be done

**Business model**
- Do not add a general store or wholesale restocking menu. No "3 daily goods / 10% general store". All shelf stock comes from dead pawns (or explicit voluntary buy-out/consignment).
- Do not treat an active live pawn as freely sellable own inventory. Do not jump an early-sold live pawn to "forfeited". Do not delete the liability from UI or backend. Do not auto-legalise it if the owner never returns.
- Do not make early-selling live pawns the only viable way to survive.
- Do not make deep, item-by-item flaw-hunting inspection the core loop. Do not require 100% inspection before a deal.
- Do not let the shelf be an infinite supply.

**Pressure**
- No ever-rising forced rent curve that drives the player to cheat.
- No "forget one meal → die" and no "skip one social call → friendship gone forever" as the default rhythm.
- No unconditional free bail-outs. No silent permanent lock-out of all income.

**Hidden information / UI**
- Never show success rates, patience bars, reserve prices, "best option", affection or trust bars, personality types, redemption probability, world-event weights, future draws or omniscient causality.
- Never serialise the whole session or debug JSON to the player.
- Do not hide objective accounts, contracts or deadlines behind hidden psychology.
- Do not change existing facts after a player choice.
- Do not make reading speed a punished skill. Do not require free-text input to be understood.

**Bargaining / multi-party**
- No single-sided "spam the success roll" haggling. Repeating the same line must not re-roll for free.
- Do not average companions into one group affection. Companions are not a "persuasion bonus" prop.
- The loudest person does not get disposal rights. Bystanders do not become guarantors.
- Do not broadcast private talks to everyone present.
- Do not apply a uniform affection penalty for low prices.
- Friendship ≠ automatic discount. A tough personality ≠ refusal of fair terms.

**NPCs and behaviour**
- No fixed four-action set.
- No hidden per-conversation "go crazy" roll.
- Do not equate poverty, personality type or profession with danger, crime or evil.
- Do not let MBTI/Enneagram labels drive decisions directly or appear to the player.
- Do not re-randomise personality per visit.
- Do not force every met character into a fully resolved quest line.
- Do not force the same person to revisit for the protagonist's sake.
- Absence must not automatically mean death.
- Do not make NPCs wait forever at the door.

**World / randomness**
- The world must not turn only when the player presses a button.
- Exogenous events (weather, calendar) must not read player actions.
- No karmic balancing: no bad weather to punish good deeds, and no wheel targeting the player's preparations.
- No wheel without a `quiet` outcome. Do not require a disaster every round.
- No per-frame draws. Previews must not consume RNG.
- Do not let every small deal rewrite town-wide prices. No global instant sync. No nationwide notoriety.
- Do not escalate one tiny act into a macro crisis.
- Do not equate `cause_id` with "the player caused all of it".
- No random re-adjudication of ledgers, item locks or contract authenticity.

**Institutions**
- Not four kinds of random fines. Not four "shops" opened by affection.
- A court does not rule by affection. A ruling ≠ money in hand, and judgments do not conjure assets.
- Police are not omniscient and not a universal debt collector. Ordinary debt ≠ crime.
- A soldier's private debt ≠ the army's debt. Rank ≠ disposal power.
- Officialdom: relationships do not cancel all rules.
- No modern procedures pasted onto history. Do not portray whole professions as corrupt.

**Finance**
- No pure number-crunching stock minigame. No per-second ticker, no high leverage, no sure-win insider tips.
- No infinite safe value-storage button.
- Do not count inflation loss as default. Do not silently rewrite old contract currency or amounts.
- No collecting from non-liable family or employees.
- No one-click intimidation or shaming collector.
- No double collection, double pledge or double settlement. No fees after payoff.
- Old-share purchases do not fund the company.
- Finance must not replace daily life and relationships, and must not be mandatory for every player.

**Engineering / process**
- No large LLM service by default and no per-NPC LLM. Do not make players install model software or run servers. Offline, low-spec.
- Do not claim systems are done when they only return a string, ID or counter. Empty classes and mocks are not completion. Verify real world consequences, ledger entries, observations, save/rollback and de-duplication.
- Do not let unconfirmed defaults (term lengths, fees, NPC counts, durations, probabilities) silently become "owner-confirmed". Mark prototype assumptions.
- Do not claim a Steam AI-disclosure exemption. "Hard to detect", "AI-written drawing code" or "human-polished" do not count as exemptions.
- Do not bring in the abandoned themes (star-ship worker, painter/composer, animal talker, Star Wars IP).
- Do not ask the owner to re-answer settled questions. Do not quietly override decisions.

---

## 7. Tensions and gaps for the new direction (planner's notes, not owner quotes)

1. **Timeline conflict: 1938 vs 金圆券.** The repo is set in 1938. 金圆券 historically dates from 1948–49; in 1938 the currency was 法币, with inflation rising through the 1940s. The archive says the city and month are undecided and "金圆券…需要和最终时空一致；架空变化需明确标记". This needs an owner decision. Options: move the year; use 法币 with a later 金圆券 phase as the "year progression"; or mark it as a fictional deviation.
2. **Relationship visualisation (docx #17) vs hidden affection (U26).** Show relationships qualitatively only: who knows whom, gifts given, telegrams and letters, visit history, forms of address, observed expressions. No numbers, bars or hearts.
3. **Magnifier / appraisal certificate (docx #5) vs "inspection is not the core".** This is compatible if appraisal is an optional tool with real cost (time, fee, owner consent) that gives partial information. An external appraiser or certificate could be a town shop or NPC ("请熟人帮忙鉴定 / 委托鉴定"). It must never reveal the customer's psychology.
4. **"Always buying never selling" (docx #7, #14).** This is solved within the constraints by the dead-pawn shelf with real buyers who can buy single items, plus finding specific buyers, repair-and-resell, and voluntary consignment. A general store is still not allowed.
5. **Starting items and bills (docx #8).** These fit as inherited dead-pawn stock with histories, existing active contracts, and the player's own debts and pledges. They must not be a wholesale catalogue.
6. **Live pawn: "first week sell, second week buy back" with extension (docx #10).** This matches 活当赌一手 plus 续当 (renewal keeps term versions). The obligation survives the sale.
7. **Double-agent / middleman / spy (docx #18).** This maps to multi-party sessions, private channels, 安排相遇, 有边界的委托, and the evidence workbench.
8. **Profession change (docx #9).** This fills the archive's open item "终局与是否继续经营". It may also tie into the owner's "other shops open gradually".
9. **Gen-AI DLC kept separate (docx #12).** This is consistent with keeping the base game free of disclosure-required generated content.
10. **Typewriter text (docx #2).** It must be skippable or instant, because "默认不让阅读速度成为被惩罚的能力".
11. **Town and walkable interior.** The archive's §20.6 (space shapes social life), §20.1 (arrange meetings at a place), the NPC schedules across areas, and the regional propagation graph all fit a Stardew-style town with walkable interiors. A walkable or 2.5D interior is the stronger fit for "who stands where hears what". A portrait dialogue box on entering a shop is compatible with the clue rules, provided it shows no numbers.
12. **Progressive unlocks** should be driven by in-world causes (a case, a referral, an inspection, an enterprise contact), not by spending affection or points (§3.4).
