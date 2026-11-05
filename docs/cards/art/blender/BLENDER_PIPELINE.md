# 德厚当 · Blender 出图交接（2026-10-27）

> 主创 10-27 原话：
> - “把现有的推到 GitHub/onedrive 里，我让 Gemini 驱动 Blender 做整套的”
> - 随后更正：“说错了 Google Drive”
>
> 这份文档写给**驱动 Blender 的人或 AI**（下称“操作方”），也写给主创，内容依次是：
> - 先看的结论和红线
> - 怎么装、怎么跑通样张
> - 管线原理和调参经验
> - 怎么加新场景，整套怎么排
> - 怎么交付，怎么验收
>
> 配套文件：
> - `ASSET_LIST.md`：441 个图位逐个分类：适不适合 Blender、归哪一套场景、要哪些道具
> - `PROPS_NEEDED.md`：要建模或要买的民国道具和人物清单
> - `catalog.json`：上面两份的原始数据
> - `MODELS.csv`：模型来源登记
> - `samples/`：样张
> - 代码在 `tools/blender/`

---

## 0. 现状和结论（先看这一节）

### 跑通的流程

已经跑通一条流程：**人做的 3D 模型 → Blender 卡通分层着色 + 1 像素描边 → 按游戏尺寸直接出图 → 每张压到 20–24 色**。样张有两样（`samples/`），用 `tools/blender/make_samples.sh` 能逐像素复现：

- 主界面柜台背景 `bg.counter.day/dusk/night`，320×180：一个场景，换三种光
- 库房卡 `illus.es.storeroom`，64×48

### 看对比图得出的三条

1. **3D 渲染直接缩小是一团糊**（`samples/compare_storeroom_card.png` 中间那张）。必须走卡通分层、描边、按原尺寸直出这条路。
2. **好处**：
   - 场景搭一次，就能出早、晚、夜三张。
   - 所有图的透视和风格自然统一。
   - 有了模型库以后，加图很便宜。
3. **最大的短板是模型内容**。现在只有 KayKit 免费包（CC0，作者 Kay Lousberg），是西式卡通厨房、家具和城市楼房。所以画面里是现代台灯、平板门、西式排屋。
   - 民国上海的道具和人物必须另外找人建模或者买，清单在 `PROPS_NEEDED.md`。
   - **KayKit 的人物是 Q 版奇幻角色，不能用来画这个游戏的人。**

### 样张只是演示管线，不能进游戏，也不能当构图模板

- 两个样张场景（`scenes/counter.py`、`scenes/storeroom.py`）的摆放，是 Claude 对照现在的 AI 图摆出来的。
- 里面的对联板和箱子上的锁，是脚本拼的方块，第 1 节第 1 条不允许这样做。
- 新场景只照它们的**代码结构**写，构图另起，依据见第 1 节第 2 条。

### 单靠这批图去不掉 Steam 的 AI 标签

文本、音频、商店页素材，以及第 6 节说的不走 Blender 的图（图标、头像、行走图等），都要清干净才行。见 `docs/cards/art/ART_SOURCING_2026-10-27.md` 第 1 节。

## 1. 红线（不遵守的话，这件事就白做了）

做这件事是为了去掉 Steam 商店页的“AI 生成内容”标签，所以下面几条比画得好不好更重要。

### 1. 画面里的每样东西，都必须是人做的模型

**许可**只接受这几种：

- CC0
- CC-BY 3.0 或 4.0
- 买来的、许可写明可以商用、可以用于渲染图片的

**不要用**：CC-BY-SA、CC-BY-NC、CC-BY-ND、GPL、“仅个人使用”、Sketchfab Editorial。

**用了 CC-BY 的**：
- 在 `MODELS.csv` 的 `attribution` 列写全署名：作者、作品名、链接、许可版本，以及“已修改”。
- 主创照着这一列做制作人员页（这一页归人管，操作方不写）。
- CC-BY 不许给作品加技术保护措施，它和 Steam DRM 的关系见 ART_SOURCING。能找到 CC0 的，就别用 CC-BY。

**不要用 AI 生成的 3D 模型或贴图**，例如 Meshy、Tripo、Rodin、Hunyuan3D 这类文字或图片转 3D 的工具，也不要用 AI 画的贴图。

**操作方不许用脚本“做”道具**：
- `box`、`plane` 只能用来搭房间的壳：地、墙、天花、梁柱、台面板，以及门外的天空板。
- 凡是一眼能认出是一件东西的，都必须是 `MODELS.csv` 里登记过的人做模型。例如算盘、格子门、对联、锁、招牌、家具、器物。
- 没有模型，就先空着，写进 `PROPS_NEEDED.md`，不要用方块拼一个顶替。

**场景里不许载入任何别的图片。** 只允许登记过的模型包自带的贴图。
- AI 做的 HDRI、天空图、贴花、招贴、字画都不行。
- 也不许把仓库里现成的图（`art/**`、`docs/cards/art/**`）贴到面片上。
- `render.py` 渲染前会检查：每个模型、每张图片都必须出自 `MODELS.csv` 登记过的包，否则直接报错停下。

**每个模型包都要登记在 `MODELS.csv`**，共 10 列：

| 列名 | 写什么 |
|---|---|
| `model_pack_or_file` | 包的文件夹名 |
| `source_url` | 来源网址 |
| `author` | 作者 |
| `license` | 许可 |
| `downloaded` | 下载日期 |
| `version_or_commit` | 版本或提交号 |
| `used_in` | 用在哪些场景，分号隔开 |
| `license_evidence` | 许可原文或购买页截图存在哪 |
| `ai_check` | 凭什么认为不是 AI 做的：作者声明、发布日期早于 2022、附了工程源文件，或者书面确认 |
| `attribution` | 署名原文 |

### 2. 构图依据只用人做的东西

**能用的**：
- 主创手画的草图，或者逐件摆放表：什么东西、大概在哪、机位、光从哪来。
- 主创写的文字说明。
- 能说清出处的民国老照片、老画报：图书馆或博物馆馆藏、原版画报的扫描。要记下网址或馆藏号；不用“AI 修复”“AI 上色”的版本，也不用来路不明的社交媒体转图。

**不能当构图依据的**：
- `docs/cards/art/GOOGLE_ORDER_2026-10-22.md`：这是给 Google 图像模型的提示词，现在的 AI 图就是照它出的。
- `ASSET_LIST.md` 的“画面内容”一栏：这是 Claude 生成的，只用来查这个图位是哪张卡、在哪出现。构图细节由主创另外给。

**操作方是 AI 的时候**：
- 别把这些东西放进它的上下文：`art/ai/**`、`art/_placeholder/**`、`docs/cards/art/candidates/**` 里的任何图，`samples/compare_*.png`，`pipeline_*.png`，以及 `compare.py` 出的对比图。
- `make_samples.sh` 默认不出对比图；对比图只给主创定稿时看。

### 3. 构图是谁定的，要说清楚

ART_SOURCING 第 2.11 节说“大概率不用披露”的，是 AI 只写渲染管线这种情况：通用工具、按给定的摆放去定机位和打光。

**AI 定构图，是另一回事。** 如果每张图摆什么、摆在哪由 Gemini 之类的 AI 决定，就和 ART_SOURCING 第 1 节表里“AI 写的脚本按固定规则画出的像素图”是同一个灰区，置信度低，不能套用 2.11 的结论。主创从 AI 做的几个候选里挑一张，**不算人定了构图**。

**想往“人做的”那边靠**：由主创先给草图或摆放表，操作方只负责把它翻成场景脚本、调机位和灯光。

**拿到 Valve 的书面答复之前，别默认这批图不用披露。** 在 Steamworks 后台问的时候，照实际做法写，建议原文：

> 我们的像素美术是这样做的：3D 模型全部由人制作（CC0 或购买，清单附后）；每张图的物件摆放由【开发者手绘的摆放图／Google Gemini（大语言模型）】决定，Gemini 把它写成 Blender Python 脚本并设定机位和灯光；Blender 渲染后按固定规则减色；开发者挑选，可能手工改像素。请问这类美术在 Content Survey 的 AI Generated Content 部分是否需要披露？

### 4. 全程不用任何生成式图像功能

以下这些，交付图、参考图、贴图一律不许碰：

- Gemini 或 Imagen 的出图和改图
- Google Flow
- Photoshop 生成式填充
- AI 放大（Real-ESRGAN、waifu2x、Upscayl 等）
- AI 去噪、AI 上色
- Blender 的 AI 插件（Dream Textures、AI Render 等）

最终图只用 `make_samples.sh` 出。它带 `--factory-startup`，不加载任何插件。

**操作方不改像素。** 要改，只能由主创本人在挑定之后改，并记下谁改的、改了哪里。

### 仓库里只有人能改的地方

- `art/cards/**`
- `legal/**`
- `data/cards/text/**`
- `audio/cards/**`
- `data/cards/theme/palette.json`
- `fonts/**`
- `pack.json` 里写着 `"source": "human"` 的 `packs/<id>/**`

**操作方只读仓库，不提交、不推送**。交付是一个文件夹，见第 7 节。

## 2. 环境

| 东西 | 要求 | 备注 |
|---|---|---|
| Blender | **4.0.x 或 4.1.x**（样张用的是 4.0.2）。旧版下载：`https://download.blender.org/release/Blender4.1/` 或 `.../Blender4.0/`，Windows、macOS、Linux 都有 | 4.2 以后（包括官网现在默认给的 5.x）换成了 EEVEE Next：脚本不报错，但色块出颗粒、描边少四成左右，对联板也会消失，和样张对不上。所以 `render.py` 遇到 4.2 及以上会直接拒绝，除非加 `--allow-new-blender` 做实验。把管线移植到 EEVEE Next 还没人做 |
| Python 3 + Pillow + numpy | 系统 Python 即可（样张用的是 Pillow 12.3、numpy 2.5） | 后处理 `pix.py`、`compare.py`、`gen_asset_list.py` 要用 |
| Blender 自带 Python 的 numpy | 官方 tar 包和安装包自带。Ubuntu 软件源的 Blender 用系统 Python，要 `apt install python3-numpy`，否则导入 glTF 报 `No module named numpy` | |
| EEVEE 渲染 | 要 OpenGL。有显卡的 Windows 或 macOS 不用管 | 没有显卡的 Linux：`apt install libegl1 libgl1-mesa-dri`。日志里的 `EGL Error (0x3001)`、`EGL Error (0x3009)` 可以不管，只要后面有 `Managed to successfully fallback to surfaceless EGL rendering!` |
| Cycles | 只用来出对照图（`--mode soft`），不是交付。Ubuntu 版不带 OpenImageDenoise，降噪是关着的 | 1280×720 用 CPU 渲一张约 2 分钟 |
| Shell | `.sh` 脚本要 POSIX shell。Windows 用 Git Bash 或 WSL | macOS 的 Blender 不在 PATH 里，要设 `BLENDER=/Applications/Blender.app/Contents/MacOS/Blender` |
| 模型包 | `sh tools/blender/fetch_models.sh`：从 GitHub 拉 3 个 KayKit 包，固定在样张用的提交，共约 60 MB，放进 `tools/blender/models/`（已被 git 忽略） | 要放到别处，渲染时设 `KAYKIT_DIR`。另外的包（比如买来的）放在仓库外，用 `MODEL_PATH` 指过去，多个目录用系统路径分隔符隔开 |

## 3. 拿到文件，跑通样张（第一步就做这个）

**拿文件**：

- **操作方用部分克隆**，只取管线需要的文件：`tools/blender/` 和 `docs/cards/art/blender/`，不含 `samples/`。完整仓库里有 `art/ai/**`（现在的 AI 图）和样张对比图，不能放进 AI 操作方的上下文（第 1 节第 2 条）。

  ```sh
  git clone --filter=blob:none --no-checkout https://github.com/misakamikotoghr-5205/dehoudang
  cd dehoudang
  git sparse-checkout set --no-cone '/tools/blender/' '/docs/cards/art/blender/' '!/docs/cards/art/blender/samples/'
  git checkout claude/festive-ride-vud32a
  ```

  仓库如果是私有的，要主创给权限。部分克隆里没有游戏数据，所以 `compare.py` 的左栏会是空的，这是有意的。
- **主创自己**用完整仓库即可（定稿时要用 `compare.py` 对比现在的图）。

**跑样张**：

```sh
sh tools/blender/fetch_models.sh            # 约 60 MB
sh tools/blender/make_samples.sh            # 输出到 tools/blender/out/，4 张，十几秒到 40 秒
```

每个图位得到三个文件：

- `<图位 id>.raw.png`：Blender 直出
- `<图位 id>.png`：减色后的成品
- `<图位 id>.log`：渲染日志

有任何一张失败，脚本会打印 `FAILED <id>` 和错误摘要，并以退出码 1 结束。

在 Blender 4.0.2 下，`bg.counter.*.png` 和 `illus.es.storeroom.png` 应该和 `samples/` 里的同名文件**逐像素一致**。比较的是解码后的像素：PNG 字节会不同，因为 Blender 会写入渲染日期。

不用看图也能核对：`pix.py` 打印的 `PIXELS` 行应该是下面这些值。部分克隆里没有样张图片，就用这个办法核对。

| 图位 | 像素哈希 |
|---|---|
| `bg.counter.day` | `01fab8fc0420c226cd407cd6b2e6cb00e451d2c69683f23317b875f9ea1f95ae` |
| `bg.counter.dusk` | `c5f99f8156596126dd5876cd6be0024feefdb308b9e12184dad046e0b37c48a6` |
| `bg.counter.night` | `fa9db9d333d292bc5abaa29ec4047a602b4dbe849909090d83f48a334b7332b0` |
| `illus.es.storeroom` | `1803bda576c208675f57f9784ba1117cec2e4999daeb673cea6761e4de5411c5` |

**单张渲染**：

```sh
blender -b --factory-startup -noaudio --python-exit-code 1 --python tools/blender/render.py -- \
    --scene counter --variant night --out out/n.raw.png        # 默认：卡通 + 1 像素描边 + 不抗锯齿
blender -b --factory-startup -noaudio --python-exit-code 1 --python tools/blender/render.py -- \
    --scene counter --variant night --mode soft --size 1280x720 --out out/n.soft.png   # Cycles 对照
python3 tools/blender/pix.py out/n.raw.png out/n.png --colors 24
```

**一定要带 `--python-exit-code 1`。** 不带的话，脚本出错时 Blender 照样返回 0。

**主创定稿时**才用：`sh tools/blender/make_samples.sh --compare`，或者 `python3 tools/blender/compare.py <图位 id> <新图> <对比图>`。前提是完整仓库：新旧图放大并排，下面一行是两张的原尺寸。

## 4. 管线原理和调参经验

| 文件 | 做什么 |
|---|---|
| `tools/blender/bl_lib.py` | 载入模型、改材质、卡通化、描边、渲染 |
| `tools/blender/scenes/*.py` | 每个场景一个文件，只管摆东西、放相机、打灯 |
| `tools/blender/render.py` | 命令行入口，含模型来源检查和版本检查 |
| `tools/blender/pix.py` | 减色 |
| `tools/blender/compare.py` | 对比图 |
| `tools/blender/list_jobs.py` | 给 `make_samples.sh` 列出所有场景 |

### 4.1 卡通分层（`bl_lib.toonify`）

每个材质都换成下面这条链（只在 EEVEE 里有效，Cycles 没有 Shader to RGB 节点）：

1. 白色漫反射 → Shader to RGB → 亮度
2. 亮度过一条常量色带，分成 3–4 档
3. 乘材质底色
4. 再乘“灯光颜色 ÷ 亮度”，这样暖灯和冷月光的色相能保留下来
5. 作为自发光输出

带自发光的材质不处理（比如门外的天空板）。

色带写在各场景的 `ramp(variant)` 里，格式是 `((位置, 亮度), ...)`：

| 场景 | 色带 |
|---|---|
| 柜台白天、黄昏 | `((0,0.20),(0.06,0.42),(0.25,0.72),(0.8,1.0))` |
| 柜台夜里 | `((0,0.07),(0.03,0.22),(0.15,0.55),(0.6,1.0))`。最暗那档一定要压低，不然墙面发灰发紫 |
| 库房卡 | `((0,0.40),(0.12,0.72),(0.45,1.0))` |

### 4.2 描边（`bl_lib.outlines`）

- 用 Freestyle，只画轮廓（silhouette）和开口边（border），不画折痕和内轮廓。
- 线宽 1 像素，颜色 `#1f1712`，也就是游戏的墨色。
- 几何很密的模型（比如 `book_set` 的书页）会被描成一整块黑。用 `bl_lib.noline(objs)` 把它们排除在描边外。

### 4.3 按原尺寸直出，不要先大后缩

- 卡通渲染直接用图位尺寸：背景 320×180，卡面 64×48，以 manifest 的 `base` 为准。
- 设 `taa_render_samples=1`、`filter_size=0.01`，边缘就是硬像素。
- 先渲大图再缩小，会糊，还会出过渡色。试过渲 4 倍再用 BOX 缩小，明显更差。

### 4.4 减色（`pix.py`）

- 每张图单独选色：
  - 背景用 24 色 `mediancut`。
  - 小卡面用 20 色 `maxcoverage`，这样能保住少量强调色（书脊的橙、锁的金）。
- 试过把颜色硬套到游戏自己的 35 色板（`--palette game`）上，更差：墙变绿，柜台出噪点。所以默认不用。
- 正式交付前最好统一一套“Blender 版色板”。**这套色板由主创定**，操作方只能在 `pix.py` 的参数里试，不写进 `palette.json`。

### 4.5 构图和比例

**KayKit 尺寸**（1 个 Blender 单位约合 0.75 米）：

| 模型 | 尺寸 | 备注 |
|---|---|---|
| 墙 `wall.gltf` | 4×4，厚 0.5 | |
| 门 `door_A` | 宽 1.6，高 2.8 | 原点在门轴 |
| 厨房柜台 `kitchencounter_straight_A` | 2×2×1 | 样张用 `stretch(c,1,0.6,1.2)` 压薄加高，当铺高柜台 |
| 罐子 `jar_*_large` | 高 0.75 | |
| 城市楼房 `building_*_withoutBase` | 宽 1.2–2，高 1.65–3.05 | 要放大 3 倍左右 |
| 中世纪六边形包的房子 | 高 0.9–1.4（教堂 1.65） | 按地块比例做的，不好用 |
| Q 版人物 | 高 2.2–2.7，头占一半 | **不能用** |

**64×48 的卡面**：
- 一件东西至少要 6 像素宽才认得出。所以少放、放大。
- 背景深、主体浅，对比要强。

**320×180 的柜台背景是界面底图**：
- 代码会把可点的工具（放大镜、算盘、钱匣、账本、本子、黄历、告示、条子墙、灯、古玩架）、摆件、招牌和门旗，叠画在固定位置。坐标就是 320×180 底图上的坐标，见 `scripts/cards/api/card_layout.gd` 的 `S_HOTSPOTS`、`S_PROP_SPOTS`、`S_SIGN`、`S_DOOR_FLAG`、`S_CURIO`。古玩架也是代码贴的，不要建进底图。
- 这些位置在底图上要留空：台面空、墙面空。样张没做到这一点，台面上放了台灯和书。
- 这是界面约束，不是照 AI 图摆。

**相机**：`bl_lib.camera(位置, 看向的点, 焦距)`。样张柜台用 36 mm、平视；库房卡用 33 mm。

### 4.6 灯光

Blender 的灯沿自身 -Z 方向照。`rot=(a, 0, b)` 的照射方向是 `(−sin b·sin a, cos b·sin a, −cos a)`。两个例子：
- 白天的太阳 `rot=(35°,0,150°)`：从门外右上方往屋里照。
- 黄昏 `rot=(70°,0,180°)`：压得很低，从门外直射进来。

样张的布光：

- **白天**：
  - 太阳
  - 门口一块面光，朝屋里照
  - 相机前上方一块 6×6 的大面光补光：在相机和柜台之间，y=-3、高 3.5，斜向下照进屋
- **黄昏**：
  - 橙色太阳
  - 橙色门口面光
  - 很弱的补光
  - 25 W 油灯点光
- **夜里**：
  - 环境光要非常低：卡通模式 0.15，Cycles 0.7。卡通着色没有曝光可调。
  - 160 W 暖色油灯点光
  - 门口一块冷色面光
  - 弄堂里几盏暖色小点光当路灯

**阴影软硬**：
- 太阳看 `light.data.angle`，`bl_lib.light` 里设的是 3°。
- 点光看 `shadow_soft_size`，样张里是 0.15–0.2。
- 面光看 `size`，门口 2.5，补光 6。

### 4.7 样张里还在的问题

- 柜台上的“油灯”是现代台灯（`lamp_table`）。
- 当品是一个相框。
- 门是平板门，不是格子门。
- 没有算盘、招贴。
- 对联和锁是方块。
- 门外是西式排屋。
- 台面没有给热点留空。

## 5. 加一个新场景

1. 在 `tools/blender/scenes/` 新建 `<名字>.py`，照 `storeroom.py` 的**代码结构**写（构图另起），要定义：
   - `SIZE`
   - `VARIANTS`
   - `IDS`：变体对应的 manifest 图位 id
   - `COLORS`
   - `ramp(variant)`
   - `build(variant, toon)`
2. 在 `scenes/__init__.py` 里**两处**都要加：
   - `from . import counter, storeroom, <名字>`
   - `SCENES` 字典里加 `"<名字>": <名字>,`
3. 单张渲染，看 `.raw.png` 和 `.png`，反复调整。**操作方不看对比图。** 调好后，`make_samples.sh` 会把所有登记的场景一起重出。
4. 一套场景要出多张图时（比如柜台的三种光，或同一间屋子里不同角度的几张卡面），用变体实现，不要复制场景文件。
5. 场景要确定：不用随机数。需要“随机”摆放的，用固定种子算出来，参考 `jars_on`。这样任何人重跑，都会得到同一张图。
6. 新模型：
   - `bl_lib.load()` 能读 glTF、GLB、FBX、OBJ 和 `.blend`，按扩展名自动选择。
   - 可以公开下载的包：在 `fetch_models.sh` 里加上下载命令并固定版本。
   - 买来的包：放在仓库外，用 `MODEL_PATH` 指过去，不要提交进仓库。
   - 在 `bl_lib.py` 里加一个包名常量。
   - **在 `MODELS.csv` 登记**，不登记的话 `render.py` 会拒绝渲染。

## 6. 整套怎么排

- 逐个图位的分类、场景分组和建议顺序，见 `ASSET_LIST.md`：哪些适合 Blender、归哪套场景、要哪些道具、优先级。
- 先做覆盖第 0 批（P0：每局第 1 天必然看到的）多的场景。
- 道具清单见 `PROPS_NEEDED.md`，拿去约建模或者挑素材包。
- **不走 Blender 的**（`ASSET_LIST.md` 里适合度标“不适合”的，`catalog.json` 里是 `poor`），还是约稿或手画：
  - UI 图标、卡框、转盘
  - 人物头像、行走图
  - 写满字的纸片

  人物尤其如此：用 Blender 做人，需要专门的民国人物模型、绑定和姿势，成本远高于约稿画 47 个头像。

## 7. 交付（操作方交一个文件夹，不往仓库里提交）

### 7.1 操作方交什么

每批交一个文件夹 `德厚当_blender_<批次>/`（网盘、压缩包都行），放：

1. **图**：
   - 文件名用图位 id 加 `.png`，例如 `bg.counter.day.png`。
   - 尺寸等于 manifest 的 `base`。
   - RGB PNG，背景和卡面不要透明。道具、物品这类要透明底的，单独商量。
   - 只能是 `make_samples.sh` 的输出，不改像素。
2. **`scenes/*.py`**：本批新增或修改的场景脚本。
3. **`MODELS.csv` 的新增行**，以及许可证据文件。
4. **`README.md`**，每张图一行，写明：
   - 图位 id、像素哈希（`pix.py` 打印的 `PIXELS` 那一行。PNG 文件本身的 sha256 会随 zlib 和 Pillow 版本变，不能拿来比）
   - 场景脚本路径和它的 sha256、变体
   - 完整的 `render.py` 和 `pix.py` 命令行
   - Blender 版本
   - 用到的 `MODELS.csv` 行
   - 构图依据：主创草图或摆放表的文件名
   - 参考资料清单：网址或馆藏号
   - 操作方：人名，或者 AI 产品名加模型版本
   - 像素有没有改过（应当是“没有”）
5. **对话导出**：操作方是 Gemini 的话，导出整段对话，包括给它的指令。

### 7.2 主创或 Claude 收到以后

1. 把场景脚本放进 `tools/blender/scenes/`，模型行并进 `MODELS.csv`，然后重渲一遍，核对像素哈希和 README 一致。
2. 把图放进 `docs/cards/art/candidates/blender_<批次>/`，给主创挑。`docs/` 整个目录不会被 Godot 导入。
3. 主创挑定以后，放进游戏，分两种情况：
   - **在拿到 Valve 书面答复、并且主创修改 `CARDS_INTERFACES.md` 里“`art/cards/**` 只放人画的”口径之前**：
     - AI 参与摆场景的图，只能放进 `art/ai/<类别>/<id>.png`。
     - 在 manifest 登记 `ai` 路径和 `_provenance: "ai:gemini-blender:<Gemini 模型版本>:<日期>:<场景>-<变体>"`。
     - 这一步 Claude 可以做。这样的图在免声明版里会被自动排除，披露照旧保留。
   - **移进 `art/cards/**`**：只能由主创本人做。`legal/ASSET_PROVENANCE.csv` 的 method 一栏要照实写，例如“Blender 渲染，Gemini 按主创摆放图写场景脚本，模型见 MODELS.csv”。
4. 如果 Valve 答复说不用披露：在 `tools/cards/audit/audit.py` 里加一条例外，注明答复编号。不要换个说法去绕开 `method_is_ai`。
5. 原始 `.blend` 文件不进仓库。场景是脚本生成的，脚本加上模型版本就能复现。
6. 如果以后真要给操作方 git 权限：必须用单独的 git 作者，和不在 `legal/human_authors.json` 里的 GitHub 账号，不能用主创的账号。

## 8. 验收清单（每张都过一遍）

- [ ] 尺寸等于 manifest 的 `base`。背景和卡面没有透明像素。
- [ ] 64×48 的卡，按 100% 看原图，认得出主体。主创定稿时看 `compare.py` 对比图下面那行原尺寸。
- [ ] 描边连贯，没有成块的黑。如果有，看看是不是哪个很密的模型漏了 `noline`。
- [ ] 夜景够暗、灯够亮，墙面不发灰发紫。
- [ ] 柜台背景上，代码叠画的位置（`S_HOTSPOTS`、`S_PROP_SPOTS`、`S_SIGN`、`S_DOOR_FLAG`、`S_CURIO`）是空的。
- [ ] 没有穿帮：现代或西式的台灯、塑料、汽车、洋文招牌、Q 版人物。
- [ ] 画面里没有可读的文字和数字。
- [ ] 没有用脚本方块拼的道具，没有包外图片。`render.py` 的来源检查通过，也就是日志里有 `RENDERED`，没有 `not from a pack registered`。
- [ ] 用到的每个模型都在 `MODELS.csv` 里，10 列填全。
- [ ] 全程没用生成式图像功能，没有改像素（第 1 节第 4 条）。
- [ ] 构图依据是主创的草图或摆放表，README 里写了文件名。
- [ ] 主创在自己机器上重跑 `make_samples.sh`，像素哈希（`PIXELS` 行）和 README 一致。
