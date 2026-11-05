# Rogue v1 relics: module constants. Owner RG1 (docs/cards/rogue/ROGUE_V1.md §4). No class_name.
extends RefCounted

const OWNER := "RG1"
const NS := "relic"
const DEPTHS: Array[String] = ["plain", "storied", "treasure"]
const ERR_RELIC_FULL := "relic_full"
const ERR_NOT_HELD := "not_held"
const Q_RELICS := &"relics"

# ---- RG1 additions (ROGUE_V1.md §3.1, §4.5, §4.6, §5.4, §6.3) ----
## state.relic layout version (§3.1).
const STATE_V := 1
## Rule file name under data/cards/rules (rules/relics.json, owned by RG3).
const RULES := "relics"
## Defaults used when rules/relics.json or one of its keys is missing (§6.3 values).
const DEFAULT_CAP := 6
const CLAMP_DEFAULTS := {
	"price_pay_min": 90, "price_pay_max": 105,
	"price_receive_min": 95, "price_receive_max": 115,
	"patience_min": 85, "patience_max": 125,
	"appraise_min": 90, "appraise_max": 140,
	"pool_min": 50, "pool_max": 200,
	"shelf_cap_min": -1, "shelf_cap_max": 2,
	"kept_cap_min": 0, "kept_cap_max": 1,
	"deal_count_min": 0, "deal_count_max": 1,
	"coins_min": 0, "coins_max": 1,
}
## Visible view block key (view_section) and the view_changed topic.
const VIEW_KEY := "relics"
## Notice keys: the released one is a UI key (RG1.json); the gain line is the relic's own text field.
const NOTICE_RELEASED := "rg1.notice.released"
const GAIN_FIELD := "#lines.gain"
## Lifecycle hooks and their priorities (§4.6): day_start before G03 issues the weekly demand (30),
## settle after G03 lets heat decay (40).
const HOOK_DAY_START := &"day_start"
const HOOK_SETTLE := &"settle"
const PRIORITY_DAY_START := 25
const PRIORITY_SETTLE := 45
## The only hooks a relic's passives / downsides may name in v1 (§5.4).
const PASSIVE_HOOKS: Array[String] = ["day_start", "settle"]
const PASSIVE_FIELDS: Array[String] = ["passives", "downsides"]
## Condition ops a mods row's "when" may use (§5.4): cheap ones that never ask a modifier.
const WHEN_OPS: Array[String] = ["all", "any", "not", "flag", "has_contact", "weather", "market_day", "almanac_yi",
	"estate_status", "stage_gte", "weekday", "heat_tier_gte", "rep_tier_gte"]
## Modifier kinds this module provides (§4.5); pct kinds multiply (100 = unchanged), the others add.
const PCT_KINDS: Array[StringName] = [&"price_pct", &"patience_pct", &"appraise_pct", &"pool_pct"]
const SUM_KINDS: Array[StringName] = [&"cap", &"deal_count", &"coins"]
## mods row shapes (§5.4): mod -> {param: spec}. Specs: "pct" (int 1-400), "int", "str", "strs" (string array),
## "e:a,b" (one of), trailing "?" = optional. Every row also takes "mod", optional "when" (condition) and "flaw" (bool).
const MOD_ROWS := {
	"price_pct": {"direction": "e:pay,receive", "cats": "strs?", "pct": "pct"},
	"patience_pct": {"pct": "pct"},
	"appraise_pct": {"cats": "strs?", "pct": "pct"},
	"shelf_cap": {"delta": "int"},
	"kept_cap": {"delta": "int"},
	"deal_count": {"type": "e:person,event,news", "delta": "int"},
	"pool_weight": {"pool": "str", "tags_any": "strs?", "intents": "strs?", "pct": "pct"},
	"coins": {"source_kind": "e:self,contact,money,kept,news,item", "slot_tags_any": "strs?", "delta": "int"},
}
const ROW_COMMON: Array[String] = ["mod", "when", "flaw"]
const PCT_MIN := 1
const PCT_MAX := 400
## Which mods rows feed which modifier kind (§5.4 table).
const ROWS_FOR_KIND := {
	&"price_pct": ["price_pct"], &"patience_pct": ["patience_pct"], &"appraise_pct": ["appraise_pct"],
	&"cap": ["shelf_cap", "kept_cap"], &"deal_count": ["deal_count"], &"pool_pct": ["pool_weight"],
	&"coins": ["coins"],
}
