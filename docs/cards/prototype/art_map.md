> 这是做网页原型时的构图与旧图映射记录（网页的做法），给 C01、K12 参考；正式游戏的坐标、id、尺寸以合同 §1.2、§4.8、§7.11 为准，两者不一致以合同为准。
> 文中“网页”“CSS”“手机”的部分只属于网页原型。

# 德厚当网页试玩 · 换皮美术摸底（ART_MAP）

> 给“有画面”的新版网页试玩用：柜台场景怎么拼、每个人/每件东西/每张牌用哪张图、缺什么、手机怎么裁。
> 图都已经嵌进同目录的 `assets.js`（`embed_art.py` 生成，150 张图 + 29 个别名，约 368 KB）。
> 依据：`scripts/ui/counter_view.gd`、`data/layout.json`、`tools/art/gen_backgrounds.py`、`scripts/town/town_tint.gd`、`scripts/town/char_sprite.gd`、`data/town/item_templates.json`、`data/cards/art/manifest.json`，以及 `art/_preview/*.png`、`docs/town/mockups/A3_counter_closeup.png`、`screenshots/v04_gallery/g03*/g22`。
> 核对坐标用的拼图在 `_scene/preview/`（`desk_day.png`、`desk_dusk_patrol.png`、`desk_night.png`、`desk_street_walk.png`、`mobile_day.png`、`jail_candle.png`、`street_market.png`），只是核对用，不进页面。

---

## 0. 先说几件和预想不一样的事

1. **`art/_placeholder/` 是空的**（只有 `.gitkeep`）。王山、周妈等人的立绘其实就在 `art/portraits/` 里，不是占位目录里补的。`data/cards/art/manifest.json` 里指向 `art/_placeholder/cards/**` 的那些占位图一张都没生成。
2. **`art/portraits/hu2.png` 和 `stranger_collector.png` 是同一张图**（md5 相同）。胡二没有自己的立绘。网页里 `stranger_collector` 这张立绘不再给别人用（收旧物的改用路人 2），这样同一天里不会出现两个长得一样的人。
3. **立绘有两种画法**：13 张是半身像（brother、chen、guanjia、li、linsao、ma、sunlaoye、sunyoung、wangshan、xiaoding、zhang、zhao、zhouma）；8 张是 Q 版全身（hu2、postman、ruhua、wu、stranger_collector/fence/peddler/refugee），做法是行走图朝下第一帧放大 2 倍贴在 48×64 的 (8,0)（`ruhua.png` 和这样做出来的图逐像素一致，脚本里有自检）。没有立绘的人（巡警、路人）就用同一个办法从行走图做，和这 8 张风格一致。
4. 截图和 A3 示意图是 1280×720，就是 320×180 的 **4 倍**（`layout.json` 写的 `scale: 3` 是 Godot 窗口 960×540 时的倍数）。下面所有坐标都是 320×180 的场景像素。

---

## 1. Godot 原版柜台场景怎么拼（counter_view.gd）

### 1.1 画布与分区

| 名称 | 320×180 坐标 (x, y, w, h) | 说明 |
|---|---|---|
| 整个场景 | 0, 0, 320, 180 | 先铺 `#0d0a08`，再贴背景图（背景 `bg = "dark"` 时只有这层黑） |
| wall 墙 | 0, 0, 320, 100 | 左窗格 (14,16,68,50)、右窗格 (238,14,68,48) |
| door 门洞 | 112, 8, 96, 92 | 白天/黄昏能看到街；夜里是门板 |
| counter_top 柜台面 | 0, 100, 320, 50 | 柜台前沿在 **y = 100**，人物的下边就压在这条线上 |
| under 桌下 | 0, 150, 320, 30 | 典当盒、垃圾箱、电报柜放这里 |

### 1.2 人物

| 位置 | 坐标 (x, y, w, h) | 用的图 | 备注 |
|---|---|---|---|
| 客人 customer | **136, 36, 48, 64** | `art/portraits/<id>.png`（1 倍，不放大） | 正对门洞中线（x 中心 160），脚下 y=100 正好是柜台沿 |
| 哥哥 brother_spot | **236, 36, 48, 64** | `art/portraits/brother.png` | 客人不是哥哥时，哥哥站在右边窗下（代码默认值写的是 262,40，以 layout.json 的 236,36 为准） |
| 生客 / 过路客 | 同客人 | `art/portraits/stranger_<原型>.png`，原型没有图时借 `stranger_refugee.png` | |

- **进场**：换客人时立绘从下面 18 像素处往上滑到位，每秒 120 像素（约 0.15 秒）。没有淡入、没有走路。
- **夜里**：立绘乘以 (0.95, 0.85, 0.72)（偏暖暗）。白天、黄昏不调色。
- **烛光（candle 背景）**：立绘左半边乘 (0.32, 0.25, 0.20)，右半边乘 (1, 0.86, 0.66)，像只有烛火照到半边脸；蜡烛 `tools/candle.png` 画在 (156,112)，火苗是 (159,110) 的 2×2 `#ffd25a` 方块上下抖。
- **风声大时（suspicion ≥ 5）门外有影子**（只在白天/黄昏）：一条 9×60 的竖条在 (118 + 2·sin(0.7t), 38)，上面一个半径 5 的圆头在 (x+4.5, 34)，颜色 `rgba(13,13,18,0.55)`。网页可对应“风声 ≥ 盯上了”。

### 1.3 柜台上的工具（data/layout.json 的 hotspots，图 1:1 画在框里）

| id | 图 | 坐标 (x, y, w, h) | 原版何时显示 | 原版标签 |
|---|---|---|---|---|
| door_flag | `tools/door_flag(_none/_red/_white).png` | 96, 14, 12, 40 | 非夜里；蓝=door_flag，白、红、空杆 | 门旗 |
| sign | `tools/sign.png` | 212, 14, 26, 34 | 非夜里 | 招牌 |
| calendar | `tools/calendar.png` | 250, 14, 24, 34 | 总是 | 万年历 |
| lamp | `tools/lamp.png` / `lamp_off.png` | 292, 68, 20, 32 | 总是；夜里且没点灯时用 lamp_off | 油灯 |
| magnifier | `tools/magnifier.png` | 8, 106, 30, 20 | 总是 | 放大镜 |
| abacus | `tools/abacus.png` | 42, 104, 52, 22 | 总是 | 算盘 |
| scale | `tools/scale.png` | 44, 128, 40, 20 | 解锁后 | 小秤 |
| counter_item | （物品摆这里） | **116, 104, 88, 42** | — | 验货区 |
| ledger | `tools/ledger.png` | 222, 106, 40, 26 | 总是 | 账簿 |
| notebook | `tools/notebook.png` | 268, 106, 40, 26 | 总是 | 档案簿 |
| medbook | `tools/medbook.png` | 270, 132, 36, 16 | 解锁后 | 沈记药材鉴别录 |
| pawnbox | `tools/pawnbox.png` | 136, 152, 48, 26 | 总是 | 典当盒 |
| trash | `tools/trash.png` | 4, 150, 30, 28 | 总是 | 垃圾箱 |
| telegraph | `tools/telegraph.png` / `telegraph_open.png` | 278, 150, 38, 28 | 解锁后；有电报时开着 | 电报柜 |

### 1.4 柜台上的物品

- 都摆在 counter_item (116,104,88,42) 里，横排、居中、间距 4。
- 1～2 件时每件 **36×36**，3 件以上每件 **28×28**（64×64 的图直接缩小，不是整数倍）。
  第 i 件：`s = n<=2 ? 36 : 28; total = s*n + 4*(n-1); x = 116 + (88-total)/2 + i*(s+4); y = 104 + (42-s)/2`。
- 悬停：外扩 1 像素的 35% 白框；选中：外扩 2 像素的金框 `#ffd25a` 一闪一闪；拖拽时原位空着，光标处画一个 28×28 半透明的。

### 1.5 棋子（原版的“格子检定”用的就是这块地方）

- 区域 (100, 108, 120, 30)，每行 6 个，每个 20×20，行距 22，整体居中；底下垫一个半径 11 的 55% 黑圆盘，待办的描金圈闪，做完的 35% 透明。网页的铜钱可以照搬这套几何（见 3.4）。

### 1.6 教学高亮

- 热点外扩 1 像素的金框 `rgb(255,209,89)` + 外扩 2 像素的红框 `rgb(176,38,41)`，透明度 0.55±0.45 按 sin(6t) 呼吸；热点上方一个约 7 像素宽的 ▼（金色填充 + 深色 `#0d0a08` 描边）上下跳 2 像素。

### 1.7 白天 / 黄昏 / 夜里怎么切

- 原版按钟点：`minute < 18:00 → day`，`18:00–20:59 → dusk`，`≥ 21:00 → night`（`town_tint.gd counter_bg`）。
- 三张图构图完全一样（门、窗、柜台、桌下位置不变），所以人物、工具坐标不用改，换底图就行。
- 夜里门上了门板（门洞里看不到街），门旗、招牌不画；油灯在 (302,84) 附近照出一圈暖光；没点灯时整张再盖一层 `rgba(0,0,13,0.35)`。

---

## 2. 网页建议的构图（桌面）

### 2.1 放大方式（CSS）

场景按 320×180 的坐标排，整数倍放大，空出来的地方用 `#0d0a08` 填（和原版一样的“暗木色”）。

```js
// s：能放下的最大整数倍。1920×1080 → 6；1366×768 → 4；浏览器里 1280×~650 → 3
const s = Math.max(1, Math.floor(Math.min(innerWidth / 320, (innerHeight - HUD_H) / 180)));
stage.style.setProperty('--s', s);
```

```css
.stage { position:relative; width:calc(320px*var(--s)); height:calc(180px*var(--s)); background:#0d0a08; overflow:hidden; }
.spr   { position:absolute; image-rendering:pixelated;          /* 所有像素图都要加 */
         left:calc(var(--x)*var(--s)*1px); top:calc(var(--y)*var(--s)*1px);
         width:calc(var(--w)*var(--s)*1px); height:calc(var(--h)*var(--s)*1px); }
/* 行走图：16×32 一帧，4 行（下 左 右 上）× 4 帧，背景图按 --k 倍放大 */
.walk  { image-rendering:pixelated; width:calc(16px*var(--k)); height:calc(32px*var(--k));
         background-size:calc(64px*var(--k)) calc(128px*var(--k));
         background-position:calc(-16px*var(--k)*var(--col)) calc(-32px*var(--k)*var(--row)); }
```

- 每个精灵用 `--x --y --w --h`（场景像素）定位，这样坐标表可以原样抄。也可以整块 `.stage{transform:scale(s);transform-origin:0 0}`，但个别浏览器对变换后的图会糊，用上面这种逐个乘倍数的写法最稳。
- **文字不要放进放大的场景里**（对话框、按钮、手牌放在场景外的普通 DOM 层，按场景坐标 × s 对齐），字才清楚。
- 夜里调色（和原版一模一样的乘法）：

```html
<svg width="0" height="0" style="position:absolute"><filter id="night"><feColorMatrix type="matrix"
 values="0.95 0 0 0 0  0 0.85 0 0 0  0 0 0.72 0 0  0 0 0 1 0"/></filter></svg>
<!-- .night .person { filter:url(#night) } -->
```

### 2.2 坐标表（网页版，场景像素）

和原版的差别只有三处，都是为了给手牌、英雄头像、“打烊”按钮腾地方：**桌下那一条（y ≥ 150）让给手牌**，典当盒挪到柜台上当钱匣，药材鉴别录和小秤平时不摆。

```js
const SCENE = {
  size: [320, 180],
  regions: { wall:[0,0,320,100], door:[112,8,96,92], counter:[0,100,320,50], under:[0,150,320,30] },
  // 人
  customer:  [136, 36, 48, 64],     // 主客人（立绘 1 倍）
  companion: [236, 36, 48, 64],     // 第二个人：哥哥教学、陪同、作保的人
  doorPair:  [[128,36,32,64],[160,36,32,64]],  // 门口两个人（行走图第一帧 2 倍）：两个警察、胡二带人
  doorOne:   [144, 36, 32, 64],     // 门口一个人（2 倍），还没进门 / 只是路过站一下
  street:    { y: 66, x0: 116, x1: 192, w: 16, h: 32 },  // 门外街上的人（行走图 1 倍，脚在 y≈96），左右走
  notice:    [136, 30, 48, 36],     // 门上 / 门板上贴的告示（ui.notice）
  shadow:    { x: 118, y: 38, w: 9, h: 60, head: [122.5, 34, 5] },  // 风声大时门外的影子
  // 工具（拖放目标 / 热点）
  tools: {
    door_flag:[96,14,12,40], sign:[212,14,26,34], calendar:[250,14,24,34], lamp:[292,68,20,32],
    magnifier:[8,106,30,20], abacus:[42,104,52,22], pawnbox:[60,124,48,26],   // 典当盒挪到算盘下面，当“钱匣”
    ledger:[222,106,40,26], notebook:[268,106,40,26],
    // 平时不摆：scale（称分量小游戏里再出现）、medbook（内容进“规矩”抽屉）、trash、telegraph（夜里发电报才出现在 278,150）
  },
  items:     [116, 104, 88, 42],    // 验货区；1～2 件每件 32×32，3 件每件 24×24（见 2.3），最多摆 3 件
  // 检定
  slots:     { y: 104, w: 40, h: 30, gap: 6 },   // n 个格子以 x=160 为中线排开；检定时其他工具压暗
  coins:     { y: 134, size: 16, gap: 2 },       // 铜钱一排以 x=160 为中线排开（ui.coin / ui.coin_back）
  // 场景外 DOM 层要对齐的地方
  dialog:    [4, 8, 104, 90],       // 对话框贴左墙（盖住左窗格），名字 + 台词 + 回话按钮
  hero:      [4, 134, 44, 46],      // 你的头像（portrait.ruhua 上半截），手牌左边
  contacts:  [52, 150, 60, 30],     // 人脉小牌，头像右边
  endTurn:   [262, 134, 54, 24],    // “打烊 · 下一天”按钮：右侧偏下，不挡账簿、档案簿、油灯
  hand:      [96, 146, 160, 34],    // 手牌扇形的落脚（往下伸出场景，悬停抬起盖到 y≈110）
};
```

- 拖放：拖到 `regions.door` = “叫进门 / 门口”，拖到 `regions.counter` = “放柜台上”。
- 工具当热点：账簿 ledger → 当票；万年历 calendar → 黄历宜忌；钱匣 pawnbox → 家当 / 钱；档案簿 notebook → 档案簿；算盘 abacus → 有人来当来卖时是出价，平时是规矩；放大镜 magnifier → 找不同（验货）；油灯 lamp → 夜里点灯 / 熄灯；招牌 sign → 口碑说明（可不做）。
- 原版的“柜台下 y≥150”那一条在网页里只有手牌、头像、人脉，桌下三件东西不画。

### 2.3 物品尺寸

原版是 36/28（64 的图缩成非整数倍，边会毛）。网页建议 **1～2 件 32×32、3 件 24×24**：s=4 时 32×4=128 正好是原图 2 倍，s=2 时正好 1 倍。点开细看（放大镜、找不同、吹银元）时用原图 64×64 × s。
`desk_day.png`、`desk_night.png` 是按这个尺寸拼的。

### 2.4 白天 → 黄昏 → 夜里（网页规则建议）

- `f = 今天已处理的牌 / 今天发的牌`：`f < 0.6` 用 `bg.day`；`f ≥ 0.6`（包括全处理完、还没打烊）用 `bg.dusk`；按了“打烊 · 下一天”进入夜牌阶段用 `bg.night`（油灯亮着，不盖暗层）。
- 两层背景叠着放，换的时候交叉淡入 1～1.5 秒。人物、工具坐标三张图通用。
- HUD 的时辰字可以跟着走：上午（f<0.3）/ 下午 / 傍晚（f≥0.6）/ 夜里。
- 门旗：平时 `tool.door_flag`（蓝布旗，开门营业）；查封那天 `tool.door_flag_white`；喜事（喜帖）那天可换 `door_flag_red`；夜里不画。

### 2.5 进门、说话、离开（建议做法）

1. 白天 / 黄昏：`char.<id>` 1 倍在门外街上走（行 2 = 朝右，或行 1 = 朝左，6 帧/秒），从 x=116 走到 x≈150，约 0.6 秒；
2. 行走图淡出，同时 `portrait.<id>` 从 (136, 36+18) 滑到 (136,36)、透明度 0→1，约 0.25 秒（原版只有这一步）；
3. 说话时立绘可以上下抖 1 像素；离开反过来：立绘往下滑 18 像素淡出，行走图朝外走掉。
4. 夜里门板关着：不走街，立绘直接淡入（“从后门进来”），套夜里调色；后门的戏（王山、后门收货）换 `bg.candle`，人物半边脸亮。
5. 事件里的人（警察、胡二的人、报童……）停在门口（`doorOne` / `doorPair`，行走图 2 倍），不一定进柜台。

---

## 3. 手机竖屏（约 400×860）

- **裁门口那一段，放大 2 倍**：裁剪框 **(64, 0, 176, 152)** → 352×304 CSS 像素，左右各留 24。包括门旗、整个门洞、招牌、客人、验货区和柜台前半截。拼图见 `preview/mobile_day.png`。
- 裁掉的东西挪进框里（手机专用坐标）：

| 东西 | 手机坐标 | 说明 |
|---|---|---|
| customer | 136, 36 | 不变 |
| companion | **188, 36** | 原来的 236 出框了；挡住油灯没关系 |
| calendar | **84, 14** | 门旗左边的墙上；门旗手机上不画 |
| lamp | **214, 62** | 门框右边 |
| magnifier | **68, 106** | |
| ledger | **200, 106** | |
| items | **116, 104, 80, 42** | 缩窄 8 像素，给账簿让地方；最多 2 件（32×32） |
| 不画 | abacus、pawnbox、notebook、door_flag、scale、medbook | 出价走对话框里的回话按钮；钱匣点 HUD 的钱；档案簿走底部抽屉 |
| doorPair | 128,36 / 160,36 | 不变 |
| dialog | 场景下面一整条 | 不再贴左墙 |

- 竖排：HUD（约 28）→ 场景 304 → 对话框（约 170）→ 手牌（约 190，扇形、缩小，点一下放大再点“打出”）→ 底部“打烊 · 下一天”。860 高放得下；矮屏可以把裁剪框缩到 (64,0,176,140)。
- 屏宽不够 352 时退到 1 倍 + 整个 320×180 场景，或者用 `transform:scale()` 的非整数倍（会有点不匀）。

---

## 4. 可用的 PNG（全部 8 位 RGBA、背景透明；`.import` 是 Godot 的，不用管）

### 4.1 背景 320×180

| 路径 | 画的是什么 | key |
|---|---|---|
| art/bg/counter_day.png | 白天柜台：两扇木格纸窗、敞着的门（门外雾蒙蒙的街、对面墙一张带红印的告示、两个淡淡的路人影）、青砖墙、柜台面、桌下暗格 | bg.day |
| art/bg/counter_dusk.png | 同构图，黄昏暖橙，门外街暗、门框斜影 | bg.dusk |
| art/bg/counter_night.png | 门上了门板，窗暗，右边油灯一圈暖光 | bg.night |
| art/bg/candle.png | 黑屋里一道门缝（x≈160 一条竖蓝线）+ 中间一团烛光（序章第一幕） | bg.candle（别名 bg.jail） |
| art/bg/title.png | 夜里江南水乡：月亮、白墙黑瓦、石拱桥、河 | bg.title（别名 bg.dock） |
| art/town/shops/market_bg.png | 估衣摊：蓝白条遮阳棚，挂着长衫短褂，摊上叠着布、竹筐 | bg.market（别名 bg.street、bg.temple） |
| art/town/shops/teahouse_bg.png | 茶馆：“茶馆”匾、红灯笼、茶壶茶碗、墙上告示、门 | bg.teahouse |
| art/town/shops/ricehall_bg.png | 裕丰米行：价牌（粳米 73↑ 籼米 61 糯米 80）、米袋、猫 | bg.ricehall |
| art/town/shops/pharmacy_bg.png | 济生堂：百子柜、药罐、秤、柜台 | bg.pharmacy |
| art/town/shops/post_bg.png | 邮电代办：“邮电”、钟、信格、柜台 | bg.post |
| art/town/shops/baogong_bg.png | 保公所：“保公所”、告示栏、钟、长柜台 | bg.baogong |

### 4.2 立绘 art/portraits/*.png（48×64）

| 文件 | 画的是谁 | 画法 |
|---|---|---|
| brother | 沈如松：深蓝短褂，短发 | 半身 |
| chen | 陈文庭：白发圆眼镜，棕长衫 | 半身 |
| guanjia | 孙福：瓜皮帽红顶、八字胡，灰马褂，手里端着东西 | 半身 |
| hu2 | 胡二：黑短发，深蓝立领短褂 | Q 版全身（**= stranger_collector.png**） |
| li | 李敬之：学生帽，灰黑学生装 | 半身 |
| linsao | 林嫂：发髻，米色衣，抱着包袱，挺着肚子 | 半身 |
| ma | 马万利：黑礼帽，西装红领带 | 半身 |
| postman | 何启明：绿邮差帽，绿制服 | Q 版全身 |
| ruhua | 沈如花：黑发，蓝衫，斜挎带 | Q 版全身（= 行走图 2 倍） |
| stranger_collector | 黑衣立领（和 hu2 同一张） | Q 版全身 |
| stranger_fence | 黑礼帽、黑衣（戴礼帽的人） | Q 版全身 |
| stranger_peddler | 黄草帽、土黄短褂（货郎） | Q 版全身 |
| stranger_refugee | 胡子拉碴、破布衣（逃难的） | Q 版全身 |
| sunlaoye | 孙老爷：黑瓜皮帽、山羊胡、蓝长袍 | 半身 |
| sunyoung | 孙富贵：分头，灰长衫配米色围巾，手上戒指 | 半身 |
| wangshan | 王山：平头，草黄披挂，手缠纱布 | 半身 |
| wu | 吴长发：灰发，棕褂子，咧嘴笑 | Q 版全身 |
| xiaoding | 小丁：短发，灰白围裙，捧着米袋 | 半身 |
| zhang | 张慧娟：齐耳短发，蓝白护士装，提竹篮 | 半身 |
| zhao | 赵老三：瘦脸，打补丁的灰蓝褂，烟杆 | 半身 |
| zhouma | 周妈：白头巾，棕衣白围裙 | 半身 |

### 4.3 行走图 art/town/chars/*.png（64×128，16×32 一帧，4 行：下 左 右 上 × 4 帧：站 迈左 站 迈右，脚点 (8,30)）

brother、chen（礼帽眼镜棕袍）、guanjia（黑礼帽）、li、linsao、ma、postman、ruhua、sunyoung、wangshan、wu（红箍礼帽）、xiaoding、zhang（护士帽）、zhao、zhouma（白发）、stranger_collector（黑衣金箍帽）、stranger_fence（黑礼帽）、stranger_peddler（白头巾土黄褂）、stranger_refugee（破衣），以及：

| 文件 | 画的是什么 | 网页里当谁 |
|---|---|---|
| patrol | 巡警：黑制服、白帽圈、黄领章、腰带 | 警察 / 巡警；调色后当伪军 |
| passerby_0 | 白头巾、蓝衫斜挎 | 报童 / 跑腿的 / 带话的人 |
| passerby_1 | 红衫姑娘 | 邻居姑娘（喜帖） |
| passerby_2 | 光头、绿衫 | 收旧物的 / 邻铺伙计（失火喊人） |
| passerby_3 | 白发老人、棕衫 | 老先生（贵人路过）/ 还旧账的；算命先生走路用它 |
| passerby_4 | 头巾、深灰衫 | 过路客 / 码头扛包的 / 赌摊的人 |
| passerby_5 | 齐耳发、米色衫 | 学生 |

没有行走图的：hu2（借 stranger_collector）、sunlaoye、suanming（借 passerby_3）。

### 4.4 物品 art/items/*.png（64×64）

| 文件 | 画的是什么（data/items 里的名字） |
|---|---|
| rice_jing_a / rice_xian_b / rice_nuo_c | 粳米甲 / 籼米乙 / 糯米丙（敞口米袋，米色各不同） |
| rice_mold_d | 粳米丁（受潮发霉，绿斑） |
| rice_sunji | 粳米（袋上一个红色“孙记”字号印） |
| hairpin | 金簪（簪头一粒小珍珠） |
| silver_keepsake | 爸的小银元（一枚大银元） |
| coin | 铜板（当十铜元，方孔） |
| handwarmer | 铜手炉（提梁、镂空盖） |
| ciyuan | 《辞源》一部（蓝布函套） |
| newspapers | 旧报纸一捆（麻绳捆着） |
| tabloid | 油印小报《太湖快讯》三张 |
| deed_zhao / deed_sun_real / deed_fake | 红契（水田）/ 红契（孙家三十亩）/ 地契（假的，纸色发白） |
| quinine / iodine / aspirin | 奈宁片一瓶 / 碘酒一瓶 / 阿司匹林一瓶 |
| sulfa / sulfa_fake | 磺胺粉一盒（真 / 假，盒面不同） |
| mercuro / morphine | 红药水两瓶 / 吗啡针剂一盒（网页没用到，没嵌） |

### 4.5 柜台工具 art/tools/*.png

magnifier 30×20 放大镜｜abacus 52×22 算盘｜scale 40×20 小秤｜ledger 40×26 蓝皮账簿｜notebook 40×26 档案簿（木匣式）｜medbook 36×16 药材鉴别录｜pawnbox 48×26 典当盒（抽屉）｜trash 30×28 竹篓｜telegraph / telegraph_open 38×28 电报柜（关 / 开，开着有电键和灯）｜lamp / lamp_off 20×32 煤油灯｜calendar 24×34 万年历（红顶日历）｜candle 8×16 蜡烛｜sign 26×34 招牌木牌｜door_flag(_none/_red/_white) 12×40 门旗｜piece_black/cyan/gray/red/white/yellow 14×14 棋子（网页没用，没嵌）

### 4.6 界面、道具、建筑

- **ui**：art/ui/stamp.png 24×24 红印（→ ui.stamp）；art/ui/ticket_blank.png 96×128 空白当票（→ ui.ticket）；art/town/ui/coin_icon.png 16×16 方孔铜钱（→ ui.coin）；dialog_frame.png 48×48 木框（九宫格，→ ui.dialog_frame）；notice_paper.png 48×36 告示纸（→ ui.notice）；clock_panel.png 64×24 太阳 + 牌子（→ ui.clock）；key_hint、stamina_icon（没用）。
- **props（art/town/props）**：shelf 208×50 货架（“德厚当”匾、红布柜台，左右两排货）｜notice_wall 18×26 告示栏｜lantern_post 16×34 灯笼杆｜calendar 16×32 红色月份牌｜trunk 16×14 小木箱｜boat 48×22 乌篷船｜bed 32×28 床｜storeroom_door 32×46 蓝花布门帘的库房门｜back_door 16×32 后门｜cat 14×12 / cat_sleep 14×8 猫｜clothes_rack 32×40 衣架（藏青长衫 + 红衣）｜laundry 48×34 晾衣绳｜rice_sacks 20×16 米袋堆｜broom 8×22 扫帚｜lamp 12×22 灯｜counter / counter_gate / counter_lamp / counter_mid 64×44 / 48×44 俯视柜台段｜bench 26×12 长凳｜pawn_bench 48×14｜plant 14×26 盆栽｜barrel、chicken、duck、willow、stairs、telegraph（小镇用）。嵌了其中 18 件（见 assets.js 的 prop.*）。
- **buildings（art/town/buildings，正面外观）**：pawnshop / pawnshop_night 127×107 德厚当铺面｜police / police_locked 74×77 警察所（锁门）｜baogong 70×90 保公所｜sunfu 100×80 孙府｜dock_shed 64×48 码头棚子｜market_stall 56×40 摊子｜teahouse / ricehall / pharmacy / post（各有 _night）。嵌了 12 件（bld.*）。
- **tiles**（town.png 256×48、interior.png 256×32）：小镇地砖，网页用不上。
- **_preview/*.png**：总览拼图，不是素材。

---

## 5. 映射表

### 5.1 人物（engine1.js 的 P → assets.js 的 key）

| 人物 id | 名字 | 立绘 `portrait.<id>` | 行走图 `char.<id>` | 备注 |
|---|---|---|---|---|
| me | 沈如花（你，英雄头像） | ruhua.png | ruhua | 英雄头像用立绘上半截 (0,0,48,44) |
| brother | 沈如松 | brother.png | brother | 教学的人站 companion 位 |
| zhouma | 周妈 | zhouma.png | zhouma | 也是消息牌的“报信人” |
| chen | 陈文庭 | chen.png | chen | |
| xiaoding | 小丁 | xiaoding.png | xiaoding | |
| zhang | 张慧娟 | zhang.png | zhang | |
| wangshan | 王山 | wangshan.png | wangshan | 深夜后门：bg.candle |
| li | 李敬之 | li.png | li | |
| linsao | 林嫂 | linsao.png | linsao | |
| zhao | 赵老三 | zhao.png | zhao | |
| sunyoung | 孙富贵 | sunyoung.png | sunyoung | |
| ma | 马万利 | ma.png | ma | |
| hu2 | 胡二 | hu2.png（= stranger_collector） | **借** stranger_collector | 缺自己的立绘 |
| guanjia | 孙福 | guanjia.png | guanjia | |
| wu | 吴长发 | wu.png | wu | |
| postman | 何启明 | postman.png | postman | |
| waixiang | 外乡人 | stranger_refugee.png | stranger_refugee | |
| tiaohuo | 挑货的 | stranger_peddler.png | stranger_peddler | |
| xuesheng | 学生 | **derived** passerby_5 ×2 | passerby_5 | Godot 里也没有学生图 |
| guoke | 过路客 | **derived** passerby_4 ×2 | passerby_4 | |
| shoujiu | 收旧物的 | **derived** passerby_2 ×2 | passerby_2 | 不用 stranger_collector（和胡二撞脸） |
| suanming | 算命先生 | **derived** sunlaoye 换灰褐长衫 + 墨镜 | 借 passerby_3 | 走进门的一个人 |
| stranger | 戴礼帽的人（一九六号） | stranger_fence.png | stranger_fence | |
| （额外）sunlaoye | 孙老爷 | sunlaoye.png | 无 | 大命运“贵人相助”“作保”、孙府介绍信 |
| （额外）patrol | 巡警 | **derived** patrol ×2 | patrol | |
| （额外）passerby_0..5 | 路人 | **derived** ×2 | passerby_0..5 | 见 4.3 的分工 |

### 5.2 事件里出现、但不是 P 里的人

| 谁 | 出在哪些牌 | 用的图 | 怎么站 |
|---|---|---|---|
| 警察 / 巡警 | ev_liangmin（两个）、ev_search、fa_seal、fa_requisition、fa_wind、宵禁 | char.patrol / portrait.patrol | 两个人用 doorPair（2 倍）；查铺时一个进 customer 位、一个站 companion 位；风声紧只在门外街上走过（1 倍） |
| 伪维持会的人 | ev_register、ev_tanpai、fa_fine、fa_seal、fa_requisition、fa_slander、ev_liangmin 后头跟着的 | portrait.hu2 / char.hu2 | 胡二本人就是“伪维持会的跑腿” |
| 胡二的人 | 条子要人、要货 | char.stranger_collector 做**剪影**（`filter:brightness(0) opacity(.6)`） | 门外街上 1 倍，两三个 |
| 伪军 | ev_troops | char.patrol 调色 `filter:sepia(1) saturate(.6) hue-rotate(20deg) brightness(.8)` | 门外街上 1 倍一队（4～6 个错开），行 2 朝右走过 |
| 报童 / 带话的人 | 消息牌（周妈的除外）、fa_referral、fa_ricecheap | portrait.passerby_0 | doorOne |
| 邻居姑娘 | li_wedding（送喜帖） | portrait.passerby_1，手里配 ui.stamp 当红喜帖 | customer 位；门旗换红 |
| 邻铺伙计 | fa_fire（喊失火）、fa_purse（扫地的伙计） | portrait.passerby_2 | doorOne；失火时右墙盖一层橙色闪光 |
| 老先生 | fa_noble（县里的老先生）、fa_debt（来还旧账的） | portrait.passerby_3 | 老先生站 doorOne 看招牌（招牌高亮）；还账的进 customer 位 |
| 码头工、赌摊的人 | st_work、ev_gamble、st_gamble | portrait.passerby_4 | |
| 逃难的人 | ev_refugees | char.waixiang 1 倍三四个 + 一个 portrait.waixiang 在 doorOne | |
| 赶集的人 | ev_market | passerby_0..5 1 倍在门外来回走 | |
| 娘、家里咳嗽的人、林嫂的男人、赵家儿子 | ne_family、li_cough、ne_linhusband、ne_zhao_back | **没有图** → 只用旁白；赵家儿子可用 zhao 旁边一个剪影 | |
| 教学的“账簿批注”“黄历” | GUIDE 里 who=哥哥的账簿批注 / 黄历 | 不出人：tool.ledger / tool.calendar 高亮 + 手写体批注框 | |

### 5.3 物品（items.js 的 CATS → `item.<cat>.<vid>`；每类还有 `item.<cat>` 默认图）

| 类 / 模板 | 名字 | 图 | 来源 |
|---|---|---|---|
| rice.jing | 本地粳米 | rice_jing_a | 现成 |
| rice.xian | 籼米 | rice_xian_b | 现成 |
| rice.nuo | 糯米 | rice_nuo_c | 现成 |
| rice.broken | 碎米 | 借 rice_xian_b | 同 Godot item_templates |
| （状态）rice 旧 / 赃 | worn / stolen | rice_mold_d / rice_sunji（米行字号印） | **验出来以后**才换图，别一上柜就露底 |
| clothing.robe | 藏青长衫 | **derived**：衣架左边那件，2 倍 | 缺图替代 |
| clothing.coat | 旧棉袄 | **derived**：晾衣绳蓝印花布，2 倍 | 缺图替代 |
| clothing.qipao | 旗袍料 | **derived**：衣架右边红衣，2 倍 | 缺图替代 |
| clothing.scarf | 灰羊毛围巾 | **derived**：晾衣绳白布调灰（带穗），2 倍 | 缺图替代 |
| jewelry.bangle | 旧银镯 | **derived**：银元挖空 | 缺图替代 |
| jewelry.hairpin | 细金簪 | hairpin | 现成 |
| jewelry.jade | 白玉坠 | **derived**：银元调成玉色（像玉璧） | 缺图替代 |
| jewelry.ring | 银戒指 | **derived**：银镯缩一半 | 缺图替代（Godot 借整枚银元） |
| jewelry.yuan | 银元五枚 | silver_keepsake | 现成 |
| jewelry.yingyang | 鹰洋三枚 | 借 silver_keepsake | 同类 |
| utensils.warmer | 铜手炉 | handwarmer | 现成 |
| utensils.tinpot | 锡茶壶 | **derived**：手炉调锡灰 | 缺图替代 |
| utensils.clock | 木壳座钟 | 借 tool.telegraph（38×28 木壳） | 缺图替代，形不对 |
| utensils.bowl | 青花碗一对 | **derived**：手炉调青花白 | 缺图替代，形不对 |
| art.landscape | 山水画轴 | 借 deed_fake（竖排字 + 红印的纸） | 缺图 |
| art.calligraphy | 行书条幅 | 借 deed_fake | 缺图 |
| art.flowers | 花鸟小册 | 借 ciyuan（蓝函套书） | 同 Godot |
| art.woodcut | 旧版画一套 | 借 newspapers | 同 Godot |
| medicine.quinine / iodine / aspirin / sulfa | | quinine / iodine / aspirin / sulfa | 现成（sulfa 假的验出来后换 sulfa_fake → `item.medicine.sulfa.fake`） |
| medicine.chuanbei | 川贝母一包 | 借 newspapers（捆着的纸包） | 缺图 |
| documents.field | 田契 | deed_zhao | 现成 |
| documents.house | 旧房契 | deed_sun_real | 现成 |
| documents.receipt | 商号货单 | 借 newspapers | 同 Godot |
| documents.letter | 旧家书 | 借 deed_zhao | 同 Godot |
| （状态）documents 假 | | deed_fake → `item.documents.fake` | 验出来以后才换 |

取图：`ART['item.'+it.cat+'.'+it.vid] || ART['item.'+it.cat]`。

### 5.4 背景（哪种场合用哪张）

| 场合 | 背景 | 加什么 |
|---|---|---|
| 白天 / 黄昏 / 打烊后的夜牌 | bg.day / bg.dusk / bg.night | 见 2.4 |
| 后门的戏：gold_wangshan、夜牌“后门收货” | bg.candle | prop.back_door 不用画（门缝已在图里）；人半边脸亮 |
| 牢房 | bg.candle（`bg.jail`） | 整张 `filter:hue-rotate(180deg) saturate(.4) brightness(.7)` 偏冷；被带走那一下先闪一张 bld.police_locked |
| 街头（铺子押光了） | bg.market（`bg.street`） | char.ruhua 2 倍站摊后；按牌换：st_beg 桥头 → bg.title（`filter:brightness(1.3) sepia(.3)` 当清早）；st_work 码头 → bg.title + prop.boat；st_errand 送米 → bg.ricehall；st_letter 庙门口 → bg.market + prop.bench；st_gamble 巷子 → bg.market 压暗；st_pawnself → bg.dusk（别家当铺的柜台，文字说明） |
| 庙会、月初转运势（城隍庙） | bg.market（`bg.temple`） | 两根 prop.lantern_post + 暖色层 + CSS 轮盘 |
| 街口赌摊 | bg.market 压暗 | CSS 轮盘 + passerby_4 |
| 码头来船 | bg.title（`bg.dock`） | prop.boat、几个 1 倍的路人 |
| 茶馆里的闲话 | bg.teahouse | 周妈 + 几个剪影 |
| 米价涨了 / 吴掌柜 | bg.ricehall（价牌正好是 73/61/80） | |
| 济生堂（陈叔叔求助、药） | bg.pharmacy | 可选 |
| 发电报（夜牌、何先生） | bg.post + 夜里暗层 | portrait.postman、tool.telegraph_open |
| 伪维持会登记、条子、摊派 | 柜台场景（人进门来）；也可闪一张 bg.baogong | |
| 第 7 / 14 天结账 | bg.night，柜台中间放大的 tool.ledger + tool.abacus | |
| 标题、局终 | bg.title | |

### 5.5 每张牌怎么“演”（场景里出什么）

**金色主线**
- gold_brother1：哥哥在 customer 位，账簿 ledger 高亮（“钥匙和账簿放在柜上”）。
- gold_brother2：哥哥在 doorOne，脚边 prop.trunk 当藤箱；天没亮 → bg.day 上盖 `rgba(20,30,60,.35)`。
- gold_wangshan：bg.candle，王山半边脸亮（后门）。
- gold_zhao：赵老三在 customer 位。
- gold_ma：马万利在 customer 位，柜台上一本 tool.ledger 当他的账本。
- gold_t196：戴礼帽的人在 customer 位，柜台上 ui.ticket（当票）+ 一件银的当怀表（借 item.jewelry.yuan，缺怀表图）。

**事件**
- ev_fortune / ev_temple / ev_gamble / bigfate：叠层 + CSS 轮盘（manifest 里的 wheel.* 一张都没有）；背景见 5.4。
- ev_register / ev_tanpai：胡二进门，柜台上摊一本 tool.notebook 当册子。
- ev_liangmin：两个巡警 doorPair，胡二 1 倍在街上跟着。
- ev_search：巡警一个 customer 位、一个 companion 位，柜台工具轻轻抖一下。
- ev_market：门外 1 倍路人来回走；选“摆摊”进来一个 guoke。
- ev_rain：门洞 (112,8,96,92) 里画斜雨丝、整张略暗。
- ev_riceup：报童 doorOne 报信，或闪一张 bg.ricehall。
- ev_curfew：门上贴 ui.notice（SCENE.notice），巡警 1 倍走过。
- ev_troops：伪军一队从门外走过（见 5.2）。
- ev_dock、ev_refugees、ev_rumor：见 5.2 / 5.4。

**命运**：fa_purse 柜台上三枚 ui.coin｜fa_relative 何先生 + ui.ticket 当汇单｜fa_ricecheap 报童 + 一袋米｜fa_referral 报童带话｜fa_noble 老先生 doorOne、招牌高亮｜fa_debt 还账的进门 + ui.coin｜fa_goldbar 柜台上一个纸包（借 item.art.woodcut），旁白说是金条（缺金条图）｜fa_fine 胡二 + 门口一把 prop.broom｜fa_seal 胡二 + 巡警，门洞上 CSS 贴两道白封条（缺封条图）、门旗换白｜fa_requisition 胡二 + 巡警，从柜台拿走一件｜fa_fire 邻铺伙计 doorOne，右墙橙光闪、烟｜fa_slander 门上 ui.notice（状子）+ 胡二｜fa_fakenote 钱匣 pawnbox 高亮，旁白（缺假票子图）｜fa_wind 巡警 1 倍走过 + 门外影子。

**生活**（都是旁白为主，没有人）：li_rice 旁白 + prop.rice_sacks 压暗｜li_coal 旁白（缺煤图）｜li_cough 旁白 + 里间咳嗽字幕｜li_wedding 邻居姑娘送喜帖｜li_roof 右边柜台 CSS 滴水｜li_shoes 旁白。

**消息**：标题带“周妈：”的周妈本人进门说；其余报童在 doorOne 说；对话框里放被说到的那个人的小头像（`portrait.<p>` 灰度）。ne_wire / ne_wire_reply 何先生 + tool.telegraph_open；ne_police 门上 ui.notice；ne_books 账簿 + 算盘高亮；ne_family 夜里旁白；ne_zhao_back 赵老三进门。

**来客（visit）**：来当 / 来卖 → 客人 customer 位，东西摆柜台；来买 → 客人 customer 位，你从货架抽屉挑的东西摆柜台；来赎 → ui.ticket + 原物；求助 HELP：beg 外乡人｜hide 李敬之 + 柜台上一包 item.paper.tabloid｜loan 小丁｜gossip / friend 周妈｜appraise 陈叔叔 + item.art.calligraphy｜borrow 马万利｜squeeze 胡二靠在柜台上（立绘下移 4 像素）｜telegram 何先生｜ship 张护士 + 小图 prop.boat｜ask 学生；算命 → 算命先生走进门，签筒 / 测字用叠层。

**条子**：note_deliver 胡二 + ui.notice 拍在柜台上；没办完的条子贴在左墙门旗旁（ui.notice 缩小或 prop.notice_wall 18×26 放在 (88,58)），点它开“条子”抽屉。

**牢房**：bg.jail；来作保 / 打点的人半边脸亮站 customer 位；格子和铜钱照常摆在下半截。

**夜牌**：tidy 整理库房 → bg.night 上叠 prop.shelf（208×50，放 (56,30)）｜books 对账 → ledger + abacus 高亮｜back 后门收货 → bg.candle + 一件来路不明的东西｜wire 发电报 → bg.post 压暗 + 何先生｜home 回家吃饭 → bg.night 油灯，旁白（缺家里的图）｜sleep 早点睡 → prop.bed 小图，整屏淡到黑。

**留着的牌（手里的小图）**：liangmin 良民证 → ui.stamp + CSS 纸（缺图）｜ma_favor → portrait.ma 头像｜sunfu_favor → portrait.guanjia｜wang_favor → portrait.wangshan｜sun_letter → item.documents.field｜gold_bar → 缺（CSS 金块或借 item.art.woodcut 纸包）｜blank_ticket → ui.ticket｜leaflets → item.paper.tabloid｜dirt_ma → tool.ledger｜dirt_hu2 → tool.notebook｜news_wang / news_li / news_zhang → 被说到的人的灰度头像｜box → prop.trunk｜house_offer → item.documents.house｜guarantee → item.documents.fake（字据）｜ship_ticket → prop.boat｜watch_note → item.jewelry.yuan（缺怀表）。

**家当（抽屉里的小图）**：首饰柜 → item.jewelry.hairpin（缺柜子图）｜库房 → prop.storeroom_door｜柜台 → prop.counter_mid｜老宅 → 缺（暂借 bld.sunfu，或只写字）｜铺面 → bld.pawnshop（押出去后换 bld.pawnshop_night）。

**侧边抽屉标签的小图**：人脉 → 头像｜条子 → ui.notice｜档案簿 → tool.notebook｜货架 → prop.shelf｜当票 → ui.ticket｜家当 → bld.pawnshop｜规矩 → tool.medbook｜设置 → 无（字或 CSS）。

**HUD**：钱 → ui.coin；黄历 → tool.calendar；时辰 → ui.clock（太阳图标）；天气 → 无图（字）。

**小游戏**：找不同 → 同一件物品 64×64 × s 并排两份，差异用 CSS 盖；吹银元 → item.jewelry.yuan 放大；称分量 → tool.scale 3 倍 + 物品；掷铜钱 → ui.coin（正）/ ui.coin_back（反）用 CSS 3D 翻转。

---

## 6. 缺口与替代

| 缺什么 | 现在的替代 | 以后要画的（建议尺寸） |
|---|---|---|
| 胡二自己的立绘 | hu2.png（= stranger_collector） | portrait.hu2 48×64 |
| 胡二、孙老爷、算命先生的行走图 | 借 stranger_collector / 无 / passerby_3 | 64×128 各一张 |
| 算命先生立绘 | sunlaoye 换色 + 墨镜（derived） | 48×64（manifest 里的 portrait.suanming） |
| 学生、过路客、收旧物的、巡警、路人立绘 | 行走图 2 倍（derived，和 ruhua/hu2 同画法） | 可不画 |
| 家里人（娘、咳嗽的人） | 只有旁白 | 可不画 |
| 衣物四样 | 衣架 / 晾衣绳上裁下来 2 倍（derived） | 64×64 各一张 |
| 银镯、玉坠、银戒指 | 银元挖空 / 调色 / 缩小（derived） | 64×64 |
| 锡茶壶、青花碗 | 手炉调色（derived，形不对） | 64×64 |
| 木壳座钟 | 借电报柜木壳 | 64×64 |
| 山水画轴、行书条幅 | 借假地契那张纸 | 64×64 |
| 川贝母 | 借旧报纸纸包 | 64×64 |
| 怀表、金条、良民证、封条、假票子、喜帖、煤 | 银元 / 纸包 / 红印 / CSS 白条 / 只写字 / 红印 / 只写字 | 卡面小图 64×48（manifest 的 illus.*） |
| 城隍庙、码头、老宅、家里 | 集市 / 水乡夜景 / 孙府外观 / 夜里柜台 | 320×180 背景 |
| 轮盘（月运、庙会、赌摊、大命运） | CSS conic-gradient 画 | manifest 的 wheel.* 120×120 |
| 牌框 | CSS 画（金框 = 主线） | manifest 的 frame.* 36×50 九宫格 |
| 天气图标 | 字 | 16×16 |

---

## 7. assets.js 里有什么

- `ART`：150 张图（`data:image/png;base64,...`）+ 29 个别名（`ART["portrait.guoke"]=ART["portrait.passerby_4"];` 这种，图不重复嵌）。
- `ART_META[key] = {w, h, src}`：src 是仓库里的原路径，或 `"derived"`（另有 `derived` 字段说怎么做的）；别名多 `alias`、`note`；行走图多 `frame: {w:16,h:32,cols:4,rows:4,dirs:[down,left,right,up],steps:[stand,left,stand,right],foot:[8,30],fps:6}`。
- 分组：bg 11（+4 别名）｜portrait 28（+4）｜char 26（+6）｜item 29（+15，含每类默认图）｜tool 19｜ui 7｜prop 18｜bld 12。
- 重新生成：`python3 _scene/embed_art.py [仓库根目录] [输出路径]`（只用标准库；脚本自检：PNG 解码再编码逐像素一致，行走图 2 倍和 ruhua.png 一致）。
