extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.start_match()
	assert(game.active==null and game.context_title.text.begins_with("COMMANDER"))
	game.camera_pos=Vector2(700,900)
	var depot: Dictionary = game.field.buildings[3]
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT; click.position=game.world_to_screen(depot.pos); click.pressed=true
	game._unhandled_input(click); click.pressed=false; game._unhandled_input(click)
	assert(game.selected_building.id==depot.id)
	assert(game.production_panel.visible and not game.actions_panel.visible)
	for i in game.recruit_buttons.size(): assert(game.recruit_buttons[i].visible==(i in [6,7,8]))
	game.field.money[0]=3000; game.field.fuel[0]=1000
	game.recruit_buttons[7].pressed.emit()
	assert(game.field.queues.size()==1 and game.field.queues[0].producer==depot.id)
	var other: Dictionary = {"pos":Vector2(500,1200),"team":0,"type":3,"hp":900.0}
	game.field.add_building(other)
	game.recruit(7,0,other.id)
	game.tick_production(2)
	assert(is_equal_approx(game.field.queues[0].left,game.field.queues[1].left))
	var count: int = game.units.size()
	game.tick_production(20)
	assert(game.units.size()==count+2)
	assert(game.units[-2].pos.distance_to(depot.pos)<150)
	assert(game.units[-1].pos.distance_to(other.pos)<150)
	game.selected_building={}
	var rifle: CombatUnit = game.units[0]
	var tank: CombatUnit = game.spawn(7,0,Vector2(1000,1000))
	game.selected.assign([rifle,tank]); game.active=rifle; game.refresh_panel()
	assert(game.portrait.kind==0 and not game.portrait.building)
	assert(game.actions_panel.visible and game.upgrades_panel.visible and not game.production_panel.visible)
	assert(game.selection_row.get_child_count()==2)
	var tank_goal: Vector2 = tank.goal
	game.action(4)
	assert(tank.goal==tank_goal and tank.status!="Taking cover")
	game.selected.assign([tank]); game.active=tank; game.refresh_panel()
	assert(game.command_buttons[4].disabled)
	var source: CombatUnit = game.spawn(0,1,Vector2(1000,1000))
	game.field.covers.clear(); game.field.covers.append(Rect2(900,900,200,20))
	rifle.pos=Vector2(1000,870); tank.pos=rifle.pos
	var rifle_hp: float = rifle.hp; var tank_hp: float = tank.hp
	game.damage(rifle,20,source); game.damage(tank,20,source)
	var covered_rifle: float = rifle_hp-rifle.hp; var covered_tank: float = tank_hp-tank.hp
	rifle.hp=rifle_hp; tank.hp=tank_hp; game.field.covers.clear()
	game.damage(rifle,20,source); game.damage(tank,20,source)
	assert(rifle_hp-rifle.hp>covered_rifle)
	assert(is_equal_approx(tank_hp-tank.hp,covered_tank))
	game.preferences.bindings=GameSettings.DEFAULT_KEYS.duplicate(); game.preferences.apply(false)
	game.selected.assign([rifle]); game.active=rifle
	var key: InputEventKey = InputEventKey.new(); key.keycode=KEY_A; key.physical_keycode=KEY_A; key.pressed=true
	game._unhandled_input(key)
	assert(not game.attack_mode and not key.is_action_pressed("strats_camera_left"))
	assert(rifle.attack_move and rifle.goal==rifle.pos and rifle.orders.is_empty())
	var held_position: Vector2 = rifle.pos
	game.shots.clear(); rifle.cooldown=0
	game.tick_units(.1)
	assert(rifle.pos.distance_to(held_position)<1)
	assert(game.shots.any(func(shot: Dictionary) -> bool: return shot.get("source")==rifle))
	game.recruit(7,0,depot.id); var money: float = game.field.money[0]; depot.hp=0
	game.tick_production(20)
	assert(game.field.money[0]==money+game.specs[7].manpower)
	print("PASS: commander/unit/base contexts, real depot clicks, roster filtering, previews, independent producer queues/spawns, infantry-only cover, A stationary engagement, destroyed producer refund")
	quit()
