class_name OceanRogueData
extends RefCounted
## Static definitions for the Napoleon Roguelike layer:
## - 4 functional coins (gold, supply, medal, intel)
## - 8 Monopoly-style tactical prop cards usable in march & battle
## - 8 trilogy companions + 5 faction/trait bonds + permadeath + protagonist deployment
## - 12-tile Monopoly march board, 3 branching routes, 8 side activities, 6 calendar actions
## - Big Fate crisis choices (the 6x4 tactical grid prototype is gone: battles are battle v2, see below)
## Battle v2 (turn-based rules engine) reuses COMPANIONS / BONDS here: each companion's class, stats and skill
## live in data/campaigns/ocean_battle.json, and the companion's "bonds" double as the engine's faction tags
## (bond_sets.ocean in data/campaigns/battle_templates.json). See scripts/cards/campaign/ocean_battle2.gd.
## Player-visible names and descriptions live in data/campaigns/text/ocean_rogue.json (TEXT_PATH), keyed by table and
## row id; the _TABLES below hold ids and numbers only. COINS, PROPS, BONDS, COMPANIONS, MARCH_BOARD, ROUTES,
## ACTIVITIES, CALENDAR_ACTIONS and BIG_FATES are those rows with their text merged in once at load: same shapes and
## keys as the old constants, and read-only like them. This file has no Chinese literals (WORLD_MAP_DESIGN 12.2 item 7).

const TEXT_PATH := "res://data/campaigns/text/ocean_rogue.json"

const COIN_IDS := ["gold", "supply", "medal", "intel"]

const _COINS := {
	"gold": {"id": "gold"},
	"supply": {"id": "supply"},
	"medal": {"id": "medal"},
	"intel": {"id": "intel"},
}

const PROP_IDS := ["prop_loaded_dice", "prop_barricade", "prop_forced_march", "prop_spyglass", "prop_smoke_bomb", "prop_field_ration", "prop_bribe_pouch", "prop_imperial_decree"]

const _PROPS := {
	"prop_loaded_dice": {"id": "prop_loaded_dice", "gold_cost": 1},
	"prop_barricade": {"id": "prop_barricade", "gold_cost": 1},
	"prop_forced_march": {"id": "prop_forced_march", "gold_cost": 1},
	"prop_spyglass": {"id": "prop_spyglass", "gold_cost": 1},
	"prop_smoke_bomb": {"id": "prop_smoke_bomb", "gold_cost": 2},
	"prop_field_ration": {"id": "prop_field_ration", "gold_cost": 1},
	"prop_bribe_pouch": {"id": "prop_bribe_pouch", "gold_cost": 1},
	"prop_imperial_decree": {"id": "prop_imperial_decree", "gold_cost": 2},
}

const BOND_IDS := ["imperial", "far_sea", "shadow", "scholar", "island"]

const _BONDS := {
	"imperial": {"id": "imperial", "need": 2, "atk_bonus": 8, "hp_bonus": 20, "supply_bonus": 1},
	"far_sea": {"id": "far_sea", "need": 2, "atk_bonus": 6, "hp_bonus": 15, "gold_bonus": 1},
	"shadow": {"id": "shadow", "need": 2, "atk_bonus": 10, "hp_bonus": 10, "intel_bonus": 1},
	"scholar": {"id": "scholar", "need": 2, "atk_bonus": 6, "hp_bonus": 25, "medal_bonus": 1},
	"island": {"id": "island", "need": 2, "atk_bonus": 7, "hp_bonus": 30, "block_bonus": 1},
}

const COMPANION_IDS := ["dantes", "gourgaud", "faria", "friday", "nemo", "morel", "marie", "corso"]

const _COMPANIONS := {
	"dantes": {
		"id": "dantes",
		"place": "ground",
		"cost": 2,
		"gold_cost": 2,
		"atk": 28,
		"max_hp": 100,
		"block": 2,
		"bonds": ["far_sea", "shadow"],
		"starter": true,
	},
	"gourgaud": {
		"id": "gourgaud",
		"place": "ground",
		"cost": 3,
		"gold_cost": 2,
		"atk": 22,
		"max_hp": 140,
		"block": 3,
		"bonds": ["imperial", "island"],
		"starter": true,
	},
	"faria": {
		"id": "faria",
		"place": "high",
		"cost": 2,
		"gold_cost": 2,
		"atk": 22,
		"max_hp": 80,
		"block": 1,
		"bonds": ["scholar", "shadow"],
		"starter": true,
	},
	"friday": {
		"id": "friday",
		"place": "ground",
		"cost": 2,
		"gold_cost": 2,
		"atk": 30,
		"max_hp": 95,
		"block": 2,
		"bonds": ["island", "far_sea"],
		"starter": false,
	},
	"nemo": {
		"id": "nemo",
		"place": "high",
		"cost": 3,
		"gold_cost": 3,
		"atk": 36,
		"max_hp": 92,
		"block": 1,
		"bonds": ["far_sea", "scholar"],
		"starter": false,
	},
	"morel": {
		"id": "morel",
		"place": "high",
		"cost": 2,
		"gold_cost": 2,
		"atk": 29,
		"max_hp": 85,
		"block": 1,
		"bonds": ["far_sea", "imperial"],
		"starter": false,
	},
	"marie": {
		"id": "marie",
		"place": "high",
		"cost": 2,
		"gold_cost": 2,
		"atk": 26,
		"max_hp": 82,
		"block": 1,
		"bonds": ["shadow", "imperial"],
		"starter": false,
	},
	"corso": {
		"id": "corso",
		"place": "ground",
		"cost": 3,
		"gold_cost": 2,
		"atk": 32,
		"max_hp": 120,
		"block": 2,
		"bonds": ["imperial", "scholar"],
		"starter": false,
	},
}

const _MARCH_BOARD := [
	{"index": 0, "id": "camp"},
	{"index": 1, "id": "town"},
	{"index": 2, "id": "recruit"},
	{"index": 3, "id": "salon"},
	{"index": 4, "id": "bazaar"},
	{"index": 5, "id": "duel"},
	{"index": 6, "id": "smuggle"},
	{"index": 7, "id": "shrine"},
	{"index": 8, "id": "gamble"},
	{"index": 9, "id": "festival"},
	{"index": 10, "id": "diplomacy"},
	{"index": 11, "id": "skirmish"},
]

const ROUTE_IDS := ["salon_route", "duel_route", "smuggle_route"]

const _ROUTES := {
	"salon_route": {"id": "salon_route"},
	"duel_route": {"id": "duel_route"},
	"smuggle_route": {"id": "smuggle_route"},
}

const ACTIVITY_IDS := ["salon", "duel", "gamble", "merchant", "rest", "smuggle", "festival", "diplomacy"]

const _ACTIVITIES := {
	"salon": {"id": "salon"},
	"duel": {"id": "duel"},
	"gamble": {"id": "gamble"},
	"merchant": {"id": "merchant"},
	"rest": {"id": "rest"},
	"smuggle": {"id": "smuggle"},
	"festival": {"id": "festival"},
	"diplomacy": {"id": "diplomacy"},
}

const CALENDAR_IDS := ["recruit", "train", "bond_story", "diplomacy", "festival", "smuggle"]

const _CALENDAR_ACTIONS := {
	"recruit": {"id": "recruit"},
	"train": {"id": "train"},
	"bond_story": {"id": "bond_story"},
	"diplomacy": {"id": "diplomacy"},
	"festival": {"id": "festival"},
	"smuggle": {"id": "smuggle"},
}

const BIG_FATE_IDS := ["sacrifice_rearguard", "ransom_supply", "desperate_breakout"]

const _BIG_FATES := {
	"sacrifice_rearguard": {"id": "sacrifice_rearguard"},
	"ransom_supply": {"id": "ransom_supply"},
	"desperate_breakout": {"id": "desperate_breakout"},
}

static var _text: Dictionary = _load_text()
static var COINS: Dictionary = _table(_COINS, "coins")
static var PROPS: Dictionary = _table(_PROPS, "props")
static var BONDS: Dictionary = _table(_BONDS, "bonds")
static var COMPANIONS: Dictionary = _table(_COMPANIONS, "companions")
static var MARCH_BOARD: Array = _rows(_MARCH_BOARD, "march_board")
static var ROUTES: Dictionary = _table(_ROUTES, "routes")
static var ACTIVITIES: Dictionary = _table(_ACTIVITIES, "activities")
static var CALENDAR_ACTIONS: Dictionary = _table(_CALENDAR_ACTIONS, "calendar_actions")
static var BIG_FATES: Dictionary = _table(_BIG_FATES, "big_fates")


static func _load_text() -> Dictionary:
	var parsed = CardDB.read_json(TEXT_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("OceanRogueData: cannot read " + TEXT_PATH)
		return {}
	return parsed


## {id: row} with each row's text merged in, read-only
static func _table(base: Dictionary, section: String) -> Dictionary:
	var out := {}
	for id in base:
		out[id] = _row(base[id], section)
	out.make_read_only()
	return out


## [row, ...] with each row's text merged in, read-only
static func _rows(base: Array, section: String) -> Array:
	var out: Array = []
	for row in base:
		out.append(_row(row, section))
	out.make_read_only()
	return out


static func _row(base: Dictionary, section: String) -> Dictionary:
	var row: Dictionary = base.duplicate(true)
	var id := str(base.get("id", ""))
	var words: Variant = (_text.get(section, {}) as Dictionary).get(id, null)
	if typeof(words) != TYPE_DICTIONARY:
		push_error("OceanRogueData: %s has no text for %s.%s" % [TEXT_PATH, section, id])
	else:
		for key in words:
			row[key] = str(words[key])
	for key in row:
		if typeof(row[key]) == TYPE_ARRAY:
			(row[key] as Array).make_read_only()
	row.make_read_only()
	return row
