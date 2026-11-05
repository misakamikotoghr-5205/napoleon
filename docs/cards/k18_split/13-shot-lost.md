# K18 猫走丢截图回执（13）

分支 `grok/182-2-pet-cat`。未切分支、未 commit、未 push。未改产品代码，未加 `--import`，未动 `shots/home`。

命令：

`/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/lost/shot_lost.gd`

| 项 | 结果 |
|---|---|
| png | 已生成 `scripts/tests/cards/K18/shots/lost/pet_lost.png` |
| 字节 | 19071（1280×720） |
| 退出码 | 0 |
| 最后一行 | `CARDS TEST PASS K18_shot_lost` |

`--headless` 的假纹理没有视口图。脚本发现无头后用 xvfb 转一次真窗口（OpenGL llvmpipe），由同脚本 `get_viewport().get_texture().get_image()` 写入，不是手绘。牌位正文是 `【稿】猫走了，得去找`，人脉空，四项属性为 3、2、4、1。通过行之前有一条驱动不支持垂直同步的 WARNING。
