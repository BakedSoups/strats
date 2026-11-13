class_name GameSettings
extends RefCounted
const PATH: String = "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1600,900),Vector2i(1920,1080)]
const DEFAULT_KEYS: Dictionary = {"camera_up":KEY_UP,"camera_down":KEY_DOWN,"camera_left":KEY_LEFT,"camera_right":KEY_RIGHT,"attack_move":KEY_A,"stop":KEY_X,"retreat":KEY_R}
const ACTION_NAMES: Dictionary = {"camera_up":"Camera up","camera_down":"Camera down","camera_left":"Camera left","camera_right":"Camera right","attack_move":"Fire in range","stop":"Stop","retreat":"Retreat"}
var values: Dictionary = defaults()
var bindings: Dictionary = DEFAULT_KEYS.duplicate()
var storage_path: String = PATH
func _init(path: String = PATH) -> void:
	storage_path=path
func defaults() -> Dictionary:
	return {"master":80.0,"music":70.0,"effects":85.0,"resolution":1,"fullscreen":false,"camera_speed":650.0,"zoom_sensitivity":1.0,"edge_scrolling":false}
func load_saved() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(storage_path)==OK:
		for key: String in values:
			var candidate: Variant = config.get_value("settings",key,values[key])
			if typeof(candidate)==typeof(values[key]) or (candidate is int and values[key] is float): values[key]=candidate
		var restored: Dictionary = {}
		for key: String in DEFAULT_KEYS:
			var candidate: Variant = config.get_value("bindings",key,DEFAULT_KEYS[key])
			if candidate is not int or not allowed_key(candidate) or candidate in restored.values():
				restored.clear(); break
			restored[key]=candidate
		if restored.size()==DEFAULT_KEYS.size():
			var legacy: Dictionary = {"camera_up":KEY_W,"camera_down":KEY_S,"camera_left":KEY_A,"camera_right":KEY_D,"attack_move":KEY_Q,"stop":KEY_X,"retreat":KEY_R}
			bindings=DEFAULT_KEYS.duplicate() if restored==legacy else restored
	normalize()
func normalize() -> void:
	for key: String in ["master","music","effects"]: values[key]=clampf(float(values[key]),0,100)
	values.resolution=clampi(int(values.resolution),0,RESOLUTIONS.size()-1)
	values.camera_speed=clampf(float(values.camera_speed),200,1400)
	values.zoom_sensitivity=clampf(float(values.zoom_sensitivity),.25,2.5)
func save() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: String in values: config.set_value("settings",key,values[key])
	for key: String in bindings: config.set_value("bindings",key,bindings[key])
	return config.save(storage_path)
func apply(display: bool = true) -> void:
	normalize()
	for bus_name: String in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus_name)
			AudioServer.set_bus_send(index,"Master")
	for key: String in ["master","music","effects"]:
		var index: int = AudioServer.get_bus_index("Master" if key=="master" else key.capitalize())
		var volume: float = float(values[key])/100.0
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,volume)))
		AudioServer.set_bus_mute(index,volume<=0)
	for key: String in bindings:
		var action: String = "strats_"+key
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode=bindings[key]
		InputMap.action_add_event(action,event)
	if display and DisplayServer.get_name()!="headless":
		var fullscreen: bool = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen!=bool(values.fullscreen): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not values.fullscreen and DisplayServer.window_get_size()!=RESOLUTIONS[values.resolution]:
			DisplayServer.window_set_size(RESOLUTIONS[values.resolution])
			var area: Rect2i = DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(area.position+(area.size-RESOLUTIONS[values.resolution])/2)
func key_label(action: String) -> String:
	return OS.get_keycode_string(bindings[action])
func allowed_key(code: int) -> bool:
	return code>=KEY_A and code<=KEY_Z or code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9,KEY_F10,KEY_F11,KEY_F12]
func conflict(action: String, code: int, proposed: Dictionary) -> String:
	if not allowed_key(code): return "Use a letter, arrow, Space, or F1–F12. Esc and numbers are reserved."
	for other: String in proposed:
		if other!=action and proposed[other]==code: return "Already used by "+ACTION_NAMES[other]+". Choose another key."
	return ""
