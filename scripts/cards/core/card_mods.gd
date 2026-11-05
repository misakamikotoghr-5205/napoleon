# 修正项登记表：谁都能提供，谁都能问（kind 见合同 §7.3 的表、CardIds.MODS）。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §7.3。
class_name CardMods
extends RefCounted

var _providers: Dictionary = {}   # kind → [{fn: Callable, owner: String}]（按登记顺序）


## provider: func(ctx: CardCtx, args: Dictionary) -> Variant
func register(kind: StringName, provider: Callable, owner: String) -> void:
	if not _providers.has(kind):
		_providers[kind] = []
	(_providers[kind] as Array).append({"fn": provider, "owner": owner})


## 各提供者返回 int 相加
func sum_int(ctx: CardCtx, kind: StringName, args: Dictionary) -> int:
	var total := 0
	for p in _providers.get(kind, []):
		total += int((p["fn"] as Callable).call(ctx, args))
	return total


## 各提供者返回百分比，连乘（100 为不变；整数运算，每步向下取整）
func pct(ctx: CardCtx, kind: StringName, args: Dictionary) -> int:
	var total := 100
	for p in _providers.get(kind, []):
		total = total * int((p["fn"] as Callable).call(ctx, args)) / 100
	return total


## 各提供者返回数组，拼起来
func collect(ctx: CardCtx, kind: StringName, args: Dictionary) -> Array:
	var out: Array = []
	for p in _providers.get(kind, []):
		var v = (p["fn"] as Callable).call(ctx, args)
		if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_PACKED_STRING_ARRAY:
			out.append_array(Array(v))
	return out


func any_true(ctx: CardCtx, kind: StringName, args: Dictionary) -> bool:
	for p in _providers.get(kind, []):
		if bool((p["fn"] as Callable).call(ctx, args)):
			return true
	return false


## 各提供者返回 Dictionary，按登记顺序合并；键冲突 push_error（view_section / card_view_part 用）
func merge(ctx: CardCtx, kind: StringName, args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for p in _providers.get(kind, []):
		var v = (p["fn"] as Callable).call(ctx, args)
		if typeof(v) != TYPE_DICTIONARY:
			continue
		for k in v.keys():
			if out.has(k):
				push_error("CardMods.merge(%s): key '%s' provided twice (second by %s)" % [kind, k, p["owner"]])
				continue
			out[k] = v[k]
	return out


func has_providers(kind: StringName) -> bool:
	return not (_providers.get(kind, []) as Array).is_empty()
