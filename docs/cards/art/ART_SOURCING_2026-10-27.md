# 德厚当 · 美术替换与 Steam AI 标签（2026-10-27 调研）

> 主创问：美术方面有免费或者便宜的素材可以替换以消除 AI 生成标签么？卡片和场景能不能用现有场景拼接或者 Blender 建模？
> 本文由 Claude 带调研代理写（网页搜索 + 摘录），价格和许可下单前要逐页核对。现有美术清单见 `data/cards/art/manifest.json`（441 个 id：323 个 AI、118 个 v0.4 旧图，旧图在 `docs/cards/ART_SPEC.md` 里写明也是 AI 产出，发行包不带）。

**先说明一点：**调研时 Steam、itch.io、CraftPix 这些站点的页面都没能直接打开。下面的规则措辞、价格、许可和 AI 声明全部来自搜索引擎摘录。买素材或签约之前，请自己逐页核对，并把页面截图存档。标了【低置信】的条目尤其要核实。

---

## 1. 结论：只换美术，去不掉标签

Steam 的 AI 披露是商店页上一整块"AI Generated Content Disclosure"。只要游戏包里或商店页上还有任何一类 AI 内容，这块就得保留，SteamDB 也会继续挂"AI Content Disclosed"标签（tag 1368160，玩家可以用 `&tagid=-1368160` 把这类游戏过滤掉）。这块披露去掉以后，标签才会自动消失（[GamingOnLinux](https://www.gamingonlinux.com/2025/02/steamdb-now-lets-you-filter-out-steam-games-with-ai-generation/)）。

现行规则是 2026 年 1 月 16 日改版的 Content Survey（内容调查问卷），到 10 月没查到新的改动。问卷只管"随游戏发售、玩家会接触到的内容"，比如美术、声音、叙事、本地化。开发过程中用来提高效率的 AI 工具"不是这一节关注的重点"。来源：[Steamworks 文档](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)（原页没打开，措辞来自摘录）、[PC Gamer](https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/)、[Game Developer](https://www.gamedeveloper.com/business/valve-tweaks-and-clarifies-ai-disclosure-rules-for-steam)。

| 内容 | 结论 | 置信度 |
|---|---|---|
| 约 15 张 Google 图像模型生成的图 | 必须换，明确属于披露范围 | 高 |
| AI 打底的文本（含本地化） | 必须人工重写。改到什么程度算"人写的"，Valve 没给标准 | 属于披露范围：高；改写门槛：低 |
| AI 音频 | 必须换 | 高 |
| AI 写的 Python 脚本按固定规则画出的像素图（323 张里的大头） | Valve 没有任何文字涉及这种情况。一种看法：AI 只写了代码，属于免披露的工具用途。另一种看法：AI 就是做出这些发售美术的手段（[StraySpark 指南](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide)）。玩家和鉴赏家大概率会当成 AI 美术 | 低 |
| 程序化音频（不是 AI 生成的） | 跟上一条是同一个灰区 | 低 |
| AI 辅助写的游戏代码 | 按 2026 年的措辞基本不用披露（2024 年版原文写过"code"，现已删掉）。有一家律所博客说发售的代码仍可能要披露，但它引用的原话没核实到 | 中 |
| 商店页：胶囊图、截图、预告片配音、商店文案 | 也算。游戏里没有 AI，但宣传图是 AI 做的，一样挂标签（[PCGamesN](https://www.pcgamesn.com/steam/new-gen-ai-disclosure-form)） | 中 |
| AI 只用来做概念或参考，成品全部人画 | Valve 没表态，二手资料认为不算。反面例子：Anno 117 的 AI 占位图漏进正式版，只好补披露再打补丁撤掉（[律所总结](https://legalmoveslawfirm.com/steam-ai-policy/)） | 中 |
| v0.4 的 118 张来源不明的旧图 | Steam 包里已经排除，继续排除。要重新用，得先补齐来源 | — |

**对你意味着什么：**
1. 要去掉标签，图、文、声三样都得清干净，商店页素材也一样。只换美术的话，最多能把披露文字缩小到"部分文本和音频使用了 AI"，标签还会挂着。
2. 脚本生成的美术，要么换掉，要么通过 Steamworks 后台联系支持，拿一份书面答复。拿到答复之前，别默认它不用披露。
3. 全部换完后，去 Content Survey 删掉披露，同时发补丁说明和新闻公告，讲清楚换了什么。先例：Jurassic World Evolution 3 撤掉 AI 头像后，商店页的披露就没了（[ScreenHub](https://www.screenhub.com.au/news/news/jurassic-world-evolution-3-genai-2671001/)）。另外有个鉴赏家专门盯"悄悄撤掉披露"的游戏（[鉴赏家页面](https://store.steampowered.com/curator/45944619-Games-That-Use-AI-Generation/)）。
4. 别少报。Valve 不会扫描检查，全靠开发者自报，但披露绑定在 Steam 分发协议上，少报属于违约风险（[VGC](https://www.videogameschronicle.com/news/steam-pages-will-now-disclose-which-games-use-ai-generated-content/)）。
5. 这个标签对销量的影响是真实的：2026 年 10 月的 Next Fest 约 36% 的游戏带披露，玩家反弹很大，正在要求 Steam 官方加"不看 AI 游戏"的筛选（[PCGuide](https://www.pcguide.com/news/steam-next-fest-has-even-more-generative-ai-than-last-time-gamers-say-the-event-is-absolutely-ruined/)）。

---

## 2. 逐类替换来源

**总体判断：**itch.io、CraftPix、Unity 商店、GameDev Market 上都没有画民国（1912-1949）中国的像素素材。中国题材的像素包全是古代、三国或武侠风，大多是 16x16 俯视角的 RPG Maker 风格。所以：
- **只能约稿或自己画：**181 张卡面、47 张头像、30 张行走图，以及大部分背景。
- **素材包能补上的：**图标、卡框、道具、部分物品，加上少量背景。

符号说明：★ 表示明显适合民国江南或当铺题材；"无 AI"表示页面声明没用生成式 AI。

### 2.1 卡面插画 181 张（64x48）：只能约稿或自己画
- 没有现成素材可用。
- **省钱办法：**按"场景底图 + 人物 + 道具"拆成零件约稿，人物直接复用头像的角色设计，最后由你手工拼。手工拼合仍算人做的。题材相近的卡可以共用一张图，减少要单独画的张数。

### 2.2 UI 图标 49 个（16x16 / 24x24）

| 来源 | 价格 | 许可 | 适配度 | 风险 |
|---|---|---|---|---|
| ★ [mingo88 Oriental ancient icons 24x24](https://mingo88.itch.io/oriental-ancient-icons) | $5 起 | 没看到许可文本 | 古钱、元宝、玉、印章、竹简，尺寸正好是 24x24 | 【低置信】许可和 AI 情况都不明，买前写信问作者 |
| [Kenney 1-Bit Pack](https://kenney.nl/assets/1-bit-pack) | 免费 | CC0，不用署名 | 通用 16x16，要重新上色 | 低（Kenney 公开反对生成式 AI） |
| [greatdocbrown Coins & Gems](https://greatdocbrown.itch.io/coins-gems-etc) | 免费 | CC0，附 .aseprite 源文件 | 钱币、钥匙、钱袋 | 没看到 AI 声明 |
| [496 RPG icons](https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg) | 免费 | CC0（早期版本是 CC-BY 3.0） | 西式奇幻 | 确认你下载的是 CC0 版本 |
| [game-icons.net](https://game-icons.net/faq.html) | 免费 | CC BY 3.0，要在制作人员名单署名 | 矢量剪影，要手工转成像素 | 署名；防 DRM 条款（见第 4 节） |
| [Raven Fantasy Icons](https://clockworkraven.itch.io/raven-fantasy-icons) | 单包 $5，全集 $35.5 | 可商用，署名可选 | 通用的钱袋、卷轴、钥匙 | AI 情况未知 |

民国特有的东西（银元、法币、当票、算盘、猫）素材包里都没有。49 个小图标，自己用 Aseprite 画或者照着素材改，是最省钱的办法。

### 2.3 人物头像 47 张（48x64）：只能约稿
- 免费的 CC0 头像都是 32x32 奇幻风（比如 [Buch RPG portraits](https://opengameart.org/content/rpg-portraits)），用不上。OpenGameArt 上的"Fantasy portraits"是 MidJourney 生成的，别碰。
- [Niao_K 古风角色系列](https://itch.io/s/181071/pixel-art-chinese-ancient-style-character-series)：四包 $19.6，古装。头像尺寸、许可、AI 情况都不清楚【低置信】，也不合 1938 年的设定。
- 旗袍、长衫、中山装、警察制服、伪政府官员、日军、护士都得约稿。**这一类最该优先花钱。**

### 2.4 物品 41 个（64x64）
- ★ [BiteMe Asian Pixel Items](https://bitemegames.itch.io/asian-pixel-items)：$4.99，60 个中日物件，32x32，可商用、不用署名，声明无 AI。要用在 64x64 的位置得重画，直接放大 2 倍的话像素粗细会和别的图对不上。
- [Dungeon Crawl 32x32 supplemental](https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental)：CC0，有戒指、护身符、药瓶，可以改成当物。注意剔除 [crawl/tiles](https://github.com/crawl/tiles) 说明里列出的"许可未知"图块。
- 发簪、银元、旗袍、字画、当票、金条、米袋这些，大多要自己画或约稿。

### 2.5 道具 52 个（32x32 / 24x32）
- ★ [B.B.Bits Three Kingdoms Pawnshop Tileset](https://bbbits.itch.io/three-kingdoms-pawnshop-tileset)：特价 $5.99（原价 $9.99）。画的就是当铺：31 件大家具、67 件小摆设。声明无 AI，可商用，禁止拿去训练 AI。缺点是 16x16 俯视角、三国风，只能当底子重画。
- ★ [Niao_K Ancient Chinese Pawnshop](https://niao-k.itch.io/pixel-art-ancient-chinese-pawnshop-tileset)：$5-10，可商用，署名可选。AI 情况不明，同样是 16x16 俯视角。
- ★ BiteMe Asian Pixel Items（见 2.4）：32x32 正好是道具尺寸，适合做博古架上的摆件。
- [Kabukidanshi Detective Mystery 32x32](https://kabukidanshi.itch.io/pixel-art-32x32-detective-mystery-pack)：随意付（可以付 $0），商用要署名。有书桌、文件这类年代感道具。
- [Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack)：CC0，声明无 AI（2026 年 3 月还在更新）。东亚风物件可以改着用，但偏日式 Q 版，16x16。
- [Kenney Roguelike Indoors](https://kenney.nl/assets/roguelike-indoors)：CC0，西式家具，只能参考形状重画。

### 2.6 行走图 30 个（64x128）：只能约稿
- 现成的都是 16x16 级别（B.B.Bits 三国 NPC、[Kenney RPG Urban](https://kenney.nl/assets/rpg-urban-pack)），比需要的尺寸小很多，用不上。
- **省钱办法：**只约几套基础体型，再约换装、换头；换色你自己手工做。最好和头像找同一位画师。

### 2.7 背景 18 张（320x180）
- [MOMONGA Bamboo Forest](https://momongaa.itch.io/bamboo-forest-basic-tiles)：CC0，声明无 AI，正好是 320x180，分 4 层。里面有鸟居，偏日式，删改后可以做城郊或庙前。禁止当素材转卖。
- [LyniaDesign Tiny Pixel Japan Parallax](https://lyniadesign.itch.io/tiny-pixel-japan-parallax-background)：免费，353x180，可商用、不用署名，不许转发。AI 情况没确认，日式。
- [CraftPix Chinese Street Tileset](https://craftpix.net/product/chinese-street-tileset-pixel-art/)：约 $5.5，576x324 昼夜分层背景。偏赛博风，有评论说里面有鸟居。适配度中低。
- [Minimalist Chinese Temple tileset](https://opengameart.org/content/minimalist-chinese-temple-tileset)：CC-BY 3.0，要署名。少见的中国庙宇免费素材，可以给庙会场景做参考。
- 当铺柜台（白天、黄昏、夜里）、街道、监狱是主画面，必须约稿。三个时段可以只约一张底图，光影变体另谈便宜价，或者自己调。

### 2.8 卡框 19 个（36x50，九宫格拉伸）和命运转盘 4 个（120x120）
- [KereneL FREE Pixel Art Playing Cards](https://kerenel.itch.io/pixelart-cards)：CC0，声明无 AI，56x80。里面的空白牌和牌影可以裁成 36x50 的框。
- [Kenney Pixel UI Pack](https://kenney.nl/assets/pixel-ui-pack)（自带九宫格 PNG）、[UI Pack - Pixel Adventure](https://kenney.nl/assets/ui-pack-pixel-adventure)、[Playing Cards Pack](https://kenney.nl/assets/playing-cards-pack)：全部 CC0。外观偏西式，改成漆红、旧木、纸色就能用。
- [Admurin UI Paper Theme](https://admurin.itch.io/ui-paper-theme)（另有木纹版）：随意付，约 0.6 加元起，可商用、不用署名，不许转发。页面没显示 AI 情况（是个老包）。
- ★ [Finnmercury Art Deco UI](https://finnmercury.itch.io/gold-deco-gui-pack)：$2.99，装饰艺术风，能做出 1930 年代上海的味道。许可和 AI 情况未知【低置信】。
- 转盘没找到现成的。都是几何图形，自己画最快。

### 2.9 看着对题，但别用
- **Cute SCKR（comshadow）全系列**，包括 "Chinese Jiangnan Water Town"（江南水乡）：题材最贴，但页面标了"AI Assisted, Graphics"（[示例页](https://comshadow.itch.io/chinese-wuxia-interior-pixel-art-tileset-dlc)）。
- **其他 AI 或 AI 辅助的包：**
  - Chinese.Dragon 古村道具（AI 生成，而且不是像素画）
  - Batareya CCG 卡框（AI 生成）
  - Binetsu 昭和复古图标（标了 AI 辅助，虽然作者说是逐像素重画的）
  - GegX Pixel UI Kit（AI 辅助，二代用了 PixelLab）
  - malikethworks 16px 图标
  - dream-of-light 面具（Midjourney）
  - OpenGameArt 的 "Fantasy portraits"（MidJourney）
- **LPC 以及所有 CC-BY-SA / GPL 素材：**改过的图必须按同一协议公开，署名名单很长，LPC 项目自己都说不清能不能上 Steam（[LPC README](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator)）。
- **引擎受限：**Wulan Traditional Chinese Tilesets 只许在 RPG Maker 里用（[Komodo](https://plaza-us.komodo.jp/products/traditional-chinese-tilesets)）。CN-STYLE Tileset Collection 要 $59.99，各处对引擎条款的说法互相矛盾【低置信】。
- **免费但不能直接商用：**Penzilla（商用要付建议价并署名）、BDragon1727（只限非商用）、LimeZu（商用授权在付费版里）。
- **爱给网：**内容是用户上传的，分"免费商用（CC 协议）"和"版权商用（按件付费）"，每件要单独看授权（[版权说明](https://www.aigei.com/about/copyright)）。没找到民国像素素材。

### 2.10 音频和文本（不在本次调研范围，只给提示）
- Ninja Adventure 包里还有 100 多个音效和 37 首曲子，CC0，声明无 AI，风格偏日式。Kenney 站上的资源全部是 CC0。
- 文本没有现成素材能替代，只能自己重写。

---

### 2.11 另一条路：拼接与 Blender 建模（卡面、背景、行走图）

- **拼接现有图不行**：现有 441 张全是 AI 的，拿 AI 图拼出来还是 AI 内容。拼接要用人画的或授权的底料（素材包、约稿、你自己画），这时拼合本身算人工。
- **Blender 建模渲染成像素：可行，适合这个游戏的量**（这台机器能装 Blender 4.0，CPU 渲染这么小的图够快）。关键是“模型谁做的”：
  - 你或外包建模 → 人做的，渲染出来不算 AI。国内低模外包（一个场景 + 一套可换装人物）很可能比 181 张像素卡面便宜，价格本轮没调研。
  - 人做的免费模型：Quaternius、Kenney 3D（CC0，偏卡通欧美，通用道具和人物底模能用）；Sketchfab 上的 CC-BY 中式建筑（要署名，也有 AI 模型，要查）；Mixamo 人物动作（免费商用）。【这些本轮没逐个核实许可】
  - 我写脚本直接“生成”模型 → 跟现在脚本画图一样，属于同一个灰区，不解决问题。
  - 我只写渲染管线（摆机位、打光、低分辨率渲染、套 `palette.dev.json` 调色板、描边、按数据批量出卡面）→ 属于工具，按 2026 年 1 月的问卷口径大概率不用披露，但同样建议问 Valve。
- **管线设想**：6 个场景（当铺柜台、街口、码头、城隍庙、米店或关卡、牢房）× 光线（白天 / 黄昏 / 夜 / 雨）+ 一个可换装人物（长衫、旗袍、学生装、短打、警察、伪军、日军、护士）× 几种姿势 + 道具 → 每张卡写成数据一键渲染；先渲到 2-4 倍再缩到 64×48、量化到调色板、1 像素描边。181 张卡面实际是三四十种构图换人换物；背景直接出；行走图用动作多方向渲染（Dead Cells 的做法）。
- **头像**：48×64 的脸从 3D 直接渲常常发糊、没神，一般是 3D 打底再手修，或直接约稿。
- **下一步**：可以先装 Blender、用 CC0 模型做一张柜台卡和一张街景卡的样张，跟现在的卡面并排比较，再决定走不走这条路。

## 3. 约稿：价格和合同要点

### 价格（2025-2026 年，商用；来自搜索摘录，没逐页核对）

**国内（主要是米画师）**

来源：一篇 2025 年 7 月的 11 平台报价调研（[网易转载](https://www.163.com/dy/article/L0H298GJ0526K8VB.html)，单一二手来源，中置信），加一个 2023 年米画师像素询价企划，单张预算 100-400 元（[米画师](https://www.mihuashi.com/projects/1061690)）。
- 私稿（个人用途）价格：
  - 静态像素头像 50-200 元
  - 四向行走图一套 100-200 元（没写尺寸，64x128 会更贵）
  - 场景 300-800 元起，精细大场景 500-3,000 元
- 惯例：商用按私稿价 ×2，买断按 ×3。
- 按商用 ×2 推算的单价：头像 100-400 元，卡面小场景 100-400 元，行走图 200-600 元，背景 600-1,600 元。

**海外（Fiverr、itch.io、画师个人价目页、Upwork）**

| 类别 | 单价 | 依据 |
|---|---|---|
| 头像 | $25-60 / 张 | [Frankpixl](https://www.fiverr.com/frankpixl/make-pixel-art-character-portraits-for-your-game) $25 起；[David Filus](https://davidfilus.carrd.co/) 64x64 以下 $60 |
| 卡面小场景 | $20-60 / 张 | 推算，没有这个尺寸的直接报价；[azzicore](https://azzicore.carrd.co/) 320x180 插画 $50，每多一个人物 +50% |
| 行走图 | 单方向 $60-150 / 角色，四方向 $200-400 | Filus：64x64 以上 $95 起，动画另加 $35 起，四方向约 3 倍 |
| 背景 | $50-250 / 张 | Fiverr 最低 $15；Filus 256x144 $120 起；[Pixelglade](https://pixelglade.net/artwork/commissions/commissions.html) 约 $215 |

海外很多价目表标的是个人用途价，商用要另谈。见过的做法有：加价 300%、加 10% 买全部权利、单独签合同，也有画师写明保留全部版权的。

**平台**
- 米画师：分阶段审稿、资金托管、平台仲裁，手续费约 5%（数据较旧【低置信】）。
- 画加（网易旗下）：流量大，橱窗服务费约 5% 只是用户说法【低置信】。
- 闲鱼：没有画师审核也没有担保，便宜，但风险自己担。

### 合同要点
1. **版权归属。**《著作权法》第十九条规定：委托作品的著作权归属由合同约定，没有约定的归受托人（画师）。所以合同必须写明著作权转让，或者至少是"独占、全球、永久、可转授权"的许可。用途要覆盖游戏本体、商店页和宣传、移植、续作、DLC、周边。署名权不能转让，在制作人员名单里给画师署名。还要写明你有权修改、裁切、调色、做成动画。（法条来自已有知识，本轮没打开原文核对。）
2. **海外画师。**美国的"雇佣作品"（work for hire）只适用于法律列出的几类作品，而且要有书面协议。所以合同里同时写雇佣作品条款和兜底的版权转让条款。
3. **别只写"商用"或"买断"两个字。**圈里对这两个词没有统一定义。逐项写清：是否独占、能否转授权、期限、地域、用途。
4. **交付物。**.aseprite 或分层 PSD、调色板文件、精灵图表和帧数据，按 1 倍原始尺寸导出。
5. **不用 AI 的保证条款**（可以直接改着用）：
   > 乙方保证本合同项下全部作品由乙方本人手工创作，创作的任何环节（包括但不限于构思草图、垫图、参考图、线稿、上色、放大、补帧、背景、纹理）均未使用生成式人工智能工具或其生成的内容，包括绘图软件内置的生成式功能。乙方应按阶段交付草图、线稿、过程图及含图层或历史记录的工程源文件，作为创作过程证明。甲方有合理依据怀疑违约时，乙方须在 X 日内提供过程证明；不能提供或经证实违约的，乙方应全额退还已付款项，赔偿甲方因替换素材、重新披露产生的损失，并同意甲方公开说明替换原因。

   同时加一条原创、不侵权的保证：没用第三方素材、字体，没描摹照片，除非事先书面列明。真实案例（单一来源）：2025 年 5 月米画师有一起仲裁，画师拿不出草稿和过程文件，结果被取消资格、封号，买家全额退款。
6. **付款和流程。**
   - 分阶段付款，定金不退。
   - 写明修改次数：一次构思修改，加一次细化修改。
   - 写明交期。
   - 约定画师什么时候能把作品放进作品集，建议游戏发售以后。
   - 先付费试稿 2-3 张，满意再签全量。
7. **给画师的参考资料。**用民国老照片、老画报，加上你手绘的构图草图和文字描述。别把现在的 AI 图或脚本生成的图交给画师去描，不然"没用 AI"这条保证就说不清了。【低置信：Valve 对此没表态，这只是稳妥做法。】

---

## 4. 要避开的坑

1. **许可**
   - CC0 最省心。
   - CC-BY 要署名。CC-BY 和 CC-BY-SA 还禁止对作品加技术保护措施；OpenGameArt 的说法是，Steam 算不算 DRM 要看你怎么打包（[OGA FAQ](https://opengameart.org/content/faq)）。用了 CC-BY 素材就别套 Steam 的 DRM 封装，或者干脆只用 CC0 和 OGA-BY。
   - SA 和 GPL 协议会"传染"：改过的素材也必须按同一协议公开。闭源的商业游戏别碰。
   - 免费不等于能商用，见 2.9。
   - 几乎所有付费包都禁止单独转发原始素材文件。打包进 Godot 的 .pck 没问题，但如果仓库是公开的，不能把原始素材文件提交进去。
   - Unity 商店的非受限素材一般能在 Godot 里用，受限或自定义许可的可能不行【低置信，没读到官方 FAQ】。RPG Maker 的 DLC 大多只能在 RPG Maker 里用。
2. **署名。**做一个游戏内的制作人员页。CC-BY 素材和要求署名的包（game-icons.net、Shikashi、Kabukidanshi、Minimalist Chinese Temple 等）逐一写全，约稿画师也写上。
3. **风格混搭（最影响观感）**
   - 像素粗细：游戏是整数倍放大的。把 16x16 素材放大 2 倍塞进 32x32 的位置，像素颗粒会和原生 32x32 的图对不上，宁可照着重画。
   - 视角：RPG Maker 素材是俯视角，你的柜台和卡面是正面或侧面，这些素材只能当形状参考。
   - 统一调色板：从 Lospec 选一套调色板，所有素材重新映射颜色。调色板一般可以自由使用【低置信，没找到 Lospec 的正式许可】。描边规则和光源方向也写进风格指南，发给每一位画师。
   - 古代和日式元素会串味：鸟居、汉服、武士元素要删掉或改掉。
4. **素材本身就是 AI 做的**
   - itch.io 的"No AI"标签是作者自己填的。没有这个标签，不等于没用 AI。2025-2026 年冒出来的大量"CC0 合集"看着像 AI 生成的（[itch.io 规则](https://itch.io/t/4309690/generative-ai-disclosure-tagging)）。
   - 第三方素材包如果是 AI 做的，你的游戏照样要披露。
   - 判断方法：优先选 2022 年以前发布的、附 .aseprite 或 PSD 源文件的、作者有长期作品记录的。拿不准就写信要书面确认。
   - GameDev Market 在 2025 年 8 月宣布全站清除生成式 AI 素材（[公告](https://www.gamedevmarket.net/news/an-important-update-on-generative-ai-assets-on-gdm)），但那里没找到中国题材。
   - "CraftPix 不用 AI"只是论坛上的转述【低置信】。
5. **来源登记（用仓库现成的机制，不用新建表）**
   - 人画的或买来的图放到 `art/cards/<类别>/<名>.png`（路径就是清单里每个 id 的 `human` 字段），游戏会自动用它顶替同 id 的 AI 图，不用改代码。
   - 发行审核 `tools/cards/audit/audit.py`（不带声明版 `--variant=no-disclosure`）要求：每个文件在 `legal/ASSET_PROVENANCE.csv` 里有一行（至少 `path`、`sha256`、`author`、`method`），`author` 在 `legal/human_authors.json` 里，`method` 不能是 AI（空着也算 AI）。买来的素材包：作者写素材包作者，`method` 写“手绘（素材包 名称 / 许可 / 链接）”；约稿写画师名和“约稿手绘”。
   - `legal/**` 归人管（合同 §11.5），这两个文件由你或画师建，我可以给你生成待填的模板（441 行、带 sha256 计算脚本）。
   - 买的时候就截图页面上的许可和 AI 声明，页面以后可能会改；约稿合同、过程文件一起归档。这些同时用来填 Steam 问卷、做制作人员页、应对质疑。
   - 现在的“不带声明版”导出（预设 `Steam (No AI Disclosure)`）已经会排除 `art/ai/**`、缺人做的图就报错，正好防止 AI 占位图漏进正式版（Anno 117 踩过的坑）。

---

## 5. 执行顺序和大概花费

### 执行顺序
1. **本周，不花钱：**通过 Steamworks 后台联系支持，问清"由大语言模型编写、按固定规则运行的 Python 脚本生成的像素美术，是否需要披露"，要书面答复。同时建好来源登记表，把商店页的胶囊图、截图、预告片也查一遍。
2. **先换最明确的：**约 15 张 Google 图像模型生成的图，以及商店页上的 AI 素材。
3. **定风格：**找一位主画师付费试稿（2-3 张头像加 1 张柜台背景），产出风格指南（调色板、描边、比例）。满意了再签全量。
4. **同时开始人工重写文本、替换音频。**这两样不清干净，美术换完标签也去不掉。
5. **高曝光的美术：**先做柜台背景（白天、黄昏、夜里）和其他背景，再做 47 张头像，然后是 30 张行走图，都找同一位画师。
6. **181 张卡面：**分批约，每批 20-30 张，复用角色和场景。
7. **小件：**图标、道具、物品、卡框、转盘，用素材包加自己画或改，统一调色板。
8. **全部清干净以后：**改 Content Survey 删掉披露，发补丁说明和新闻公告。只要还有一件 AI 内容在，披露就得留着，所以中途别急着撤，最后一次撤掉。
   - 如果 Valve 书面答复说脚本生成的美术不算，第 4 步做完就能撤披露。美术替换就从"去标签必需"变成"提升品质"。但鉴赏家和玩家仍可能按 AI 美术看待【低置信】。

### 花费（按商用价，不含你自己的时间）

**素材包：**上面推荐的全买下来约 $30-65，合 200-500 元。

**省钱方案：国内画师 + 复用 + 小件自己画，约 3-4 万元**

| 项目 | 算法 | 金额 |
|---|---|---|
| 头像 | 47 张 × 100-150 元 | 约 0.5-0.7 万 |
| 背景 | 光影变体自己调，按约 12 张独立底图 × 600-1,000 元（张数是假设） | 约 0.7-1.2 万 |
| 行走图 | 30 个 × 200 元（基础体型加换装） | 约 0.6 万 |
| 卡面 | 共用图后减到约 100 张 × 100-150 元 | 约 1-1.5 万 |
| 小件 | 素材包加自己画 | 几百元 |

**稳妥方案：一位主画师统一风格、全部约稿、过程文件齐全，约 5-17 万元**
- 四大类（头像、卡面、行走图、背景）全量约稿，国内商用价约 4-14 万元。同样的量找海外画师约 $7,500-30,000。
- 小件（图标、物品、道具、卡框、转盘共 165 个）也约稿，约 1-3 万元。这是按海外单件 $15-50 推算的，国内一般更低【低置信】。
- 如果要完整的著作权转让（买断 ×3，而不是商用 ×2），在上面的基础上再加约五成。
- 找一位画师谈总包可能便宜很多。调研里"独立游戏全套美术总包 8,000-32,000 元"没说明游戏规模，441 个美术 id 的量多半会超过这个上限【低置信】。

**下单前必须再核实：**mingo88、Niao_K、Finnmercury、Raven 的许可和 AI 情况；所有 itch.io 页面的现价和"No AI"标记；Steamworks 问卷的原文措辞；米画师现在的手续费。