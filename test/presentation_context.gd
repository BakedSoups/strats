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
	game.start_match(); game.camera_pos=Vector2(950,900); game.zoom_level=.65
func _process(delta: float) -> bool:
	time+=delta
	if time>2 and stage==0:
		game.select_building(game.field.buildings[3]); stage=1
	if time>4 and stage==1:
		game.recruit_buttons[6].pressed.emit(); stage=2
	if time>6 and stage==2:
		game.selected_building={}; game.selected.assign([game.units[0]]); game.active=game.units[0]; game.refresh_panel(); stage=3
	if time>8 and stage==3:
		var key: InputEventKey = InputEventKey.new(); key.keycode=KEY_A; key.physical_keycode=KEY_A; key.pressed=true
		game._unhandled_input(key); game.issue(Vector2(1200,900),false,game.attack_mode); game.attack_mode=false; stage=4
	if time>10 and stage==4:
		game.selected.clear()
		for u in game.units:
			if u.team==0 and u.spec.infantry: game.selected.append(u)
		game.active=game.selected[0]; game.refresh_panel(); game.action(4); stage=5
	if time>13 and stage==5:
		game.select_building(game.field.buildings[4]); stage=6
	if time>16 and stage==6:
		game.selected_building={}; game.selected.clear(); game.active=null; game.refresh_panel(); stage=7
	return false
