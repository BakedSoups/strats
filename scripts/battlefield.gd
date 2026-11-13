class_name Battlefield
extends RefCounted
const SUPPLY_PER_POINT: float = 3.5
const FUEL_PER_POINT: float = 2.5
const MANPOWER_CAP: int = 60
const SIZE: Vector2 = Vector2(3200,2200)
var roads: Array[PackedVector2Array] = []
var water: PackedVector2Array = PackedVector2Array([Vector2(0,360),Vector2(3200,1360),Vector2(3200,1840),Vector2(0,840)])
var bridges: Array[Rect2] = [Rect2(1490,780,220,640),Rect2(450,480,140,580),Rect2(2610,1140,140,580)]
var next_building_id: int = 1
var points: Array[Dictionary] = []
var covers: Array[Rect2] = []
var blocks: Array[Rect2] = []
var buildings: Array[Dictionary] = []
var supply: Array[float] = [1000.0,1000.0]
var fuel: Array[float] = [40.0,40.0]
var tickets: Array[float] = [500.0,500.0]
var queues: Array[Dictionary] = []
var navigation: AStarGrid2D
var nav_revision: int = 0
func _init() -> void:
	# An estuary divides two city districts; the central bridge is the main crossing.
	var locations: Array[Vector2] = [Vector2(1600,500),Vector2(1600,1100),Vector2(1600,1700),Vector2(920,1390),Vector2(600,1220),Vector2(2280,810),Vector2(2600,980),Vector2(1150,1880),Vector2(2050,320)]
	for i in locations.size(): points.append({"pos":locations[i],"type":0 if i<3 else (1 if i<7 else 2),"owner":-1,"progress":0.0,"capturer":-1})
	var north: Array[PackedVector2Array] = []
	north.append(PackedVector2Array([Vector2(900,240),Vector2(2800,240)]))
	north.append(PackedVector2Array([Vector2(900,500),Vector2(2900,500)]))
	north.append(PackedVector2Array([Vector2(1400,740),Vector2(2800,740)]))
	for x in [1000,1300,1600,1900,2200,2500]: north.append(PackedVector2Array([Vector2(x,240),Vector2(x,780 if x==1600 else (740 if x>1600 else 500))]))
	north.append(PackedVector2Array([Vector2(2680,740),Vector2(2680,1140)]))
	north.append(PackedVector2Array([Vector2(2200,980),Vector2(2280,810),Vector2(2280,500)]))
	north.append(PackedVector2Array([Vector2(1200,600),Vector2(1600,780),Vector2(2200,980),Vector2(2680,1140)]))
	for road in north:
		roads.append(road)
		var mirrored: PackedVector2Array = []
		for at in road: mirrored.append(SIZE-at)
		roads.append(mirrored)
	roads.append(PackedVector2Array([Vector2(1600,780),Vector2(1600,1420)]))
	roads.append(PackedVector2Array([Vector2(520,480),Vector2(520,1060)]))
	roads.append(PackedVector2Array([Vector2(2680,1140),Vector2(2680,1720)]))
	var parcels: Array[Rect2] = [Rect2(1050,300,180,110),Rect2(1950,550,180,110),Rect2(1350,80,180,110),Rect2(1650,80,180,110)]
	for parcel in parcels:
		blocks.append(parcel); blocks.append(Rect2(SIZE-parcel.end,parcel.size))
	for cover in [Rect2(1410,1460,130,20),Rect2(1660,720,130,20),Rect2(1460,420,20,100),Rect2(1720,1680,20,100),Rect2(610,1100,120,20),Rect2(2470,1080,120,20)]: covers.append(cover)
	for team in 2: add_building({"pos":Vector2(520,1680) if team==0 else Vector2(2680,520),"team":team,"type":0,"hp":2400.0})
	rebuild_navigation()
func income(delta: float) -> void:
	var vp: Array[int] = [0,0]
	for p in points:
		var owner: int = p.owner
		if owner<0: continue
		if p.type==0: vp[owner]+=1
		if p.type==1: supply[owner]+=delta*SUPPLY_PER_POINT
		if p.type==2: fuel[owner]+=delta*FUEL_PER_POINT
	for team in 2:
		supply[team]+=delta*2.0; fuel[team]+=delta*.5
		if vp[1-team]>vp[team]: tickets[team]=maxf(0,tickets[team]-delta*(vp[1-team]-vp[team])*1.4)
func headquarters(team: int) -> Dictionary:
	for b in buildings:
		if b.team==team and b.type==0: return b
	return {}
func add_building(data: Dictionary) -> void:
	data.id=next_building_id; next_building_id+=1
	data.heavy=false; data.research=0.0
	buildings.append(data)
	if navigation!=null: rebuild_navigation()
func building_by_id(id: int) -> Dictionary:
	for b in buildings:
		if b.id==id: return b
	return {}
func obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.append_array(blocks); result.append_array(covers)
	for b in buildings:
		if b.hp>0: result.append(Rect2(b.pos-Vector2(48,42),Vector2(96,84)))
	return result
func rebuild_navigation() -> void:
	navigation=AStarGrid2D.new(); navigation.region=Rect2i(0,0,80,55); navigation.cell_size=Vector2(40,40); navigation.offset=Vector2(20,20)
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in 80:
		for y in 55:
			if water_blocked(Vector2(x*40+20,y*40+20),25): navigation.set_point_solid(Vector2i(x,y))
	for obstacle in obstacles():
		var r: Rect2 = obstacle.grow(25)
		for x in range(maxi(0,int(r.position.x/40)),mini(80,int(r.end.x/40)+1)):
			for y in range(maxi(0,int(r.position.y/40)),mini(55,int(r.end.y/40)+1)): navigation.set_point_solid(Vector2i(x,y))
	nav_revision+=1
func free_cell(pos: Vector2) -> Vector2i:
	var center: Vector2i = Vector2i(pos/40).clamp(Vector2i.ZERO,Vector2i(79,54))
	for radius in 8:
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var candidate: Vector2i = center+Vector2i(x,y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return candidate
	return center
func find_path(at: Vector2, goal: Vector2) -> PackedVector2Array:
	var path: PackedVector2Array = navigation.get_point_path(free_cell(at),free_cell(goal))
	if not path.is_empty() and not occupied(goal,26): path.append(goal)
	return path
func waypoint(at: Vector2, goal: Vector2, _radius: float) -> Vector2:
	var path: PackedVector2Array = find_path(at,goal)
	if path.size()>1: return path[1]
	return goal if not occupied(goal) else at
func occupied(pos: Vector2, radius: float=20) -> bool:
	if water_blocked(pos,radius): return true
	for r in obstacles():
		if r.grow(radius).has_point(pos): return true
	return false
func can_place(pos: Vector2, team: int) -> bool:
	var site: Rect2 = Rect2(pos-Vector2(60,55),Vector2(120,110))
	if not Rect2(Vector2(80,80),SIZE-Vector2(160,160)).encloses(site): return false
	if water_blocked(pos,80): return false
	for bridge in bridges:
		if bridge.grow(40).intersects(site): return false
	for r in obstacles():
		if r.grow(35).intersects(site): return false
	for p in points:
		if p.pos.distance_to(pos)<160: return false
	if pos.distance_to(headquarters(team).pos)<560: return true
	for p in points:
		if p.owner==team and p.pos.distance_to(pos)<280: return true
	return false
func line_blocked(a: Vector2, b: Vector2) -> bool:
	for r in blocks:
		if r.has_point(a) or r.has_point(b) or crosses(r,a,b): return true
	return false
func cover_factor(at: Vector2, source: Vector2) -> float:
	for r in covers:
		if at.clamp(r.position,r.end).distance_to(at)>58 or r.has_point(at): continue
		var normal: Vector2 = Vector2.DOWN if r.size.x>=r.size.y else Vector2.RIGHT
		if (at-r.get_center()).dot(normal)*(source-r.get_center()).dot(normal)<0: return .42
	return 1.0
func crosses(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var corners: Array[Vector2] = [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return true
	return false

func water_blocked(pos: Vector2, radius: float = 0) -> bool:
	if absf(pos.y-(600+pos.x*.3125))>=240+radius: return false
	for bridge in bridges:
		if bridge.size.x>radius*2 and bridge.size.y>radius*2 and bridge.grow(-radius).has_point(pos): return false
	return true
