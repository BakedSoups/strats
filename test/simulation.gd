extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	seed(42)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	load("res://test/fixtures.gd").combined(game)
	game.start_match()
	game.set_process(false)
	var u: CombatUnit = game.units[0]
	var before: float = game.field.supply[0]
	var original: float = u.stats.damage
	assert(game.buy_upgrade(u,0))
	assert(u.stats.damage>original)
	assert(game.field.supply[0]==before-game.upgrades[0].supply)
	assert(not game.buy_upgrade(u,0))
	u.pos=game.field.points[0].pos
	u.goal=u.pos
	game.tick_capture(11)
	assert(game.field.points[0].owner==0)
	var tickets: float = game.field.tickets[1]
	game.field.income(2)
	assert(game.field.tickets[1]<tickets)
	game.recruit(0)
	var count: int = game.units.size()
	game.tick_production(20)
	assert(game.units.size()==count+1)
	var flame: CombatUnit = game.spawn(8,0,Vector2(1200,900))
	var enemy: CombatUnit = game.spawn(0,1,Vector2(1290,900))
	var flank: CombatUnit = game.spawn(0,1,Vector2(1200,1030))
	var hp: float = enemy.hp
	var flank_hp: float = flank.hp
	game.shoot(flame,enemy)
	assert(enemy.hp<hp and enemy.burn>0)
	assert(flank.hp==flank_hp)
	var transport: CombatUnit = game.spawn(10,0,Vector2(1300,900))
	game.selected.assign([transport]); game.active=transport
	u.pos=transport.pos
	game.action(5)
	assert(u.loaded)
	transport.ability_cooldown=0
	game.action(5)
	assert(not u.loaded)
	var engineer: CombatUnit = game.spawn(2,0,Vector2(700,700))
	game.active=engineer
	game.field.supply[0]=1000; game.field.fuel[0]=500
	game.set_build_menu(true)
	var building_count: int = game.field.buildings.size()
	engineer.pos=Vector2(400,1500)
	game.construct_building(5,0,Vector2(400,1400),engineer)
	assert(game.field.buildings.size()==building_count+1)
	assert(game.field.supply[0]==880 and game.field.fuel[0]==500)
	assert(not game.has_building(0,5))
	game.tick_production(30)
	assert(game.has_building(0,5))
	game.set_build_menu(false)
	var tank: CombatUnit = game.spawn(7,0,Vector2(1000,600))
	assert(not game.buy_upgrade(tank,10))
	assert(game.buy_upgrade(tank,8))
	assert(game.buy_upgrade(tank,10))
	var mg: CombatUnit = game.spawn(1,0,Vector2(900,600))
	game.damage(enemy,5,mg)
	assert(enemy.suppressed>0)
	var initial_hp: float = tank.hp
	enemy.pos=tank.pos+Vector2(100,0)
	game.damage(tank,30,enemy)
	var front_loss: float = initial_hp-tank.hp
	tank.hp=initial_hp
	enemy.pos=tank.pos-Vector2(100,0)
	game.damage(tank,30,enemy)
	assert(initial_hp-tank.hp>front_loss)
	game.shots.clear()
	u.pos=Vector2(200,200)
	enemy.pos=Vector2(300,200)
	var air_target: CombatUnit = game.spawn(9,1,Vector2(250,200))
	var air_hp: float = air_target.hp
	var ground_hp: float = enemy.hp
	game.shoot(u,enemy)
	game.tick_shots(.2)
	assert(air_target.hp==air_hp and enemy.hp<ground_hp)
	for step in 1800: game._process(1.0/30)
	assert(game.units.size()>5)
	game.field.tickets[1]=0
	game._process(.1)
	assert(game.ended)
	print("PASS: upgrades/costs, capture, income/tickets, recruitment, flame cone/burn, transport, construction, prerequisites, suppression, directional armor, projectile flight layers, 60s combat/AI, victory")
	quit()
