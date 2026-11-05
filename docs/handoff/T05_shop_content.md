# T05 店铺特写内容（茶馆、米行、济生堂、保公所、邮电局、集市）

- **执行者**：Grok
- **依赖**：可先写数据；联调要等 T03（ShopView）与 T02（背景图）
- **分支**：`town/T05-shops`
- **状态**：完成（Grok / 2026-10-11）

## 目标
每家店进门都是一个有人味的侧视特写：掌柜的招呼随天气、米价、时段、你们的过往而变；菜单里的事都有实际后果（钱、货、流言、关系），不是摆设。

## 必读
1. `docs/handoff/TOWN_INTERFACES.md` §7（配置格式与动作白名单）
2. `docs/town/research/repo_story.md`（周妈、陈叔叔、马保长、孙福等人的口吻与秘密；**照原文口吻写**）
3. `docs/town/research/web_research.md` §4（1938 江南小镇各店的历史依据：茶馆是消息与说和的地方、米行挂牌价、保甲与维持会……）
4. `docs/town/mockups/B2_ricehall_sideview.png`

## 要做的事
- [ ] `data/town/shops/{teahouse,ricehall,pharmacy,baogong,post,market}.json`：招呼语（每店 ≥8 条，带条件）、动作菜单（每店 4–7 个）、话题（每店 ≥5 个，可引出流言或线索）。
  - 茶馆（周妈）：喝茶听消息、托周妈找买主、吃讲茶（调解纠纷，后续）、打听某人
  - 米行（吴掌柜，新人物）：看牌价、买米、赊账（额度随口碑）、问米船、把收来的米卖给米行
  - 济生堂（陈叔叔）：买药、请他对批号（付费鉴定）、卖药给药铺、后屋（剧情锁）
  - 保公所（马保长）：交维持费/房捐、议价、办良民证、问告示
  - 邮电代办所（新人物）：取信（哥哥的信）、发电报（明码，后台记录）、汇款
  - 集市（五天一集）：估衣摊收满当衣物、旧货摊、货郎
- [ ] 需要脚本的动作写成 `data/story/town_shop_*.json`（沿用现有剧情脚本 op）。
- [ ] 新人物（吴掌柜、邮电代办所的人）补进 `data/cast.json`（人格预设、口吻、日程），并在回报栏告诉 T01 加进 town_pack。
- [ ] 测试 `scripts/tests/test_town_shops.gd`：每个配置能加载、每个动作 kind 在白名单、每个 script 存在、条件表达式能求值。

## 只能改这些文件
`data/town/shops/**`、`data/story/town_shop_*.json`、`data/cast.json`（只新增人物）、`scripts/tests/test_town_shops.gd`、`tools/run_tests.sh`（只追加）。

## 写作原则（主创定的）
- 克制、观察式旁白；后果晚到、安静。
- 不显示任何好感/概率；关系变化只从称呼、语气、是否赊给你、是否告诉你消息里体现。
- 这些文字现在由 AI 写，上 Steam 前要么人工重写、要么在 Steam 披露（见 `docs/town/research/art_costs.md` §1）。在每个文件里加 `"_provenance": "ai_draft"`，方便日后统计。

## 回报（执行者填写）
- 分支 / PR：`town/T05-shops`（叠在 `town/T02-art-maps` 上，因为吴掌柜/何先生的立绘和导入测试要先有图）
- 测试结果：`test_town_shops.gd` 通过（6 店能加载、招呼 ≥8、话题 ≥5、动作 4–7、kind 在白名单、script 文件存在且 id 相符、条件可解析）。`validate_data.gd`：27 脚本、15 人物，无缺字。
- 遗留问题：吴掌柜、何先生已写入 `data/cast.json`（日程地点名用的是合同里的那 12 个）。请 T01 把这两人补进 `town_pack.json` 的 npcs/links。剧本里还没进 cast 的人（吴、何、货郎）只用旁白转述，避免校验失败。店内动作的钱和货要等 T03 的 ShopView 才真正入账；脚本只落旗标、笔记和允许的 stat。每个文件带 `_provenance: ai_draft`。越界：为了让数据校验能找到立绘，分支继承了 T02 的 `art/portraits/wu.png` 与 `postman.png`（T02 已交）。
