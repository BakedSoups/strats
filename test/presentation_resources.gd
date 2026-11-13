extends SceneTree
var game: Node
var time: float = 0
var stage: int = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	game.start_match(); game.select_building(game.field.headquarters(0))
	game.units[0].command(game.field.points[4].pos,false,false)
func _process(delta: float) -> bool:
	time+=delta
	if time>2 and stage==0: game.recruit_buttons[12].pressed.emit(); stage=1
	if time>8 and stage==1:
		game.selected_building={}
		for u in game.units:
			if u.team==0 and u.kind==12: game.active=u; game.selected.assign([u]); break
		game.refresh_panel(); stage=2
	return false
