# 高清界面的叠层框：几层 StyleBoxFlat 依次画（外影 + 底 + 金边，内缩几像素的第二道细金边，上半截的一层微光）。
# StyleBoxFlat 只有一道边，“双金边”和“玻璃上的高光”要靠叠层。没有 class_name；由 hd_theme.gd 的 panel_box()
# 和 apply_button() 造出来。内边距用 StyleBox 自己的 content_margin_*（造的时候从最外层抄过来）。
#   layers 每项 {"box": StyleBoxFlat, "inset": 像素, "top": 0..1（只画上面这一截，1 = 整块）}
# 改颜色：box.outer() 是最外层（底色、外边、影子），box.inner() 是第二道细边（可能为 null）。
extends StyleBox

var layers: Array = []


func add_layer(box: StyleBoxFlat, inset: float = 0.0, top: float = 1.0) -> void:
	layers.append({"box": box, "inset": inset, "top": top})


## 最外层（底色、外边、影子都在这层）
func outer() -> StyleBoxFlat:
	return layers[0]["box"] if not layers.is_empty() else null


## 第二道细边（没有就是 null）
func inner() -> StyleBoxFlat:
	for l in layers:
		var b: StyleBoxFlat = l["box"]
		if not b.draw_center and float(l["inset"]) > 0.0:
			return b
	return null


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	for l in layers:
		var r := rect.grow(-float(l["inset"]))
		var top := float(l["top"])
		if top < 1.0:
			r.size.y = r.size.y * top
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		(l["box"] as StyleBoxFlat).draw(to_canvas_item, r)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var o := outer()
	if o == null:
		return rect
	return rect.grow_individual(o.expand_margin_left, o.expand_margin_top, o.expand_margin_right,
		o.expand_margin_bottom)
