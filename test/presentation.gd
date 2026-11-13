extends SceneTree
var game: Node
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.demo=true
	game.call_deferred("start_match")
