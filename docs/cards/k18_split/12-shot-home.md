# K18 猫在店截图回执（12）

分支 `grok/182-2-pet-cat`。未切分支、未 commit、未 push。未改产品代码，未加 `--import`。

命令：

`/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/home/shot_home.gd`

| 项 | 结果 |
|---|---|
| png | 已生成 `scripts/tests/cards/K18/shots/home/pet_home.png` |
| 字节 | 18772（1280×720） |
| 退出码 | 0 |
| 最后一行 | `CARDS TEST PASS K18_shot_home` |

`--headless` 的假纹理没有视口图（直接 `get_image()` 会在 dummy 渲染器上报 `ERROR: Parameter "t" is null`）。脚本发现无头后用 xvfb 转一次真窗口（OpenGL llvmpipe），由同脚本 `get_viewport().get_texture().get_image()` 写入整屏，不是手绘。

视图不含隐藏键：`self.uid` 为 `self1`，`attrs` 为 eye 3、tongue 2、pull 4、nerve 1，`contacts` 空，`pet` 为 `{show:true, home:true, lost:false}`。牌位正文是 `【稿】店里的猫在`。人脉空。

通过行之前有一条驱动不支持垂直同步的引擎警告（llvmpipe，不是缺字体）：

`WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver.`

本机起初没有 `libXcursor.so.1` 和 `libXinerama.so.1`，真窗口会失败并打出 `Unable to create DisplayServer`。这两份库已放到系统加载路径后，上面的命令才能截到图。没有字体类警告，没有对象泄漏警告。
