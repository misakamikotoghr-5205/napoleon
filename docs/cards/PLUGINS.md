# 剧情插件（story pack）

> 框架版收尾默认（2026-10-22，Claude），主创可改。合同见 `docs/cards/CARDS_INTERFACES.md` §4.5；代码在 `scripts/cards/core/card_packs.gd`（读插件）、`card_db.gd`（分层查字）、`card_text.gd`（缺字回退）。

## 一、剧情插件是什么

卡牌版的牌、规则、数值（“骨架”）都在 `data/cards/**`，这部分是玩法，不随剧情变。玩家看到的字分层放：

| 层 | 位置 | 谁写 | 说明 |
|---|---|---|---|
| 1. 剧情插件 | `packs/<id>/text/**` | 写剧情的人（人或 AI，清单里写明） | 有人物性格的正文、台词、开场、告示。可以有好几个，按清单里的 `order` 叠放 |
| 2. 人写层 | `data/cards/text/**` | 只归人（A/B） | 合同 §4.5 原来的正文层 |
| 3. AI 基础层 | `data/cards/text_ai/**` | AI 线 | 中性、通用、短的“功能正文”，保证每张牌都有能看懂的字 |
| 4. 都没有 | — | — | 默认给空串，界面跳过这一拍；开发开关开着时给【稿】+ brief |

一个剧情插件就是一包“只换字、不换玩法”的正文：它的键和 `data/cards/text/**` 一模一样，插件里写了的字段盖过下面所有层，没写的字段照旧用下面的层。所以插件可以只写正文 `body` 和台词 `lines.*`，牌名、选项、按钮继续用基础层。

只带正文的插件**不改** `CardDB.hash()`（哈希只算机制数据），装上、卸下、改字，存档都照用。

## 二、查字顺序（按字段）

CardText 每次取一个字段（例：`p.chen.1938.buy_scroll#lines.greet`）都从上往下找，找到第一个**非空字符串**就用：

1. 已载入的剧情插件，`order` 大的先查；`order` 相同按 id 排，id 靠后的先查（后者覆盖前者）；
2. 人写层 `data/cards/text/**`；
3. AI 基础层 `data/cards/text_ai/**`；
4. 都没有：默认返回空串，`CardText.has_text(ref)` 为假。界面遇到空的拍子就跳过（对话框不演空句、开月过场不翻空页）。

各层分开存，不合并成一个字典，所以“插件只给 body，牌名用基础层”这种逐字段穿透一定成立。

开发开关（只在非发行版有效）：命令行 `-- --show-drafts` 打开、`-- --hide-drafts` 关掉，或者在项目设置里加 `dehoudang/cards/show_drafts = true`。打开时缺字显示【稿】+ brief（灰、斜），方便看哪里还没写。测试库 `scripts/tests/cards/lib/card_t.gd` 默认打开它，老测试照旧按开发版断言。

## 三、目录

```
packs/
  <id>/
    pack.json                 清单（必有）
    text/                     正文，路径与键照 data/cards/text/** 一一镜像
      ui/C04.text.json
      era/1938/people.text.json
      era/1938/stage.text.json
      persons.text.json
      …
    cards/                    （预留）新剧情牌的增量，暂不读取
    art/                      （预留）美术清单增量，暂不读取
```

- 放在仓库里的：`res://packs/<id>/`，跟游戏一起导出。
- 玩家自己装的：`user://packs/<id>/`（文件夹），或者一个 `.pck` 放进 `user://packs/` 或导出包 exe 旁边的 `packs/` 文件夹。`.pck` 里面的路径必须是 `packs/<id>/…`，挂上后就等于 `res://packs/<id>/`；挂载不覆盖游戏已有的文件。
- id 只能用 `[a-z0-9_]`，必须和文件夹名相同。以 `_` 开头的是开发用插件（例如 `packs/_example`），不进发行包。
- 同一个 id 在 `res://packs` 和 `user://packs` 都有时，用先读到的 `res://` 那份，另一份记一条警告。

## 四、清单 `pack.json`

```json
{
  "id": "proto_1938",
  "name": "1938 试玩剧情",
  "version": "0.1.0",
  "order": 100,
  "source": "ai",
  "_provenance": "ai:claude:opus-5.5:2026-10-22:proto-1938",
  "enabled": true,
  "compat": "cards-text/1",
  "base_db_hash": "",
  "description": "……",
  "requires": [],
  "cards": [],
  "art": ""
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | 是 | 与文件夹同名，`[a-z0-9_]+` |
| `name` | 是 | 给人看的名字（可以写中文） |
| `version` | 是 | 插件自己的版本号，字符串 |
| `order` | 否 | 整数，默认 100。叠放顺序：大的盖小的 |
| `source` | 是 | `"human"` 或 `"ai"`：这包字是谁写的。混着写的拆成两个插件 |
| `_provenance` | 是 | `source` 为 `human` 时照人写层：`human:(A|B):YYYY-MM-DD`；为 `ai` 时照 AI 层的五段：`ai:<工具>:<模型>:YYYY-MM-DD:<提示词或任务 id>` |
| `enabled` | 否 | 默认 `true`；`false` 时不读（命令行 `--enable-pack=<id>` 可临时打开） |
| `compat` | 校验必填 | 插件格式版本，现在只认 `"cards-text/1"`。运行时缺了按 `cards-text/1` 读并警告；写成别的整包跳过 |
| `base_db_hash` | 否 | 写插件时基础数据的 `CardDB.hash()`。对不上只提示（NOTE），不跳过——键对不上的条目本来就会被跳过 |
| `description` | 否 | 说明 |
| `authors` | 否 | 字符串数组 |
| `requires` | 否 | 依赖的插件 id。缺了依赖，这个插件不载 |
| `cards` | 否（预留） | 以后放新剧情牌的文件列表（`cards/*.json`）。现在**不读**，写了运行时警告、严格校验报错。读新牌会改 `CardDB.hash()`，存档会标 `db_changed`，要等机制那边一起设计 |
| `art` | 否（预留） | 以后放美术清单增量（`art/manifest.json`）。现在不读 |
| `_doc` 等 `_` 开头的键 | 否 | 注释，随便写，发行时剥掉 |

别的键一律算错：运行时整包跳过（防止 `enabeld` 这种错字让本该停用的包被打开），校验报 V26。

正文文件可以带 `_meta._provenance`，条目也可以带 `_provenance`；带了就必须和清单的 `source` 同一类（人写包只能写 `human:…`，AI 包只能写 `ai:…`）。

## 五、怎么写一个插件

1. 新建 `packs/<id>/pack.json`，照上表填。AI 写的 `source` 填 `ai`，`_provenance` 用五段格式。
2. 打开 `docs/cards/audit/missing_text.md`（或 `missing_text.json` 的 `entries`）：每条有牌 id、要写的字段（`title`、`body`、`lines.greet`、`choices.<id>`、`outcomes.<x>`……）和人写层的目标文件 `text_file`。把开头的 `data/cards/text/` 换成 `packs/<id>/text/`，就是插件里的文件。
3. 文件内的结构照合同 §4.5 和现有夹具（`tools/cards/audit/fixtures/**/text/**`、`scripts/tests/cards/G01/fixtures/**/text/**`）。例：

   ```json
   {
     "_meta": {"_provenance": "ai:claude:opus-5.5:2026-10-22:proto-1938"},
     "p.chen.1938.buy_scroll": {
       "body": "……",
       "lines": {"greet": "……", "accept": "……"}
     },
     "stage.1938": {"intro": {"p1": "……", "p2": "……", "p3": "……"}}
   }
   ```
4. 只写想改的字段。没写的字段自动用基础层；某个字段想“删掉”不行（空串等于没写，会穿透到下面）。
5. 写字规矩和基础层一样：时代口语、伪政权加“伪”字、不写隐藏数值、不许有 `%`、参数用 `{name}` 这类花括号。人名照统一人名表。
6. 现成的小例子：`packs/_example/`（默认停用，两条正文）。

## 六、怎么测

- 校验（会查 `res://packs` 下每个插件，包括停用的）：
  ```
  $GODOT --headless --path . -s res://scripts/cards/core/validate_main.gd -- --mode=strict
  ```
  插件的问题报 V26：清单字段、来源格式、键在骨架里有没有、字段允不允许、正文里有没有 `%`、插件里有没有代码文件（`.gd` `.tscn` `.pck` 等一律不许）。
  只查别处的插件目录：`-- --packs=<目录1>,<目录2>`；不查插件：`-- --no-packs`。
- 发行缺字（V27）：
  ```
  … validate_main.gd -- --mode=ship --variant=ai-disclosure
  ```
  插件补上的字段算数：`source` 为 `human` 的两种发行版都算；`source` 为 `ai` 的只在带 AI 声明版算。不带声明版（`--variant=no-disclosure`）里出现 AI 插件直接报 V27。停用的插件不算覆盖（要算，加 `--enable-pack=<id>`）。
- 进游戏看：插件默认就载入（`enabled` 为真时）；停用的用 `-- --enable-pack=<id>`；临时全关用 `-- --no-packs`；关掉某一个用 `-- --disable-pack=<id>`。想看还缺哪些字，加 `-- --show-drafts`。
- 坏插件不会挡住新局：清单坏（JSON 坏、来源不对、未知键、id 对不上、格式版本不认识、依赖缺了）整包跳过；正文文件坏整文件跳过；条目坏或键不存在只跳过那一条。都打印成 `CardDB note: …`，也能用 `CardDB.warnings()`、`CardDB.packs()` 查（`packs()` 每行有 `state`：loaded / disabled / skipped，和 `reason`）。AI 基础层 `text_ai/**` 的坏文件同样只警告，不再让“新局”失败；严格校验照样把它们报成错。
- 测试：`scripts/tests/cards/G01/test_packs.gd`（`G01_packs`：逐字段穿透、叠放、停用/启用、坏插件、.pck、校验）、`C09_month_open_skip`、`C04_dialog_skip`（缺字跳过），Python 侧 `tools/cards/audit/tests/`（暂存与审核按变体带不带插件）。

## 七、怎么发行

- **随游戏一起**：插件放在 `res://packs/<id>/`，导出时跟着进包。Steam 出包走 `tools/package_steam.sh` → `tools/cards/audit/stage_ship.py`：只拷 `pack.json` 和 `text/**.json`；跳过 `_` 开头的开发插件、`enabled: false` 的插件、清单坏的插件；不带声明版只拷 `source: "human"` 的插件。`_provenance` 保留给发行校验和审核看。
- **单独发一个 .pck**：用 Godot 的 `--export-pack` 配一个只包含 `packs/<id>/*` 的导出过滤（或者用 `PCKPacker` 打包），文件里的路径必须是 `packs/<id>/…`。玩家把 `.pck` 放进 `user://packs/`（Windows：`%APPDATA%\Godot\app_userdata\德厚当\packs\`）或 exe 旁边的 `packs\` 文件夹，下次启动自动挂载。
- **审核**（`tools/cards/audit/audit.py`）：第 1 项查插件路径（只许 `pack.json`、`text/**.json`，不许 `_` 开头、不许停用的插件进包；不带声明版不许 AI 插件）；第 2 项查清单与正文来源；第 6、7 项把插件正文算进判词、百分号、字体覆盖；第 9 项在 `.pck` 里同样查插件清单。

## 八、AI 声明

- `source: "ai"` 的插件就是 AI 内容，和 `data/cards/text_ai/**` 一样：只能进**带 AI 声明版**；审核报告把它的每一条算进“AI 生成、需声明”的台词统计（按清单的 `_provenance` 统计工具和模型）；被叠在上面的人写插件盖住的字段算“已被人工覆盖”。
- 不带声明版（Steam No AI Disclosure）只能带 `source: "human"` 的插件，而且人写插件的作者必须在 `legal/human_authors.json` 里。
- 归属：`docs/cards/ownership.json` 的 `paths.packs` = `packs/**`，归写剧情的人（各管自己的 `packs/<id>/**`）。`check_pr_paths.py` 对清单写着 `source: "human"` 的插件按人写层处理：作者不在 `human_authors.json` 的改动一律拒绝（新建一个自称 human 的插件、或者把 human 插件改成 ai，也拒绝）。

## 九、还没做的

- `cards/`（新剧情牌）与 `art/`（美术增量）只登记了清单字段，加载器不读。做的时候要处理：新牌改 `CardDB.hash()`（存档 `db_changed`）、人物登记、美术清单合并、发行审核。
- 玩家在游戏里开关插件的界面（现在只有命令行开关和清单的 `enabled`）。
- `tools/cards/audit/missing_text.py` 还不认插件：缺字清单只看基础层。想看“装上某个插件后还缺什么”，用上面的 `--mode=ship` 校验。
