# 德厚当: story content catalogue for the town redesign

Source: `/home/user/dehoudang` (v0.3b). I read every file named in the brief in full: `data/cast.json`, `factions.json`, `codebook.json`, `medbook.json`, `night.json`, `pages.json`, `layout.json`, all 15 `data/story/*.json`, all 11 `data/sessions/*.json`, all 6 `data/items/*.json`, `README_CN.md`, `docs/V03_BRIEF.md` and `docs/playtest/*.md`. I also read `docs/review/m3_summary.md` and `m4_ending.md`, and the story-relevant parts of `scripts/core/world.gd` and `director.gd`: the hidden stats, rumor facts, off-screen life, night actions and hook functions. I modified no repo files.

---

## 0. Summary

* **The content is good and it is not the problem.** It has 13 written characters with personality presets, a social graph and daily schedules. It has a mystery spine: the missing parents, 陈叔叔's radio and the ticket 德字第一九六号. It has about 25 moral branch points whose consequences land later, and it has authentic period appraisal knowledge.
* **The Probably Stolen feel comes from the frame, not the story.** The frame is one fixed counter screen, a queue of `session`s per time slot, a magnifier minigame, haggle rounds, a rent countdown, a morning report and an end-of-day settlement. Most of what PS sets up inside the shop already happens off-screen in a town here.
* **The town already exists in the data.** Characters' `sched` arrays name 19 places: 铺子, 桥头街, 济生堂, 孙府, 孙府厨房, 茶馆, 码头, 客栈, 镇外, 县立中学, 银楼, 田里, 保安队, 赌坊, 维持会, 街上, 商会, 县城路上 and the generic 家. `outside_accounts` adds 8 money accounts that are really businesses: 米行, 济生堂柜, 废品摊, 保安队, 银楼, 维持会公账, 市场, 船行. Six time slots per day (清晨/上午/中午/下午/傍晚/夜) already drive where everyone is. A Stardew-style town can be built straight on top of this.
* **The variable survival pressure already exists, but only one week of it.** It is the 维持费 (100, 120 or 150 depending on your choices), the 铺租 of 30, the 良民证 at 30 per head (rumored to rise to 50), and rice and medicine prices that move with a seeded "wheel". It needs to become a recurring, randomised system.

---

## 1. Setting

| Aspect | Content |
|---|---|
| **Place** | **青溪镇** (Qingxi), a Jiangnan water town near **太湖** on the **青溪河**. The shop faces **桥头街** (Bridge-head Street) and the 桥头茶馆. Landmarks named in the text: the bridge, the notice wall opposite the shop (a new 告示 with a red seal), 码头 (boats to Shanghai), 镇外大路, 赵家坑, the fields east of the river, 孙家田. Off-map places: 县城 (county town with a Japanese 据点 and the requisitioned 教会医院), 上海 (concession newspapers, where 林嫂's husband went), 老家 (the family's home village, the brother's route). |
| **Time** | **民国二十七年 (1938)**, early occupation. Prologue is 二月初四 night (day 0). Day 1 is 二月初五, a Sunday. Day 2 is 二月初六, a Monday. The calendar approximates 30-day lunar months (`world.date_text`). The parents left on **正月十九**, 15 days before the prologue. |
| **Currency / start** | Prices are in **蚨** (a stylised unit). The shop starts with **600 蚨**. |
| **Protagonist** | **沈如花**, 16, daughter of the 沈 family that owns the pawnshop **德厚当**. She grew up around the counter. People call her 如花, 小掌柜, 沈家丫头 or 小沈掌柜. Her grandfather (沈…) signed as 中人 (witness) on 赵老三's land deed, so the family has deep roots in the town. She knows the local land, which is an in-fiction reason for deed appraisal. |
| **Family** | The parents left half a month ago without a word. Their instruction was that if the shop stayed closed two weeks and they had not returned, the children must reopen it. Brother **沈如松** (19) teaches her for two days, then leaves at noon on day 2 to look for them along the route to 老家. He promises a letter from every city he passes, the first due on day 4, each teaching an appraisal skill (first: 吹银元听响). He leaves her father's 小秤, the warehouse key and **father's 小银元** (a keepsake, not for sale). |
| **Shop doctrine** | 爸常说，当铺这行就六个字：**看人，看货，看世道**. Before the war the shop only took pawns (活当). Now people have no hope of redeeming, so it also does 买断 (outright purchase). By the old rule a ticket always records an item's condition as "破旧" so the shop is never liable. 爸从来不这么写 (Dad never did). This is a moral choice on every ticket. |
| **Hidden plot** | **陈叔叔 (陈文庭)** of 济生堂 is an old family friend and a former 邮电局 telegraph operator. He brings a **radio transceiver and codebook** hidden in an old account box (callsign 陈 · 七一三; his knock is three, pause, two) and teaches a **door-flag code** the parents used with him: blue means "safe, come"; white (public meaning "family mourning") means "being watched, stay away"; red (public meaning "a celebration") means "goods here, collect at night". Whom he works for is "a long-term mystery". 王山 knows him: when Ruhua telegraphs "有人 药", the reply is late and says only "收到". The story implies the parents were part of this network. |
| **Chapter hook** | After night 2 someone knocks with **Chen's knock**. No one answers. A blue cloth bundle slides under the door holding pawn ticket **德字第一九六号**, in **father's handwriting**, dated **正月十九** (the day the parents left), with the **当户 field blank**. It is recorded in the notebook and as a foreign ticket. Then the caption 第一章 · 未完. |
| **The occupation layer** | **维持会** (collaborationist committee) appoints **马保长**. Its notice requires **良民证 at 30 蚨 a head** and a weekly **维持费** from every shop. It collects 铺租 (rent), controls medicine ("must be reported"), and wants travel permits to leave town. **保安队** (puppet security corps) press-ganged 赵老三's son and sells him back for 300. **城里的兵** (the Japanese garrison) are never seen: "你只会见到替他们说话的人". |
| **Tone** | Restrained, observational narration. Hidden morality (本心). Consequences arrive late and quietly: a note under the door reading 磺胺是假的。有人死了。; a student's cap on the bridge that nobody picks up; a classmate spitting at the counter. |

---

## 2. Characters

### 2.1 Overview with proposed town buildings

Legend: **Owns** = natural owner or keeper of the building. **Works** = works there. **Visits** = frequent visitor or story location.

| id | Name (label) | Age | Role | Building (proposal) | Relation |
|---|---|---|---|---|---|
| — | 沈如花 (player) | 16 | Pawnshop keeper | **德厚当** (start building, home) | Owns |
| brother | 沈如松 (哥哥) | 19 | Young master, tutor, then gone | 德厚当, then **邮局/邮电局** (his letters arrive there) | Leaves day 2 |
| chen | 陈文庭 (陈叔叔) | 50 | Family friend, secret radio man, 中间人 | **济生堂** (herbal and Western pharmacy); back room = radio | Owns |
| xiaoding | 小丁 | 17 | Cook in the Sun household | **孙府厨房** (works); 小丁家 in a back alley (sick mother) | Works |
| zhang | 张慧娟 (张护士) | 26 | Church-hospital nurse fleeing to Shanghai | **码头 / 客栈** (transient); off-map 教会医院 | Visits |
| wangshan | 王山 (过路的) | 22 | Guerrilla of unstated side; 双面, 黑市 | **镇外** (reed marsh or ruined temple); the shop's **back door at night** | Visits at night |
| li | 李敬之 | 18 | Middle-school student, writes for a secret anti-enemy paper | **县立中学**; propose a hidden **油印/书报摊** press | Works/Visits |
| linsao | 林嫂 | 24 | Boatman's wife, 8 months pregnant | 林家 (home); linked to **船行** (remittances) and **银楼** (gold lock) | Resident |
| zhouma | 周妈 | 45 | Cook at the 桥头茶馆; news hub; 中间人, 口舌 | **桥头茶馆** | Works (de facto hostess) |
| zhao | 赵老三 | 40 | Tenant farmer | **赵家田 / 田里**; son held at **保安队** | Resident |
| sunyoung | 孙富贵 (孙少爷) | 22 | Landlord's only son; 双面 | **赌坊** (his afternoons), 孙府, 茶馆 | Visits |
| ma | 马万利 (马保长) | 38 | 维持会-appointed 保长 | **维持会 / 保公所** (fees, permits, rent) | Owns |
| sunlaoye | 孙德昌 (孙老爷) | 55 | Head of 孙府, chairman of the 商会 (provisional, never at the counter) | **孙府** and **商会** | Owns |
| guanjia | 孙福 (孙府管家) | 52 | Sun steward; keeps the books; 孙府 role | **孙府账房**; propose he runs **孙记米行** (the rice bag says 孙记) | Works |

**Buildings that have no story owner yet.** Each needs a new NPC, or random NPCs from a generator:
* **保安队 / 警察所**: this is the 警察局 the owner asked for. In 1938 it would be the puppet security corps or police post. It holds 赵老三's son, and 李敬之 is taken here if reported. Propose a new 保安队长 who answers to 马保长.
* **银楼** (the "宝成" stamp suggests a 宝成银楼 goldsmith).
* **米行**: Sun-owned, or an independent rice merchant.
* **废品摊 / 纸扎铺** (scrap and paper-effigy shop).
* **船行 / 码头**: boats, remittances, the boat to Shanghai.
* **客栈** (inn).
* **邮局** (letters).
* **市场** (the generic market account).
* **赌坊** owner.

### 2.2 Persona presets (from `cast.json`; mind = GameJev PersonaResidual)

Instincts are ordered [preservation, social, intensity].

| id | MBTI | Ennea | Instincts | Honesty | Compassion | Sociab. | Assert. | Patience | Risk | Impuls. | Emo-react | Top values | Needs / emotions / goals | Cash | Roles |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| brother | ISTJ | 1w9 | .6/.75/.55 | .85 | .75 | .35 | .6 | .75 | .55 | .2 | .3 | loyalty .95, order .85, fairness .80 | – | 20 | – |
| chen | INFJ | 5w6 | .4/.65/.6 | .6 | .65 | .45 | .4 | .85 | .6 | .15 | .25 | loyalty .80, fairness .70, benevolence .70 | – | 300 | 中间人 |
| xiaoding | ISFP | 6w5 | .15/.7/.25 | .7 | .7 | .3 | .15 | .35 | .25 | .35 | .7 | security .85, loyalty .80, benevolence .70 | resources .85, safety .6, fear .45 | 0 | – |
| zhang | ESTJ | 3w2 | .75/.6/.55 | .75 | .6 | .55 | .75 | .4 | .55 | .3 | .4 | autonomy .75, fairness .70, loyalty .70 | resources .7, safety .6, avoid_loss .5, fulfill_duty .6 | 20 | – |
| wangshan | ISTP | 8w9 | .7/.55/.8 | .65 | .55 | .2 | .7 | .55 | .8 | .25 | .3 | loyalty .95, fairness .70, benevolence .60 | – | 200 | 双面, 黑市 |
| li | ENFP | 4w3 | .6/.7/.75 | .7 | .7 | .6 | .6 | .35 | .75 | .6 | .7 | fairness .90, autonomy .85, novelty .80 | – | 5 | – |
| linsao | ESFJ | 2w3 | .35/.8/.25 | .75 | .8 | .75 | .35 | .6 | .25 | .3 | .5 | loyalty .85, security .80, benevolence .80 | resources .6, status .5, hope .6 | 30 | – |
| zhouma | ESFP | 2w3 | .6/.7/.4 | .6 | .7 | **.95** | .6 | .4 | .4 | .6 | .6 | benevolence .70, novelty .70, fairness .60 | – | 80 | 中间人, 口舌 |
| zhao | ISTJ | 8w9 | .6/.6/.35 | .85 | .6 | .2 | .6 | .6 | .35 | .2 | .35 | loyalty .90, fairness .80, security .75 | resources .95, safety .7, fear .4, sadness .5, fulfill_duty .95 | 0 | – |
| sunyoung | ESTP | 3w4 | .8/.3/.75 | .3 | .3 | .7 | .8 | .25 | .75 | .7 | .65 | autonomy .80, achievement .75, novelty .70 | – | 300 | 双面 |
| ma | ENTJ | 8w7 | .85/.15/.5 | .25 | .15 | .7 | .85 | .55 | .5 | .3 | .4 | achievement .80, security .75, order .70 | – | 500 | 维持会 |
| sunlaoye | INTJ | 6w5 | .7/.25/.3 | .45 | .25 | .45 | .7 | .85 | .3 | .15 | .3 | security .95, achievement .70, order .65 | – | 5000 | – |
| guanjia | ISTJ | 6w1 | .6/.5/.4 | .35 | .3 | .5 | .6 | .7 | .3 | .1 | .2 | loyalty .95, order .90, security .75 | – | 300 | 孙府 |

Every NPC also has a `voice_pitch` (used for the typewriter beep), a `color`, a 48×64 portrait (`art/portraits/<id>.png`, all 13 exist), a `look` line, and haggle `lines`: accept_happy, accept, counter, counter_sell, plead, leave.

### 2.3 Social graph (`cast.json` edges, familiarity 0–1; rumors travel only along these)

```
zhouma ─0.7─ linsao ─0.3─ zhao ─0.3─ zhouma
zhouma ─0.5─ xiaoding ─0.35─ sunlaoye
zhouma ─0.6─ ma ─0.5─ sunlaoye ─0.6─ sunyoung ─0.7─ ma
zhouma ─0.45─ sunlaoye ─0.9─ guanjia ─0.4─ zhouma
zhouma ─0.3─ zhang ─0.4─ chen ─0.6─ wangshan
                        chen ─0.3─ li
brother: no edges
```

There are three clusters:
1. **Gossip hub**: 周妈, with 7 edges.
2. **Sun / power cluster**: 孙老爷, 孙福, 孙少爷 and 马保长.
3. **Hidden network**: 陈叔叔, 王山, 李敬之 and 张护士. Its only bridge to the gossip hub is 张护士 through 周妈.

This structure is worth keeping. It makes secrets leak slowly and in a believable way.

### 2.4 Per-character detail (scenes, wants, branches)

#### 沈如松 (brother): "稳重、护妹妹、话不多，爱讲规矩"
* **Look**: short hair, navy changshan, old scar on the left brow.
* **Scenes**:
  * Prologue: candle scene, then a choice of A "你一定要回来" (本心 +1), B "我跟你一起去" (本心 +1) or C silence. He then runs the counter tutorial: pawn box, magnifier on a coin, abacus, ledger, notebook, trash, and the six item categories.
  * Day 1: he stands beside her and whispers hints and suggested prices.
  * `day1_close`: up to 3 conditional verdict lines, in priority order: holding 孙记 rice; the 20 lent to 小丁; the fake sulfa in stock; "你比我想的还细心" if she told the nurse; "（他很久没说话。）……爸要是在，不会这么做。" if she sold the fake knowingly; praise for funding 李敬之; "（他把账簿合上了。）睡吧。" if she reported the student.
  * `d2_morning`: teaches 活当 (30 days at 3% a month), the ticket procedure with a practice 铜手炉, and the 破旧 rule.
  * `d2_farewell`: he hints if any ticket was written 破旧, gives the scale, key and silver dollar, and offers a choice. Option B "带上钱匣里的钱" leads to giving him 0, 50 or 100 蚨 (`flag brother_money`).
* **Later**: letters only. The 读家书 night action is defined for night 4 but not playable. The first letter teaches the silver-dollar ring test.
* **Function**: the moral mirror and the tutorial voice. **Building**: 德厚当, then the **邮局**, where letters and their skill unlocks arrive.

#### 陈文庭 (陈叔叔): "和气、谨慎，说话留半句"
* **Identity**: 济生堂 ("specific job unknown"), the parents' friend of many years.
* **Look**: grey hair, round glasses, dark-brown changshan.
* **Secret**: former 邮电局 telegraph operator. Why he has a radio and whom he serves is the long mystery.
* **Scenes**:
  * Prologue: the back-door knock (three, pause, two). He explains the six factions with the chess pieces, gives the radio and codebook ("白天别碰，夜里关了门再用"), and teaches the blue flag.
  * Night 2, the first telegram: incoming "平安 是否". Reply table:
    * 平安: blue flag tomorrow, chen_trust +2.
    * 维持会 钱: "收到 不要 危险", plus the 怎么对付维持会 advice page, chen_trust +2.
    * 需要 药 (only when no medicine is in stock): "明日 来", and 济生堂 will supply medicine.
    * 有人 药: a long silence, then "收到". Flag `chen_knows_wangshan`.
    * Skip: chen_trust −2.
  * Free telegraph on later nights; each send adds suspicion +1.
* **Unlocks**: medicine ordering ("药品进货需要陈叔叔的信任度"). He learns about the fake hospital medicine via rumor (chen_trust +1).
* **Wants**: the shop to survive, and to keep the network hidden.
* **Building**: **济生堂**. Back-room radio, the medicine supply chain, and the place to verify batch numbers.

#### 小丁: "胆小、老实、说话结巴"
* **Identity**: 孙家的伙夫 (cook).
* **Look**: tall and thin, grey jacket, greasy apron, towel round his neck.
* **Secret**: stole rice from the Sun storehouse because his mother is sick with fever (malaria, so she needs 奈宁).
* **Day 1 schedule**: 孙府厨房, 桥头街, 孙府厨房, 济生堂 (buys herbs off-screen with what he got), then home.
* **`d1_xiaoding`** (buy, 1 bag of `rice_sunji`; ask 50, floor 25; at least 3 inspections):
  * The bag is sewn inside-out. Turning it shows **孙记** (`found_sunji`). The extra action 追问来路 gets a confession; brother: 赃物。收不收，你自己定.
  * Price bands: <30 is low (本心 −3, and the 孙府 scolds him next day); 30–34 is fair; 35–50 is fair (口碑 +2, rumor `fair_shop`); >50 is fair (口碑 +2).
  * Special deals: refuse and urge him to return it (本心 +1), or refuse and **lend 20** (本心 +4, 口碑 +2).
  * After accepting: swap the 孙记 bag for the shop's own bag (suspicion −1), or keep it.
* **Follow-ups**:
  * `n2_backdoor`: if he got the loan, his mother leaves a basket of 籼米 at the back door (本心 +2).
  * `d2_xiaoding_return` (if fair price or loan): repays the loan according to what he actually has, warns that 孙府管家 is asking about the missing rice, and wants 奈宁. Options: sell (favor +4), credit 60 (favor +8), gift (favor +12), refuse (−3).
  * `d2_guanjia`: the player can **betray him** (favor −10).
  * Off-screen: earns 4 a day from the Sun household; his debt decision runs on day 5 or later.
* **Wants**: medicine for his mother; not to be discovered.
* **Building**: 孙府厨房 and 小丁家. He is a natural candidate for a later 伙计 (helper) at 德厚当.

#### 张慧娟 (张护士): "干练、说话快，不轻易示弱"
* **Look**: cap removed, navy qipao under a greyed white coat, carries a basket.
* **Secret**: the hospital was requisitioned and the medicines are her unpaid wages. She wants money to take her younger brother to Shanghai.
* **Day 1 schedule**: 县城路上, 桥头街, 茶馆 ×2, 码头, 客栈.
* **`d1_zhang`** (buy, split per item: 奈宁, 红药水 and fake 磺胺; ask 260, floor 150):
  * Unlocks the medbook.
  * Extras: **tell her the sulfa is fake**. She takes it back, the price drops to 140 (floor 90), 本心 +2, rumor `fake_hospital`. Or **ask about other medicine**, which gets a hint of a box of 吗啡 she dares not sell.
  * Accepting only the real items without telling her: 本心 −1.
  * Outro line: "来买药的人不一定都是病人".
* **Off-screen**: if her cash is ≥120 she decides (mind) to take the morning boat. On day 2 she is seen on a boat with a child.
* **`d2_dawn_news`**: if told about the fake, she sends a note ("医院的事，我会告诉该知道的人") and a bottle of iodine, or nods from the doorway (favor +3).
* **Building**: transient (码头, 客栈). She could return as a county-hospital contact or an 教会诊所 NPC.

#### 王山 (过路的): "少言、站姿笔直、眼神警觉"
* **Look**: old straw cape, leg wraps showing under cloth shoes, bloody bandage on the left hand.
* **Secret**: a guerrilla. The draft deliberately does not say which side. His faction key is "王山那边". Roles: 双面, 黑市.
* **`d1_wangshan`** (the first **sell** session; wants anti-malarial and anti-inflammatory medicine):
  * Observations: leg wraps, bandage, accent. Any of them notes "像是当兵的". Asking where he is from gets "过路的。……你不知道，对你好。"
  * Telling him the sulfa is fake: faction +5, "这一句话，比一盒药值钱".
  * Deals:
    * **IOU**: 40 cash plus a **60 借条 due day 9**.
    * **Gift**: 本心 +3, faction +8, suspicion +1.
    * **Refuse**.
  * Selling the fake knowingly: 本心 **−6**.
* **`n1_backdoor`** (if refused, or no stock): an unfamiliar knock. Options: sell for 40, give one free (本心 +2, faction +8), say none left (−2), or don't open (−4, 本心 −1).
* **`n2_backdoor`**:
  * Sold the fake: a note under the door, **"磺胺是假的。有人死了。"** (本心 −3, faction −10).
  * Holding the IOU: he repays half (30) if he can.
* **Backend**: on day 5 he returns "with two men, face dark" if the fake was sold.
* **Wants**: medicine for the wounded, and discretion.
* **Building**: none in town. He is the **night / outskirts** character (镇外 hideout, back door).

#### 李敬之: "热血、自尊心强、说话带书卷气"
* **Identity**: 县立中学 student.
* **Look**: student uniform, cap pulled low, trousers too short.
* **Secret**: writes for a secret anti-enemy tabloid and wants to be published in Shanghai concession papers ("一篇稿子能换三十蚨").
* **`d1_li`** (buy, by weight: a bundle of newspapers plus a 《辞源》; must weigh and flip):
  * Flipping finds a **《太湖快讯》 mimeographed tabloid**: garrison rotations, roadblocks. Choices:
    * Slip it back to him (本心 +1).
    * Trash it.
    * Hide it in the pawn box (suspicion +2).
    * **Report it to the 维持会** (本心 −8, 维持会 +5, rumor `li_reported`).
  * Price: <18 is low (本心 −2); 18–39 is normal; ≥40 means **funding him** (本心 +3, favor +10; he promises the first newspaper that prints him).
  * The 《辞源》 flyleaf hides a manuscript titled **《春水》** (`found_manuscript`, never used later).
* **Follow-ups**:
  * Funded: day 2 noon he brings the newspaper carrying his article (favor +5, 口碑 +1).
  * Kept the tabloid: he warns that the 维持会 is searching. Burn it (suspicion −1) or keep it (+1).
  * Reported: dawn of day 2, he is marched over the bridge and his cap falls (本心 −2). At noon classmates spit at the counter (口碑 −2). Backend: he disappears on day 4.
* **Building**: **县立中学**. Propose a hidden press or bookstall as an unlockable underground location.

#### 林嫂: "温和、爱笑、有点爱面子"
* **Look**: hair in a bun, plain jacket, hand on her back, 8 months pregnant.
* **Secret**: her husband has run boats out of Shanghai for three months and sent no money.
* **`d2_linsao`** (the first **pawn**: a gold hairpin, ask 150, floor 100):
  * The money is the half deposit at the 银楼 for a baby's **金锁** ("锁住命").
  * Price bands: ≥160 is fair (口碑 +3, 本心 +1); 131–159 is fair; 100–130 is low (本心 −2); refusing or walking out costs 口碑 −2.
  * Writing 破旧 on the ticket sets `lin_ticket_old`, and the brother remarks on it.
  * Ticket due **day 32**. She promises red eggs at the baby's first month.
* **Off-screen**: pays the 银楼 100 on day 2. Each day there is a 12% chance of a 150 remittance via the 船行.
* **Building**: her home. Linked to the **船行** (husband) and the **银楼**. She is the model **live-pawn / redemption** storyline.

#### 周妈: "嘴碎、热心、爱打听"
* **Identity**: cook at the 桥头茶馆. Secret: she is the town's news centre. Roles: 中间人, 口舌.
* **`d2_zhouma`** (sell, rice):
  * If she sees a 孙记 bag: "孙家也往当铺里卖米了？", which triggers rumor `sunji_rice`, which brings 孙福 to the shop.
  * Selling to her below 55, or giving rice: favor +5 and `zhouma_news`. From then on she brings one piece of town news every morning, with hop and confidence tags.
  * Outro: the 良民证 / 维持费 notice, then rumor sharing.
* **Building**: **桥头茶馆**. The obvious town hub for rumor, news and quests.

#### 赵老三: "沉默、硬气"
* **Identity**: tenant farmer.
* **Look**: dark and thin, patched jacket, pipe at his waist.
* **Secret**: his son was press-ganged by the 保安队 and is ransomed at 300.
* **`d2_zhao`** (pawn: a **red deed** for 1.2 mu of paddy, ask 300 with a **hard floor**, true value 1500–2500):
  * Inspection shows the bounds: east is the Sun fields, west is the 青溪河. The **witness signatures include 沈… — Ruhua's grandfather**.
  * Price bands: 300–399 is the base; ≥400 is "generous" (本心 +3, 口碑 +3); refuse gives 本心 −2; walking out gives 本心 −3.
  * Post note: if he cannot redeem, **孙府 will come to buy the deed from Ruhua**.
* **Off-screen**: if he has no money by noon, his mind decides to **sell the land to 孙府 for 400** (rumor `zhao_sold_land`). With 300 he pays the 保安队 and the son comes home limping (seen on the bridge).
* **Building**: farmland. A main reason to visit the **保安队**.

#### 孙富贵 (孙少爷): "体面"
* **Identity**: only son of the Sun landlord.
* **Look**: slicked hair, Western suit, long scarf, a gold pocket watch he keeps opening and shutting.
* **Secret**: "理由不详，这里是伏笔". Rumor variants suggest debts.
* **Schedule**: 孙府, 茶馆, 赌坊. On day 2 at dusk he goes to the **维持会**.
* **`d2_sunyoung`** (pawn: a **forged deed** for "30 mu", ask 3000):
  * It has five tells: owner not him and no proxy letter, east and west bounds reversed (compare 赵老三's deed), bright new seal ink, no 契尾, new paper stained with tea.
  * With 2 or more tells found she can **expose** him. He then slaps down the **real deed** (`d2_sunyoung_real`, ask 1500, floor 600, value about 9000).
  * Other options: decline ("本钱不够"), bluff ("回去叫你爸来签字", he threatens her), or accept, which means **being scammed** (he takes whatever cash she has, minimum 100).
* **Off-screen**: if exposed, his mind decides to complain to 马保长, which raises the fee to 150 and earns "年轻人，眼睛别太尖".
* **Night option** 派人给孙老爷捎话: 孙府 +5, 孙老爷 favor +5, 孙少爷 −20, rumor `sun_fake_deed`.
* **Building**: **赌坊**, which explains his need for cash; 孙府.

#### 马万利 (马保长): "笑里藏刀、善于记仇"
* **Look**: bowler hat, little moustache, white armband on the left arm, ledger inside his coat.
* **`d2_ma`**:
  * The **维持费** depends on prior choices: 100 if she reported the student, 150 if 孙少爷 complained, otherwise 120. Due **Saturday (day 7)** as a countdown.
  * If medicine is in stock ("药是管制的东西，收了要报备"): hand one over (suspicion −2, fee −20) or claim it is sold (+1).
  * Responses:
    * Acknowledge.
    * Pay half (60) now (suspicion −1).
    * Give a "见面礼" item (suspicion −2, fee −20).
    * Haggle: with 口碑 ≥60 the fee drops to 100; otherwise he sneers and suspicion +1.
  * He asks where her brother went and says leaving town needs a **通行证**.
* **Also**: the opening liability of **铺租 30 to 保长, due day 7**. He receives reported tabloids.
* **Building**: **维持会 / 保公所**: fees, permits, 良民证, reports. Pairs with the **保安队** as the "police" side.

#### 孙德昌 (孙老爷)
* "精明、沉稳、不轻易露面" (provisional; the README says the character sheet was added in this version).
* Off-screen only. Holds 5000 cash. His plan, implied, is to protect the family estate and buy land cheap. He buys 赵老三's land.
* Reacts to rumors: hearing `sunji_rice` makes him send the steward.
* **Building**: **孙府** and the **商会**. A late-unlock "gentry" building.

#### 孙福 (孙府管家): "圆滑、客气里带刺、记账精"
* **Look**: grey changshan, skullcap, counts prayer beads that look like abacus beads.
* **Secret**: watches every transaction in town for the master.
* **`d2_guanjia`** (triggered if the rice rumor spread, or 孙记 rice is still in stock unswapped):
  * Offers to **buy the rice back for 20** (sell session, max 30).
  * Return it free (孙府 +5), bribe him with 10 (+1), or **insist it is the shop's own rice** (−5, 口碑 −1).
  * If the rice was already sold on: **name 小丁** (孙府 +3, 小丁 −10) or say "don't know" (−3, suspicion +1).
  * Outro: "老爷说了，镇上每一笔进出，他都记着".
* **Building**: 孙府账房. Proposed manager of **孙记米行**.

### 2.5 Off-stage people mentioned (generator material)

* 爸 and 妈 (missing).
* Grandfather 沈… (witness on the deed).
* 小丁娘 (sick).
* 张护士's younger brother.
* 林嫂's husband (boatman in Shanghai).
* 赵家儿子 (press-ganged, returns lame).
* 李敬之's classmates.
* 跑腿的孩子 (errand boy for messages).
* 挑担的 and 卖菜的 (morning news sources).
* 西医生 (fled the hospital).
* 保安队, 银楼 宝成, 米行, 船行, 纸扎铺, 报馆 (Shanghai).

---

## 3. Items

### 3.1 Item schema (`data/items/*.json`)

**Item fields:**
* `name`, `cat`, `cat_cn`, `sprite`
* `market`: true value. `claimed`: what a fake pretends to be worth.
* `fake`, `grade` (甲乙丙丁), `origin` (normal, stolen or contraband), `contraband`
* `est` [lo, hi]: the vague estimate before inspection.
* `suggest`, `ask_w`, `weight`, `tags` (e.g. 孙记, 爸的遗物)
* `ticket_condition`: the honest 成色 line for a pawn ticket.

**`parts[]`**, one per inspectable part:
* `id`, `label`, `text`, `rect`
* `tool`: hand, magnifier, nose, book (medbook) or scale
* `est`: narrows the estimate
* `flag`: knowledge flag
* `event`: story event
* `tell: true`: evidence that the item is fake or bad
* `highlight_if` / `highlight_note`: cross-reference memory, e.g. remembering 赵老三's deed bounds

**Economy rules:**
* `market_now = market × rice_mod / med_mod × (1 + tidy_bonus + market_bonus)`.
* The brother's buy suggestion is **60% of market_now**.
* Night sell goes to 米行, 济生堂 or 废品摊 at **70–85%**. Orders arrive at **80%**.
* Pawn: **30 days at 3% a month**, +5 days grace, then 满当 (the item becomes the shop's).
* Haggling allows at most **5 rounds**.

The brother's six categories ("前三样能买断，金银和纸契走活当，破烂按斤称"):
1. 米粮精油 (food and oil): **rice only implemented**.
2. 药 (medicine).
3. 洋货 (foreign goods): **none implemented**.
4. 金银首饰: one hairpin.
5. 地契房契: three deeds.
6. 破烂 (scrap): three paper items.

Pawn rate table (`pages.pawn_rates`): 金银 80%, 玉器古玩字画 50%, 丝绸 60%, 被帐 50%, 衣服 30%, 红契 30%, 白契 15%. The jade, silk, bedding, clothes and white-deed classes have **no items yet**, so they are ready for a generator.

### 3.2 Rice (`rice.json`)

Base price per small bag: 粳 90, 籼 70, 糯 80. Grade multiplier: 甲 ×100%, 乙 ×75%, 丙 ×50%, 丁 ×15% (丁 is pig feed or for brewing). Inspection order: grain shape (variety), light and colour (new or old), magnifier for broken grains and impurities, smell (mould means 丁), and the bag markings (origin).

| id | Name | Market | Grade | Origin | Note |
|---|---|---|---|---|---|
| rice_sunji | 粳米 (30-odd 斤) | 68 | 乙 | **stolen**, tag 孙记 | Bag sewn inside-out; inner print 孙记 sets `found_sunji` |
| rice_jing_a | 粳米甲 | 90 | 甲 | normal | Reference good rice |
| rice_xian_b | 籼米乙 | 52 | 乙 | normal | Also the gift from 小丁's mother |
| rice_nuo_c | 糯米丙 | 40 | 丙 | normal | Yellowed old rice (tell) |
| rice_mold_d | 粳米丁 (mouldy) | 13 | 丁 | normal | Green-grey spots, insects, sand, mould smell. **Unused in any session.** |

### 3.3 Medicine (`medicine.json` + `medbook.json`)

**Batch rule**: `厂码 年·月 序号`, e.g. HC 26·11 0482 means 海昌药厂, 民国26年11月, batch 0482. A genuine item must pass all of these:
1. The maker code matches the label.
2. The date is before today (民国27年2月) and within shelf life.
3. The serial is 4 digits and not on the known-fake list: **HC 26·09 0311, RH 25·12 1180, DT 26·08 0007**.

| id | Name | Maker / code | Market | Contraband | Batch on item | Genuine features | Fake features (medbook) | Shelf life / risk |
|---|---|---|---|---|---|---|---|---|
| quinine | 奈宁片 (金鸡纳霜, malaria) | 海昌 HC | 100 | yes | HC 26·10 0517 | Blue label with white text; foil seal stamped 海昌; pure white pill marked Q, very bitter | Re-glued seal; grey, non-bitter flour pills | 3 yrs; medium (guerrillas need it) |
| aspirin | 阿司匹林 | 瑞和洋行 RH | 40 | no | RH 26·07 2046 | Red-and-white striped label, wax seal, cross-scored pill | Blurry pinkish label | 2 yrs; low |
| iodine | 碘酒 | 华美药房 HM | 15 | no | HM 26·11 1508 | Brown bottle, waxed cork, dark liquid, sharp smell | Red tea, no smell | 1 yr; low |
| mercuro | 红药水 (two bottles) | 华美 HM | 24 | no | HM 26·12 2203 | Green bottle, deep red liquid that clings to the glass | Diluted, pale | 1 yr; low |
| sulfa | 磺胺粉 | 德泰洋行 DT | 180 | yes | DT 26·09 1134 | Tin with embossed logo, faintly yellow powder | — | 3 yrs; **high** (most needed, most controlled) |
| **sulfa_fake** | 磺胺粉 (fake) | "DT" | 0 (claims 180) | yes | **DT 26·08 0007** (on fake list) | — | No embossing, pure white odourless talc (3 tells) | Brought by 张护士 |
| morphine | 吗啡针剂 | 教会医院专用 | 300 | yes (origin contraband) | — | "教会医院专用，不对外销售"; ampoules | — | **Extreme**: controlled, may bring disaster. Only hinted. |

Only the sulfa fake exists as an item. The medbook already describes fakes for quinine, aspirin, iodine and mercurochrome, which is ready-made **procedural fake** content. Aspirin, real sulfa and morphine appear in no session.

### 3.4 Deeds (`deed.json`, `pages.deed_rules`)

Rules: a 红契 is taxed with an official seal and a 契尾 attached (30% loan rate). A 白契 is a private contract (15%). Check five things: owner name against the person pawning, the 四至 (bounds, which Ruhua knows locally), seal ink and 契尾, the 中人 signatures, and the paper (new paper aged with tea, or seal ink too fresh).

| id | Name | Market | Fake | Key parts |
|---|---|---|---|---|
| deed_zhao | 红契 水田一亩二分 | 2000 (est 1500–2500; pawn suggestion 600) | no | Owner 赵德福 with note "传长子赵老三"; bounds E 孙家田 / **W 青溪河** / S 镇外大路 / N 赵家坑 (`saw_zhao_bounds`); dark-red seal with full 契尾; **witness 沈… (grandfather)**; old brittle paper |
| deed_fake | 地契 孙家三十亩 | 0 (claims 10000) | yes | 5 tells: owner 孙德昌 with no proxy letter; "**东**至青溪河" (wrong side, highlighted if you saw 赵老三's deed); bright shiny seal ink; 契尾 missing; new paper with tea stain |
| deed_sun_real | 红契 孙家三十亩 | 9000 (est 4000–9000) | no | Owner 孙德昌, "孙家长房"; correct bounds; dark-red seal with full 契尾; witnesses are known local families |

### 3.5 Gold (`gold.json`, `pages.gold_rules`)

* **hairpin** 金簪 with a small pearl. Market 200, weight 三钱二分, stamp **宝成足金**. Deep-yellow colour, soft enough to dent with a fingernail (足金). Freshwater pearl with a chip. Ticket: "足金，珠有小缺".
* Rules: check stamps (宝成足纹, 老凤祥足金, both fictional). Full gold is deep yellow and soft; 包金 (gold plate) shows the base metal where worn. Full silver tarnishes dark but scrapes bright white; 白铜 (cupronickel) looks greenish. Value = weight × fineness price. Wear and workmanship decide the condition line.

### 3.6 Scrap and paper (`scrap.json`, `pages.scrap_rules`)

* Rules: waste paper sells for 1 蚨 a 斤 (paper-effigy shops, kindling). Useful old books (dictionaries, textbooks, medical books) fetch 5–30 each. Banned papers have no price: hide them, burn them, or give them to a faction. **Inserts** (letters, photos, banknotes) trigger story.
* **newspapers**: one bundle of 12 斤, market 12, est 3–8. Flipping it is required and reveals the tabloid.
* **ciyuan**: 《辞源》, market 30. The flyleaf holds the manuscript 《春水》.
* **tabloid**: 油印小报《太湖快讯》 ×3. Category contraband_paper, market 0. Garrison rotations and roadblocks.

### 3.7 Practice items and keepsakes (`practice.json`)

* **coin**: 当十铜元 from the 光绪 era, market 1. Prologue magnifier practice.
* **handwarmer**: 铜手炉, market 40, ticket line "铜，盖有磨损". Ticket practice on day 2.
* **silver_keepsake**: 爸的小银元, cat keepsake, market 30, tag 爸的遗物. Its "吹一吹听响" part is locked until the first letter. **This is the seed for the owner's item #13** (heirlooms from the parents).

---

## 4. Factions and hidden variables

### 4.1 Six factions (`factions.json`, the 陈叔叔 chess scene)

| Piece | Key | Chen's line | Wants |
|---|---|---|---|
| 黑子 | 城里的兵 (Japanese garrison) | 你不会见到他们。你只会见到替他们说话的人。 | Grain, medicine, copper and iron, intelligence |
| 白子 | 维持会 | 要钱，也要消息。给钱可以，给消息要小心。 | Protection fees, goods of unclear origin, informants |
| 青子 | 湖上的人 (太湖; Shanghai accent, rich; implied loyalist or KMT-linked) | 出手大方 | Intelligence, gold and silver, medicine |
| 红子 | 山里的人 (implied Communist guerrillas) | 穿得破，开借条。借条能不能兑现，要看以后。 | Medicine, paper and ink, salt, batteries |
| 黄子 | 孙府 | 孙家不站在任何一边，只站在孙家那边。 | Protect the estate, buy land cheap |
| 灰子 | 水路上的 (lake bandits, gangs) | 他们的东西，一样都别收。 | Fencing stolen goods, protection money |

Plus **王山那边**, an extra faction key, deliberately unassigned. Chen's closing line: "这六家，你得罪哪一家都不好过。可一家都不得罪，也做不到。"

* **Door flags**: 不挂, 蓝 (unlocked in the prologue), 白 and 红 (unlocked by telegram). Each has a public meaning and a secret one.
* **Signs (招牌)**: 收米粮, 收旧书报, 金银首饰. **Neither flags nor signs affect who visits yet.**
* **Codebook**: 20 words with 4-digit codes: 平安 有人 来 药 米 钱 明日 今夜 危险 维持会 哥 信 收到 需要 不要 门旗 蓝 白 红 是否. Plus **locked words 山 and 湖** (unlocked by story), which point to future contact with the mountain and lake factions.

### 4.2 Hidden and visible state (`world.gd`)

| Variable | Range / start | Visible? | Moved by (examples) |
|---|---|---|---|
| **口碑 koubei** | 0–100, starts 50 | **Visible** (changes are logged in the notebook as 推测) | Fair prices +2 or +3; funding 李敬之's paper +1; reporting the student −2 or −3; refusing 林嫂 −2; 破旧 ticket discovered at redemption −3; ≥60 lets you haggle Ma down |
| **本心 benxin** (conscience) | 0–100, starts 50 | Hidden | Lending to 小丁 +4; gifts +2 or +3; lowballing −2 or −3; selling a fake knowingly −6; reporting the student −8; "有人死了" −3. Below 40 unlocks the 写日记 night action (+2) |
| **怀疑 suspicion** (维持会) | 0–10, starts 0 | Hidden. At ≥5 a shadow appears outside the door | Each telegram +1; hiding the tabloid +2; selling or giving medicine at night +1; contraband found in the trash +2 (35% chance per night); appeasing Ma −1 or −2; swapping the rice bag −1 |
| **chen_trust** | −20 to 20 | Hidden | Telegram replies ±2; fake-medicine rumor +1. Gates medicine orders |
| **faction_trust[k]** | −20 to 20 for each faction plus 王山那边 | Hidden | e.g. 王山那边: +4 to +8 for help, −10 for the fake; 孙府 ±1 to ±5; 维持会 +5 for reporting |
| **favor:npc** | Maps onto relationship dimensions trust, affection, respect, fear, resentment, indebtedness, familiarity, dependence | Shown in the contacts panel only as 亲近 / 一般 / 冷淡 (≥8 / ≤−5) | Gifts and help +; betrayal − |
| NPC emotions / needs / goals | fear, sadness, hope, joy, anger…; resources, safety, status; fulfill_duty… | Hidden | Patrols add fear; favor events add joy or anger |
| **rumors** | 12 keys, 3 distortion levels each | Learned via notebook and NPC talk | Spread along edges with p = edge × sociability × confidence × 0.7; delayed one slot; at most 3 hops; confidence ×0.75 per hop |
| **risks** | e.g. `ticket_old` | Hidden | Fires 口碑 −3 when the 当户 redeems |
| **liabilities / todos** | 铺租 30 (day 7); 维持费 100/120/150 (day 7) | Visible (countdown) | **Never actually settled or enforced** (see repo_core.md) |
| World wheel | weather; patrol (4-slot cooldown); rice_mod 0.85–1.30; med_mod 0.85–1.40 | Price board visible | Rice boat arrived or blocked; city requisitioning medicine or smuggled supply from Shanghai; news via 挑担的 / 卖菜的 |
| Night ticks | quiet, boots, truck, dog | Notebook | One roll per lamp of oil used |
| Notebook | Each entry is tagged 亲眼 / 听说 / 推测, with source and confidence | Visible | Information boundary (GameJev P05) |

**Rumor keys and how they distort**: each key goes from the true version to the most distorted.

* sunji_rice: 德厚当卖的米，袋子上印着“孙记” → 孙家的米跑到当铺里去了 → 孙家库里的米让人偷出去当了.
* xiaoding_herbs.
* zhang_gone: 张护士带着弟弟坐早船走了 → … → 医院里的人都在往外跑.
* zhao_son_free: … → 保安队收钱放人.
* zhao_sold_land: … → 孙家趁乱收地.
* sun_exposed: … → 德厚当跟孙家结了梁子.
* li_reported: … → 德厚当靠不住.
* fair_shop: … → 德厚当好说话.
* liangmin_notice: … → 良民证的钱怕是要涨到五十蚨了.
* hospital_requisition.
* sun_fake_deed: … → 孙家要败了.
* fake_hospital.

Consequences fire only when the rumor reaches a particular person:
* 孙老爷 hears sunji_rice → sends the steward.
* 马保长 hears sun_exposed → resentment, fee 150.
* 周妈 or 林嫂 hear fair_shop → 口碑 +1.
* 周妈 hears li_reported → 口碑 −3.
* 陈叔叔 hears fake_hospital → chen_trust +1.
* 小丁 hears sunji_rice → fear.

**Key story flags**, which are useful to keep as save hooks:
* Rice and 小丁: `xiaoding_rice` (fair, low or refused), `xiaoding_loan`, `rice_bag_swapped`, `found_sunji`, `found_stolen_rice`.
* Medicine and 王山: `found_fake_sulfa`, `zhang_told`, `zhang_left`, `fake_sulfa_in_stock`, `wangshan` (sold, gift, refused, nostock), `wangshan_iou`, `sold_fake_to_wangshan`.
* 李敬之: `li_paper` (returned, burned, kept, reported, unseen), `li_fund`.
* Pawns and deeds: `lin_pawn`, `lin_ticket_old`, `zhao_pawn`, `zhao_sold_land`, `zhao_son_free`.
* 孙府 and 马保长: `sun_young` (exposed, declined, bluffed, scammed), `sun_real_pawn`, `guanjia_visit`, `sun_rice_rumor`, `ma_heard_sun`.
* Family and ending: `brother_money`, `ticket196`.

**Night actions** (`night.json`; 3 lamps of oil):
* 对账 (review accounts).
* 整理库房 (+5% value to one item, kept permanently).
* 烧垃圾 (burn the trash).
* 夜卖 (sell at night, 70–85%).
* 定货 (order stock, 80%; medicine needs Chen's trust).
* 换门旗/招牌 (change flag or sign).
* 发电报 (send a telegram).
* 读家书 (read a letter; night 4, not playable).
* 派人给孙老爷捎话 (send word to 孙老爷).
* 写日记 (write a diary; 本心 <40).
* 吹灯睡觉 (sleep).

Night 1 allows only 2 starred actions.

---

## 5. What to keep and what to change

### 5.1 Strong hooks to KEEP (they are what make this game itself and not Probably Stolen)

1. **The missing parents and 德字第一九六号.** A ticket in father's hand, dated the day they left, with the 当户 blank, delivered with Chen's knock while Chen does not answer. In a town this becomes an **investigation spine**: who holds the stub, what was pawned, why it was pawned, and who knocked. Each answer can sit in a different building (邮局 letters, 济生堂 radio, 维持会 permits and records, 码头 and 船行 departures).
2. **The radio, codebook and door flags.** These are unique mechanics, and they map naturally onto a town. The flag is **visible on the shop front in the overworld**, so NPCs passing by react to it. Telegrams raise suspicion, which the 保安队 / police can "detect". The locked words 山 and 湖 are ready progression.
3. **Moral dilemmas whose consequences arrive later through the world:**
   * 孙记 stolen rice: 小丁, 周妈, the rumor, then the steward visits, with the option to betray 小丁.
   * Fake 磺胺: tell 张护士, sell it to 王山, then "有人死了".
   * The 李敬之 tabloid: four outcomes, from his article printed to his arrest on the bridge.
   * 赵老三's deed: ransom, then the 孙府 land grab, with the grandfather's witness signature.
   * 孙少爷's forged deed: expose him and the real deed comes out, or he complains to Ma.
   * The 破旧 ticket rule.
   * 林嫂's gold lock and her husband's remittance (a 32-day pawn arc).
   * Paying, negotiating or bribing 马保长.
4. **The 3-cluster social graph with rumor distortion** and seen / heard / inferred source tags. This is far richer than PS and is the GameJev pillar the owner designed.
5. **Schedules and off-screen lives.** Characters already move between named places every slot, and make their own decisions: 张护士 leaves, 赵老三 sells his land, 孙少爷 goes to complain. This **is** Stardew NPC routing.
6. **A ledger where money only moves between accounts**, and **IOUs where ability to pay is separate from willingness** (小丁 repays what he has; 王山 "过些日子"). The outside accounts (米行, 银楼, 船行…) become real shops.
7. **The brother's letters as skill unlocks.** The silver-dollar ring test, then more, is progression without a skill tree.
8. **Authentic appraisal knowledge.** Rice grades, medicine batch numbers with a fake list, deed bounds, seals, 契尾 and witnesses, gold stamps and fineness, weighing scrap and flipping for inserts. Keep it as content. Change where and how it is used (see 5.2).
9. **Six-faction chess intro.** It can become the **town map legend** or the faction-reputation screen.
10. **Character voices.** Stammering 小丁, terse 王山, 周妈's chatter, 马保长's "账本我先记着", 孙福's "账是跑不掉的".

### 5.2 What reads as Probably Stolen and should CHANGE

| Current element | Why it feels like PS | Town-version direction |
|---|---|---|
| **One fixed first-person counter** (`layout.json`, 320×180) is the whole game | PS is a single shop screen in which "客人一个一个从栈里出来" | Overworld town. The counter becomes one *interior* among many. Some deals happen in other buildings: buying rice at the 米行, selling medicine to 济生堂, testing gold at the 银楼 |
| **Linear queue of `session`s per slot** (day1/day2 lists of 4–7 customers) | PS's daily customer stack with one intent per customer | NPCs walk their schedules. Some come in, some you meet in the street or the teahouse. Randomised visitors come from a generator driven by flag and sign, 口碑, the world wheel and faction needs |
| **Magnifier minigame + "tell" judgement** | PS 放大镜细看 + 对质 真/假 | Keep the content, spread the method around town: check a batch number at 济生堂, compare deed records at the 维持会 or 商会, ask 周妈 who owns a bag. The owner's docx items #5 (manual appraisal, certificates) and #11 (mystery box) fit here |
| **Haggle rounds with patience and walk-away**; single-item purchase; separate buy and sell modifiers; budget gate (explicitly absorbed in `V03_BRIEF.md`) | Copied from PS 议价 and 交易卡 | Keep the persona-driven reactions. Fold haggling into relationship talk (favors, IOUs, barter, "sell new things to extend" per docx #10) rather than a number duel at a counter |
| **Rent countdown** + **morning report / calendar furniture** + **end-of-day settlement** | PS 晨报 / 租金倒计时 / 日终 | Survival pressure becomes **variable and town-driven**: rice-price-linked food costs, the 维持费 recalculated weekly from suspicion and 口碑, surprise levies (良民证 30 to 50), requisitions, the brother's travel money, 林嫂's redemption, bribes. Paid **in person at buildings** (保公所, 米行) |
| **Contraband / stolen flags + suspicion + "inspector"** | PS 违禁/赃物 heat + 检查官 | Make the **police station (保安队)** and **维持会** real places with their own schedules and searches, an informant network (周妈 is 口舌), and patrols seen in the street |
| **Only buying, never selling freely** (owner issue #7) | — | Town shops buy from you (米行, 济生堂, 银楼, 废品摊, 纸扎铺, 报馆 via 李敬之), and NPCs come to buy |
| Night "lamp oil" action menu | Not PS, but menu-like | Nights become walkable: the back door, the 镇外 meeting with 王山, the radio in the back room, burning things in the stove |

### 5.3 Dangling hooks already in the data (cheap content for days 3 and later)

* Day 4: the first letter (silver-dollar test). 李敬之 disappears if reported.
* Day 5: 王山 returns with two men (fake sold). 小丁 decides about his debt.
* Day 7 (Saturday): 维持费 and 铺租 due.
* Day 9: 王山's IOU due.
* Day 32: 林嫂's ticket expires. Her husband's remittance is random.
* After that: 孙府 wants to buy 赵老三's deed if it goes unredeemed.
* Never followed up: 《春水》 manuscript, 张护士's morphine hint, the 孙少爷 debt "伏笔", the 吗啡 / 阿司匹林 / real 磺胺 / mouldy rice items, the white and red flags, the 山 and 湖 code words, the 招牌 signs, guarantees (FIN06, coded but unused).

### 5.4 Owner's docx list mapped to story assets

| Owner item | Story assets to reuse |
|---|---|
| #8 Starting pawn items and bills | 铺租 30, 维持费, starting cash 600, the 196 ticket, the keepsake |
| #10 Live pawn with extension | 林嫂 (32 days, remittance), 赵老三 (redeem after the autumn harvest) |
| #13 Heirloom late game | 爸的小银元 and the 196 ticket |
| #17 Relationship visualisation and telegram notices | Edges, favor and the codebook |
| #18 Double agent / middleman / spy | `roles`: 王山 双面·黑市, 孙少爷 双面, 陈叔叔 and 周妈 中间人, 周妈 口舌, 马保长 维持会, 孙福 孙府 |
| #9 Choose to keep the pawnshop or change profession | Each town building a story NPC runs is a potential alternative trade: pharmacy (陈), teahouse (周妈), rice shop (孙福) |

---

## 6. Playtest feedback themes (`docs/playtest/`)

**R2 (first human player, prologue plus 小丁)**: no crashes. Issues by severity:
* **Interaction did not match the tutorial wording**: the tutorial said "push into the box", but the action was click the item, then click the box. Not a drag.
* **Fast clicks skipped lines**, so tutorial text was missed.
* **The inspect panel was clipped** and needed scrolling.
* **The right panel was crowded**: 待办 (to-do list) truncated, panels overlapping.
* **The 小丁 floor price was shown**, which killed the haggle suspense.
* Medium: low-contrast name tags; faint hotspots; chess pieces nearly invisible; odd choice menus with blank rows; continuity (brother still visible after going to open the door); repeated stage directions; stale customer info left on the side panel.
* Minor: tooltip ghosting, tiny HUD text, the rice bag flickering after a deal.

**R3 (v0.2 GUI retest)**: no hard soft-lock. Click, space, enter, Esc and skip all advance dialogue, but Esc cannot pick a choice. Haggling has clean exits (5-round cap). The tidy bonus persists. New branches are visible. The title still said v0.1. The "看完了" button is placed badly.

**Self-checklist and M5 recheck**: 9 fixed, 4 partial, 1 open, 3 unverified. Decisions: real customers **never show floor price or the inner estimate**; the brother whispers only a suggestion. Hidden values stay hidden. "World is moving" is shown via the price board and street news. Sound was **never actually heard** (no audio device).

**Themes:**
1. **Too much on one screen.** The single-counter UI is overloaded: HUD, to-dos, hints, tools and side panels. The owner's own list (#1 side dialogue, #3 delete to-dos and hints, #4 glow-then-fade hints) attacks the same problem. **A town layout spreads these functions across places**, which addresses the cause.
2. **Discoverability and tutorial wording versus the real interaction.**
3. **Dialogue pacing and readability** (typewriter, skipping, name contrast).
4. **Suspense versus information** (floor-price leak). Designers repeatedly chose hidden numbers.
5. **Thin real-human testing.** Only one human playtest (R2), covering the prologue and first customer. Nobody has evaluated whether the loop is *fun*, and the PS-clone concern is the owner's own verdict after playing.
6. Branch content was verified mostly by automated plans (22 branch plans, 5 strategies), so the **story logic is well tested and safe to port**.
