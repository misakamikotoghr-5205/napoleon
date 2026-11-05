# Web research: reference games and techniques for the 德厚当 town redesign

Date: 2026-10-11. **Method:** the sandbox egress policy blocked WebFetch and curl for every wiki, Wikipedia and Godot-docs host I tried (stardewvalleywiki.com, fandom, en.wikipedia.org, docs.godotengine.org, pinyin.info). All facts below therefore come from WebSearch result excerpts, which I cross-checked against my own background knowledge where I could. Numbers marked **[verify]** come from one community source or from memory and should be checked before they go into balance data. URLs are the pages the search engine quoted.

The repo constraints come from `understand/gamejev_design.md`. The design recommendations here respect them:
- psychology, probabilities and affection stay hidden;
- life pressure comes from food, rest, 周转 and 人情, not escalating rent;
- dead pawns stock the shelf;
- the live-pawn gamble stays;
- the four institutions (法庭/警局/军队/官场) are in;
- the exogenous/endogenous world wheel is seeded with `draw(seed, domain, key)`.

---

## 0. Key takeaways

1. **Stardew's town runs on three layers, and we should copy all three.**
   - (a) A **fixed calendar spine**: festivals, birthdays, and dated openings such as the Mines opening on Spring 5 and the Railroad on Summer 3.
   - (b) **Schedules**: shops have hours and days off, and NPC routes vary by weekday, weather and heart level.
   - (c) A **player-driven restoration arc**: the Community Center. Each finished room physically repairs part of the map, for example the bridge, greenhouse, minecarts or bus.
   - We copy the structure, not the farming.
2. **What separates us from Probably Stolen is the time-delayed contract.** That means the 当票 with its 当期, 月息, 续当, 赎当 and 满当, plus **selling dead pawns elsewhere in town**. Probably Stolen is a one-room queue of flips. Our town should exist to make contracts play out over weeks among people who have lives.
3. **Variable survival pressure should combine three models:**
   - the **Papers, Please line-item bill**: mandatory rent, plus skippable food and heat whose consequences arrive after a delay;
   - **Pathologic 2 drifting essentials**: food gets dearer and scarcer as the world worsens;
   - **Cart Life / 大多数 personal-life costs**.
   - Telegraph pressure through public price boards, rumours and letters. Let it carry over through 赊账 credit and arrears.
4. **The randomness toolkit is already well understood:**
   - storylets (prerequisites over quality ranges lead to effects);
   - weighted decks with cooldowns and a mandatory quiet card;
   - storyteller pacing in the Cassandra style (on/off cycles), Randy (pure random with a 13-day guarantee) or Phoebe (long gaps);
   - streak control with pseudo-random distribution or shuffle bags;
   - **one RNG stream per subsystem** (the Slay the Spire 2 correlation fix).
   - GameJev's `draw(seed, domain, key)` already matches the best practice.
5. **Fixed spine plus random flesh is a proven pattern.** Frostpunk 2 hard-codes its early temperature sequence (drop, rise, drop, drop, rise) and randomises it only after that. Stardew posts its Traveling Cart on fixed days with random stock, and its Help Wanted quests at a fixed place with random content.
6. **Recommended visual approach:** 2D top-down 3/4 view with 16 px tiles and 16×32 characters, rendered at 320×180 and scaled ×4. This is exactly the existing pipeline. Fake depth with Y-sort, drop shadows, roofs that fade out, CanvasModulate plus PointLight2D, and optionally normal maps generated in Python. **Do not build HD-2D with Sprite3D now.** The reasons are in §5.
7. **Dialogue:** in the town, use speech bubbles anchored beside each speaker (owner item #1). At the counter close-up, use a portrait with a bubble. Typewriter "blips" get a per-speaker pitch plus small random jitter (owner item #2).
8. **Show relationships without numbers.** Stardew uses hearts, but GameJev forbids a visible affection meter. Show relationships diegetically instead:
   - a **人情簿** (gift ledger, which is historically real);
   - letters and telegrams;
   - forms of address, greetings and invitations;
   - what a person brings to pawn.
9. **History in one paragraph:**
   - The pawnshop counter was "twice my height" (Lu Xun).
   - 朝奉 was the appraiser title, tied to the Huizhou merchants who dominated southern pawnbroking.
   - Monthly interest was about 3分 (3%), plus fees.
   - Loans were about 60–80% of the item's value.
   - A Qing ticket ran 16 months. Unlicensed 小押 shops gave 3-month terms at higher rates.
   - Teahouses were the market, political and information nodes of Jiangnan towns.
   - In 1938 the occupied delta came under the 维新政府 (Nanjing, 28 March 1938), with local 治安维持会 committees and puppet police. Vice was tolerated in exchange for support.
   - Food prices stayed fairly stable through 1938, and inflation took off from 1939.

---

## 1. Stardew Valley: how the town works

### 1.1 Layout and the "everything is close" rule
Pelican Town is a compact hub. The town square has Pierre's General Store, the Stardrop Saloon, the clinic, the community bulletin board, the Community Center to the north and JojaMart to the east. Districts radiate out from it:
- the beach (Willy's fish shop);
- the mountain (Robin the carpenter, the Mines, the Adventurer's Guild);
- the forest (Marnie's ranch, the Wizard);
- the bus stop leading to the desert.

The player's farm sits one screen west. Every important place is within about 30–60 real seconds' walk. **For us:** one water-town main street plus a canal and a bridge. The pawnshop and home sit at the centre, every shop is within one or two screens, and outlying areas (the dock, temple, school, outskirts) open later.

### 1.2 Hours, days off and NPC schedules
- **Shops keep hours and close on certain days.** The wiki's Shop Schedules table lists, among others:
  - Stardrop Saloon 12pm–12am;
  - Traveling Cart 6am–8pm, but **only Friday and Sunday**;
  - Wizard's Tower 6am–11pm;
  - Movie Theater 9am–9pm;
  - Carpenter about 9am–5pm, closed Tuesday.

  **All buildings and homes lock on festival days** whose festival starts before 7pm, with a few exceptions. ([Shop Schedules](https://stardewvalleywiki.com/Shop_Schedules), [alt](https://wiki.stardewvalley.net/Shop_schedule)). Pierre is open 9–5 and closed Wednesday, until the Community Center is finished **[verify]**. Robin's routine changes after the Community Center is restored ([guide excerpt](https://platform-api.staging3.proposable.com/stardew-valley-finding-robin-and-her-schedule-a-players-guide-to-locating-the-mayors-daughter)).
- **NPC schedules are data, not AI.** Each NPC has keyed schedule entries:
  - a day of week (it applies when it is not raining);
  - `rain`;
  - `rain2` (a 50% chance on rainy days);
  - season plus day;
  - season, day of week and a **minimum heart level** (e.g. `spring_Mon_6`).

  The highest qualifying heart key wins. If nothing matches, the NPC simply stays home ([Modding:Schedule data](https://stardewvalleywiki.com/Modding:Schedule_data)). Heart events recognise only two weather states, Sun and Rain. Dialogue keys use the same idea: `Mon` applies at 0+ hearts and `Mon2` at 2+ hearts ([Directions for Dialogue](https://stardewmodding.wiki.gg/wiki/Directions_for_Dialogue)).
- **Lesson:** cheap, authored, deterministic schedules with a few variant keys (weekday, weather, relationship tier, story flag) give a "living town" for very little code. Randomness can then pick *which variant applies today*, for example the `rain2` 50% key, instead of simulating every step.

### 1.3 How the world opens over time
- **Dated spine openings, announced by mail:** on Spring 5 the debris is cleared, which opens the Mines and the Adventurer's Guild, and a letter tells you. On Summer 3 an earthquake opens the Railroad ([The Mountain](https://stardewvalleywiki.com/The_Mountain), [The Mines](https://wiki.stardewvalley.net/The_Mines)).
- **The Community Center** is a ruined building you can see from day one. You complete bundles of items, and each finished room repairs something on the map:
  - **Crafts Room** fixes the bridge to the Quarry;
  - **Pantry** restores the Greenhouse;
  - **Boiler Room** fixes the minecarts. It opens after any 2 bundles;
  - **Fish Tank** removes the glittering boulder, which leads to panning;
  - **Vault** (42,500g) fixes the bus, which leads to the Calico Desert;
  - **Bulletin Board** gives friendship with several villagers.

  ([Bundles](https://stardewvalley.fandom.com/wiki/Bundles), [Vault](https://www.stardewvalleywiki.com/Vault), [guide](https://www.bamboogaming.net/stardew/community-center))
- **The Joja alternative** is a moral fork. You buy membership and pay cash for each project: about 135k for the projects, or 140k including membership, per one guide. The bundle route is then gone for that save ([PlayNews](https://www.playnews.gg/en/guides/stardew-valley-the-complete-community-center-guide-the-30-bundles-the-6-rooms-and-the-140-000g-joja-route)). The same unlocks come either from **community labour and relationships** or from **money plus a corporation**. That is a strong template for the occupation era: open the town through neighbours and guilds, or through the 维持会 and collaborators.
- **Visible-but-closed buildings create anticipation.** The boarded Community Center, the broken bus and the glittering boulder are all on screen long before you can use them.

### 1.4 Daily loop, clock and energy
- A day runs 6am→2am, which is 20 in-game hours. **10 in-game minutes take 7 real seconds**, so a full day lasts about 14 real minutes. The clock pauses in menus and cutscenes in single player ([Day Cycle](https://www.stardewvalleywiki.com/Day_Cycle), [Time](https://stardewvalleywiki.com/Time)).
- **Passing out at 2am**, or from exhaustion outside your home, sends you home. It costs **10% of your gold, capped at 1,000g**, and a letter explains the loss.
  - Sleeping by midnight restores full energy.
  - Staying up later restores less: about 75% at 1am and 50% at 2am.
  - Being exhausted restores half.
  - You always wake at 6am.

  ([Passing out](https://stardewvalleywiki.com/Passing_out), [Sleep](https://stardewvalleywiki.com/Sleep))
- Base energy is 270 **[verify]**. Tools, fishing and similar actions drain it. Food restores it.
- **Telegraphed daily randomness:** the TV in the house shows
  - the **Fortune Teller**, who reveals today's hidden *daily luck* (it affects mining drops, ladders and more);
  - the **Weather Report**, which gives tomorrow's weather.

  Weather also changes villager dialogue and behaviour ([Fortune Teller](https://stardewvalleywiki.com/Fortune_Teller), [Television](https://stardewvalleywiki.com/Television)). This is the key pattern: **a hidden random variable plus a diegetic oracle**. For 1938 the oracle would be a 黄历, the fortune-teller at the teahouse, or the newspaper.
- **The Help Wanted board** outside Pierre's may post a random quest on any day after the first. A "!" marks a new posting. You get **2 days** (today and tomorrow), and rewards scale with the job plus a little randomness ([Help Wanted](https://stardewvalleywiki.com/Help_Wanted)).

### 1.5 Entering buildings
Doors are **warp tiles**. The map data lists the source tile and the target location plus tile, and the engine fades to black, swaps maps and fades in. The fade even plays before the game checks that the target exists ([Modding:Buildings](https://stardewvalleywiki.com/Modding:Buildings), [forum](https://forums.stardewvalley.net/threads/please-help-warp-failed-location-wasn%E2%80%99t-found.34839/latest)). Interiors are separate maps and are often bigger inside than outside. The fade hides the teleport ([gamedev.net discussion of the pattern](https://nene.gamedev.net/forums/topic/668452-how-to-do-rpg-interiors/5231571)).

### 1.6 How dialogue is shown
- Stardew uses a **large bottom dialogue box** with a 64×64 portrait and a nameplate on the right. Text advances with a click.
- Portraits are a sheet of expressions. Dialogue strings switch the expression with commands: numbered `$0…$N` picks a portrait index, and named codes such as `$h` (happy), `$s` (sad), `$a` (angry) and `$l`/`$u` exist. Gift reactions fall back to the happy or sad portrait automatically ([Modding talk:Dialogue](https://stardewvalleywiki.com/Modding_talk:Dialogue), [forum](https://forums.stardewvalley.net/threads/dialogue-mods.3880/latest), [Nexus](https://www.nexusmods.com/stardewvalley/mods/15882)).
- **The owner explicitly does not want a big box** (item #1: lines placed beside speakers). In the town, use comic-style bubbles anchored above or beside each speaker's head. At the counter, put the portrait beside its own bubble. That is closer to Night in the Woods than to Stardew. Stardew's **portrait-expression codes in the text** are still worth copying for authoring.

### 1.7 Gifts, hearts and mail
- **Friendship:**
  - Each heart is 250 points. Villagers have 10 hearts; a spouse has 14.
  - You can give **1 gift per day and at most 2 per week** per villager, tracked by checkboxes in the Social tab.
  - Friendship decays if you don't talk to someone that day, unless their meter is full: −2/day normally, −10/day after a bouquet, −20/day when married. A telephone call doesn't count as talking.

  ([Friendship](https://stardewvalleywiki.com/Friendship), [Social tab](https://stardewvalleywiki.com/Social_tab)). Birthday gifts are ×8 **[verify]**.
- **Heart events** unlock at thresholds such as 2, 4, 6, 8 and 10. Weather gating is limited to Sun and Rain ([Schedule data](https://stardewvalleywiki.com/Modding:Schedule_data)).
- **Mail** is a data file of letters. Letters can **carry items** (e.g. Robin's wood gift, Demetrius's specimen) and can **teach recipes** once a friendship threshold is reached; they arrive the morning after. Mail also announces unlocks, penalties and quests ([Modding:Mail data](https://stardewvalleywiki.com/Modding:Mail_data), [Steam thread](https://steamcommunity.com/app/413150/discussions/0/385428458168051125)).
- **For us:**
  - Mail and telegrams fit 1938 perfectly. Use letters for 赎当 promises, invitations (喜帖/讣告), levies, rumours and threats.
  - The **2-per-week gift cap plus decay** is a good *hidden* model, but GameJev bans the visible heart meter. Show the relationship diegetically instead:
    - a 人情簿 that records who gave what, when, and what you owe back;
    - forms of address that change (e.g. 王老板 → 老王 → 王大哥);
    - greetings on the street, or being ignored;
    - invitations, or their absence;
    - letters;
    - who comes to speak for you (说情) during a negotiation.

    This satisfies owner item #17 (relationship visualisation through gifts and telegram notices) without showing numbers.

### 1.8 Why it feels cosy, and where its tension comes from
- **Cosy:**
  - there is no game over and failure is mild (a passing-out fee);
  - gentle music and animation, and an unobtrusive UI;
  - players set their own goals;
  - the seasonal calendar always gives you something to anticipate;
  - the routine and familiarity of people's lives;
  - restoring a communal building.

  ([criticalvideogamestudies analysis](https://gamedesign.criticalvideogamestudies.com/stardew-valley-game-analysis/), [Medium](https://medium.com/swlh/deceptively-simple-design-cabde40af87f), [kokutech](https://www.kokutech.com/blog/gamedev/design-patterns/world-building/stardew-valley)). Barone's own stated aim was Harvest Moon's "magical feeling of exploring a different world" plus relationships with townsfolk ([NPR via KPBS](https://www.kpbs.org/news/2025/01/24/the-legacy-and-future-of-the-farming-game-stardew-valley)).
- **Tension:**
  - the 14-minute day clock and the energy budget;
  - crops that only grow in their season;
  - the 2am cut-off;
  - weekly gift caps and birthdays;
  - Joja's encroachment.

  Many players say they find the timer stressful and that it is really a time-management game ([HN thread](https://news.ycombinator.com/item?id=25887051), [Steam thread](https://steamcommunity.com/app/413150/discussions/0/844005195821149789/)).
- **For 德厚当:** the 1938 setting needs *more* dread than Stardew, but the cosy layer of ordinary days, regulars and teahouse gossip is what makes the dread matter. GameJev already says this: "普通日子是重要内容，不是等待灾难的空白".

### 1.9 Borrow and avoid

| Borrow | Avoid |
|---|---|
| Shop hours, days off, schedule keys (weekday/rain/tier/flag) | A big bottom dialogue box (owner #1) |
| Visible-but-closed buildings; restoration via relationships vs. via money/collaboration | A visible hearts meter (GameJev rule) |
| Dated spine openings announced by mail | Real-time clock pressure during conversations (pause the clock at the counter, as Stardew does in menus) |
| Diegetic oracle for hidden daily randomness (TV → 黄历/报纸/茶馆) | Farming and combat loops |
| Bulletin-board random jobs with short windows | |
| Fade-warp interiors | |

---

## 2. Shopkeeper, pawnshop and survival references: what to borrow

Relevance to the new direction (★★★ = borrow now):

| Game | Rel. | Best mechanisms to borrow |
|---|---|---|
| **Papers, Please** | ★★★ | Line-item household bill with skippable items and delayed consequences; a daily newspaper; the EZIC double-agent thread |
| **Pathologic 2** | ★★★ | Essentials get dearer as the town falls; barter matters more than cash; days lock content |
| **Cart Life / 大多数** | ★★★ | Personal life costs (family, health, permits) inside a vendor loop |
| **Recettear** | ★★ | Debt instalments tied to the calendar; customer budgets; a combo bonus for a right first offer |
| **Moonlighter** | ★★ | Price discovery through reactions plus a ledger; investing to bring new shops to town |
| **Potionomics** | ★★ | Haggling as a turn structure with interest and patience; NPC relationships unlock negotiation options |
| **Graveyard Keeper** | ★★ | A named-day week where certain NPCs appear only on their day; the town's needs as quests |
| **Strange Horticulture** | ★★ | A reference book plus close inspection to identify items from customers' vague requests; a gentle "dread" fail meter |
| **Disco Elysium** | ★★ | Red/white checks (one-shot vs retryable); a town investigation where exploring creates options |
| **Dredge** | ★★ | A day/night timer with night dread; a shaped-grid hold |
| **Kynseed** | ★★ | Generations, heirlooms, NPCs that remember and age; reputation spreads |
| **Coffee Talk** | ★ | Stories branch on *what you serve*, not on dialogue picks |
| **Sunless Sea** | ★ | Ports advance their stories bit by bit over repeated visits; costs that are a constant drain |
| **This War of Mine** | ★★ | Hunger, illness and mood interlocking; neighbours asking for help; a randomised war length |
| **Pawnbroker Simulator (2026)** | ★ | A cautionary tale: haggling depth praised, the repetitive loop criticised |
| **Merchant of the Six Kingdoms** | ★ | Multiple markets and speculation across a map |
| **Eastward / Octopath (HD-2D)** | visual | See §5 |

### Papers, Please (the best model for variable pressure)
- **The bill is settled at the end of each day** as line items: rent, food, heat, and medicine when needed.
  - **Rent is mandatory.** The class-8 apartment costs 20 credits, rising to 25 after day 5. Failing to pay rent ends the game.
  - **Food** costs 5 per family member, and **heat** costs 10. Both can be skipped.
  - Skip food or heat for two days in a row, or both on the same day, and family members may fall sick. **Medicine** costs 5 per person.
  - Players learn to alternate food and heat and to buy medicine reactively.

  ([Family](https://papersplease.fandom.com/wiki/Family), [ludo.guide](https://www.ludo.guide/guide/papers-please/family-expenses), [Heat](https://papersplease.fandom.com/wiki/Heat)). **Borrow:** skippable needs with *delayed, escalating* consequences. That turns survival into daily choices instead of a single threshold.
- **The daily newspaper** (*The Truth of Arstotzka*) appears each morning. Its headlines are fixed story beats, some reflect your earlier choices, and the details can matter ([wiki](https://papersplease.fandom.com/wiki/The_Truth_Of_Arstotzka)). **Borrow:** a morning paper or notices as the telegraph channel. The 报馆 building can unlock it.
- **EZIC:** a secret order gives five tasks on fixed days. The number you complete selects the ending ([speedrun guide](https://speedrun.com/papers_please/guides/qgmep), [Day 32](https://papersplease.fandom.com/wiki/Day_32)). **Borrow for owner item #18** (double agent, middleman, spy): a resistance network and the 维持会 both ask for favours, and the endings count which side you served.

### Pathologic 2
- Each day is followed by a short night. Some content locks at night, until the next day or permanently ([wiki](https://pathologic.wiki.gg/wiki/Game_Mechanics)).
- **Food grows more expensive and rarer as time passes.** Water turns contaminated as districts fall. Money becomes nearly worthless and **barter** takes over (children trade for nuts and sharp objects). Stores sell at about 110% and buy at about 90% of base price ([wiki](https://en.wikipedia.org/wiki/Pathologic_2), [PC Gamer](https://www.pcgamer.com/pathologic-2-review/), [Slant](https://www.slantmagazine.com/games/pathologic-2-review/)).
- Critics found the survival tuning too punishing.
- **Borrow:**
  - essential prices that drift with *world state* (blockade, refugees);
  - a **single public base price with fixed buy and sell spreads**. This fixes owner item #14, where buying high and selling low came from inconsistent prices;
  - barter as a fallback.
- **Avoid** making survival so tight that it drowns the story.

### Cart Life and 大多数 (大多数人生)
- Cart Life (IGF 2013 Grand Prize) has three street vendors. Each must pay for supplies, rent and personal needs while dealing with life events: a custody hearing, addiction, a family. It also requires **an up-to-date permit**, and its minimalist pixel art "lets players fill in details" ([Wikipedia](https://en.wikipedia.org/wiki/Cart_Life), [BuzzFeed](https://www.buzzfeednews.com/article/josephbernstein/the-essential-great-recession-simulator)).
- 大多数 has hunger, thirst, stamina and health that interlock. Stamina at 0 forces sleep and costs 10 health, and low health cuts income. Rent is due monthly and failing it ends the game. The fridge has limited capacity and food spoils ([TapTap review](https://www.taptap.cn/review/48465209)).
- **Borrow:**
  - **storage and spoilage** as the counterweight to bulk-buying cheap rice;
  - **permits and licences** as institution-driven costs (the 警察所 or 维持会 issues the 当铺 licence);
  - family members whose needs differ.

### Recettear
- You pay off a debt in **weekly instalments that grow**. Missing one is game over, though you keep your merchant level on restart. Each day has a few time units, and opening the shop costs one ([Wikipedia](https://en.wikipedia.org/wiki/Recettear:_An_Item_Shop%27s_Tale), [RPG Site](https://rpgsite.net/review/2955-recettear-an-item-shop-s-tale-review)).
- Customers have **budgets**. If your first offer is accepted you get a "just combo" XP chain of 2, 4, 8, 16…; haggling breaks the chain ([guide](https://www.writeups.org/recettear-strategy-guide-tips/)).
- **Borrow:** reward a *fair first quote* (reputation for 公道) over grinding the haggle. It fits 德厚 ("thick virtue") thematically.

### Moonlighter
- **Price discovery:** customers react with emoji to four price bands. A notebook records the best price that drew each reaction ([Siliconera](https://siliconera.com/?p=709874)). Moonlighter 2 bands as measured by fans: Cheap <88%, Perfect 88–104%, Expensive 105–120%, Over 121%+ ([Prima](https://primagames.com/tips/moonlighter-2-shop-guide-pricing-furniture-perks-explained)) **[verify]**.
- **Investing in the town:** you spend money to bring NPCs who open new shops (blacksmith, potion witch, and so on), and they don't steal your customers ([Indiecator](https://indiecator.org/2019/07/24/indietail-moonlighter/)).
- **Borrow:**
  - selling dead pawns on a **public shelf or market stall**, where you read *body language*, not emoji or numbers;
  - shops opening through your investment or loans. A 钱庄 or 布庄 opens because you **financed** it, which is a neat pawnbroker-as-lender twist.

### Potionomics
- Haggling is a card battle. The customer has **Interest** (fill it to raise the price) and **Patience** (it drains each turn). Stress limits your draw. Closers end the haggle at +5%. Better cards come from **befriending NPCs** ([RPGFan](https://www.rpgfan.com/review/potionomics/), [TV Tropes](https://www.tvtropes.org/pmwiki/pmwiki.php/VideoGame/Potionomics), [Inverse](https://www.inverse.com/gaming/potionomics-review-best-sim-2022)).
- **Borrow for owner #15** (interaction during bargaining): give negotiation *moves* (cite the ledger, invoke 人情, call a guarantor, offer better terms, go silent), unlocked by relationships.
- **Do not** show the Patience bar. GameJev forbids it, so show patience through tapping fingers, glances at the door, or a change of tone.

### Graveyard Keeper
- The week has six named days, each with a symbol. Key NPCs appear **only on their day**, and if you miss them you wait a week. There is no time pressure and quests never expire. Quests chain deeply; the tech tree is deep but opaque ([NWR review](https://nintendoworldreport.com/review/51008), [Steam](https://steamcommunity.com/app/599140/discussions/0/4034726433733820353)). Graveyard Keeper 2 ties weekly events to days, such as a sermon day or a merchant-ship day ([wikily](https://wikily.gg/graveyard-keeper-2/calendar/wrath)).
- **Borrow:** a **market-day (集日) cycle** and weekly fixtures. For example, the 米船 arrives every 3rd day, the teahouse 评弹 runs on certain nights, and 庙会 falls on lunar dates. **Avoid** opaque requirements; keep goals legible.

### Strange Horticulture
- Customers ask by name, by effect or by vague problem. You identify the plant using a **book that starts nearly empty** (pages come from exploring, letters and customers) plus close inspection. Three wrong answers in a day fill the "Rising Dread" meter and trigger a puzzle, a gentle penalty. A map with clues unlocks new locations ([PC Gamer](https://www.pcgamer.com/strange-horticulture-review/), [Start Menu](https://startmenu.co.uk/home/review-strange-horticulture)).
- **Borrow for owner #5 and #11** (manual appraisal, appraisal certificate, mystery box): an 鉴定谱 book whose pages you collect (on porcelain marks, silver purity, jade), plus a magnifier and touchstone. Mystery boxes become puzzles that use the book.

### Disco Elysium
- **White checks** can be retried after you gain skill or information. **Red checks** are one-time and may close a path. Failing rarely hard-locks the main case. The environment uses the same check system as dialogue. The Thought Cabinet holds 12 slots, and an internalised thought often carries a temporary penalty first ([wiki](https://discoelysium.wiki.gg/wiki/Thoughts), [RPGamer](https://rpgamer.com/review/disco-elysium-review/), [gfinity](https://gfinity.net/disco-elysium/can-you-fail/)).
- **Borrow:**
  - the **red/white distinction** for irreversible moments (a refused plea, a reported customer) versus retryable ones (appraisal);
  - investigating the town means **asking around**, which yields optional clues, never failure.

### Dredge
- The daylight clock runs only while you are at sea. Night brings a "panic" eye and sanity drain, and lights keep madness down. Shaped items fill a grid hold. Reviewers praised the hold, called fishing repetitive, and found the night tension effective ([GamingTrend](https://gamingtrend.com/reviews/dredge-review-a-checkered-flag-of-red-and-white/), [NME](https://www.nme.com/reviews/dredge-review-3418763)).
- **Borrow:** *curfew* (宵禁) under occupation as our "night". Being out after curfew is a real but light dread (checkpoints, patrols).
- **Avoid** a grid inventory at the counter; that is Probably Stolen's signature.

### Kynseed
- You raise children and play as them. Some traits are inherited and some are replaced by "black sheep" traits. A legacy item starts the family tree. NPCs remember and age. Reputation spreads, and mistreating someone can start a vendetta ([dev interview](https://useapotion.com/2018/03/kynseed-interview), [Retroware](https://articles.retroware.com/2020/10/13/checking-in-on-kynseed/)).
- **Borrow for owner #9 and #13** (choose a career at year end; parents leave heirlooms): heirlooms with provenance, and an end-of-year 盘点 where you choose your path.

### Coffee Talk and Sunless Sea
- **Coffee Talk:** branches come from *what you serve*, not from dialogue choices ([Moby](https://www.mobygames.com/game/138352), [Xbox Hub](https://www.thexboxhub.com/?p=84035)). **Borrow:** how you value or hold someone's pawn (lend more, keep it safe, sell it early) *is* the dialogue choice.
- **Sunless Sea:** port stories advance bit by bit over many visits, and the costs of food, fuel and terror never stop draining ([RPGamer](https://archive.rpgamer.com/games/indie/sunsea/reviews/sunseastrev1.html), [PCGamesN](https://www.pcgamesn.com/sunless-sea/sunless-sea-early-access-review)). **Borrow:** each building advances its own storylet chain one step per visit.

### This War of Mine
- You keep survivors' health, hunger and mood up until a **ceasefire after a randomised duration**. Daytime is for crafting and trading; one person scavenges at night. Raids are random. Neighbours come asking for help, which creates moral trade-offs ([Wikipedia](https://en.wikipedia.org/wiki/This_War_of_Mine), [GodIsAGeek](https://godisageek.com/reviews/this-war-of-mine-review/)).
- **Borrow:** neighbours asking for help (a pawn of desperation), mood as a cost of cruelty, and a **randomised length for the occupation phase**.

### Pawnbroker Simulator (released 11 Mar 2026) and Merchant of the Six Kingdoms
- **Pawnbroker Simulator** offers 200+ items and a customer-specific haggling style. Players praised the negotiation but criticised demanding customers and a loop that turns repetitive quickly ([Vaporlens](https://vaporlens.app/app/3997360/pawnbroker_simulator), [wasdland](https://www.wasdland.com/game/pawnbroker-simulator-3997360/)). It is a warning: a counter loop alone gets stale, and the town and long-term contracts are the cure.
- **Merchant of the Six Kingdoms** (2023) is a medieval bartering and investing RPG with about 20 markets, 200 characters, auctions and speculation ([ITAD](https://isthereanydeal.com/game/merchant-of-the-six-kingdoms/info/)). It is only relevant for *arbitrage between town venues*.

(I did not research Kingdom Come: its relevance to a pawn or town sim is low.)

---

## 3. Design patterns for randomness in daily-life sims

### 3.1 Storylets (quality-based narrative) as the content unit
- A storylet has **prerequisites**, a list of quality ranges the world must fall within, and **effects**, the quality changes it applies. Those changes unlock further storylets. Failbetter calls them "mosaic tiles, not pipes". Long arcs need a "spine" of manually managed qualities, and Fallen London's **opportunity deck** lets the player shape which storylets get drawn ([Emily Short 2016](https://emshort.blog/2016/04/12/beyond-branching-quality-based-and-salience-based-narrative-structures/), [Kreminski on storylets](https://emshort.blog/2019/01/06/kreminski-on-storylets/), [Yarn Spinner primer](https://docs.yarnspinner.dev/write-yarn-scripts/advanced-scripting/storylets-and-saliency-a-primer)).
- **Apply:** each building has a storylet deck. Prerequisites read world qualities (rice price band, occupation phase, relationship tier, contract states). On each visit the game draws one *salient* storylet, i.e. the most specific match, with a weighted pick among ties.

### 3.2 Weighted deck with cooldowns and a mandatory quiet card
- Use an effective weight (this is GameJev's own formula):

  `effective weight = base × prerequisite gate × cooldown gate × season factor × context modifier`

  Every deck has a positive-weight **quiet** card, so most days stay ordinary.
- **Darkest Dungeon town events** do the same in their own way. Since a 2016 patch there are 40+ events (bonus recruits, extra supplies, facility closures), each with art and narrator commentary, mostly chaos with some boons. The player can adjust their frequency in Options, and they are mandatory in New Game+. **Some recruit classes appear only through their own event** ([wiki Hamlet](https://darkestdungeon.wiki.gg/wiki/Hamlet), [patch](https://darkestdungeon.wiki.gg/wiki/17_May_2016_Patch), [Siliconera](https://www.siliconera.com/not-even-hamlet-safe-everything-burns-update-darkest-dungeon/)).
- **Apply:** each morning shows one **town notice** (镇上告示 / 晨间见闻), for example "药铺歇业一日", "米船到埠，米价松动" or "维持会摊派". Rare NPC types (an itinerant antique dealer, a refugee scholar) are gated behind their own events.

### 3.3 Storytellers and directors (pacing)
- **RimWorld:**
  - **Cassandra Classic** alternates about 4.6-day "On" and 6-day "Off" phases. Each On phase brings 1 or 2 major threats (50/50), at least 1.9 days apart.
  - **Randy Random** fires events about every 1.35 days on average and scales raid points by ×0.5–1.5. If 13 days pass with no major threat, the next event is forced to be one. Over the long run he averages about as many threats as Cassandra, yet many players find Cassandra harder because she is regular.
  - **Phoebe Chillax** leaves long gaps between disasters.

  ([Cassandra](https://rimworldwiki.com/wiki/Cassandra), [Randy](https://rimworldwiki.com/wiki/Randy_Random), [Storytellers](https://rimworldwiki.com/wiki/Storyteller)). Threat points scale with wealth (buildings count at half, and wealth below about 14k barely matters), multiplied by difficulty and an **adaptation** factor that drops when colonists die or are downed and recovers over time. Tynan has said that wealth alone does not drive scaling ([Wealth management](https://rimworldwiki.com/wiki/Wealth_management), [Steam](https://steamcommunity.com/app/294100/discussions/0/360671583800707840)). **PopulationIntent** separately decides whether to offer new colonists ([wiki](https://mail.rimworldwiki.com/wiki/PopulationIntent)).
- **The Left 4 Dead AI Director** is a finite-state machine of build-up → peak → relax. It eases off when the team is struggling and pushes harder when they are cruising ([Wikipedia](https://en.wikipedia.org/wiki/Left_4_Dead), [Shacknews preview](https://shacknews.com/article/46769/left-4-dead-preview), [Evolve on L4D](https://shacknews.com/article/82787/how-evolve-assures-action-peaks-and-valleys)).
- **Apply, within GameJev's rule that exogenous wheels never read the player:**
  - **Disasters** (weather, the war front, epidemics) are exogenous and use Cassandra-like **fixed on/off phases with their own cooldowns**, never rubber-banded to the player's cash.
  - **Opportunities and social traffic** (who comes to pawn what) are endogenous. They may read *town* pressure, and it is natural for poorer times to bring more pawns. A Director-style relax phase also comes naturally: after a crisis, a festival or market day.
  - Offer a difficulty choice as a **named storyteller persona**, e.g. 「太平年」 (Phoebe) / 「常年」 (Cassandra) / 「乱世」 (Randy). It also reads well as an in-fiction almanac.

### 3.4 Streak control
- **Pseudo-random distribution (Dota 2 / WC3):** the chance starts low and grows after each failure. A nominal 25% effect has about an 8.5% first-try chance, rising by about 8.5% per failure and resetting on success. The result is the same mean with much less variance ([Liquipedia](https://liquipedia.net/dota2/Random_Distribution), [fandom](https://dota2.fandom.com/wiki/Pseudo-random_distribution), [diplograph](https://diplograph.net/notes/games/randomness/dota-2-prd)).
- **Shuffle bag:** draw without replacement from a bag, e.g. one theft per 20 day-slots, and refill when empty. This guarantees frequency per cycle. It is a standard technique; the search found no single canonical source.
- **Randy's 13-day guarantee** is a "pity timer" on the other side.
- **Apply:**
  - Use PRD or a bag for *good* surprises (a rare treasure in a pawn bundle, owner #13 "valuable items appear late") so the player isn't starved.
  - Use cooldowns plus caps for *bad* shocks, e.g. at most one household medical emergency per 10 days.
  - Never let a re-roll come from clicking (GameJev rule).

### 3.5 Seeds and separate streams
- Slay the Spire uses one run seed but separate generators for monsters, events, merchants, cards, treasure, relics and potions, and some are re-created each floor ([forum quote](https://greaterwrong.com/posts/DvRBSzFjfaPYBhwmj/one-shot-strategy-games/comment/JKtHbTEDPsFe2xssD), [Map Generation](https://slaythespire.wiki.gg/wiki/Map_Generation)). In Slay the Spire 2, players found **correlations between streams**, and Mega Crit reworked the RNG, reportedly seeding each subsystem with seed + hash(system name) ([GosuGamers](https://www.gosugamers.net/entertainment/news/78641-slay-the-spire-2-overhauls-rng-after-players-uncover-unexpected-run-correlations-removes-a-boss), [tck.mn](https://tck.mn/blog/correlated-randomness-sts2/)).
- GameJev's `draw(world_seed, domain, semantic_key)` via SHA256 is the *correct* version of this. Keep it, and give **each building, each NPC and each wheel its own domain**.

### 3.6 Input vs output randomness, and the "fixed spine + random flesh" pattern
- Keith Burgun separates **input randomness** (it is known before you decide, e.g. today's rice price or who walks in) from **output randomness** (a dice roll after you commit). He argues output randomness hurts strategy ([Burgun](https://keithburgun.net/riot-is-thinking-about-inputoutput-randomness-in-league-of-legends), [Game Developer](https://www.gamedeveloper.com/design/how-randomness-contributes-to-strategic-thinking)). **Apply:** reveal the daily variables in the morning (the price board, the notice, the weather), so the player plans *around* randomness. Keep output randomness for hidden human reactions only. Those are judgeable, not dice.
- **Fixed spine + random flesh:**
  - Frostpunk 2 hard-codes the first temperature changes (drop, rise, drop, drop, rise) and randomises only afterwards ([changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/3357735062)). Frostpunk 1 shows a **weather forecast beside the big temperature readout** so you can plan ([Checkpoint review](https://checkpointgaming.net/reviews/2018/04/frost-punk-review-not-winter-wonderland/)).
  - Stardew fixes the dates (Spring 5, Summer 3, festivals) but randomises stock, quests, luck and weather.
  - Papers Please fixes the story days and draws the entrants procedurally.
  - Hades makes failure advance the story ([GameSpot](https://gamespot.com/articles/hades-changes-what-it-means-to-be-a-roguelike/1100-6483420/)).

  **Apply:** use 1938's historical calendar as the spine:
  - the 维新政府 is founded on 28 March;
  - a curfew and passes (良民证);
  - the 端午 and 中秋 festivals;
  - the silk-cocoon season (春蚕);
  - rice harvests.

  The flesh is drawn from decks.

### 3.7 Designing variable daily survival pressure fairly (a template)
Split the 家用 (household budget) into **lines with different randomness types**. Each line has a public source of information and a lag:

| Line | Cadence | Randomness | Telegraph | Skip consequence (lagged) |
|---|---|---|---|---|
| 铺租 / 房租 (rent) | monthly, fixed date | change only by landlord letter ≥7 days ahead | letter + calendar | eviction warning, then loss of goodwill |
| 米 (rice) | daily need × household size × 米价(t) | market wheel: mean-reverting random walk plus shocks (blockade, 米船 delayed, harvest) | **米行 price board each morning**; rumours at the teahouse | hunger streak → sickness after 2 days (Papers Please rule) |
| 柴炭 (fuel) | daily; seasonal | weather wheel (cold snap) | 黄历 / forecast | illness risk for the old and very young |
| 药 (medicine) | only when sick | triggered by the streaks above, or by the epidemic wheel | the clinic's diagnosis | worsening, then death possible (rare, telegraphed) |
| 人情 (gifts/礼金) | event-driven | NPC life events (weddings, funerals, births) | **invitation letter 3–7 days ahead** | relationship cost, not cash |
| 捐/摊派 (levies) | irregular | endogenous civic wheel (维持会, 保甲) | 保长's visit or a posted notice | **negotiable**: reuse the bargaining system on obligations |
| 执照 / 规费 (licence) | quarterly | institutional | notice | shop shut until paid |
| 债息 (debt interest) | if the player borrowed | fixed | ledger | collateral seized |

Fairness rules distilled from the references:
1. **Every cost has a visible source and date.** No silent deduction at night, except true emergencies, and those are capped by cooldown (Papers Please, plus GameJev's "facts are never rewritten").
2. **Ranges, not secrets:** show the band ("米价 每石 X–Y") and rumours drawn from the *already rolled* state. GameJev allows public quotes with a source and timestamp, and forbids future draws.
3. **Lagged, escalating consequences.** The Papers Please 2-day rule gives the player room to juggle.
4. **Carry-over buffers:**
   - 赊账 credit at the 米行, with a limit set by reputation;
   - arrears with a grace period;
   - **the player pawning their own things** (GameJev U22);
   - a 钱庄 loan.
5. **Agency against variance:** bulk buying with storage limits and spoilage (大多数), substitution (cheaper grains), and barter (Pathologic 2).
6. **Preparation is never punished.** GameJev EXT09 says reserves change your ability to cope, not the draws.
7. **A variance budget, checked by Monte Carlo:** target the *mean weekly burn* and the *P90 weekly burn*, and run, say, 200 seeds headless. GameJev already ran an 80-seed propagation test.
8. **Calm windows:** exogenous decks have their own off phases (Cassandra), so a run of disasters is structurally bounded *without* reading the player's state.

---

## 4. Historical grounding: a small Jiangnan town in 1938

The search coverage of Chinese sources was thin, because of blocked fetches. The items below are cited where possible; anything else is marked as general knowledge **[verify]**.

### 4.1 The pawnshop (当铺 / 典当 / 质铺)
- **The high counter.** Lu Xun, *呐喊·自序*: as a boy he went almost daily to the pawnshop and the pharmacy. The pharmacy counter was as tall as he was, and the **pawnshop counter was twice his height**. He handed up clothes and jewellery to be "insulted" and took the cash to buy medicine for his father ([marxists.org full text](https://www.marxists.org/chinese/reference-books/luxun/03/001.htm), [aisixiang](https://www.aisixiang.com/data/39023.html)). This is an instant scene idea: the player looks *down* on customers from the 高柜台.
- **朝奉:** in the Ming and Qing, northern pawnbroking was dominated by Shanxi and Shaanxi merchants and southern pawnbroking **by Huizhou merchants**. 朝奉 became the folk name for the Huizhou pawnbroker or appraiser, and the tale "徽州朝奉来取宝" spread across Jiangnan. Local operators gained the trade's know-how only in the late Qing and early Republic (search excerpts from [douban note](https://www.douban.com/note/786317482) and related results).
  - Typical roles, from general knowledge **[verify]**: 掌柜/经理 (manager); 朝奉 at the high counter, who appraises and quotes; 写票 (ticket writer, in a special cursive "当字"); 卷包/管包 (wraps, tags and stores the goods); 学徒 (apprentice, usually 3 years). Tickets famously used deprecating descriptions to limit liability, for example "虫吃鼠咬" and "光板没毛" **[verify]**.
- **Terms and rates:**
  - Shandong local gazetteers record a **monthly interest of 3分 (3%) plus a 5厘 storage fee**.
  - Clothing was pawned at **60–80% of value**, with the term negotiated.
  - In the Republic, pawnshop and lending-shop loans were capped at **10 months**.
  - Land 典 terms ran 2–3 years.

  ([gazetteer 1](https://shandong-chorography.org/database/c31/section/1/article/314/index.txt), [gazetteer 2](https://shandong-chorography.org/database/c84/section/1/article/282/index.txt)). These are northern data and only a proxy for Jiangnan.
- **Qing reference:**
  - Giles (1876) describes a ticket at **3% per month for 16 months**, after which the pledge became the pawnbroker's property.
  - **Unlicensed shops took pledges for only 3 months at much higher interest.**
  - A ticket records the shop's name and address, a number, a description, the amount lent and the date.

  ([Giles, *Chinese Sketches* ch.12](https://pinyin.info/books/giles/sketches/chap12.html), [Gutenberg](https://gutenberg.org/files/2133/2133-h/2133-h.htm))
- **Vocabulary for the game:**
  - 当期 (term);
  - 月息 (monthly interest);
  - 赎当 (redeem);
  - 续当/转当 (renew by paying the interest);
  - **满当 / 死当 / 绝当** (forfeited at term, which goes to the dead-pawn shelf, GameJev U24);
  - 小押/押店 (small, short-term, high-rate operators; a plausible *rival* or *lower tier*);
  - 架本 (the capital tied up on the shelves) **[verify]**.
- **Republic-era context:** pawnshops adapted to competition from modern banks and stayed numerous as informal finance until the early 1950s (Köll's research, summarised in the [HKU CBH programme](https://www.hkihss.hku.hk/wp-content/uploads/2024/07/CBH-Conference-Program-22072024-Public-Version_20240730.pdf)). Lowenstein's dataset of Qing and Republic loan contracts includes pawnshops as a lender type ([Hoover slides](https://hoover.org/sites/default/files/2025-03/Lowenstein%20-%20Presenter.pdf)). **Primary book to get:** Yang Zhaoyu 杨肇遇, *中国典当业* (1929), translated as *The Pawnshop in China* (U. Michigan Press) ([press page](https://press.umich.edu/Books/T/The-Pawnshop-in-China)).

### 4.2 Town buildings and their gameplay roles

| Building | Grounding | Suggested function |
|---|---|---|
| **茶馆** | Teahouses were "the nodes of the rural market, the focus of community politics and the hotspot of leisure" in modern Jiangnan (Zhu Xiaotian). Deals were negotiated and information traded there. Nanxun reportedly had about 50 teahouses before the war, and Xinchang about 18 in the 1920s–30s; "孵茶馆" is the local term ([Zhu Xiaotian PDF](https://shxyj.ajcass.com/Admin/UploadFile/20130926008/2015-08-30/Issue/obl3qpmq.pdf), [Wang Di](https://www.chinawriter.com.cn/n1/2024/0717/c442005-40279477.html)) | **The rumour and information hub** (GameJev information chain); 吃讲茶 mediation of disputes **[verify]**; finding private buyers for dead pawns; the 评弹 night |
| **米行** | Many Jiangnan market towns had large rice firms, e.g. 甪直's 万盛米行 from the early Republic ([Ctrip page, low reliability](https://gs.ctrip.com/html5/you/sight/11/3930.html)) | The daily **price board**; 赊账 credit; rice-boat (米船) arrivals |
| **钱庄 / 银号** | Called "百业之首" in Shanghai until the 1952 socialisation ([The Paper](https://www.thepaper.cn/newsDetail_forward_10445116)) | The player's lender and competitor; currency exchange (法币 vs. military scrip) |
| **药铺 (中药) / 西药房** | Chinese pharmacies far outnumbered Western ones even as both grew: a Shandong county had 34 → 144 Chinese and 3 → 16 Western pharmacies by 1936 ([gazetteer](https://shandong-chorography.org/database/bd/section/13/article/692/index.txt)). The pawnshop-pharmacy pairing is Lu Xun's | Medicine cost line; the pharmacist is a natural *regular*; Western drugs as smuggled high-value goods under occupation |
| **警察所 / 维持会警察** | In 1938 the Japanese cabinet approved the **中华民国维新政府** (Nanjing, 28 March 1938), which covered occupied Jiangsu, Zhejiang and Anhui plus Nanjing and Shanghai ([Guancha](https://www.guancha.cn/history/2025_03_26_769907_2.shtml), [JACAR glossary](https://jacar.go.jp/english/exhibition/glossary_en/term2/0050-0060-0020-0010-0010.html)). Japan liaised with local **治安维持会** committees. Brook's *Collaboration* covers the Jiading pacification and the creation of the Reformed Government ([Goodreads](https://www.goodreads.com/book/show/2267263.Collaboration), [Brook CV](https://www.college-de-france.fr/media/pierre-etienne-will/UPL31592_Brook_CV_publications.pdf)). Puppet Shanghai police numbered 5,662 by June 1939 ([Wakeman, *Shanghai Badlands*](https://www.cambridge.org/core/books/shanghai-badlands/puppet-police-and-76-jessfield-road/53FEFCBE5BD1A366B069AF23845CC6A7)) | Licences, stolen-goods reports, "tea money", pass checks; the police chief as a *person* with a family who also pawns things |
| **镇公所 / 保长 / 维持会** | 1930s Jiangsu moved from 自治 (self-government) to 保甲 (household mutual-responsibility groups); a 1935 national conference debated the two ([Yu Jianrong](https://www.aisixiang.com/data/4471.html), [NDL paper](https://ndlsearch.ndl.go.jp/en/books/R000000004-I9304542)). Local elites kept real power in Rugao ([UW thesis](https://digital.lib.washington.edu/researchworks/items/3076c27e-a408-4454-a9dd-d89047f30e4f)) | Levies (摊派), household registration, guarantors (保人); a source of collaboration dilemmas |
| **赌场 / 烟馆** | In occupied Shanghai, puppet gangsters supported the Japanese in exchange for protection of their casinos, brothels and opium dens ("the Badlands") ([LRB](https://www.lrb.co.uk/v26/n12/andrew-nathan/the-gangsters-who-were-really-officials-and-the-officials-who-were-really-gangsters), [ChinaFile](https://www.chinafile.com/node/478)) | Desperate pawns, stolen goods, debts; a late-unlocking, morally loaded building |
| **邮局 / 电报局** | Small towns usually had a 邮政代办所 (postal agency) rather than a full office **[verify]** | The mail and telegram channel (owner #17); remittances |
| **报馆 / 报贩** | Papers Please analogue | A morning paper that telegraphs the spine |
| **布庄 / 估衣铺 / 旧货摊** | General knowledge: 估衣 (second-hand clothing) dealers bought forfeited clothes **[verify]** | **The channel for selling dead pawns** (fixes owner #7) |
| **码头 / 航船** | Towns sat along waterways and boats were the main transport ([The Paper](https://www.thepaper.cn/newsDetail_forward_16302893)) | Arrivals and departures of strangers; blockades; smuggling |
| **庙 / 祠堂** | General knowledge | Festivals (庙会) as calendar beats; clan pressure |
| **学堂 / 诊所** | General knowledge | Children's needs; the doctor as an informant |

- **Market hierarchy:** 县市 → 镇市 → 草市 ([The Paper](https://www.thepaper.cn/newsDetail_forward_16302893)). Our town is a 镇市, and outlying 草市 market days could be a weekly "fair" event.
- **Prices in 1938:** locally produced food stayed relatively stable until 1938 (helped by a good Sichuan harvest). Prices of local and imported goods rose together from 1939 ([Wikipedia, Chinese hyperinflation](https://en.wikipedia.org/wiki/Chinese_hyperinflation)). Shanghai's refugee-driven boom of 1937–38 faded from autumn 1939, when the Yangtze blockade cut the city off and prices jumped. Puppet currency began circulating in Shanghai in 1942, and by 1940 real wages were about half their pre-war level ([The Paper, 江文君](https://www.thepaper.cn/newsDetail_forward_28273221)). **Design implication:** 1938 is the *calm before the inflation*. Start rice-price variance low and let the macro wheel's drift turn upward in 1939, a natural escalation that comes from history rather than from rising rent.

---

## 5. Godot 4 techniques, and a recommendation

### 5.1 Option A: Stardew-style 2D top-down 3/4 view (recommended)
- **Grid and scale:** 16×16 tiles, with characters taller than a tile (about 16×32) because of the perspective. Feet should not sit exactly on the bottom edge of a tile ([Stardew forum](https://forums.stardewvalley.net/threads/sprite-sizes-character-sheets-pixel-art.5597/latest), [itch thread](https://itch.io/post/15655890)). The repo already renders 320×180 ×4 with nearest filtering, and `understand/town_poc/` proves a palette-legal 16 px town at that scale.
- **TileMapLayer plus Y-sort:**
  - Enable `y_sort_enabled` on the TileMapLayer and put characters as children of the same Y-sorted parent, all at the same z-index.
  - Set each tall tile's **Y Sort Origin** to its base in the TileSet, and set the character origin at the feet.
  - `TileMapLayer.y_sort_origin` can fake height levels.

  ([class ref 4.3](https://docs.godotengine.org/es/4.3/classes/class_tilemaplayer.html), [forum solution](https://forum.godotengine.org/t/how-to-make-y-sort-for-tilemaplayer-in-godot-4-3/87689), [bugnet notes](https://bugnet.io/blog/fix-godot-tilemap-layer-y-sort-incorrect)). Use separate layers for ground, walls/objects (Y-sorted) and roofs/overhangs (above everything, faded when the player is underneath).
- **Movement:** `CharacterBody2D` with `velocity = Input.get_vector(...) * speed`, then `move_and_slide()` in `_physics_process`, without multiplying by delta ([KidsCanCode](https://kidscancode.org/godot_recipes/4.x/2d/topdown_movement/), [docs](https://docs.godotengine.org/en/4.2/tutorials/physics/using_character_body_2d.html)). Keep movement on the 320×180 integer grid to avoid pixel shimmer.
- **Doors and interiors:**
  - Use `Area2D.body_entered`, filtered to the player, as a warp tile, with a collision mask that matches the player.
  - **Store the target spawn id in an autoload *before* switching**, then let the new scene's `_ready()` place the player.
  - `change_scene_to_file` replaces the whole scene, so persistent state (the clock, money, contracts, the world wheel) must live in autoloads.
  - The alternative is a persistent `World` root that swaps the child map scene, which keeps the clock and HUD alive. That works well here, but individual map scenes then can't be run on their own.

  ([Autoload docs](https://docs.godotengine.org/en/4.2/tutorials/scripting/singletons_autoload.html), [door forum](https://forum.godotengine.org/t/how-change-scene-and-position-with-a-door/63035)). Add a 0.2–0.3 s fade, as in Stardew.
- **Camera:** a `Camera2D` with `limit_left/right/top/bottom` in world pixels, not tiles. Call `reset_smoothing()` after a warp so the camera doesn't drift outside the limits ([Camera2D ref](https://docs.godotengine.org/en/4.2/classes/class_camera2d.html), [forum](https://forum.godotengine.org/t/how-do-you-limit-the-camera-position/133286)). Prefer no smoothing, or snap the camera position to integers, to keep pixels crisp.
- **Day/night lighting:**
  - Animate a `CanvasModulate` colour along a time-of-day gradient; it sets the ambient colour wherever no light reaches.
  - Use `PointLight2D` for lanterns, with a radial `GradientTexture2D` falloff.
  - `DirectionalLight2D` gives sun/moon shadows.

  ([2D lights and shadows, 4.7 docs](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html)). Curfew nights become the dark CanvasModulate plus a few lit windows.
- **"Depth-lite" without 3D:**
  - Y-sort;
  - an ellipse drop shadow under every actor;
  - roofs that fade when you walk under them;
  - 1–2 px parallax on foreground eaves and bridges;
  - a light fog band over the canal;
  - optionally **normal-mapped sprites through `CanvasTexture`**, so `Light2D` lights them directionally. Godot expects X+/Y+/Z+ normals. CanvasTexture works only in 2D, and a forum report notes pixel-art normal-map lighting can look smoothed, worked around with a higher light height ([CanvasTexture ref](https://docs.godotengine.org/en/4.2/classes/class_canvastexture.html), [forum](https://forum.godotengine.org/t/low-bit-pixel-art-light-texture-on-canvastexture-sprite-has-unexpected-smoothing-blurring/129394)).

  The Python pipeline can **generate normal maps from a per-sprite height map** (Sobel filter) at almost no cost. That is the realistic route to "a bit of 景深" with no artist. One team got a similar effect by lighting sprites with 3D lights placed above them ([xDasher devlog](https://pixel-beef.itch.io/xdasher/devlog/192949/4-things-we-did-to-add-light-and-depth-to-our-pixel-art-game)). Eastward's exact method is not documented publicly; forum posts only speculate ([itch](https://itch.io/post/9039152)).
- **Schedules in Godot:** use an NPC schedule as data, e.g. `{key:"Mon"|"rain"|"tier2"|flag, entries:[(time, map, tile, facing, anim)]}` (Stardew format). Off-screen NPCs are positioned **analytically from the schedule**, with no pathfinding when unseen. Pathfind with `AStarGrid2D` only on the current map.

### 5.2 Option B: fake 2.5D / HD-2D (Sprite3D billboards in a 3D diorama)
- **What HD-2D is:** pixel-art billboard sprites in fully 3D environments, with dynamic lighting, **depth of field and tilt-shift** for a diorama look, and point lights that let sprites cast shadows. It was built on Unreal Engine 4/5 by Square Enix and Acquire. Even they found it hard to make the 3D backgrounds sit naturally with the sprites ([HD-2D Wikipedia](https://en.wikipedia.org/wiki/HD-2D), [Unreal interview, Octopath II](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style)).
- **The Godot route:** `Sprite3D` with billboard (full or Y-billboard) in a 3D scene, rendered into a low-res `SubViewport` with nearest upscale and an orthographic or narrow-FOV camera. Problems:
  - **Y-billboards foreshorten under a high camera**; the fix is a narrow FOV plus Y-scaling ([forum](https://godotforums.org/d/41420-billboarding-with-sprite-3d-with-a-current-camera)).
  - **Sprites clip into 3D boxes** ([Q&A](https://ask.godotengine.org/87021/prevent-clipping-billboard-sprites-into-objects-for-5d-game)).
  - SubViewport blur appears unless *both* the canvas and the 3D materials use Nearest ([forum](https://forum.godotengine.org/t/subviewport-texture-is-blurry-but-settings-are-set-to-nearest/53477), [GDQuest pixel setup](https://www.gdquest.com/library/pixel_art_setup_godot4/)).
  - There are pixel-art 3D toolkits (BUKKBEEK's MIT "Godot Pixel Renderer", compositor edge-detection demos) ([80.lv](https://80.lv/articles/free-open-source-3d-to-pixel-art-toolkit-for-godot)).
- **Renderer constraints:** the project uses **GL Compatibility**, which is also the only web target, since WebGL2 has no Forward+ ([Web export docs 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)). Users have reported that Compatibility lacked 3D shadows and decals on web ([forum](https://godotforums.org/d/36011-godot-4-web-export-shadow-and-decal)). Some shadow support has landed since, so **[verify on 4.7]**. The signature HD-2D post effects (DOF, SSAO, volumetrics) belong to Forward+ and are limited or absent in Compatibility **[verify]**.

### 5.3 Recommendation for a small team with procedural Python art and no artist
**Choose Option A (2D 3/4 top-down) for the town and the interiors, and keep the existing 320×180 counter close-up as the "zoom-in" mode when you step behind the 高柜台.**

Reasons:
1. **Pipeline fit.** PIL plus `pixlib.py` with a locked 32-colour palette already produces 2D sprites and tiles at this exact scale. A town tileset (water, stone bridges, whitewashed walls, black tile roofs) is mostly **parametric rectangles plus patterns**, which is ideal for code-generated art. HD-2D would need 3D meshes, UVs, materials and lighting authored in code *and* billboard sprites to match, which doubles the art formats.
2. **Renderer risk.** HD-2D's look depends on post effects that are weak in Compatibility. Switching to Forward+ would give up the web build and the low-end hardware the project currently targets.
3. **Readability.** Owner item #1 (speech beside speakers) and the GameJev "space affects who hears whom" idea (EXT06) are both easiest to show in flat 3/4. Bubbles anchor cleanly, and partitions and earshot are visible on the tile grid.
4. **Depth when we want it.** Normal maps plus lantern lights plus a CanvasModulate night give Eastward-like mood cheaply. A later "diorama" pass can be added *for one hero location* (the pawnshop interior) without committing the whole game to 3D.
5. **Scope.** Stardew proves a solo developer can carry a full town in this format. HD-2D shipped from a large team using UE4's toolset.

What to prototype first: one 20×12-tile street with the pawnshop, 米行 and 茶馆, plus one interior; a door warp; three scheduled NPCs; CanvasModulate time of day; and bubble dialogue with typewriter blips. The blips can follow the Animal Crossing approach: one clip pitch-shifted per speaker plus small random jitter, and silence on punctuation ([Nookipedia](https://nookipedia.com/wiki/Animalese), [RPG Maker bleep plugin](https://winterbitestudios.itch.io/plugin-rpg-maker-mz-dialogue-bleep), [animalese crate](https://docs.rs/animalese)).

---

## 6. How to make this NOT a Probably Stolen clone

What Probably Stolen *is*, from the mechanics dump:
- **Day shape:** a single shop with three states (morning, open, closed) and a **stack of customers who come one at a time**.
- **Counter actions:**
  - drag items into buy, display, counter or scale zones;
  - per-item-type **inspection minigames** and a "confrontation" true/false verdict;
  - contraband and stolen-goods **heat**, with periodic inspectors, fines and bribes;
  - an in-shop shooting mode.
- **Systems around the shop:**
  - chemistry that reacts overnight;
  - machines and recipes;
  - expeditions and space-station raids;
  - faction reputations shown as emoji tiers.
- **Pressure:** rent, loan and mortgage countdowns.
- **Customer generation:** many independent sources with filters, cooldowns and attractiveness tiers.

Structural differences we should commit to:

| Axis | Probably Stolen | 德厚当 (new) |
|---|---|---|
| **Unit of play** | A queue at one counter | **A day in a town.** Route choices: where to be when (teahouse at dawn, 米行 before noon, counter in the afternoon, home by curfew). The counter is one location among many. |
| **Core object** | Items to flip | **Contracts over time** (当票: 当期/月息/续当/赎当/满当, plus the live-pawn gamble). The emotional payoff is *redemption day*, or its absence. |
| **Selling** | A display case in the same room | **Off-site channels:** 估衣铺/旧货摊 on market days, private buyers met in the teahouse, auctions of 满当 goods, consignment. This fixes owner #7. |
| **Customers** | A generated stack with cooldowns | **Townsfolk with schedules, homes, families and debts.** You meet them outside too (Stardew). Strangers arrive by boat. Absence is meaningful (GameJev EXT07). |
| **Law** | Inspector visits, contraband scans, arrests, guns | **Institutions as people:** a 巡长 who pawns his wife's bracelet, a 保长 who negotiates levies, the 维持会. Consequences are social and legal, not scan-and-fine. No shooting. |
| **Pressure** | Rent, loan and mortgage countdowns | **Variable household lines** (rice price, fuel, medicine, 人情, levies) with telegraphs and lagged consequences (§3.7). |
| **Information** | A morning report UI | **A rumour network** (teahouse), letters and telegrams, the newspaper. Hearsay vs. eyewitness (GameJev information chain). |
| **Inspection** | Many per-item minigames | **Few, deep tools:** magnifier, touchstone, abacus (owner #6), an appraisal book with collected pages (Strange Horticulture), an appraisal certificate as a sellable document (owner #5). |
| **Bargaining** | One customer, price-centred, a deal machine | **Multi-party and multi-term:** interest, term, guarantor (保人), people speaking for the customer (说情). Moves are unlocked by relationships (Potionomics), and no meters are shown. |
| **Progress** | Licences, machines, upgrades, network | **The town opens up:** buildings visible but closed, opened by time (the historical spine), by relationships (Stardew CC), or by your money or collaboration (Joja analogue). Year-end career choice (owner #9). Heirlooms (owner #13). |
| **Randomness** | Event schedule, faction actions, generator filters | **The GameJev world wheel** (exogenous/endogenous) plus building storylet decks plus a historical spine. Disasters never target the player. |
| **Tone and setting** | Sci-fi black comedy, chemistry, space | **1938 occupied Jiangnan:** ordinary life under pressure, collaboration dilemmas, the double-agent thread (Papers Please EZIC-style, owner #18). |

Also **avoid Probably Stolen's signature UI vocabulary**:
- a grid inventory with item rotation on the counter;
- a doorbell to call the next customer;
- pulling down a shutter to close;
- emoji reputation faces;
- a confrontation true/false verdict screen;
- per-item minigame screens.

Replace them with:
- the abacus and the ledger;
- the 当票 writing desk;
- 高柜台 framing;
- comic bubbles in the world;
- a 人情簿.

### Owner-list cross-reference (where the research helps)

| # | Owner item | Reference pattern |
|---|---|---|
| 1 | Dialogue beside speakers | In-world anchored bubbles (§5.3) |
| 2 | Typewriter sound | Per-speaker pitch blips (§5.3) |
| 3 | Perpetual calendar | Stardew calendar with festivals and birthdays, plus the 1938 spine (§1, §3.6) |
| 5 | Manual appraisal | Strange Horticulture book plus inspection |
| 6 | Abacus | A diegetic calculator; quoting aloud |
| 7 | Never selling | Moonlighter shelf plus off-site channels |
| 9 | Change profession | Kynseed generations / year-end 盘点 |
| 10 | Live pawn and extensions | 续当 rules (Giles: 16 months Qing, 小押 3 months) |
| 11 | Mystery box | Strange Horticulture puzzle |
| 13 | Late-game valuables, heirlooms | PRD / bag for rare finds (§3.4); Kynseed |
| 14 | Unify prices | Pathologic 2's base price with a ±10% spread |
| 15 | Interaction while bargaining | Potionomics moves without meters |
| 17 | Relationship visualisation | 人情簿, letters and telegrams instead of hearts |
| 18 | Double agent | Papers Please EZIC |

---

### Appendix: research limitations
- Every page fetch was denied by the egress proxy, so quotes come from search-engine excerpts. Several numbers (Stardew birthday ×8, base energy 270, Pierre's hours, Moonlighter 2 price bands, pawnshop staff titles, 小押 details, the Compatibility-renderer feature list) are marked **[verify]**.
- Chinese-language historical coverage was weak: there were no Jiangnan-specific 1930s pawn regulations, and no 1938 town-level 维持会 records. Before writing setting text, read Yang Zhaoyu's *中国典当业* (1929), Brook's *Collaboration* (chapters on Jiading and on the 1938 Reformed Government), Wakeman's *Shanghai Badlands*, and Zhu Xiaotian on Jiangnan teahouses.
