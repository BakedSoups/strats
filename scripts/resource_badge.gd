class_name ResourceBadge
extends Control
var kind: int = 0
var accent: Color
var value_label: Label
var detail_label: Label
func _init(title: String, type: int, color: Color, width: float) -> void:
	kind=type; accent=color; size=Vector2(width,50)
	var background: Panel = Panel.new(); background.size=size; background.show_behind_parent=true; background.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(background)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=Color("263c42"); style.border_color=Color("496066"); style.set_border_width_all(1); style.border_width_left=3; style.set_corner_radius_all(4); background.add_theme_stylebox_override("panel",style)
	add_text(title,Vector2(43,3),11,accent)
	value_label=add_text("",Vector2(43,14),25,Color("f0f3e8"))
	detail_label=add_text("",Vector2(width-79,25),11,Color("b6cbc3"))
	mouse_filter=Control.MOUSE_FILTER_STOP
func add_text(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new(); label.text=text; label.position=at; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(label); return label
func _draw() -> void:
	draw_line(Vector2(2,8),Vector2(2,42),accent,3)
	var center: Vector2 = Vector2(22,27)
	if kind==0:
		draw_rect(Rect2(center-Vector2(10,9),Vector2(20,18)),accent,false,2)
		draw_line(center+Vector2(-9,-3),center+Vector2(9,-3),accent,2)
		draw_line(center+Vector2(0,-9),center+Vector2(0,9),accent,2)
	elif kind==1:
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-13),center+Vector2(-8,0),center+Vector2(-8,6),center+Vector2(0,11),center+Vector2(8,6),center+Vector2(8,0)]),accent)
		draw_line(center+Vector2(-4,1),center+Vector2(-4,5),Color("263c42"),2)
	else:
		for offset in [Vector2(-8,3),Vector2(8,3),Vector2(0,-3)]:
			draw_circle(center+offset-Vector2(0,6),3.5,accent)
			draw_line(center+offset,center+offset+Vector2(0,8),accent,5)
