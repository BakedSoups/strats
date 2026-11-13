extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	load("res://test/fixtures.gd").combined(game)
	game.start_match(); game.set_process(false)
	assert(game.field.points.size()==9 and game.field.roads.size()>=8)
	for p in game.field.points:
		var mirror: Vector2 = game.field.SIZE-p.pos
		assert(game.field.points.any(func(other: Dictionary) -> bool: return other.type==p.type and other.pos.distance_to(mirror)<1))
		for b in game.field.buildings: assert(p.pos.distance_to(b.pos)>180)
	var depot: Dictionary = game.field.buildings[3]
	game.field.supply[0]=1000; game.field.fuel[0]=300
	game.select_building(depot)
	game.recruit(6,0,depot.id); game.recruit(7,0,depot.id)
	game.refresh_hud()
	assert(game.queue_progress.visible and is_zero_approx(game.queue_progress.value))
	assert(game.queue_label.text.contains("NEXT: Battle Tank"))
	game.tick_production(2); game.refresh_hud()
	assert(game.queue_progress.value>0 and game.queue_progress.value<100)
	assert(is_equal_approx(game.field.queues[1].left,game.field.queues[1].duration))
	game.tick_production(10); game.refresh_hud()
	assert(game.queue_label.text.contains("TRAINING: Battle Tank"))
	assert(is_zero_approx(game.queue_progress.value))
	game.tick_production(20); game.refresh_hud()
	assert(not game.queue_progress.visible and game.queue_label.text=="Queue empty")
	# Exercise the actual cached movement system across the main and side bridges.
	for route in [Vector4(1600,1500,1600,700),Vector4(520,1150,520,400)]:
		var destination: Vector2 = Vector2(route.z,route.w)
		var truck: CombatUnit = game.spawn(13,0,Vector2(route.x,route.y))
		truck.command(destination,false,false)
		for step in 1200:
			game.tick_units(1.0/30)
			assert(not game.field.water_blocked(truck.pos))
			if truck.pos.distance_to(destination)<20: break
		assert(truck.pos.distance_to(destination)<20)
	print("PASS: symmetric objectives, clear base approaches, producer progress/next unit/reset, horizontal/vertical barricade routing")
	quit()
