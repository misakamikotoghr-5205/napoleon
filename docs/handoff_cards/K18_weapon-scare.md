# K18 · 武器只开吓唬

合同 1.4。#182 第 4 条。DESIGN §九.7。基线已普通合并 `claude/festive-ride-vud32a` @ `038f7db`（含 K17 office）。

1939 腊月第 12 天，生人 `nf_pistol` 拿短枪来。来意是 `story`，不是公开当票。藏起来得到 `kp.pistol`（硬货、不过期、被查到只加风声并记下 `weapon_found`，不抓人）。藏起来记下 `weapon_held`。不收或没理会都没有枪（`weapon_pawn_ignored`）。

1940 起（`loop.stage >= 2`）枪在留着的牌里时，普通客人的回话多一句吓唬（键 `k18.reply.scare`）。胆量检定要 1 个正面。吓住：`weapon_scare_yield`，风声 +1，口碑 -1。没吓住：`weapon_scare_reported`，风声 +3。两种都给计数 `weapon_scare_uses`。金色牌和带 `story_node` 的主线不加这句。

动手不在这一版。没有 `act`。

新机制 `scare`，发出者记在 G03，发牌时记第一次。指引 `gd.scare`，规矩页仍是 `rule.kept`。

跨线文件暂时挂在 K18 名下，只为路径检查能过。合并后请 Claude 把它们还回原主人：`choices.gd` / `rules_install.gd` 归 G03，`slot_panel.gd` 归 C03，`counter_panel.gd` 归 C04，指引两份归 K16，`card_ids.gd`、骨架测试、合同和归属表归 Claude。

与 K17 的 `office`、已合并的 #189 `pet`、以及本支收徒并在一起：机制数 70（office、pet、apprentice 与 scare 各算一个）。G01 正例夹具 `coverage.json` 的 teaches / unlock 同时保留这四项。

回执截图：`docs/handoff_cards/K18_1940_scare.png`（1280×720）。1940-03-01，留着的牌只有 `kp.pistol`，普通客人 `p.chen.1939.pawn_clock` 的回话里有吓唬。正式台词还没有，按钮上是草稿。年份和短枪被柜台挡住，没画在这张图上。
