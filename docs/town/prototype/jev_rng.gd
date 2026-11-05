# Port of gamejev_living/randomness.py (draw + weighted_choice) and selection.replay_draw.
class_name JevRng
extends RefCounted

const TWO_53 := 9007199254740992.0

# Canonical JSON identical to Python json.dumps(..., ensure_ascii=False, separators=(',',':'))
# for ints / strings / bools / nested arrays. Floats are formatted with repr-like rules only for
# integral floats is NOT supported -> keep keys to ints and strings.
static func canon(v) -> String:
	match typeof(v):
		TYPE_INT:
			return str(v)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_STRING, TYPE_STRING_NAME:
			return _qs(String(v))
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for x in v:
				parts.append(canon(x))
			return "[" + ",".join(parts) + "]"
		TYPE_FLOAT:
			# JSON round-trips turn ints into floats in Godot; treat integral floats as ints so a
			# loaded save draws the same numbers. (Python would print 3.0 -- keep keys int/str.)
			if is_finite(v) and v == floor(v) and absf(v) < 9.0e15:
				return str(int(v))
			push_error("JevRng: non-integral float in semantic key")
			return str(v)
	push_error("JevRng: unsupported key type")
	return ""

static func _qs(s: String) -> String:
	var o := "\""
	for ch in s:
		var c := ch.unicode_at(0)
		if ch == "\"": o += "\\\""
		elif ch == "\\": o += "\\\\"
		elif c == 0x0A: o += "\\n"
		elif c == 0x0D: o += "\\r"
		elif c == 0x09: o += "\\t"
		elif c == 0x08: o += "\\b"
		elif c == 0x0C: o += "\\f"
		elif c < 0x20: o += "\\u%04x" % c
		else: o += ch
	return o + "\""

static func _u53(bytes: PackedByteArray) -> float:
	var v: int = 0
	for i in range(6):
		v = (v << 8) | int(bytes[i])
	v = (v << 5) | (int(bytes[6]) >> 3)
	return float(v) / TWO_53

static func sha256_bytes(text: String) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish()

# draw(seed, domain, key...) in [0,1). key is an Array of ints/strings.
static func draw(seed: int, domain: String, key: Array) -> float:
	return _u53(sha256_bytes(canon([seed, domain, key])))

static func replay_draw(seed: int, agent_id: String, counter: int) -> float:
	return _u53(sha256_bytes("gamejev-persona-v03|%d|%s|%d" % [seed, agent_id, counter]))

# rows: Array of [id:String, weight:float]
static func weighted_choice(rows: Array, u: float) -> String:
	assert(not rows.is_empty() and u >= 0.0 and u < 1.0)
	var total := 0.0
	for r in rows:
		assert(float(r[1]) >= 0.0)
		total += float(r[1])
	assert(total > 0.0)
	var threshold := u * total
	var cum := 0.0
	for r in rows:
		cum += float(r[1])
		if threshold < cum:
			return r[0]
	for i in range(rows.size() - 1, -1, -1):
		if float(rows[i][1]) > 0.0:
			return rows[i][0]
	return rows[-1][0]
