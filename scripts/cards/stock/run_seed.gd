# Seeds for new runs: run 1 is always 7; later runs derive from the profile salt, the run number and how many times
# the title's reroll was pressed. Never reads the wall clock (red line 2). Typed text maps deterministically to a seed.
# Owner RG2 (docs/cards/rogue/ROGUE_V1.md §5.7). Pure functions, usable by the engine and the shell.
class_name CardRunSeed
extends RefCounted

const FIRST_RUN_SEED := 7
const MAX_SEED := 2147483646
const DOMAIN := "m.run.seed"
const TEXT_DOMAIN := "m.run.seed_text"
const TEXT_MAX := 24


static func derive(salt: int, run_no: int, reroll: int) -> int:
	if run_no <= 1 and reroll <= 0:
		return FIRST_RUN_SEED
	return 1 + int(JevRng.draw(salt, DOMAIN, [run_no, reroll]) * float(MAX_SEED - 1))


## -1 = empty (use the suggested seed). Digits are used as is (folded into 1..MAX_SEED); any other text is hashed.
static func parse(text: String) -> int:
	var s := text.strip_edges()
	if s == "":
		return -1
	if RegEx.create_from_string("^[0-9]{1,18}$").search(s) != null:
		var v := int(s)
		return v if v >= 1 and v <= MAX_SEED else 1 + posmod(v - 1, MAX_SEED)
	return 1 + int(JevRng.draw(0, TEXT_DOMAIN, [s.substr(0, TEXT_MAX)]) * float(MAX_SEED - 1))


static func text(seed_value: int) -> String:
	return str(seed_value)
