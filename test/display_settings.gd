extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	assert(DisplayServer.get_name()!="headless")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for index in GameSettings.RESOLUTIONS.size():
		game.preferences.values.resolution=index
		game.preferences.values.fullscreen=false
		game.preferences.apply()
		for frame in 5: await process_frame
		assert(DisplayServer.window_get_size()==GameSettings.RESOLUTIONS[index])
		assert(root.get_visible_rect().size.is_equal_approx(Vector2(1440,900)))
		game.open_settings()
		assert(game.settings_menu.get_global_rect().size.is_equal_approx(Vector2(1440,900)))
		game.settings_menu.close_menu()
	game.preferences.values.fullscreen=true
	game.preferences.apply()
	for frame in 5: await process_frame
	assert(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN)
	game.preferences.values.fullscreen=false
	game.preferences.values.resolution=1
	game.preferences.apply()
	for frame in 5: await process_frame
	assert(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED)
	print("PASS: all four resolutions, preserved logical viewport/settings layout, fullscreen and windowed switching")
	quit()
