extends SceneTree
func _initialize() -> void:
	var field: Battlefield = Battlefield.new()
	assert(field.blocks.size()==8 and field.bridges.size()==3)
	for block in field.blocks:
		assert(Rect2(field.SIZE-block.end,block.size) in field.blocks)
		for point in field.points: assert(point.pos.distance_to(point.pos.clamp(block.position,block.end))>=200)
		for corner in [block.position,block.end,Vector2(block.position.x,block.end.y),Vector2(block.end.x,block.position.y)]: assert(not field.water_blocked(corner))
		for road in field.roads:
			for i in road.size()-1: assert(not field.crosses(block.grow(40),road[i],road[i+1]))
	for bridge in field.bridges:
		var path: PackedVector2Array = field.find_path(Vector2(bridge.get_center().x,bridge.position.y-80),Vector2(bridge.get_center().x,bridge.end.y+80))
		assert(path.size()>5)
		for at in path: assert(not field.water_blocked(at))
	for team in 2:
		var origin: Vector2 = field.headquarters(team).pos
		for kind in range(1,5): assert(field.can_place(origin+Vector2(220 if team==0 else -220,(kind-2.5)*220),team))
	print("PASS: estuary parcel symmetry, objective/road/water clearance, three traversable bridges, usable HQ plots")
	quit()
