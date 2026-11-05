<!--
PR 模板。开工前先读仓库根目录的 HANDOFF.md（§6 工作规矩），接口与归属以 docs/cards/CARDS_INTERFACES.md 为准。
标题 [<任务号>] <中文摘要>；目标分支 claude/festive-ride-vud32a。
合并前要在最新集成头上用 Godot 4.7.1 跑门禁：tools/run_card_tests.sh、tools/run_legacy_smoke.sh 全绿，合并人再跑全量 tools/run_tests.sh。
-->
## [<任务号>] <一句话>

### 范围
- 任务 / issue：
- 改动路径（都在 docs/cards/ownership.json 里本任务名下；跨线文件写明是谁同意的）：

### 自查
- [ ] tools/run_card_tests.sh、tools/run_legacy_smoke.sh 在最新集成头上全绿（Godot 4.7.1，贴结果）
- [ ] 输出里没有 SCRIPT ERROR / ERROR / WARNING / Parse Error / 泄漏；没有提交 .import 的改动
- [ ] 红线：打烊永远能按；视图、界面里没有隐藏数值（概率、权重、底价、真假、口碑/风声点数）；伪字、不写血腥
- [ ] .gd / .tscn 里没有中文字面量和颜色字面量；界面字走 CardText，颜色走 CardTheme，坐标走 CardLayout
- [ ] 新机制有新手指引（first-time、锚点、步骤），新面板都能关
- [ ] AI 产物登记了 `_provenance`；没碰人写路径（data/cards/text/**、art/cards/**、audio/cards/**、legal/**、fonts/**）
- [ ] 同种子跑两遍哈希一样；golden 变了的话，按合同 §12.5 单独提交只改 golden.json 的 commit 并写明原因
- [ ] 界面改动附 1280×720 截图

### 需要主创或合并人决定的事
### 已知问题、留给后面的事
