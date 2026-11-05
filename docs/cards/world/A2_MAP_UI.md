# 地图操作界面续作记录

> 本文记录 `d375c8d3` 时的 A2 状态；后续已完成 B2/C2/C3 正式第一卷接入与默认入口切换，当前状态见 [VOLUME1.md](VOLUME1.md)。下文的“待接入”和 17 套验收属于历史记录。

2026-11-04，分支 `napoleon-campaign-next`，基于 Claude `claude/festive-ride-vud32a` 的 `0ec4f625`。保留既有 A1、B1、C1 工作；原 Claude 分支与 0.9 分支不覆盖。设计依据为 [WORLD_MAP_DESIGN.md](WORLD_MAP_DESIGN.md) §5、§12、§15.2。

## 已接通

- 标题读取书名、局外记录和可进入篇章；支持显式书/段/章参数，窗口标题跟随书名。缺失正式数据时入口显示原因。
- 地图显示当前位置、节点、路线、雾、对手、四种币和行军资源。Natural Earth 底图支持投影、条件镜头、拖动与 1–3 倍缩放，世界图默认 2 倍。
- 每日骰子、指定点数、行军手牌、移动、侦察、建站、收费选择、开拔；节点事务、商店、营地、插曲和行军箱/伙伴入口使用已有后端命令。
- 地图事件通过 `event:` 接入 VN；查验、选项和条件失败原因来自引擎。每场角色美术覆盖仅作用于该场 VN，不改全局图集。
- 根场景按 `campaign.map.enabled` 选择地图或原营地。剧情/战斗结束返回地图，菜单存档与继续沿用 A1 格式。
- UI 只读公开 `view/query`，镜头条件由后端求值。`--map-reveal` 只改变预览，不修改探索状态；未揭开的节点不暴露剧情或开放行动。

## 试玩与验收

使用 Godot **4.7.1.stable.official.a13da4feb**；云环境先执行 `source /workspace/.dehoudang-env/activate.sh`。

```sh
# 独立存档，从标题开始；不占用 0.9 或默认远洋的目录。
godot --path . -- --cards \
  --book=res://data/campaigns/napoleon/fixtures/mini_book.json \
  --save-dir=user://cards/napoleon-map-preview

# 直接选择远洋第二章（章号从 0 开始）。
godot --path . -- --cards \
  --book=res://data/campaigns/napoleon/fixtures/mini_book.json \
  --segment=ocean --stage=1 --save-dir=user://cards/napoleon-map-preview

GODOT=godot bash tools/run_ocean_tests.sh
GODOT=godot bash tools/run_legacy_smoke.sh

# 有图形显示时额外导出真实界面截图；无头验收不读取纹理。
OCEAN_MAP_SHOTS=/tmp/napoleon-map-shots godot --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  -s res://scripts/tests/cards/OCEAN/test_map_ui.gd
```

OCEAN runner 共 17 套，新增 `test_map_ui.gd`。它通过真实控件覆盖行军、营地/商店、事件 VN、战斗返回、章间插曲、直接章节入口、行军箱、预览限制、剧情锚点门禁、两次保存/继续的状态哈希与命令日志一致。`map_policy.gd` 仅是测试侧的公开接口策略，不进入发行运行时；三条迷你分支分别抵达 `k_mini_vol_dusk`、`o_mini_alliance`、`m_mini_vol_wait`。

本轮实测：17 套 OCEAN 测试与旧版冒烟全部通过。地图 UI 为 188 项断言、46 次控件命令；Xvfb/Mesa 图形复验为 193 项断言，导出并检查 5 张截图。图形驱动仅提示不支持切换 V-Sync，无脚本/渲染错误；无头验收无警告或错误。独立初始存档、源码归档、截图与日志保存于 `/workspace/snapshots/napoleon-campaign-next/`，未覆盖既有快照。本轮未重复运行完整 396 项旧卡牌清单。

## 后续工作与边界

- 正式 `data/campaigns/napoleon/book.json` 仍引用尚未落地的主干、征服、基督山等剧情/地图/事件文件；完整书不能作为可玩成品发布。当前验收对象为 `fixtures/mini_book.json`，`DEFAULT_BOOK` 保持 `ocean_pawn`。
- 按现有计划继续 B2 战斗模板、C2 正式内容接入，再做 C3 默认书切换与标题→土伦→地图→首战验收。
- 标题的“继续分岔存档”恢复已有 `branch.json`。标准携带、重新抽种子的“从分岔点新开局”后端入口仍待实现，不能把恢复快照当作该功能。
- 继续信息目前显示第 N 日；完整历法日期尚未从 `title_info` 暴露。原 `--cards-autoplay` 未改成地图全流程策略。
- 所有美术沿用现有素材或代码占位，本轮没有制作正式美术。
