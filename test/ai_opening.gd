extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	seed(9)
	var game: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.start_match(); game.set_process(false)
	for step in 7200: game._process(1.0/30)
	for kind in range(1,5): assert(game.has_building(1,kind))
	assert(game.units.any(func(u: CombatUnit) -> bool: return u.team==1 and u.kind not in [2]))
	assert(game.manpower_used(1)<=Battlefield.MANPOWER_CAP)
	assert(game.field.supply[1]>=0 and game.field.fuel[1]>=0)
	print("PASS: 4-minute HQ-only AI opening constructs all facilities, recruits combat troops, respects resources/cap")
	quit()
