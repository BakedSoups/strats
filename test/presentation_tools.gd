extends SceneTree
var game: Node
var engineer: CombatUnit
var truck: CombatUnit
var time: float = 0
var stage: int = 0
var cover_spot: Vector2
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func select(unit: CombatUnit) -> void:
	game.selected_building={}; game.selected.assign([unit]); game.active=unit; game.refresh_panel()
func begin() -> void:
	game.set_process(false); game.start_match(); engineer=game.units[0]
	var site: Dictionary = game.construct_building(3,0,game.base_plot(0,3),engineer)
	for step in 1200:
		game._process(1.0/30)
		if site.construction<=0: break
	game.recruit(13); game.tick_production(6); truck=game.units[-1]; truck.hp=65
	game.camera_pos=Vector2(1000,1630); game.zoom_level=.66
	select(engineer); game.set_process(true)
func _process(delta: float) -> bool:
	time+=delta
	if time>2 and stage==0: game.use_tool("build"); stage=1
	if time>4 and stage==1:
		game.catalog_back.pressed.emit(); game.buy_upgrade(engineer,4); game.refresh_panel(); stage=2
	if time>5 and stage==2:
		game.use_tool("repair"); game.assign_repair(engineer,truck); game.engineer_mode=""; stage=3
	if time>8 and stage==3:
		game.use_tool("barricade"); cover_spot=(engineer.pos+Vector2(160,0)).snapped(Vector2(20,20)); Input.warp_mouse(game.world_to_screen(cover_spot)); stage=4
	if time>9 and stage==4:
		game.place_barricade(engineer,cover_spot); game.engineer_mode=""; stage=5
	if time>11 and stage==5: select(truck); stage=6
	if time>12 and stage==6: game.use_tool("load"); stage=7
	if time>17 and stage==7: game.use_tool("unload"); stage=8
	return false
