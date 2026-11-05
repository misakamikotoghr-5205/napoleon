# Rogue v1 weekly stocktake and customer sources: module constants. Owner RG2. No class_name.
# Contract: docs/cards/rogue/ROGUE_V1.md §3.2 (state), §4.2-§4.6 (command, query, op, mods, hooks), §6.3 (rules).
extends RefCounted

const OWNER := "RG2"
const NS := "stock"
const DOMAIN := "c.stock.offer"
const PANEL := &"stocktake"
const CMD_PICK := &"stock.pick"
const Q_STOCKTAKE := &"stocktake"
const OP_OFFER := &"stock_offer"

# ---- added by RG2 ----
const RULES := "stock"
const VERSION := 1
const KIND_RELIC := "relic"
const KIND_SOURCE := "source"
## Fallback order when a slot's pool is empty (§5.1).
const KINDS: Array[String] = ["relic", "source"]
const FROM_WEEK := "week"
const FROM_PEDDLER := "peddler"
const ST_OPEN := "open"
const ST_PICKED := "picked"
const ST_PASSED := "passed"
const ST_LAPSED := "lapsed"
## A card_resolved almanac with this entry is one deal of the week (§5.1).
const TRADE := "trade"
const MOD_POOL := "pool_weight"
const MOD_DEALS := "deal_count"
const GAIN_SUFFIX := "#lines.gain"
const SRC_PREFIX := "stock:"

const N_STOCKTAKE := "rg2.notice.stocktake"
const N_FEW := "rg2.notice.stocktake_few"
const N_PASSED := "rg2.notice.passed"
const N_SOURCES_LAPSED := "rg2.notice.sources_lapsed"
const N_PEDDLER_EMPTY := "rg2.notice.peddler_empty"
const N_LAPSED := "rg2.notice.lapsed"

## Hook priorities (§4.6).
const PRI_STAGE_START := 60
const PRI_DAY_START := 3
const PRI_RESOLVED := 35
const PRI_SETTLE := 80

## rules/stock.json defaults (§6.3); a missing rules file means the module is off.
const DEFAULTS := {
	"enabled": true, "week_days": [7, 14, 21, 28], "deals_needed": 2, "offers_full": 3, "offers_few": 2,
	"slot_kinds": ["relic", "source", "relic"], "source_only_weeks": ["0:0"],
}
const CLAMP := {"pool_min": 50, "pool_max": 250, "deal_count_min": 0, "deal_count_max": 1}
## stock.pick argument keys (§4.2).
const PICK_KEYS: Array[String] = ["offer", "pick", "replace"]
