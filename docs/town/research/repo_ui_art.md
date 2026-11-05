# 德厚当: UI, scenes, art pipeline, fonts and screenshots

Repo: `/home/user/dehoudang`, Godot 4.7, GL Compatibility renderer. I changed nothing in the repo. All experiments ran from the scratchpad folder `.../scratchpad/understand/`.

---

## 0. Summary

- **One scene, no `.tscn` content.** `scenes/Main.tscn` is a single `Control` with `scripts/ui/main.gd` attached. All other UI is built in code. Panels are `PanelContainer` subclasses, and their styles come from the `UiStyle` factory in `scripts/ui/style.gd`.
- **Pixel world view:** `counter_view.gd` draws everything with `_draw()` at **320×180** and is scaled **×4** to fill 1280×720 (`main.gd` `VIEW_SCALE := 4`). `data/layout.json` still says `"scale": 3`, which is out of date and unused.
- **Text is not pixel text.** All Chinese text is vector *Noto Serif SC* (subset) drawn at 1280×720 on top of the ×4 pixel art. Titles and names use *Ma Shan Zheng* calligraphy.
- **Art is generated procedurally in Python** with PIL and `tools/art/pixlib.py`. A locked **32-colour palette** (`data/palette.json`) is enforced by an `assert` in `Canvas.save()`. Asset sizes:

  | Asset | Size (px) |
  |---|---|
  | Portraits | 48×64 |
  | Item close-ups | 64×64 |
  | Backgrounds | 320×180 |
  | Tools | sized to their hotspot rect |
  | Chess pieces | 14×14 |
  | Ticket | 96×128 |
  | Stamp | 24×24 |

- **Town fits the same scale.** 16×16 tiles and 16×32 characters work at 320×180 ×4, the same scale Stardew Valley uses. I built a palette-legal proof of concept in `scratchpad/understand/town_poc/` (`town_mock_x4.png`, `walker_sheet_x6.png`).
- **Fonts:** the body subset already contains all of GB2312 (7552 glyphs), so most new simplified Chinese needs no font rebuild. `tools/build_fonts.py` **cannot run in this container**: `fontTools`/`pyftsubset` are missing and the source fonts are missing. It also writes into the repo.
- **Screenshots work with Xvfb, not with `--headless`.** Xvfb gives llvmpipe OpenGL 4.5, and both 2D and 3D render. The exact command is in §4.

---

## 1. UI architecture

### 1.1 Project and scene
- `project.godot` settings:
  - main scene `res://scenes/Main.tscn`
  - viewport 1280×720, `stretch/mode="canvas_items"`, `aspect="keep"`
  - `gui/theme/default_font_size=18`
  - renderer `gl_compatibility`, clear colour `#141009`-ish
- **No autoloads.** `DB` (`scripts/core/db.gd`, `class_name DB`, static `DB.get_db()`, `DB.tex(path)`) and `UiStyle` (`class_name`) are global classes.
- **No default texture filter is set**, so the project default is linear. Every pixel node sets `texture_filter = NEAREST` itself (`counter_view`, the inspect close-up, and every `TextureRect`). Any new `Sprite2D`, `TileMapLayer` or `AnimatedSprite2D` must do the same. The alternative is to set `rendering/textures/canvas_textures/default_texture_filter=0` once.
- `scenes/Main.tscn` holds only the root `Control` (full rect) with `script = res://scripts/ui/main.gd`. Nothing else is authored in `.tscn` files.

### 1.2 `scripts/ui/main.gd` (1292 lines, the god-object)
Header: "route beats from Director to panels; route player input back."

| Area | Functions | Notes |
|---|---|---|
| Boot | `_ready`, `_build` (L83–225) | Parses `--key=value` user args (`--autoplay --delay --shots --until --quit --seed --skip-title`). Builds a Theme with `UiStyle.body_font()` at size 18. `_build` creates every node in code: background ColorRect, `scene_holder` (clip, 1280×720) → `CounterView` scaled 4×, desk-edge strip plus `bottom_hint`, `Sidebar` (hidden by default, pos 900,16, 360×688), `cash_chip` button (钱匣 · N 蚨), `DialogueBox`, `overlay` Control → `InspectPanel` / `BookPanel` / `TicketPanel` / `TelegraphPanel` / `generic_panel` (paper PanelContainer reused for summary, night, calendar, ending, "sell one"), `toast_lbl`, `hover_lbl`, `stow_hint`, `caption_layer` (full-screen black + title-font caption), `Beeper`. Absolute positions are set with `_place(c, Rect2)`. |
| Title | `_show_title`, `_begin`, `start_game(seed)`, `_begin_demo` | Creates `Director` (core), wires `director.beat → _on_beat` and `world.changed → sidebar.refresh`. |
| Beat routing | `_on_beat(b)` (L473) | Large `match` on `b.type`: `caption say narr choice door_flag pick_item tutorial practice counter ticket stow ledger summary night telegraph chess ending`. Beats with `nowait` (`scene`, `sfx`) only update the view or play sound. Unknown types raise `push_error`. |
| Responding | `_respond(r)` → `director.submit(r)` | Clears highlight, options and actions, and hides the panel tied to that beat type. `_respond_if(type, r)` is used for panel signals. |
| Dialogue placement | `_place_dialogue(who, is_narr)` | Bubble positions are hard-coded: NPC (24,160), player (720,360), narration (420,500), all 440×~160. `dialogue.set_side("npc"\|"player"\|"narr")`. |
| Counter (bargain) | `_open_counter(b)` | Puts session items on the counter, `sidebar.open_session(...)`, shows the sidebar, and adds bubble action buttons (extras/deals plus local `_inspect_again`, `_sell_one`, `_open_ledger`). |
| Hotspots | `_on_hotspot(id)`, `_on_item_clicked`, `_on_item_dropped`, `_on_piece`, `_on_hover_text`, `_on_scene_click` | Hotspot ids come from `layout.json`. Flavour clicks show a `_toast(text)` (2.2 s fade). |
| Hints | `_glow_tip(hotspot_id, text)` | Label beside the hotspot. Fades after 1.6 s, plus 0.7 s fade-out (owner item #4). |
| Calendar | `_open_calendar()` | 万年历: date, price board, todos with due dates. The global todo HUD was removed (owner item #3). |
| Day/night panels | `_open_summary`, `_open_night`, `_open_ending`, `_show_end_card`, `_pick_single_sell` | All built into `generic_box` at runtime. |
| Sidebar toggling | `_show_sidebar`, `_hide_sidebar(force)`, `_toggle_sidebar_panel`, `_on_sidebar_closed`, `_refresh_cash_chip` | |
| Input | `_unhandled_input` | Number keys 1–9 pick options. Space/Enter advances. Esc closes the book or inspect panel, otherwise skips the line. |
| Test/autoplay | `auto_apply(b, r)` (L1035–1133) | Autoplayer drives the UI through real buttons and signals. Modes: `auto_say_mode` = `click`/`esc`/`scene`/`skip`. |
| Screenshots | `_init_shot_plan`, `_maybe_shot`, `_capture(key)`, `take_title_shot` | Trigger key → file name map. `_capture` awaits `RenderingServer.frame_post_draw`, then `get_viewport().get_texture().get_image().save_png(dir/file)`. `--shots=` may be an absolute path, which lets you write outside the repo. |

**Tests depend on these `main.gd` members:** `autostart`, `start_game`, `sidebar`, `cash_chip`, `scene_holder`, `bottom_hint`, `desk_edge`, `_show_sidebar`, `_hide_sidebar`, `_set_bottom_hint`, `_clear_bottom_hint`, `auto_apply`, `auto_say_mode`, `autoplayer`. They are used in `test_v03.gd`, `test_dialogue.gd`, `autoplayer.gd` and `run_playthrough.gd`.

`run_tests.sh` fails on any `WARNING:` line. Even "Nodes with non-equal opposite anchors…" counts; `shot_v03b.gd` triggers it, but that script is not in the suite. New UI code must therefore not emit warnings.

### 1.3 `dialogue_box.gd` (272 lines, `extends PanelContainer`): side bubbles and typewriter
- Signals: `advanced`, `option_picked(id)`, `action_picked(kind, id)`, `skipped`.
- Structure: top row with `name_lbl` (title font 20, outlined), `hint_lbl` (▼ / … / "选（1–n）") and `skip_btn` (跳过 ▶). Below that: `text_lbl` (RichTextLabel, bbcode, size 17), `options_box` and `actions_box` (button rows, 1–3 per row).
- `set_side(side, who)` only changes the border colour: npc `#c99a5e`, player `#e8c88a`, narration `#7b8a7b`. There is no tail or arrow pointing at the speaker. Position is set by `main._place_dialogue`.
- **Typewriter:**
  - `show_line(name, text, color, is_narr, click_to_continue, voice)` sets `visible_characters = 0`.
  - `_process` advances `shown_chars` at `cps = 45` and calls `beeper.beep(pitch)` every 2 characters. `pitch` is `cast.json[who].voice_pitch`; the player is 1.1 and narration 0.8.
  - `click()` first completes the line, then advances, with a 180 ms guard (`CLICK_GUARD_MS`) against double-clicks.
  - `skip()` completes the line and advances at once.
  - `instant = true` is used by the autoplayer.
- Other API: `show_options(prompt, text, opts)`, `option_button(id)`, `show_actions(acts)`, `action_button(kind,id)`, `clear_options/actions`, `finish_typing`, `is_typing`, `set_hint`.

### 1.4 `beeper.gd` (82 lines, `extends Node`): all sound is synthesised
- An `AudioStreamGenerator` at 22050 Hz pushes frames by hand. No audio files.
- `beep(pitch)` is a 520·pitch Hz square wave for 35 ms (the Dave-the-Diver-style blip).
- Other sounds: `click()` (1400 Hz, 12 ms), `morse(n)`, and `play(name)` with `door_open/door_close/stamp/boots` (low-pass noise thud), `coins` (three sine pings) and `page`.
- Disabled automatically when `DisplayServer` is headless or the audio driver is Dummy.

### 1.5 `counter_view.gd` (358 lines, `extends Control`): the only "world" renderer
- Size 320×180, `texture_filter NEAREST`, redrawn every frame (`_process` → `queue_redraw`).
- Signals: `hotspot_clicked(id)`, `item_clicked(iid)`, `piece_clicked(key)`, `hover_text(text, global_pos)`, `empty_clicked`, `item_dropped(iid, hotspot_id)`.
- State: `bg` (`dark`/`day`/`dusk`/`night`/`candle`), `customer` (portrait id), `brother`, `lamp`, `highlight[]`, `counter_items[]`, `selected_item`, `pieces[]`.
- `set_scene(b)` slides a new customer's portrait in from 18 px below.
- `_draw()` order:
  1. background PNG
  2. door flag and sign
  3. suspicion "shadow" at the door
  4. `_draw_people` (customer at `layout.customer` = 136,36 48×64; brother at `brother_spot`)
  5. tools at hotspot rects (`art/tools/<id>.png`)
  6. counter items (28 or 36 px squares, centred in the `counter_item` rect)
  7. chess pieces
  8. tutorial highlight (gold/red frame plus bouncing ▼)
  9. hover frame
  10. dragged item
  11. night shade
- Hit-testing: `_hit(pos)` checks pieces, then items, then drop targets/hotspots, then customer. Drag starts after 3 px.
- Hotspot rectangles live in `data/layout.json`, in 320×180 coordinates.

### 1.6 `inspect_panel.gd` (247 lines): magnifier and appraisal
- Paper panel. Left side: tabs for multi-item sessions and a 300×300 close-up control that draws the 64×64 item sprite at about 4.7× plus part rectangles (`item.parts[].rect` in 64-px coordinates). Right side: name, category/weight, part buttons with tool prefixes 【镜/秤/册/手/闻】, findings RichText (tells in seal red), checkboxes ("这件也算进去", "我看这是假货"), a medbook link, and close (放下（回柜台看货）).
- Signals: `closed`, `inspected(iid, pid)`, `done_practice`.
- `do_inspect(pid)` → `session.inspect()` → findings are logged.
- `_highlighted(p)` auto-highlights a part when `world.flags[highlight_if]` is set.

### 1.7 `sidebar.gd` (472 lines): cash box, reputation and abacus
- Hidden by default, toggled from `cash_chip`.
- Info mode: date (click opens the calendar), cash, 口碑 progress bar, payment countdown, door flag and sign, price board, and visible relationships (熟/平/冷 plus roles).
- Bargain mode (`open_session`): NPC and mode, ask price, brother's hint, abacus, oral quote, quote tutorial button, then 出价 / 照他的价 / 资助 / 不收了.
  - The abacus has 4 rods: heaven bead button ±5, earth ± buttons, and a text bead display. `set_value(v)` updates beads and the oral quote.
  - `_oral_quote()` converts a number to spoken Chinese, e.g. "三百零五蚨".
  - The abacus is Button-and-label based, not a pixel abacus (owner item #6 is only partly done).
- Signals: `offer(value)`, `extra(id)`, `deal(id)`, `refuse`, `open_inspect`, `closed`.

### 1.8 Other panels
- **`book_panel.gd` (255 lines):** paper panel with indigo border. `open(kind, world)` takes `ledger` (tabs 钱匣/活当/借据/待办/库存), `notebook` (档案簿: messages tagged 亲眼/听说/推测, knowledge pages, people) or `medbook` (paged 鉴别录). Everything is RichText; there are no pixel assets. Signal `closed`.
- **`ticket_panel.gd` (171 lines):** the 当票 workflow. Left: `ticket_blank.png` (96×128) scaled to 288×384 (×3) with ink drawn over it in `_draw_paper`, and an animated `stamp.png`. Right: rows, condition choice (如实写 / 照老规矩写), 盖章 and 交钱收物 buttons. Signal `finished(condition)`.
- **`telegraph_panel.gd` (171 lines):** the incoming message is 4-digit code groups decoded with the codebook; you reply by picking up to 4 code words and pressing send. Signals `sent(words)`, `skipped`, `done`.

### 1.9 `style.gd` (`class_name UiStyle`, 132 lines)
- Colour constants: `WOOD_DARK #1f1712`, `WOOD #3a2a1e`, `WOOD_MID #5a3f2a`, `PAPER #f4e2b0`, `PAPER_OLD #d9c49a`, `INK`, `INK_SOFT`, `LAMP #ffd25a`, `LAMP_PALE #e8c88a`, `SEAL #b0262a`, `INDIGO #2f4670`, `MIST #9aa4aa`, `GOOD #4a6a3a`. All are palette colours.
- Fonts: `title_font()` is a FontVariation of MaShanZheng with NotoSerif as fallback. `body_font()` is NotoSerif.
- Factories: `box(bg, border, bw, radius, pad)` returns a StyleBoxFlat. Also `paper_panel()`, `wood_panel()`, `label(text,size,color,wrap)`, `title_label`, `button(text,size,kind="paper"|"seal"|"wood",wrap)`, `hsep`, `scroll`, `vbox`, `hbox`, `cn_money(n)` (大写数字).
- **Reuse this for the town UI.** The panels are flat `StyleBoxFlat` rectangles with 2–6 px borders, not pixel-art 9-slices. A Stardew-like pixel dialogue frame would be a new 9-slice PNG (`StyleBoxTexture`, NEAREST), e.g. a 24×24 source with 8 px margins drawn ×3 or ×4.

### 1.10 Implications for the town redesign
- `counter_view.gd` is hard-wired to one counter layout (`layout.json` hotspots). The town needs new nodes: a `TownView` and a per-shop `ShopView`.
  - **Option A (recommended):** a `SubViewport` 320×180 holding `TileMapLayer`s, y-sorted `Node2D`, `CharacterBody2D` and `Camera2D`, shown through a ×4 `TextureRect`/`SubViewportContainer` (stretch_shrink 4). This keeps pixel-perfect scrolling.
  - **Option B:** a `Node2D` with `scale = 4` and a pixel-snapped camera.
- **Entering a shop** can reuse the counter model: 320×180 front view, a 48×64 portrait behind a counter, and the `DialogueBox` bubble. This uses existing assets and matches the owner's "enter a shop → pixel dialogue" idea. Option A costs little.
- **The "2.5D" depth look** is cheapest as 2D y-sort with 3/4-view building fronts, as in Stardew; trees and roofs occlude the player. A true 3D HD-2D look (`Sprite3D` billboards plus a 3D camera) also renders in this container (§4) but costs far more.
- **`main.gd` should be split** before adding a town: a mode or state machine (town / shop interior / counter / night), with `_on_beat` routing per mode.

---

## 2. Art pipeline

### 2.1 Files and conventions
- Generators live in `tools/art/`:

  | Generator | Lines | Writes |
  |---|---|---|
  | `gen_backgrounds.py` | 505 | `art/bg/counter_{day,dusk,night}.png`, `candle.png`, `title.png`, all 320×180 opaque |
  | `gen_tools.py` | 460 | `art/tools/*.png`, each sized exactly to its `layout.json` hotspot rect (asserted), plus `piece_*` 14×14 and `candle` 8×16 |
  | `gen_items_basic.py` / `gen_items_medicine.py` / `gen_items_valuables.py` | | `art/items/*.png`, 64×64 |
  | `gen_portraits_a.py` / `gen_portraits_b.py` / `gen_portrait_guanjia.py` | | `art/portraits/*.png`, 48×64 |
  | (ui) | | `art/ui/ticket_blank.png` 96×128, `stamp.png` 24×24 |

- Run from the project root: `python3 tools/art/gen_xxx.py`. Every generator is deterministic. Noise comes from a hash, `hz(x,y,s) = frac(sin(x*127.1+y*311.7+s*74.7)*43758.5453)`, not from `random`.
- Each generator also writes a contact sheet to `art/_preview/<group>.png` via `pixlib.preview()` (×2–×4). That folder has a `.gdignore`, so Godot skips it, and `package.sh` excludes it.
- **Python dependencies:** only Pillow (installed: **PIL 12.3.0**; numpy 2.5.3 is also present but unused). Generators import `pixlib` by inserting their own directory into `sys.path`.

### 2.2 `pixlib.py` API (200 lines)
- `P`: palette object built from `data/palette.json`. Colours are reached as `P.<name>` or `P[i]`, as RGBA tuples. `CLEAR = (0,0,0,0)`. `ALLOWED` = palette ∪ {CLEAR}.
- `Canvas(w, h, fill=CLEAR)` wraps `self.img` (PIL RGBA) and `self.px`. Methods:
  - primitives: `pixel`, `get`, `rect(x,y,w,h,col)`, `frame` (1 px outline rect), `hline`, `vline`, `line` (Bresenham), `ellipse(cx,cy,rx,ry,col,filled)`, `poly(pts,col)` (scanline fill)
  - shading: `dither(x,y,w,h,a,b,level)` (Bayer 4×4), `vgradient(x,y,w,h,cols)`
  - composition: `outline(col=P.dkbrown)` (1 px silhouette outline), `blit(other,x,y)`, `mirror_x()`
  - output: `check_palette()`, `save(rel_path)`
- **`save()` asserts every opaque pixel is a palette colour and writes to `ROOT/rel_path`, i.e. into the repo.** In experiments outside the repo, call `c.check_palette()` and `c.img.save(abs)` instead, as the proof of concept does.
- `load_layout()` reads `data/layout.json`. `preview(paths, out_rel, scale)` builds contact sheets.
- Shading idioms in the generators:
  - `gen_backgrounds.ramp_px(c,x,y,ramp,v)` picks a colour on a dark→light ramp with Bayer dithering between steps.
  - There are per-material ramps for day, dusk and night (`MATS`).
  - Portrait `robe()` shades the left side `lo` and the right side `hi` (lamp from the upper right). `head()` uses an elliptical skin ramp.
  - `house()` draws 白墙黛瓦 houses, already used in `title.png`.

### 2.3 Palette (`data/palette.json`)
32 colours, each with a name:

`black dkbrown wood0-3 tan lamp_pale paper_hi paper paper_old lamp flame wall0-2 mist fog indigo0-2 seal_red dkred skin_hi skin skin_lo hair gray silver white gold moss`

- The palette is warm browns, grey-blue stone, indigo, paper and skin. **There is only one green (`moss #4a6a3a`)** and no bright sky blue or water cyan.
- The palette fits a 1938 Jiangnan water town well: white walls, dark roof tiles, flagstone, canals. It also keeps the game visually distinct from Stardew's saturated greens.
- To add colours, append to both the `"colors"` and `"names"` arrays. Nothing else depends on the count: `db.gd` loads `palette` but never uses it, and existing assets stay valid.
- Suggested additions for a town: 3–4 greens (`#2e4a2a`, `#6e8a4a`, `#9aa86a`), one water or sky tint, and possibly a brick red.

### 2.4 Godot import (`.import` files)
- Every PNG has a committed `*.png.import` beside it:
  - `importer="texture"`, `CompressedTexture2D`, `compress/mode=0` (lossless), `mipmaps/generate=false`, `process/fix_alpha_border=true`
  - a `uid://…`
  - the cache path `.godot/imported/...ctex`
- New PNGs get their `.import` files when Godot imports: `godot --headless --import`, the editor, or the first line of `tools/run_tests.sh`. Nothing needs to be written by hand. Commit the generated `.import` files, as the repo does now.
- `.godot/` is gitignored. New `.gd` scripts also get `.gd.uid` sidecars, which are committed.
- **Filtering is not an import setting here.** Nearest filtering is set per node at runtime (§1.1).
- Textures are loaded with `DB.tex("art/…png")` → `load("res://…")`. They are not preloaded.

### 2.5 Native resolutions and scale (measured)

| Asset | Native px | On screen | Colours used |
|---|---|---|---|
| Counter background | 320×180 | ×4 → 1280×720 | 17 |
| Title background | 320×180 | ×4 (TextureRect stretch) | 12 |
| Portrait (`li.png`) | 48×64 | ×4 on the counter (192×256 px) | 16 |
| Item (`coin.png`) | 64×64 | 28–36 px on the counter (×4 → 112–144), 300 px in inspect | 6 |
| Tools | hotspot rect, e.g. abacus 52×22 | ×4 | ~7 |
| Ticket / stamp | 96×128 / 24×24 | ×3 (288×384) / 72×72 | 5 / 3 |

Visual identity:
- 1 px dark outline (`dkbrown` or `black`)
- light from the upper right
- heavy Bayer-dither texture on walls, wood and street
- chunky low-detail faces: 2×2 eyes, 3 px mouth
- warm lamp tones

UI text sits over the pixel art in smooth serif at native 1280×720. See `screenshots/v03b_panel_open.png` and `m5_fix_typewriter.png`.

### 2.6 Recommended sizes for the town (same ×4 scale, Stardew conventions)
- **Viewport:** 320×180 logical (20×11.25 tiles of 16 px) at ×4 = 1280×720, the same scale as the counter. Stardew is also effectively 16-px tiles at ×4.
- **Ground and road tiles: 16×16.** Pack them into an atlas (e.g. 256×256 = 16×16 tiles) for a `TileSet` with `tile_size = 16×16`. Suggested set:
  - flagstone 石板路 (2–4 variants)
  - packed earth
  - canal water (3–4 animation frames)
  - stone canal edge and bridge pieces
  - grass (needs the extra greens)
  - wall bases
- **Buildings: whole sprites, not tiles.** Use 3/4 front view, 64–96 px wide × 64–80 px tall (4–6 tiles by 4–5).
  - Door is 16×24 at bottom centre, and the door tile is the entrance trigger.
  - The signboard is about 20×9 px. At 9 px a rendered glyph is barely legible, so use a 16×16 board with a 12–14 px glyph, or draw the shop name as an engine `Label` above the door.
  - Draw the roof as a separate sprite (or a y-sorted top half) so the player can walk behind it.
- **Trees: 32×48** (willow, 2×3 tiles), 1-tile trunk footprint, y-sorted.
- **Walking characters: 16×32 frames, 4 directions × 4 frames.**
  - Frames: neutral, step-left, neutral, step-right with a 1 px bob.
  - Sheet is 64×128: rows down, left, right, up. Left is `mirror_x()` of right.
  - In Godot, use `Sprite2D` with `hframes=4, vframes=4` or `AnimatedSprite2D` with `SpriteFrames`.
  - Townsfolk variety comes from palette-swapping the robe ramp (indigo / wood / wall / mist, as `robe()` does in the portraits) plus hair and hat variants chosen by a seeded `random.Random(seed)`. The same seed can come from the GameJev world generator, so NPCs are reproducible.
- **Portraits for dialogue:** keep 48×64 and show them ×3 or ×4 in the shop or dialogue frame. Every existing NPC portrait is reused. The protagonist (`you`, 沈如花) has **no portrait or sprite yet** and needs both.
- **Shop interiors:** either
  - (a) a 320×180 front view per shop, generated like `gen_backgrounds.scene(mode)` (wall, door or window, counter, shelf props) with the shopkeeper portrait at the counter. This is the cheapest option and continues the current look. Or
  - (b) top-down 16-px interior tiles. This is far more work.

  Recommend (a) for every shop except the pawnshop, which can keep its counter view.
- **Rendering signboard glyphs into pixel art works.** PIL can rasterise the repo's own subset font at pixel sizes with no anti-aliasing (`ImageFont.truetype('fonts/NotoSerifSC-Regular-subset.otf', 12)`, `draw.fontmode='1'`), then map the result to a palette colour. I tested this at 12 px for 当警局 and at 9 px in the proof of concept.

### 2.7 Proof of concept (scratch only)
`scratchpad/understand/town_poc/gen_town_poc.py` imports the repo's `pixlib` read-only and writes into the scratch folder. It produces:
- 16×16 flagstone, earth and water tiles
- an 80×64 白墙黛瓦 shop with a 16×24 door, lattice windows and a signboard with a rendered glyph (当 / 警 / 茶)
- a 32×48 willow
- a 16×32 walker sheet, 64×128, 4 directions × 4 frames

All output passes `check_palette()` with only the existing 32 colours. Previews: `town_mock_x4.png` (1280×720) and `walker_sheet_x6.png`.

It reads as a Jiangnan street that matches the existing art. Weak points:
- The ground is too noisy.
- The 9 px glyphs are crude.
- Trees would benefit from 2–3 more greens.

---

## 3. Font pipeline

### 3.1 What ships
| File | Font | Coverage | Size |
|---|---|---|---|
| `fonts/NotoSerifSC-Regular-subset.otf` | Noto Serif CJK SC (body) | **7552 glyphs** = ASCII + CJK punctuation + all **6763 GB2312 hanzi** + every character used in `data/`, `scripts/`, `scenes/` (`.json .gd .tscn .md`) | 4.4 MB |
| `fonts/MaShanZheng-Title-subset.ttf` | Ma Shan Zheng (calligraphy titles) | **1506 glyphs** = ASCII/base + used characters only, no GB2312 | 1.0 MB |

- The title font is used through `UiStyle.title_font()`, a FontVariation with the serif as fallback. A missing calligraphy glyph therefore falls back to serif: you get a style mismatch, not tofu.
- Import settings: `font_data_dynamic`, antialiasing on, `allow_system_fallback=true`.

### 3.2 `tools/build_fonts.py`
- Docstring: "Run from the project root after adding any new Chinese text: `python3 tools/build_fonts.py`".
- It takes no arguments (no `--help`). It **writes straight into the repo's `fonts/`** (`OUT_SERIF` / `OUT_TITLE`), so I did not run it.
- Steps:
  1. Collect character set = base ∪ GB2312 ∪ characters used anywhere under `data/ scripts/ scenes/`.
  2. Run `pyftsubset` on `/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc` (SC face index found by name) and `/usr/share/fonts/truetype/sand-box/google/Ma Shan Zheng/MaShanZheng-Regular.ttf`, with `--layout-features=* --no-hinting --desubroutinize`.
  3. Verify coverage. It **exits 1 if any used character (>0x7F) is missing from the serif output**. Characters missing from the title font are only printed as a note.
- **It cannot run in this container:**
  - `fontTools` is not installed (`ModuleNotFoundError`) and `pyftsubset` is not on PATH. `pip download fonttools` does work through the proxy, so `pip install fonttools` is possible.
  - **Both source font files are missing.** The only system CJK fonts are WenQuanYi Zen Hei (`/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc`) and Unifont.
  - To rebuild, download Noto Serif CJK SC (OTF/TTC) and MaShanZheng-Regular.ttf (Google Fonts, OFL), then either place them at those paths or run a scratch copy of the script with the paths patched.

### 3.3 When new Chinese text is added
1. **Simplified text inside GB2312 needs nothing.** It is already in the body subset. I checked 当铺警察局镇长茶馆米行药铺邮局钱庄裁缝铺铁匠铺巡捕房鉴定证书珠算盘盒铸蚨: all present.
2. **Characters outside GB2312 need a rebuild with `python3 tools/build_fonts.py`.** That means traditional forms (謎繼續萬曆鐵礦), rare characters such as 镕, and supplementary-plane characters.
3. **New title or calligraphy strings** (shop names on signs, chapter cards) are only in Ma Shan Zheng if they were already used. 庄匠捕铸 are missing from it today. Without a rebuild they render in serif via fallback.
4. **What the test catches:** `scripts/tests/validate_data.gd::_glyphs()` (in `run_tests.sh` as "数据校验") loads the serif subset. It checks every character with codepoint ≥ U+2E80 in `data/cast.json, pages.json, factions.json, medbook.json, codebook.json, night.json` plus every `.json` in `data/story/`, `data/sessions/` and `data/items/`.
   - A missing glyph raises `errs.append("正文字体缺字（会显示豆腐块）：… → 运行 python3 tools/build_fonts.py")`, the script exits 1, and **the test fails**.
5. **What the test does not catch:**
   - strings in `.gd` files (all UI labels in `main.gd`, `sidebar.gd` and the rest)
   - new data directories (for example a future `data/town/*.json`) until they are added to `_glyphs()`
   - the title font

   In those cases nothing fails. At runtime Godot uses system fallback (`allow_system_fallback=true`): on Windows or macOS that is usually a system CJK font, so the text appears in the wrong typeface. Without a system CJK font it is tofu.
6. **The container hides tofu in screenshots.** WenQuanYi is installed here, so Godot falls back to it; my probe showed 你好 rendered with no project font. Screenshot checks therefore will not reveal missing glyphs. Rely on `_glyphs()`, and extend it to new data folders.
7. **Practical rule for this container:** keep new text inside GB2312 simplified Chinese and add any new JSON folder to `_glyphs()`. Only install fonttools and download the sources if a non-GB2312 character or a new calligraphy title is truly needed.

---

## 4. Screenshots in this container

### 4.1 Environment
- `DISPLAY` is unset and there is no Wayland.
- `/usr/bin/Xvfb` and `/usr/bin/xvfb-run` are present.
- Mesa 25.2.8 is present with `swrast_dri.so` / `kms_swrast_dri.so` / `zink_dri.so`, libLLVM 17/18/20, libGL, libGLX_mesa, libgbm and the X11, Xcursor, Xinerama, Xrandr, Xi and xkbcommon libraries. ALSA and Pulse libraries are present.
- No Vulkan ICD is installed, so Forward+ and Mobile will not work. Stay on `gl_compatibility`, which is what the project uses.
- 4 CPUs, 15 GB RAM.

### 4.2 `--headless` cannot capture
With `--headless`, `DisplayServer` is `headless` and the renderer is the dummy one:
- `await RenderingServer.frame_post_draw` never returns. My probe hung until a 60 s timeout killed it.
- Without that await, `get_viewport().get_texture().get_image()` errors with `Parameter "t" is null` (`dummy/storage/texture_storage.h:110`) and returns null.

### 4.3 Working method: Xvfb + OpenGL3 on llvmpipe (verified)
```bash
G=/tmp/claude-0/-home-user-dehoudang/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/godot/Godot_v4.7-stable_linux.x86_64
xvfb-run -a -s "-screen 0 1280x720x24" "$G" --rendering-driver opengl3 --audio-driver Dummy \
  --path <project_dir> -s <script.gd>          # or: -- --autoplay=fair --shots=/ABS/DIR --until=<checkpoint> --quit
```

Godot logs `OpenGL API 4.5 (Core Profile) Mesa 25.2.8 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)`, and `DisplayServer.get_name()` is `X11`. The only warning is a harmless `Could not set V-Sync mode`, which `run_tests.sh` already ignores.

Verified runs:
1. **Trivial probe** (`scratchpad/understand/probe_project/probe.gd`): a ColorRect and Label saved to `scratchpad/understand/probe.png`, 1280×720, correct pixels.
2. **Real game screenshot script on a scratch copy of the repo** (`scratchpad/understand/ui_shotcopy/`, rsync with `.git` excluded):
   `xvfb-run -a -s "-screen 0 1280x720x24" $G --rendering-driver opengl3 --audio-driver Dummy --path …/ui_shotcopy -s res://scripts/tests/shot_v03b.gd`
   This wrote `v03b_clean_counter.png` and `v03b_panel_open.png` in 1.6 s, identical to the committed ones.
3. **Full autoplay with screenshot plan, output outside the repo:**
   `xvfb-run -a -s "-screen 0 1280x720x24" $G --rendering-driver opengl3 --audio-driver Dummy --path …/ui_shotcopy -- --autoplay=fair --shots=/tmp/claude-0/…/scratchpad/understand/shots_test --until=prologue_done --quit`
   This wrote 12 PNGs (title through door flag, including the typewriter mid-line shot) in about 8 s.
   - Checkpoints for `--until`: `prologue_done`, `day1_done`, `night1_done`, `day2_done`, `night2_done`, `ending`.
4. **3D also renders** (`probe3d.gd`: BoxMesh, `Sprite3D` billboard with NEAREST pixel texture, DirectionalLight3D) at roughly 3.5 ms per frame on llvmpipe. A 2.5D/HD-2D prototype is therefore testable here too.

### 4.4 Notes
- **Running against the repo itself modifies it.** Using `--path /home/user/dehoudang`:
  - touches `.godot/` (gitignored)
  - `shot_v03b.gd` writes into `res://screenshots/` (tracked files)
  - `main.gd --shots=<relative>` also resolves under `res://`

  To leave the repo untouched, run against a scratch copy, or pass an absolute `--shots=` directory and accept the `.godot/` cache changes.
- The README's documented method is `DISPLAY=:5 godot --path . --resolution 1280x720 -- --autoplay=fair --delay=0.05 --shots=screenshots --quit`. It assumed a persistent X server on `:5`; `xvfb-run -a` replaces that here.
- For a custom capture inside a `SceneTree` script, copy `shot_v03b.gd::_snap`: two `await process_frame`, then `await RenderingServer.frame_post_draw`, then `root.get_viewport().get_texture().get_image().save_png(path)`.
- `beeper.gd` disables itself under the Dummy audio driver, so no audio device is needed.
