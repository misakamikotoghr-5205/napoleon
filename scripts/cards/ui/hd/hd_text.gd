# 高清界面共用的文字小工具（只处理字符串，不碰节点）。没有 class_name，用的地方：
#   const HdText = preload("res://scripts/cards/ui/hd/hd_text.gd")
# same_title：两个标题是不是同一件事（序曲的“部”和“场次标题”就是一回事，章节卡、营地顶栏只写一次）；
# unpage：旧像素对话框的分页（ocean_view._dialog_pages 每 52 字切一页、页与页空一行）还原成一行一句。
extends RefCounted

## 句末标点（。！？；：）：分页在这些字后面断开的，还原时另起一行
const STOPS := ["\u3002", "\uFF01", "\uFF1F", "\uFF1B", "\uFF1A"]


## 去掉标点、空格以后一个包含另一个
static func same_title(a: String, b: String) -> bool:
	var na := _bare(a)
	var nb := _bare(b)
	if na == "" or nb == "":
		return false
	return na.contains(nb) or nb.contains(na)


static func _bare(s: String) -> String:
	var out := ""
	for i in s.length():
		var code := s.unicode_at(i)
		# 空白、ASCII 标点、全角标点（3000–303F、FF00–FF0F、FF1A–FF20）、间隔号 00B7 / 30FB / 2027
		if code <= 47 or (code >= 58 and code <= 64) or (code >= 0x3000 and code <= 0x303F) \
				or (code >= 0xFF00 and code <= 0xFF0F) or (code >= 0xFF1A and code <= 0xFF20) \
				or code in [0xB7, 0x30FB, 0x2027, 0x2014, 0x2026]:
			continue
		out += s.substr(i, 1)
	return out


## 句末标点结尾的页另起一行，硬切断（满 48 字以上、不是句末）的页直接接上
static func unpage(text: String) -> String:
	var out := ""
	for page in text.split("\n\n", false):
		var p := str(page).strip_edges()
		if p == "":
			continue
		if out == "":
			out = p
			continue
		var last := out.substr(out.length() - 1, 1)
		if out.length() >= 2 and not (last in STOPS) and not out.ends_with("\n"):
			var tail := out.get_slice("\n", out.get_slice_count("\n") - 1)
			if tail.length() >= 48:
				out += p
				continue
		out += "\n" + p
	return out
