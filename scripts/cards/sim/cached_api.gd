# 模拟工具的只读视图缓存；每条变更指令前失效，事件内外busy始终读真实门面。
# G06；合同1.2 §7.2、§12.4；不读ctx、不缓存query、不新增冻结类。
extends CardEngineApi

var _delegate: CardEngineApi
var _cached_view: Dictionary = {}
var _has_view: bool = false


func _init(target: CardEngineApi) -> void:
	_delegate = target
	bus = target.bus


func new_game(opts: Dictionary) -> Dictionary:
	_invalidate()
	return _delegate.new_game(opts)


func load_game(path: String) -> Dictionary:
	_invalidate()
	return _delegate.load_game(path)


func save_game(path: String) -> Dictionary:
	_invalidate()
	return _delegate.save_game(path)


func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	_invalidate()
	return _delegate.send(cmd, args)


func view() -> Dictionary:
	if not _has_view:
		_cached_view = _delegate.view()
		_has_view = true
	var result: Dictionary = _cached_view.duplicate(true)
	result["busy"] = _delegate.is_busy()
	return result


func query(q: StringName, args: Dictionary = {}) -> Dictionary:
	return _delegate.query(q, args)


func is_busy() -> bool:
	return _delegate.is_busy()


func state_hash() -> String:
	return str(_delegate.call("state_hash")) if _delegate.has_method("state_hash") else ""


func command_log() -> Array:
	return _delegate.call("command_log") if _delegate.has_method("command_log") else []


func _invalidate() -> void:
	_cached_view = {}
	_has_view = false
