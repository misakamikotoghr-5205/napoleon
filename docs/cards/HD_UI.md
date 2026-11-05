# 拿破仑篇高清界面：公用件（HD kit）

> 2026-11-01，Claude 起草。拿破仑篇（远洋战役）不再用像素风：剧情做成 FGO 那样的视觉小说（大立绘、全屏背景、
> 名字牌、文本框），战斗做成明日方舟那样的斜俯视战场（部署卡条、费用、单位信息、技能/撤退按钮、敌人路线预告）。
> 只借这两类游戏的通用版式，不用它们的任何素材、图标、logo、字体，也不照抄画面。
> 美术规则和清单：`docs/cards/art/hd/HD_ART_RULES.md`、`data/hd/art_list.json`。

这一层是剧情 VN 面板和战场/HUD 共用的底子，只管“图从哪来、长什么样”，不碰战斗规则和战役逻辑。

## 文件

| 文件 | 干什么 |
|---|---|
| `scripts/cards/ui/hd/hd_art.gd` | 找图：按清单的 `kinds.path` 去 `res://art/hd/` 找真图，找不到回 `null` / `[]` |
| `scripts/cards/ui/hd/hd_theme.gd` | 样子：配色、字体、面板框、按钮、标签 |
| `scripts/cards/ui/hd/hd_placeholder.gd` | 占位和统一入口：`make_bg` / `make_chara` / `make_face` 有真图用真图，没有画占位 |
| `hd_box.gd` `hd_draw.gd` `hd_ph_bg.gd` `hd_ph_chara.gd` `hd_ph_face.gd` | 内部件：叠层框、画图小件、三种占位控件 |
| `scripts/tests/cards/OCEAN/test_hd_kit.gd` | 无头测试 `OCEAN_hd_kit`（在 `tools/run_ocean_tests.sh` 里） |

都没有 `class_name`，用的地方 preload：

```gdscript
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
```

## 回退规则：有真图用真图，没有就画占位

- `art/hd/` 里现在一张图都没有。所有界面必须在全是占位的情况下就好看；美术把图放进 `art/hd/`（按规则命名）以后，
  下次启动自动换成真图，不改代码。
- 找图先 `ResourceLoader.exists` 再 `load`，找不到不报错；找到的和找不到的都缓存（找到的最多留 96 张，最近用过的优先）。
  美术中途加图、测试换图时调 `HdArt.clear_cache()`。
- id、表情、状态只认小写字母、数字、下划线，别的（比如 `../`）一律当找不到。
- 头像、小人、地块、立绘这几类会缩得很小，导入时没生成 mipmap 的，`HdArt` 读进来时补一份（无头模式跳过）。
- `make_*` 造出来的节点都带 meta：`hd_placeholder`（true = 占位）、`hd_id`；都不接鼠标，线性过滤 + mipmap。

## API

### HdArt（找图）

```gdscript
static func data() -> Dictionary                                   # 整份清单（只读）
static func entry(kind: String, id: String) -> Dictionary           # 清单里的一项，没有回 {}；kind = bg cg chara face unit tex side prop
static func assets(kind: String = "") -> Array                      # 某一类的全部条目（清单顺序）
static func display_name(kind: String, id: String) -> String        # 条目的中文名，没有回 id
static func bg(id: String, variant: String = "") -> Texture2D       # bg/<id>[__variant].jpg|png；变体没有退回本图；都没有 null
static func cg(id: String) -> Texture2D
static func chara(id: String, expr: String = "normal") -> Texture2D # 没有这个表情退回 normal；都没有 null
static func face(id: String) -> Texture2D
static func unit_frames(id: String, state: String) -> Array         # <state>_01.. 连续帧（Texture2D），没有 []
static func unit_meta(id: String) -> Dictionary                     # {"fps": 12, "attack_hit_frame": n}，n 默认攻击帧数一半（向上取整，至少 1）
static func unit_anchor() -> Vector2                                # 双脚中点 (192, 336)，来自 kinds.unit.anchor
static func unit_size() -> Vector2                                  # (384, 384)
static func tile_tex(id: String) -> Texture2D                       # tile/<id>.png（顶面 tex 或侧面 side_earth / side_rock）
static func terrain_tex(terrain: String) -> String                  # 战斗地形 -> 地块贴图 id（清单 tex 条目 terrain 字段里第一个列了它的），没有 ""
static func prop(id: String) -> PackedScene                         # prop/<id>.glb
static func accent(id: String) -> Color                             # 每个 id 固定的强调色（hd_accent_0..11）
static func accent_index(id: String) -> int
static func has_art(kind: String, id: String, fields := {}) -> bool # 只查路径不读图
static func clear_cache() -> void
```

地形对照（现在的清单）：plain/gate/eagle → grass，road → road，high → rock，village → village_ground，
woods → forest_floor，river → water，ford → ford，marsh → marsh，earthwork → earthwork_top。
**bridge 没有自己的地块**：底下铺 water，上面摆 `prop/bridge`。

强调色：主角 villefort 是金色，几位主要人物固定一色（`ACCENT_FIXED`），其余按 id 散列；`enemy_*` 只在红色系里挑，
`troop_*` 只在蓝色系里挑。立绘轮廓光、头像圆环、名字牌的点缀都用它。

### HdTheme（样子）

```gdscript
static func color(key: String) -> Color                  # hd_* 配色键（不写 hd_ 前缀也行）
static func alpha(key: String, a: float) -> Color        # 同一键乘透明度
static func mix(a: String, b: String, t: float) -> Color
static func size(role: String) -> int                    # tiny 12 small 14 ui 16 num 18 body 20 name 22 big 26 title 34 hero 52
static func font(kind: String, spacing: int = 0) -> Font # serif（剧情正文）title（衬线加粗、字距 +2）sans（界面）sans_bold / num
static func panel_box(kind: String) -> StyleBox          # 见下表；每次新建，随便改
static func box(spec: Dictionary) -> StyleBox            # 按规格造框（写法见 hd_theme.gd 的 PANELS 说明）
static func apply_button(btn: Button, kind: String) -> void   # primary secondary danger ghost choice icon
static func make_label(text: String, size: int, kind := "sans", color_key := "hd_text") -> Label
static func apply_hd_filter(node: CanvasItem) -> void    # 线性过滤 + mipmap
```

面板框 `panel_box(kind)`：

| kind | 用在 |
|---|---|
| `glass` | 默认的深蓝玻璃面板（透明度 0.82、双金边、上半截微光、柔和外影） |
| `glass_strong` | 更实的玻璃（弹窗、单位信息栏） |
| `glass_soft` | 无边的淡玻璃（底条、提示区） |
| `parchment` | 羊皮纸（文书、战报、结局卡），上面的字用 `hd_parchment_ink` |
| `textbox` | VN 文本框（宽内边距 44×26） |
| `nameplate` | VN 名字牌（左边一道粗金条） |
| `card` / `card_selected` | 部署卡、出征名单卡；选中是亮金边 + 金色外发光 |
| `chip` | 小药丸（费用、标签、状态） |
| `tooltip` | 悬停提示 |
| `hud` | 顶栏（只有下边一道金线） |
| `slot` | 空位（部署槽、名单空格） |
| `header` | 面板里的小标题条 |

双金边和微光是 `hd_box.gd`（几层 StyleBoxFlat 叠着画）；要改颜色就改 `box.outer()`（底色、外边、影子）和
`box.inner()`（第二道细边）。没有内边和微光的 kind 直接是 StyleBoxFlat。

按钮 `apply_button(btn, kind)`：设好 normal / hover / pressed / hover_pressed / disabled / focus 六个框、字体、字号、
各状态字色和图标色，鼠标变手形，最小尺寸只往大里改；`btn.get_meta("hd_button")` 是 kind。

| kind | 样子 |
|---|---|
| `primary` | 金色大按钮，深色衬线字 22，高 48（出征、交火、继续） |
| `secondary` | 深蓝底金边，金色无衬线字 17 |
| `danger` | 蜡封红（撤退、放弃） |
| `ghost` | 无底，悬停才出淡金底（次要操作、跳过） |
| `choice` | 剧情选项：宽 520 起、高 54、衬线字 20 |
| `icon` | 圆角小方块 40×40（倍速、暂停、技能） |

### HdPlaceholder（占位和统一入口）

```gdscript
static func make_bg(id: String, title := "", subtitle := "", variant := "") -> Control   # 真图：铺满裁切的 TextureRect；否则章节卡（title 空 = 清单名）
static func make_cg(id: String, title := "", subtitle := "") -> Control
static func make_chara(id: String, name := "", expr := "normal") -> Control             # 真图：按比例居中的 TextureRect（不裁头）；否则剪影
static func make_face(id: String, name := "") -> Control                                # 真图：按比例居中；否则圆章
static func set_chara_expr(node: Control, id: String, expr: String) -> void              # 已造好的立绘换表情（真图换贴图、占位换徽记）
static func is_placeholder(node: Node) -> bool
static func bg_control(id: String, title: String, subtitle := "", mood := "", kind := "bg") -> Control
static func chara_control(id: String, name: String, expr := "normal") -> Control
static func face_control(id: String, name: String) -> Control
static func make_tile_tex(id: String) -> Texture2D       # 真图或无缝噪声占位（128 像素，带 mipmap，2D 平铺、3D 材质都能用）
static func tile_texture(id: String) -> Texture2D        # 只要占位
static func mood_for(id: String) -> String               # night sea lamp interior dusk deep day
```

- **背景占位**是一张“章节卡”：按地点气氛（`MOOD_TABLE` 按 id 写死，变体名是气氛名时按变体，比如 `__night`）画三段渐变、
  光斑、气氛纹样（星空和月光倒影、海浪和远岛、船肋和灯、窗光、风暴和礁石、深海光束和气泡、远山），星盘纹饰、暗角、胶片颗粒，
  中间是地点名和副标题。右上角的 `BG <ID>` 小字只给美术对号用，默认不画：项目设置
  `dehoudang/hd/show_art_ids = true` 或环境变量 `DEHOUDANG_SHOW_ART_IDS=1` 时才画。开始对话后把地点名淡出：
  `create_tween().tween_property(bg, "title_alpha", 0.0, 0.5)`（真图没有这个属性，先 `is_placeholder` 再调）。
- **立绘占位**是 1200:1800 的剪影（在控件里按比例居中、底边对齐）：外套翻领、领巾、扣子（神甫长袍、玛丽长裙披肩），
  按人物戴帽子，左上主光、右后方强调色轮廓光，右上角表情徽记（normal 不画），底部名字；有名字牌时 `node.show_name = false`。
- **头像占位**是圆章：强调色圈、金细圈、名字第一个字。

## 视觉语言（帝国蓝金）

配色键全在 `data/cards/theme/palette.dev.json`，都以 `hd_` 开头（正式配色 palette.json 由主创定，不改）：

- 底：`hd_navy` #0f1a2e、`hd_navy_2` #1b2a4a、`hd_navy_3`、`hd_ink`（最深）、`hd_glass`（0.82 透明）、`hd_glass_strong`、
  `hd_card`、`hd_card_hi`
- 金：`hd_gold` #c9a45c、`hd_gold_hi` #e8d29a、`hd_gold_deep`
- 纸和蜡：`hd_parchment` #efe4c8、`hd_parchment_2`、`hd_parchment_ink`、`hd_wax` #8e2a2a、`hd_wax_hi`
- 字：`hd_text` #f3efe6、`hd_text_2`、`hd_text_3`
- 阵营和状态：`hd_ally` #3f7fd0、`hd_ally_hi`、`hd_enemy` #c0453a、`hd_enemy_hi`、`hd_good`、`hd_warn`
- 杂项：`hd_shadow`（黑，用 `alpha()` 调）、`hd_white`（高光，用 `alpha()` 调）
- 强调色：`hd_accent_0` … `hd_accent_11`
- 背景气氛：`hd_mood_<night|sea|lamp|interior|dusk|deep|day>_<top|mid|bottom|glow|line>`
- 地块占位：`hd_tile_<地块 id>`、`hd_tile_<地块 id>_dark`（grass road rock village_ground forest_floor water ford marsh
  earthwork_top side_earth side_rock）

字体：衬线先找系统的 Noto Serif CJK SC / 思源宋体 / 宋体，都没有就用仓库里的 `fonts/NotoSerifSC-Regular-subset.otf`
（远洋战役、战斗文字表、美术清单里用到的字它全有，也有拉丁字母）；无衬线先找 Noto Sans CJK SC / 微软雅黑 / 苹方 /
文泉驿，最后是系统的 sans-serif，缺字回落到衬线子集。新代码不用像素字体、不做整数倍放大。

## 显示

- 逻辑画布 1280×720（`canvas_items` 拉伸、保持比例），按窗口分辨率渲染：1080p 上字和高清图都是清楚的。
- 高清面板的根节点调一次 `HdTheme.apply_hd_filter(root)`（子节点继承线性过滤 + mipmap）。旧的像素版界面不调，
  也不要改项目的全局过滤设置。
- 画东西用抗锯齿的 `draw_*`、StyleBoxFlat 圆角和柔和外影；动效用 tween。

## 剧情 VN 层怎么用

- 全屏背景：`HdPlaceholder.make_bg(bg_id, "", "", variant)` 铺满；有占位时开场显示地点名，说第一句话时淡出 `title_alpha`。
- 立绘：`make_chara(char_id, "", expr)`，左中右三个位置，高约 680/720，底边贴屏幕下沿；说话的人亮、其他人压暗（modulate）；
  换表情 `set_chara_expr`；占位上把 `show_name` 关掉（名字牌已经有名字）。
- 文本框 `panel_box("textbox")` + 名字牌 `panel_box("nameplate")` 压在文本框左上角；正文 `font("serif")` 20 左右，
  名字 `font("title")` 22 `hd_gold_hi`；选项 `apply_button(b, "choice")` 竖排居中。
- 中文界面字放 `data/hd/vn_ui.json`，代码里不写中文字面量。

## 剧情 VN（已做：`scripts/cards/ui/vn/`）

远洋战役的金色剧情牌（uid `story:<场次>`）打出来开满屏的剧情 VN（面板 kind `vn`，在 `modal_host.gd` 的
`SCRIPT_PANELS` 和 `FULLSCREEN` 里登记；`ocean_view.gd` 给剧情牌的 `panel` 是 `vn`）。别的远洋牌见下面「营地」。

| 文件 | 干什么 |
|---|---|
| `vn_panel.gd` | 面板：背景、立绘台、文本框、名字牌、右上角按钮、抉择菜单、线索框、记录、章节卡 |
| `vn_script.gd` | 把剧情牌正文拆成一句一句（不改写正文）：谁在说话、引号后面的旁白、长句切块、每段的演出 |
| `vn_stage.gd` | 立绘台：最多三人，一人居中、两人左右、三人左中右；说话的亮、其他人压暗略缩；滑入滑出；换表情 |
| `vn_deco.gd` | 只画的小件：上下压暗渐变、跳动的“下一句”箭头、章节卡横带、金线菱形饰 |
| `vn_data.gd` | 读 `data/hd/vn_ui.json`（界面字）和 `data/hd/vn_cast.json`（人物叫法和每场演出） |
| `scripts/tests/cards/OCEAN/test_vn.gd` | 无头测试 `OCEAN_vn`（在 `tools/run_ocean_tests.sh` 里） |

**流程**：开场章节卡（部、场次标题、日期、地点，2.6 秒后或点一下淡出）→ 开场的人滑上台 → 一句一句（打字机每秒约
40 字；点一下 / 空格 / 回车先出全句，再点下一句；整句出完右下角金箭头跳动）→ 正文放完（已鉴定的线索各一句）出抉择菜单。
菜单里鉴定和决定都是选项（数字键 1–9 也能选），灰的写原因（缺鉴定时列出还缺哪几项、等本场的仗、前情没准备好……），
左边线索框列出已鉴定的观察，右边“账面”列出金库（币名单独一行小字）、同盟威望、敌方警戒、生命与动力、建设 / 探索
（选项要花这些，选的时候看得见），底下是“重看本场”和“稍后再来”。菜单按实际高度排：放不下先挤一挤（行矮一点、间距小一点），
还放不下中间的选项滚动，“重看本场 / 稍后再来”那一行永远在屏幕上（第十一、十二场仗没打时决定全灰、每行多一行原因，最高）。
菜单开着时台上的人淡到 45%，灰的选项底几乎不透（`hd_theme` 的 `choice.disabled`），后面的外套扣子不再透出来；
出菜单时正文里换场景亮起的地点横幅收掉，换到菜单背景也不亮横幅。点鉴定：发 `card.choose`，观察结果当一句话放出来，
再回菜单。点决定：发 `card.choose`，先放“抉择”那一句，再放结算（同盟威望等的变动、行军箱进出、翻到新的一部、
下一场的标题；结局就说航程合上账簿），最后一下关面板。同一局里看过的场次再打开直接到菜单（记录里有全文）。

**右上角**：自动（读完一句自己接下一句）、快进（一路放到抉择菜单就停，按住 Ctrl 也一样；结算放到最后一句停，不替玩家关面板）、
记录（全部台词带名字，可滚动；鼠标滚轮往上也能打开）、隐藏（右键也行，点任意处恢复）、稍后（关面板，不发指令）。
地点牌、右上角这排按钮和地点横幅在单独的一层（`Top`），画在抉择菜单的压暗层上面：选的时候“记录”“隐藏”照样点得到。
Esc 走宿主的 `close_top` → 面板的 `dismiss()`：先关记录、再恢复隐藏，最后才关面板；没有面板时 Esc 照旧开暂停菜单。

**正文从哪来**：只读引擎。`engine.query(card)`（选项、灰的原因、已鉴定的观察）、`engine.query(campaign)`
（结算前后的指标、场次、部）、`engine.view()`（日期、行军箱），只发 `card.choose`。正文是 `ocean_view.gd` 覆盖层里
`ocean.scene.<id>` 的 `paras`（剧情牌 body 原样的段落）、`title`、`chapter`、`location`、`choices.*`；剧情牌的选项多带了
`reason`（引擎的原因码）和 `needs`（还缺的鉴定）。存档读档后照样能开。

**拆句规则**（`vn_script.gd`）：一段以“叫法（可带 说道 / 答道 / 转述 …）：“……””开头 → 这个人说的一句（只取引号里的话，
名字牌写正文里的叫法），引号后面剩下的再看一遍（还是“叫法：“”就是下一个人说的，否则是一句旁白）；别的段落是旁白（没有名字牌）。
旁白以某人的叫法开头、里面又有引号（“维尔福敲响天平：“……””）时，这个人上台并被照亮，这句仍按原文当旁白放。
超过 150 字的一句按句末切开。说话的人不在台上时自己上台（台上满三人时让最久没说话的人下去）。
立绘是占位剪影时，肩线上挂一枚名字牌（`NameChip`，每个人都挂在同一条线上：占位剪影画布 y≈615，`vn_stage.gd` 的 `CHIP_LINE`，
不压脸），台上几个长得一样的剪影分得清；有了真立绘不挂。抉择菜单压暗台子时、对话记录开着时名字牌收起。
对话记录开着时顶栏（地点签、自动 / 快进 / 记录）也收起，不从记录框后面露半截。换地点时顶上横幅亮着，左上角的地点签先藏起来，
横幅淡出以后它再淡入（同一个地名不同时出现两次）。
章节卡：部名和场次标题说的是同一件事时（序曲）只写大标题（`hd_text.gd` 的 `same_title`）。文本框底色 0.94，几乎不透。

**演出表 `data/hd/vn_cast.json`**：
- `chars.<人物 id>`：`aliases`（正文里的叫法，长的优先匹配）、`art`（立绘 id，`morrel` 的立绘是 `morel`）、
  `placeholder_only`（清单里没有立绘条目的：潜水长、史密斯）。24 个人物都有。
- `scenes.<场次>`：`bg`（`[{id, at, variant?}]`，at 是从第几段正文起换，`"choices"` 是出菜单时换；第一项 at 必须是 0）、
  `cast`（开场在台上的人 `[{who, at: left|center|right}]`）、`enter` / `exit`（段号 → 上场 / 下场）、
  `expr`（段号 → `{人物: normal|smile|angry|sad|surprise}`）。段号从 0 数，对应剧情牌 body 的段落。
- 换背景时交叉淡化，顶上亮一下地点名横幅；左上角一直写着当前地点。第十场开头用 `new_elba_shoal__night`（清单已登记，
  没有这张图时用白天那张；占位按夜景气氛画）。

界面字全在 `data/hd/vn_ui.json` 的 `text`（灰的原因在 `text.reason.<原因码>`）。

## 营地（已做：`scripts/cards/ui/hub/`）

远洋战役不再回到像素的柜台和手牌扇：根场景（`card_game_root.gd`）发现远洋战役开着（引擎里有 `_ocean`）就在牌桌后面、
叠层宿主前面插一层满屏的高清营地（`hub_panel.gd`，z 250，盖住整张牌桌含牌桌顶层；标题压着时藏起来），旧的打烊铜牌藏起来，
抽屉框挪到营地上面（z 260），像素飘字和像素对话框（晨报）不再出。旧版战役（`DEHOUDANG_CAMPAIGN=legacy`）什么都不变。

| 文件 | 干什么 |
|---|---|
| `hub_panel.gd` | 营地主画面：顶栏（部、场次标题 · 日期 · 第几场，金库和四五项指标，规矩 / 信物 / 档案 / 设置 / 菜单）、左栏伙伴（主角、伙伴头像、兵种等级、兵力条，阵亡的压暗）和部队、功能币；中间当前剧情大卡（这一场背景缩图、标题、地点、鉴定进度、能不能作决定）、本场战事卡（打输以后换成红色大命运卡，呼吸发光）、催逼、航海日志；右栏营地事务（八张，带可办件数）、行军箱（物件、道具）、结账按钮。数值变了在数字上飘 ± 字 |
| `hub_card_panel.gd` | 事务面板：营地事务、账簿、大命运、催逼、道具、物件、伙伴、规矩。左边文书（圆章、小标题、标题、正文；办过以后写结果：账面变动、功能币、行军箱进出），右边选项（和剧情 VN 同一套按钮，灰的写原因，1–9 选），底下“稍后再来 / 返回营地”。大命运用战场远景、红边。牌办完不在了就写“这件事已经了结” |
| `hub_phase_panel.gd` | 过场面板：开部（部名、币制）、日终结账（引擎报表）、换部、航程终了（结局插图、标题、正文、回到标题） |
| `hub_kit.gd` `hub_data.gd` | 小件（能点的卡片框、药丸签、圆章、背景压暗、飘字）；读 `data/hd/hub_ui.json`（营地的界面字），营地背景跟着这一场 VN 的第一张背景 |
| `scripts/tests/cards/OCEAN/test_hub.gd` | 无头测试 `OCEAN_hub`（在 `tools/run_ocean_tests.sh` 里） |

**点什么开什么**：营地上的卡片等于打出手里那张牌（根场景的 `_open_card`）：剧情开 VN，战场开出征名单 / 战场 / 战果，
别的开事务面板。结账按钮等于旧的“打烊 / 下一天”（根场景的 `_on_close_day`，字和样子也由根场景给：
`hub.set_end_state(title, sub, tone)`）。规矩开只读事务面板（`read` + `{"def": "ocean.rules"}`；正文用 `hub_ui.json` 的 `rules_body`，写真按钮「开始剧情」「排兵出征」「结账」，
不再说“打出金色剧情牌”），信物、档案开高清清单页，设置开高清设置，菜单开高清暂停。

**换面板不换 kind**：远洋战役开着时，根场景在叠层宿主里登记 `overrides`：`slots` / `read` → `hub_card_panel.gd`，
`month_open` / `settle` / `year_jump` / `game_over` → `hub_phase_panel.gd`。kind 不变（`top_kind`、`is_open`、
自动试玩、跟进指令都照旧认它），换上的都是满屏叠层（`is_fullscreen`）。指令和旧面板一样：事务面板只发 `card.choose`
（只读的牌不发），结账发 `settle.next`，换部发 `year.next`，开部只关面板，终了回标题。

**标题、暂停、设置、信物、档案、帮助也是高清的**（第二轮评审修正）：
- 标题 `hub_title.gd`：远洋战役时根场景 `_show_title` 造它（`_ocean_mode()`：真引擎、没指定旧版数据），旧版战役照旧
  `CardTitle.tscn`。它继承 `CardTitle`，只换样子：满屏 `bg/title`（没有图时是夜景占位 + 代码画的黄铜天平星盘纹章，天平轻轻摆），
  左边深蓝渐隐、题签、衬线金色大字、引子、高清按钮（启航金色主按钮 / 接续航程 / 设置 / 离开，节点名照旧 `new continue settings quit`）、
  一行说明（`hub_ui.json` 的 `title_hint`，说营地上的真按钮）；右下旧账盒换成玻璃面板、高清字、高清种子框和书脊。
  `chose`、`set_rogue`、`is_asking_new`、`show_error`、键盘绕圈都是父类的，测试按名字找的节点都在。
- 根场景开机时（远洋战役）就把 `overrides` 登记好，标题上点「设置」也是高清的。`modal_host.gd`：换上的面板一律按满屏叠层摆，
  原来是抽屉的（信物 / 档案 / 设置）不再进像素抽屉框。
- 暂停 `hub_pause_panel.gd`（继承 `CardPause`）：营地压暗、玻璃面板、圆章「憩」、金色「回到营地」（不再是“回到柜台”）、
  设置 / 经营须知 / 回到标题 / 离开游戏，回标题和离开先问一句（红色「确定」/「再想想」）。字在 `hub_ui.json` 的 `pause.*`。
- 设置 `hub_settings_panel.gd`（继承 `CardSettings`，读写和通知都照旧）：玻璃面板，金色滑条、四档文字速度、开关按钮、「收起」。
- 帮助（F1、暂停里的「经营须知」）：`help` 也换成 `hub_card_panel.gd`，打开就是经营须知。
- 信物 / 档案 `hub_list_panel.gd`：信物是一份文书（已收存几件 / 共几件，两列物件卡：圆章、名字、说明、第几日收存；一件没有时写空着的说明）；
  档案左边人物格子（头像圆章 + 名字，四列可滚动），右边选中那个人的立绘（占位剪影）、名字、正文，点格子换人，方向键也能换。

**结账按钮不再抢戏**：`hub_panel.pending_parts()` 数今天还没办的正事（这一场剧情牌还在手里 = 剧情未定；本场有仗没了结；
大命运待决；营地事务还能办几件）。有的话结账按钮退成次要样子（深蓝底），副行写「剧情未定 · 本场的仗还没打 · 还能办 N 件」
（`hub_ui.json` 的 `end_pending.*`），不再是金色“今天的事都办了”。剧情卡和战事卡上该走的那一步（「开始剧情」或剧情等着仗时的
「排兵出征」）是金色大按钮带金光，不是这一步的退成深底金字。

**其他小修**：营地事务的行高按栏里剩下的高度算（八件也不顶出栏底、不压行军箱，测试查两块不相交）；顶栏副标题先写「第 N/14 场 · 日期」，
这一场标题放最后（放不下省略的是标题）；顶栏指标的 ± 飘字从顶栏下沿往下飘，不压在“金库”这些字上。

## 战场（明日方舟式）怎么用

- 地块：`HdArt.terrain_tex(terrain)` 得到贴图 id，再 `HdPlaceholder.make_tile_tex(id)`（有真图用真图）；侧面用
  `side_earth`（平地）/ `side_rock`（高地）；桥是 water + `prop/bridge`。摆件 `HdArt.prop(id)`，没有时自己画简单形体。
- 小人：`HdArt.unit_frames(id, state)` 按 `unit_meta(id).fps` 播放，攻击在 `attack_hit_frame` 帧弹伤害；图的
  `unit_anchor()` 对准格子中心的地面点；朝左时水平镜像；没有帧时自己画占位小人（阵营色底环由游戏画）。
- 部署卡条：`panel_box("card")` / `"card_selected"` + `make_face(unit_or_troop_id)` + 费用 `chip`；单位信息栏
  `glass_strong`；技能、撤退按钮用 `secondary` / `danger` / `icon`；交火 `primary`。
- 战斗文字仍在 `data/campaigns/battle_ui.json`。
- 斜俯视 3D 战场已经做好（`scripts/cards/ui/battle/battle_board.gd` + `field/`，配色键 `bt3d_*`）：地块、摆件、小人、
  敌情、高亮都在板子里，HUD 只要把板子铺满全屏再 `set_safe_area(rect)` 让出自己的地方。细节见
  `docs/cards/BATTLE_V2.md`「3D 战场」。
- 战场 HUD、出征名单、战果三块高清面板已经做好（`battle_panel.gd`、`battle_lineup_panel.gd`、`battle_result_panel.gd`
  + `scripts/cards/ui/battle/hud/`，配色键 `bthud_*`）：部署牌、军令牌、单位身边的圆按钮、情报栏、名单立绘卡、战果的
  高清铜钱。头像先找 `face/<id>.png`，没有就截立绘头肩，再没有就是占位剪影。细节见 `docs/cards/BATTLE_V2.md`「高清 HUD」。

## 规矩（测试会查）

- `scripts/cards/ui/hd/` 下：没有 `class_name`；不写 `Color(…)`、`Color8`、`Color.html`（`Color.WHITE` / `TRANSPARENT` 除外）；
  字符串字面量只有 ASCII（中文放 JSON）；用到的 `hd_*` 键都要在 `palette.dev.json` 里。`scripts/cards/ui/vn/`
  （`OCEAN_vn`）和 `scripts/cards/ui/hub/`（`OCEAN_hub`）守同样的规矩。
- 只管表现：战斗规则、战役状态（整数）一律不碰。营地和换上的面板只发原来那几条指令（`card.choose`、`day.end`、
  `settle.next`、`year.next`），旧版战役（`DEHOUDANG_CAMPAIGN=legacy`）里一个像素都不变。
