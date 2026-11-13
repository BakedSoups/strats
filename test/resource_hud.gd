extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false)
	game.field.supply[0]=1020; game.field.fuel[0]=45; game.refresh_hud()
	assert(game.supply_badge.value_label.text=="1,020")
	assert(game.fuel_badge.value_label.text=="45")
	assert(game.supply_badge.detail_label.text=="+120/min")
	assert(game.fuel_badge.detail_label.text=="+30/min")
	assert(game.manpower_badge.value_label.text=="2 / 60")
	game.field.points[3].owner=0; game.field.points[7].owner=0; game.field.points[0].owner=1
	game.recruit(2)
	game.refresh_hud()
	assert(game.supply_badge.detail_label.text=="+330/min")
	assert(game.fuel_badge.detail_label.text=="+180/min")
	assert(game.manpower_badge.value_label.text=="4 / 60")
	assert(game.manpower_badge.tooltip_text.contains("2 deployed + 2 reserved"))
	assert(game.drain_label.text=="Azure −84/min")
	await process_frame
	for badge in [game.supply_badge,game.fuel_badge,game.manpower_badge]:
		assert(badge.value_label.position.x+badge.value_label.size.x<badge.detail_label.position.x+1)
		assert(badge.get_global_rect().end.x<=880)
	print("PASS: resource grouping, formatted balances, true income, queued capacity, VP drain, no label overlap")
	quit()
