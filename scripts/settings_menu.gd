class_name SettingsMenu
extends Control
signal closed
signal applied
var settings: GameSettings
var draft: Dictionary
var draft_keys: Dictionary
var controls: Dictionary = {}
var key_buttons: Dictionary = {}
var waiting: String = ""
var note: Label
func _init(service: GameSettings) -> void:
	settings=service
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new(); shade.color=Color(0.04,.09,.11,.9); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var frame: Panel = Panel.new(); frame.position=Vector2(240,65); frame.size=Vector2(960,770); add_child(frame)
	var style: StyleBoxFlat = StyleBoxFlat.new(); style.bg_color=Color("1b2d33"); style.border_color=Color("53b8ed"); style.set_border_width_all(2); frame.add_theme_stylebox_override("panel",style)
	add_label(frame,"SETTINGS",Vector2(34,20),30,Color("53b8ed"))
	add_label(frame,"Preferences are saved on Apply. The match pauses while this menu is open.",Vector2(35,66),16)
	add_label(frame,"AUDIO & DISPLAY",Vector2(35,116),18,Color("53b8ed"))
	add_slider(frame,"master","Master volume",155,0,100,1,"%")
	add_slider(frame,"music","Music volume",205,0,100,1,"%")
	add_slider(frame,"effects","Effects volume",255,0,100,1,"%")
	add_label(frame,"Volume controls are ready; this build has no game audio yet.",Vector2(35,304),13,Color("9cb2ac"))
	add_label(frame,"Resolution",Vector2(35,345),16)
	var resolution: OptionButton = OptionButton.new(); resolution.position=Vector2(230,335); resolution.size=Vector2(205,35); frame.add_child(resolution)
	for size_option: Vector2i in GameSettings.RESOLUTIONS: resolution.add_item("%d × %d"%[size_option.x,size_option.y])
	controls.resolution=resolution
	resolution.item_selected.connect(func(index: int) -> void: draft.resolution=index)
	add_toggle(frame,"fullscreen","Fullscreen",390)
	add_label(frame,"Window resolution applies in windowed mode.",Vector2(35,439),13,Color("9cb2ac"))
	add_label(frame,"CAMERA",Vector2(35,490),18,Color("53b8ed"))
	add_slider(frame,"camera_speed","Pan speed",530,200,1400,50," px/s")
	add_slider(frame,"zoom_sensitivity","Zoom sensitivity",580,.25,2.5,.05,"×")
	add_toggle(frame,"edge_scrolling","Edge scrolling",630)
	add_label(frame,"KEY BINDINGS",Vector2(510,116),18,Color("53b8ed"))
	add_label(frame,"Click a binding, then press a key. Esc cancels rebinding.",Vector2(510,145),13)
	var row: int = 0
	for action: String in GameSettings.DEFAULT_KEYS:
		add_label(frame,GameSettings.ACTION_NAMES[action],Vector2(510,194+row*52),17)
		var b: Button = add_button(frame,"",Vector2(737,184+row*52),Vector2(185,38))
		b.pressed.connect(begin_rebind.bind(action)); key_buttons[action]=b; row+=1
	add_label(frame,"Esc: menu • Shift: queue • Ctrl + 0–9: groups\nG: grenade • M: mortars (reserved)\nMouse buttons and these modifiers stay reserved.",Vector2(510,568),14,Color("9cb2ac"))
	note=add_label(frame,"",Vector2(35,681),14,Color("f2ce85"))
	add_button(frame,"Restore defaults",Vector2(35,720),Vector2(220,34)).pressed.connect(reset_draft)
	add_button(frame,"Cancel / Back",Vector2(490,720),Vector2(205,34)).pressed.connect(close_menu)
	add_button(frame,"Apply & Save",Vector2(715,720),Vector2(205,34)).pressed.connect(apply_draft)
	hide()
func add_label(parent: Node, text: String, at: Vector2, font_size: int, color: Color=Color("dfebdf")) -> Label:
	var label: Label = Label.new(); label.text=text; label.position=at; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(label); return label
func add_button(parent: Node, text: String, at: Vector2, size_button: Vector2) -> Button:
	var button: Button = Button.new(); button.text=text; button.position=at; button.size=size_button; button.add_theme_font_size_override("font_size",16); parent.add_child(button); return button
func add_slider(parent: Node, key: String, title: String, y: float, minimum: float, maximum: float, step_size: float, suffix: String) -> void:
	add_label(parent,title,Vector2(35,y),16)
	var slider: HSlider = HSlider.new(); slider.position=Vector2(230,y+4); slider.size=Vector2(150,25); slider.min_value=minimum; slider.max_value=maximum; slider.step=step_size; parent.add_child(slider); controls[key]=slider
	var value_label: Label = add_label(parent,"",Vector2(390,y),14)
	slider.value_changed.connect(func(value: float) -> void:
		draft[key]=value
		value_label.text=("%.2f"%value if suffix=="×" else "%d"%value)+suffix)
func add_toggle(parent: Node, key: String, title: String, y: float) -> void:
	var toggle: CheckButton = CheckButton.new(); toggle.text=title; toggle.position=Vector2(35,y); toggle.size=Vector2(400,36); parent.add_child(toggle); controls[key]=toggle
	toggle.toggled.connect(func(enabled: bool) -> void: draft[key]=enabled)
func open_menu() -> void:
	draft=settings.values.duplicate(true); draft_keys=settings.bindings.duplicate()
	waiting=""; note.text=""; refresh_controls(); show()
func refresh_controls() -> void:
	for key: String in controls:
		var control: Control = controls[key]
		if control is Range:
			control.value=float(draft[key])
			control.value_changed.emit(control.value)
		elif control is CheckButton: control.set_pressed_no_signal(draft[key])
		elif control is OptionButton: control.select(draft[key])
	for key: String in key_buttons: key_buttons[key].text=OS.get_keycode_string(draft_keys[key])
func begin_rebind(action: String) -> void:
	waiting=action
	for key: String in key_buttons: key_buttons[key].text=OS.get_keycode_string(draft_keys[key])
	key_buttons[action].text="Press a key…"
	note.text="Binding "+GameSettings.ACTION_NAMES[action]+" • Esc to cancel"
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	if not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if waiting!="":
		if event.keycode==KEY_ESCAPE:
			waiting=""; note.text="Rebinding cancelled."; refresh_controls(); return
		if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
			note.text="Choose a key without modifiers."; return
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		var problem: String = settings.conflict(waiting,code,draft_keys)
		if problem!="": note.text=problem; return
		draft_keys[waiting]=code; waiting=""; note.text="Binding updated. Apply to save."; refresh_controls()
	elif event.keycode==KEY_ESCAPE: close_menu()
func reset_draft() -> void:
	waiting=""; draft=settings.defaults(); draft_keys=GameSettings.DEFAULT_KEYS.duplicate(); refresh_controls(); note.text="Defaults restored in preview. Apply to save."
func apply_draft() -> void:
	if waiting!="": note.text="Finish or cancel rebinding first."; return
	var old_values: Dictionary = settings.values.duplicate()
	var old_keys: Dictionary = settings.bindings.duplicate()
	settings.values=draft.duplicate(); settings.bindings=draft_keys.duplicate()
	settings.normalize()
	if settings.save()!=OK:
		settings.values=old_values; settings.bindings=old_keys; note.text="Could not save settings. Previous settings are still active."; return
	settings.apply()
	applied.emit()
	note.text="Settings saved. Back or Esc returns to the previous screen."
func close_menu() -> void:
	waiting=""; hide(); closed.emit()
