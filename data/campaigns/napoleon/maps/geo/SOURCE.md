# 世界地图底图：来源与许可

本目录的三张底图只给界面画世界地图用（陆地、湖泊、冰盖、河流、小岛轮廓），不进内核状态，不受整数规则约束（WORLD_MAP_DESIGN §1 C4、§5.1）。

| 文件 | 视图 | 用在哪里 |
|---|---|---|
| `europe.json` | 墨卡托，经度 −12…56，纬度 24…63，画布 2400×2012 | 主干第一到第六幕、鹰飞 |
| `world.json` | 米勒圆柱，全球，2400×1402，x 方向在 180° 经线回绕 | 远洋鹦鹉螺号一章 |
| `med.json` | 墨卡托，经度 −6…30，纬度 34…51.5，2400×1606（1:10m 海岸） | 伊夫堡第三、四章 |

地图文件（`maps/*.json`）的 `views.*.base` 写底图 id（`europe` / `world` / `med`），解析到 `res://data/campaigns/napoleon/maps/geo/<id>.json`；投影参数从底图自己的 `view` 读（WORLD_MAP_DESIGN §1 C3、§6.4）。

## 来源

- **Natural Earth**（https://www.naturalearthdata.com），**公有领域**（public domain）。Natural Earth 的条款：“All versions of Natural Earth raster + vector map data found on this website are in the public domain. You may use the maps in any manner, including modifying the content and design, electronic dissemination, and offset printing.” 不需要署名，这里仍注明出处。
- 用到的图层（每个文件的 `source_files` 字段逐个列出）：
  - `europe.json`：`ne_50m_land`、`ne_50m_lakes`、`ne_10m_rivers_europe`、`ne_10m_rivers_lake_centerlines`
  - `world.json`：`ne_50m_land`、`ne_50m_lakes`、`ne_50m_antarctic_ice_shelves_polys`
  - `med.json`：`ne_10m_land`、`ne_10m_lakes`、`ne_10m_lakes_europe`、`ne_10m_rivers_europe`、`ne_10m_rivers_lake_centerlines`
- 人工补画（不是 Natural Earth 的数据，文件里标了 `approx` 或 `fictional`）：伊夫堡与弗留利群岛的近似轮廓、新厄尔巴岛与林肯岛（虚构）、咸海的历史近似轮廓。现代水库已从湖泊里去掉。每个文件的 `notes` 字段有说明。

## 怎样重新生成

生成脚本是 `tools/maps/build_maps.py`（与 `docs/cards/world/geo/build_maps.py` 同一份，只用 python3，预览图要 Pillow）。先把上面列出的 Natural Earth GeoJSON 下载到一个单独的目录（文件名形如 `ne_50m_land.geojson`），再运行：

```
python3 -I tools/maps/build_maps.py <GeoJSON 所在目录> <输出目录>
```

脚本会在输出目录写出 `europe.json`、`world.json`、`med.json`、`gazetteer.json` 和三张 `preview_*.png`。只把三张底图拷回本目录；`gazetteer.json`（地名表）和预览图留在 `docs/cards/world/geo/`，供内容包离线排地图节点用。

## 本目录的文件

由 A0 从 `docs/cards/world/geo/` 原样拷入（逐字节相同）。之后的唯一写手是 A（WORLD_MAP_DESIGN §15.5）。
