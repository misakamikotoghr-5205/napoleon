# 界面自查清单（代替真人 GUI 试玩，见 HELP_RESPONSES R2）

验收方式：`tools/run_tests.sh`（含经由界面的自动试玩）+ `DISPLAY=:5` 渲染截图后逐张目检（screenshots/）。

| 项 | 怎么查 | 第一天状态（M3） |
|---|---|---|
| 热点可点 | 自动试玩经 counter_view.hotspot_clicked / item_clicked 驱动全部教学与放进典当盒；截图看高亮框是否落在物体上 | OK：放大镜、算盘、小秤、账簿、档案簿、鉴别录、典当盒、垃圾箱高亮均对位 |
| 文字溢出 | 截图看右栏、对白框、面板底部 | 已修：右栏议价区改为可滚动；4 个选项按 2×2 排；当票竖排在格子内 |
| 豆腐块 | validate_data 检查数据文本全部在字体里；截图目检 | OK（字体为 GB2312 全集 + 项目用字） |
| 教学清晰 | 每个教学点都有哥哥台词 + 发亮热点 + 右栏提示；不看够部位不让出价（小丁至少三处、李敬之必须称重并翻报纸） | OK |
| 底价显示 | 第一天顾客下方显示“客人底价”（设计稿要求）；第二天起不显示 | OK |
| 隐藏数值不外露 | 本心、怀疑、好感、概率不出现在界面 | OK |
| 世界在动 | 右栏“行情”每天随轮盘涨跌；清晨“（听挑担的说）……”；客人临走可能转述传闻（档案簿标〔听说〕） | OK |
| 声音 | 嘀嘀对白、算盘、铜钱、门板、电报（程序合成） | 本机无音频设备，未实听 |

未覆盖：真人的手感（拖拽 vs 点击、阅读节奏），等真人试玩。

## R2 复查（M5）

复查日期 2026-10-10。依据：screenshots/m5_*、m2/m3/m4 新截图；代码见 dialogue_box.gd、counter_view.gd、main.gd、sidebar.gd、inspect_panel.gd、prologue.json、director.gd。R2 旧图为窗口截图（顶部约 30 px 被装饰遮挡），非游戏问题。

| 项 | 状态 | 证据 |
|---|---|---|
| 推进典当盒：先点物再点盒，无文字提示 | FIXED | m5_fix_pawnbox_hint.png 黄框+▼+浮字「先点当物，再点高亮的典当盒」；main.gd:159-163、515-519 |
| 点击过快跳过台词 | FIXED | dialogue_box.gd:76、185-236 typing 状态+180 ms 防抖；m5_fix_typewriter.png 显示「▼ 点击继续」 |
| 鉴定面板选项被裁切/出滚动条 | FIXED | m5_fix_inspect.png 选项 2×2 加整行全部可见，无滚动条 |
| 右栏拥挤、待办截断 | FIXED | m4_cliffhanger.png 待办完整；m3_day1_li.png 待办可滚动（附注见视觉遗留） |
| 小丁「客人底价 25」直接明示 | PARTIAL（与设计冲突） | sidebar.gd:288-297 已去掉底价与心里估价（floor_lbl 置空）。但设计稿 story_sub2 第 337 行「客人要价和底价写在每位顾客下方」、第 361 行小丁 50/25，self_checklist 第一天行仍写「显示底价」。需决定：恢复第一天底价并加一句教学说明，或改设计稿 |
| 角色名低对比（哥哥/陈叔叔） | PARTIAL | dialogue_box.gd:65、166-172 已提亮；哥哥、小丁、马保长采样亮度 0.62 合格；但 m5_fix_typewriter.png 与 m2_prologue_3_tutorial.png 的「陈叔叔」采样为原色 #5a3f2a（亮度 0.26），未生效，需查原因并重截 |
| 烛火段「远处有狗」被截/淡出过快 | UNVERIFIED | prologue.json:26 整句完整；R2_02 亦为整句；无新截图，淡出时长未核 |
| 账本货币字太小 | PARTIAL | m4_ledger.png 字号下「蚨」清晰可读；未与 R2_05 做逐像素对比 |
| 算盘/放大镜提示箭头与热点不对位 | FIXED | counter_view.gd:206 _draw_arrow 贴高亮框上沿；m5_fix_pawnbox_hint、m5_fix_hotspots 箭头对位 |
| 热点淡、棋子几乎看不见 | FIXED | m2_prologue_7_chess.png 棋子黑底圆+金边清晰；counter_view.gd:161 悬停改为灰色细框 |
| 选项出现空白行；旗子选项分支 | UNVERIFIED | 无新门旗截图（R2_08 为旧图）；4 选项布局 m3_day1_li.png 无空行 |
| 哥哥去开门后柜台仍显示哥哥 | PARTIAL | prologue.json:226 的叙述行仍在 scene brother:false（约 228 行）之前执行，「哥哥去开门」那句仍显示哥哥。建议把 scene brother:false 提到 226 行之前 |
| 重复「（笑了笑）」舞台指示 | FIXED（代码） | director.gd:274-279 同一客人连续相同神色去重；mind.gd:198 仍为来源；无新截图 |
| 交易结束后右栏残留旧客人 | FIXED（代码） | sidebar.gd:296-318 closed 状态与 close_session 切回信息面板；m5_fix_hotspots.png、m4_cliffhanger.png 右栏无旧客人 |
| 悬浮提示残影/不跟随光标 | FIXED | counter_view.gd 已无 tooltip_text，改发 hover_text（53、297-302）；main.gd:500-510 跟随光标，离开时清空 |
| 右上 HUD 字小、对比低 | OPEN | m5 系列「门旗/招牌/行情」仍为小号灰字 |
| 接受报价后米袋短暂消失 | UNVERIFIED | 本次未核查 |

汇总：FIXED 9，PARTIAL 4（其中「底价」与设计冲突），OPEN 1，UNVERIFIED 3。

视觉遗留（新截图）：
- m3_day1_wangshan.png 底部：黄字「选好了，再点发亮的典当盒（或垃圾箱）。」压在垃圾篓上、无底框、左侧被遮，来源 main.gd:542 _toast。建议与 stow_hint 同款底框，或移入对白框。同图第二行选项几乎被窗口底边裁掉。
- m3_day1_li.png 右栏：「资助」按钮越出「照他的价」列并贴到滚动条；「推回去（不收）」在滚动区底部被裁。建议收窄或放到独立行。
- m2_prologue_3_tutorial.png 文件名与内容不符（实为棋子段）：棋子排距约 42 px，m2_prologue_7_chess.png 为 60 px，已完成棋子几乎不可见。建议重截并统一尺寸。
- counter_view 已无 tooltip_text，但 main.gd:650、inspect_panel.gd:104、sidebar.gd:76、115 仍用 tooltip_text（非本条范围，记录备查）。
- 未见豆腐块字。m5 窗口截图底部约 30 px 白条为桌面，非游戏内容。

### 复查后的处理（主控，M5）
- 底价：**按 R2 反馈与用户指示，真实顾客一律不显示底价与心里估价**（设计稿第一天【实现】的例外被取消）；哥哥在旁时只小声给建议价，属教学。视为已关闭。
- 陈叔叔名牌：代码对所有名牌统一提亮（亮度 ≥ 0.6 + 深色描边），新截图肉眼可读；复查采样落在描边像素上。关闭。
- 哥哥去开门：`scene brother:false` 已移到“后门传来三声轻敲……哥哥去开门”那句之前，陈叔叔进门后再出现。关闭。
- 浮字提示（toast）：改为左上角带底框，不再压在垃圾箱上。关闭。
- “资助”按钮：独占一行，不再挤到滚动条。关闭。
- 对白框动作过多（王山 8 个）：每行 4 个、字小一号，台词区压扁，全部在框内（见 m3_day1_wangshan.png）。关闭。
- HUD 门旗/招牌/行情：字号 13→15、提亮。关闭。
- 未验证项（狗叫淡出、门旗空行、米袋闪一下）：打字机已改为“先补全整句”，门旗选项 2 个一行；米袋闪动为成交后物品换位置（柜台→库房→放进盒子提示），留待后续动画。
