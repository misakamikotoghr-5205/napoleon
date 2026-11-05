# Rogue v1 run context (old ledger): module constants. Owner RG5. No class_name.
# docs/cards/rogue/ROGUE_V1.md §3.3, §4.1, §4.3-§4.6, §5.6. The engine never reads the profile file:
# the shell hands the run context in through game.new {run}, and takes the harvest out through legacy.harvest.
extends RefCounted

const OWNER := "RG5"
const NS := "run"
const NS_VERSION := 1
const Q_HARVEST := &"legacy.harvest"
const Q_OLD_INK := &"legacy.old_ink"
const COND_VETERAN := &"veteran"
const MOD_UNSCRIPTED := &"unscripted_day"
## View block key (view_section); only present while state.run exists.
const VIEW_KEY := "run"
## rules/legacy.json; a missing file means only the default opening exists (module dormant).
const RULES := "legacy"
const DEFAULT_OPENING := "og.default"
## Used when rules/legacy.json has no openings table: today's game, nothing unlockable.
const DEFAULT_OPENINGS := {"og.default": {"veteran": false, "notice": "", "unlock_closed": 0, "order": 0}}
## day_start priority (before RG2's 3 and the G03 demand issue at 30).
const DAY_START_PRIORITY := 2
## The opening notice goes out on this stage / stage day only.
const NOTICE_STAGE := 0
const NOTICE_DAY := 1
## unscripted_day: a veteran opening plays the scripted tutorial days of this stage as ordinary days.
const UNSCRIPTED_STAGE := 0

## legacy.harvest {close}: the reasons with their own chronicle keys; anything else is "other".
const CLOSE_ENDING := "ending"
const CLOSE_PRISON := "prison"
const CLOSE_ABANDONED := "abandoned"
## Eras that have their own prison / abandoned chronicle keys (rg5.chronicle.<reason>.<era>).
const CHRONICLE_ERAS: Array[String] = ["1938", "1939", "1940"]
const KEY_PREFIX := "rg5.chronicle."
const KEY_OTHER := "rg5.chronicle.other"
const KEY_ENDING_KIND := "rg5.chronicle.ending.kind"
const KEY_ENDING_PLAIN := "rg5.chronicle.ending.plain"
const KEY_ENDING_HARD := "rg5.chronicle.ending.hard"
## rules.legacy.chronicle defaults (conscience thresholds; engine only, never shown).
const KIND_AT := 20
const HARD_AT := -20
