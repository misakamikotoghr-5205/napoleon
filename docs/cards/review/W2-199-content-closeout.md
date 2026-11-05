# W2-6 #199：K13 审读修正与 1938 内容收口

基线：`gpt/199-k13-content`，`0d9176784f89b8d6a7959e669bda62b652df4c1e`。复核日期：2026-10-18。执行依据：`docs/handoff_cards/W2_HANDOFF.md` 任务 6、K13 任务卡，以及本次明确授权的 K13 / 内容线修正范围。

## 意见来源与归属

仓库的 `K01.md`–`K11.md`、`K16.md` 都是 2026-10-13 交付前的“未审读”占位报告，没有逐牌意见。不能把这些报告里的零计数当成已完成审读。本轮以 K13 任务卡列明的规则对当前全量真数据重新扫描，并核对 1938 教学人物和跨线登记；下表区分扫描发现、本轮人工发现、已满足的历史意见。本轮不声称完成 1939–1940 全部人物关系的人工审读。

归属登记直接使用 `docs/cards/ownership.json` 的现有规则：

| 文件 | 归属及已登记模式 |
|---|---|
| `data/cards/era/1939/people.json` | K03：`data/cards/era/1939/{people,story}.json` |
| `data/cards/era/1940/officialdom.json` | K17：同名精确路径 |
| `data/cards/era/1938/tutorial.json` | K16：同名精确路径 |
| `data/cards/guide/steps.json` | K16：`data/cards/guide/**`（K18 也有共享登记） |
| `docs/cards/post1949/policy_events.md` | K16：`docs/cards/post1949/**` |
| 本对照表、同目录 `README.md`、`STATUS.md` | K13：`docs/cards/review/**` |

新对照表已被 K13 的目录通配登记覆盖，不新增归属、不修改归属表。数据改动为 `brief` / `_meta.brief`，以及 K03 的四处跨年剧情走向引用纠正。保留 id、日程、数值、效果操作及其分支结构、来源记录、机制代码和测试。没有修改 `data/cards/text/**` 的人类正文。

## 逐条对照

| 编号 / 来源 / 意见原文要点 | 文件 / id / 字段 | 修改或不修改的理由 |
|---|---|---|
| R01 · 本轮扫描，K13 `puppet_prefix`：日方扶植的政权前面要有“伪”；原片段“往区公所升” | `data/cards/era/1940/officialdom.json` / `p.ma.1940.baozhang` / `brief` | 改为“往伪区公所升”。只补政权定性，不改官场选项或后果。 |
| R02 · 本轮扫描，K13 `brief_no_dialogue`：“引号内超过 12 个字”；原片段“「guide_data 只有例子集 3 步」” | `data/cards/guide/steps.json` / `_meta`（不是牌 id）/ `brief` | 原文是工具说明而非对白。改为无引号的历史说明：W0 早期只覆盖三步，当前以完整指引为准；同时去掉过时的测试必红判断。70 步及其条件保持原样。 |
| R03 · 本轮扫描，K13 `fifties_no_punish`；原片段“不发「批斗」「游街」「抄家」这类牌” | `docs/cards/post1949/policy_events.md` / 无牌 id / “明确不做”第一项 | 原文是禁止事项，属于否定语境误报。改成“禁止批斗，禁止游街，禁止抄家；这些场面不描写，也不做成牌”。逐项明确禁令，让原有否定识别能正确读取；不放宽词表或检查器。 |
| R04 · 本轮人工核对，K13 任务卡要求人物关系不矛盾；原片段“张先生来当” | `data/cards/era/1938/tutorial.json` / `p.zhang.1938.tut_pawn` / `brief` | 改为“护士张慧娟来当”。依据 K09 `ct.zhang` 的“张慧娟，县城教会医院的护士”及 K01 `p.zhang.1938.help_shanghai` 的“借给她”。保留人物 id、簪子及第 1 天看货教学。 |
| R05 · 同上，教学人物称呼与既有人设对齐；原片段“李先生来卖” | `data/cards/era/1938/tutorial.json` / `p.li.1938.tut_sell` / `brief` | 改为“学生李敬之来卖”。依据 K09 `ct.li` 及 K01 `p.li.1938.pawn_letter` 的县立中学学生身份；不新定人名。 |
| R06 · 本轮 1938 收口核对；原片段“人物登记等 K01” | `data/cards/era/1938/tutorial.json` / `ev.1938.tut_fortune` / `brief` | 改为“人物已由 K01 登记为 suanming”。登记已在 `data/cards/era/common/passersby.json` 的 `persons.suanming`；去掉已过期的等待描述。 |
| R07 · 本轮 1938 收口核对；原片段“人脉牌 id 等 K09” | `data/cards/era/1938/tutorial.json` / `ev.1938.tut_contact` / `brief` | 改为“人脉牌为 K09 已登记的 ct.zhouma”。实际效果原已引用该牌，`data/cards/common/contacts.json` 已定义；不改引用。 |
| R08 · 历史意见，`stages_1939.md`：“只把那条 _doc 改成 K13 已核对……不要改 start 和 days” | `data/cards/rules/stages.json` / `stages[1]`（era `1939`）/ `_doc` | **不改，基线已满足**：写明已核对 `1940-01-09` 至 `1940-02-07`，起点与 30 天未变；此文件归 G02，不在本次内容修改范围。只复核历史意见是否落实，未重新做历法考证。 |
| R09 · 历史意见，`K07.md` 与 README：例子 `dm.1938.money.t1` 的开头缺“伪” | `data/cards/_examples/demand/demands.json` / `dm.1938.money.t1` / `brief` | **不改**：旧报告明确这是 W0 例子，非 K07 交付数据，归 Claude。本轮全量真数据不含 `_examples`；真数据 `data/cards/demand/demands_1938.json` 同名 id 已写“伪维持会”。不把例子集说成零问题。 |
| R10 · K13 任务卡：指引不泄露隐藏数值、演出块 brief 同样审读、不写暴力细节 | 当前全量真数据（含 guide_step、rule_page、已存在的 stage 子树） | **保留现有内容与规则**：全量措辞复查零命中。没有为了扫绿删除场面、移除扫描范围、放宽规则或改用 default 校验。没有演出块的牌不视为完成画面演出验收。 |
| R11 · 1938 引用收口，实测 `NOTE: dangling story s1938.wangshan:met`；K03 任务卡要求走向名必须已由 K01 定义 | `data/cards/era/1939/people.json` / `p.wangshan.1939.pawn_ring`、`p.wangshan.1939.ask_wary` / 各自 `conditions` 中的 `story` 与 `brief` | 两处 `met` 改为 `helped`。依据 K01 `p.wangshan.1938.visit`：收留选项 `shelter` 实际写 `helped`；其余为 `turned`、`ignored`。对应肯把东西押下的正向后续与其相反的戒备后续；brief 同步明确为“收留”，不再含糊称“见过”。保持原条件组合及离开状态限制。 |
| R12 · 1938 引用收口，实测 `NOTE: dangling story s1938.linsao_term:accepted`；同上 | `data/cards/era/1939/people.json` / `p.linsao.1939.pawn_coat` 的 `conditions`；`p.linsao.1939.redeem` 的 `effects.on_accept[0].cond`；两牌 `brief` | 两处 `accepted` 改为 `extended`。依据 K01 `p.linsao.1938.term`：宽限选项 `extend` 实际写 `extended`；其余为 `forfeited`、`ignored`。正向后续对应宽限簪子当期，未宽限走冬衣后续；brief 同步明确“宽限”，不新增走向或选项。 |

## 需要主创 / 内容负责人拍板（未代定）

本轮 R01–R07、R11–R12 都能依据既有规则、人设或 K01 已写出的走向修正，没有新增待定决策。以下原有留白保持原样，不把它们算作本轮已定稿：

| 位置 | 保留的待定内容 | 原因 |
|---|---|---|
| `data/cards/era/1938/people.json` / `persons.nf1938a`–`persons.nf1938d` | 钱阿根、周阿绣、方小安、崔老奎均为“名字提议……由 A 定稿” | 需主创 / A 确认正式名字；本轮不替换为自定名字。 |
| `data/cards/era/1938/story.json` / `p.wangshan.1938.visit`；`people.json` / `p.wangshan.1938.help_food`、`p.sunyoung.1938.buy_jade` | 王山“哪一边先不写死”、孙家少爷“真正要来做什么先不写死，留给后年站队” | 属于后续剧情编排，保留模糊身份，不自行确定立场或动机。 |
| `docs/cards/post1949/policy_events.md` / `ev.branch.1950.land_reform`（设计提议 id） | `stage_day【待调】` | 超出 1938 收口；具体日程留待主创 / 后续内容编排，不擅自落到数据。 |

## 验证记录

环境：`godot --version` 原文为 `4.7.1.stable.official.a13da4feb`。测试从本 worktree 根目录运行。没有运行合并门禁，没有改主分支、提交、推送或开 PR。

### 措辞扫描及工具测试

实际命令（初扫、修正后的复扫均使用同一工具和规则）：

```bash
python3 tools/cards/review/wording_lint.py --scope=all --fail-on=must --json=/tmp/dh-199/wording-before.json
python3 tools/cards/review/wording_lint.py --scope=all --fail-on=must --json=/tmp/dh-199/wording-final.json
python3 -m unittest discover -s tools/cards/review/tests
```

初扫原文（逐条见 R01–R03）：

```text
LINT MUST data/cards/era/1940/officialdom.json:p.ma.1940.baozhang:brief puppet_prefix 日方扶植的政权前面要有“伪”或“汪伪”：区公所
LINT MUST data/cards/guide/steps.json:_meta:brief brief_no_dialogue 引号内超过 12 个字或含。！？，像能直接拿去用的对白
LINT MUST docs/cards/post1949/policy_events.md:-:body fifties_no_punish 1950 年代不写斗争会和运动场面：批斗、游街
LINT DONE 3 must, 0 should, 0 hint
```

最终扫描退出码 0，工具测试退出码 0，原文：

```text
LINT DONE 0 must, 0 should, 0 hint
.............
----------------------------------------------------------------------
Ran 13 tests in 0.012s

OK
```

### 严格校验、内容清单与悬空引用

第一次直接运行下面命令退出码 1；Godot 的默认用户目录不可写导致清单进程退出 134。原日志 `/tmp/dh-199/content-suites.log`，代表性失败原文：

```bash
CARDS_VALIDATE_MODE=strict CARDS_SUITES=K01,K02,K03,K04,K05,K06,K07,K08,K09,K10,K11,K13,K16,K17,K18 bash tools/run_card_tests.sh
```

```text
✗ K13_wording_lint (exit 134)
    ERROR: Failed to open 'user://logs/godot2026-10-18T15.18.48.log'.
卡牌版测试失败
```

随后给 Godot 使用可写的临时 XDG 目录，不更改项目配置、测试脚本或失败判定。使用这些目录的第一次完整复跑中，54 项清单显示通过，但 K03 内部仍打印下列两条 NOTE，不能据此宣称悬空引用为零：

```text
NOTE: dangling story s1938.linsao_term:accepted
NOTE: dangling story s1938.wangshan:met
CARDS TEST PASS K03_guide_support
```

`validation_extra.gd` 的 V11 检查剧情节点是否存在，未覆盖此处走向名。因此 R11/R12 修正后，既重新运行全体 54 项内容清单，也独立遍历数据检查所有剧情走向引用。没有过滤 NOTE、白名单或跳过检查。

单独严格校验的实际命令（退出码 0；最终内容清单还会再次执行同一严格校验）：

```bash
XDG_DATA_HOME=/tmp/dh-199/xdg-data XDG_CONFIG_HOME=/tmp/dh-199/xdg-config XDG_CACHE_HOME=/tmp/dh-199/xdg-cache CARDS_VALIDATE_MODE=strict godot --headless --path . -s res://scripts/cards/core/validate_main.gd -- --mode=strict --name=cards_data_validate
```

```text
CARDS VALID 1115 cards, 0 errors
CARDS TEST PASS cards_data_validate
```

最终内容清单实际命令（日志 `/tmp/dh-199/content-suites-final.log`）：

```bash
XDG_DATA_HOME=/tmp/dh-199/xdg-data XDG_CONFIG_HOME=/tmp/dh-199/xdg-config XDG_CACHE_HOME=/tmp/dh-199/xdg-cache CARDS_VALIDATE_MODE=strict CARDS_SUITES=K01,K02,K03,K04,K05,K06,K07,K08,K09,K10,K11,K13,K16,K17,K18 bash tools/run_card_tests.sh > /tmp/dh-199/content-suites-final.log 2>&1
```

最终结果：**54/54 清单测试通过；严格数据校验 1115 张牌、0 错误；悬空引用 0**。脚本整体退出码 **1**，唯一失败阶段为导入的 localhost 监听错误，不能把整条脚本标为通过。以下是该命令输出原文：

```text
✗ import (exit 0)
    ERROR: Condition "_sock == -1" is true. Returning: FAILED
    ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE
    ERROR: Condition "_sock == -1" is true. Returning: FAILED
    ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE
✓ 数据校验（strict）：CARDS VALID 1115 cards, 0 errors
✓ K01_data
✓ K01_guide_support
✓ K01_silver_pawn
✓ K02_data
✓ K02_guide_support
✓ K01_validate
✓ K03_guide_support
✓ K02_validate
✓ K03_data
✓ K03_validate
✓ K04_data
✓ K04_guide_support
✓ K04_validate
✓ K05_data
✓ K05_guide_support
✓ K05_validate
✓ K06_guide_support
✓ K06_data
✓ K07_data
✓ K06_validate
✓ K07_guide_support
✓ K08_guide_support
✓ K08_data
✓ K07_validate
✓ K08_validate
✓ K09_guide_support
✓ K09_data
✓ K09_validate
✓ K10_data
✓ K10_guide_support
✓ K10_bail_day
✓ K11_data
✓ K10_validate
✓ K13_wording_lint
✓ K11_guide_support
✓ K11_validate
✓ K16_guide_coverage
✓ K16_validate_strict
✓ K16_tutorial
✓ K13_rules_valid
✓ K16_validate
✓ K17_baozhang
✓ K17_validate
✓ K17_baozhang_guide
✓ K17_baozhang_real
✓ K18_validate
✓ K18_apprentice
✓ K18_apprentice_ui
✓ K18_pet
✓ K18_pet_edges
✓ K18_scare
✓ K18_pet_flow
✓ K18_scare_ui
✓ K16_d1_3_mock
卡牌版：54 项清单测试；日志：/tmp/tmp.pig0ZuTYUH
卡牌版测试失败
```

最终内部日志原文（`/tmp/tmp.pig0ZuTYUH/validate.log`、`K03_guide_support_.log`、`K13_wording_lint_.log`、`K13_rules_valid_.log`）：

```text
CARDS VALID 1115 cards, 0 errors
CARDS TEST PASS cards_data_validate
CARDS TEST PASS K03_guide_support
CARDS TEST PASS K13_wording_lint
CARDS VALID 1115 cards, 0 errors
CARDS TEST PASS K13_rules_valid
```

另对该轮全部 55 份校验 / 测试日志检查 `NOTE:.*dangling` 与 `DATA ERROR:`，结果：

```text
CONTENT LOGS 55; DANGLING REFERENCES 0
```


补充检查实际命令为 `python3 /tmp/dh-199/check_story_refs.py`（退出码 0）。其完整代码如下，可在仓库根目录重建运行；它不改仓库、不调用引擎，覆盖所有非例子真数据的剧情条件与分支，核对它们是否有已定义的 story 效果产出：

```python
import json
from pathlib import Path

produced = set()
refs = []

def walk(value, path, card='-', field=''):
    if isinstance(value, dict):
        card = value.get('id', card)
        if value.get('op') == 'story':
            produced.add((value.get('node'), value.get('outcome')))
        if isinstance(value.get('story'), list) and len(value['story']) == 2:
            refs.append((tuple(value['story']), str(path), card, field + '.story'))
        for key, child in value.items():
            if not key.startswith('_') and key != 'brief':
                walk(child, path, card, field + '.' + key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, path, card, field + '[' + str(index) + ']')

for path in sorted(Path('data/cards').rglob('*.json')):
    if any(part.startswith('_') for part in path.parts[2:]):
        continue
    walk(json.loads(path.read_text()), path)
missing = [row for row in refs if row[0] not in produced]
for row in missing:
    print('DANGLING STORY', *row)
print(f'STORY REFERENCES {len(refs)} checked, {len(missing)} dangling; {len(produced)} outcomes')
raise SystemExit(bool(missing))

```

结果原文：

```text
STORY REFERENCES 59 checked, 0 dangling; 72 outcomes
```

### 旧版冒烟及未验证项

实际命令（日志 `/tmp/dh-199/legacy-smoke.log`）：

```bash
XDG_DATA_HOME=/tmp/dh-199/xdg-data XDG_CONFIG_HOME=/tmp/dh-199/xdg-config XDG_CACHE_HOME=/tmp/dh-199/xdg-cache bash tools/run_legacy_smoke.sh > /tmp/dh-199/legacy-smoke.log 2>&1
```

脚本退出码 **1**。9 项冒烟通过；导入报本地套接字错误；主入口 Mock 自动试玩超时。输出原文：

```text
✗ import (exit 0)
    ERROR: Condition "_sock == -1" is true. Returning: FAILED
    ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE
    ERROR: Condition "_sock == -1" is true. Returning: FAILED
    ERROR: Condition "err != OK" is true. Returning: ERR_CANT_CREATE
✓ 数据校验
✓ 对白框
✓ 验货找不同
✓ 小镇数据与轮盘规则
✓ 暂停菜单、设置、返回标题
✓ 过路客人与门口吆喝
✓ 全流程（核心，策略 fair）
✓ 全流程（经由界面，策略 fair）
✓ 小镇自动试玩 2 天
✗ 主入口 --cards（Mock 情景走 60 步） (exit 124)
    
旧版冒烟日志：/tmp/tmp.LOjrRyh7nV
旧版冒烟失败
```

`--cards` 主入口用脚本原有的 120 秒时限，退出码 124；`/tmp/tmp.LOjrRyh7nV/cards_entry.log` 只有 Godot 版本启动行，没有 `CARDS AUTOPLAY` 完成标记，也没有进一步错误。**超时原因尚未确认，不能归因为 localhost 或显示限制，更不能标为通过**。本轮没有延长时限，也没有修改入口机制；该项需入口 / 集成线后续复核。通过的 9 项中含旧版经由界面的 headless 流程，并不等同于这个卡牌入口自动试玩通过。

#### 同 SHA 复跑与基线对照（Grok，2026-10-18，审后补充）

上面是首轮（GPT 沙箱）的原始记录，保留不改。按 GPT 代 Claude 审（2026-10-18T09:27:36Z）第 1 项，在 Grok box 上对**同一 SHA** 和 **base 分支 tip** 在同一环境各跑一次旧版冒烟，脚本、时限（import 300 秒、`--cards` 120 秒）均未改动：

| 运行 | SHA | 退出码 | 结果 |
|---|---|---:|---|
| 本 PR | `9a564407cfbd44f7a645034ea74e2e32071c8188` | 0 | 11/11 ✓（含 `✓ import` 无 ERROR、`✓ 主入口 --cards（Mock 情景走 60 步）`），末行 `旧版冒烟全部通过` |
| base `claude/festive-ride-vud32a` | `0d9176784f89b8d6a7959e669bda62b652df4c1e` | 0 | 11/11 ✓，末行 `旧版冒烟全部通过` |

```bash
env GODOT=godot GODOT_SILENCE_ROOT_WARNING=1 XDG_DATA_HOME=<run>/data XDG_CONFIG_HOME=<run>/cfg XDG_CACHE_HOME=<run>/cache TMPDIR=<run>/tmp bash tools/run_legacy_smoke.sh
```

`--cards` 入口另外单独计时（同一 120 秒 `timeout`，命令即脚本原行 `godot --headless --path . -- --cards --cards-autoplay=60`）：本 PR `9a564407` 退出码 0、54.1 秒；base `0d917678` 退出码 0、53.9 秒；两者末行均为 `CARDS AUTOPLAY day 4`，日志无 ERROR / WARNING。机器 8 核，运行时 1 分钟负载约 5（同机另有其他任务）。Godot 4.7.1.stable.official.a13da4feb。

**归属**：在 Grok box 上，本 PR 与 base 的旧版冒烟和 `--cards` 入口结果一致、耗时一致，首轮的 exit 1 / exit 124 **在本 SHA 上不复现，也没有证据表明由本 PR 引起**（本 PR 只改 brief 与四处 story 引用，不碰入口代码）。首轮 exit 1 中的 import 失败与沙箱禁 localhost 一致；`--cards` 的 124 原因仍未确认——该入口在本机约 54 秒，只有约 2.2 倍余量，较慢或更受限的环境可能撞到 120 秒，这只是推测，未验证。不因此延长时限；这里的“通过”只指上表这两次旧版冒烟，不等于全量 G/C/K 套件或 `merge_gate.sh` 全绿。


导入步骤需要 localhost 监听，而本沙箱禁用本地套接字。即使 Godot 导入进程返回 0，日志中的 `ERROR` 仍按原门禁判失败。此项保留为环境阻塞，不能写成“整套脚本通过”。未通过禁用错误检查、过滤上述错误、改测试或跳过 import 来绕过门禁。

显示相关的真实窗口走查、截图和像素布局未验证：本沙箱无显示；headless 的 UI 逻辑测试不替代可视验收。未跑全量 G/C/K 测试、发行 ship 审核或后续年代的完整人工剧情审读；本次运行范围为 K13 和内容线 K01–K11、K16–K18，以及旧版冒烟。未跑 `tools/cards/merge_gate.sh`。

Godot 自动改写的 16 个占位图 `.import` 已恢复至本轮起始内容。最终数据结构差异复核原文：

```text
DATA DIFF PASS: 10 brief edits, 4 story reference edits; no other data fields changed
```

`git diff --check` 退出码 0、无输出。首轮曾用 `check_pr_paths.py` 的匹配函数对 K03/K13/K16/K17 路径做联合匹配，得到 `OWNERSHIP PASS: 8 files within authorized content/K13 paths`；**这不是 PR 门禁**（审后更正，见下节），不能当作归属已验收。最终工作树只保留本表所列的内容 / K13 文档改动。

### 路径门禁实测（审后补充，Grok 2026-10-18）

`check_pr_paths.py:128–139` 只从 `cards/<G|C|K>NN-<slug>` 分支名识别任务号；本 PR 分支 `gpt/199-k13-content` 不被识别，不带 `--task` 时输出 `NOTE: no task id … ownership check skipped` / `PATHS OK`，归属未检查。合同 §2.6：K13 不改别人的数据；“W2 的集成改动由 Claude 指派，PR 标题 `[X##] …`”。`ownership.json` 的 `_meta.owner` 是 Claude，且须与合同 §2.2 逐条一致。所以登记一个跨线 W2 范围需要 Claude 指派 / 批准，本 PR **不自行改 `ownership.json`**。

当前 PR 不跳过归属的真实结果（base `0d917678`…HEAD `9a564407`，`--author=misakamikotoghr-5205`）：

| `--task` | 结果 | 越界文件 |
|---|---|---|
| （不带，分支名） | exit 0，`NOTE … ownership check skipped`，`PATHS OK: 8 files, 0 problems` | 未检查，不算数 |
| K13 | **exit 1**，`PATHS FAILED: 8 files, 5 problems` | `era/1938/tutorial.json`、`era/1939/people.json`、`era/1940/officialdom.json`、`guide/steps.json`、`docs/cards/post1949/policy_events.md` |
| K03 | **exit 1**，`PATHS FAILED: 8 files, 7 problems` | 除 `era/1939/people.json` 外全部 |
| K16 | **exit 1**，`PATHS FAILED: 8 files, 5 problems` | `era/1939/people.json`、`era/1940/officialdom.json`、三份 `docs/cards/review/*` |
| K17 | **exit 1**，`PATHS FAILED: 8 files, 7 problems` | 除 `era/1940/officialdom.json` 外全部 |

逐文件归属（`ownership.json` 现行规则）：`tutorial.json`、`policy_events.md` → K16；`guide/steps.json` → K16（K18 共享登记）；`era/1939/people.json` → K03；`era/1940/officialdom.json` → K17；三份 `docs/cards/review/*` → K13。没有文件落在 `human_only`。

按归属拆分的本地预演（只在本地 scratch 工作树从 base 各做一个提交，未推送、未开 PR）：K16 组 3 个文件 `PATHS OK: 3 files, 0 problems`；K03 组 `PATHS OK: 1 files, 0 problems`；K17 组 `PATHS OK: 1 files, 0 problems`；K13 组 `PATHS OK: 3 files, 0 problems`，均为 `--task=<ID>` 实跑 exit 0。

**提请 Claude 二选一（未代定）**：

1. **登记 W2 跨线范围**：Claude 指派一个 `X##`，PR 改题 `[X##] …`，并在 `ownership.json`（及合同 §2.2）登记精确路径（按 X02 / K18 先例，合并后还回原主人）：
   ```json
   "X##": [
     "data/cards/era/1938/tutorial.json",
     "data/cards/era/1939/people.json",
     "data/cards/era/1940/officialdom.json",
     "data/cards/guide/steps.json",
     "docs/cards/post1949/policy_events.md",
     "docs/cards/review/**"
   ]
   ```
   之后 `check_pr_paths.py 0d917678 <head> --author=misakamikotoghr-5205 --task=X##` 应为不跳过归属的实际门禁。注意 #218 同时在改 `ownership.json`，登记由 Claude 合并顺序决定。
2. **按归属拆成四个 PR**（K16 / K03 / K17 / K13 各一，分支 `cards/<ID>-<slug>` 自动识别），上面的本地预演表明每组都能单独通过。

