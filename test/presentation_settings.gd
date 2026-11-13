extends SceneTree
var game: Node
var time: float = 0
var stage: int = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	game.preferences.storage_path="user://settings_presentation.cfg"
	game.demo=true
	game.start_match()
func _process(delta: float) -> bool:
	time+=delta
	if time>2 and stage==0:
		game.open_settings(); stage=1
	if time>3.5 and stage==1:
		game.settings_menu.controls.camera_speed.value=900
		game.settings_menu.controls.zoom_sensitivity.value=1.3
		game.settings_menu.controls.edge_scrolling.button_pressed=true
		game.settings_menu.begin_rebind("attack_move")
		stage=2
	if time>5 and stage==2:
		var key: InputEventKey = InputEventKey.new()
		key.keycode=KEY_E; key.physical_keycode=KEY_E; key.pressed=true
		game.settings_menu._input(key)
		stage=3
	if time>6 and stage==3: game.settings_menu.apply_draft(); stage=4
	if time>8 and stage==4: game.settings_menu.close_menu(); stage=5
	if time>12 and stage==5: game.open_settings(); stage=6
	if time>14 and stage==6: game.settings_menu.close_menu(); stage=7
	return false
func _finalize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_presentation.cfg"))
