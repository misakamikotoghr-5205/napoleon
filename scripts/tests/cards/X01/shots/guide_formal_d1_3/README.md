# X01-a 正式新存档 1938 第 1–3 天指引截图（真引擎）

- 来源：`scripts/tests/cards/K14/shot_guide_d1_3.gd`（`Walk.FORMAL`：正式 `data/cards`，不传 data_root、不替换教学牌，`mock:false`，隔离 save_dir）
- 代码提交：`4a73c01`（本目录所在提交只加截图，不改代码）
- Godot 4.7.1.stable.official.a13da4feb，box，xvfb 1280×720×24，opengl3：

```bash
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
  -s res://scripts/tests/cards/K14/shot_guide_d1_3.gd -- --out=<dir>
$GODOT --headless --path . -s res://scripts/tests/cards/K14/sheet.gd -- --dir=<dir> --out=<dir>/sheet.png
```

- `01`–`22_<step>.png`：每步一张真实 1280×720 视口截图，按走查顺序。`_test.d1_3` 的 21 步全在，另有
  `20_gd.person_state.png`（正式数据里哥哥「听他交代完」会把哥哥标成已走，真实指引在第 3 天格子牌前多亮这一步；
  要不要留，等 Claude 定）。
- `sheet.png`：拼图（每格 1/4 尺寸，4 列）。`SHA256SUMS`：各文件校验和。
