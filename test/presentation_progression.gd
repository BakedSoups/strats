extends SceneTree
var game: Node
var time: float = 0
var stage: int = 0
var commander: CombatUnit
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	game.start_match(); game.camera_pos=Vector2(780,1100); game.zoom_level=.60
	game.select_building(game.field.headquarters(0)); game.recruit_buttons[12].pressed.emit()
func _process(delta: float) -> bool:
	time+=delta
	if time>2 and stage==0:
		game.selected_building={}; game.selected.assign([game.units[0]]); game.active=game.units[0]; game.refresh_panel(); game.set_build_menu(true)
		game.recruit_or_build(0); stage=1
	if time>3 and stage==1:
		game.construct_building(1,0,game.base_plot(0,1),game.units[0]); game.placement_kind=-1; stage=2
	if time>6 and stage==2:
		for u in game.units:
			if u.team==0 and u.kind==12: commander=u
		if commander!=null:
			game.selected_building={}; game.selected.assign([commander]); game.active=commander; game.refresh_panel()
			game.buy_upgrade(commander,17); game.refresh_panel(); stage=3
	if time>9 and stage==3:
		var enemy: CombatUnit = game.spawn(0,1,commander.pos+Vector2(180,0))
		game.cast_ability(commander,"grenade",enemy.pos); stage=4
	if time>12 and stage==4:
		game.spawn(0,1,commander.pos+Vector2(300,50))
		game.cast_ability(commander,"mortar",commander.pos+Vector2(300,50)); stage=5
	if time>16 and stage==5:
		game.selected_building={}; game.selected.clear(); game.active=null; game.refresh_panel()
		game.camera_pos=game.field.SIZE/2; game.zoom_level=.24; stage=6
	return false
