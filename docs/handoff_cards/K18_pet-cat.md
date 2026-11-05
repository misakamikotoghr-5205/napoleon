# K18 `pet-cat` · 宠物（店里的猫）

> 本卡补 `docs/cards/DESIGN_cards.md` §九.7 与合同 1.4。**优先级：主创原话 > 合同 > 本卡**。领任务的线自己写本卡（#182：合同缺口由领到的线补）。

## 执行者与线号

- 执行者：**Grok**
- 线号：**K18**（#182 第 2 条；K01–K16 之外的首发新系统）
- 分支：`grok/182-2-pet-cat`，基线 `claude/festive-ride-vud32a`

## 做了什么

店里的猫。一个小牌位，像人脉，不是新区。

- 每天多看一眼：猫在店里时，当天第一次找不同的墨次或吹银元的次数 +1。不是永久眼力。称分量、拼碎片、解密不加。
- 夜里防鼠：猫在的那一晚，货架上的米不掉成色。猫住过又走丢之后，每个这样的晚上每件米货掉 `mold_permille`（默认 50）。从没留过猫的局不变。
- 陪着：猫在店里的日结夜里，隐藏刻度 +`conscience_night`（默认 1）。界面不写这个数，brief 也不写。
- 会走丢：在店住满 `min_nights`（默认 3）之后，夜里 `c.pet.wander`，`int(draw * wander_den) < wander_num`（默认 1/12）就走丢。第二天排 `ev.1938.find_cat`。不会自己走回。牌不在手上、也不在队列里，再过 `retry_days`（默认 3）再排一次。
- 进店：`ev.1938.cat_arrive`，1938 第一关第 15 天，`weight` 0，只排程。留下 / 赶走 / 不理会（`on_expire`）。
- 找猫：去找是两枚铜钱要一个正面。找到才回来。
- 指引：机制 `pet`，步骤 `gd.pet`，教的人 `obj.brother_ledger`，锚点 `a.pet`（备用 `a.contacts`），规矩页仍是 `rule.contact`（不新加页）。第一次留下或找回来的当刻就记，不等第二天早上。

数字都在 `data/cards/rules/pet.json`，【待调】。

## 状态

- 旗标 `rules.flags`：`pet_home` `pet_lost` `pet_refused` `pet_missed`。
- 计数 `rules.pet`：`look_left` `look_day` `had` `find_due` `nights`。全是整数或布尔。没留过猫不写这块。
- 不新增区、命名空间、效果 op、`class_name`。

## 跨线（合同 1.4 记在配套的 [api] issue）

`card_ids.gd`（机制、锚点、随机数域）、`rules_install.gd`（挂上）、`appraisal.gd`（多看一眼）、`hero_bar.gd` 与 `card_layout.gd`（牌位）、`guide/steps.json` 与 `rule.contact`、W0 / K16 的条数断言。

## 不挡打烊

猫牌是普通必须了断的事件：不理会走 `on_expire`，`day.end` 确认后照旧往前走。
