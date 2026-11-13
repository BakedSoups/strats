extends SceneTree
var game: Node
var time: float = 0
var stage: int = 0
func _initialize() -> void:
	seed(42)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	call_deferred("begin")
func begin() -> void:
	load("res://test/fixtures.gd").combined(game)
	game.start_match(); game.camera_pos=Vector2(1300,900); game.zoom_level=.30
func _process(delta: float) -> bool:
	time+=delta
	if time>3 and stage==0:
		game.camera_pos=Vector2(650,900); game.zoom_level=.65
		game.select_building(game.field.buildings[3])
		game.recruit_buttons[6].pressed.emit(); game.recruit_buttons[7].pressed.emit()
		stage=1
	if time>8 and stage==1:
		game.selected_building={}; game.selected.assign([game.units[0]]); game.active=game.units[0]; game.refresh_panel()
		game.spawn(0,1,game.active.pos+Vector2(170,0))
		var key: InputEventKey = InputEventKey.new(); key.keycode=KEY_A; key.physical_keycode=KEY_A; key.pressed=true
		game._unhandled_input(key); stage=2
	if time>12 and stage==2:
		game.select_building(game.field.buildings[3]); stage=3
	if time>15 and stage==3:
		game.selected_building={}; game.selected.clear(); game.active=null; game.refresh_panel()
		game.camera_pos=Vector2(1300,900); game.zoom_level=.30; stage=4
	return false
