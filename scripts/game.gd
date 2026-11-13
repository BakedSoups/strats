extends Node2D
const BLUE: Color = Color("53b8ed")
const RED: Color = Color("ed6e6c")
const INK: Color = Color("24383e")
const CREAM: Color = Color("dfebdf")
var vision: BattleVision
var fog_clock: float = 0
var building_specs: Array[BuildingSpec] = []
var abilities: Dictionary = {}
var ability_mode: String = ""
var ability_caster: CombatUnit
var blasts: Array[Dictionary] = []
var placement_kind: int = -1
var placement_builder: CombatUnit
var tools_grid: GridContainer
var tools_title: Label
var tool_hint: Label
var tool_buttons: Dictionary = {}
var engineer_mode: String = ""
var engineer_caster: CombatUnit
var cover_vertical: bool = false
var catalog_title: Label
var catalog_back: Button
var catalog_scroll: ScrollContainer
var depot_upgrade_button: Button
var base_frame: Panel
var base_cards: Dictionary = {}
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
var camera_pos: Vector2 = Vector2(920,1560)
var zoom_level: float = .66
var elapsed: float = 0
var ai_clock: float = 0
var running: bool = false
var ended: bool = false
var attack_mode: bool = false
var drag_start: Vector2
var dragging: bool = false
var hud: CanvasLayer
var supply_badge: ResourceBadge
var fuel_badge: ResourceBadge
var manpower_badge: ResourceBadge
var ticket_labels: Array[Label] = []
var vp_label: Label
var drain_label: Label
var clock_label: Label
var info: Label
var selection_row: GridContainer
var upgrades_box: VBoxContainer
var queue_progress: ProgressBar
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
var build_mode: bool = false
var demo: bool = false
var demo_stage: int = 0
var mouse_world: Vector2:
	get: return screen_to_world(get_viewport().get_mouse_position())
func _ready() -> void:
	vision=BattleVision.new(field,units)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	preferences.load_saved()
	preferences.apply()
	for i in 14: specs.append(load("res://data/unit_%d.tres"%i))
	for i in 21: upgrades.append(load("res://data/upgrade_%d.tres"%i))
	for i in 6: building_specs.append(load("res://data/building_%d.tres"%i))
	abilities={"grenade":load("res://data/ability_grenade.tres"),"mortar":load("res://data/ability_mortar.tres")}
	RenderingServer.set_default_clear_color(Color("788b80"))
	build_ui()
	for team in 2: spawn(2,team,field.headquarters(team).pos+Vector2(110 if team==0 else -110,0))
	selected.clear()
	active=null
	vision.refresh()
	refresh_panel()
	if "--demo" in OS.get_cmdline_user_args(): start_match(); demo=true
func spawn(kind: int, team: int, at: Vector2) -> CombatUnit:
	var u: CombatUnit = CombatUnit.new(specs[kind],kind,team,at)
	units.append(u)
	fog_clock=0
	return u
func start_match() -> void:
	running=true
	menu.hide()
	toast("Engineer → Build → place a Barracks. HQ trains your commander." if field.buildings.size()==2 else "Capture sectors. Outflank cover. Hold the victory rings.")
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
	camera_pos=camera_pos.clamp(Vector2(300,240),field.SIZE-Vector2(300,240))
	if not ended:
		field.income(delta)
		tick_capture(delta)
		tick_units(delta)
		tick_shots(delta)
		tick_production(delta)
		tick_blasts(delta)
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
			if not u.loaded and not u.spec.flying and u.team!=fire_zones[i].team and u.pos.distance_to(fire_zones[i].pos)<50: u.burn=2
		if fire_zones[i].life<=0: fire_zones.remove_at(i)
	fog_clock-=delta
	if fog_clock<=0:
		fog_clock=.15; vision.refresh()
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
		for key in u.ability_timers: u.ability_timers[key]=maxf(0,u.ability_timers[key]-delta)
		u.ability_cooldown=maxf(0,u.ability_cooldown-delta)
		u.burn=maxf(0,u.burn-delta)
		u.suppressed=maxf(0,u.suppressed-delta)
		if u.burn>0: u.hp-=delta*u.burn_dps
		var base: Vector2 = field.headquarters(u.team).pos
		if u.pos.distance_to(base)<170:
			var restore: float = minf(u.stats.hp-u.hp,delta*16)
			if field.supply[u.team]>=restore*.35:
				u.hp+=restore
				field.supply[u.team]-=restore*.35
			if u.retreating and u.hp>=u.stats.hp*.9: u.retreating=false; u.status="Defending"
		var target: CombatUnit = null
		var best: float = u.stats.reach
		if not u.retreating:
			for other in units:
				if other.team==u.team or other.loaded: continue
				if other.spec.flying and u.kind not in [0,1,6,9,11]: continue
				var distance: float = u.pos.distance_to(other.pos)
				if not spotted(u.team,other.pos): continue
				if not u.spec.flying and u.kind!=4 and field.line_blocked(u.pos,other.pos): continue
				if distance<best: best=distance; target=other
		if target==null and not u.retreating:
			for b in field.buildings:
				if b.team!=u.team and b.hp>0 and spotted(u.team,b.pos) and u.pos.distance_to(b.pos)<u.stats.reach and not field.line_blocked(u.pos,b.pos):
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
			var to: Vector2 = u.goal
			if not u.spec.flying:
				if u.path_goal!=u.goal or u.nav_revision!=field.nav_revision:
					u.path=field.find_path(u.pos,u.goal); u.path_goal=u.goal; u.nav_revision=field.nav_revision
				while not u.path.is_empty() and u.pos.distance_to(u.path[0])<12: u.path.remove_at(0)
				to=u.path[0] if not u.path.is_empty() else u.pos
			var direction: Vector2 = (to-u.pos).normalized()
			u.hull=lerp_angle(u.hull,direction.angle(),delta*5)
			u.pos+=direction*u.stats.speed*delta*(.35 if u.suppressed>0 else 1.0)*(1.45 if u.retreating else 1.0)
		else:
			u.setup+=delta
			if target!=null and u.setup>2: u.hull=lerp_angle(u.hull,u.angle,delta*.6)
			if u.orders.size()>0 and u.pos.distance_to(u.goal)<20 and u.repair_unit==null and u.repair_building<0: u.goal=u.orders.pop_front()
		for passenger in u.cargo: passenger.pos=u.pos
		for other in units:
			if other==u or other.loaded or other.spec.flying!=u.spec.flying: continue
			var offset: Vector2 = u.pos-other.pos
			if offset.length()<29 and offset.length()>0:
				var displaced: Vector2 = u.pos+offset.normalized()*delta*23
				if u.spec.flying or not field.occupied(displaced,12): u.pos=displaced
		if u.kind==2: tick_repair(u,delta)
		var lvl: int = mini(3,int(u.xp/130))
		if lvl>u.level: u.hp=minf(u.stats.hp,u.hp+20); u.level=lvl
	var selection_changed: bool = false
	for i in range(units.size()-1,-1,-1):
		if units[i].hp<=0:
			var dead: CombatUnit = units[i]
			effect(dead.pos,Color("ffbd68"),45,.7)
			for passenger in dead.cargo:
				passenger.loaded=false; passenger.pos=unload_position(dead.pos,dead.cargo.find(passenger)); passenger.goal=passenger.pos; passenger.hp*=.5
			selection_changed=true
			selected.erase(dead)
			if active==dead: active=selected[0] if selected.size()>0 else null
			units.remove_at(i)
	if selection_changed: refresh_panel()
func shoot(u: CombatUnit, target: CombatUnit) -> void:
	if u.kind==8:
		for v in units:
			var diff: Vector2 = v.pos-u.pos
			if v.team!=u.team and not v.loaded and not v.spec.flying and diff.length()<u.stats.reach and absf(angle_difference(u.angle,diff.angle()))<.48:
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
				if s.building.hp<=0:
					field.rebuild_navigation()
					if s.building.type==0: finish(1-s.building.team)
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
			if not s.air and field.line_blocked(before,s.pos):
				effect(before,Color("c0bca3"),12,.2); shots.remove_at(i); continue
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
		if b.get("construction",0.0)>0:
			var builder: CombatUnit = b.get("builder")
			if builder!=null and builder in units and builder.pos.distance_to(b.pos)<135 and not builder.retreating and builder.suppressed<=0 and builder.repair_unit==null and builder.repair_building<0:
				b.construction=maxf(0,b.construction-delta*(1.8 if 4 in builder.purchased else 1.0))
				builder.status="Constructing "+building_name(b.type)
				if b.construction<=0: builder.status="Defending"; builder.goal=builder.pos
		if b.research>0:
			b.research=maxf(0,b.research-delta)
			if b.research<=0: b.heavy=true

		if b.type==5 and b.get("construction",0.0)<=0:
			b.cooldown=b.get("cooldown",0.0)-delta
			if b.cooldown<=0:
				for u in units:
					if u.team!=b.team and not u.spec.flying and spotted(b.team,u.pos) and not field.line_blocked(b.pos,u.pos) and u.pos.distance_to(b.pos)<320:
						u.hp-=12*(field.cover_factor(u.pos,b.pos) if u.spec.infantry else 1.0); b.cooldown=.35; effect(u.pos,Color("ffdc9a"),12,.15); break
	var busy: Array[String] = []
	var completed: Array[Dictionary] = []
	for q in field.queues:
		var building: Dictionary = field.building_by_id(q.producer)
		if building.is_empty() or building.hp<=0:
			field.supply[q.team]+=specs[q.kind].supply
			field.fuel[q.team]+=specs[q.kind].fuel
			completed.append(q); continue
		var production_id: String = str(q.producer)
		if production_id in busy: continue
		busy.append(production_id)
		q.left-=delta
		if q.left<=0:
			var u: CombatUnit = spawn(q.kind,q.team,building.pos+Vector2(80 if q.team==0 else -80,randf_range(-50,50)))
			if q.team==1 and u.kind!=2: u.command(field.points[1].pos)
			completed.append(q)
	for q in completed: field.queues.erase(q)
func production_type(kind: int) -> int:
	if kind in [2,12]: return 0
	if kind<=3: return 1
	if kind<=5 or kind==11: return 2
	return 4 if kind in [9,10] else 3
func recruit(kind: int, team: int=0, producer: int=-1) -> void:
	var s: UnitSpec = specs[kind]
	var building: Dictionary = field.building_by_id(producer)
	if producer<0:
		for b in field.buildings:
			if b.team==team and b.type==production_type(kind) and b.hp>0 and b.get("construction",0.0)<=0 and recruitment_reason(kind,team,b).is_empty(): building=b; break
	if building.is_empty() or building.team!=team or building.type!=production_type(kind) or building.hp<=0 or building.get("construction",0.0)>0: return
	if not recruitment_reason(kind,team,building).is_empty(): return
	field.supply[team]-=s.supply
	field.fuel[team]-=s.fuel
	field.queues.append({"producer":building.id,"team":team,"kind":kind,"duration":5.0+s.fuel*.055,"left":5.0+s.fuel*.055})
	if team==0: toast("Queued: "+s.title)
func tick_ai() -> void:
	var engineer: CombatUnit = null
	for u in units:
		if u.team==1 and u.kind==2: engineer=u; break
	if engineer==null:
		if not field.queues.any(func(q: Dictionary) -> bool: return q.team==1 and q.kind==2): recruit(2,1)
		return
	var constructing: bool = false
	for b in field.buildings:
		if b.team==1 and b.get("construction",0.0)>0:
			constructing=true
			if b.get("builder") not in units:
				b.builder=engineer; engineer.command(b.pos+Vector2(0,100),false,false)
	if not constructing:
		for kind in [1,2,3,4]:
			if not has_building(1,kind):
				construct_building(kind,1,base_plot(1,kind),engineer); break
	var reserve_supply: int = 0
	for kind in [1,2,3,4]:
		if not field.buildings.any(func(b: Dictionary) -> bool: return b.team==1 and b.type==kind and b.hp>0): reserve_supply=building_specs[kind].supply; break
	for b in field.buildings:
		if field.supply[1]>=220+reserve_supply and b.team==1 and b.type==3 and not b.heavy and b.get("construction",0.0)<=0: research_depot(b)
	var aircraft: bool = units.any(func(u: CombatUnit) -> bool: return u.team==0 and u.spec.flying and spotted(1,u.pos))
	for u in units:
		if u.team!=1 or u.kind==2 or u.loaded: continue
		if u.hp<u.stats.hp*.28: retreat(u); continue
		if u.retreating: continue
		var best: Vector2 = field.points[1].pos; var score: float = INF
		for point in field.points:
			var value: float = u.pos.distance_to(point.pos)+(500 if point.owner==1 else 0)-(160 if point.type==0 else 0)
			if value<score: score=value; best=point.pos
		if u.kind==13:
			if u.cargo.is_empty() and u.pos.distance_to(field.headquarters(1).pos)<650: load_or_unload(u,[0,1,3])
			elif not u.cargo.is_empty() and u.pos.distance_to(best)<180: load_or_unload(u)
		u.command(best+Vector2(randf_range(-35,35),randf_range(-35,35)))
		if u.kind==12:
			if 17 not in u.purchased and field.supply[1]>reserve_supply+180: buy_upgrade(u,17)
			for target in units:
				if target.team==0 and not target.loaded and spotted(1,target.pos) and u.pos.distance_to(target.pos)<850: cast_ability(u,"mortar",target.pos); break
		elif u.spec.infantry:
			for target in units:
				if target.team==0 and not target.loaded and not target.spec.flying and spotted(1,target.pos) and u.pos.distance_to(target.pos)<210: cast_ability(u,"grenade",target.pos); break
		if randf()<.2 and field.supply[1]>reserve_supply+180:
			for id in options(u):
				if buy_upgrade(u,id): break
	if field.queues.filter(func(q: Dictionary) -> bool: return q.team==1).size()<4:
		var kind: int = 11 if aircraft else [0,0,1,3,4,6,6,7,8,9,12,13].pick_random()
		if field.supply[1]>=reserve_supply+specs[kind].supply: recruit(kind,1)
func retreat(u: CombatUnit) -> void:
	u.command(field.headquarters(u.team).pos,false,false)
	u.retreating=true
	u.status="Retreating / reinforcing"
func options(u: CombatUnit) -> Array:
	match u.kind:
		12: return [17,18,19]
		0: return [0,1]
		1: return [2,3,1]
		2: return [4,1]
		3: return [5,7,1]
		5,11: return [5,7,8]
		4: return [6,7]
		6: return [20,9,8]
		7: return [8,9,10]
		13: return [9,8]
		8: return [11,12,13,8]
		9: return [14,15]
		10: return [16,15]
	return []
func buy_upgrade(u: CombatUnit, id: int) -> bool:
	var up: UpgradeSpec = upgrades[id]
	if not can_upgrade(u,id): return false
	field.supply[u.team]-=up.supply
	field.fuel[u.team]-=upgrade_fuel(u,id)
	u.upgrade(id,up)
	return true
func finish(winner: int) -> void:
	ended=true
	menu.show()
	menu.get_node("Title").text="VICTORY" if winner==0 else "DEFEAT"
	menu.get_node("Subtitle").text="The battlefield belongs to Azure Command." if winner==0 else "Crimson Command controls the territory."
func tick_demo() -> void:
	if demo_stage==0:
		select_building(field.headquarters(0)); recruit(12)
		construct_building(1,0,base_plot(0,1),units[0]); demo_stage=1
	if demo_stage==1:
		for u in units:
			if u.team==0 and u.kind==12:
				selected_building={}; selected.assign([u]); active=u; buy_upgrade(u,17); refresh_panel(); demo_stage=2; break
func _draw() -> void:
	draw_set_transform(Vector2(720,335)-camera_pos*zoom_level,0,Vector2.ONE*zoom_level)
	draw_rect(Rect2(Vector2.ZERO,field.SIZE),Color("83958a"))
	for x in range(0,3201,80): draw_line(Vector2(x,0),Vector2(x,2200),Color("7b8e83"),1)
	for y in range(0,2201,80): draw_line(Vector2(0,y),Vector2(3200,y),Color("7b8e83"),1)
	for road in field.roads:
		for i in road.size()-1:
			draw_line(road[i],road[i+1],Color("94a297"),80)
			draw_dashed_line(road[i],road[i+1],Color("b3bbae"),2,25)
	draw_colored_polygon(field.water,Color("4c8794"))
	draw_line(field.water[0],field.water[1],Color("b3bcab"),9,true)
	draw_line(field.water[3],field.water[2],Color("b3bcab"),9,true)
	for bridge in field.bridges:
		draw_rect(bridge.grow(5),INK); draw_rect(bridge,Color("a8aa99"))
		draw_line(bridge.position+Vector2(12,0),Vector2(bridge.position.x+12,bridge.end.y),Color("d6d7c5"),5)
		draw_line(Vector2(bridge.end.x-12,bridge.position.y),bridge.end-Vector2(12,0),Color("d6d7c5"),5)
		draw_dashed_line(Vector2(bridge.get_center().x,bridge.position.y),Vector2(bridge.get_center().x,bridge.end.y),CREAM,3,25)
		for y in range(int(bridge.position.y)+20,int(bridge.end.y),70):
			draw_rect(Rect2(bridge.position.x-8,y,15,12),INK); draw_rect(Rect2(bridge.end.x-7,y,15,12),INK)
	for block in field.blocks:
		draw_rect(block.grow(5),INK); draw_rect(block,Color("637671")); draw_rect(block.grow(-12),Color("8b978b"))
		draw_line(block.position+Vector2(12,12),block.end-Vector2(12,12),Color("72847a"),4)
		for x in range(int(block.position.x)+20,int(block.end.x)-15,35):
			draw_rect(Rect2(x,block.position.y+15,16,14),Color("b1c6be")); draw_rect(Rect2(x,block.end.y-29,16,14),INK)
	for b in field.buildings:
		if b.team!=0 and not spotted(0,b.pos): continue
		var col: Color = BLUE if b.team==0 else RED
		if b.hp<=0: col=Color("53645e")
		var r: Rect2 = Rect2(b.pos-Vector2(43,36),Vector2(86,72))
		if not selected_building.is_empty() and b.id==selected_building.id: draw_rect(r.grow(10),Color("b7f5ed"),false,3)
		draw_rect(r.grow(4),INK)
		draw_rect(r,col.darkened(.25))
		if b.get("construction",0.0)>0:
			draw_arc(b.pos,55,0,TAU*(1-b.construction/b.get("build_duration",12.0)),32,CREAM,4,true)
		draw_building_symbol(b.pos,b.type,col)
		if b.heavy: draw_rect(r.grow(-5),Color("f3d58a"),false,3)
		var work: Dictionary = training_order(b.id)
		if b.research>0: work={"left":b.research,"duration":14.0}
		if not work.is_empty():
			draw_rect(Rect2(b.pos+Vector2(-48,-57),Vector2(96,9)),INK)
			draw_rect(Rect2(b.pos+Vector2(-46,-55),Vector2(92*training_fraction(work),5)),Color("f3d58a"))
		draw_string(ThemeDB.fallback_font,b.pos+Vector2(-36,58),["HQ","BARRACKS","SUPPORT","DEPOT","HELIPAD","EMPLACEMENT"][b.type],HORIZONTAL_ALIGNMENT_LEFT,-1,18,CREAM)
	for i in field.points.size():
		var p: Dictionary = field.points[i]
		var col: Color = CREAM if p.owner<0 else (BLUE if p.owner==0 else RED)
		draw_circle(p.pos,88,Color(col,.08))
		draw_arc(p.pos,72,0,TAU,64,INK,9,true)
		draw_arc(p.pos,72,0,TAU,64,col,5,true)
		if p.progress>0 and spotted(0,p.pos): draw_arc(p.pos,81,-PI/2,-PI/2+p.progress*TAU,48,BLUE if p.capturer==0 else RED,5,true)
		draw_circle(p.pos,25,INK)
		draw_string(ThemeDB.fallback_font,p.pos+Vector2(-14,6),["VP","+S","+F"][p.type],HORIZONTAL_ALIGNMENT_LEFT,-1,18,col)
	for r in field.covers:
		draw_rect(r.grow(4),INK)
		draw_rect(r,Color("bbc1b3"))
		for x in range(int(r.position.x)+12,int(r.end.x),26): draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color("85948a"),3)
	for z in fire_zones:
		if not spotted(0,z.pos): continue
		draw_circle(z.pos,46,Color(1,.4,.1,.13))
	for u in selected:
		if u.loaded: continue
		if u==active:
			draw_arc(u.pos,u.stats.reach,0,TAU,80,Color(BLUE,.12),2,true)
			if u.kind==6: draw_arc(u.pos,u.stats.sight,0,TAU,100,Color("8dc7a0"),2,true)
		if u.pos.distance_to(u.goal)>20:
			draw_dashed_line(u.pos,u.goal,Color(BLUE,.7),2,9)
			draw_arc(u.goal,12,0,TAU,24,BLUE,2,true)
		var prior: Vector2 = u.goal
		for dest in u.orders: draw_dashed_line(prior,dest,BLUE,2,8); prior=dest
	for u in units:
		if not u.loaded and not u.spec.flying and (u.team==0 or spotted(0,u.pos)): draw_unit(u)
	for u in units:
		if not u.loaded and u.spec.flying and (u.team==0 or spotted(0,u.pos)): draw_unit(u)
	for s in shots:
		if not spotted(0,s.pos): continue
		var at: Vector2 = s.pos
		if s.kind==4:
			draw_circle(at,7,Color(INK,.25))
			at.y-=sin(s.time/s.duration*PI)*120
		if s.rocket: draw_line(at,at-s.vel.normalized()*18,Color("ffbd72"),5)
		draw_circle(at,7 if s.kind in [3,4,5,7] or s.rocket else 4,INK)
		draw_circle(at,4 if s.kind in [3,4,5,7] else 2,Color("ffe0a1"))
	for e in effects:
		if not spotted(0,e.pos): continue
		var ratio: float = e.life/e.max
		var color: Color = e.color
		color.a=ratio*.8
		draw_circle(e.pos,e.size*(ratio if e.flame else 1-ratio*.75),color)
		if e.flame: draw_circle(e.pos,e.size*ratio*.45,Color(1,.9,.35,ratio))
	for blast in blasts:
		if not spotted(0,blast.pos) and blast.source.team!=0: continue
		var fraction: float = clampf(1-blast.left/blast.flight,0,1)
		var at: Vector2 = blast.start.lerp(blast.pos,fraction)
		at.y-=sin(fraction*PI)*(190 if blast.mortar else 90)
		draw_arc(blast.pos,blast.radius,0,TAU,32,Color(1,.6,.2,.3),2)
		draw_circle(at,7,INK); draw_circle(at,4,Color("ffce7d"))
	if running and get_viewport().get_mouse_position().y<610 and placement_kind<0 and engineer_mode=="" and ability_mode=="":
		var slots: Dictionary = cover_destinations(mouse_world)
		for unit in slots:
			var spot: Vector2 = slots[unit]
			if unit.pos.distance_to(spot)<10: continue
			draw_line(unit.pos,spot,Color(.6,1,.7,.35),2,true)
			draw_circle(spot,17,Color(.5,1,.65,.25))
			draw_arc(spot,19,0,TAU,24,Color("9ee9ab"),2,true)
			draw_line(spot,spot+Vector2.from_angle(unit.angle)*27,Color(.7,1,.8,.6),5,true)
			draw_cover_shield(spot+Vector2(0,-51),Color("9ee9ab"))
	draw_texture_rect(vision.fog_texture,Rect2(Vector2.ZERO,field.SIZE),false)
	for known in vision.known_buildings[0].values():
		if spotted(0,known.pos): continue
		draw_rect(Rect2(known.pos-Vector2(43,36),Vector2(86,72)),Color(.3,.26,.27,.65))
		draw_building_symbol(known.pos,known.type,Color(.5,.34,.34,.6))
		draw_string(ThemeDB.fallback_font,known.pos+Vector2(-36,58),"LAST SEEN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.65,.65,.6,.8))
	if placement_kind>=0:
		var at: Vector2 = mouse_world.snapped(Vector2(20,20))
		draw_arc(field.headquarters(0).pos,560,0,TAU,96,Color(BLUE,.3),2)
		var color: Color = BLUE if field.can_place(at,0) else RED
		draw_rect(Rect2(at-Vector2(48,42),Vector2(96,84)),Color(color,.35)); draw_building_symbol(at,placement_kind,color)
	if engineer_mode=="barricade" and engineer_caster!=null:
		var at: Vector2 = mouse_world.snapped(Vector2(20,20))
		var rect: Rect2 = cover_footprint(at)
		draw_rect(rect,Color(BLUE if can_place_barricade(engineer_caster,at) else RED,.6))
		draw_arc(engineer_caster.pos,220,0,TAU,64,Color(BLUE,.5),2,true)
	if engineer_mode=="repair": draw_arc(mouse_world,28,0,TAU,32,Color("9ed4aa"),3,true)
	if ability_mode!="" and ability_caster!=null:
		draw_arc(ability_caster.pos,abilities[ability_mode].reach,0,TAU,80,Color("f6d68b"),3)
		draw_arc(mouse_world,abilities[ability_mode].radius,0,TAU,32,Color("f6d68b"),3)
	draw_set_transform(Vector2.ZERO)
	if dragging:
		var r: Rect2 = Rect2(drag_start,get_viewport().get_mouse_position()-drag_start).abs()
		draw_rect(r,Color(BLUE,.12))
		draw_rect(r,BLUE,false,1)
	for p in field.points:
		if not spotted(0,p.pos):
			var marker: Vector2 = world_to_screen(p.pos)
			if marker.y>80 and marker.y<580: draw_arc(marker,maxf(8,72*zoom_level),0,TAU,40,Color(CREAM,.45),1,true)
		var compact: bool = zoom_level<.45
		var label_width: float = 96 if compact else 160
		var label_pos: Vector2 = world_to_screen(p.pos)+Vector2(-label_width/2+5,72*zoom_level+(18 if compact else 24))
		if label_pos.y<75 or label_pos.y>582 or label_pos.x<0 or label_pos.x>1440-label_width: continue
		var caption: String = ["VICTORY POINT","SUPPLY +%d/min"%int(Battlefield.SUPPLY_PER_POINT*60),"FUEL +%d/min"%int(Battlefield.FUEL_PER_POINT*60)][p.type]
		if compact: caption=["VICTORY","SUPPLY +%d/min"%int(Battlefield.SUPPLY_PER_POINT*60),"FUEL +%d/min"%int(Battlefield.FUEL_PER_POINT*60)][p.type]
		draw_rect(Rect2(label_pos-Vector2(5,13 if compact else 16),Vector2(label_width,18 if compact else 35)),Color(INK,.9))
		draw_string(ThemeDB.fallback_font,label_pos,caption,HORIZONTAL_ALIGNMENT_CENTER,label_width-10,11 if compact else 12,CREAM)
		if not compact: draw_string(ThemeDB.fallback_font,label_pos+Vector2(0,13),"CAPTURE TO EARN" if p.owner<0 else ("AZURE CONTROL" if p.owner==0 else "CRIMSON CONTROL"),HORIZONTAL_ALIGNMENT_CENTER,150,10,Color("a9c0b6"))
	draw_minimap()
func draw_unit(u: CombatUnit) -> void:
	var col: Color = BLUE if u.team==0 else RED
	var at: Vector2 = u.pos
	if u in selected: draw_arc(at,34 if not u.spec.infantry else 25,0,TAU,32,Color("b7f5ed"),3,true)
	if u.spec.flying:
		draw_circle(at+Vector2(13,23),30,Color(INK,.2))
		at.y-=22+sin(elapsed*3+u.pos.x)*4
	if u.spec.infantry:
		if u.kind==12: draw_arc(at,23,0,TAU,32,Color("f3d58a"),3,true)
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
		elif u.kind in [6,13]:
			for wheel in [Vector2(-20,-20),Vector2(20,-20),Vector2(-20,20),Vector2(20,20)]: draw_rect(Rect2(wheel-Vector2(8,5),Vector2(16,10)),INK)
			draw_rect(Rect2(-32,-17,64,34),INK); draw_rect(Rect2(-28,-13,56,26),col)
			if u.kind==13:
				draw_rect(Rect2(-25,-10,29,20),INK); draw_rect(Rect2(13,-10,7,20),Color("b8dcd7"))
				for i in u.cargo.size(): draw_circle(Vector2(-18+i*12,0),5,CREAM)
			else:
				draw_circle(Vector2.ZERO,11,INK); draw_circle(Vector2.ZERO,8,col.lightened(.2))
				draw_line(Vector2.ZERO,Vector2(35,0).rotated(u.angle-u.hull),INK,5)
				draw_line(Vector2(-18,-8),Vector2(-24,-32),CREAM,2); draw_arc(Vector2(-24,-32),10,-1.8,-.2,12,Color("8dc7a0"),2,true)
		else:
			if u.kind in [7,8]: draw_rect(Rect2(-36,-30,72,60),INK)
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
	if u.spec.infantry and not u.loaded and infantry_in_cover(u.pos): draw_cover_shield(at+Vector2(0,-55),Color("9ee9ab"))
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
	var scale_map: float = 220.0/field.SIZE.x
	draw_rect(Rect2(origin-Vector2(6,6),Vector2(232,163)),INK)
	draw_rect(Rect2(origin,field.SIZE*scale_map),Color("72887d"))
	var shoreline: PackedVector2Array = []
	for at in field.water: shoreline.append(origin+at*scale_map)
	draw_colored_polygon(shoreline,Color("4c8794"))
	for bridge in field.bridges: draw_rect(Rect2(origin+bridge.position*scale_map,bridge.size*scale_map),Color("b8b8a4"))
	for block in field.blocks: draw_rect(Rect2(origin+block.position*scale_map,block.size*scale_map),Color("485f59"))
	for b in field.buildings:
		if b.hp>0 and (b.team==0 or spotted(0,b.pos)): draw_rect(Rect2(origin+b.pos*scale_map-Vector2(3,3),Vector2(6,6)),BLUE if b.team==0 else RED)
	for u in units:
		if not u.loaded and (u.team==0 or spotted(0,u.pos)): draw_circle(origin+u.pos*scale_map,2.5,BLUE if u.team==0 else RED)
	if running and get_viewport().get_mouse_position().y<610 and placement_kind<0 and engineer_mode=="" and ability_mode=="":
		var slots: Dictionary = cover_destinations(mouse_world)
		for unit in slots:
			var spot: Vector2 = slots[unit]
			if unit.pos.distance_to(spot)<10: continue
			draw_line(unit.pos,spot,Color(.6,1,.7,.35),2,true)
			draw_circle(spot,17,Color(.5,1,.65,.25))
			draw_arc(spot,19,0,TAU,24,Color("9ee9ab"),2,true)
			draw_line(spot,spot+Vector2.from_angle(unit.angle)*27,Color(.7,1,.8,.6),5,true)
			draw_cover_shield(spot+Vector2(0,-51),Color("9ee9ab"))
	draw_texture_rect(vision.fog_texture,Rect2(origin,field.SIZE*scale_map),false)
	# Geography and crossings are public; enemy presence still requires sight.
	draw_line(origin+field.water[0]*scale_map,origin+field.water[1]*scale_map,Color(.3,.5,.53,.7),1)
	draw_line(origin+field.water[3]*scale_map,origin+field.water[2]*scale_map,Color(.3,.5,.53,.7),1)
	for bridge in field.bridges: draw_rect(Rect2(origin+bridge.position*scale_map,bridge.size*scale_map),Color(.7,.72,.65,.6),false,1)
	for known in vision.known_buildings[0].values():
		if not spotted(0,known.pos): draw_rect(Rect2(origin+known.pos*scale_map-Vector2(2,2),Vector2(4,4)),Color("956d6c"))
	# Objectives and their ownership are public strategic information.
	for p in field.points: draw_circle(origin+p.pos*scale_map,4,CREAM if p.owner<0 else (BLUE if p.owner==0 else RED))
	var top: Vector2 = screen_to_world(Vector2(0,60))
	var view_box: Rect2 = Rect2(origin+top*scale_map,Vector2(1440,550)/zoom_level*scale_map).intersection(Rect2(origin,field.SIZE*scale_map))
	draw_rect(view_box,Color(CREAM,.7),false,1)
func _unhandled_input(event: InputEvent) -> void:
	if settings_menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and (placement_kind>=0 or ability_mode!="" or engineer_mode!=""): placement_kind=-1; ability_mode=""; engineer_mode=""; return
		if event.keycode==KEY_TAB and engineer_mode=="barricade": cover_vertical=not cover_vertical; return
		if event.keycode==KEY_ESCAPE: menu.visible=not menu.visible; running=not menu.visible; dragging=false; return
		if not running: return
		if event.is_action_pressed("strats_attack_move"): action(1)
		if event.keycode==KEY_G: prepare_ability("grenade")
		if event.keycode==KEY_M: prepare_ability("mortar")
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
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom_level=maxf(.24,zoom_level/pow(1.1,float(preferences.values.zoom_sensitivity)))
		if event.position.y>610 or event.position.y<60: return
		if event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and (placement_kind>=0 or ability_mode!="" or engineer_mode!=""): placement_kind=-1; ability_mode=""; engineer_mode=""; return
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if engineer_mode=="barricade":
				if place_barricade(engineer_caster,mouse_world.snapped(Vector2(20,20))): engineer_mode=""
				return
			if engineer_mode=="repair":
				for u in units:
					if u.pos.distance_to(mouse_world)<40 and assign_repair(engineer_caster,u): engineer_mode=""; return
				for building in field.buildings:
					if building.pos.distance_to(mouse_world)<60 and assign_repair(engineer_caster,null,building): engineer_mode=""; return
				toast("Choose a damaged friendly vehicle or completed base"); return
			if placement_kind>=0:
				var placed: Dictionary = construct_building(placement_kind,0,mouse_world.snapped(Vector2(20,20)),placement_builder)
				if not placed.is_empty(): placement_kind=-1
				return
			if ability_mode!="":
				if cast_ability(ability_caster,ability_mode,mouse_world): ability_mode=""
				return
		if event.position.x>1180 and event.position.y<240 and event.pressed:
			camera_pos=((event.position-Vector2(1184,72))*(field.SIZE.x/220.0)).clamp(Vector2(300,240),field.SIZE-Vector2(300,240)); return
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			for b in field.buildings:
				if b.team==0 and b.get("construction",0.0)>0 and b.pos.distance_to(mouse_world)<70:
					for u in selected:
						if u.kind==2: b.builder=u; u.command(b.pos+Vector2(0,100),false,false); return
			issue(mouse_world,event.shift_pressed,attack_mode); attack_mode=false
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
		if u.team==1 and not u.loaded and spotted(0,u.pos) and u.pos.distance_to(at)<45: enemy=true
	var cover_slots: Dictionary = cover_destinations(at) if not enemy else {}
	for i in selected.size():
		var offset: Vector2 = Vector2((i%4-1.5)*40,(i/4)*40)
		var destination: Vector2 = (at+offset).clamp(Vector2(30,30),field.SIZE-Vector2(30,30))
		if not selected[i].spec.flying and field.occupied(destination,25): destination=field.navigation.get_point_position(field.free_cell(destination))
		if cover_slots.has(selected[i]): destination=cover_slots[selected[i]]
		selected[i].command(destination,queued,aggressive or enemy)
		if cover_slots.has(selected[i]): selected[i].status="Taking cover"
func build_ui() -> void:
	hud=CanvasLayer.new(); add_child(hud)
	var top: Panel = panel(Rect2(0,0,1440,60),Color("1d3036")); hud.add_child(top)
	label_at(top,"S T R A C K S",Vector2(24,13),26,BLUE)
	supply_badge=ResourceBadge.new("SUPPLY",0,Color("efd08a"),205); supply_badge.position=Vector2(230,5); top.add_child(supply_badge)
	fuel_badge=ResourceBadge.new("FUEL",1,Color("80d3e4"),205); fuel_badge.position=Vector2(445,5); top.add_child(fuel_badge)
	manpower_badge=ResourceBadge.new("MANPOWER",2,Color("9ed4aa"),220); manpower_badge.position=Vector2(660,5); top.add_child(manpower_badge)
	var score: Panel = panel(Rect2(890,5,360,50),Color("263c42")); top.add_child(score)
	label_at(score,"AZURE",Vector2(12,3),10,BLUE); label_at(score,"CRIMSON",Vector2(88,3),10,RED)
	ticket_labels.append(label_at(score,"",Vector2(12,15),25,BLUE)); ticket_labels.append(label_at(score,"",Vector2(88,15),25,RED))
	label_at(score,"vs",Vector2(65,22),12,Color("9cb2ac"))
	vp_label=label_at(score,"",Vector2(154,5),11,CREAM)
	drain_label=label_at(score,"",Vector2(154,27),11,Color("b6cbc3"))
	label_at(score,"TIME",Vector2(300,3),10,Color("9cb2ac")); clock_label=label_at(score,"",Vector2(292,19),19,CREAM)
	button("Settings",Vector2(1264,12),Vector2(152,35),top).pressed.connect(open_settings)
	toast_label=label_at(hud,"",Vector2(385,80),18,CREAM)
	toast_label.size=Vector2(760,44); toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; toast_label.clip_text=true
	var bottom: Panel = panel(Rect2(0,610,1440,290),Color("1b2d33")); bottom.mouse_filter=Control.MOUSE_FILTER_STOP; hud.add_child(bottom)
	base_frame=panel(Rect2(10,38,340,217),Color("263f45")); bottom.add_child(base_frame)
	context_title=label_at(bottom,"COMMANDER",Vector2(18,12),14,BLUE)
	portrait=UnitPortrait.new(); portrait.position=Vector2(16,48); portrait.size=Vector2(110,100); bottom.add_child(portrait)
	info=label_at(bottom,"",Vector2(138,47),14,CREAM); info.size=Vector2(208,162); info.clip_text=true
	health_bar=ProgressBar.new(); health_bar.position=Vector2(18,161); health_bar.size=Vector2(108,10); health_bar.show_percentage=false; bottom.add_child(health_bar); configure_health(health_bar)
	var health_style: StyleBoxFlat = StyleBoxFlat.new(); health_style.bg_color=BLUE; health_style.set_corner_radius_all(3); health_bar.add_theme_stylebox_override("fill",health_style)
	var health_background: StyleBoxFlat = StyleBoxFlat.new(); health_background.bg_color=Color("3b5053"); health_bar.add_theme_stylebox_override("background",health_background)
	actions_panel=Control.new(); actions_panel.position=Vector2(365,0); bottom.add_child(actions_panel)
	tools_title=label_at(actions_panel,"TOOLS",Vector2(0,12),14,BLUE)
	tools_grid=GridContainer.new(); tools_grid.position=Vector2(0,43); tools_grid.columns=2; tools_grid.add_theme_constant_override("h_separation",8); tools_grid.add_theme_constant_override("v_separation",8); actions_panel.add_child(tools_grid)
	tool_hint=label_at(actions_panel,"",Vector2(0,246),11,Color("a6bbb5")); tool_hint.size=Vector2(316,20); tool_hint.clip_text=true
	upgrades_panel=Control.new(); upgrades_panel.position=Vector2(705,0); bottom.add_child(upgrades_panel)
	catalog_title=label_at(upgrades_panel,"UNIT UPGRADES",Vector2(0,12),14,BLUE)
	catalog_back=button("← Back to upgrades",Vector2(0,39),Vector2(310,26),upgrades_panel); catalog_back.pressed.connect(func() -> void: set_build_menu(false))
	catalog_scroll=ScrollContainer.new(); catalog_scroll.position=Vector2(0,44); catalog_scroll.size=Vector2(320,209); catalog_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; upgrades_panel.add_child(catalog_scroll)
	upgrades_box=VBoxContainer.new(); upgrades_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; catalog_scroll.add_child(upgrades_box)
	selection_panel=Control.new(); selection_panel.position=Vector2(1060,0); bottom.add_child(selection_panel)
	label_at(selection_panel,"SELECTED UNITS",Vector2(0,12),14,BLUE)
	var selection_scroll: ScrollContainer = ScrollContainer.new(); selection_scroll.position=Vector2(0,45); selection_scroll.size=Vector2(360,211); selection_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; selection_panel.add_child(selection_scroll)
	selection_row=GridContainer.new(); selection_row.columns=2; selection_scroll.add_child(selection_row)
	production_panel=Control.new(); production_panel.position=Vector2(365,0); bottom.add_child(production_panel)
	production_title=label_at(production_panel,"",Vector2(0,12),14,BLUE)
	var production_scroll: ScrollContainer = ScrollContainer.new(); production_scroll.position=Vector2(0,45); production_scroll.size=Vector2(1058,155); production_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; production_panel.add_child(production_scroll)
	production_grid=GridContainer.new(); production_grid.columns=4; production_scroll.add_child(production_grid)
	for i in specs.size():
		var b: Button = unit_card(i,Vector2(252,78),true); production_grid.add_child(b); b.pressed.connect(recruit_or_build.bind(i)); recruit_buttons.append(b)
	depot_upgrade_button=button("Heavy Workshop • 220 Supply / 40 Fuel",Vector2(740,5),Vector2(310,32),production_panel); depot_upgrade_button.pressed.connect(func() -> void: research_depot(selected_building))
	base_grid=GridContainer.new(); base_grid.columns=4; production_scroll.add_child(base_grid)
	queue_progress=ProgressBar.new(); queue_progress.position=Vector2(0,210); queue_progress.size=Vector2(1040,10); queue_progress.show_percentage=false; production_panel.add_child(queue_progress); configure_health(queue_progress)
	queue_label=label_at(production_panel,"",Vector2(0,232),13,CREAM); queue_label.size=Vector2(1040,32); queue_label.clip_text=true
	controls_hint=label_at(bottom,"",Vector2(18,270),12,Color("91aaa2"))
	controls_hint.hide()
	menu=panel(Rect2(360,170,720,420),Color("1b2d33")); hud.add_child(menu)
	var title: Label = label_at(menu,"S T R A C K S",Vector2(65,42),55,BLUE); title.name="Title"
	var subtitle: Label = label_at(menu,"TERRITORY & STEEL  /  TACTICAL RTS",Vector2(69,116),19,CREAM); subtitle.name="Subtitle"
	label_at(menu,"Build a base. Recruit troops. Capture the three victory rings.\nUse directional cover and flanking routes to break the front.\n\nBlue: Azure Command  /  Red: Crimson Command\nStart with HQ and an engineer. Build your army from scratch.",Vector2(69,169),18,Color("b7c8bf"))
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
	clear_panel_children(tools_grid)
	tool_buttons.clear()
	clear_panel_children(selection_row)
	clear_panel_children(upgrades_box)
	clear_panel_children(base_grid)
	upgrade_buttons.clear()
	if not selected_building.is_empty() and selected_building.hp<=0: selected_building={}
	if selected_building.is_empty() and (active==null or active not in units):
		var bases: Array = field.buildings.filter(func(b: Dictionary) -> bool: return b.team==0 and b.hp>0)
		if bases.size()==1: selected_building=bases[0]
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
	portrait.building_kind=selected_building.get("type",0)
	portrait.queue_redraw()
	if unit_mode:
		for u in selected:
			var card: Button = unit_card(u.kind,Vector2(171,75),false); card.set_meta("unit",u); selection_row.add_child(card)
			card.pressed.connect(func() -> void: active=u; selected_building={}; refresh_panel())
		if active.kind!=2: build_mode=false
		build_tool_cards()
		catalog_title.text="BUILDING PLANS" if build_mode else "UNIT UPGRADES"
		catalog_back.visible=build_mode
		catalog_scroll.position.y=76 if build_mode else 44
		catalog_scroll.size.y=177 if build_mode else 209
		if build_mode:
			for i in 5:
				var spec: BuildingSpec = building_specs[i+1]
				var b: Button = Button.new(); b.custom_minimum_size=Vector2(310,61); b.set_meta("building_kind",i+1); upgrades_box.add_child(b)
				var preview: UnitPortrait = UnitPortrait.new(); preview.building=true; preview.building_kind=i+1; preview.position=Vector2(5,5); preview.size=Vector2(52,49); b.add_child(preview)
				label_at(b,spec.title,Vector2(64,8),14,CREAM)
				label_at(b,"%d Supply • %.0fs work"%[spec.supply,spec.duration/(1.8 if 4 in active.purchased else 1.0)],Vector2(64,32),12,BLUE)
				b.tooltip_text=spec.description; b.pressed.connect(recruit_or_build.bind(i))
		else:
			for id in options(active):
				var up: UpgradeSpec = upgrades[id]
				var b: Button = Button.new(); b.text="%s\n%d Supply / %d Fuel  •  %s"%[up.title,up.supply,upgrade_fuel(active,id),up.description]; b.custom_minimum_size=Vector2(310,47); b.add_theme_font_size_override("font_size",12); b.set_meta("id",id); upgrades_box.add_child(b); upgrade_buttons.append(b)
				b.pressed.connect(func() -> void:
					if active!=null and buy_upgrade(active,id): toast(up.title+" installed"); refresh_panel())
	else:
		for b in field.buildings:
			if b.team!=0 or b.hp<=0: continue
			var card: Button = building_card(b); base_grid.add_child(card); card.pressed.connect(select_building.bind(b))
	refresh_hud()
func refresh_hud() -> void:
	refresh_resources()
	base_frame.visible=active==null or not selected_building.is_empty()
	if not selected_building.is_empty() and selected_building.hp<=0: selected_building={}; active=null; refresh_panel(); return
	if active!=null and active in units and selected_building.is_empty():
		context_title.text="UNIT / "+active.spec.title.to_upper()
		health_bar.value=active.hp/active.stats.hp*100
		info.text="%s\nHP %d / %d\nArmor %d • Damage %d\nSpeed %d • Range %d\nSight %d\nVeterancy %d / 3 • XP %d"%[active.spec.title,active.hp,active.stats.hp,active.stats.armor,active.stats.damage,active.stats.speed,active.stats.reach,active.stats.sight,active.level,active.xp]
		if active.spec.cargo_capacity>0: info.text+="\nCargo %d / %d squads"%[active.cargo.size(),active.spec.cargo_capacity]
		info.tooltip_text=""
		for id in active.purchased: info.tooltip_text+="Installed: "+upgrades[id].title+"\n"
		refresh_tool_states()
		if build_mode:
			for plan in upgrades_box.get_children():
				var kind: int = plan.get_meta("building_kind")
				plan.disabled=field.supply[0]<building_specs[kind].supply or builder_busy(active)
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
		info.text="%s\nHP %d / %d\n%s"%[building_name(selected_building.type),selected_building.hp,2400 if selected_building.type==0 else 900,"Constructing: %.0fs"%selected_building.construction if selected_building.get("construction",0.0)>0 else ("Heavy Workshop: READY" if selected_building.heavy else "Operational")]
		health_bar.value=selected_building.hp/(2400 if selected_building.type==0 else 900)*100
		var roster: String = ["Engineers • Commander","Rifles • MG • Anti-tank","Mortars • AT • Anti-air","Scouts • Light trucks\nHeavy tanks: "+("UNLOCKED" if selected_building.heavy else "LOCKED"),"Attack • Transport","Defensive fire"][selected_building.type]
		info.text+="\n\n"+roster
		production_title.text="TRAIN UNITS / "+building_name(selected_building.type).to_upper()
	else:
		context_title.text="COMMANDER / AZURE"
		info.text="Azure Command\n%d units deployed\nTickets: %d\nClick a base to recruit.\nClick a unit to command."%[units.filter(func(u: CombatUnit) -> bool: return u.team==0).size(),field.tickets[0]]
		health_bar.value=field.tickets[0]/500*100
		production_title.text="YOUR BASES / SELECT A BUILDING"
	for i in recruit_buttons.size():
		var b: Button = recruit_buttons[i]
		b.visible=not selected_building.is_empty() and production_type(i)==selected_building.type
		var reason: String = recruitment_reason(i,0,selected_building)
		b.disabled=not reason.is_empty()
		if i in [7,8]: b.get_node("Lock").visible=not selected_building.get("heavy",false)
		b.tooltip_text=reason if not reason.is_empty() else "%d Supply • %d Fuel • %d Manpower"%[specs[i].supply,specs[i].fuel,specs[i].manpower]
	depot_upgrade_button.visible=not selected_building.is_empty() and selected_building.type==3
	if depot_upgrade_button.visible:
		depot_upgrade_button.disabled=selected_building.heavy or selected_building.research>0 or selected_building.get("construction",0.0)>0 or not training_order(selected_building.id).is_empty() or field.supply[0]<220 or field.fuel[0]<40
		depot_upgrade_button.text="✓ Heavy Workshop installed" if selected_building.heavy else ("Researching Heavy Workshop…" if selected_building.research>0 else "Heavy Workshop • 220 Supply / 40 Fuel")
	var work: Dictionary = training_order(selected_building.get("id",-1))
	var construction: bool = selected_building.get("construction",0.0)>0
	var research: bool = selected_building.get("research",0.0)>0
	if construction: work={"left":selected_building.construction,"duration":selected_building.build_duration}
	if research: work={"left":selected_building.research,"duration":14.0}
	queue_progress.visible=not work.is_empty()
	if not work.is_empty():
		queue_progress.value=training_fraction(work)*100
		queue_label.text=("CONSTRUCTION: %.1fs remaining • Engineer must stay nearby"%work.left) if construction else ("RESEARCH: Heavy Workshop  •  %.1fs remaining"%work.left) if research else ("TRAINING: %s  •  %.1fs remaining"%[specs[work.kind].title,maxf(0,work.left)])
		var waiting: Array[Dictionary] = []
		for q in field.queues:
			if q.producer==selected_building.id: waiting.append(q)
		if not construction and waiting.size()>1: queue_label.text+="    |    NEXT: "+specs[waiting[1].kind].title+"  (+%d waiting)"%(waiting.size()-1)
	else:
		queue_label.text="Select a base above or on the battlefield." if selected_building.is_empty() else "Queue empty" + (" • This building does not train units." if selected_building.type==5 else "")
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
				if r.get_center().distance_to(u.pos)<distance: distance=r.get_center().distance_to(u.pos); nearest=r.get_center()+((Vector2(0,42 if u.team==0 else -42)) if r.size.x>=r.size.y else Vector2(-42 if u.team==0 else 42,0))
			u.command(nearest); u.status="Taking cover"
		if id==5:
			if u.kind==12: prepare_ability("mortar"); break
			if u.spec.infantry and u.kind!=2: prepare_ability("grenade"); break
			if u.ability_cooldown>0: toast("Ability recharging: %.0fs"%u.ability_cooldown); continue
			u.ability_cooldown=5
			if u.kind==2: prepare_engineer_tool("repair")
			elif u.spec.cargo_capacity>0: load_or_unload(u)
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
	if active==null or active.kind!=2: toast("Select Engineers to build"); return
	placement_kind=id+1; placement_builder=active; ability_mode=""; engineer_mode=""
	toast("Place "+building_name(id+1)+" • Left-click build, right-click cancel")

func can_upgrade(u: CombatUnit, id: int) -> bool:
	var up: UpgradeSpec = upgrades[id]
	return id not in u.purchased and field.supply[u.team]>=up.supply and field.fuel[u.team]>=upgrade_fuel(u,id) and (up.prerequisite<0 or up.prerequisite in u.purchased) and has_building(u.team,up.building)

func spotted(team: int, at: Vector2) -> bool:
	return vision!=null and vision.can_see(team,at)

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
	controls_hint.text="%s / %s / %s / %s camera • RMB move • [%s] fire • [%s] stop • [%s] retreat • Shift queue • Ctrl+0–9 groups"%[preferences.key_label("camera_up"),preferences.key_label("camera_left"),preferences.key_label("camera_down"),preferences.key_label("camera_right"),preferences.key_label("attack_move"),preferences.key_label("stop"),preferences.key_label("retreat")]

func building_name(kind: int) -> String:
	return building_specs[kind].title
func select_building(building: Dictionary) -> void:
	engineer_mode=""; ability_mode=""; placement_kind=-1
	selected.clear(); active=null; selected_building=building; build_mode=false; attack_mode=false; dragging=false; refresh_panel(); queue_redraw()
func unit_card(kind: int, dimensions: Vector2, price: bool) -> Button:
	var card: Button = Button.new(); card.custom_minimum_size=dimensions; card.clip_contents=true
	card.tooltip_text=specs[kind].title+"\nHP %d • Damage %d • Speed %d • Sight %d\n%d Supply / %d Fuel • %d Manpower"%[specs[kind].hp,specs[kind].damage,specs[kind].speed,specs[kind].sight,specs[kind].supply,specs[kind].fuel,specs[kind].manpower]
	if specs[kind].cargo_capacity>0: card.tooltip_text+="\nCarries %d infantry squads. Use Load / Unload."%specs[kind].cargo_capacity
	var preview: UnitPortrait = UnitPortrait.new(); preview.position=Vector2(5,5); preview.size=Vector2(64,52); preview.kind=kind; card.add_child(preview)
	var title: Label = label_at(card,specs[kind].title,Vector2(74,9),12,CREAM); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.size=Vector2(dimensions.x-80,30); title.clip_text=true
	if price:
		label_at(card,"%d S / %d F • %d MP"%[specs[kind].supply,specs[kind].fuel,specs[kind].manpower],Vector2(74,43),12,BLUE)
		if kind in [7,8]:
			var lock_label: Label = label_at(card,"LOCKED: Heavy Workshop",Vector2(74,61),10,Color("f3d58a")); lock_label.name="Lock"
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

func training_order(producer: int) -> Dictionary:
	for q in field.queues:
		if q.producer==producer: return q
	return {}
func training_fraction(order: Dictionary) -> float:
	return clampf(1-float(order.left)/float(order.duration),0,1)
func draw_building_symbol(at: Vector2, kind: int, color: Color) -> void:
	match kind:
		0:
			draw_rect(Rect2(at-Vector2(24,16),Vector2(48,37)),color)
			draw_line(at+Vector2(-26,-30),at+Vector2(-26,22),CREAM,4)
			draw_colored_polygon(PackedVector2Array([at+Vector2(-24,-30),at+Vector2(8,-22),at+Vector2(-24,-14)]),color)
		1:
			for x in [-23,0,23]:
				draw_colored_polygon(PackedVector2Array([at+Vector2(x-10,20),at+Vector2(x,-24),at+Vector2(x+10,20)]),color)
		2:
			draw_circle(at+Vector2(-20,20),9,color); draw_circle(at+Vector2(20,20),9,color)
			draw_line(at+Vector2(-25,10),at+Vector2(22,-23),CREAM,7)
			draw_line(at+Vector2(25,10),at+Vector2(-22,-23),color,7)
		3:
			draw_rect(Rect2(at-Vector2(30,24),Vector2(60,48)),color)
			draw_rect(Rect2(at+Vector2(-20,-10),Vector2(40,34)),INK)
			for y in [-17,-9]: draw_line(at+Vector2(-26,y),at+Vector2(26,y),CREAM,3)
			draw_line(at+Vector2(-15,30),at+Vector2(15,30),color,4)
		4:
			draw_arc(at,28,0,TAU,32,color,4,true)
			draw_line(at+Vector2(-10,-16),at+Vector2(-10,16),CREAM,5)
			draw_line(at+Vector2(10,-16),at+Vector2(10,16),CREAM,5)
			draw_line(at+Vector2(-10,0),at+Vector2(10,0),CREAM,5)
		5:
			draw_circle(at,23,color); draw_circle(at,14,INK)
			draw_line(at,at+Vector2(36,0),CREAM,8)
func manpower_used(team: int) -> int:
	var used: int = 0
	for u in units:
		if u.team==team and u.hp>0: used+=u.spec.manpower
	for q in field.queues:
		if q.team==team: used+=specs[q.kind].manpower
	return used
func recruitment_reason(kind: int, team: int, producer: Dictionary) -> String:
	if producer.is_empty(): return "Select a production building"
	if producer.team!=team or producer.type!=production_type(kind): return "Wrong producer"
	if producer.hp<=0 or producer.get("construction",0.0)>0: return "Building not operational"
	if producer.research>0: return "Heavy Workshop research in progress"
	if kind in [7,8] and not producer.heavy: return "Requires this depot's Heavy Workshop upgrade"
	if kind==12:
		for u in units:
			if u.team==team and u.kind==12 and u.hp>0: return "Commander already deployed"
		for q in field.queues:
			if q.team==team and q.kind==12: return "Commander already recruiting"
	if manpower_used(team)+specs[kind].manpower>Battlefield.MANPOWER_CAP: return "Manpower capacity reached (includes queued units)"
	if field.supply[team]<specs[kind].supply: return "Insufficient supply"
	if field.fuel[team]<specs[kind].fuel: return "Insufficient fuel"
	return ""
func upgrade_fuel(u: CombatUnit, id: int) -> int:
	return upgrades[id].fuel if u.kind in [7,8] else 0
func base_plot(team: int, kind: int) -> Vector2:
	return field.headquarters(team).pos+Vector2(220 if team==0 else -220,(kind-2.5)*220)
func construct_building(kind: int, team: int, at: Vector2, builder: CombatUnit) -> Dictionary:
	if builder==null or builder not in units or builder.team!=team or builder.kind!=2: return {}
	if kind<1 or kind>5 or field.supply[team]<building_specs[kind].supply: return {}
	for b in field.buildings:
		if b.get("builder")==builder and b.get("construction",0.0)>0: toast("Engineer already assigned to construction"); return {}
	if not field.can_place(at,team):
		if team==0: toast("Blocked site • Build near HQ or an owned sector")
		return {}
	var spec: BuildingSpec = building_specs[kind]
	field.supply[team]-=spec.supply
	var site: Dictionary = {"pos":at,"team":team,"type":kind,"hp":spec.health,"construction":spec.duration,"build_duration":spec.duration,"builder":builder}
	field.add_building(site)
	builder.command(at+Vector2(0,100),false,false); builder.status="Travelling to construction"
	return site
func research_depot(building: Dictionary) -> bool:
	if building.is_empty() or building.type!=3 or building.hp<=0 or building.get("construction",0.0)>0: return false
	if building.heavy or building.research>0 or not training_order(building.id).is_empty(): return false
	var team: int = building.team
	if field.supply[team]<220 or field.fuel[team]<40: return false
	field.supply[team]-=220; field.fuel[team]-=40; building.research=14.0
	if team==0: toast("Heavy Workshop research started • 14 seconds")
	return true
func prepare_ability(key: String) -> void:
	if active==null or active.loaded or not active.spec.infantry: toast("Select infantry for grenades or a commander for mortars"); return
	if key=="mortar" and (active.kind!=12 or 17 not in active.purchased): toast("Commander requires Mortar Support upgrade"); return
	if active.ability_timers[key]>0: toast("Ability recharging: %.0fs"%active.ability_timers[key]); return
	ability_mode=key; ability_caster=active; placement_kind=-1; engineer_mode=""
	toast(abilities[key].title+" • Click a target, right-click cancel")
func cast_ability(caster: CombatUnit, key: String, target: Vector2) -> bool:
	if caster==null or caster not in units or caster.loaded or not caster.spec.infantry: return false
	if key=="mortar" and (caster.kind!=12 or 17 not in caster.purchased): return false
	var spec: AbilitySpec = abilities[key]
	if caster.ability_timers[key]>0 or field.supply[caster.team]<spec.supply: return false
	if caster.pos.distance_to(target)>spec.reach or not Rect2(Vector2.ZERO,field.SIZE).has_point(target):
		if caster.team==0: toast("Target outside ability range")
		return false
	field.supply[caster.team]-=spec.supply; caster.ability_timers[key]=spec.cooldown
	for i in spec.count:
		var at: Vector2 = target+(Vector2(randf_range(-85,85),randf_range(-85,85)) if key=="mortar" else Vector2.ZERO)
		blasts.append({"source":caster,"start":caster.pos,"pos":at,"left":.9+i*.3,"flight":.9+i*.3,"damage":caster.stats.strike_damage if key=="mortar" else spec.damage,"radius":caster.stats.strike_radius if key=="mortar" else spec.radius,"mortar":key=="mortar"})
	if caster.team==0: toast(spec.title+" deployed • −%d Supply"%spec.supply)
	return true
func tick_blasts(delta: float) -> void:
	for i in range(blasts.size()-1,-1,-1):
		var blast: Dictionary = blasts[i]; blast.left-=delta
		if blast.left>0: continue
		for victim in units:
			if not victim.loaded and not victim.spec.flying and victim.team!=blast.source.team and victim.pos.distance_to(blast.pos)<blast.radius:
				damage(victim,blast.damage*(1.0 if victim.spec.infantry else .35),blast.source,true)
		effect(blast.pos,Color("ffd28b"),blast.radius,.65); blasts.remove_at(i)
func building_card(building: Dictionary) -> Button:
	var card: Button = Button.new(); card.custom_minimum_size=Vector2(252,100); card.clip_contents=true
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=Color("2b474e"); style.border_color=Color("557c82"); style.set_border_width_all(1); style.set_corner_radius_all(5); card.add_theme_stylebox_override("normal",style)
	var icon: UnitPortrait = UnitPortrait.new(); icon.building=true; icon.building_kind=building.type; icon.position=Vector2(8,10); icon.size=Vector2(64,64); card.add_child(icon)
	label_at(card,building_name(building.type),Vector2(81,10),15,CREAM)
	label_at(card,"CONSTRUCTING" if building.get("construction",0.0)>0 else "OPERATIONAL",Vector2(81,36),11,BLUE)
	var description: Label = label_at(card,building_specs[building.type].description,Vector2(81,55),11,Color("b5c8be")); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; description.size=Vector2(162,36)
	return card
func unload_position(at: Vector2, index: int) -> Vector2:
	for ring in range(1,6):
		for slot in 12:
			var candidate: Vector2 = at+Vector2.from_angle((slot+index*3)*TAU/12)*(50+ring*30)
			if Rect2(Vector2(30,30),field.SIZE-Vector2(60,60)).has_point(candidate) and not field.occupied(candidate,18): return candidate
	return field.navigation.get_point_position(field.free_cell(at))
func load_or_unload(transport: CombatUnit, allowed: Array[int] = [], mode: String = "toggle") -> void:
	if mode=="unload" or (mode=="toggle" and not transport.cargo.is_empty()):
		for index in transport.cargo.size():
			var passenger: CombatUnit = transport.cargo[index]
			passenger.loaded=false; passenger.pos=unload_position(transport.pos,index); passenger.command(passenger.pos)
		transport.cargo.clear()
		if transport.team==0: toast("Squads unloaded")
	else:
		for passenger in units:
			if passenger==transport or passenger.team!=transport.team or not passenger.spec.infantry or passenger.loaded or passenger.hp<=0: continue
			if not allowed.is_empty() and passenger.kind not in allowed: continue
			if passenger.pos.distance_to(transport.pos)<150 and transport.cargo.size()<transport.spec.cargo_capacity:
				passenger.command(passenger.pos,false,false); passenger.loaded=true; passenger.orders.clear(); passenger.setup=0; transport.cargo.append(passenger)
		if transport.team==0: toast("Loaded %d / %d squads"%[transport.cargo.size(),transport.spec.cargo_capacity])
	fog_clock=0

func refresh_resources() -> void:
	var supply_points: int = 0; var oil_wells: int = 0
	var victories: Array[int] = [0,0]
	for point in field.points:
		if point.type==0 and point.owner>=0: victories[point.owner]+=1
		if point.owner==0 and point.type==1: supply_points+=1
		if point.owner==0 and point.type==2: oil_wells+=1
	var supply_rate: int = int((2+Battlefield.SUPPLY_PER_POINT*supply_points)*60)
	var fuel_rate: int = int((.5+Battlefield.FUEL_PER_POINT*oil_wells)*60)
	supply_badge.value_label.text=format_amount(int(field.supply[0]))
	supply_badge.value_label.add_theme_font_size_override("font_size",25 if supply_badge.value_label.text.length()<=5 else 20)
	supply_badge.detail_label.text="+%d/min"%supply_rate
	supply_badge.tooltip_text="SUPPLY — shared spending currency\nBuildings, troops, upgrades and abilities.\nIncome: +120/min from HQ + %d/min from %d supply sectors.\nHQ healing spends supply separately."%[supply_rate-120,supply_points]
	fuel_badge.value_label.text=format_amount(int(field.fuel[0]))
	fuel_badge.value_label.add_theme_font_size_override("font_size",25 if fuel_badge.value_label.text.length()<=5 else 20)
	fuel_badge.detail_label.text="+%d/min"%fuel_rate
	fuel_badge.tooltip_text="FUEL — tanks and Heavy Workshop research\nIncome: +30/min base + %d/min from %d oil wells."%[fuel_rate-30,oil_wells]
	var used: int = manpower_used(0)
	var queued: int = 0
	for order in field.queues:
		if order.team==0: queued+=specs[order.kind].manpower
	manpower_badge.value_label.text="%d / %d"%[used,Battlefield.MANPOWER_CAP]
	manpower_badge.detail_label.text="%d free"%maxi(0,Battlefield.MANPOWER_CAP-used)
	manpower_badge.value_label.add_theme_color_override("font_color",RED if used>=Battlefield.MANPOWER_CAP else CREAM)
	manpower_badge.tooltip_text="MANPOWER — army capacity, not money\n%d deployed + %d reserved by training = %d / %d.\nLosses and cancelled/refunded orders release capacity."%[used-queued,queued,used,Battlefield.MANPOWER_CAP]
	for team in 2: ticket_labels[team].text="%d"%int(field.tickets[team])
	vp_label.text="VICTORY POINTS  %d : %d"%[victories[0],victories[1]]
	var difference: int = victories[0]-victories[1]
	drain_label.text="No ticket drain" if difference==0 else ("Crimson −%d/min" if difference>0 else "Azure −%d/min")%(absi(difference)*84)
	drain_label.add_theme_color_override("font_color",RED if difference<0 else CREAM)
	clock_label.text="%02d:%02d"%[int(elapsed)/60,int(elapsed)%60]
func format_amount(value: int) -> String:
	var digits: String = str(value)
	var formatted: String = ""
	for index in digits.length():
		if index>0 and (digits.length()-index)%3==0: formatted+=","
		formatted+=digits[index]
	return formatted
func build_tool_cards() -> void:
	var available: Array[String] = []
	if active.kind==2: tools_title.text="ENGINEER TOOLS"; available.assign(["build","repair","barricade","grenade"])
	elif active.kind==12: tools_title.text="COMMANDER ABILITIES"; available.assign(["grenade","mortar"])
	elif active.spec.cargo_capacity>0: tools_title.text="TRANSPORT TOOLS"; available.assign(["load","unload"])
	elif active.spec.infantry: tools_title.text="SQUAD ABILITIES"; available.assign(["grenade"])
	else: tools_title.text="UNIT TOOLS"
	var definitions: Dictionary = {
		"build":["Build","Production & defenses","Choose a plan"],
		"repair":["Repair","Vehicles & completed bases","No Supply cost"],
		"barricade":["Barricade","Directional infantry cover","45 Supply"],
		"grenade":["Grenade","Target ground area","%d Supply • G"%abilities.grenade.supply],
		"mortar":["Mortars","Six-shell barrage","%d Supply • M"%abilities.mortar.supply],
		"load":["Load","Nearby infantry squads","%d squad capacity"%active.spec.cargo_capacity],
		"unload":["Unload","Deploy passengers","%d aboard"%active.cargo.size()]}
	for key in available:
		var details: Array = definitions[key]
		var card: ToolCard = ToolCard.new(details[0],details[1],details[2],key)
		card.set_meta("cost_text",details[2]); card.set_meta("detail_text",details[1]); tools_grid.add_child(card); tool_buttons[key]=card
		card.pressed.connect(use_tool.bind(key))
	if available.is_empty(): label_at(tools_grid,"No active tools for this unit.",Vector2.ZERO,13,Color("9eb6ad"))
func builder_busy(builder: CombatUnit) -> bool:
	for site in field.buildings:
		if site.get("builder")==builder and site.get("construction",0.0)>0: return true
	return false
func refresh_tool_states() -> void:
	for key in tool_buttons:
		var card: ToolCard = tool_buttons[key]
		var reason: String = "Unload this squad first" if active.loaded else ""
		card.cost_label.text=card.get_meta("cost_text")
		card.detail_label.text=card.get_meta("detail_text")
		if key=="build" and builder_busy(active): reason="Engineer assigned to construction"
		if key=="barricade" and field.supply[0]<45: reason="Requires 45 Supply"
		if key in ["grenade","mortar"]:
			if active.ability_timers[key]>0:
				reason="Recharging: %.0fs"%active.ability_timers[key]; card.cost_label.text=reason
			if key=="mortar" and 17 not in active.purchased: reason="Buy Mortar Support to unlock"; card.cost_label.text="Upgrade required"
			if field.supply[0]<abilities[key].supply: reason="Insufficient Supply"
		if key in ["load","unload"]:
			card.detail_label.text="%d / %d squads aboard"%[active.cargo.size(),active.spec.cargo_capacity]
			if active.ability_cooldown>0: reason="Ready in %.0fs"%active.ability_cooldown; card.cost_label.text=reason
			elif key=="unload" and active.cargo.is_empty(): reason="Transport is empty"
			elif key=="load" and active.cargo.size()>=active.spec.cargo_capacity: reason="Transport is full"
			elif key=="load" and not units.any(func(u: CombatUnit) -> bool: return u!=active and u.team==active.team and u.spec.infantry and not u.loaded and u.hp>0 and u.pos.distance_to(active.pos)<150): reason="Move near friendly infantry to load"
		if key=="repair":
			card.detail_label.text="%.1f HP / sec"%active.stats.repair
			card.tooltip_text="Repair a damaged friendly vehicle or completed building.\nNo Supply cost. Engineer travels to the target.\nAdvanced Tools improves repair and construction speed."
		else: card.tooltip_text=card.detail_label.text+"\n"+str(card.get_meta("cost_text"))
		card.disabled=not reason.is_empty()
		if not reason.is_empty(): card.tooltip_text+="\n"+reason
	if placement_kind>=0: tool_hint.text="Choose a site • RMB / Esc cancels"
	elif engineer_mode=="barricade": tool_hint.text="Choose a spot • Tab rotates • RMB cancels"
	elif engineer_mode=="repair": tool_hint.text="Click a damaged vehicle or base • RMB cancels"
	elif ability_mode!="": tool_hint.text="Choose a target • RMB / Esc cancels"
	else: tool_hint.text=active.status
func use_tool(key: String) -> void:
	if active==null or active.loaded: return
	match key:
		"build": engineer_mode=""; ability_mode=""; set_build_menu(true)
		"repair","barricade": prepare_engineer_tool(key)
		"grenade","mortar": prepare_ability(key)
		"load","unload":
			if active.ability_cooldown>0: return
			var before: int = active.cargo.size()
			var any_squad: Array[int] = []
			load_or_unload(active,any_squad,key)
			if before!=active.cargo.size(): active.ability_cooldown=5
	refresh_tool_states()
func prepare_engineer_tool(key: String) -> void:
	if active==null or active.kind!=2 or active.loaded: return
	engineer_mode=key; engineer_caster=active; ability_mode=""; placement_kind=-1
	if key=="repair": toast("Click a damaged friendly vehicle or base")
	else: toast("Place cover • 45 Supply • Tab rotates • RMB cancels")
func cover_footprint(at: Vector2) -> Rect2:
	return Rect2(at-Vector2(10,65),Vector2(20,130)) if cover_vertical else Rect2(at-Vector2(65,10),Vector2(130,20))
func can_place_barricade(builder: CombatUnit, at: Vector2) -> bool:
	if builder==null or builder not in units or builder.kind!=2 or builder.loaded or builder.pos.distance_to(at)>220: return false
	var shape: Rect2 = cover_footprint(at)
	if not Rect2(Vector2(30,30),field.SIZE-Vector2(60,60)).encloses(shape) or field.water_blocked(at,35): return false
	for bridge in field.bridges:
		if bridge.grow(30).intersects(shape): return false
	for obstacle in field.obstacles():
		if obstacle.grow(20).intersects(shape): return false
	return true
func place_barricade(builder: CombatUnit, at: Vector2) -> bool:
	if not can_place_barricade(builder,at) or field.supply[builder.team]<45: return false
	field.supply[builder.team]-=45; field.covers.append(cover_footprint(at)); field.rebuild_navigation()
	toast("Barricade placed • −45 Supply"); return true
func assign_repair(builder: CombatUnit, target: CombatUnit = null, base: Dictionary = {}) -> bool:
	if builder==null or builder.kind!=2 or builder.loaded or builder not in units: return false
	var position: Vector2
	if target!=null:
		if target not in units or target.team!=builder.team or target.spec.infantry or target.hp<=0 or target.hp>=target.stats.hp: return false
		position=target.pos
	elif not base.is_empty():
		if base.team!=builder.team or base.hp<=0 or base.hp>=building_specs[base.type].health or base.get("construction",0.0)>0: return false
		position=base.pos
	else: return false
	var side: Vector2 = (builder.pos-position).normalized()
	if side.is_zero_approx(): side=Vector2.LEFT
	var worksite: Vector2 = position+side*100
	if field.occupied(worksite,18): worksite=field.navigation.get_point_position(field.free_cell(worksite))
	builder.command(worksite,false,false); builder.repair_unit=target; builder.repair_building=base.get("id",-1); builder.status="Travelling to repair"
	return true
func tick_repair(builder: CombatUnit, delta: float) -> void:
	var target: CombatUnit = builder.repair_unit
	var base: Dictionary = field.building_by_id(builder.repair_building)
	if target==null and base.is_empty():
		builder.repair_building=-1; return
	if (target!=null and (target not in units or target.loaded or target.hp<=0 or target.hp>=target.stats.hp)) or (not base.is_empty() and (base.hp<=0 or base.hp>=building_specs[base.type].health)):
		builder.repair_unit=null; builder.repair_building=-1; builder.goal=builder.pos; builder.status="Defending"; return
	var at: Vector2 = target.pos if target!=null else base.pos
	if builder.pos.distance_to(at)>135:
		var side: Vector2 = (builder.pos-at).normalized()
		if side.is_zero_approx(): side=Vector2.LEFT
		if builder.goal.distance_to(at+side*100)>35:
			var worksite: Vector2 = at+side*100
			builder.goal=field.navigation.get_point_position(field.free_cell(worksite)) if field.occupied(worksite,18) else worksite
		builder.status="Travelling to repair"; return
	builder.goal=builder.pos
	if builder.suppressed>0: builder.status="Repair paused"; return
	builder.status="Repairing vehicle" if target!=null else "Repairing "+building_name(base.type)
	if target!=null: target.hp=minf(target.stats.hp,target.hp+builder.stats.repair*delta)
	else: base.hp=minf(building_specs[base.type].health,base.hp+builder.stats.repair*delta)

func cover_destinations(at: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var nearby: Rect2
	var best: float = 85
	for rect in field.covers:
		var nearest: Vector2 = at.clamp(rect.position,rect.end)
		var distance: float = nearest.distance_to(at)
		if distance<best: best=distance; nearby=rect
	if nearby.size==Vector2.ZERO: return result
	var infantry: Array = selected.filter(func(u: CombatUnit) -> bool: return u.spec.infantry and not u.loaded)
	var normal: Vector2 = Vector2.DOWN if nearby.size.x>=nearby.size.y else Vector2.RIGHT
	var tangent: Vector2 = normal.orthogonal()
	var side: float = signf((at-nearby.get_center()).dot(normal))
	if side==0 and not infantry.is_empty(): side=signf((infantry[0].pos-nearby.get_center()).dot(normal))
	if side==0: side=1
	var length: float = maxf(nearby.size.x,nearby.size.y)
	for i in infantry.size():
		var along: float = (i-(infantry.size()-1)*.5)*36
		if absf(along)>length*.5-12: continue
		var spot: Vector2 = nearby.get_center()+normal*side*36+tangent*along
		if not field.occupied(spot,18): result[infantry[i]]=spot
	return result
func infantry_in_cover(at: Vector2) -> bool:
	for rect in field.covers:
		var nearest: Vector2 = at.clamp(rect.position,rect.end)
		if nearest.distance_to(at)<=58 and not rect.has_point(at): return true
	return false
func draw_cover_shield(at: Vector2, color: Color) -> void:
	var outline: PackedVector2Array = PackedVector2Array([at+Vector2(-10,-9),at+Vector2(10,-9),at+Vector2(9,3),at+Vector2(0,11),at+Vector2(-9,3)])
	draw_colored_polygon(outline,INK)
	var inner: PackedVector2Array = PackedVector2Array()
	for point in outline: inner.append(at+(point-at)*.72)
	draw_colored_polygon(inner,color)
	draw_line(at+Vector2(-4,0),at+Vector2(-1,4),INK,2,true)
	draw_line(at+Vector2(-1,4),at+Vector2(5,-4),INK,2,true)
