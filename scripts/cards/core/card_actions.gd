# 手牌上的动作（视图里的 actions：open / keep / discard / refuse / read / choose:<id>）登记表。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §7.3、§7.5。
class_name CardActions
extends RefCounted

var _providers: Dictionary = {}   # 牌的类型（或 &"*" 所有类型）→ [{fn, owner}]


## provider: func(ctx: CardCtx, uid: String) -> Array[Dictionary]（{id, enabled, reason_key}）
func register(type: StringName, provider: Callable, owner: String) -> void:
	if not _providers.has(type):
		_providers[type] = []
	(_providers[type] as Array).append({"fn": provider, "owner": owner})


## 先问 &"*" 的提供者，再问这张牌类型的；同一个动作 id 只留第一次出现的
func for_card(ctx: CardCtx, uid: String) -> Array:
	var def := CardPiles.def_of(ctx, uid)
	var out: Array = []
	var seen: Dictionary = {}
	for t in [&"*", StringName(str(def.get("type", "")))]:
		for p in _providers.get(t, []):
			for a in (p["fn"] as Callable).call(ctx, uid):
				var aid := str(a.get("id", ""))
				if aid == "" or seen.has(aid):
					continue
				seen[aid] = true
				out.append(a)
	return out
