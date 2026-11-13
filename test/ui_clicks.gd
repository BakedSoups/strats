extends SceneTree
var game: Node
func _initialize() -> void:
	call_deferred("verify")
func click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position=at; event.global_position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	root.push_input(event,true)
	event=event.duplicate(); event.pressed=false
	root.push_input(event,true)
func verify() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	load("res://test/fixtures.gd").combined(game)
	game.start_match(); game.set_process(false)
	await process_frame
	click(game.base_grid.get_child(0).get_global_rect().get_center())
	await process_frame
	assert(not game.selected_building.is_empty())
	game.selected_building={}; game.selected.assign([game.units[0],game.units[1]]); game.active=game.units[0]; game.refresh_panel()
	await process_frame
	click(game.selection_row.get_child(1).get_global_rect().get_center())
	await process_frame
	assert(game.active==game.units[1])
	game.field.supply[0]=1000
	click(game.upgrade_buttons[0].get_global_rect().get_center())
	await process_frame
	assert(0 in game.active.purchased)
	for iteration in 12:
		game.selected_building={}; game.selected.clear(); game.active=null; game.refresh_panel()
		await process_frame
		click(game.base_grid.get_child(iteration%game.base_grid.get_child_count()).get_global_rect().get_center())
		await process_frame
		assert(not game.selected_building.is_empty())
	print("PASS: real viewport mouse clicks on base cards, unit cards, and upgrades")
	quit()
