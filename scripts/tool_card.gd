class_name ToolCard
extends Button
var detail_label: Label
var cost_label: Label
class Glyph extends Control:
	var key: String
	func _draw() -> void:
		var c: Color = Color("8bc8d7")
		var white: Color = Color("e1e8d8")
		match key:
			"build":
				draw_line(Vector2(6,28),Vector2(24,6),c,5)
				draw_line(Vector2(15,6),Vector2(30,18),white,8)
			"repair":
				draw_line(Vector2(6,27),Vector2(25,8),c,6)
				draw_arc(Vector2(25,8),8,.2,4.4,16,white,4,true)
				draw_circle(Vector2(6,27),4,white)
			"barricade":
				for y in [8,22]: draw_rect(Rect2(2,y,30,6),white)
				for x in [8,24]: draw_line(Vector2(x,4),Vector2(x,31),c,3)
			"grenade":
				draw_circle(Vector2(16,21),11,Color("e6c17d"))
				draw_rect(Rect2(12,4,10,8),white)
				draw_arc(Vector2(24,5),5,-2,2,12,c,2,true)
			"mortar":
				draw_line(Vector2(7,29),Vector2(25,7),white,9)
				draw_line(Vector2(4,29),Vector2(30,29),c,4)
			"load", "unload":
				draw_rect(Rect2(5,10,23,21),c,false,2)
				var start: float = 0 if key=="load" else 29
				var finish: float = 24 if key=="load" else 5
				draw_line(Vector2(16,start),Vector2(16,finish),white,3)
				var dy: float = -6 if key=="load" else 6
				draw_polyline(PackedVector2Array([Vector2(10,finish+dy),Vector2(16,finish),Vector2(22,finish+dy)]),white,3)
func _init(title: String, detail: String, cost: String, key: String) -> void:
	custom_minimum_size=Vector2(154,94); clip_contents=true; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var normal: StyleBoxFlat = StyleBoxFlat.new(); normal.bg_color=Color("2b464c"); normal.border_color=Color("527078"); normal.set_border_width_all(1); normal.set_corner_radius_all(4)
	add_theme_stylebox_override("normal",normal)
	var hover: StyleBoxFlat = normal.duplicate(); hover.bg_color=Color("375b63"); hover.border_color=Color("7fcbe5"); add_theme_stylebox_override("hover",hover)
	var disabled_style: StyleBoxFlat = normal.duplicate(); disabled_style.bg_color=Color("24383d"); disabled_style.border_color=Color("384c51"); add_theme_stylebox_override("disabled",disabled_style)
	var icon: Glyph = Glyph.new(); icon.key=key; icon.position=Vector2(8,6); icon.size=Vector2(34,36); icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(icon)
	var name_label: Label = text_label(title,Vector2(48,13),14,Color("e0eadd")); name_label.size=Vector2(101,22); name_label.clip_text=true
	detail_label=text_label(detail,Vector2(10,45),11,Color("b4c8c0")); detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_label.size=Vector2(135,29)
	cost_label=text_label(cost,Vector2(10,76),11,Color("e6c17d"))
func text_label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new(); label.text=text; label.position=at; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(label); return label
