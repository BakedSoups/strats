class_name UnitPortrait
extends Control
var kind: int = 0
var building: bool = false
var tint: Color = Color("53b8ed")
var clock: float = 0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if kind in [9,10] and not building: clock+=delta; queue_redraw()
func _draw() -> void:
	var center: Vector2 = size/2
	var scale_icon: float = minf(size.x/100,size.y/80)
	draw_set_transform(center,0,Vector2.ONE*scale_icon)
	var ink: Color = Color("172a30")
	if building:
		draw_rect(Rect2(-31,-24,62,48),ink)
		draw_rect(Rect2(-27,-20,54,40),tint.darkened(.15))
		draw_rect(Rect2(-18,-12,36,24),tint)
		draw_line(Vector2(-35,-28),Vector2(35,-28),tint,4)
	elif kind in [9,10]:
		draw_line(Vector2(-12,0),Vector2(-39,0),ink,10)
		draw_style_box(rounded(tint),Rect2(-24,-14,54,28))
		draw_circle(Vector2(16,0),8,ink)
		draw_circle(Vector2(18,0),5,Color("b7e9e6"))
		var rotor: Vector2 = Vector2.from_angle(clock*18)*39
		draw_line(-rotor,rotor,Color("ccddd2"),3,true)
		draw_line(-rotor.orthogonal(),rotor.orthogonal(),Color("ccddd2"),3,true)
		draw_circle(Vector2.ZERO,5,ink)
	elif kind<=4:
		for offset: Vector2 in [Vector2(-17,14),Vector2(-17,-14)]:
			draw_circle(offset,9,ink); draw_circle(offset,6,tint.darkened(.2))
		draw_circle(Vector2.ZERO,19,ink); draw_circle(Vector2.ZERO,15,tint)
		draw_line(Vector2(4,0),Vector2(37,0),ink,12 if kind in [1,3] else 9)
		draw_line(Vector2(6,0),Vector2(34,0),Color("b7c8c1"),5)
		if kind==2: draw_line(Vector2(-5,-8),Vector2(5,8),Color("ffe0a1"),4)
		if kind==4: draw_circle(Vector2.ZERO,10,Color("c1ccc2"))
	else:
		draw_rect(Rect2(-31,-23,62,46),ink)
		draw_rect(Rect2(-27,-18,54,36),tint)
		draw_rect(Rect2(-31,-27,60,9),Color("49615b"))
		draw_rect(Rect2(-31,18,60,9),Color("49615b"))
		draw_circle(Vector2.ZERO,16,ink); draw_circle(Vector2.ZERO,12,tint.lightened(.1))
		draw_line(Vector2.ZERO,Vector2(40,0),ink,13 if kind==8 else 8)
		if kind==8: draw_line(Vector2(22,0),Vector2(39,0),Color("ffbb62"),8)
	draw_set_transform(Vector2.ZERO)
func rounded(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=color; style.set_corner_radius_all(14); return style
