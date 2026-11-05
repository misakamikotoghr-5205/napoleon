# 一枚铜钱的一面。清单里没有 icon.coin.head / icon.coin.tail 时用配色画圆。
# 主人 C03。不写 class_name。合同：docs/cards/CARDS_INTERFACES.md §1.2、§3.3 C03。
# 换皮（10-22，原型 60/62）：没掷的铜钱画正面、整枚压暗（调用方设 modulate 55%）；ring = 自动算正面的那几枚，外面一圈金。
extends Control

var face: bool = false
var shown: bool = false
## 没掷之前也画正面（等着掷的铜钱）；false 时没翻开就画一枚暗圆。
var idle_face: bool = false
var ring: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5
	if ring:
		draw_circle(c, rad + 3.0, CardTheme.with_alpha(&"gold_hi", 0.25))
		draw_arc(c, rad + 2.0, 0.0, TAU, 32, CardTheme.color(&"gold_hi"), 2.0, true)
	var tex := _texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	var key := &"wood_dark"
	if shown or idle_face:
		key = &"gold" if (face or not shown) else &"wood_mid"
	draw_circle(c, rad * 0.84, CardTheme.color(key))


func _texture() -> Texture2D:
	if not shown and not idle_face:
		return null
	var id := "icon.coin.head" if (face or not shown) else "icon.coin.tail"
	var path := CardArt.path(id)
	if path == "" or path == CardArt.path("__c03_no_coin__"):
		return null
	return CardArt.texture(id)
