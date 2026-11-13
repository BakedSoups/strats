extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	seed(42)
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.start_match()
	assert(game.field.bridges.size()==3)
	assert(game.field.water_blocked(Vector2(1200,975)))
	assert(not game.field.water_blocked(Vector2(1600,1100),25))
	assert(not game.field.can_place(Vector2(1600,1100),0))
	for team in 2:
		for kind in range(1,5): assert(game.field.can_place(game.base_plot(team,kind),team))
	var bridge_route: PackedVector2Array = game.field.find_path(Vector2(1600,1500),Vector2(1600,700))
	assert(bridge_route.size()>5)
	var crossed: bool = false
	for at in bridge_route:
		assert(not game.field.water_blocked(at))
		if game.field.bridges[0].has_point(at): crossed=true
	assert(crossed)
	game.vision.refresh()
	assert(not game.spotted(0,game.field.headquarters(1).pos))
	assert(not game.vision.was_explored(0,game.field.headquarters(1).pos))
	assert(game.spotted(0,game.field.headquarters(0).pos))
	var center: Vector2i = Vector2i(game.field.headquarters(0).pos/BattleVision.CELL)
	assert(game.vision.visible[0][center.y*BattleVision.COLS+center.x]==1)
	var infantry: CombatUnit = game.units[0]
	infantry.pos=Vector2(1600,1450); infantry.goal=infantry.pos
	var enemy: CombatUnit = game.spawn(0,1,Vector2(1600,900))
	assert(not game.spotted(0,enemy.pos))
	var scout: CombatUnit = game.spawn(6,0,infantry.pos+Vector2(10,0))
	assert(scout.stats.sight>infantry.stats.sight)
	assert(game.spotted(0,enemy.pos))
	game.vision.refresh(); assert(game.vision.was_explored(0,enemy.pos))
	scout.pos=game.field.headquarters(0).pos
	assert(not game.spotted(0,enemy.pos))
	game.vision.refresh(); assert(game.vision.was_explored(0,enemy.pos))
	assert(game.vision.known_buildings[0].is_empty())
	scout.pos=game.field.headquarters(1).pos+Vector2(-150,0)
	game.vision.refresh(); assert(game.vision.known_buildings[0].has(game.field.headquarters(1).id))
	scout.pos=game.field.headquarters(0).pos; game.vision.refresh()
	assert(game.vision.known_buildings[0].has(game.field.headquarters(1).id))
	assert(not game.spotted(0,game.field.headquarters(1).pos))
	var enemy_hq: Dictionary = game.field.headquarters(1)
	enemy_hq.hp=0; game.vision.refresh()
	assert(game.vision.known_buildings[0].has(enemy_hq.id))
	scout.pos=enemy_hq.pos+Vector2(-150,0); game.vision.refresh()
	assert(not game.vision.known_buildings[0].has(enemy_hq.id))
	enemy_hq.hp=2400; scout.pos=game.field.headquarters(0).pos
	game.field.supply[0]=2000; assert(game.buy_upgrade(scout,20)); assert(scout.stats.sight==950)
	var depot: Dictionary = {"pos":game.base_plot(0,3),"team":0,"type":3,"hp":900.0}
	game.field.add_building(depot); game.select_building(depot)
	assert(game.recruit_buttons[13].visible and not game.recruit_buttons[13].disabled)
	var before: float = game.field.supply[0]; var fuel: float = game.field.fuel[0]
	game.recruit(13,0,depot.id)
	assert(game.field.supply[0]==before-140 and game.field.fuel[0]==fuel)
	game.tick_production(6)
	var truck: CombatUnit = game.units[-1]
	assert(truck.kind==13 and truck.spec.reach==0 and truck.spec.cargo_capacity==2)
	infantry.pos=truck.pos+Vector2(40,0)
	var second: CombatUnit = game.spawn(0,0,truck.pos+Vector2(40,30))
	game.load_or_unload(truck)
	assert(truck.cargo.size()==2 and infantry.loaded and second.loaded)
	game.load_or_unload(truck)
	assert(not infantry.loaded and not second.loaded)
	assert(not game.field.occupied(infantry.pos,18))
	# Unspotted aircraft cannot inform the AI's anti-air decision or targeting.
	assert(not game.spotted(1,game.field.headquarters(0).pos))
	# Shared spotting controls auto-fire, not only rendering.
	for u in game.units:
		if u.team==0: u.pos=game.field.headquarters(0).pos
	var shooter: CombatUnit = game.spawn(0,0,Vector2(1600,1450)); shooter.stats.sight=100
	var contact: CombatUnit = game.spawn(0,1,Vector2(1600,1260))
	game.shots.clear(); shooter.cooldown=0; game.tick_units(.05)
	assert(not game.shots.any(func(shot: Dictionary) -> bool: return shot.get("source")==shooter))
	var spotter: CombatUnit = game.spawn(6,0,shooter.pos+Vector2(-20,0))
	game.tick_units(.05)
	assert(game.shots.any(func(shot: Dictionary) -> bool: return shot.get("source")==shooter))
	# Ground vision is blocked by city buildings; aerial vision can see over them.
	for u in game.units:
		if u.team==0: u.pos=game.field.headquarters(0).pos
	spotter.pos=Vector2(1000,355); contact.pos=Vector2(1280,355)
	assert(not game.spotted(0,contact.pos))
	var aircraft: CombatUnit = game.spawn(9,0,spotter.pos)
	assert(game.spotted(0,contact.pos))
	# Loaded troops cannot scout from inside a transport.
	for u in game.units:
		if u.team==0: u.pos=game.field.headquarters(0).pos
	truck.pos=Vector2(1600,1100)
	var officer: CombatUnit = game.spawn(12,0,truck.pos)
	contact.pos=Vector2(1600,650)
	assert(game.spotted(0,contact.pos))
	var officers: Array[int] = [12]
	game.load_or_unload(truck,officers); assert(officer.loaded)
	assert(not game.spotted(0,contact.pos))
	var flame: CombatUnit = game.spawn(8,1,truck.pos-Vector2(100,0))
	var protected_hp: float = officer.hp
	game.shoot(flame,officer)
	assert(officer.hp==protected_hp)
	print("PASS: three navigable bridges, water/build rules, fog/exploration memory, hidden HQ/units, scout optics, light truck recruitment/cargo/safe unloading")
	quit()
