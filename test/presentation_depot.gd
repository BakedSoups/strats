extends SceneTree
var game: Node
var time: float = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	game.set_process(false); game.start_match()
	var depot: Dictionary = game.construct_building(3,0,game.base_plot(0,3),game.units[0])
	for step in 1200:
		game._process(1.0/30)
		if depot.construction<=0: break
	game.camera_pos=Vector2(780,1100); game.zoom_level=.6; game.select_building(depot)
func _process(delta: float) -> bool:
	time+=delta
	if time>1 and not game.selected_building.is_empty() and game.selected_building.research<=0: game.research_depot(game.selected_building)
	if time>1: game._process(delta)
	return false
