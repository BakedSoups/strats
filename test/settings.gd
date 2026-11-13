extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var path: String = "user://settings_test.cfg"
	var service: GameSettings = GameSettings.new(path)
	service.apply(false)
	assert(service.conflict("attack_move",KEY_UP,service.bindings)!="")
	assert(service.conflict("attack_move",KEY_ESCAPE,service.bindings)!="")
	assert(service.conflict("attack_move",KEY_E,service.bindings)=="")
	service.values.master=0.0
	service.values.camera_speed=900.0
	service.values.edge_scrolling=true
	service.bindings.attack_move=KEY_E
	assert(service.save()==OK)
	var restored: GameSettings = GameSettings.new(path)
	restored.load_saved()
	assert(restored.values.master==0 and restored.values.camera_speed==900 and restored.values.edge_scrolling)
	assert(restored.bindings.attack_move==KEY_E)
	restored.apply(false)
	assert(AudioServer.is_bus_mute(0))
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode=KEY_E; key.keycode=KEY_E; key.pressed=true
	assert(key.is_action_pressed("strats_attack_move"))
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.preferences.storage_path=path
	game.preferences.values=game.preferences.defaults()
	game.preferences.bindings=GameSettings.DEFAULT_KEYS.duplicate()
	game.preferences.apply(false)
	game.start_match()
	game.open_settings()
	assert(not game.running and game.settings_menu.visible)
	var paused_time: float = game.elapsed
	game._process(1.0)
	assert(game.elapsed==paused_time)
	var menu: SettingsMenu = game.settings_menu
	menu.controls.camera_speed.value=1100
	menu.begin_rebind("attack_move")
	menu._input(key)
	assert(menu.draft_keys.attack_move==KEY_E)
	assert(game.preferences.values.camera_speed!=1100)
	menu.close_menu()
	assert(game.running and not menu.visible and game.preferences.values.camera_speed!=1100)
	game.open_settings()
	menu.controls.camera_speed.value=1100
	menu.begin_rebind("attack_move"); menu._input(key)
	menu.apply_draft()
	assert(game.preferences.values.camera_speed==1100)
	assert(game.command_buttons[1].text.contains("[E]"))
	menu.close_menu()
	game._unhandled_input(key)
	assert(not game.attack_mode)
	game.attack_mode=false
	key.keycode=KEY_A; key.physical_keycode=KEY_A
	game._unhandled_input(key)
	assert(not game.attack_mode)
	game.menu.show(); game.running=false
	game.open_settings(); menu.close_menu()
	assert(not game.running and game.menu.visible)
	game.open_settings(); menu.reset_draft(); menu.apply_draft()
	assert(game.preferences.bindings.attack_move==KEY_A)
	assert(game.preferences.values.camera_speed==650)
	var config: ConfigFile = ConfigFile.new()
	config.set_value("settings","camera_speed",999999.0)
	config.set_value("settings","resolution",99)
	config.set_value("bindings","camera_up",KEY_ESCAPE)
	config.save(path)
	restored=GameSettings.new(path); restored.load_saved()
	assert(restored.values.camera_speed==1400 and restored.values.resolution==3)
	assert(restored.bindings==GameSettings.DEFAULT_KEYS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: settings persistence, validation, rebinding/conflicts, audio mute, pause, apply/cancel/defaults, command labels and live input")
	quit()
