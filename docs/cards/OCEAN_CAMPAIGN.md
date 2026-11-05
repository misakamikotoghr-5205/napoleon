# 远洋：三部曲后端映射（《鹰旗军需官》的远洋分支）

本卷把用户提供的原稿整理成可执行剧情数据，玩家看到的书名是《远洋：从圣赫勒拿到鹦鹉螺号》。主角埃德蒙·德·维尔福是帝国老近卫军的军需官兼司库，滑铁卢之后随皇帝流亡；故事串联拿破仑、基督山伯爵、星期五与尼摩。它是明确的**架空历史奇幻**：人物交会、历史指控、幻想矿物与深海技术均为作品设定，不作为史实或科学结论。

原稿把主角写成远洋上开当铺的掌柜。2026-11 改版成《鹰旗军需官》以后（`docs/cards/world/WORLD_MAP_DESIGN.md` §12），玩家看得见的当铺说法全部换成军需与行军的说法，机制、id、命令和存档键一个没动，见文末「去当铺」一节。远洋现在是《鹰旗军需官》厄尔巴分岔以后的三条分支之一（「远洋」，海底两万里线）；单段书 `ocean_pawn` 仍可单独开局，作回归用。

数据源为 `data/campaigns/ocean_pawn.json`，顶层 `id=ocean_pawn`、`version=1`。原始附件名为 `code_artifact.md`，SHA-256：

```text
73beadd074bbc6071d40ed6257f08bdd85cccacb9b4951bb529ae42a5d791d83
```

原稿的危险实验与毒理情节保留叙事作用，改为密封物证、虚构化验报告和任务凭证。数据没有真实毒物用量、化学合成配方、爆炸物内部结构或组装步骤。绿翡翠瓶对应脱身准备，三层封存军需桶对应行动准备；它们只改变故事状态。

## 0.9 基底与独立保存

当前分支 `napoleon-ocean-pawn-v09` 以 Claude 集成分支 `claude/festive-ride-vud32a` 的 `9fecf270be901fce7b957c58436c98d26bd1ebba` 为基底；其中包含 v0.9 肉鸽功能和新手验收修复。它没有修改原分支，也不覆盖之前基于旧 main 的 `napoleon-ocean-pawn`。前端脚本、场景、美术、音频、字体和项目配置均继承 Claude 基底。

远洋战役的存档与战役档案使用 `user://cards/ocean_pawn/`（目录名是内部名，玩家看不见）；原 v0.9 使用 `user://cards/`。通过 `DEHOUDANG_CAMPAIGN=legacy` 可运行保留的 v0.9 民国战役。新战役适配现有标题、种子、档案书架和博古格接口，原 v0.9 的模块安装顺序与旧战役规则保持不变。

## 数据契约

| 字段 | 含义 |
| --- | --- |
| `source` | 来源文件名与内容哈希，不依赖上传文件的临时绝对路径 |
| `initial` | 六项整数状态：`treasury`、`morale`、`heat`、`vitality`、`construction`、`exploration` |
| `chapters` | 四章有序数组；含章节 ID、名称、币制、开账军费及场景顺序 |
| `characters` | 24 位人物；每项含 `id/name/role`，场景 `speaker` 引用人物 ID |
| `items` | 八件关键物证；每项含 `id/name/chapter/description` |
| `scenes` | 14 场；含 ISO 日期、地点、发言人、正文段落、物证、查验与决策 |
| `appraisals` | `id/kind/label/observation`；`kind` 只有 `spot/weigh/ring/decode`（察看、过秤、听音、破译） |
| `choices` | 线索和历史标记前置条件、六项数值增减、标记和物品增删、是否推进 |
| `endings` | 四个原稿结局；`body` 为字符串段落数组 |
| `tuning` | 结局阈值、营令三色旗与催逼说明、普通任务物品目录 |
| `design_notes` | 区分原稿设定、抽象化处理与实现默认值 |

每项选择的六个 `effects` 字段均明确给出整数，包括零值。`requires_clues` 只引用本场查验 ID；跨场条件使用 `requires_flags`。`advance=false` 表示留在本场的支线选择，同一场同一个选择只消费一次。不同场允许有同名选择，消费记录以场景隔离。背叛次数按不同标记计算，不能反复私吞同一类款项凑出两个背叛。

八件关键物证之外，`medicine` 是普通医疗补给任务凭证。它可以由第一场选项发放或从市镇补给购买，不代表具体药品或药物配方。运行时接受它作为库存 ID；它不是第九件关键物证。

## 原稿章节与日期

| 场景 ID | 日期 | 原稿事件与执行映射 | 理想推进选择 |
| --- | --- | --- | --- |
| `prologue` | 1815-08-04 | 贝勒罗丰号；怀表夹层、法利亚的半封信与随行名额 | `secure_passage` |
| `scene01` | 1817-11-01* | 海鸥号补给栈；玛丽送布、1817铁证、营令三色旗与双催逼 | `seal_evidence` |
| `scene02` | 1818-06-01* | 假马伦哥佩剑；揭穿独眼杰克、克劳福德内线 | `expose_sabre` |
| `scene03` | 1819-09-01* | 皇家橡树酒馆；奥米拉底单、莫雷尔与摩西汇票 | `audit_accounts` |
| `scene04` | 1821-04-28 | 南岸海蚀洞暗门；唐泰斯、两半密信、脱身凭证 | `prepare_escape` |
| `scene05` | 1821-05-05 | 朗伍德到闪电号；假死掩护与金蝉脱壳（秘密转运） | `redeem_emperor` |
| `scene06` | 1822-03-14 | 信天翁号沉船；水桶、物资、龙骨与配给账 | `establish_rations` |
| `scene07` | 1824-09-13* | 星期五鲸骨图；毒蛇号身份与人质危机 | `expose_viper` |
| `scene08` | 1824-09-14 | 花岗岩宫工坊；三项虚构行动凭证 | `prepare_operation` |
| `scene09` | 1824-09-15 | 骷髅礁交割；罗伯茨、救回科尔索与接管毒蛇号 | `capture_viper` |
| `scene10` | 1829-11-02 | 鹦鹉螺号；四海同盟与深海金库授权 | `audit_alliance` |
| `scene11` | 1831-04-01* | 维哥湾；腐蚀银元、诱饵金盘与史密斯 | `expose_vigo` |
| `scene12` | 1834-12-01* | 亚特兰蒂斯；山铜查验、储备分割与拨款抉择 | `cut_orichalcum` |
| `finale` | 1835-11-09 | 泰晤士河口；总册核验与军需总监大印 | `close_ledger` |

带星号的日期只有月份来自原稿。为满足排序和存档契约，通常取当月第一日；第七场排到9月13日以衔接14日和15日。具体日号属于实现默认值。日期表示剧本时间，`day` 表示游戏的行动日，两者不以真实天数直接相减。

## 关键物证与四种查验

| 物证 ID | 关键证据 | 作用 |
| --- | --- | --- |
| `elba_watch` | VI 刻度、C. S. — 1498、重量缺口、底盖回音、法利亚密信 | 获得随行名额并保存前后呼应的旧表 |
| `longwood_linen` | 异物外观、封存登记、虚构化验报告 | 设置 `arsenic_evidence`；保留原稿“1817·铁证”的意义 |
| `marengo_sabre` | B&W 1816 与1800年出处矛盾、粗劣蜂纹、空洞回音 | 揭穿圈套；原稿二十英镑汇票与警戒 −30 |
| `emerald_vial` | 瓶封、密信拼合、过秤校准任务凭证 | 设置 `escape_prepared`；第五场兑换脱身结果 |
| `whale_bone` | HMS Viper — 1823、倒置暗礁图 | 设置 `viper_identified`，支持第九场接管舰只 |
| `forfeit_barrel` | 工兵验收、交割封签、救援协调 | 设置 `operation_prepared`；没有现实制造过程（id 里的 forfeit 是内部名，玩家看到的是「三层封存军需桶」） |
| `vigo_coins` | 真币与腐蚀币听音、1830新刻痕、交接记录 | 设置 `vigo_decoy_exposed`，或选择误收导致追踪 |
| `orichalcum` | 幻想比重、祭坛纹章、轮机与母币两份计划 | 设置 `orichalcum_cut`；推进银行或远航抉择 |

41 项查验覆盖四种操作（命令仍叫 `campaign.appraise`）。原稿的嗅觉、特殊实验与电导检查按其证据用途归并到察看、过秤、听音和破译，不新增前端实验操作。查验取得线索；有条件的选项才产生剧情结果，不能仅凭阅读观察文字就直接领取所有成就。

## 数值、行动日与市镇

下列数值来自原稿：红旗（就地征发）每日警戒 +15，白旗（照常行军）0，黑旗（闭营清点）每日警戒 −10 并消耗10先令；庄园医疗补给限五日；治安保证金50英镑；假佩剑事件交付20英镑汇票后警戒 −30；警戒满100会触发危险结算。营令三色旗就是 `campaign.sign` 的 `white/red/black`，命令和存档键没变。

第一部用整数先令入账，20先令为1英镑。因此保证金为1000先令，假佩剑汇票为400先令。序曲与圣赫勒拿开账军费各6000；岛上配给账开账4000，深海账开账8000。这些军费、同盟威望60、警戒10、体力与士气70、财富阈值20000及其余选项增减都是实现默认值，原稿没有提供完整平衡表。

章节转换保留旧账到 `chapter_balances`，用新章节的 `treasury_start` 开立新币制账户；这不是把先令和深海金砖按同一汇率相加。同盟威望、警戒、体力与士气和任务标记跨章保留。岛屿建设、深海探索范围为0至100。体力与士气依章节分别代表皇帝健康、要塞完整度、潜艇动力。

第一场建立 `medicine` 与 `bond` 两个催逼，均在当前行动日 +5 到期。原稿的保证金是周末前；把它同样设为五个行动日是首场统一催逼窗口的实现选择。药品催逼消费 `medicine` 凭证、无需额外现金；保证金消费1000先令。完成产生 `medicine_delivered` 和 `bond_paid`。第一场的两条推进选择都会给药品；推进后可在下一场立即交付，或者在第一场先从市镇补给购入并交付。离开圣赫勒拿时仍未完成的催逼结为逾期。

`campaign.visit` 提供市镇补给（`town`）与密探联络（`backdoor`）两种行动。市镇补给支出100：第一部可购得普通医疗补给；其他章节作为补给与联络活动。密探联络提供隐蔽联络。市镇、密探和买卖均按每场一次记录，防止重复领奖。营地事务牌与面板显示这些操作；数据不要求新增界面。

运行时附加默认值：公道买卖增加200军费与4同盟威望；假币黑市生意增加1500军费、减少20同盟威望、增加10警戒；岛上建设花费200增加25建设；深海探索花费200增加25探索；直接支持大陆拨款花费1000并增加15同盟威望。这些是独立的通用营地操作。剧情选项使用 JSON 中显示的自身数值。是否还有可用活动与行动回执，以运行时可用动作和结果为准。

所有场次都有不要求线索的推进分支。第四场未完成凭证可走备用转运；第八场未准备行动，第九场仍可赎人撤离；维哥湾可以整批隔离，缺少查验时不必接受致命诱饵。备用转运、延期和放弃缴获会失去完美条件，但不会因为缺少完美标记而把流程锁死。军费耗尽、体力与士气耗尽和警戒满值属于独立失败状态。

## 四个结局的条件与可复现路线

下表按运行时优先级排列。每次选择前，应先取得该场所需的查验线索；支线选择必须在推进选择之前执行。

| 结局 ID | 条件 | 正常操作路线 |
| --- | --- | --- |
| `tragedy` | `vigo_decoy_missed` 且警戒达到100 | 推进至第十一场，选择 `accept_vigo_decoy`；该选项明确警告结果并增加100警戒，立即结算悲剧 |
| `dark` | 当前军费大于20000、同盟威望小于30，同时有 `theft_treasure` 和 `counterfeit_trade` | 理想路线到第十场；先执行 `theft_treasure` 再 `audit_alliance`；第十一场先查验 `vigo_ring`，执行 `counterfeit_trade` 再 `expose_vigo`；其后正常分割山铜与封账（结局标题「深海利维坦的财政官」） |
| `ghost` | 建设100、探索100、`refused_funding` | 按理想路线推进；第十二场先 `choose_autonomy` 再 `cut_orichalcum`，最终封账（结局标题「永不靠岸的幽灵舰队」） |
| `alliance` | `escape_prepared`、`arsenic_evidence`、`viper_captured`、`vigo_decoy_exposed`、`orichalcum_cut` 全部成立，且未满足以上优先结局 | 完成下列理想路线，保存证据并避免背叛与误收 |

完整理想选择序列：

```text
prologue secure_passage
scene01  seal_evidence
         随后立即完成 medicine 与 bond 两项催逼
scene02  expose_sabre
scene03  audit_accounts
scene04  prepare_escape
scene05  redeem_emperor
scene06  establish_rations
scene07  expose_viper
scene08  prepare_operation
scene09  capture_viper
scene10  audit_alliance
scene11  expose_vigo
scene12  cut_orichalcum
finale   close_ledger
```

理想路线的建设进度为35 +20 +25 +20 =100；探索进度为35 +30 +35 =100，不依赖重复刷通用活动。幽灵路线只需追加自主选择。暗黑路线在深海开账之后执行私吞，避免依赖已封存的第一部币制余额；两项背叛各减少65同盟威望，因此即使此前威望满值，正常后续奖励也不会把它抬回30以上。同名早期私吞不会替代第二种背叛。

`choose_autonomy` 设置 `refused_funding` 并清除 `revolution_funded`；`fund_revolution` 做相反操作。两种入口应由运行时共同处理，不能把相互矛盾的拨款状态保存成同时成立。

没有满足四个原稿结局条件而安全抵达终局时，运行时提供 `bittersweet` 收束；另有 `bankruptcy/loss/blockade`（军费告罄、最后的灯火、封锁线合拢）作为失败状态。这些不是原稿新增的第五至第八种正式结局，不进入数据的四结局目录。

## 验证范围

数据结构核验覆盖来源哈希、四章十四场顺序、24名人物、八件关键物证、41项查验、34项选择、引用完整性、合法效果字段和每场的恢复分支。运行时命令测试应从真实初始状态执行四条结局路线、药品与保证金的履约和逾期、三面营令旗、重复行动拒绝及存档回放；不能直接改存档标记来“证明”结局可达。

## 拿破仑肉鸽扩展层（卡牌 + 多币种小道具 + 明日方舟网格战斗 + 战役间三合一玩法）

在保留 Godot 4.7.1 引擎、v0.9 肉鸽账簿（`RunKeeper` / `CardProfile` / 博古格）及完整 14 场剧情与固定结局的基础上，`scripts/cards/campaign/ocean_rogue_data.gd`、`scripts/cards/campaign/ocean_rogue_rules.gd` 实装了以下肉鸽机制（2026-11-01：Gemini 的 6×4 战术网格 `ocean_battle_panel.gd` / `battle_grid` 和 `campaign.battle_start / battle_scout / battle_deploy / battle_skill / battle_step / battle_retreat` 已拆掉，战斗换成战斗规则 v2，见 `docs/cards/BATTLE_V2.md`「界面与剧情门槛」）。`ocean_rogue_data.gd` 只放 id 和数值；伙伴、道具、羁绊、行军格、路线、小活动、营地日程和大命运的名字与说明在 `data/campaigns/text/ocean_rogue.json`，加载时按 id 合进同名的表（`COMPANIONS[id].name` 等，形状和以前的常量一样，只读）。

1. **手牌 + 四种功能币 + 大富翁式小道具 (`coins` & `props`)**：
   - **帝国金币 (`gold`)**：在募兵驿站招募伙伴、在行商处购置战术小道具。
   - **军需券 (`supply`)**：原先是战术网格的部署费用；战斗 v2 部署用战场里的军令点，军需券现在只在营地日程、行军、小活动和大命运里进出。
   - **荣誉勋章 (`medal`)**：晋升伙伴等级、强化伙伴生命与攻击、提升羁绊梯队。
   - **密报情报币 (`intel`)**：战前或战中侦察敌军推进路线、削弱敌方攻击并解锁分支。
   - **8 种大富翁式战术小道具 (`prop:*`)**：`prop_loaded_dice`（遥控罗盘骰）、`prop_barricade`（铁木拒马路障）、`prop_forced_march`（帝国急行军靴）、`prop_spyglass`（黄铜单筒望远镜）、`prop_smoke_bomb`（炼金掩护烟幕弹）、`prop_field_ration`（朗姆酒与军粮桶）、`prop_bribe_pouch`（密使金币袋）、`prop_imperial_decree`（帝国鹰徽嘉奖令），保存在留存牌（`kept`）中，白天打出（`campaign.use_prop`）。原先对战术网格的效果随网格一起拆掉了；战斗 v2 里还没有道具（拉雷的担架等留给以后），道具描述里“战场使用”的半句暂时不生效。
2. **明日方舟式 2D 回合制战术网格 + 伙伴羁绊 + 一条命 + 统帅亲征 + 大命运**：
   - **战场（战斗规则 v2）**：每一场都有一仗。白天打出手里的「战场」牌：出征名单（`battle_lineup`）→ 满屏战场（`battle_v2`，部署、朝向、技能、军令牌、交火、撤销、换牌、撤退）→ 战果（`battle_result`，命悬一线的铜钱）。推进剧情的决定要等这一仗了结（打赢、撤出，或者打输后处理完大命运）。规则见 `docs/cards/BATTLE_V2.md`。
   - **8 名伙伴与 5 大羁绊 (`bonds`)**：唐泰斯、古尔戈、法利亚、星期五、尼摩、莫雷尔、玛丽·朗热、科尔索分属 `imperial`（帝国旧部）、`far_sea`（远洋同盟）、`shadow`（暗影密使）、`scholar`（博学工坊）、`island`（荒岛求生）五大羁绊，2 名以上存活在队即激活阵营加成。
   - **伙伴只有一条命 (`permadeath`)**：伙伴在战斗中倒下后战后掷命悬一线的铜钱，全反面阵亡；或者在大命运中选择断后死战。阵亡即永久（`alive = false`，记入 `fallen_companions`），本局内无法再出征或复活。
   - **主角亲临前线**：出征名单上的开关。军心 +3、奖赏 ×1.5，但猎官和斩首令会盯着他；倒下掷 2 枚铜钱，全反面就是讣告，主角在场时战败直接被俘（转大命运）。
   - **战败触发大命运 (`campaign.big_fate`)**：战斗失利不直接锁死流程，而是触发大命运三选一：`sacrifice_rearguard`（断后死战·牺牲一名伙伴保全大局）、`ransom_supply`（割让军需赎买，顺带赎回被俘的伙伴）、`desperate_breakout`（强行浴血突围）。突围永远选得了（体力与士气不够 12 时这一下耗尽，走“最后的灯火”），所以大命运不会卡死。
3. **战役之间的穿插玩法（避免积累与战役单调交替）**：
   - **大富翁式行军棋盘 (`campaign.roll_dice`)**：营地上叫「世界地图」。12 格环形行军棋盘（大本营、集镇、募兵驿站、沙龙、自由集市、决斗场、走私港、纪念碑、轮盘赌局、水手节庆、外交公馆、前哨遭遇战），掷骰前进并触发对应事件与绕圈奖励。拿破仑书里这一块换成真正的世界地图（`WORLD_MAP_DESIGN.md` §5）。
   - **分支路线图与穿插小活动 (`campaign.pick_route` & `campaign.activity`)**：提供 `salon_route`、`duel_route`、`smuggle_route` 三条分支路线，穿插沙龙、决斗、赌局、行商、休整、走私、节庆、外交等 8 种小活动。
   - **营地日程 (`campaign.schedule`)**：每周 3 格日程槽，用营地日程卡安排招兵、演练、伙伴羁绊剧情、外交、节庆、走私，倒计时归零后迎战大军团战役。
4. **3D/2D 美术资产管线（NVIDIA SimReady + GitHub glTF + 本机 Blender 4.0.2 光追渲染）**：
   - **`tools/cards/art/fetch_open_3d.py`**：从英伟达开源 3D 模型库 `nvidia/simready-assets`（Hugging Face OpenUSD 资产：`crate_plywood_a04`、`book_open_a01`、`decor_candle_a01`、`barrier_fence_metal_a02`、`container_jar_glass_gold_a01`）与 GitHub `KhronosGroup/glTF-Sample-Assets`（`RiggedFigure.glb`、`Fox.glb`、`Duck.glb`）拉取开源 3D 网格。
   - **`tools/cards/art/gen_napoleon_blender.py`**：调用本机 `/usr/bin/blender --background` 自动完成拿破仑主题 3D 建模与组装，导出 20 个 `.glb` 3D 模型至 `art/ocean_3d/models/`（含 `imperial_cannon.glb`、`bellerophon_ship.glb`、`nautilus_sub.glb`、`monopoly_dice.glb`、4 个 NVIDIA SimReady 道具模型、9 名友军与 3 类敌军 3D 模型），并通过 Cycles 光追渲染 32 张透明 PNG 图标与角色/地形立绘至 `art/ocean_3d/renders/`。`art/ocean_3d/` 有 `.gdignore`，不进导出包；战斗 v2 的界面不用这些渲染图，格子和单位都是程序画的像素块。

## 去当铺（2026-11，WORLD_MAP_DESIGN §12，C1）

**原则**：只换玩家看得见的字和美术描述；机制、id、命令、旗标、存档键一律不动。存档目录 `user://cards/ocean_pawn/`、环境变量值 `ocean_pawn`、单段书的 id、物品 id `forfeit_barrel`、旗标 `emperor_redeemed` / `ledger_closed`、结局 id `ghost` / `dark`、命令 `campaign.sign` / `campaign.appraise` 都是内部名，保留。

| 原来（当铺义） | 现在 |
| --- | --- |
| 远洋当铺（书名、标题） | 远洋（单段书和远洋分支）；整部游戏叫《鹰旗军需官》 |
| 海鸥号估值铺 / 当铺前堂 / 内堂 | 海鸥号补给栈（法国侨民开的船具补给栈，暗中接济朗伍德）/ 补给栈的货棚 / 补给栈后间 |
| 掌柜；学徒、守店 | 军需官 / 司库；勤务兵、守营 |
| 柜台挂牌：白牌平价典当 / 红牌军需特收 / 黑牌闭门盘库 | 营令三色旗：白旗·照常行军 / 红旗·就地征发 / 黑旗·闭营清点 |
| 鉴定（已鉴定的线索） | 查验：察看、过秤、听音、破译（已查验的线索） |
| 当物、当票、流当军需桶、流当大印、活当赎回 | 关键物证、调拨凭单、三层封存军需桶、军需总监大印、金蝉脱壳（秘密转运） |
| 营业日 / 开张 · 今日行动 / 结账 · 等待明日 / 夜 · 结账 | 行动日 / 拔营 · 今日行动 / 扎营 · 等待明日 / 夜 · 点名 |
| 经营须知 | 军需官手册 |
| 金库储备 / 生命与动力 | 军费 / 体力与士气（指标键 `treasury` / `vitality` 不变） |
| 营地牌：柜台挂牌、街区暗访、后门密访、资源与援助、行军棋盘、据点周历、金库与航海日志 | 营令、市镇补给、密探联络、工程与援助、世界地图、营地日程、军需账簿与航海日志（牌 uid 不变） |
| 永不靠岸的幽灵当铺 / 深海利维坦的账房先生 | 永不靠岸的幽灵舰队 / 深海利维坦的财政官 |
| 黄铜天平（序曲标题、讣告、结局） | 厄尔巴双面金怀表、军需官的账簿 |
| 航海旧账、书架上的账本 | 战役档案、回忆录书架 |
| 玛丽·瓦伦丁、科尔索·老炮手 | 玛丽·朗热（随军军医）、科尔索（科西嘉神枪手） |

**字在哪里**（都归内容包 C；改字不改别的）：

- `data/campaigns/ocean_pawn.json`：剧情、人物、物品、结局（由 `docs/cards/world/drafts/ocean/ocean_scenes_rewrite.json` 生成，同目录 `tools/apply_rewrite.py` 逐键证明除文字以外与基线一致，段落数不变，`vn_cast.json` 的段号照样对得上）；
- `data/campaigns/text/ocean_ui.json`：`ocean_view.gd` 产出的全部界面字（营地覆盖层、指标名、营令名、账目、标题页、局外记录）；
- `data/campaigns/text/ocean_rogue.json`：`ocean_rogue_data.gd` 各表的名字与说明；
- `data/hd/hub_ui.json`、`data/hd/vn_ui.json`：高清营地与剧情 VN 的界面字；
- `data/campaigns/ocean_battle.json` 的 `text` 块（战果入账、讣告、大命运），`data/campaigns/battle_ui.json` 的 `text.result_done`（「记进战史」）；
- `data/hd/art_list.json` 里 12 项远洋美术的 name / desc（补给栈、鹰徽、罗盘，不再画天平和当进来的物件；id 不改）。

**防回潮**：`scripts/tests/cards/OCEAN/test_content.gd`（`OCEAN_content`，在 `tools/run_ocean_tests.sh` 里）。它扫 §12.3 的 19 个词（当铺、典当、当票、流当、估值铺、掌柜、挂牌、柜台、活当、收当、盘库、鉴定、营业、经营须知、当物、赎当、押当、典押、账房先生）：

1. 拿破仑线全部玩家可见数据（上面这些文件、`data/campaigns/napoleon/**`、`data/campaigns/text/*.json`、`vn_cast.json`、有了以后的 `map_ui.json`）；
2. 远洋线脚本的字符串字面量（`ocean_rogue_data.gd` 连中文都不许有）；
3. 五条结局路线逐步重放时 `ocean_view` 产出的所有字；
4. 真根场景里的标题页（不许有「当」字）、序曲 VN 的标题卡（不许有「天平」）、营地主画面、营地事务面板、手册、暂停、设置、信物、档案、出征名单、日终面板。

docs、注释和旧版 1938 的目录不扫。窗口标题等于书名一项等 A2（§12.2 第 10 条）做好后打开（`WINDOW_TITLE_READY`）。
