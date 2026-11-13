extends Node2D
const BLUE: Color = Color("53b8ed")
const RED: Color = Color("ed6e6c")
const INK: Color = Color("24383e")
const CREAM: Color = Color("dfebdf")
var specs: Array[UnitSpec] = []
var upgrades: Array[UpgradeSpec] = []
var units: Array[CombatUnit] = []
var selected: Array[CombatUnit] = []
var active: CombatUnit
var field: Battlefield = Battlefield.new()
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var fire_zones: Array[Dictionary] = []
var groups: Dictionary = {}
var camera_pos: Vector2 = Vector2(1040,900)
var zoom_level: float = .66
var elapsed: float = 0
var ai_clock: float = 0
var running: bool = false
var ended: bool = false
var attack_mode: bool = false
var drag_start: Vector2
var dragging: bool = false
var hud: CanvasLayer
var resource_label: Label
var info: Label
var order_label: Label
var selection_row: GridContainer
var upgrades_box: VBoxContainer
var queue_label: Label
var menu: Panel
var toast_label: Label
var toast_time: float = 0
var refresh_clock: float = 0
var recruit_buttons: Array[Button] = []
var upgrade_buttons: Array[Button] = []
var health_bar: ProgressBar
var preferences: GameSettings = GameSettings.new()
var settings_menu: SettingsMenu
var settings_was_running: bool = false
var command_buttons: Array[Button] = []
var controls_hint: Label
var selected_building: Dictionary = {}
var portrait: UnitPortrait
var context_title: Label
var production_title: Label
var actions_panel: Control
var upgrades_panel: Control
var production_panel: Control
var selection_panel: Control
var production_grid: GridContainer
var base_grid: GridContainer
var build_toggle: Button
var upgrade_toggle: Button
var build_mode: bool = false
var demo: bool = false
var demo_stage: int = 0
var mouse_world: Vector2:
	get: return screen_to_world(get_viewport().get_mouse_position())
func _ready() -> void:
	preferences.load_saved()
	preferences.apply()
	for i in 12: specs.append(load("res://data/unit_%d.tres"%i))
	for i in 17: upgrades.append(load("res://data/upgrade_%d.tres"%i))
	RenderingServer.set_default_clear_color(Color("788b80"))
	build_ui()
	for team in 2:
		for k in [0,0,1,2,3,4,7,8,9,10,11]:
			var at: Vector2 = Vector2(560+randf()*220,570+randf()*660) if team==0 else Vector2(1820+randf()*220,570+randf()*660)
			spawn(k,team,at)
	selected.clear()
	active=null
	refresh_panel()
	if "--demo" in OS.get_cmdline_user_args(): start_match(); demo=true
func spawn(kind: int, team: int, at: Vector2) -> CombatUnit:
	var u: CombatUnit = CombatUnit.new(specs[kind],kind,team,at)
	units.append(u)
	return u
func start_match() -> void:
	running=true
	menu.hide()
	toast("Capture sectors. Outflank cover. Hold the three victory rings.")
func screen_to_world(at: Vector2) -> Vector2:
	return (at-Vector2(720,335))/zoom_level+camera_pos
func world_to_screen(at: Vector2) -> Vector2:
	return (at-camera_pos)*zoom_level+Vector2(720,335)
func toast(message: String) -> void:
	toast_label.text=message
	toast_time=4
func _process(delta: float) -> void:
	if not running: return
	elapsed+=delta
	toast_time-=delta
	toast_label.visible=toast_time>0
	var motion: Vector2 = Input.get_vector("strats_camera_left","strats_camera_right","strats_camera_up","strats_camera_down")
	if preferences.values.edge_scrolling and DisplayServer.window_is_focused() and not dragging:
		var pointer: Vector2 = get_viewport().get_mouse_position()
		if pointer.y>=60 and pointer.y<610:
			if pointer.x>=0 and pointer.x<12: motion.x-=1
			if pointer.x>1428 and pointer.x<1440: motion.x+=1
		if pointer.x>=0 and pointer.x<1180:
			if pointer.y>=60 and pointer.y<72: motion.y-=1
			if pointer.y>598 and pointer.y<610: motion.y+=1
	camera_pos+=motion.limit_length()*delta*float(preferences.values.camera_speed)/zoom_level
	camera_pos=camera_pos.clamp(Vector2(300,240),Vector2(2300,1560))
	if not ended:
		field.income(delta)
		tick_capture(delta)
		tick_units(delta)
		tick_shots(delta)
		tick_production(delta)
		ai_clock-=delta
		if ai_clock<=0: ai_clock=3.0; tick_ai()
		for t in 2:
			if field.tickets[t]<=0: finish(1-t)
	for i in range(effects.size()-1,-1,-1):
		effects[i].life-=delta
		effects[i].pos+=effects[i].vel*delta
		if effects[i].life<=0: effects.remove_at(i)
	for i in range(fire_zones.size()-1,-1,-1):
		fire_zones[i].life-=delta
		for u in units:
			if not u.spec.flying and u.team!=fire_zones[i].team and u.pos.distance_to(fire_zones[i].pos)<50: u.burn=2
		if fire_zones[i].life<=0: fire_zones.remove_at(i)
	refresh_clock-=delta
	if refresh_clock<=0:
		refresh_clock=.3
		refresh_hud()
	if demo: tick_demo()
	queue_redraw()
func tick_capture(delta: float) -> void:
	for p in field.points:
		var count: Array[int] = [0,0]
		var presence: Array[bool] = [false,false]
		for u in units:
			if not u.loaded and u.pos.distance_to(p.pos)<100:
				presence[u.team]=true
				if u.spec.infantry: count[u.team]+=1
		var side: int = 0 if count[0]>0 and not presence[1] else (1 if count[1]>0 and not presence[0] else -1)
		if side>=0 and p.owner!=side:
			if p.capturer!=side: p.progress=0.0; p.capturer=side
			p.progress+=delta*.095
			if p.progress>=1: p.owner=side; p.progress=0.0
func tick_units(delta: float) -> void:
	for u in units:
		if u.loaded: continue
		u.cooldown-=delta
		u.ability_cooldown=maxf(0,u.ability_cooldown-delta)
		u.burn=maxf(0,u.burn-delta)
		u.suppressed=maxf(0,u.suppressed-delta)
		if u.burn>0: u.hp-=delta*u.burn_dps
		var base: Vector2 = field.buildings[u.team*5].pos
		if u.pos.distance_to(base)<170:
			var restore: float = minf(u.stats.hp-u.hp,delta*16)
			if field.money[u.team]>=restore*.35:
				u.hp+=restore
				field.money[u.team]-=restore*.35
			if u.retreating and u.hp>=u.stats.hp*.9: u.retreating=false; u.status="Defending"
		var target: CombatUnit = null
		var best: float = u.stats.reach
		if not u.retreating:
			for other in units:
				if other.team==u.team or other.loaded: continue
				if other.spec.flying and u.kind not in [0,1,6,9,11]: continue
				var distance: float = u.pos.distance_to(other.pos)
				if distance>u.spec.sight and not spotted(u.team,other.pos): continue
				if distance<best: best=distance; target=other
		if target==null and not u.retreating:
			for b in field.buildings:
				if b.team!=u.team and b.hp>0 and u.pos.distance_to(b.pos)<u.stats.reach:
					u.angle=(b.pos-u.pos).angle()
					if u.cooldown<=0:
						shots.append({"pos":u.pos,"start":u.pos,"end":b.pos,"vel":Vector2.ZERO,"kind":u.kind,"time":0.0,"duration":.45,"building":b,"damage":u.stats.damage,"rocket":false})
						u.cooldown=u.stats.reload
					break
		var moving: bool = u.pos.distance_to(u.goal)>12
		if target!=null:
			var aim: float = (target.pos-u.pos).angle()
			u.angle=lerp_angle(u.angle,aim,minf(1,delta*6))
			if u.attack_move: moving=false
			if u.cooldown<=0 and u.setup>=u.stats.setup and absf(angle_difference(u.hull,aim))<=u.spec.weapon.firing_arc/2:
				shoot(u,target)
				u.cooldown=u.stats.reload*pow(.93,u.level)
				u.burst+=1
				if u.kind==1 and u.burst>=30: u.cooldown=2.3; u.burst=0
				if u.kind==8 and u.burst>=(65 if 13 in u.purchased else 35): u.cooldown=2; u.burst=0
		else:
			u.angle=lerp_angle(u.angle,u.hull,delta*2)
		if moving:
			u.setup=0
			var to: Vector2 = u.goal if u.spec.flying else field.waypoint(u.pos,u.goal,15 if u.spec.infantry else 27)
			var direction: Vector2 = (to-u.pos).normalized()
			u.hull=lerp_angle(u.hull,direction.angle(),delta*5)
			u.pos+=direction*u.stats.speed*delta*(.35 if u.suppressed>0 else 1.0)*(1.45 if u.retreating else 1.0)
		else:
			u.setup+=delta
			if target!=null and u.setup>2: u.hull=lerp_angle(u.hull,u.angle,delta*.6)
			if u.orders.size()>0 and u.pos.distance_to(u.goal)<20: u.goal=u.orders.pop_front()
		for other in units:
			if other==u or other.loaded or other.spec.flying!=u.spec.flying: continue
			var offset: Vector2 = u.pos-other.pos
			if offset.length()<29 and offset.length()>0: u.pos+=offset.normalized()*delta*23
		if u.kind==2 and u.status=="Repairing":
			for other in units:
				if other.team==u.team and not other.spec.infantry and u.pos.distance_to(other.pos)<130: other.hp=minf(other.stats.hp,other.hp+delta*u.stats.repair)
		var lvl: int = mini(3,int(u.xp/130))
		if lvl>u.level: u.hp=minf(u.stats.hp,u.hp+20); u.level=lvl
	var selection_changed: bool = false
	for i in range(units.size()-1,-1,-1):
		if units[i].hp<=0:
			var dead: CombatUnit = units[i]
			effect(dead.pos,Color("ffbd68"),45,.7)
			for passenger in dead.cargo: passenger.loaded=false; passenger.pos=dead.pos; passenger.hp*=.5
			selection_changed=true
			selected.erase(dead)
			if active==dead: active=selected[0] if selected.size()>0 else null
			units.remove_at(i)
	if selection_changed: refresh_panel()
func shoot(u: CombatUnit, target: CombatUnit) -> void:
	if u.kind==8:
		for v in units:
			var diff: Vector2 = v.pos-u.pos
			if v.team!=u.team and not v.spec.flying and diff.length()<u.stats.reach and absf(angle_difference(u.angle,diff.angle()))<.48:
				damage(v,u.stats.damage*(.15 if not v.spec.infantry else 1),u,true)
				v.burn=u.spec.weapon.burn_duration
				v.burn_dps=u.spec.weapon.burn_damage*(1.6 if 12 in u.purchased else 1.0)
		for j in 7:
			var dir: Vector2 = Vector2.from_angle(u.angle+randf_range(-.25,.25))
			effects.append({"pos":u.pos+dir*35,"vel":dir*randf_range(130,260),"life":.65,"max":.65,"size":randf_range(10,21),"color":Color("ffae43"),"flame":true})
		if randf()<.2: fire_zones.append({"pos":target.pos,"team":u.team,"life":3.0})
	else:
		shots.append({"pos":u.pos+Vector2.from_angle(u.angle)*24,"start":u.pos,"target":target,"end":target.pos,"team":u.team,"source":u,"damage":u.stats.damage,"air":target.spec.flying,"rocket":u.kind==9 and 14 in u.purchased,"kind":u.kind,"time":0.0,"duration":.9 if u.kind==4 else .5,"vel":(target.pos-u.pos).normalized()*u.spec.weapon.projectile_speed})
func damage(v: CombatUnit, amount: float, source: CombatUnit, bypass: bool=false) -> void:
	var protection: float = 1.0
	if not bypass:
		if v.spec.infantry: protection=field.cover_factor(v.pos,source.pos)
		else:
			var facing: float = absf(angle_difference(v.hull,(source.pos-v.pos).angle()))
			protection=100.0/(100+v.stats.armor*(3.2 if facing<.9 else (1.6 if facing<2 else .55)))
	if source.kind in [3,5] and v.spec.infantry: amount*=.3
	if source.kind==11 and v.spec.flying: amount*=2.3
	if source.kind==9 and 14 in source.purchased and not v.spec.infantry: amount*=1.5
	v.hp-=amount*protection*pow(.95,v.level)
	source.xp+=amount*.28
	if source.kind==1 and v.spec.infantry: v.suppressed=2.5
func tick_shots(delta: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var s: Dictionary = shots[i]
		s.time+=delta
		var hit: bool = false
		if s.has("building"):
			s.pos=s.start.lerp(s.end,minf(1,s.time/s.duration))
			if s.time>=s.duration:
				s.building.hp-=s.damage
				effect(s.end,Color("ffd18a"),32,.3)
				if s.building.hp<=0 and s.building.type==0: finish(1-s.building.team)
				shots.remove_at(i)
			continue
		if s.kind==4:
			s.pos=s.start.lerp(s.end,minf(1,s.time/s.duration))
			if s.time>=s.duration:
				for u in units:
					if u.team!=s.team and not u.spec.flying and u.pos.distance_to(s.end)<s.source.spec.weapon.splash_radius*(1.3 if 6 in s.source.purchased else 1.0): damage(u,s.damage,s.source,true)
				effect(s.end,Color("ffd18a"),95,.6)
				hit=true
		else:
			var before: Vector2 = s.pos
			s.pos+=s.vel*delta*(.65 if s.rocket else 1.0)
			for u in units:
				if u.spec.flying!=s.air: continue
				if u.team!=s.team and not u.loaded and Geometry2D.get_closest_point_to_segment(u.pos,before,s.pos).distance_to(u.pos)<(20 if u.spec.infantry else 29):
					damage(u,s.damage,s.source)
					effect(s.pos,Color("ffdc9a"),18,.18)
					hit=true
					break
		if hit or s.time>3: shots.remove_at(i)
func effect(at: Vector2, color: Color, size: float, life: float) -> void:
	effects.append({"pos":at,"vel":Vector2.ZERO,"life":life,"max":life,"size":size,"color":color,"flame":false})
func tick_production(delta: float) -> void:
	for b in field.buildings:
		if b.hp<=0: continue
		if b.get("construction",0.0)>0: b.construction=maxf(0,b.construction-delta)
		if b.type==5 and b.get("construction",0.0)<=0:
			b.cooldown=b.get("cooldown",0.0)-delta
			if b.cooldown<=0:
				for u in units:
					if u.team!=b.team and not u.spec.flying and u.pos.distance_to(b.pos)<320:
						u.hp-=12*(field.cover_factor(u.pos,b.pos) if u.spec.infantry else 1.0); b.cooldown=.35; effect(u.pos,Color("ffdc9a"),12,.15); break
	var busy: Array[String] = []
	var completed: Array[Dictionary] = []
	for q in field.queues:
		var building: Dictionary = field.building_by_id(q.producer)
		if building.is_empty() or building.hp<=0:
			field.money[q.team]+=specs[q.kind].manpower
			field.fuel[q.team]+=specs[q.kind].fuel
			completed.append(q); continue
		var production_id: String = str(q.producer)
		if production_id in busy: continue
		busy.append(production_id)
		q.left-=delta
		if q.left<=0:
			var u: CombatUnit = spawn(q.kind,q.team,building.pos+Vector2(80 if q.team==0 else -80,randf_range(-50,50)))
			if q.team==1: u.command(Vector2(1300,900))
			completed.append(q)
	for q in completed: field.queues.erase(q)
func production_type(kind: int) -> int:
	if kind<=3: return 1
	if kind<=5 or kind==11: return 2
	return 4 if kind in [9,10] else 3
func recruit(kind: int, team: int=0, producer: int=-1) -> void:
	var s: UnitSpec = specs[kind]
	var building: Dictionary = field.building_by_id(producer)
	if producer<0:
		for b in field.buildings:
			if b.team==team and b.type==production_type(kind) and b.hp>0 and b.get("construction",0.0)<=0: building=b; break
	if building.is_empty() or building.team!=team or building.type!=production_type(kind) or building.hp<=0 or building.get("construction",0.0)>0: return
	if field.money[team]<s.manpower or field.fuel[team]<s.fuel: return
	field.money[team]-=s.manpower
	field.fuel[team]-=s.fuel
	field.queues.append({"producer":building.id,"team":team,"kind":kind,"left":5.0+s.fuel*.055})
	if team==0: toast("Queued: "+s.title)
func tick_ai() -> void:
	var enemy_count: int = 0
	var aircraft: int = 0
	for u in units:
		if u.team==0 and u.spec.flying: aircraft+=1
		if u.team!=1: continue
		enemy_count+=1
		if u.hp<u.stats.hp*.28: retreat(u); continue
		if u.retreating: continue
		var best: Vector2 = Vector2(1300,900)
		var score: float = INF
		for p in field.points:
			var value: float = u.pos.distance_to(p.pos)+(500 if p.owner==1 else 0)-(160 if p.type==0 else 0)
			if value<score: score=value; best=p.pos
		if u.spec.infantry: u.command(best+Vector2(randf_range(-40,40),randf_range(-40,40)))
		else: u.command(best+Vector2(-90,randf_range(-120,120)))
		if u.spec.infantry and u.pos.distance_to(best)<180 and randf()<.45:
			for r in field.covers:
				if r.get_center().distance_to(best)<180: u.command(r.get_center()+Vector2(0,-40))
		if randf()<.3:
			for id in options(u):
				if buy_upgrade(u,id): break
	if field.money[1]>400 and field.fuel[1]>70 and randf()<.2:
		var base: Vector2 = field.buildings[5].pos
		field.money[1]-=150; field.fuel[1]-=30
		field.add_building({"pos":base+Vector2(-200,randf_range(-500,500)),"team":1,"type":5,"hp":900.0,"construction":12.0})
	if enemy_count<24 and field.queues.size()<6: recruit(11 if aircraft>1 and randf()<.45 else [0,1,2,3,4,7,8,9].pick_random(),1)
func retreat(u: CombatUnit) -> void:
	u.command(field.buildings[u.team*5].pos,false,false)
	u.retreating=true
	u.status="Retreating / reinforcing"
func options(u: CombatUnit) -> Array:
	match u.kind:
		0: return [0,1]
		1: return [2,3,1]
		2: return [4,1]
		3: return [5,7,1]
		5,11: return [5,7,8]
		4: return [6,7]
		6,7: return [8,9,10]
		8: return [11,12,13,8]
		9: return [14,15]
		10: return [16,15]
	return []
func buy_upgrade(u: CombatUnit, id: int) -> bool:
	var up: UpgradeSpec = upgrades[id]
	if not can_upgrade(u,id): return false
	field.money[u.team]-=up.manpower
	field.fuel[u.team]-=up.fuel
	u.upgrade(id,up)
	return true
func finish(winner: int) -> void:
	ended=true
	menu.show()
	menu.get_node("Title").text="VICTORY" if winner==0 else "DEFEAT"
	menu.get_node("Subtitle").text="The battlefield belongs to Azure Command." if winner==0 else "Crimson Command controls the territory."
func tick_demo() -> void:
	if demo_stage==0:
		camera_pos=Vector2(1300,900)
		var counts: Array[int] = [0,0]
		for u in units:
			var slot: int = counts[u.team]
			counts[u.team]+=1
			u.pos=Vector2(1060+slot%3*38 if u.team==0 else 1460+slot%3*38,750+(slot/3)*85)
			u.goal=u.pos
		for u in units:
			u.command(Vector2(1230 if u.team==0 else 1370,780+randf()*250))
		selected.clear()
		for u in units:
			if u.team==0 and u.kind==8: selected.append(u); active=u
		refresh_panel()
		recruit(0); recruit(7); recruit(9)
		demo_stage=1
	if int(elapsed*30)%90==0:
		for u in units:
			if not u.retreating: u.command(Vector2(1270 if u.team==0 else 1330,800+(u.kind%4)*65))
	if elapsed>5 and demo_stage==1:
		buy_upgrade(active,11)
		toast("PRESSURIZED FUEL purchased • Flame reach +40%")
		refresh_panel()
		demo_stage=2
	if elapsed>10 and demo_stage==2:
		for u in units:
			if u.team==0 and u.kind==9: selected.assign([u]); active=u; break
		if active==null and units.size()>0:
			for u in units:
				if u.team==0: selected.assign([u]); active=u; break
		toast("Reinforcements deploying • Combined arms advance")
		refresh_panel()
		demo_stage=3
	if elapsed>13 and demo_stage==3:
		for u in units:
			if u.team==0 and u.kind==9:
				selected.assign([u]); active=u; u.command(Vector2(1300,900)); camera_pos=u.pos.lerp(Vector2(1300,900),.5); refresh_panel(); demo_stage=4; break
func _draw() -> void:
	draw_set_transform(Vector2(720,335)-camera_pos*zoom_level,0,Vector2.ONE*zoom_level)
	draw_rect(Rect2(Vector2.ZERO,field.SIZE),Color("83958a"))
	for x in range(0,2601,80): draw_line(Vector2(x,0),Vector2(x,1800),Color("7b8e83"),1)
	for y in range(0,1801,80): draw_line(Vector2(0,y),Vector2(2600,y),Color("7b8e83"),1)
	for y in [450,900,1350]:
		draw_line(Vector2(200,y),Vector2(2400,y),Color("94a297"),105)
		draw_dashed_line(Vector2(220,y),Vector2(2380,y),Color("b3bbae"),2,25)
	draw_line(Vector2(1300,100),Vector2(1300,1700),Color("94a297"),85)
	for b in field.buildings:
		var col: Color = BLUE if b.team==0 else RED
		if b.hp<=0: col=Color("53645e")
		var r: Rect2 = Rect2(b.pos-Vector2(43,36),Vector2(86,72))
		if not selected_building.is_empty() and b.id==selected_building.id: draw_rect(r.grow(10),Color("b7f5ed"),false,3)
		draw_rect(r.grow(4),INK)
		draw_rect(r,col.darkened(.25))
		if b.get("construction",0.0)>0:
			draw_arc(b.pos,55,0,TAU*(1-b.construction/12.0),32,CREAM,4,true)
		draw_rect(r.grow(-12),col)
		draw_string(ThemeDB.fallback_font,b.pos+Vector2(-36,58),["HQ","BARRACKS","SUPPORT","DEPOT","HELIPAD","EMPLACEMENT"][b.type],HORIZONTAL_ALIGNMENT_LEFT,-1,14,CREAM)
	for i in field.points.size():
		var p: Dictionary = field.points[i]
		var col: Color = CREAM if p.owner<0 else (BLUE if p.owner==0 else RED)
		draw_circle(p.pos,88,Color(col,.08))
		draw_arc(p.pos,72,0,TAU,64,INK,9,true)
		draw_arc(p.pos,72,0,TAU,64,col,5,true)
		if p.progress>0: draw_arc(p.pos,81,-PI/2,-PI/2+p.progress*TAU,48,BLUE if p.capturer==0 else RED,5,true)
		draw_circle(p.pos,25,INK)
		draw_string(ThemeDB.fallback_font,p.pos+Vector2(-14,6),["VP","+M","+F"][p.type],HORIZONTAL_ALIGNMENT_LEFT,-1,18,col)
	for r in field.covers:
		draw_rect(r.grow(4),INK)
		draw_rect(r,Color("bbc1b3"))
		for x in range(int(r.position.x)+12,int(r.end.x),26): draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color("85948a"),3)
	for z in fire_zones:
		draw_circle(z.pos,46,Color(1,.4,.1,.13))
	for u in selected:
		if u.loaded: continue
		if u==active: draw_arc(u.pos,u.stats.reach,0,TAU,80,Color(BLUE,.12),2,true)
		if u.pos.distance_to(u.goal)>20:
			draw_dashed_line(u.pos,u.goal,Color(BLUE,.7),2,9)
			draw_arc(u.goal,12,0,TAU,24,BLUE,2,true)
		var prior: Vector2 = u.goal
		for dest in u.orders: draw_dashed_line(prior,dest,BLUE,2,8); prior=dest
	for u in units:
		if not u.loaded and not u.spec.flying: draw_unit(u)
	for u in units:
		if not u.loaded and u.spec.flying: draw_unit(u)
	for s in shots:
		var at: Vector2 = s.pos
		if s.kind==4:
			draw_circle(at,7,Color(INK,.25))
			at.y-=sin(s.time/s.duration*PI)*120
		if s.rocket: draw_line(at,at-s.vel.normalized()*18,Color("ffbd72"),5)
		draw_circle(at,7 if s.kind in [3,4,5,7] or s.rocket else 4,INK)
		draw_circle(at,4 if s.kind in [3,4,5,7] else 2,Color("ffe0a1"))
	for e in effects:
		var ratio: float = e.life/e.max
		var color: Color = e.color
		color.a=ratio*.8
		draw_circle(e.pos,e.size*(ratio if e.flame else 1-ratio*.75),color)
		if e.flame: draw_circle(e.pos,e.size*ratio*.45,Color(1,.9,.35,ratio))
	draw_set_transform(Vector2.ZERO)
	if dragging:
		var r: Rect2 = Rect2(drag_start,get_viewport().get_mouse_position()-drag_start).abs()
		draw_rect(r,Color(BLUE,.12))
		draw_rect(r,BLUE,false,1)
	draw_minimap()
func draw_unit(u: CombatUnit) -> void:
	var col: Color = BLUE if u.team==0 else RED
	var at: Vector2 = u.pos
	if u in selected: draw_arc(at,34 if not u.spec.infantry else 25,0,TAU,32,Color("b7f5ed"),3,true)
	if u.spec.flying:
		draw_circle(at+Vector2(13,23),30,Color(INK,.2))
		at.y-=22+sin(elapsed*3+u.pos.x)*4
	if u.spec.infantry:
		for offset in [Vector2(-11,10),Vector2(11,10)]:
			draw_circle(at+offset,8,INK)
			draw_circle(at+offset,5,col.darkened(.15))
		draw_circle(at,16,INK)
		draw_circle(at,12,col)
		if u.kind==4:
			draw_circle(at,9,Color("bac8bd"))
			draw_line(at,at+Vector2.from_angle(u.angle)*24,INK,11)
		else:
			draw_line(at,at+Vector2.from_angle(u.angle)*28,INK,10 if u.kind==3 else 8)
			draw_line(at,at+Vector2.from_angle(u.angle)*27,Color("b7c7bf"),4)
	else:
		draw_set_transform(Vector2(720,335)-camera_pos*zoom_level+at*zoom_level,u.hull,Vector2.ONE*zoom_level)
		if u.spec.flying:
			draw_line(Vector2(-18,0),Vector2(-51,0),INK,10)
			draw_colored_polygon(PackedVector2Array([Vector2(-30,-12),Vector2(-14,-20),Vector2(24,-15),Vector2(33,0),Vector2(24,15),Vector2(-14,20),Vector2(-30,12)]),INK)
			draw_style_box(oval_style(col),Rect2(-26,-15,54,30))
			draw_circle(Vector2(17,0),9,INK)
			draw_circle(Vector2(18,0),6,Color("b3e5db"))
			var rotor: Vector2 = Vector2.from_angle(elapsed*34)*47
			draw_line(-rotor,rotor,Color(INK,.7),5,true)
			draw_line(-rotor.orthogonal(),rotor.orthogonal(),Color(INK,.7),5,true)
			var tail: Vector2 = Vector2.from_angle(elapsed*49)*13
			draw_line(Vector2(-47,0)-tail,Vector2(-47,0)+tail,CREAM,3,true)
			draw_circle(Vector2.ZERO,6,INK)
		else:
			draw_rect(Rect2(-32,-25,64,50),INK)
			draw_rect(Rect2(-28,-21,56,42),col)
			draw_rect(Rect2(-31,-28,60,9),Color("435851"))
			draw_rect(Rect2(-31,19,60,9),Color("435851"))
			draw_circle(Vector2.ZERO,17,INK)
			draw_circle(Vector2.ZERO,13,col.lightened(.12))
			draw_set_transform(Vector2(720,335)-camera_pos*zoom_level+at*zoom_level,u.angle,Vector2.ONE*zoom_level)
			draw_line(Vector2.ZERO,Vector2(42 if u.kind!=8 else 30,0),INK,13 if u.kind==8 else 9)
			if u.kind==8: draw_line(Vector2(18,0),Vector2(32,0),Color("edba66"),7)
		draw_set_transform(Vector2(720,335)-camera_pos*zoom_level,0,Vector2.ONE*zoom_level)
	draw_rect(Rect2(at+Vector2(-23,-39),Vector2(46,6)),INK)
	draw_rect(Rect2(at+Vector2(-22,-38),Vector2(44*maxf(0,u.hp/u.stats.hp),4)),col)
	if u.burn>0: draw_circle(at+Vector2(0,-16),10,Color(1,.5,.05,.7))
	if u.suppressed>0: draw_string(ThemeDB.fallback_font,at+Vector2(-15,-47),"PIN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffe39b"))
	if u.level>0: draw_string(ThemeDB.fallback_font,at+Vector2(-10,42),"★".repeat(u.level),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffe39b"))
func oval_style(col: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color=col
	s.set_corner_radius_all(15)
	return s
func draw_minimap() -> void:
	var origin: Vector2 = Vector2(1184,72)
	var scale_map: float = .085
	draw_rect(Rect2(origin-Vector2(6,6),Vector2(233,165)),INK)
	draw_rect(Rect2(origin,field.SIZE*scale_map),Color("72887d"))
	for p in field.points: draw_circle(origin+p.pos*scale_map,4,CREAM if p.owner<0 else (BLUE if p.owner==0 else RED))
	for u in units:
		if not u.loaded: draw_circle(origin+u.pos*scale_map,2.5,BLUE if u.team==0 else RED)
	var top: Vector2 = screen_to_world(Vector2(0,60))
	var view_box: Rect2 = Rect2(origin+top*scale_map,Vector2(1440,550)/zoom_level*scale_map).intersection(Rect2(origin,field.SIZE*scale_map))
	draw_rect(view_box,Color(CREAM,.7),false,1)
func _unhandled_input(event: InputEvent) -> void:
	if settings_menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: menu.visible=not menu.visible; running=not menu.visible; dragging=false; return
		if not running: return
		if event.is_action_pressed("strats_attack_move"): action(1)
		if event.is_action_pressed("strats_stop"):
			for u in selected: u.command(u.pos); u.status="Stopped"
		if event.is_action_pressed("strats_retreat"):
			for u in selected: retreat(u)
		if event.keycode>=KEY_0 and event.keycode<=KEY_9:
			var id: int = event.keycode-KEY_0
			if event.ctrl_pressed: groups[id]=selected.duplicate()
			elif groups.has(id):
				selected.clear()
				selected_building={}
				for u in groups[id]:
					if u in units: selected.append(u)
				active=selected[0] if selected.size()>0 else null
				refresh_panel()
	if not running: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom_level=minf(1.2,zoom_level*pow(1.1,float(preferences.values.zoom_sensitivity)))
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom_level=maxf(.4,zoom_level/pow(1.1,float(preferences.values.zoom_sensitivity)))
		if event.position.y>610 or event.position.y<60: return
		if event.position.x>1180 and event.position.y<240 and event.pressed:
			camera_pos=((event.position-Vector2(1184,72))/.085).clamp(Vector2(300,240),Vector2(2300,1560)); return
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: issue(mouse_world,event.shift_pressed,attack_mode); attack_mode=false
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if attack_mode: issue(mouse_world,event.shift_pressed,true); attack_mode=false; return
				drag_start=event.position; dragging=true
			elif dragging:
				dragging=false
				if not event.shift_pressed: selected.clear()
				var rect: Rect2 = Rect2(drag_start,event.position-drag_start).abs()
				var closest: CombatUnit = null
				var distance: float = 35
				for u in units:
					if u.team!=0 or u.loaded: continue
					var screen: Vector2 = world_to_screen(u.pos)
					if rect.size.length()>12:
						if rect.has_point(screen) and u not in selected: selected.append(u)
					elif screen.distance_to(event.position)<distance: closest=u; distance=screen.distance_to(event.position)
				if closest!=null and closest not in selected: selected.append(closest)
				selected_building={}
				if closest==null and rect.size.length()<=12:
					for b in field.buildings:
						if b.team==0 and b.hp>0 and Rect2(world_to_screen(b.pos)-Vector2(48,42)*zoom_level,Vector2(96,84)*zoom_level).has_point(event.position):
							select_building(b); return
				active=selected[0] if selected.size()>0 else null
				refresh_panel()
func issue(at: Vector2, queued: bool, aggressive: bool) -> void:
	var enemy: bool = false
	for u in units:
		if u.team==1 and u.pos.distance_to(at)<45: enemy=true
	for i in selected.size():
		var offset: Vector2 = Vector2((i%4-1.5)*40,(i/4)*40)
		selected[i].command((at+offset).clamp(Vector2(30,30),field.SIZE-Vector2(30,30)),queued,aggressive or enemy)
func build_ui() -> void:
	hud=CanvasLayer.new(); add_child(hud)
	var top: Panel = panel(Rect2(0,0,1440,60),Color("1d3036")); hud.add_child(top)
	label_at(top,"S T R A T S",Vector2(24,13),26,BLUE)
	resource_label=label_at(top,"",Vector2(240,17),20,CREAM)
	button("Settings",Vector2(1288,12),Vector2(125,35),top).pressed.connect(open_settings)
	toast_label=label_at(hud,"",Vector2(385,80),18,CREAM)
	var bottom: Panel = panel(Rect2(0,610,1440,290),Color("1b2d33")); bottom.mouse_filter=Control.MOUSE_FILTER_STOP; hud.add_child(bottom)
	context_title=label_at(bottom,"COMMANDER",Vector2(18,12),14,BLUE)
	portrait=UnitPortrait.new(); portrait.position=Vector2(16,48); portrait.size=Vector2(110,100); bottom.add_child(portrait)
	info=label_at(bottom,"",Vector2(138,47),14,CREAM); info.size=Vector2(208,162); info.clip_text=true
	health_bar=ProgressBar.new(); health_bar.position=Vector2(18,161); health_bar.size=Vector2(108,10); health_bar.show_percentage=false; bottom.add_child(health_bar); configure_health(health_bar)
	var health_style: StyleBoxFlat = StyleBoxFlat.new(); health_style.bg_color=BLUE; health_style.set_corner_radius_all(3); health_bar.add_theme_stylebox_override("fill",health_style)
	var health_background: StyleBoxFlat = StyleBoxFlat.new(); health_background.bg_color=Color("3b5053"); health_bar.add_theme_stylebox_override("background",health_background)
	actions_panel=Control.new(); actions_panel.position=Vector2(365,0); bottom.add_child(actions_panel)
	label_at(actions_panel,"TACTICAL ORDERS",Vector2(0,12),14,BLUE)
	var actions: Array[String] = ["Move [RMB]","Fire in range [A]","Stop [X]","Retreat [R]","Take cover","Special ability"]
	for i in actions.size():
		var b: Button = button(actions[i],Vector2((i%2)*158,46+(i/2)*39),Vector2(150,33),actions_panel)
		b.pressed.connect(action.bind(i)); command_buttons.append(b)
	order_label=label_at(actions_panel,"",Vector2(0,170),13,Color("a6bbb5")); order_label.size=Vector2(315,83); order_label.clip_text=true
	upgrades_panel=Control.new(); upgrades_panel.position=Vector2(705,0); bottom.add_child(upgrades_panel)
	label_at(upgrades_panel,"UNIT UPGRADES",Vector2(0,12),14,BLUE)
	upgrade_toggle=button("Upgrades",Vector2(0,39),Vector2(153,28),upgrades_panel); upgrade_toggle.pressed.connect(func() -> void: set_build_menu(false))
	build_toggle=button("Build",Vector2(160,39),Vector2(153,28),upgrades_panel); build_toggle.pressed.connect(func() -> void: set_build_menu(true))
	var upgrade_scroll: ScrollContainer = ScrollContainer.new(); upgrade_scroll.position=Vector2(0,76); upgrade_scroll.size=Vector2(320,177); upgrade_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; upgrades_panel.add_child(upgrade_scroll)
	upgrades_box=VBoxContainer.new(); upgrades_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; upgrade_scroll.add_child(upgrades_box)
	selection_panel=Control.new(); selection_panel.position=Vector2(1060,0); bottom.add_child(selection_panel)
	label_at(selection_panel,"SELECTED UNITS",Vector2(0,12),14,BLUE)
	var selection_scroll: ScrollContainer = ScrollContainer.new(); selection_scroll.position=Vector2(0,45); selection_scroll.size=Vector2(360,211); selection_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; selection_panel.add_child(selection_scroll)
	selection_row=GridContainer.new(); selection_row.columns=2; selection_scroll.add_child(selection_row)
	production_panel=Control.new(); production_panel.position=Vector2(365,0); bottom.add_child(production_panel)
	production_title=label_at(production_panel,"",Vector2(0,12),14,BLUE)
	var production_scroll: ScrollContainer = ScrollContainer.new(); production_scroll.position=Vector2(0,45); production_scroll.size=Vector2(1058,173); production_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; production_panel.add_child(production_scroll)
	production_grid=GridContainer.new(); production_grid.columns=4; production_scroll.add_child(production_grid)
	for i in specs.size():
		var b: Button = unit_card(i,Vector2(252,78),true); production_grid.add_child(b); b.pressed.connect(recruit_or_build.bind(i)); recruit_buttons.append(b)
	base_grid=GridContainer.new(); base_grid.columns=4; production_scroll.add_child(base_grid)
	queue_label=label_at(production_panel,"",Vector2(0,225),13,CREAM); queue_label.size=Vector2(1040,32); queue_label.clip_text=true
	controls_hint=label_at(bottom,"",Vector2(18,270),12,Color("91aaa2"))
	menu=panel(Rect2(360,170,720,420),Color("1b2d33")); hud.add_child(menu)
	var title: Label = label_at(menu,"S T R A T S",Vector2(65,42),55,BLUE); title.name="Title"
	var subtitle: Label = label_at(menu,"TERRITORY & STEEL  /  TACTICAL RTS",Vector2(69,116),19,CREAM); subtitle.name="Subtitle"
	label_at(menu,"Command combined arms. Capture the three victory rings.\nUse directional cover and flanking routes to break the front.\n\nBlue: Azure Command  /  Red: Crimson Command\nYour army starts deployed; recruit and upgrade from the panel.",Vector2(69,169),18,Color("b7c8bf"))
	button("DEPLOY / RESUME",Vector2(40,325),Vector2(205,54),menu).pressed.connect(start_match)
	button("SETTINGS",Vector2(258,325),Vector2(205,54),menu).pressed.connect(open_settings)
	button("NEW OPERATION",Vector2(476,325),Vector2(205,54),menu).pressed.connect(func() -> void: get_tree().reload_current_scene())
	settings_menu=SettingsMenu.new(preferences)
	hud.add_child(settings_menu)
	settings_menu.closed.connect(close_settings)
	settings_menu.applied.connect(refresh_binding_labels)
	refresh_binding_labels()
func panel(rect: Rect2, color: Color) -> Panel:
	var p: Panel = Panel.new(); p.position=rect.position; p.size=rect.size
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=color; style.border_color=Color("48605f"); style.set_border_width_all(1)
	p.add_theme_stylebox_override("panel",style)
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p
func label_at(parent: Node, text: String, at: Vector2, font_size: int, col: Color) -> Label:
	var l: Label = Label.new(); l.text=text; l.position=at; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",col); l.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(l); return l
func button(text: String, at: Vector2, size_button: Vector2, parent: Node) -> Button:
	var b: Button = Button.new(); b.text=text; b.position=at; b.size=size_button; b.add_theme_font_size_override("font_size",14)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=Color("30494e"); style.border_color=Color("56777a"); style.set_border_width_all(1); style.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal",style)
	parent.add_child(b); return b
func refresh_panel() -> void:
	clear_panel_children(selection_row)
	clear_panel_children(upgrades_box)
	clear_panel_children(base_grid)
	upgrade_buttons.clear()
	if not selected_building.is_empty() and selected_building.hp<=0: selected_building={}
	var unit_mode: bool = active!=null and active in units and selected_building.is_empty()
	if not unit_mode: build_mode=false
	actions_panel.visible=unit_mode
	upgrades_panel.visible=unit_mode
	selection_panel.visible=unit_mode
	production_panel.visible=not unit_mode
	production_grid.visible=not selected_building.is_empty()
	base_grid.visible=selected_building.is_empty()
	portrait.building=not unit_mode
	portrait.kind=active.kind if unit_mode else 0
	portrait.queue_redraw()
	if unit_mode:
		for u in selected:
			var card: Button = unit_card(u.kind,Vector2(171,75),false); card.set_meta("unit",u); selection_row.add_child(card)
			card.pressed.connect(func() -> void: active=u; selected_building={}; refresh_panel())
		build_toggle.visible=active.kind==2
		upgrade_toggle.visible=active.kind==2
		if active.kind!=2: build_mode=false
		if build_mode:
			for i in 5:
				var b: Button = Button.new(); b.text="%s  •  150 Manpower / 30 Fuel"%building_name(i+1); b.custom_minimum_size=Vector2(310,38); b.add_theme_font_size_override("font_size",12); upgrades_box.add_child(b); b.pressed.connect(recruit_or_build.bind(i))
		else:
			for id in options(active):
				var up: UpgradeSpec = upgrades[id]
				var b: Button = Button.new(); b.text="%s\n%d Manpower / %d Fuel  •  %s"%[up.title,up.manpower,up.fuel,up.description]; b.custom_minimum_size=Vector2(310,47); b.add_theme_font_size_override("font_size",12); b.set_meta("id",id); upgrades_box.add_child(b); upgrade_buttons.append(b)
				b.pressed.connect(func() -> void:
					if active!=null and buy_upgrade(active,id): toast(up.title+" installed"); refresh_panel())
	else:
		for b in field.buildings:
			if b.team!=0 or b.hp<=0: continue
			var card: Button = Button.new(); card.text=building_name(b.type)+"\nClick to manage"; card.custom_minimum_size=Vector2(252,76); base_grid.add_child(card); card.pressed.connect(select_building.bind(b))
	refresh_hud()
func refresh_hud() -> void:
	resource_label.text="MANPOWER  %04d     FUEL  %03d        AZURE  %03d   :   %03d  CRIMSON     %02d:%02d"%[field.money[0],field.fuel[0],field.tickets[0],field.tickets[1],int(elapsed)/60,int(elapsed)%60]
	if not selected_building.is_empty() and selected_building.hp<=0: selected_building={}; active=null; refresh_panel(); return
	if active!=null and active in units and selected_building.is_empty():
		context_title.text="UNIT / "+active.spec.title.to_upper()
		health_bar.value=active.hp/active.stats.hp*100
		info.text="%s\nHP %d / %d\nArmor %d  •  Damage %d\nSpeed %d  •  Range %d\nVeterancy %d / 3\nXP %d"%[active.spec.title,active.hp,active.stats.hp,active.stats.armor,active.stats.damage,active.stats.speed,active.stats.reach,active.level,active.xp]
		info.tooltip_text=""
		for id in active.purchased: info.tooltip_text+="Installed: "+upgrades[id].title+"\n"
		order_label.text="ORDER: %s\nWeapon: %s  %.1fs\nAbility ready in %.1fs"%[active.status,"READY" if active.cooldown<=0 else "RELOADING",maxf(0,active.cooldown),active.ability_cooldown]
		command_buttons[4].disabled=not selected.any(func(u: CombatUnit) -> bool: return u.spec.infantry)
		command_buttons[4].tooltip_text="Infantry only: move behind a nearby barricade. Vehicles use their armor."
		command_buttons[5].text="Build / Repair" if active.kind==2 else ("Load / Unload" if active.kind==10 else "Patrol")
		for card in selection_row.get_children():
			var u: CombatUnit = card.get_meta("unit")
			card.get_node("Health").value=maxf(0,u.hp/u.stats.hp*100)
		for b in upgrade_buttons:
			var id: int = b.get_meta("id"); var up: UpgradeSpec = upgrades[id]
			b.disabled=not can_upgrade(active,id)
			b.tooltip_text=up.description+"\nApplies to this unit only."
			if up.prerequisite>=0: b.tooltip_text+="\nRequires "+upgrades[up.prerequisite].title
			if id in active.purchased: b.text="✓ "+up.title+" / INSTALLED"
	elif not selected_building.is_empty():
		context_title.text="BASE / "+building_name(selected_building.type).to_upper()
		info.text="%s\nHP %d / %d\n%s"%[building_name(selected_building.type),selected_building.hp,2400 if selected_building.type==0 else 900,"Constructing: %.0fs"%selected_building.construction if selected_building.get("construction",0.0)>0 else "Operational"]
		health_bar.value=selected_building.hp/(2400 if selected_building.type==0 else 900)*100
		production_title.text="TRAIN UNITS / "+building_name(selected_building.type).to_upper()
	else:
		context_title.text="COMMANDER / AZURE"
		info.text="Azure Command\n%d units deployed\nTickets: %d\nClick a base to recruit.\nClick a unit to command."%[units.filter(func(u: CombatUnit) -> bool: return u.team==0).size(),field.tickets[0]]
		health_bar.value=field.tickets[0]/500*100
		production_title.text="YOUR BASES / SELECT A BUILDING"
	for i in recruit_buttons.size():
		var b: Button = recruit_buttons[i]
		b.visible=not selected_building.is_empty() and production_type(i)==selected_building.type
		b.disabled=field.money[0]<specs[i].manpower or field.fuel[0]<specs[i].fuel or selected_building.get("construction",0.0)>0
	queue_label.text=""
	for q in field.queues:
		if q.team==0 and (selected_building.is_empty() or q.producer==selected_building.id): queue_label.text+="%s %.0fs  "%[specs[q.kind].title,q.left]
	if queue_label.text=="": queue_label.text="Select a base above or on the battlefield." if selected_building.is_empty() else "Queue empty" + (" • This building does not train units." if selected_building.type in [0,5] else "")
func action(id: int) -> void:
	if id==0: attack_mode=false; toast("Right-click to move. Shift queues orders.")
	if id==1: attack_mode=false; toast("Engage targets in weapon range • Hold position")
	for u in selected:
		if id==1:
			u.command(u.pos,false,true)
			u.status="Firing at targets in range"
		if id==2: u.command(u.pos); u.status="Stopped"
		if id==3: retreat(u)
		if id==4:
			if not u.spec.infantry: continue
			var nearest: Vector2 = u.pos
			var distance: float = 240
			for r in field.covers:
				if r.get_center().distance_to(u.pos)<distance: distance=r.get_center().distance_to(u.pos); nearest=r.get_center()+Vector2(0,42 if u.team==0 else -42)
			u.command(nearest); u.status="Taking cover"
		if id==5:
			if u.ability_cooldown>0: toast("Ability recharging: %.0fs"%u.ability_cooldown); continue
			u.ability_cooldown=5
			if u.kind==2:
				if field.money[0]>=45: field.money[0]-=45; field.covers.append(Rect2(u.pos+Vector2(-65,-42),Vector2(130,20))); u.status="Repairing"; toast("Barricade built • Repairing nearby vehicles")
			elif u.kind==10:
				if u.cargo.size()>0:
					for passenger in u.cargo: passenger.loaded=false; passenger.pos=u.pos+Vector2(randf_range(-60,60),50); passenger.goal=passenger.pos
					u.cargo.clear(); toast("Troops deployed")
				else:
					for passenger in units:
						if passenger.team==u.team and passenger.spec.infantry and not passenger.loaded and passenger.pos.distance_to(u.pos)<160 and u.cargo.size()<3: passenger.loaded=true; u.cargo.append(passenger)
					toast("Transport loaded: %d squads"%u.cargo.size())
			else: u.attack_move=true; u.status="Patrolling"; u.orders.append(u.pos); u.goal=u.pos+Vector2(150,0)
	refresh_panel()

func has_building(team: int, kind: int) -> bool:
	for b in field.buildings:
		if b.team==team and b.type==kind and b.hp>0 and b.get("construction",0.0)<=0: return true
	return false
func set_build_menu(enabled: bool) -> void:
	build_mode=enabled
	refresh_panel()
func recruit_or_build(id: int) -> void:
	if not build_mode:
		if not selected_building.is_empty(): recruit(id,0,selected_building.id)
		return
	if active==null or active.kind!=2: toast("Select Engineers to construct a building"); return
	if field.money[0]<150 or field.fuel[0]<30: return
	field.money[0]-=150; field.fuel[0]-=30
	field.add_building({"pos":active.pos+Vector2(0,-95),"team":0,"type":id+1,"hp":900.0,"construction":12.0})
	toast("Construction started • 12 seconds")

func can_upgrade(u: CombatUnit, id: int) -> bool:
	var up: UpgradeSpec = upgrades[id]
	return id not in u.purchased and field.money[u.team]>=up.manpower and field.fuel[u.team]>=up.fuel and (up.prerequisite<0 or up.prerequisite in u.purchased) and has_building(u.team,up.building)

func spotted(team: int, at: Vector2) -> bool:
	for observer in units:
		if observer.team==team and not observer.loaded and observer.pos.distance_to(at)<=observer.spec.sight: return true
	return false

func open_settings() -> void:
	if settings_menu.visible: return
	settings_was_running=running
	running=false
	dragging=false
	attack_mode=false
	settings_menu.open_menu()
func close_settings() -> void:
	running=settings_was_running
func refresh_binding_labels() -> void:
	command_buttons[1].text="Fire in range [%s]"%preferences.key_label("attack_move")
	command_buttons[2].text="Stop [%s]"%preferences.key_label("stop")
	command_buttons[3].text="Retreat [%s]"%preferences.key_label("retreat")
	controls_hint.text="%s / %s / %s / %s camera  •  Wheel zoom  •  Drag select  •  Shift queue  •  Ctrl+0–9 groups"%[preferences.key_label("camera_up"),preferences.key_label("camera_left"),preferences.key_label("camera_down"),preferences.key_label("camera_right")]

func building_name(kind: int) -> String:
	return ["Headquarters","Barracks","Support Works","Vehicle Depot","Helipad","Emplacement"][kind]
func select_building(building: Dictionary) -> void:
	selected.clear(); active=null; selected_building=building; build_mode=false; attack_mode=false; dragging=false; refresh_panel(); queue_redraw()
func unit_card(kind: int, dimensions: Vector2, price: bool) -> Button:
	var card: Button = Button.new(); card.custom_minimum_size=dimensions; card.clip_contents=true
	card.tooltip_text=specs[kind].title+"\nHP %d • Damage %d • Speed %d\n%d Manpower / %d Fuel"%[specs[kind].hp,specs[kind].damage,specs[kind].speed,specs[kind].manpower,specs[kind].fuel]
	var preview: UnitPortrait = UnitPortrait.new(); preview.position=Vector2(5,5); preview.size=Vector2(64,52); preview.kind=kind; card.add_child(preview)
	var title: Label = label_at(card,specs[kind].title,Vector2(74,9),12,CREAM); title.size=Vector2(dimensions.x-80,25); title.clip_text=true; title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if price: label_at(card,"%d M / %d F"%[specs[kind].manpower,specs[kind].fuel],Vector2(74,43),12,BLUE)
	else:
		var bar: ProgressBar = ProgressBar.new(); bar.name="Health"; bar.position=Vector2(7,62); bar.size=Vector2(dimensions.x-14,6); bar.show_percentage=false; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(bar); configure_health(bar)
	return card

func configure_health(bar: ProgressBar) -> void:
	bar.add_theme_font_size_override("font_size",1)
	var background: StyleBoxFlat = StyleBoxFlat.new(); background.bg_color=Color("3b5053"); background.set_content_margin_all(0); bar.add_theme_stylebox_override("background",background)
	var fill: StyleBoxFlat = StyleBoxFlat.new(); fill.bg_color=BLUE; fill.set_content_margin_all(0); bar.add_theme_stylebox_override("fill",fill)
	bar.size=Vector2(bar.size.x,8)

func clear_panel_children(container: Node) -> void:
	# A button may request this rebuild from inside its own pressed signal.
	# Remove old controls immediately, but destroy them after input dispatch.
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
