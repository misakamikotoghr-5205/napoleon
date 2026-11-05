# 面板基类：所有面板都继承它。界面只读视图、只发指令（engine.send / query / view），只听 CardBus（自己只发 ui_event）。
# 主人 W0（Claude），冻结。合同：docs/cards/CARDS_INTERFACES.md §7.8、§3.3。
class_name CardPanel
extends Control

## 面板要关（宿主收到后关掉它并发 ui_event panel_closed）
signal close_requested(result: Dictionary)

var engine: CardEngineApi
var bus: CardEventBus


## 宿主实例化后先调它；子类 super(p_engine, p_bus) 之后再连自己要听的总线信号
func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	engine = p_engine
	bus = p_bus


## 宿主打开时调用（args 来自 request_panel 或牌的 uid 等）
func open(_args: Dictionary) -> void:
	pass


## 收到 view_changed 后宿主调用
func refresh(_view: Dictionary) -> void:
	pass


## 做一个合理的动作（发一条指令或推进动画），没得做返回 false；同一状态永远做同样的事（自动试玩、K14 走查用）
func autoplay_step() -> bool:
	return false


## “算了”：玩家点关掉或按 Esc（宿主调它）。默认直接关；有默认做法的面板（夜牌：今晚不选；留牌满：扔掉新来的；
## 人脉满：新来的不留；钱不够：认了）覆盖它，先发那条指令再关。没有关不掉的面板（合同 §7.8、§7.4.7，主创 10-13）。
func dismiss() -> void:
	close_requested.emit({})
