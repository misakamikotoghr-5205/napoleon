# K18 找猫牌截图回执（14）

分支 `grok/182-2-pet-cat`。未切分支，未 commit / push，未改产品代码，未跑 `--import`。

## 命令

`/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/find/shot_find.gd`

退出码 0。日志无本脚本的 `SCRIPT ERROR`。

`--headless` 的显示驱动只有 dummy，视口读不出像素。脚本发现自己在 headless 时，只再拉起一次 `xvfb-run -a -s "-screen 0 1280x720x24"`，用同一 Godot、`--rendering-driver opengl3` 画真视口。本机缺 `libXcursor` / `libXinerama`，动态库在 `/tmp/xlibs/usr/lib/x86_64-linux-gnu`，这次重入会把它放进 `LD_LIBRARY_PATH`。

## 画面

- `CardEngine.new_game`：seed 7，`only_examples` false，`save_dir` = `user://test/K18_shot_find`
- `CardPiles.spawn` 把 `ev.1938.find_cat` 放进手牌
- 控件：`CardWidget`（`scenes/cards/card/CardWidget.tscn`，脚本 `scripts/cards/ui/card/card_widget.gd`）。`set_card` 用引擎 `view().hand` 里这张牌的那一项，手牌尺寸，画面正中
- 没用手牌扇：开局阶段是 `month_open`，扇在非日/夜阶段是空的，也更重

## 结果

- png：已生成
- 路径：`scripts/tests/cards/K18/shots/find/find_cat.png`
- 大小：12097 字节，1280×720
- 最后一行：`CARDS TEST PASS K18_shot_find`
