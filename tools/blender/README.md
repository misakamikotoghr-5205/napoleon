# tools/blender

Blender 3D -> pixel-art pipeline for the card game's backgrounds and card illustrations.
Full guide (Chinese), including the rules on model sources and AI use: `docs/cards/art/blender/BLENDER_PIPELINE.md`.
Requires Blender 4.0.x or 4.1.x (4.2+ / EEVEE Next does not reproduce the samples and is refused by render.py).

```sh
sh tools/blender/fetch_models.sh      # CC0 KayKit packs -> tools/blender/models (git-ignored)
sh tools/blender/make_samples.sh      # every registered scene -> tools/blender/out (git-ignored); exit 1 on any failure
```

| file | what |
|---|---|
| `bl_lib.py` | model loading (glTF/GLB/FBX/OBJ/.blend), material tweaks, cel shading (`toonify`), outlines, render |
| `scenes/` | one module per 3D set; registry in `scenes/__init__.py` |
| `render.py` | CLI: `blender -b --factory-startup -noaudio --python-exit-code 1 --python tools/blender/render.py -- --scene counter --variant day --out x.png`; refuses models/images not from a pack in `MODELS.csv` |
| `list_jobs.py` | lists scene variants for `make_samples.sh` (runs inside Blender) |
| `pix.py` | colour reduction of a render; prints the pixel hash recorded in deliveries |
| `compare.py` | side-by-side with the image the game uses now (owner's final check only) |
| `review_sheet.py` | owner-side review sheet: current game image next to a delivered candidate, per art id |
| `gen_asset_list.py` | regenerates `ASSET_LIST.md` / `PROPS_NEEDED.md` from `docs/cards/art/blender/catalog.json` |

Environment: `KAYKIT_DIR` (default `tools/blender/models`), `MODEL_PATH` (more pack folders, os.pathsep-separated),
`BLENDER` (binary used by `make_samples.sh`).
