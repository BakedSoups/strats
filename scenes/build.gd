extends SceneTree
func _initialize() -> void:
	var root_node: Node2D = Node2D.new()
	root_node.name = "STRATS"
	root_node.set_script(load("res://scripts/game.gd"))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_node) == OK)
	var check: Node = packed.instantiate()
	assert(check.name == root_node.name)
	check.free()
	assert(ResourceSaver.save(packed, "res://scenes/main.tscn") == OK)
	root_node.free()
	quit()
