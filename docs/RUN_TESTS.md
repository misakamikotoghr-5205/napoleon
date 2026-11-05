# 如何运行自动测试

## 前置
- Godot 4（headless 可用即可）、bash、python3、coreutils `timeout`、xargs。
- 在仓库任意位置执行均可，脚本会先 `cd` 到仓库根目录。

## 运行
```bash
bash tools/run_tests.sh                                    # 跑到结尾（默认 until=ending）
GODOT=/path/to/godot4 JOBS=4 bash tools/run_tests.sh       # 指定可执行文件与并行数（默认 6）
bash tools/run_tests.sh --dry-run                          # 只打印解析到的 godot 路径后退出
```
- `GODOT`：Godot 可执行文件路径。脚本按以下顺序自动探测：显式 `GODOT` → `command -v godot` → `command -v godot4` → 脚本内置的旧默认路径（仅原开发机存在，仅作最后兜底）；都找不到会打印错误并以退出码 2 退出。
- `JOBS`：并行数，默认 6。
- 第一个参数可选，指定全流程策略跑到哪一步（默认 `ending`）。

## 结果
- 先串行跑 12 项前置检查（导入、数据校验、对白、整理、议价、人格、v0.3b、小镇美术、店铺特写、验货、打字机音效、活当赎回），再并行跑 63 项（分支计划、经由界面、全流程、防卡死），打印 `共 N 项并行测试；日志：<临时目录>`。
- 接着依次跑小镇各阶段：T01 小镇模拟、T04 小镇玩法、T07 数值烟测、T03 小镇界面与自动试玩、过路客人；最后调用 `tools/run_card_tests.sh` 跑卡牌版清单测试（`CARDS_SUITES=G04,X01` 这类写法可只跑部分套件）。
- 日志中出现 `SCRIPT ERROR` / `ERROR` / `WARNING` / `FAIL:` 等，或非零退出码，即判失败；任一阶段失败即以退出码 1 退出，全部通过时最后一行是「卡牌版测试全部通过」。

## 常见问题：测试跑不起来（退出码 2，或每项都是 `✗ ... (exit 127)`）
127 = 找不到要执行的命令。按可能性从高到低排查：

1. **首要原因：找不到 Godot。** `GODOT` 未设置，且 `PATH` 里既没有 `godot` 也没有 `godot4`；脚本回落到内置的旧默认路径，而该路径只在原开发机存在。当前脚本会在启动时直接打印「错误：找不到 godot 可执行文件」并以**退出码 2** 退出，不会再逐项报 127（旧版脚本写死路径，才会表现为每项 127）。
   - 处理：`GODOT=/path/to/godot4 bash tools/run_tests.sh`，或把 `godot` / `godot4` 加入 `PATH`。
   - 自查：`bash tools/run_tests.sh --dry-run` 应打印 `GODOT=<路径>`；`"$GODOT" --version` 能打印版本号即可。
2. **次要原因：缺 `timeout`。** 每个测试都经 coreutils `timeout` 调用，本机没有（如 macOS 默认无）时每项都会是 exit 127 → 安装 coreutils（macOS：`brew install coreutils`）。
3. **次要原因：文件无执行权限。** `GODOT` 指向的文件不可执行时，启动校验同样会报错并以退出码 2 退出 → `chmod +x <godot 路径>`；直接用 `./tools/run_tests.sh` 运行而脚本本身无执行权限时会报 Permission denied（退出码 126）→ 改用 `bash tools/run_tests.sh` 或 `chmod +x tools/run_tests.sh`。
