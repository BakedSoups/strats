extends SceneTree
var game: Node
var elapsed: float = 0
var issued: bool = false
var cover: Rect2
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); call_deferred("begin")
func begin() -> void:
	game.start_match()
	cover=Rect2(Vector2(650,1580),Vector2(160,20)); game.field.covers.append(cover); game.field.rebuild_navigation()
	var rifle: CombatUnit = game.spawn(0,0,Vector2(650,1720))
	game.selected_building={}; game.active=rifle; game.selected.assign([rifle]); game.refresh_panel()
	var at: Vector2 = cover.get_center()+Vector2(0,36)
	var slots: Dictionary = game.cover_destinations(at)
	assert(slots.has(rifle))
	assert(game.infantry_in_cover(slots[rifle]))
	assert(game.field.cover_factor(slots[rifle],cover.get_center()-Vector2(0,200))<1)
	assert(game.field.cover_factor(slots[rifle],cover.get_center()+Vector2(0,200))==1)
	Input.warp_mouse(game.world_to_screen(at))
func _process(delta: float) -> bool:
	elapsed+=delta
	if elapsed>4 and not issued:
		game.issue(cover.get_center()+Vector2(0,36),false,false); issued=true
	if elapsed>10 and issued:
		assert(game.infantry_in_cover(game.active.pos))
	return false
