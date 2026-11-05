# 引擎接口：界面、自动玩、测试唯一能碰的引擎入口（真引擎 CardEngine 与 MockCardEngine 都继承它）。
# 主人 W0（Claude），冻结；改签名走 [api] issue。合同：docs/cards/CARDS_INTERFACES.md §7.2、§7.4、§7.5。
@abstract
class_name CardEngineApi
extends RefCounted

## 由创建者注入；无头测试自己 new 一个 CardEventBus，用完 free()。引擎代码不直接引用 autoload CardBus。
var bus: CardEventBus = null


## 开新局。opts: {seed:int, difficulty:"normal", stage:int=0, data_root:String="res://data/cards",
## only_examples:bool=false, save_dir:String="user://cards"}。返回 {ok, err}；成功后阶段为 month_open。
@abstract func new_game(opts: Dictionary) -> Dictionary


## 读档。返回 {ok, err, meta}。读档时 ui 命名空间取“内存里的 ∪ 存档里的”（§6.1）。
@abstract func load_game(path: String) -> Dictionary


## 存档。返回 {ok, err}；只在 morning / month_open 阶段可存。
@abstract func save_game(path: String) -> Dictionary


## 只含看得见的信息的快照（§7.5）；同一状态永远返回同样内容。
@abstract func view() -> Dictionary


## 发指令（§7.4）；永远返回 {ok:bool, err:String, …}。执行顺序：检查 → 改状态 → 依次发 ctx.out 里的事件 →
## command_done → view_changed → 返回。ui.* 指令只改 ui 命名空间，不发任何事件、不进指令日志。
## 不要在 CardBus 回调里同步调用（会得到 err "busy"），要调就 call_deferred。
@abstract func send(cmd: StringName, args: Dictionary = {}) -> Dictionary


## 只读查询（§7.4 查询表）；查询键与参数见合同。
@abstract func query(q: StringName, args: Dictionary = {}) -> Dictionary


## send 正在执行（防重入）。
@abstract func is_busy() -> bool
