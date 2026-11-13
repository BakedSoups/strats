extends SceneTree
var game: Node
var time: float = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	game.start_match(); game.camera_pos=game.field.SIZE/2; game.zoom_level=.24
	game.units[0].command(game.field.points[0].pos,false,false)
func _process(delta: float) -> bool:
	time+=delta
	if time<3: return false
	var target: Vector2 = Vector2(1600,760) if time<9 else Vector2(1600,1450)
	var desired_zoom: float = .5
	if time>15: target=game.field.SIZE/2; desired_zoom=.24
	game.camera_pos=game.camera_pos.lerp(target,minf(1,delta*2))
	game.zoom_level=lerpf(game.zoom_level,desired_zoom,minf(1,delta*2))
	return false
