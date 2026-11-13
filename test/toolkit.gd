extends SceneTree
var game: Node
func _initialize() -> void:
	call_deferred("verify")
func click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=at; event.global_position=at; event.pressed=true; root.push_input(event,true)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
func verify() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.start_match()
	assert(game.selected_building==game.field.headquarters(0))
	assert(not game.controls_hint.visible)
	game.selected_building={}
	var engineer: CombatUnit = game.units[0]
	game.selected.assign([engineer]); game.active=engineer; game.refresh_panel()
	assert(game.tool_buttons.size()==4 and game.tool_buttons.has("build") and game.tool_buttons.has("repair") and game.tool_buttons.has("barricade") and game.tool_buttons.has("grenade"))
	await process_frame
	click(game.tool_buttons.build.get_global_rect().get_center())
	await process_frame
	assert(game.build_mode and game.catalog_title.text=="BUILDING PLANS" and game.upgrades_box.get_child_count()==5)
	click(game.catalog_back.get_global_rect().get_center())
	await process_frame
	assert(not game.build_mode and game.upgrade_buttons.size()==2)
	var supply: float = game.field.supply[0]
	game.use_tool("repair"); assert(game.engineer_mode=="repair" and game.field.supply[0]==supply)
	var truck: CombatUnit = game.spawn(13,0,engineer.pos+Vector2(110,0)); truck.hp=80
	assert(game.assign_repair(engineer,truck)); engineer.pos=truck.pos-Vector2(80,0); engineer.goal=engineer.pos
	game.tick_repair(engineer,1)
	assert(truck.hp==92 and game.field.supply[0]==supply)
	assert(game.buy_upgrade(engineer,4)); var upgraded_hp: float = truck.hp
	game.tick_repair(engineer,1); assert(is_equal_approx(truck.hp-upgraded_hp,21.6))
	engineer.command(engineer.pos); assert(engineer.repair_unit==null)
	var hq: Dictionary = game.field.headquarters(0); hq.hp=2100
	assert(game.assign_repair(engineer,null,hq)); engineer.pos=hq.pos+Vector2(100,0)
	game.tick_repair(engineer,1); assert(hq.hp>2100)
	engineer.command(engineer.pos)
	game.cover_vertical=false
	var point: Vector2 = hq.pos+Vector2(220,-180)
	supply=game.field.supply[0]
	var count: int = game.field.covers.size()
	assert(game.place_barricade(engineer,point))
	assert(game.field.covers.size()==count+1 and game.field.supply[0]==supply-45)
	assert(not game.place_barricade(engineer,point))
	assert(game.field.supply[0]==supply-45)
	engineer.pos=game.field.bridges[0].get_center()+Vector2(100,0)
	assert(not game.can_place_barricade(engineer,game.field.bridges[0].get_center()))
	game.selected.assign([truck]); game.active=truck; game.refresh_panel()
	assert(game.tool_buttons.size()==2 and game.tool_buttons.has("load") and game.tool_buttons.has("unload"))
	engineer.pos=truck.pos+Vector2(40,0)
	assert(game.assign_repair(engineer,truck))
	game.use_tool("load"); assert(engineer.loaded and engineer.repair_unit==null)
	truck.ability_cooldown=0; game.use_tool("unload"); assert(not engineer.loaded)
	var rifle: CombatUnit = game.spawn(0,0,truck.pos)
	game.selected.assign([rifle]); game.active=rifle; game.refresh_panel()
	assert(game.tool_buttons.size()==1 and game.tool_buttons.has("grenade"))
	var key: InputEventKey = InputEventKey.new(); key.keycode=KEY_A; key.physical_keycode=KEY_A; key.pressed=true
	game._unhandled_input(key); assert(rifle.goal==rifle.pos and not game.attack_mode)
	print("PASS: contextual tool cards, real build/back clicks, separate repairs/cover costs, Advanced Tools effects, transport controls, keyboard fire")
	quit()
