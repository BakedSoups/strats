class_name BattleVision
extends RefCounted
const CELL: int = 50
const COLS: int = 64
const ROWS: int = 44
var field: Battlefield
var units: Array[CombatUnit]
var visible: Array[PackedByteArray] = []
var explored: Array[PackedByteArray] = []
var known_buildings: Array[Dictionary] = [{},{}]
var fog_texture: ImageTexture
func _init(map: Battlefield, army: Array[CombatUnit]) -> void:
	field=map; units=army
	for team in 2:
		var current: PackedByteArray = PackedByteArray(); current.resize(COLS*ROWS); current.fill(0); visible.append(current)
		var memory: PackedByteArray = PackedByteArray(); memory.resize(COLS*ROWS); memory.fill(0); explored.append(memory)
	fog_texture=ImageTexture.create_from_image(Image.create(COLS,ROWS,false,Image.FORMAT_RGBA8))
func can_see(team: int, at: Vector2) -> bool:
	for u in units:
		if u.team==team and not u.loaded and u.hp>0 and u.pos.distance_squared_to(at)<=float(u.stats.sight)*float(u.stats.sight):
			if u.spec.flying or not field.line_blocked(u.pos,at): return true
	for b in field.buildings:
		if b.team!=team or b.hp<=0 or b.get("construction",0.0)>0: continue
		var radius: float = 500 if b.type==0 else 300
		if b.pos.distance_squared_to(at)<=radius*radius and not field.line_blocked(b.pos,at): return true
	for p in field.points:
		if p.owner==team and p.pos.distance_squared_to(at)<=130*130 and not field.line_blocked(p.pos,at): return true
	return false
func was_explored(team: int, at: Vector2) -> bool:
	var cell: Vector2i = Vector2i(at/CELL).clamp(Vector2i.ZERO,Vector2i(COLS-1,ROWS-1))
	return explored[team][cell.y*COLS+cell.x]!=0
func refresh() -> void:
	for team in 2:
		visible[team].fill(0)
		for u in units:
			if u.team==team and not u.loaded and u.hp>0: reveal(team,u.pos,u.stats.sight,u.spec.flying)
		for b in field.buildings:
			if b.team==team and b.hp>0 and b.get("construction",0.0)<=0: reveal(team,b.pos,500 if b.type==0 else 300,false)
		for p in field.points:
			if p.owner==team: reveal(team,p.pos,130,false)
		for b in field.buildings:
			if b.team==team or not can_see(team,b.pos): continue
			if b.hp>0: known_buildings[team][b.id]={"pos":b.pos,"type":b.type,"team":b.team}
			else: known_buildings[team].erase(b.id)
	var pixels: Image = Image.create(COLS,ROWS,false,Image.FORMAT_RGBA8)
	for y in ROWS:
		for x in COLS:
			var index: int = y*COLS+x
			pixels.set_pixel(x,y,Color(0.03,.05,.065,0 if visible[0][index]!=0 else (.58 if explored[0][index]!=0 else .97)))
	fog_texture.update(pixels)
func reveal(team: int, origin: Vector2, radius: float, aerial: bool) -> void:
	var first: Vector2i = Vector2i((origin-Vector2.ONE*radius)/CELL).clamp(Vector2i.ZERO,Vector2i(COLS-1,ROWS-1))
	var last: Vector2i = Vector2i((origin+Vector2.ONE*radius)/CELL).clamp(Vector2i.ZERO,Vector2i(COLS-1,ROWS-1))
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var index: int = y*COLS+x
			if visible[team][index]!=0: continue
			var at: Vector2 = Vector2(x+.5,y+.5)*CELL
			if origin.distance_squared_to(at)>radius*radius: continue
			if not aerial and field.line_blocked(origin,at): continue
			visible[team][index]=1; explored[team][index]=1
