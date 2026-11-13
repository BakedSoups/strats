extends SceneTree
var game: Node
var elapsed: float = 0
var recruited: bool = false
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	assert(game.selected_building==game.field.headquarters(0))
	assert(not game.controls_hint.visible)
	game.start_match()
func _process(delta: float) -> bool:
	elapsed+=delta
	if elapsed>2 and not recruited:
		game.recruit_buttons[2].pressed.emit(); recruited=true
	return false
