# R2 · 局外传承「旧账」设计稿（两局之间带过去什么）

> 角度：**局与局之间**（meta-progression）。另两位设计师管局内的肉鸽元素，本稿只管“一局结束以后留下什么、下一局怎么不一样”。
> 状态：提案，不是合同。HANDOFF §5.4 写明 N06 的“局外传承会改变跨局结构，要主创逐项定取舍”，N01–N06 动工前要主创先写进 DESIGN。所以本稿第一件事是请主创拍板（§13），然后由 Claude 写进 DESIGN §十、合同 1.6。
> 依据：`docs/cards/DESIGN_cards.md`、`docs/cards/CARDS_INTERFACES.md`（1.5）、`HANDOFF.md`、`scripts/cards/**`、`data/cards/**`、归档 `archive/cards/N03-relic-month` `N04-dossier-infer` `N05-people-by-year` `N06-meta-pack`。
> 写法：名词和 id 照代码原样；玩家看得到的字一律是**键**，正文归 A（人写），AI 只在 `text_ai/**` 放基础层占位。

---

## 0. 一页结论

- **一局 = 一本账。** 局终（被抓没出来）、收尾（1940 三月月底）、或者玩家自己“另起一本”，这本账就**合上**，放上书架。书架上的账越摞越高，合起来叫**旧账**。
- **带过去的只有四样，没有一样是“更多的钱、更高的数”：**
  1. **知道的**：旧墨档案（所有账里见过的碎片）、主线谱（每个主线节点走过哪几条路）、对上了（跨几本账才凑齐的推理）。
  2. **能选的开头**：出身（不同的起手处境，含从 1939、1940 开头）、随身（最多带一件传家之物）、年景（通关后自选的难处）、只记一个月（短局）。
  3. **镇上多出来的**：只有旧账里知道了某件事，镇上才会出现的人和事；以及**知情回话**——对话里多一句只有“知道内情”才说得出口的话。
  4. **铺史**：每本账合上时写下的一两行“德厚当这些年”。
- **不带过去的**：钱、货、当票、人脉、属性、口碑风声、局内拿到的任何东西。没有货币、没有经验值、没有“局外商店”。N06 提案里的 `start_money_delta`（局外加钱）**不采用**：它就是刷。
- **引擎做法**：开局时外壳把档案文件里“这本账能用的东西”编成一个**本局上下文**，经 `game.new` 的新参数 `run` 交给引擎，冻结在状态的新命名空间 `state.data.run` 里。引擎**从不读档案文件**；局内只认 `run`。档案文件 `profile.json` 和局内存档分开放，只由外壳写。
- **零传承 = 今天的游戏**：`opts.run` 不给或为空时，状态里不出现 `run`，哈希与现在逐字相同——现有黄金种子不用重算（§10）。
- **先做什么**：先修一个小毛病（标题上每次“开张”都是种子 7，每局一模一样），然后做“知道的会留下”：档案文件 + 合账画面 + 档案簿里的旧墨。出身和年景放第二、第四波。

---

## 1. 读代码得到的事实（它们决定了这份设计的形状）

| # | 事实 | 在哪 | 对本设计意味着 |
|---|---|---|---|
| F1 | 标题上点“开张”永远用种子 7：`var options := {"seed": int(_opts.get("seed", 7))}` | `scripts/cards/ui/table/card_game_root.gd` `_start()` | 现在每一局完全一样。任何肉鸽都要先改这里（§4.1、包 L02） |
| F2 | 档案簿 36 页、362 块碎片。16 个主要人物里有 **9 页**含有“同一张牌不同选项各给一块”的互斥碎片，**一局里补不齐**：`dp.brother`（`df.brother.1938.farewell` / `farewell_cold`）、`dp.chen`、`dp.hu2`、`dp.linsao`（`term` / `forfeit`）、`dp.ma`、`dp.postman`、`dp.sunlaoye`、`dp.wangshan`（`met` / `turned`）、`dp.zhao` | `data/cards/dossier/pages.json` + 各年 `story.json` | 数据**本来就长成了“要好几局才拼得完”的样子**。而这 9 页的 `on_complete`（林嫂、陈文庭、马万利、王山、何启明成人脉等）局内永远不会触发——这是要顺手修的数据问题（§4.2 `alt_groups`） |
| F3 | 不算 `year_after`，有 104 块碎片没有任何牌用 `dossier` 效果给出：`df.*.quiet` 这种“信任那一层”只被交消息时变成缺口、从来拿不到；其中 69 块（多是 `nf*`、`stranger_*`、几块 1939/1940 的）连任何牌都没提到 | 同上 | 这些页局内、跨局都补不齐。以“全本”为条件的解锁要等 K08 补完；首版改用“这一页旧账里有 ≥ n 块”（§5.5 `page_known_gte`） |
| F4 | 存档只有 `stage_%02d.json`（每关开头）和 `suspend.json`（每天早上），在 `CardSave.root()` 下，**不记是哪一局**；`ui` 命名空间不进哈希、读档时取并集 | `card_save.gd`、`card_state.gd`、`core_install.gd` `merge_ui` | 有“状态外、哈希外”数据的先例；开新局会盖掉旧局的续玩点，要管（§4.1）。`game.new` 本来就收 `stage` 参数，从 1939 开头很便宜 |
| F5 | 局终两种：`close_month` 里最后一关结完 → `finish_game(ctx, "ending")`；牢房 `pr.cell` 的 `check.on_fail` → `game_over`，原因 `prison`。局终画面只有一个正文键 `g02.ending.<reason>`，按钮：重来本关 / 续玩 / 回标题 | `day_loop.gd`、`common/prison.json`、`ui/month/game_over.gd` | 要在局终画面加“合账”，并给合账一个更细的“这本账怎么合上的”（铺史，§4.11） |
| F6 | 牌库先按 `conditions` 筛、再按权重抽（`CardWeights.rows`）；日程的 `when` 对单日 `stage_day` 也起作用（`CardSchedule._matches`） | `fate/weights.gd`、`loop/schedule.gd` | 加一批“没解锁就不进牌库”的牌，**不改变**没解锁时的抽牌结果——零传承恒等成立 |
| F7 | 条件不满足的选项照样列出来、变灰，原因键 `g03.reason.condition` | `rules/choices.gd` `options()` | “知情回话”要能**整句藏起来**，否则灰着的回话本身就剧透（§4.4 `knowing`） |
| F8 | `ctx.rules(name)` 是所有数值读取的唯一入口；`balance_overrides.json` 已有“只换已有键、不改类型”的深合并 | `core/card_ctx.gd`、`core/card_db.gd` `_merge_override` | 出身和年景的数值改动用**同一种深合并**叠在本局上，不加新代码路径（§4.6、§4.8） |
| F9 | 第一关第 1–3 天是教学日：`deal.json` 的 `scripted_days: {"0": [1, 2, 3]}`，`era/1938/tutorial.json` 11 张按日程发的教学牌 | | 每局都要重新被教三天，是重玩的“税”。用“懂行的出身”在戏里免掉（§4.6 `og.shanghai`） |
| F10 | 20 个主线节点、约 70 种走向（`s1938.wangshan`：`helped` `turned` `ignored`；`s1940.sunfu_stance`：`with_sun` `apart` `hedge` `ignored`……） | 各年 `story.json` 等 | 主线谱一局最多走一条，5 种走向的节点要 5 本账才走全——天然的 5–10 局骨架 |
| F11 | 10-22 平衡报告：只按打烊的 refuser 三关 20/20 全过，主动经营反而难；买卖差价很薄 | `docs/cards/balance/report_2026-10-22_framework.md` | 局外传承**不能**再给原始实力，否则平衡更糟；出身只做“换一种难处”（§9） |
| F12 | N03（镇店之宝，月底三选一）是**局内**被动物；N04 档案推理是局内加口碑风声；N05 是数据索引 | 归档 | N03 的宝不跨局；N04 的六条推理原样搬来做**跨局**的“对上了”，奖励换成故事（§4.5） |

---

## 2. 原则

1. **带过去的是“知道的”和“能选的开头”，不是“更强的数”。** 每个解锁都能用一句话讲成故事（“她在上海银楼学过三年徒”），讲不成故事的不做。
2. **一本账自成一局。** 开局时把旧账“抄进”这本账（`state.data.run`），抄完就冻结；局内拿到的新东西只写进档案文件，**下一本**才用得上。
3. **第一本账和今天的游戏一样。** 没有解锁任何东西之前，不出现开局画面、不多一个选择；只多一个“合账”按钮。
4. **每本账至少翻出一样新东西。** 没有新碎片、新走向、新解锁的那一本，合账时给一句“下一本可以留意”的提示（§4.13）。
5. **每个出身换一种难处，不是全面更好。** 随身最多一件。年景只加难，奖励只有铺史上的朱印。
6. **隐藏的照旧隐藏**（红线 3）：概率、权重、本心、口碑风声点数、底价真假，开局画面和合账画面一样不给。
7. **重来本关、续玩照旧可用**（DESIGN §三.8、§九.5）。旧账只增不减：重来以后，刚才见过的碎片照样记在旧账里——知道了就是知道了。

---

## 3. 玩家体验：十本账

> 时长按“熟手一天 3–4 分钟”估：一关 30 天约 1.5–2 小时，三关一局约 5–6 小时。**这个数要实测**（§9 R10）；本设计用“从 1939 / 1940 开头”和“只记一个月”把一局压到 1.5–2 小时，所以不依赖它。

| 本 | 怎么开头 | 这一本里发生的 | 合账时留下 | 玩家此刻的感受 |
|---|---|---|---|---|
| 1 | 没有开局画面，直接“开张”（`og.default`，种子 7，和今天完全一样） | 哥哥教三天；听完交代；拼好一九六号当票；收留王山；腊月里风声到顶被抓，重来本关一次还是没出来 → 局终画面点“合账” | 铺史第一行（腊月被抓）；旧账里 40 来块碎片；主线谱 1938 的 6 个节点各走了一条；解锁：`og.shanghai`（走过了教学日）、`og.1939`（到过腊月） | “原来这是一本一本记下去的账。” |
| 2 | 第一次见到“另起一本”画面，选**上海学过徒**：眼力 3、门路 0、钱少 40，没有教学日 | 档案簿里林嫂那页有一行淡墨（上一本听来的“她男人在船上”）；第 16 天林嫂来处理当期，对话里多了一句带朱笔圈的回话——“问起她男人的船”；这一本和哥哥争了几句 | 一条新走向（`s1938.brother_farewell = argued`）、林嫂一块新碎片；到了 1940 三月**收尾** → 年景解锁、`kp.silver_keepsake`（这本账合上时手里留着娘家的银饰）成了随身之物 | “上一本知道的事，这一本用上了。” |
| 3 | 选**腊月接手**（`og.1939`）+ 只记一个月：一个半小时的短账 | 专门去追哥哥的第一封信（这次压下不拆），和邮电代办那块“信走过的路” | 旧账里第一回**对上了**：`ded.ticket196`——一九六号当票、哥哥的信、陈文庭那半张票、邮差的路，四本账里零零碎碎，这一本补上最后一块；批注一句（A 写）；解锁随身 `kp.hl.stub196`、镇上会多一个来打听一九六号的生人 | “故事是拼出来的，不是一局讲完的。” |
| 4 | 原来的开头 + 随身“银饰” + 年景“苛捐” | 这一本把王山交了出去，看他 1939 年那条线怎么断；1940 年在牢里没出来 | 王山一页的另一半（`df.wangshan.1938.turned`）；铺史第二种死法；苛捐没收尾，不盖印 | “换个选择，就是换一个人的下场。” |
| 5 | **周妈的干女儿**（周妈那页旧账里已有 8 块以上才出现）：第 1 天周妈就是人脉、口碑高一档 | 1940 年三月，第一次出现那个来问一九六号的生人（只有对上过 `ded.ticket196` 才进牌库）；收尾 | 新的铺史结局行（跟孙府“两头不靠”）；周妈一页全本 | “镇上的人记得我（虽然是另一本账）。” |
| 6–8 | 自由组合：三种出身 × 一件随身 × 年景；挑没走过的路 | 主线谱里空着的格子越来越少；几本短账专门补 1939 腊月 | 对上第 2–5 条推理；年景朱印 | 像 Hades 一样，每一本都在补一块大图 |
| 9–10 | 带三四个年景打一本完整的三关 | 最大的那条推理 `ded.de196_whole` 要“听完交代 / 和他争”“信还暖 / 信冷了”“跟去 / 封起来”三对互斥的路都走过——至少两本收尾的账才凑得齐 | 铺史最后一行（A 写，首发版的“这些年”收束）；书架上那摞账的最上面一本盖金印 | 首发三关的故事在旧账里讲完了；1941 起的更新接着往书架上摞 |

节奏目标（给 K14 / 平衡用的验收口径，【待调】）：**第 5 本账结束时**，主线谱 1938 的走向见过 ≥ 60%、至少对上过 1 条推理、至少解锁 3 个出身；**第 10 本**见过全部节点的 ≥ 80% 走向。

---

## 4. 规则

### 4.1 一本账的一生

```
标题「另起一本」 ─(有解锁才出开局画面)→ 开局画面（出身 / 随身 / 年景 / 只记一个月）
      → engine.new_game({seed, stage, run})          …… 这本账开着（profile.current.status = "open"）
      → 每天早上自动存档时：外壳 query("legacy.harvest") → 并进旧账（只增不减）
      → 局终 game_over（prison） ─┬─ 重来本关 / 续玩：还是这本账
                                  └─ 合账 ──────────┐
      → 收尾（ending；或只记一个月到月底：act_end）──→ 合账画面 → 放上书架 → 标题
标题「另起一本」时还有一本开着：先确认（“这本账还没记完，就这样合上？”），按 abandoned 合上
```

- **一本账的身份**：`profile.current = {no, seed, status}`；局内状态里 `run.no` 同号。标题上“接着记”只在 `suspend.json` 存在**且** `state.run.no == profile.current.no` 且这本账还开着时可点。
- **合账**做三件事：最后一次 `legacy.harvest {close: <原因>}` 并进旧账、写一条铺史、**删掉** `suspend.json` 和 `stage_*.json`（这本账再也续不上，书架上只留记录）。
- **种子**：第一本账固定 `7`（今天的种子，新手体验可控，指引走查不用改）；第二本起 `seed = 1 + floor(JevRng.draw(profile.salt, "m.run.seed", [run_no]) × 2147483646)`，`salt` 默认 0。**不读墙钟**（红线 2）；同一份档案、同一本号，种子永远一样，测试可重现。命令行 `--seed=N` 照旧优先。
- **旧存档**：第一次带着旧账功能启动时，如果已经有一个不带 `run` 的 `suspend.json`，就把它认作第一本账（`profile.current = {no: 1, status: "open"}`），不丢进度。

### 4.2 旧墨：档案簿跨局（知道的①）

- **旧账记什么**：每块碎片第一次在哪本账里拿到（`frags: {id: run_no}`）。缺口不记——这一本撕掉了，不等于你不知道。
- **局内怎么显示**（C10 档案簿）：开局时冻结的 `run.known` 里有、这一本还没拿到的碎片，画成**淡墨**（`ink_soft`、减淡、页角一个小“旧”字印）；这一本已经撕成缺口、旧账里却有的，画成撕痕底下透出一点淡墨字——“撕掉的地方，旧账上还看得见”。
- **淡墨不算数**：这一本的补齐（`on_complete`）、`dossier_has` 条件、N04 式的局内推理，全部只认这一本拿到的。旧墨只给玩家看、给“知情”条件用（§4.4）。
- **两种“齐”**：这一本补齐 = 朱印“齐”（照旧，触发 `on_complete`）；旧账里每一块都见过 = 金字“全本”（只在旧账和档案簿页眉上显示，没有局内效果）。
- **顺手修 F2**（包 L03 + K08）：`dossier_page` 加可选字段 `alt_groups`（互斥的几块算一个位子）。**局内补齐**时每组有一块就算；**全本**要每块都见过。这样 9 页主线人物局内终于补得齐，全本仍要好几本账。

### 4.3 主线谱（知道的②）

- 旧账记每个主线节点走过哪些走向：`story: {node: {outcome: run_no}}`，来自状态 `rules.story`。`ignored`（没理他）、`left`（等不及走了）也算走过。
- 旧账画面的“主线”栏按年份列节点；走过的走向盖上走向名（A 写的短名），没走过的是空格子（是否显示空格子见 §13 D3）。
- 主线谱只给玩家看、给解锁条件用（`seen`、`seen_count_gte`），**不改局内任何东西**。

### 4.4 知情回话（知道的③，局内的直接体现）

- 选项（Choice）加一个字段 `knowing: true`：条件不满足时**整句不出现**（不是变灰）；满足时照常列出，回话前面画一个朱笔小圈（`icon.knowing`），告诉玩家“这是你知道内情才说得出口的”。
- 条件用新条件 op `knows`：这块碎片在开局冻结的 `run.known` 里，**或者**这一本已经拿到了。所以同一本账里先听来的事，后面也能用上；上一本听来的，这一本一样能用。
- 知情回话是**另一条路**，不是更好的路：它给一块新碎片、一条新走向、或一句只有这里才有的话；钱、口碑风声的得失和别的回话同一量级（§9 R3 审读）。
- 被藏起来的选项走 `card.choose` 会得到 `no_such_choice`（不是 `cond_failed`），连“这里有个藏着的选项”都不漏。

### 4.5 对上了：跨局推理（知道的④）

- 一条推理 = 一组碎片（`requires`，合取）。旧账里（所有账加起来）凑齐了，就“对上了”，旧账里多一页批注（A 写的一两句：这几样东西放在一起说明了什么）。
- **局内也会发生**：每晚日结（`settle` 钩子，priority 65，在 G02 写日结报告 70 之前），引擎看 `run.known ∪ 这一本拿到的` 有没有凑齐一条还没对上过的推理；凑齐了就在日结里说一行（`l01.notice.ded`），档案簿多一页批注，发 first-time `deduction`。这一刻的“啊——”留在戏里。它对这一本**没有别的效果**；解锁从下一本起生效。
- 首版：N04 的六条（`ded.rice_kitchen` `ded.deed_unclaimed` `ded.levy_runner` `ded.dock_word` `ded.code_chain` `ded.ticket196`，`requires` 都是已存在的碎片），奖励从“口碑 +1 / 风声 +2”改成故事和解锁；外加一条大的 `ded.de196_whole`（要三对互斥碎片，见 §3 第 9–10 本）。

### 4.6 出身（能选的开头①）

开局画面选一个；**只用已有的效果 op 和规则深合并**，不加新 op。首版五个：

| id | 叫法（A 定字） | 从哪天开头 | 和原来比 | 怎么解锁 |
|---|---|---|---|---|
| `og.default` | 哥哥的铺子 | 1938-03-01 | 原样（教学日、哥哥第 2 天告别） | 永远有 |
| `og.shanghai` | 上海学过徒 | 1938-03-01 | 懂行：**没有第 1–3 天的教学日**（`scripted_days` 置空、第 1–3 天的 8 张教学牌不发；第 5–7 天那 3 张算命先生、周妈的牌照发与否由 K16 逐张定），眼力 +1、门路 −1、开局钱 300；哥哥第 2 天照样告别 | 任何一本账走到过 1938 第 4 天早上 |
| `og.zhouma` | 周妈的干女儿 | 1938-03-01 | 第 1 天周妈就是人脉（每天多一张消息）；口碑高一档；风声起点高一点；第 7 天的“周妈成人脉”教学牌不发 | 周妈那页旧账里有 ≥ 8 块 |
| `og.1939` | 腊月接手 | 1940-01-09（1939 腊月） | 第二关开头；1938 按一个“平平过来”的版本写进状态（听完交代、拼好一九六号、周妈是人脉、几块碎片），钱按第二关物价给【待调】；不教学 | 任何一本账到过 1939 腊月 |
| `og.1940` | 三月接手 | 1940-03-01 | 第三关开头，同上【待调】 | 任何一本账到过 1940 三月 |

- `veteran: true` 的出身（`og.shanghai` `og.1939` `og.1940`）免掉教学日；指引的进度从旧账里带进来（`ui` 命名空间，不进哈希），教过的不再亮。
- 二期可做“接着某一本旧账的 1938”：从书架上挑一本到过腊月的账，按它的主线走向开 `og.1939`。首版不做。

### 4.7 随身（能选的开头②）

- 开局时最多带**一件**传家之物：一张留着的牌，第 1 天早上就在留牌区。它占五个留牌位里的一个。
- 首版三件：

| 牌 | 是什么 | 怎么解锁 |
|---|---|---|
| `kp.silver_keepsake`（已有） | 娘家的银饰信物：`family` 格子多 1 枚铜钱，不消耗 | 某本账合上时手里留着它（局内是 1940 年哥哥来信 `read_on` 给的） |
| `kp.hl.ledger`（新） | 旧账本的一页：`pawn` 格子多 1 枚铜钱，不消耗 | 第一次对上一条推理 |
| `kp.hl.stub196`（新） | 一九六号的存根：`official` 格子算 2 个正面，用一次就没 | 对上 `ded.ticket196` |

- `kp.brother_note` 不做随身（第 2 天听完交代还会再发一张，重复）。

### 4.8 年景（通关以后的难处）

- 第一次收尾（`ending`）以后，开局画面多一排“年景”，可以任选几样。每样都是**规则深合并**，写在数据里：

| id | 叫法 | 改什么（已有键） |
|---|---|---|
| `hard.levy` | 苛捐 | `demand_rules.tier_by_stage`：`[0,1,1]` → `[1,1,2]`（胡二的条子从第一关就是中档） |
| `hard.lean` | 荒年 | `loop.life_per_week`：`{1,2}` → `{2,3}`（生活牌多） |
| `hard.watch` | 查得严 | `meters.heat.decay_per_day`：`1` → `0`（风声不自己落） |
| `hard.alone` | 无人作保 | `fate.big.max_per_stage`：`2` → `1`（大轮盘每关只来一次） |
| `hard.dear` | 米贵 | `economy.month_expenses`：`30` → `45`（月底家用多，钱数看得见） |

- 画面上只写戏里的话（“这一年，胡二的条子从头就不轻”）和看得见的钱数，不写“+30%”。
- **奖励只有铺史上的朱印**：带着某个年景收尾，那本账的书脊上盖一个印；旧账条件 `hard_cleared` 只用来解锁铺史的纪念行，不给实力。
- 二期备选 `hard.iron`“一本到底”：局终画面不给“重来本关 / 续玩”，只能合账（要主创按红线 9 判，§13 D5）。

### 4.9 只记一个月（短局）

- 第一次合账以后，开局画面多一个开关“只记一个月”：这本账在出身那一关的月底就收尾（原因 `act_end`），不跳年。配 `og.1939` 就是一本专门补腊月的短账。
- 实现：G02 的“是不是最后一关”改成问 `CardDayLoop.is_last_stage(ctx)`（看 `run.end_stage`），`close_month` 和收徒的结局前窗口都用它。

### 4.10 镇上多出来的（新面孔、新事件）

- 一张牌的 `conditions` 写 `{"legacy": "lg.card.xxx"}`：开局时这条解锁在，它才进牌库或按日程发；不在，它根本不上表（F6，抽牌结果不变）。
- 首版五张（新数据文件 `data/cards/legacy/cards.json`）：1939 码头船户捎信（`lg.card.boatman`：知道林嫂丈夫和街坊那两块）、1940 来打听一九六号的生人（`lg.card.stranger196`：对上 `ded.ticket196`）、1940 陈文庭那张对得上的电码页（消息，`lg.card.chen_code`：对上 `ded.code_chain`）、1939 王山的妹妹（`lg.card.wangshan_sister`：`s1938.wangshan` 三种走向都走过）、1940 赵老三家的地（事件，`lg.card.zhao_field`：借过也拒过赵老三）。每张都带新碎片，所以旧账还能长。

### 4.11 铺史

- 合账时引擎按数据挑铺史行：`end` 组恰好一行（这本账怎么合上的），`people` 组至多三行（几个人的下落）。条件用局内条件（可以用本心——DESIGN §三.9 本来就让本心决定结局文字），玩家只看到挑出来的句子。
- 每个合上的原因（`ending` `prison` `act_end` `abandoned`）× 年代都有一行兜底，校验器查。
- 书架上一本账一根书脊；铺史在旧账画面“铺史”栏按本号排。

### 4.12 熟人三档（不另存，从旧账推出来）

| 档 | 什么时候 | 用在哪 |
|---|---|---|
| 认得 | 旧账里有他的碎片 | 旧账人名索引里出现 |
| 熟人 | 某本账合上时他是你的人脉 | 条件 `contact_end` |
| 知根知底 | 他那页旧账里有 ≥ n 块，或全本 | 条件 `page_known_gte` / `page_full`；首版用来开 `og.zhouma` |

页眉上写这一档的字，不写块数。

### 4.13 每本账至少一样新东西（提示保底）

合账时如果这一本没有新碎片、新走向、新推理、新解锁，就从“旧账里走过一部分、还有没走过的走向”的主线节点里按 `JevRng.draw(profile.salt, "m.hint", [run_no])` 挑一个，给一句 A 写的提示（`l04.hint.<node>`，例：“那天要是没把他交出去……”）。只说是哪件事，不说怎么做。

### 4.14 看得见 / 看不见

| 看得见 | 看不见 |
|---|---|
| 出身的开局钱、四项本事点数、带着的牌、认得的人、从哪一天开头 | 年景改了哪个权重、改了多少百分比 |
| 年景的名字和戏里的一句话；“米贵”的家用钱数 | 解锁条件的具体写法（只给 A 写的模糊提示） |
| 旧墨碎片的正文（你见过的） | 你没见过的碎片正文 |
| 主线走向名（你走过的） | 本心、口碑风声点数、铺史是按什么条件挑的 |
| 本号（第几本账） | 种子（合同 §7.5 黑名单里的 `seed`；本号不是种子） |

---

## 5. 数据格式与例子

> 全部整数、ASCII id、`brief` 以外不许有中文（合同 §4.1–§4.3）。新目录 `data/cards/legacy/`（主人 L04），`CardDB.CARD_DIRS` 加 `"legacy"`；新类型 `origin` `hardship` `legacy_unlock` `deduction` `chronicle_line` 加进 `CardIds.TYPES`。新规则文件 `data/cards/rules/legacy.json`（主人 L01）。例子集 `data/cards/_examples/legacy/` 由 Claude 照本节放。

### 5.1 档案文件 `<存档根>/profile.json`（外壳写；引擎不读）

```json
{
  "format": "dehoudang-cards-profile", "v": 1, "salt": 0,
  "runs_started": 4, "runs_closed": 3,
  "current": {"no": 4, "seed": 1844671223, "status": "open"},
  "frags": {"df.linsao.1938.hairpin": 1, "df.linsao.1938.husband": 1, "df.brother.1938.farewell_cold": 2},
  "story": {"s1938.brother_farewell": {"listened": 1, "argued": 2}, "s1938.wangshan": {"helped": 1, "turned": 4}},
  "reached": {"0": 30, "1": 30, "2": 18},
  "closed": {"prison": [1, 4], "ending": [2], "act_end": [3]},
  "carried": {"kp.silver_keepsake": [2]},
  "contact_end": {"zhouma": [2, 3], "chen": [2]},
  "lg_flags": {"lg_hid_ledger": 3},
  "deds": {"ded.ticket196": 3},
  "unlocks": {"lg.og.shanghai": 1, "lg.og.1939": 1, "lg.hardships": 2, "lg.hl.silver": 2, "lg.hl.stub196": 3},
  "hard_cleared": {"hard.levy": [2]},
  "chronicle": [
    {"no": 1, "origin": "og.default", "keepsake": "", "hard": [], "single_act": false, "reason": "prison",
     "at": {"stage": 1, "era": "1939", "stage_day": 17, "y": 1940, "m": 1, "d": 25}, "lines": ["ch.end.prison.1939", "ch.people.wangshan.helped"]}
  ],
  "guide": {"gd.d1.deal": {"shows": 1, "status": "done"}},
  "notes_seen": {"l05.note.pick": true, "l05.note.close": true}
}
```

- 只有集合与“第几本第一次”，**没有可以攒的数**。`absorb` 是并集：同样的收获并两次 = 并一次；先后顺序无所谓。
- 写法照 `CardSave.write`：全精度 JSON、先写 `.tmp` 再改名；每次成功写完另留一份 `profile.bak.json`。读坏了 → 改名 `profile.broken.json`、退到 `.bak`、再不行就新建，标题上说一句（`l05.title.profile_reset`），不挡开张。
- 路径跟 `CardSave.root()`：正常 `user://cards/profile.json`；测试一律在 `user://test/<名字>/` 下，互不干扰。以后 Steam 云存档同步这个文件。
- 数据改版：档案里认不得的 id（被删掉的牌）保留不动、编本局上下文时滤掉。

### 5.2 本局上下文：`game.new` 的 `run`，和状态里的 `run`

外壳编好交给引擎（`CardProfile.compile`）：

```json
{"seed": 1844671223, "stage": 0,
 "run": {"no": 4, "origin": "og.shanghai", "keepsake": "kp.silver_keepsake",
         "hard": ["hard.levy"], "single_act": false,
         "unlocks": ["lg.card.boatman", "lg.hardships", "lg.og.1939", "lg.og.shanghai"],
         "known": ["df.brother.1938.de196", "df.linsao.1938.husband", "df.linsao.1938.neighbors"],
         "deds": ["ded.ticket196"]}}
```

引擎校验后写进状态（主人 L01；数组都排好序；`rules` 是引擎按 `origin` + `hard` 的定义算出来的深合并覆盖，存进状态是为了任何从这份状态建出来的 `CardCtx`——包括 `CardSchedule._project` 的投影——读到的规则都一样）：

```json
"run": {"_v": 1, "no": 4, "origin": "og.shanghai", "keepsake": "kp.silver_keepsake",
        "hard": ["hard.levy"], "single_act": false, "start_stage": 0, "end_stage": 2,
        "unlocks": ["lg.card.boatman", "lg.hardships", "lg.og.1939", "lg.og.shanghai"],
        "known": ["df.brother.1938.de196", "df.linsao.1938.husband", "df.linsao.1938.neighbors"],
        "deds": ["ded.ticket196"], "found": [], "applied": true,
        "rules": {"deal": {"scripted_days": {"0": []}}, "economy": {"start_money": 300},
                  "demand_rules": {"tier_by_stage": [1, 1, 2]}}}
```

- `opts.run` 没给或是 `{}` → 状态里**没有** `run` 键（零传承恒等，§10 T1）。L01 登记的钩子、修正项在没有 `run` 时一律什么都不做：不写状态、不发 first-time、不交 `view_section`；`veteran` 条件为假、`legacy` `knows` `origin` `hardship` 为假。教学牌加的 `when: {"not": {"veteran": true}}` 因此恒真，发牌和今天一样。
- 校验（不过返回 `bad_args`）：出身、年景、随身、解锁、碎片、推理 id 都存在；`stage == 出身.start_stage`；随身在 `unlocks` 授予的范围里；规则覆盖按 `_merge_override` 的规矩（只换已有键、不改类型）。
- `run` 在 `game.new` 的参数里，所以指令日志第一条就带着它，`CardReplay.replay(opts, …)` 原样重现。`command_done` 发给界面前照旧过 `_visible_args`。

### 5.3 收获 `query("legacy.harvest", {close?})`（只读，L01）

```json
{"ok": true, "err": "", "no": 4, "phase": "game_over", "reason": "prison",
 "at": {"stage": 2, "era": "1940", "stage_day": 18, "y": 1940, "m": 3, "d": 18},
 "reached": {"stage": 2, "stage_day": 18},
 "frags": ["df.linsao.1938.boat_word", "df.wangshan.1938.turned"],
 "gaps": ["df.zhao.1938.borrow"],
 "pages_complete": ["xiaoding"],
 "story": {"s1938.brother_farewell": "listened", "s1938.wangshan": "turned"},
 "contacts": ["chen", "zhouma"], "kept": ["kp.silver_keepsake"],
 "lg_flags": ["lg_hid_ledger"], "deds": ["ded.code_chain"],
 "chronicle": ["ch.end.prison.1940", "ch.people.wangshan.turned"]}
```

- 不给 `close` 时没有 `chronicle`（每天早上的收获用这个）；给了（`ending` `prison` `act_end` `abandoned`）才挑铺史行。
- 结果过 `CardViewModel.leaks()`；查询前后 `state_hash()` 不变。
- `lg_flags` 只收 `rules.flags` 里以 `lg_` 开头的旗——数据作者用它表示“这件事值得记进旧账”（例：某张事件牌“把账簿藏进夹墙”置 `lg_hid_ledger`）。

### 5.4 出身 `data/cards/legacy/origins.json`

```json
{
  "_meta": {"owner": "L04", "schema": 1, "brief": "出身：另起一本账时选一个。只用已有效果 op 与规则深合并。"},
  "cards": [
    {
      "id": "og.default", "type": "origin", "era": ["1938"], "weight": 0,
      "start_stage": 0, "veteran": false, "unlock": "", "order": 0,
      "rules": {}, "effects": [],
      "show": {"date": "1938-03-01", "money": 340, "attrs": {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1},
               "kept": [], "contacts": [], "rep_tier": 0, "heat_tier": 0},
      "art": "illus.og.default",
      "brief": "哥哥的铺子：原来的开局。第 1 到 3 天哥哥在柜台教，第 2 天告别。永远能选。",
      "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}
    },
    {
      "id": "og.shanghai", "type": "origin", "era": ["1938"], "weight": 0,
      "start_stage": 0, "veteran": true, "unlock": "lg.og.shanghai", "order": 10,
      "rules": {"deal": {"scripted_days": {"0": []}}, "economy": {"start_money": 300}},
      "effects": [
        {"op": "attr", "who": "ruhua", "attr": "eye", "delta": 1},
        {"op": "attr", "who": "ruhua", "attr": "pull", "delta": -1}
      ],
      "show": {"date": "1938-03-01", "money": 300, "attrs": {"eye": 3, "tongue": 1, "pull": 0, "nerve": 1},
               "kept": [], "contacts": [], "rep_tier": 0, "heat_tier": 0},
      "art": "illus.og.shanghai",
      "brief": "在上海银楼学过三年徒：眼力高一点，镇上门路少一点，带的钱少一些。她懂行，没有教学日，哥哥第 2 天照样告别。",
      "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}
    },
    {
      "id": "og.1939", "type": "origin", "era": ["1939"], "weight": 0,
      "start_stage": 1, "veteran": true, "unlock": "lg.og.1939", "order": 30,
      "rules": {"economy": {"start_money": 420}},
      "effects": [
        {"op": "story", "node": "s1938.brother_farewell", "outcome": "listened"},
        {"op": "person_state", "person": "brother", "state": "gone"},
        {"op": "add_card", "card": "kp.brother_note", "to": "kept"},
        {"op": "dossier", "frag": "df.brother.1938.farewell"},
        {"op": "story", "node": "s1938.ticket196", "outcome": "pieced"},
        {"op": "flag", "key": "k01_ticket196_pieced", "value": true},
        {"op": "dossier", "frag": "df.brother.1938.ticket196"},
        {"op": "contact_gain", "person": "zhouma"}
      ],
      "show": {"date": "1940-01-09", "money": 420, "attrs": {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1},
               "kept": ["kp.brother_note"], "contacts": ["zhouma"], "rep_tier": 0, "heat_tier": 0},
      "art": "illus.og.1939",
      "brief": "腊月接手：从第二关开头。1938 年按平平过来写进状态：听完交代、拼好一九六号、周妈是人脉。钱按第二关物价给，待调。",
      "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}
    }
  ]
}
```

- 引擎在 `stage_start` 钩子 priority **90**（排在 G01 的 50“清理不属于新年代的手牌”之后）、`stage == run.start_stage` 且 `run.applied` 为假时执行 `effects`，然后置 `applied`。`stage_00.json` / `stage_01.json` 是在这之后存的，重来本关不会再执行一遍。
- `show` 是给开局画面看的“看得见的结果”，**不是**规则；L04 的测试逐个出身开一局，对比 `view()` 的钱、`self.attrs`、`kept`、`contacts`、`rep_tier`、`heat_tier`、`date` 和 `show` 一字不差（预览 = 实际）。
- 正文键（A 写）：`og.shanghai#title` `#body`（两三句）`#locked`（没解锁时空白牌上的一句模糊提示，可省）`#intro`（这本账开月过场多出来的一段）。

### 5.5 解锁 `data/cards/legacy/unlocks.json` 与旧账条件

```json
{"id": "lg.og.shanghai", "type": "legacy_unlock", "era": ["*"], "weight": 0, "order": 10,
 "when": {"reached": [0, 4]},
 "grants": {"origins": ["og.shanghai"]}, "announce": true,
 "brief": "走过了教学日：以后可以从“上海学过徒”开头。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```
```json
{"id": "lg.card.stranger196", "type": "legacy_unlock", "era": ["*"], "weight": 0, "order": 60,
 "when": {"ded": "ded.ticket196"},
 "grants": {}, "announce": true,
 "brief": "对上了一九六号：以后的 1940 三月，会有一个生人来柜台打听那张票。牌在 legacy/cards.json，条件 legacy 指向本条。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```

- `grants` 可有 `origins` `keepsakes` `hardships` `single_act`（布尔）；空的解锁只给牌和回话的 `legacy` 条件用。`announce: true` 的在合账画面“旧账里翻出来的”里列出来（正文 `lg.x#body`，A 写）。
- `when` 用**旧账条件**（档案里的事实；`CardLegacyRules.test(profile, cond)`，纯函数，L02）：

| op | 值 | 为真当 |
|---|---|---|
| `all` / `any` / `not` | `[…]` / `[…]` / `{…}` | 组合 |
| `known` · `known_all` | 碎片 id · `[碎片 id…]` | 旧账里有 |
| `page_known_gte` | `[person, n]` | 这一页旧账里有 ≥ n 块 |
| `page_full` | person | 这一页每块旧账里都有（全本） |
| `page_run` | person | 某本账里这一页局内补齐过 |
| `seen` | `[node, outcome]` | 某本账走过这条路 |
| `seen_count_gte` | `[node, n]` | 这个节点走过 ≥ n 种 |
| `reached` | `[stage, stage_day]` | 某本账走到过这一关这一天的早上 |
| `closed` · `closed_gte` | 原因 · n | 某本账这样合上过 · 合上过 ≥ n 本 |
| `carried` | 留牌 def | 某本账合上时手里留着 |
| `contact_end` | person | 某本账合上时他是人脉 |
| `lg_flag` | 键（`lg_` 开头） | 某本账里置过 |
| `ded` · `ded_gte` | id · n | 对上过 |
| `chronicle` | 铺史行 id | 铺史里写过 |
| `hard_cleared` | 年景 id | 带着它收尾（`ending`）过 |

- 旧账条件**不许**用本心、口碑风声点数（它们不在档案里）；铺史行可以按本心挑，旧账条件再用 `chronicle` 去认。

**局内新条件 op**（主人 L01；形状进 `CardDslShapes`）：

| op | 值 | 语义 |
|---|---|---|
| `legacy` | 解锁 id | 开局时这条在 `run.unlocks` 里 |
| `knows` | 碎片 id | 在 `run.known` 里，或这一本已经拿到 |
| `origin` | 出身 id | 这本账的出身 |
| `hardship` | 年景 id | 这本账带着这个年景 |
| `veteran` | bool | 出身的 `veteran` 等于它（没有 `run` 时为 `false`） |

### 5.6 年景 `data/cards/legacy/hardships.json`

```json
{"id": "hard.levy", "type": "hardship", "era": ["*"], "weight": 0, "order": 10,
 "rules": {"demand_rules": {"tier_by_stage": [1, 1, 2]}},
 "effects": [], "art": "illus.hard.levy",
 "brief": "苛捐：胡二的条子从第一关起就是中档，第三关是大档。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```

- 合并顺序：基础规则 → `balance_overrides.json`（CardDB 已做）→ 出身的 `rules` → 年景的 `rules`（按 id 排序）。两个来源改同一个键：校验器报 `NOTE:`，后者赢。
- `effects` 在每关 `stage_start`（priority 91）执行，首版五个都是空的。

### 5.7 推理 `data/cards/legacy/deductions.json`（N04 原样搬来，奖励换成故事）

```json
{"id": "ded.ticket196", "type": "deduction", "era": ["*"], "weight": 0, "order": 60,
 "requires": ["df.brother.1938.de196", "df.brother.1938.ticket196", "df.chen.1938.ticket",
              "df.postman.1939.letter_run", "df.brother.1939.first_letter"],
 "brief": "一九六号：票面那一栏、拼回来的票、陈文庭那半张、邮差说的路、哥哥撕开的信。对上以后批注一句（A 写），解锁随身存根和来打听的生人。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```

正文：`ded.ticket196#title` `#body`（旧账批注）。N04 里的 `flag` `reward` `unlock_card` `required_missing` 不要了。

### 5.8 铺史 `data/cards/legacy/chronicle.json`

```json
{"id": "ch.end.prison.1939", "type": "chronicle_line", "era": ["1939"], "weight": 0,
 "group": "end", "order": 90, "reasons": ["prison"], "when_end": {},
 "brief": "兜底：腊月里被抓进去，没能出来。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```
```json
{"id": "ch.end.ending.apart", "type": "chronicle_line", "era": ["1940"], "weight": 0,
 "group": "end", "order": 10, "reasons": ["ending"],
 "when_end": {"story": ["s1940.sunfu_stance", "apart"]},
 "brief": "收尾：没跟孙府站一边，铺子还开着。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```
```json
{"id": "ch.people.linsao.extended", "type": "chronicle_line", "era": ["*"], "weight": 0,
 "group": "people", "order": 20, "reasons": ["*"],
 "when_end": {"story": ["s1938.linsao_term", "extended"]},
 "brief": "人：当期宽限过的林嫂后来怎样（A 写，不写死结果）。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```

- `era` 指合上时的年代；`reasons` 可写 `"*"`；`when_end` 是局内条件（合同 §5.3，可用 `conscience_gte` 这类只在引擎里用的条件）。`end` 组按 `order` 取第一条；`people` 组按 `order` 取至多 `legacy.json.chronicle_people_max`（起步 3）条。正文 `ch.x#body`。

### 5.9 只在旧账里知道了才出现的牌 `data/cards/legacy/cards.json`

```json
{"id": "p.stranger196.1940.ask", "type": "person", "person": "stranger196", "era": ["1940"], "weight": 6,
 "tags": ["story", "omen_far", "omen_official"], "intent": "ask",
 "conditions": {"all": [{"legacy": "lg.card.stranger196"}, {"day_gte": 10}]},
 "choices": [
   {"id": "tell", "effects": [{"op": "dossier", "frag": "df.stranger196.1940.asked"}, {"op": "heat", "delta": 3}]},
   {"id": "deny", "effects": [{"op": "dossier", "frag": "df.stranger196.1940.denied"}]}
 ],
 "effects": {"on_expire": []}, "art": "portrait.stranger196",
 "brief": "1940 三月，一个外地口音的人来柜台打听德字第一九六号。只有旧账对上过一九六号才进牌库。说还是不说，各补一块碎片。名字由 A 定。",
 "_provenance": {"by": "ai", "task": "L04", "date": "2026-10-25"}}
```

新人物登记在同文件的 `persons` 块；新碎片和新页 `dp.stranger196` 照 K08 的格式写在 `legacy/cards.json` 里（或开 `[shared]` 请 K08 收进 `dossier/`）。

### 5.10 知情回话（加在已有的牌上，要 `[shared]` 原主人改）

```json
{"id": "boat_word", "knowing": true,
 "conditions": {"knows": "df.linsao.1938.husband"},
 "effects": [
   {"op": "story", "node": "s1938.linsao_term", "outcome": "boat_word"},
   {"op": "dossier", "frag": "df.linsao.1938.boat_word"},
   {"op": "flag", "key": "lg_linsao_word", "value": true}
 ],
 "brief": "知情回话：知道她男人在船上，托码头的人捎一句话。不宽限也不收下，换一条路；1939 年那张船户牌看这面旗。"}
```

加在 `p.linsao.1938.term`（K01 的 `era/1938/story.json`）的 `choices` 里。首版六处：`p.brother.1938.farewell`（`ask196`，只能从旧账知道一九六号——它第 4 天才来）、`p.linsao.1938.term`（`boat_word`）、`p.wangshan.1938.visit`（`name_him`，知道 1939 年那块 `df.wangshan.1939.whisper`）、`p.zhao.1938.borrow`、`p.sunlaoye.1940.stance`、`p.postman.1940.hook`。每处一块新碎片、一个新走向名。

### 5.11 档案页的互斥组（K08 + G03）

```json
{"id": "dp.brother", "type": "dossier_page", "person": "brother", "era": ["*"], "weight": 0,
 "fragments": ["df.brother.1938.farewell", "df.brother.1938.farewell_cold", "…"],
 "alt_groups": [["df.brother.1938.farewell", "df.brother.1938.farewell_cold"],
                ["df.brother.1940.letter", "df.brother.1940.letter_cold"]],
 "effects": {"on_complete": [{"op": "flag", "key": "k08.page.brother", "value": true}]}}
```

一块碎片最多在一组里；组里的碎片都在 `fragments` 里（校验器查）。

### 5.12 规则文件 `data/cards/rules/legacy.json`（L01）

```json
{"_meta": {"owner": "L01", "schema": 1},
 "_doc": ["旧账：第一本账的种子、随身上限、铺史人物行上限、书架最多画几本。"],
 "first_run_seed": 7, "keepsake_max": 1, "chronicle_people_max": 3, "shelf_max": 24}
```

### 5.13 正文键一览（全部 A 写；AI 基础层在 `text_ai/legacy/**`、`text_ai/ui/L05.text.json`）

- 牌上的：`og.*#title|body|locked|intro`、`hard.*#title|body`、`lg.*#body`、`ded.*#title|body`、`ch.*#body`、新牌照 §4.5 的必填字段、知情回话 `<牌>#choices.<id>` 与 `outcomes.*`。
- 界面键（`ui_keys/L05.json`，键以 `l05.` 开头）：标题按钮 `l05.title.new_book` `l05.title.continue_book` `l05.title.archive`、本号 `l05.book.no`（`{n}`）、开局画面 `l05.pick.*`、合账 `l05.close.*`、旧账 `l05.archive.tab.*`、批注纸 `l05.note.pick|close|archive`、坏档提示 `l05.title.profile_reset`。
- 引擎的（`ui_keys/L01.json`）：`l01.notice.ded`（`{title_key}`）、`l01.reason.origin`。
- 主线走向短名（`ui_keys/L04.json`）：`l04.story.<node>.<outcome>`，约 70 条；提示 `l04.hint.<node>`，20 条。

---

## 6. 引擎与存档改动

| 文件 | 主人 | 改什么 | 函数 |
|---|---|---|---|
| `scripts/cards/legacy/legacy.gd`（新，`class_name CardLegacy`，要 Claude 同意） | L01 | 本局上下文的校验与落盘、规则覆盖、条件、收获、局内推理 | `init_run(ctx, run: Dictionary) -> String`（错误码，空串 = 成功）· `rules_overlay(ctx, name) -> Dictionary` · `knows(ctx, frag) -> bool` · `harvest(ctx, close: String) -> Dictionary` · `check_deductions(ctx) -> void` · `end_stage(ctx) -> int` |
| `scripts/cards/legacy/legacy_install.gd`（新） | L01 | 登记：条件 `legacy` `knows` `origin` `hardship` `veteran`；查询 `legacy.harvest`；钩子 `stage_start` 90/91、`month_open` 20（first `origin` `hardship` `old_ink`）、`settle` 65（推理）；修正项 `view_section` 交 `run: {no, origin, keepsake, hard, single_act}` | 在 `CardEngine._init` 里接在 `_ApprenticeInstall` 之后（合同 §7.3 “接在六段之后”） |
| `scripts/cards/core/card_ctx.gd` | G01（`[shared]`） | `rules(name)`：状态里有 `run.rules[name]` 时返回“数据库规则深合并它”的结果，按 name 缓存在 ctx 里（缓存随 `state` 对象换掉而清空）；没有时和现在一样 | `rules(name)` |
| `scripts/cards/core/card_db.gd` | G01 | `CARD_DIRS` 加 `"legacy"`；`_merge_override` 拆出一个静态的 `merge_rules(base, over, errors: Array) -> Dictionary` 给 L01 复用 | `merge_rules` |
| `scripts/cards/core/card_validator.gd` / `validation_extra.gd` | G01 | V43–V48（§10） | |
| `scripts/cards/core/card_state.gd` | G01 | 不改 `NAMESPACES`（`run` 不自动建）；文件头注释登记 `run`（主人 L01） | — |
| `scripts/cards/loop/loop_install.gd` | G02（`[shared]`） | `_cmd_new`：建状态后、`begin_stage` 前调 `CardLegacy.init_run(ctx, opts.get("run", {}))`，非空错误返回 `bad_args`；`_cmd_load` 之后不用改（`run` 跟着状态走） | `_cmd_new` |
| `scripts/cards/loop/day_loop.gd` | G02 | 新 `is_last_stage(ctx) -> bool`（下一关没有，或 `stage >= CardLegacy.end_stage(ctx)`）；`close_month` 用它，原因：下一关存在时是 `act_end`，否则 `ending`；`open_pre_ending_window` 同样用它 | `is_last_stage` `close_month` `open_pre_ending_window` |
| `scripts/cards/rules/dossier.gd` | G03 | `view()`：碎片多一种 `state: "old"`、缺口多一个 `old: true`；页多 `old_only`（这一本没见过这个人，只有旧账里有）、`full`（全本）；`complete()` 认 `alt_groups` | `view` `complete` |
| `scripts/cards/rules/choices.gd` | G03 | `options()`：`knowing: true` 且条件不过 → 不列；过了 → 多一个 `knowing: true`；`choose()`：藏着的 → `no_such_choice`；第一次列出知情回话发 first `knowing` | `options` `choose` |
| `scripts/cards/api/card_ids.gd`、`dsl_shapes.gd` | Claude（`[api]`） | `TYPES` 加五类；`FIRSTS` 加 `old_ink` `knowing` `origin` `hardship` `deduction`；`ANCHORS` 加 `a.top.run`；`RNG_DOMAINS` 加 `m.run.seed` `m.hint`（主人 L02，档案盐上用，不经 `ctx.draw`）；`PANELS` 加 `origin_pick` `ledger_close` `archive`（叠层）；五个条件的形状、Choice 的 `knowing` 字段 | |
| `scripts/cards/mock/**` | Claude | Mock 的 `view.run`、`legacy.harvest`、档案簿视图的 `old`，加三个夹具（第一本、第五本、带年景） | |
| `scripts/cards/legacy/profile/card_profile.gd`（新，`class_name CardProfile`） | L02 | 档案文件读写、并账、合账、编本局上下文、可选清单、种子、提示 | `load(path) -> CardProfile` · `save(path) -> Dictionary` · `absorb(harvest, run_no)` · `close_run(harvest, reason) -> Dictionary`（返回合账画面要的“新写下的 / 翻出来的”）· `available(db) -> {origins, keepsakes, hardships, single_act}` · `compile(db, pick) -> Dictionary`（`game.new` 的 opts）· `next_seed() -> int` · `hint(db) -> String` · `adopt_legacy_suspend()` |
| `scripts/cards/legacy/profile/legacy_rules.gd`（新，preload） | L02 | 旧账条件求值与形状（校验器也用） | `test(profile, cond) -> bool` · `shape(cond) -> String` |
| `scripts/cards/sim/autoplay.gd`、`balance_main.gd`、`scripts/tests/cards/golden/test_golden.gd` | G06 | `--origin=` `--hard=` `--unlocks=all` `--single-act`；黄金用例可带 `run` | |

**存档**：局内存档信封不变（`format` `v` 都不升）；状态多一个可选的 `run`；信封 `meta` 多一个 `run_no`（标题判断“接着记”用）。旧存档没有 `run` = 零传承，照常读。档案文件另放，见 §5.1。**引擎不读、不写档案文件**；收获只经查询交给外壳。

**外壳的接线**（C01 `card_game_root.gd`，`[shared]`）：`_start()` 改成问 `CardProfile`：有可选的东西就开 `origin_pick`，没有就直接 `engine.new_game(profile.compile(db, {}))`；收到 `saved` 事件、`game_over` 事件时 `profile.absorb(engine.query(&"legacy.harvest", {}))` 并存档案；合账时 `close_run(...)` 后开 `ledger_close`。

---

## 7. 界面（1280×720，像素柜台的同一套纸墨）

> 字号、按钮、纸张都照 `MonthUi` 和档案簿现有做法；颜色只用配色键；新图 id 交 K12 登记清单。四个新画面都是叠层（`origin_pick` `ledger_close` `archive`）或标题上的部件，都能 Esc /“算了”关掉，回到标题或牌桌（红线 9）。

### 7.1 标题 = 书架（C16 的 `CardTitle` 加东西）

```
┌──────────────────────────────── 1280×720  bg.title ─────────────────────────────────┐
│                               德  厚  当        （标题字 64，y 120，lamp）               │
│  ┌───── 书架 x64–404 y300–660（wood_dark）────┐                                       │
│  │ ▌▌▌▌▌▌▌▌▌▌▌▌   一本账一根书脊 28×120        │   [ 另起一本 ]   (500,320) 280×48       │
│  │ ▌▌▌             prop.ledger_spine ×4        │   [ 接着记   ]   (500,380)             │
│  │ 书脊竖写“第一本”；收尾的盖 seal 小印；         │      第四本 · 民国二十九年一月十二日     │
│  │ 年景收尾的再盖 gold 小印                      │      （ink_soft 14，y 430）            │
│  │ 悬停：上方浮一张纸，写这本的铺史 end 行        │   [ 翻旧账   ]   (500,452)             │
│  └─────────────────────────────────────────────┘   [ 设置     ]   (500,512)             │
│                                                     [ 退出     ]   (500,572)             │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- 还没有合上过任何一本：**没有书架**，按钮就是今天的“开张 / 继续 / 设置 / 退出”（`CardTitle.chose` 信号的四个动作不变；“翻旧账”是新动作 `&"archive"`）。
- 点书脊 = 打开旧账画面的“铺史”栏、翻到那一本。

### 7.2 另起一本（`origin_pick`，叠层，整屏纸）

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ 另起一本 · 第五本                                   ┌ 批注纸（第一次打开，obj.old_ledger）┐ │ y30
│                                                    └ “旧账上能抄过来的，都在这儿了。”    ┘ │
│ 出身 ─────────────────────────────────────────────────────                            │ y92
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐     牌 144×200，x = 60 + i×164，最多 5 张，         │ y110
│ │哥哥│ │上海│ │周妈│ │腊月│ │ 空 │     多了左右翻；选中的抬起 12、gold 描边；           │
│ │的铺│ │学过│ │的干│ │接手│ │ 白 │     没解锁、带 locked 正文的画成空白账页 paper_old   │
│ └────┘ └────┘ └────┘ └────┘ └────┘     （一句模糊提示），不带的根本不画                 │ y310
│ 随身（最多一件）──────────────                                                         │ y330
│ [不带] [银饰] [旧账一页] [存根]          小牌 72×100，x = 60 + i×88                    │ y350–450
│ 年景 ───────────── （第一次收尾以后才有这一排）                                         │ y470
│ [苛捐] [荒年] [查得严] [无人作保] [米贵]   [只记一个月]   小牌 72×100，点一下翻面=选中   │ y490–590
│                                  ┌── 右栏 x900–1240 y92–600 ─────────────────────────┐ │
│                                  │ 上海学过徒（名字条 22）                             │ │
│                                  │ 两三句（A 写，16）                                  │ │
│                                  │ 从民国二十七年三月初一开头                           │ │
│                                  │ 钱 300 · 眼力 3 口才 1 门路 0 胆量 1                │ │
│                                  │ 带着：（小牌）  认得：（人脉小牌）                   │ │
│                                  │ 年景：苛捐、米贵（只列名字）                         │ │
│                                  └─────────────────────────────────────────────────┘ │
│ [ 算了 ]  (60,640) 200×48                                       [ 开张 ] (1040,640) 200×48 │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- 右栏的数全部来自出身的 `show`（测试保证和开局后的视图一致）；年景一个数都不写，“米贵”可以写家用钱数（钱看得见）。
- 键盘：1–9 选出身，Tab 在三排之间换，Enter = 开张，Esc = 算了。`autoplay_step()` 选第一个出身、不带随身、开张。

### 7.3 合账（`ledger_close`，叠层）

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ 合账 · 第四本                                                                          │ y30
│ ┌── x60–400 y90–600 ─────┐ ┌── 这本账里新写下的 x430–850 ──┐ ┌── 旧账里翻出来的 x880–1240 ┐ │
│ │ 账本封面 bg.ledger_cover │ │ 档案  林嫂 · 王山 · 哥哥       │ │ ┌────┐ 出身：周妈的干女儿  │ │
│ │ （合上的动画 0.6 秒）    │ │       三页添了新墨（缩略 72×100）│ │ │    │ （正文一句）        │ │
│ │ 铺史：                   │ │ 主线  新走过的路 3 条          │ │ └────┘                    │ │
│ │  民国二十九年三月十八日， │ │       “王山 · 交出去” …        │ │ [72×100] 随身：一九六号的存根│ │
│ │  ……（end 行）            │ │ 对上了  一九六号（批注一句）   │ │ 镇上会多一个人（一句）       │ │
│ │  ……（people 行 ≤3）      │ │ 下一本可以留意：……（提示，     │ │ ……还有 2 样，翻旧账里看     │ │
│ │ 年景朱印（收尾才盖）      │ │  只在这一本什么都没翻出来时）  │ │                            │ │
│ └──────────────────────────┘ └──────────────────────────────┘ └────────────────────────────┘ │
│                                                                   [ 放上书架 ] (1040,640) │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- 一行一行出（点一下下一行，同开月过场；快动画设置开着就一下子全出）。数只出现“几页”“几条”这类看得见的计数，不出现“完成度 %”。
- 第一本账第一次合上：批注纸讲“合上的账放上书架，旧账里记下的，下一本还用得着”。

### 7.4 翻旧账（`archive`，叠层，和档案簿同一本书的样子 1080×620 @ (100,50)）

- 左边栏签：**人 · 主线 · 对上的 · 铺史 · 规矩**。
- **人**：人名索引（认得的才有）；每页碎片按 `order` 排，墨色是见过的，页眉写熟人三档的字、全本盖金字；是否画“空行”见 §13 D3。
- **主线**：1938 / 1939 / 1940 三栏，节点一行（节点名用那张金色牌的 `title`），走过的走向盖章（`l04.story.<node>.<outcome>`），没走过的空格。
- **对上的**：对上过的推理，题目 + 批注；没对上的不列。
- **铺史**：一本一条：本号、出身、随身、年景、民国日期、end 行、people 行。
- **规矩**：`rule.old_ledger`、`rule.origin` 两页（同档案簿“规矩”栏的 `RulesView`）。

### 7.5 局内的四处小改

| 在哪 | 主人 | 样子 |
|---|---|---|
| 档案簿（C10 `dossier_book.gd`） | C10 | 旧墨碎片：`ink_soft`、0.6 透明、页角 `icon.old_ink`（16×16“旧”字小印）；缺口 + 旧墨：撕痕下透淡字；只在旧账里有的人，索引里名字发灰；页眉“全本”金字；新栏签“对上的” |
| 对话框回话（C04 `dialog_box.gd`） | C04 | `knowing: true` 的回话左边一个 `icon.knowing`（朱笔圈 16×16），字色不变；没有任何提示框 |
| 顶栏（C01 `hud.gd`） | C01 | 日期后面一段小字“第四本”，后面跟年景的小图标（16×16）；锚点 `a.top.run` |
| 局终画面（C09 `game_over.gd`） | C09 | 按钮改成四个：重来本关 (100,520) · 续玩 (380,520) · **合账** (660,520) · 回标题 (940,520)，各 240×48；原因是 `ending` / `act_end` 时“合账”是默认焦点；锚点 `a.over.close`（新） |

---

## 8. 新手指引（红线 8）

| 机制（`CardIds.FIRSTS`） | 谁发 | 步骤 | 教的人 | 锚点 | 讲什么（brief） |
|---|---|---|---|---|---|
| `old_ink` | L01（`month_open`，`run.known` 不空的第一本） | `gd.old_ink` | `obj.old_ledger`（新：旧账页边的批注） | `a.tab.dossier` | 档案簿里淡墨的是旧账上见过的；这一本要自己再问出来才算 |
| `knowing` | G03（第一次列出知情回话） | `gd.knowing` | `obj.old_ledger` | `a.counter.reply`（备用 `a.hand`） | 带朱笔圈的话，是你知道内情才说得出口的 |
| `origin` | L01（`month_open`，出身不是 `og.default`） | `gd.origin` | `obj.old_ledger` | `a.top.run` | 这本账是怎么开头的；开头不同，难处不同 |
| `hardship` | L01（`month_open`，带年景） | `gd.hardship` | `obj.old_ledger` | `a.top.run` | 这一年的年景；收尾了，书脊上盖印 |
| `deduction` | L01（`settle` 里第一次对上） | `gd.deduction` | `obj.old_ledger` | `a.settle.lines` | 几本账里的零碎对上了，档案簿里多了一页批注 |

- 规矩页：`rule.old_ledger`（`unlock_first`: `old_ink` `knowing` `deduction`）、`rule.origin`（`origin` `hardship`）。
- 局外三个画面（开局、合账、旧账）不在局内，C16 的指引引擎管不到：各自第一次打开时画面上有一张批注纸（同 `guide_note` 配色），看过记进档案 `notes_seen`；同样的话在旧账“规矩”栏能回看。合同 V31 的 `teacher` 白名单加 `obj.old_ledger`；K16 写步骤，A 写正文。
- 指引进度跨局：外壳开新局时把档案里的 `guide` 并进新状态的 `ui`（`CardCoreInstall.merge_ui` 同一种并法；`ui` 不进哈希，开不开指引照旧不改任何状态）。

---

## 9. 平衡风险

| # | 风险 | 怎么防 | 怎么量 |
|---|---|---|---|
| R1 | 出身变成“更好的开局”（`og.zhouma` 每天多一张消息 + 口碑高一档） | 每个出身都带代价；随身最多一件；不做加钱的解锁 | G06 矩阵：5 出身 × 7 策略 × 20 种子；验收（【待调】）：fair / greedy 各出身三关过关率在 `og.default` 的 ±15 个百分点内 |
| R2 | 从 1939 / 1940 开头的钱和状态太好或太差 | 起手钱按“fair 策略打到那一关开头时的中位数”定，不按好的定 | Telemetry 取 `og.default` fair 的 1938 月底钱分布，`og.1939` 起手钱落在 40–60 分位 |
| R3 | 知情回话变成“最优解”，玩家为它刷旧账 | 审读规矩：知情回话的钱、口碑风声得失不超过同一张牌别的回话；主要给碎片和走向 | K13 / 编排逐条审；自动策略带 `--unlocks=all` 跑，过关率不明显高于不带 |
| R4 | 年景反而让 refuser 更安全（F11 的老问题：条子中档失败对不做生意的人不疼） | 年景不承担修这个问题；`hard.levy` 让条子早升档，refuser 会更早被封、被拿家当，但仍可能“不疼” | 报告里单列 refuser × 每个年景；结论依赖 #198 主创对“条子失败后果”的决定 |
| R5 | 拼全本要太多本账，变成刷 | 首发每页互斥组 ≤ 2；短账（`og.1939` + 只记一个月）；提示保底；全本没有实力奖励 | 节奏目标见 §3 末；K14 用“每本换一条没走过的路”的脚本策略量需要几本 |
| R6 | 读档刷知识：第 16 天早上选“宽限”，读续玩点再选“收下”，一本账里两块都进了旧账 | 允许。知识本来就留下（原则 7）；它只加快旧账，不加局内实力；解锁都是故事 | 不量；写进规矩页一句“旧账只记，不罚” |
| R7 | 旧墨泄露鉴定答案（上一本知道林嫂的簪“补过”） | 这是玩家记性，和真肉鸽的“知道这个怪会干什么”一样；不另防 | — |
| R8 | 局中改了档案文件（另一局并账）影响这一局 | 本局上下文开局时冻结在状态里；引擎从不读档案文件 | §10 T3 |
| R9 | 104 块没人给的碎片让“全本”永远达不到 | 首版解锁只用 `page_known_gte`；`page_full` 等 K08 补完再用；新校验 V48（strict）列出没人给的碎片 | V48 报告数逐版下降 |
| R10 | 一局太长（三关约 5–6 小时），5–10 本账吃不消 | 从 1939/1940 开头 + 只记一个月 + 懂行的出身免教学日 | K14 / 试玩记真人时长；超过 2 小时一关，再按 DESIGN §八“太长就把平淡的日子合并”另提方案 |
| R11 | 两种“齐”让人糊涂 | 局内“齐”是朱印、旧账“全本”是金字，规矩页讲清 | 试玩问卷 |
| R12 | 互斥组（`alt_groups`）让 9 页局内补得齐 → 人脉多拿几个 → 局内变强 | 这是修 bug，但会改平衡：单独一个 PR、单独跑平衡 | 改前改后 fair 第三关过关率 |

---

## 10. 测试与黄金种子

**不变式**（每条一个测试，名字按 `<任务>_<名>` 登记进 `suites/L0x.txt`）：

| # | 不变式 | 测试 |
|---|---|---|
| T1 | **零传承恒等**：不给 `run`、给 `run: {}`，三关浸泡每天的 `state_hash()` 和现在的 `golden.json` 逐个相同 | `L01_zero_identity`（也是 L01 PR 不动 `golden.json` 的证明） |
| T2 | 同种子 + 同 `run` + 同指令 → 同哈希；任意早上存 → 读 → 继续，哈希相同；`game.retry_stage` 后出身效果不重复执行 | `L01_determinism_save` |
| T3 | 局中改档案文件、局中并账，对这一局的哈希没有影响（引擎不读档案） | `L01_frozen_run` |
| T4 | 每个出身开局后的视图 = 它的 `show` | `L04_origin_show` |
| T5 | 规则覆盖：合法的合进去、投影上下文（`CardSchedule._project`）读到一样的值；改不存在的键或换类型 → `game.new` 返回 `bad_args` | `L01_rules_overlay` |
| T6 | `legacy.harvest` 只读（查询前后哈希相同）、过 `leaks()`、没有浮点 | `L01_harvest` |
| T7 | 只记一个月：出身那关月底以 `act_end` 收尾；不带时照旧 `ending` | `L01_single_act` |
| T8 | 局内推理：凑齐那晚的日结有一行、只一次、存读后不重发；first `deduction` 一次 | `L01_deduction` |
| T9 | 五个新条件 op 的正例和形状反例；新 first-time 各恰好一次 | `L01_ops_conds`、`L01_firsts` |
| T10 | 档案簿视图：`old`、缺口 + `old`、`old_only`、`full`；`alt_groups` 的局内补齐；没有 `run` 时视图和现在一样 | `G03_dossier_old` |
| T11 | 知情回话：条件不过不列、过了带 `knowing`；藏着的 `card.choose` → `no_such_choice` | `G03_knowing_choice` |
| T12 | 档案文件：原子写、坏档回退、版本比自己新拒读；`absorb` 幂等、可交换（随机收获序列的性质测试）；`compile` 确定、滤掉认不得的 id；种子推导确定；合账删掉续玩点 | `L02_profile_io`、`L02_absorb_props`、`L02_compile` |
| T13 | 不卡死：`G06_no_deadlock` 每 10 局有 1 局带随机的合法 `run`（随机出身、年景、只记一个月） | G06 加参数 `--random-run=10` |
| T14 | 每个出身、每个年景 × 7 策略三关不卡死 | `G06_policies_no_stall --origin=… --hard=…` |
| T15 | 界面：三个新画面实例化、各状态渲染、`all_text_from_cardtext`、画面上没有“%”、键盘、`autoplay_step()`；X01 真点冒烟延长一段：标题 → 开张 → …（夹具直接进局终）→ 合账 → 书架上一根书脊 → 另起一本 | `L05_*`、`X01_click_smoke` |

**校验器新规则**（G01 实现，L04 的数据要全绿）：

| 规则 | 查什么 | default / strict / ship |
|---|---|---|
| V43 | 五个新类型的字段齐、id 前缀对（`og.` `hard.` `lg.` `ded.` `ch.`）、`start_stage` 是存在的关 | 错 / 错 / 错 |
| V44 | `effects` 过 DSL 形状；`rules` 覆盖的路径存在、类型不变；两个来源改同一键 → `NOTE:` | 错 / 错 / 错 |
| V45 | 解锁的 `when` 过旧账条件形状；`grants` 指向存在的出身 / 留牌 / 年景；数据里每个 `{"legacy": id}` 指向存在的解锁 | 错 / 错 / 错 |
| V46 | 推理的 `requires` 都是存在的碎片；`knows` 指向存在的碎片；带 `knowing` 的选项必须有 `knows` 条件 | 错 / 错 / 错 |
| V47 | 铺史：每个原因 × 每个年代都有 `end` 组兜底；`alt_groups` 合法 | 错 / 错 / 错 |
| V48 | 有页的碎片没有任何牌给、也不是 `year_after` | `NOTE:` / 警告 / 警告（首版 104 条，逐版下降） |

**黄金种子**（合同 §12.5）：

- L01、L02、L03 的 PR **不改** `golden.json`，`G06_golden` 必须照绿（T1 是证明）。
- L04（新数据）、L06（加知情回话、教学牌加 `when`）改了数据库哈希 → 状态里的 `db_hash` 变 → 全部哈希变。按 §12.5 在最新集成头上单独一个提交 `--update-golden`，PR 里附“去掉 `db_hash` 后逐日哈希相同”的诊断，说明行为没变（藏着的选项不在 `options` 里，自动策略看不到；教学牌的 `when` 在没有 `run` 时为真）。
- L07 新加两个用例：`{"seed": 7, "policy": "fair", "data": "real", "days": 30, "run": {"no": 2, "origin": "og.shanghai", "hard": ["hard.levy"], "unlocks": ["lg.hardships", "lg.og.shanghai"], "known": [...]}}` 和一个 `og.1939`（`stage: 1`）用例，锁住传承的行为。

---

## 11. 先做什么

1. **先修种子**（半天的活，不等主创）：标题“开张”不再永远是 7。哪怕没有旧账，第二局也该不一样。做法就是 §4.1 的种子推导，档案文件里先只存 `salt` 和 `runs_started`。
2. **第一波 · 知道的会留下**（零平衡影响，纯叙事）：档案文件 + 收获查询 + 合账画面 + 书架 + 档案簿旧墨 + 铺史 10 行。玩家第二本账就能看到“上一本的淡墨”。
3. **第二波 · 能选的开头**：`og.shanghai`（顺带解决教学日的重玩税）、`og.1939`、`og.1940`、只记一个月、开局画面。
4. **第三波 · 镇上多出来的**：知情回话 6 处、新牌 5 张、推理 7 条、`alt_groups`。这一波最依赖 A 的正文。
5. **第四波 · 难处**：年景 5 个、朱印、平衡矩阵；`hard.iron` 等主创定。

---

## 12. 实现拆分（互相独立的包）

> 编号 L00–L07 是提议（K18 那种一号多用的事别再出，HANDOFF §5.5）；编排可以改号。每个包都能对着 Mock / 夹具单独开发、单独合入。

| 包 | 做什么 | 文件（归属） | 依赖 | 测试 | 黄金 | 量 |
|---|---|---|---|---|---|---|
| **L00** 合同 | 主创批准后：DESIGN §十；合同 1.6（`run` 命名空间、五类型、条件、查询、FIRSTS、锚点、面板、随机域、V43–V48、`teacher` 白名单）；`ownership.json` 加 `scripts/cards/legacy/**`（L01，`profile/**` 归 L02）、`data/cards/legacy/**`（L04）、`data/cards/rules/legacy.json`（L01）、`scripts/cards/ui/legacy/**` + `scenes/cards/legacy/**`（L05）；`card_ids.gd` `dsl_shapes.gd` Mock 与夹具；`_examples/legacy/` | Claude | 主创拍板 | W0 测试照绿 | 不动 | S |
| **L01** 引擎 · 本局上下文 | `CardLegacy`、`legacy_install.gd`、`rules/legacy.json`；`CardCtx.rules` 覆盖（`[shared]` G01）、`_cmd_new` 一行（`[shared]` G02）、`is_last_stage`（`[shared]` G02）、`CardDB.CARD_DIRS` 与 `merge_rules`（`[shared]` G01） | L01（GPT 线） | L00 | T1–T9 | **不动**（T1 证明） | M |
| **L02** 档案文件 | `CardProfile`、`legacy_rules.gd`；种子推导；合账删档；旧续玩点认领 | L02 | L00（收获的形状用夹具，不等 L01） | T12 | 不动 | M |
| **L03** 档案簿与回话 | `dossier.gd` 旧墨与 `alt_groups`、`choices.gd` 的 `knowing` | G03 | L00（`run.known` 用状态夹具） | T10、T11 | 不动 | S |
| **L04** 旧账数据 | `data/cards/legacy/{origins,unlocks,hardships,deductions,chronicle,cards}.json`、`ui_keys/L04.json`、`tags/L04.json`、`text_ai/legacy/**` 基础层；校验器 V43–V48 由 G01 写（同包里开 `[shared]`） | L04（Grok 线）+ G01 | L00；数据可先写，L01 合入后跑 T4 | T4、V43–V48 | **重算**（db 哈希） | M |
| **L05** 外壳与画面 | 书架（`[shared]` C16 `card_title.gd`）、`origin_pick` `ledger_close` `archive` 三个叠层、局终按钮（`[shared]` C09）、旧墨与“全本”（`[shared]` C10）、回话朱圈（`[shared]` C04）、顶栏本号（`[shared]` C01）、`card_game_root.gd` 接线（`[shared]` C01）；美术 id 交 K12 | L05（Cursor 线） | L00 的 Mock；L02 的 API | T15、截图 | 不动 | L |
| **L06** 跨主人的内容 | 知情回话 6 处（K01 / K03 / K05 的 `story.json`）、教学牌 `when`（K16 `tutorial.json`）、`alt_groups` 与新碎片（K08）、指引步骤与规矩页（K16）、新碎片的人物登记 | 各原主人，`[shared]` 逐条 | L03、L04 | 各主人的校验 + `L06_content` 统计 | **重算** | M（正文靠 A） |
| **L07** 自动玩、平衡、黄金 | autoplay / balance 的 `--origin` `--hard` `--unlocks` `--single-act`；`G06_no_deadlock --random-run`；两个新黄金用例；平衡报告加“出身 × 策略”“年景 × 策略”两张表 | G06 | L01、L04 | T13、T14 | **加用例** | M |

并行关系：L00 之后，L01 / L02 / L03 / L04 四包同时开；L05 对 Mock 开；L06、L07 在 L01 + L04 合入后开。

一个耦合要注意：`CardIds.FIRSTS` 一加新机制，V29（每个机制都要有指引步骤和规矩页）就会要求 K16 的 `steps.json` / `rule_pages.json` 同时有对应的步骤。`validation_extra.gd` 的 `_guide()` 对 `FIRSTS` 里每一项都查，连 `FIRSTS_RESERVED` 也不例外。所以 L00 加 FIRSTS 的提交要和 K16 的五个步骤、两页规矩（AI 基础层正文一起）**同一个合并波次**进集成分支，不能拆开先合。

---

## 13. 要主创 / 编排决定的事

| # | 事 | 本稿的默认 |
|---|---|---|
| D1 | 要不要局外传承（HANDOFF：它改跨局结构） | 要，按本稿的“只带知道的和能选的开头” |
| D2 | 要不要一个明说的框架（例：1981 年孙女在老宅夹墙里翻出一包当票存根，一本账是一种“当年可能是这样”） | 不明说，只叫“旧账”；楔子留给主创写剧本时定 |
| D3 | 旧账画面里，没见过的碎片、没走过的走向画不画“空行 / 空格”（会让人看出一页还缺几块、一个节点有几条路） | 画，不写字；局内档案簿照合同不画 |
| D4 | 从 1939 / 1940 开头、“只记一个月”算不算违背“一关一个月、打完跳一年” | 算局外的玩法选项，第一本账永远从 1938 开始 |
| D5 | `hard.iron`“一本到底”（局终只能合账）和红线 9 “重来本关 / 续玩永远可用”怎么摆 | 引擎照旧永远可用，界面只在玩家自选这个年景时不给按钮；要主创点头才做 |
| D6 | 种子：第一本 7、之后按档案盐推导、盐默认 0、不读墙钟 | 照此；要每台机器不同就改成建档时取一次墙钟作盐 |
| D7 | `alt_groups` 让 9 页主线人物局内补得齐（林嫂、陈文庭、马万利、王山、何启明会更常成人脉） | 修，单独一个 PR、单独跑平衡 |
| D8 | N04 的局内推理（口碑风声奖励）还要不要 | 不要；同一批推理改成跨局、奖励是故事 |
| D9 | 名字：旧账 / 合账 / 另起一本 / 接着记 / 翻旧账 / 出身 / 随身 / 年景 / 铺史 / 知情 | 照此，A 可改字，id 不改 |
| D10 | 档案文件进不进 Steam 云存档、成就怎么从解锁里取 | 进；成就二期 |

---

## 14. 首版内容清单（数量都是起步，【待调】）

| 内容 | 数量 | 谁 |
|---|---|---|
| 出身 | 5（`og.default` `og.shanghai` `og.zhouma` `og.1939` `og.1940`） | L04 骨架，A 正文 |
| 随身 | 3（`kp.silver_keepsake` 已有、`kp.hl.ledger` `kp.hl.stub196` 新） | L04 |
| 年景 | 5（`hard.levy` `hard.lean` `hard.watch` `hard.alone` `hard.dear`） | L04 |
| 解锁 | 约 15（出身 4、随身 3、年景 1、只记一个月 1、新牌 5、铺史纪念 1） | L04 |
| 推理 | 7（N04 六条 + `ded.de196_whole`） | L04，A 写批注 |
| 铺史行 | 约 20（`end` 兜底 4 原因 × 3 年代 = 12，收尾分支 4，`people` 若干） | L04，A 写 |
| 新牌 | 5（人物 3、事件 1、消息 1），各带 1–2 块新碎片 | L04，A 写 |
| 知情回话 | 6 处，各 1 块新碎片、1 个新走向 | L06（K01/K03/K05），A 写 |
| 新碎片 | 约 14 | L04 / L06（K08 格式） |
| 指引 | 5 步、2 页规矩、3 张局外批注纸 | K16，A 写 |
| 主线走向短名、提示 | 约 70 + 20 条界面键 | L04，A 写 |
| 美术 | 出身插图 5、年景小图 5、书脊 1、账本封面 1、`icon.old_ink` `icon.knowing`、年景图标 5 | K12 登记，A / 美术线出图 |
| 代码 | 新文件 6 个左右（引擎 2、档案 2、画面 3–4），改 ~12 个别人的文件（都走 `[shared]`） | L01 / L02 / L05 + 原主人 |
