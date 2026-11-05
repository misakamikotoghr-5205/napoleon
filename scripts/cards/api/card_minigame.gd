# 小游戏插件基类：引擎只给物理量参数，小游戏只回观察键（红线 5，§8）。
# 主人 W0（Claude），冻结。合同：docs/cards/CARDS_INTERFACES.md §8.1、§8.2。
@abstract
class_name CardMiniGame
extends Control

## 结果：{quality_permille:int 0–1000, observations:[观察键], minutes:int, measures:{…整数}, aborted:bool}。
## 永远不返回“真/假/仿”这类判词；quality_permille 只决定观察清不清楚。
signal finished(result: Dictionary)

var _minutes_spent: int = 0


## 小游戏 kind（&"spot" &"coin_ring" &"weigh" &"fragments" &"decode"）。
@abstract func kind() -> StringName


## 只用 params 搭局面；不读引擎、不读存档。内部随机只用 JevRng.draw(params.seed, "c.mg.<kind>.layout", [i])。
@abstract func start(params: Dictionary) -> void


## skill 0.0–1.0；用和玩家一样的代码路径自己玩完（测试、自动试玩用），最后发 finished。
@abstract func autoplay(skill: float) -> void


## 玩家关掉（Esc）：交出空观察。
func abort() -> void:
	finished.emit({"quality_permille": 0, "observations": [], "minutes": minutes_spent(), "measures": {},
		"aborted": true})


## 到现在为止花掉的钟点（整数分钟），引擎从客人耐心里扣。
func minutes_spent() -> int:
	return _minutes_spent
