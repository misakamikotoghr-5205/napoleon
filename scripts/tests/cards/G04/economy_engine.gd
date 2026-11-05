# G04 的 W1 引擎替身，仅安装本模块和口碑、本心效果替身。
# 与实际跨模块验收分开，避免其他线的未完成钩子影响经济单测。
extends CardEngine
func _init() -> void:
	_commands.clear()
	_queries.clear()
	ctx = CardCtx.new()
	CardEconomyInstall.install(self, ctx)
	for op in [&"rep", &"conscience"]:
		ctx.ops.register(op, _meter, CardDslShapes.shape(op), "test")

static func _meter(_ctx: CardCtx, _eff: Dictionary, _source: String) -> void:
	pass
