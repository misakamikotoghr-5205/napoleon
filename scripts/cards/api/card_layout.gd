# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen 1280x720 screen layout, contract 7.11.2 (1.3).
# S_* rectangles and prop positions use the 320x180 scene grid; screen = x4.
# Dialog height and hand animation remain the owner's responsibility.
class_name CardLayout
extends RefCounted

const SCALE := 4
const SCREEN := Rect2(0, 0, 1280, 720)
const S_WALL := Rect2i(0, 0, 320, 100)
const S_DOOR := Rect2i(112, 8, 96, 92)
const S_COUNTER := Rect2i(0, 100, 320, 50)
const S_UNDER := Rect2i(0, 150, 320, 30)
const S_ITEMS := Rect2i(116, 104, 88, 42)
const S_SHADOW := Rect2i(116, 30, 12, 70)
const S_SIGN := Rect2i(212, 14, 26, 34)
const S_DOOR_FLAG := Rect2i(96, 14, 12, 40)
const WALL := Rect2(0, 0, 1280, 400)
const DOOR := Rect2(448, 32, 384, 368)
const COUNTER := Rect2(0, 400, 1280, 200)
const UNDER := Rect2(0, 600, 1280, 120)
const ITEMS := Rect2(464, 416, 352, 168)
const SHADOW := Rect2(464, 120, 48, 280)
const SIGN := Rect2(848, 56, 104, 136)
const DOOR_FLAG := Rect2(384, 56, 48, 160)
const S_CURIO := Rect2i(237, 60, 52, 38)
const CURIO := Rect2(948, 240, 208, 152)
const CURIO_CELL := Vector2(64, 64)

const S_SPOTS := {
	&"customer": Rect2i(136, 36, 48, 64),
	&"companion": Rect2i(236, 36, 48, 64),
	&"door": Rect2i(144, 36, 32, 64),
	&"door_l": Rect2i(128, 36, 32, 64),
	&"door_r": Rect2i(160, 36, 32, 64),
	&"street": Rect2i(116, 66, 16, 32),
}
const S_STREET_END := Vector2i(192, 66)
const S_PROP_SPOTS := {
	&"counter_left": Vector2i(128, 138),
	&"counter_mid": Vector2i(160, 138),
	&"counter_right": Vector2i(192, 138),
	&"door_side": Vector2i(186, 100),
	&"door_notice": Vector2i(160, 66),
	&"wall_right": Vector2i(226, 84),
}
const S_HOTSPOTS := {
	&"magnifier": Rect2i(8, 106, 30, 20),
	&"abacus": Rect2i(42, 104, 52, 22),
	&"cashbox": Rect2i(6, 124, 48, 26),
	&"ledger": Rect2i(222, 106, 40, 26),
	&"notebook": Rect2i(268, 106, 40, 26),
	&"calendar": Rect2i(250, 14, 24, 34),
	&"notice": Rect2i(84, 56, 24, 32),
	&"notewall": Rect2i(214, 54, 18, 26),
	&"lamp": Rect2i(292, 68, 20, 32),
	&"curio": Rect2i(237, 60, 52, 38),
}
const HOTSPOTS := {
	&"magnifier": Rect2(32, 424, 120, 80),
	&"abacus": Rect2(168, 416, 208, 88),
	&"cashbox": Rect2(24, 496, 192, 104),
	&"ledger": Rect2(888, 424, 160, 104),
	&"notebook": Rect2(1072, 424, 160, 104),
	&"calendar": Rect2(1000, 56, 96, 136),
	&"notice": Rect2(336, 224, 96, 128),
	&"notewall": Rect2(856, 216, 72, 104),
	&"lamp": Rect2(1168, 272, 80, 128),
	&"curio": Rect2(948, 240, 208, 152),
}

# Bounds for the standard four-slot row and maximum fourteen-coin row.
const S_SLOTS := Rect2i(71, 102, 178, 30)
const S_COINS := Rect2i(63, 133, 194, 12)
const SLOTS := Rect2(284, 408, 712, 120)
const COINS := Rect2(252, 532, 776, 48)
const SLOT_SIZE := Vector2i(40, 30)
const SLOT_SMALL_WIDTH := 30
const SLOT_GAP := 6
const COIN_SIZE := Vector2i(12, 12)
const COIN_GAP := 2
const COIN_MAX := 14

const HUD := Rect2(0, 0, 1280, 30)
const HUD_DATE := Rect2(12, 3, 300, 24)
const HUD_WEATHER := Rect2(316, 3, 100, 24)
const HUD_ALMANAC := Rect2(420, 3, 260, 24)
const HUD_STATUS := Rect2(684, 3, 200, 24)
const HUD_MONEY := Rect2(888, 3, 120, 24)
const HUD_REP := Rect2(1012, 3, 124, 24)
const HUD_HEAT := Rect2(1140, 3, 128, 24)
# The dialog bottom stops at the FAN band top (y 520) so it never covers the fan or HERO.
const DIALOG := Rect2(52, 38, 380, 482)
const DIALOG_MIN_HEIGHT := 180
const DIALOG_MAX_BOTTOM := 520
const DIALOG_CHECKS_BOTTOM := 404
const FAN := Rect2(372, 520, 636, 200)
const PREVIEW_CARD := Rect2(496, 112, 288, 400)
# Reskin 10-22 (creative lead: follow the web prototype): the preview buttons sit right of the zoomed card and
# end above y 424, so neither they nor the preview tray cover the ledger hotspot (888, 424) (audit b42).
const PREVIEW_BTNS := Rect2(800, 272, 148, 140)
const HERO := Rect2(12, 566, 108, 144)
const CONTACT_MINIS: Array[Rect2] = [Rect2(128, 610, 72, 100),
	Rect2(206, 610, 72, 100), Rect2(284, 610, 72, 100)]
const PET := Rect2(128, 566, 220, 40)
const TABS_L: Array[Rect2] = [Rect2(0, 100, 44, 78), Rect2(0, 184, 44, 78),
	Rect2(0, 268, 44, 78), Rect2(0, 352, 44, 78)]
const TABS_R: Array[Rect2] = [Rect2(1236, 100, 44, 78), Rect2(1236, 184, 44, 78),
	Rect2(1236, 268, 44, 78), Rect2(1236, 352, 44, 78)]
const DRAWER_L := Rect2(0, 30, 400, 690)
const DRAWER_R := Rect2(860, 30, 420, 690)
const END_DAY := Rect2(1020, 556, 210, 92)
const STREET_REDEEM := Rect2(1020, 452, 210, 92)
const OVERLAY_MAX := Rect2(90, 40, 1100, 640)
const GUIDE_SAY := Rect2(452, 36, 480, 104)
const GUIDE_SAY_LOW := Rect2(16, 588, 520, 116)
const GUIDE_TEACHER := Rect2(944, 144, 192, 256)


static func screen(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * SCALE, Vector2(r.size) * SCALE)


static func spot(name: StringName) -> Rect2:
	return screen(S_SPOTS.get(name, Rect2i()))


# Props are positioned by their bottom-center point, not their top-left corner.
static func prop_rect(at: StringName, base: Vector2i) -> Rect2:
	if not S_PROP_SPOTS.has(at) or base.x <= 0 or base.y <= 0:
		return Rect2()
	var point: Vector2 = Vector2(S_PROP_SPOTS[at])
	var origin := point - Vector2(float(base.x) * 0.5, base.y)
	return Rect2(origin * SCALE, Vector2(base) * SCALE)


static func slot_rect(i: int, n: int) -> Rect2:
	if n <= 0 or i < 0 or i >= n:
		return Rect2()
	var width: int = SLOT_SIZE.x if n <= 4 else SLOT_SMALL_WIDTH
	var row_width := n * width + (n - 1) * SLOT_GAP
	var left := 160.0 - float(row_width) * 0.5
	return Rect2((left + i * (width + SLOT_GAP)) * SCALE, S_SLOTS.position.y * SCALE,
		width * SCALE, SLOT_SIZE.y * SCALE)


static func coin_rect(i: int, n: int) -> Rect2:
	var count := mini(n, COIN_MAX)
	if count <= 0 or i < 0 or i >= count:
		return Rect2()
	var row_width := count * COIN_SIZE.x + (count - 1) * COIN_GAP
	var left := 160.0 - float(row_width) * 0.5
	return Rect2((left + i * (COIN_SIZE.x + COIN_GAP)) * SCALE, S_COINS.position.y * SCALE,
		COIN_SIZE.x * SCALE, COIN_SIZE.y * SCALE)


## Rogue v1: the i-th curio shelf cell (0..5, row-major, 3 x 2), screen coordinates; 64 x 64 each.
static func curio_cell(i: int) -> Rect2:
	if i < 0 or i >= 6:
		return Rect2()
	return Rect2(CURIO.position + Vector2(8.0 + float(i % 3) * 64.0, 12.0 + float(i / 3) * 64.0), CURIO_CELL)
