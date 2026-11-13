extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	seed(42)
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.start_match()
	assert(game.field.buildings.size()==2 and game.units.size()==2)
	assert(game.units[0].kind==2 and game.units[1].kind==2)
	assert(game.field.SIZE==Vector2(3200,2200) and game.field.blocks.size()==8)
	assert(game.manpower_used(0)==2)
	var hq: Dictionary = game.field.headquarters(0)
	game.select_building(hq)
	for i in game.recruit_buttons.size(): assert(game.recruit_buttons[i].visible==(i in [2,12]))
	var count: int = game.field.queues.size()
	game.recruit(0,0,hq.id); assert(game.field.queues.size()==count)
	game.recruit(2,0,hq.id); game.recruit(12,0,hq.id)
	assert(game.manpower_used(0)==7)
	game.recruit(12,0,hq.id); assert(game.field.queues.size()==count+2)
	game.tick_production(6); game.tick_production(6)
	var commander: CombatUnit
	for u in game.units:
		if u.team==0 and u.kind==12: commander=u
	assert(commander!=null and game.manpower_used(0)==7)
	game.field.supply[0]=5000; game.field.fuel[0]=500
	var engineer: CombatUnit = game.units[0]
	var before: float = game.field.supply[0]
	assert(game.construct_building(1,0,game.field.blocks[0].get_center(),engineer).is_empty())
	assert(game.field.supply[0]==before)
	for kind in range(1,5):
		var site: Dictionary = game.construct_building(kind,0,game.base_plot(0,kind),engineer)
		assert(not site.is_empty())
		var paused: float = site.construction
		var prior: Vector2 = engineer.pos; engineer.pos=hq.pos-Vector2(140,0)
		game.tick_production(.1)
		assert(site.construction==paused)
		engineer.pos=prior
		for step in 1200:
			game._process(1.0/30)
			if site.construction<=0: break
		assert(site.construction<=0 and game.has_building(0,kind))
	var depot: Dictionary
	for b in game.field.buildings:
		if b.team==0 and b.type==3: depot=b
	assert(not depot.heavy)
	before=game.field.supply[0]; count=game.field.queues.size()
	game.recruit(7,0,depot.id); assert(game.field.supply[0]==before and game.field.queues.size()==count)
	assert(game.research_depot(depot))
	assert(game.field.supply[0]==before-220)
	assert(not game.research_depot(depot))
	game.tick_production(15); assert(depot.heavy)
	game.recruit(7,0,depot.id); assert(game.field.queues[-1].kind==7)
	game.tick_production(15)
	var rifle: CombatUnit = game.spawn(0,0,Vector2(700,1100))
	var enemy: CombatUnit = game.spawn(0,1,Vector2(850,1100))
	before=game.field.supply[0]
	assert(game.cast_ability(rifle,"grenade",enemy.pos))
	assert(game.field.supply[0]==before-20)
	assert(not game.cast_ability(rifle,"grenade",enemy.pos))
	var health: float = enemy.hp; game.tick_blasts(2); assert(enemy.hp<health)
	assert(not game.cast_ability(commander,"mortar",commander.pos+Vector2(200,0)))
	assert(game.buy_upgrade(commander,17))
	before=game.field.supply[0]
	assert(game.cast_ability(commander,"mortar",commander.pos+Vector2(200,0)))
	assert(game.blasts.size()==6)
	assert(game.field.supply[0]==before-80)
	assert(not game.cast_ability(commander,"mortar",commander.pos+Vector2(200,0)))
	game.tick_blasts(5)
	assert(game.blasts.is_empty())
	var used: int = game.manpower_used(0); rifle.hp=0; assert(game.manpower_used(0)==used-3)
	while game.manpower_used(0)<59: game.spawn(0,0,Vector2(600,1600))
	before=game.field.supply[0]; count=game.field.queues.size(); game.recruit(2,0,hq.id)
	assert(game.field.supply[0]==before and game.field.queues.size()==count)
	assert(game.field.line_blocked(game.field.blocks[0].position-Vector2(100,-40),game.field.blocks[0].end+Vector2(100,-40)))
	for block in game.field.blocks:
		var path: PackedVector2Array = game.field.find_path(block.position-Vector2(100,0),block.end+Vector2(100,0))
		assert(not path.is_empty())
		for at in path: assert(not block.has_point(at))
	print("PASS: HQ-only engineer/commander opening, four attended constructions, placement, supply/fuel/manpower, depot research, grenade/barrage costs & cooldowns, capacity release, block navigation")
	quit()
