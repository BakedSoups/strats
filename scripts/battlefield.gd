class_name Battlefield
extends RefCounted
const SIZE: Vector2 = Vector2(2600,1800)
var next_building_id: int = 1
var points: Array[Dictionary] = []
var covers: Array[Rect2] = []
var buildings: Array[Dictionary] = []
var money: Array[float] = [900.0,900.0]
var fuel: Array[float] = [240.0,240.0]
var tickets: Array[float] = [500.0,500.0]
var queues: Array[Dictionary] = []
func _init() -> void:
	var locations: Array[Vector2] = [Vector2(850,450),Vector2(1300,900),Vector2(1750,1350),Vector2(500,650),Vector2(850,1350),Vector2(1750,450),Vector2(2100,1150),Vector2(1050,250),Vector2(1550,1550)]
	for i in locations.size(): points.append({"pos":locations[i],"type":0 if i<3 else (1 if i<7 else 2),"owner":-1,"progress":0.0,"capturer":-1})
	for v in [Vector2(730,430),Vector2(1170,830),Vector2(1440,990),Vector2(1760,1240),Vector2(650,1050),Vector2(1900,700),Vector2(1100,350),Vector2(1460,1430)]: covers.append(Rect2(v,Vector2(145,20)))
	for team in 2:
		var base: Vector2 = Vector2(240,900) if team==0 else Vector2(2360,900)
		add_building({"pos":base,"team":team,"type":0,"hp":2400.0})
		for j in 4: add_building({"pos":base+Vector2(100 if team==0 else -100,(j-1.5)*145),"team":team,"type":j+1,"hp":900.0})
func income(delta: float) -> void:
	var vp: Array[int] = [0,0]
	for point in points:
		var owner: int = point.owner
		if owner<0: continue
		if point.type==0: vp[owner]+=1
		if point.type==1: money[owner]+=delta*3.5
		if point.type==2: fuel[owner]+=delta*2.5
	for team in 2:
		money[team]+=delta*1.5
		fuel[team]+=delta*.5
		if vp[1-team]>vp[team]: tickets[team]=maxf(0,tickets[team]-delta*(vp[1-team]-vp[team])*1.4)
func cover_factor(at: Vector2, source: Vector2) -> float:
	for r in covers:
		if at.distance_to(r.get_center())<100 and (at.y-r.get_center().y)*(source.y-r.get_center().y)<0: return .42
	return 1.0
func waypoint(at: Vector2, target: Vector2, radius: float) -> Vector2:
	for r in covers:
		var obstacle: Rect2 = r.grow(radius)
		if obstacle.has_point(at): return at+Vector2(0,-50 if at.y<r.get_center().y else 50)
		if crosses(obstacle,at,target):
			var left: Vector2 = obstacle.position-Vector2(20,20)
			var right: Vector2 = obstacle.position+Vector2(obstacle.size.x+20,-20)
			if at.y>r.get_center().y:
				left.y=obstacle.end.y+20
				right.y=left.y
			return left if at.distance_to(left)+left.distance_to(target)<at.distance_to(right)+right.distance_to(target) else right
	return target

func crosses(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var corners: Array[Vector2] = [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: return true
	return false

func add_building(data: Dictionary) -> void:
	data.id=next_building_id
	next_building_id+=1
	buildings.append(data)
func building_by_id(id: int) -> Dictionary:
	for b in buildings:
		if b.id==id: return b
	return {}
