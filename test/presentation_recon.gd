extends SceneTree
var game: Node
var scout: CombatUnit
var truck: CombatUnit
var time: float = 0
var stage: int = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func select(unit: CombatUnit) -> void:
	game.selected_building={}; game.selected.assign([unit]); game.active=unit; game.refresh_panel()
func begin() -> void:
	game.set_process(false); game.start_match(); game.ai_clock=99999
	for kind in [1,3]:
		var site: Dictionary = game.construct_building(kind,0,game.base_plot(0,kind),game.units[0])
		assert(not site.is_empty())
		for step in 1800:
			game._process(1.0/30)
			if site.construction<=0: break
	game.recruit(0); game.recruit(6); game.recruit(13)
	game.tick_production(6); game.tick_production(6)
	var rifle: CombatUnit
	for u in game.units:
		if u.team!=0: continue
		if u.kind==0: rifle=u
		if u.kind==6: scout=u
		if u.kind==13: truck=u
	assert(rifle!=null and scout!=null and truck!=null)
	rifle.command(truck.pos+Vector2(30,0),false,false)
	for step in 300:
		game._process(1.0/30)
		if rifle.pos.distance_to(truck.pos)<100: break
	game.load_or_unload(truck)
	scout.command(Vector2(1600,1500),false,false); truck.command(Vector2(1600,1500),false,false)
	for step in 900:
		game._process(1.0/30)
		if scout.pos.distance_to(Vector2(1600,1500))<20 and truck.pos.distance_to(Vector2(1600,1500))<20: break
	# A recon scenario on previously surveyed terrain; enemy locations remain hidden.
	game.vision.explored[0].fill(1)
	game.spawn(0,1,Vector2(1600,650)); game.spawn(7,1,Vector2(2000,700))
	game.vision.refresh(); game.camera_pos=Vector2(1600,1100); game.zoom_level=.42
	select(truck); game.set_process(true)
func _process(delta: float) -> bool:
	time+=delta
	if time>1 and stage==0: select(scout); scout.command(Vector2(1600,850),false,false); stage=1
	if time>3 and stage==1: game.buy_upgrade(scout,20); game.refresh_panel(); stage=2
	if time>6 and stage==2: truck.command(Vector2(1600,1100),false,false); stage=3
	if time>9 and stage==3: game.load_or_unload(truck); select(truck); truck.command(Vector2(1600,1500),false,false); stage=4
	if time>11 and stage==4: select(scout); scout.command(Vector2(1300,1750),false,false); stage=5
	return false
