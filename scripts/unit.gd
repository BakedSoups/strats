class_name CombatUnit
extends RefCounted
var spec: UnitSpec
var kind: int
var team: int
var pos: Vector2
var goal: Vector2
var orders: Array[Vector2] = []
var hp: float
var stats: Dictionary = {}
var purchased: Array[int] = []
var angle: float = 0
var hull: float = 0
var cooldown: float = 0
var setup: float = 0
var burn: float = 0
var burn_dps: float = 6
var ability_cooldown: float = 0
var burst: int = 0
var suppressed: float = 0
var xp: float = 0
var level: int = 0
var retreating: bool = false
var attack_move: bool = true
var cargo: Array[CombatUnit] = []
var loaded: bool = false
var path: PackedVector2Array = []
var path_goal: Vector2 = Vector2.INF
var nav_revision: int = -1
var ability_timers: Dictionary = {"grenade":0.0,"mortar":0.0}
var repair_unit: CombatUnit
var repair_building: int = -1
var status: String = "Defending"
func _init(s: UnitSpec, k: int, t: int, at: Vector2) -> void:
	spec = s
	kind = k
	team = t
	pos = at
	goal = at
	hp = s.hp
	stats = {"hp":s.hp,"speed":s.speed,"damage":s.damage,"reach":s.reach,"reload":s.reload,"armor":s.armor,"setup":s.weapon.setup_time,"repair":12.0,"sight":s.sight,"strike_damage":48.0,"strike_radius":85.0}
func command(to: Vector2, queued: bool = false, aggressive: bool = true) -> void:
	if not queued: repair_unit=null; repair_building=-1
	if queued:
		orders.append(to)
	else:
		orders.clear()
		goal = to
	attack_move = aggressive
	retreating = false
	status = "Attack move" if aggressive else "Moving"
func upgrade(id: int, data: UpgradeSpec) -> void:
	purchased.append(id)
	stats[data.stat] *= data.factor
	if data.stat == "hp": hp += stats.hp - spec.hp
