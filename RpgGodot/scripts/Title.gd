class_name Title
extends Node2D
## Titelbildschirm: Nachthimmel mit Bergen, die drei Helden am Lagerfeuer,
## Spiellogo und Startmenü (Neues Spiel / Steuerung).

signal start_game

const HEROES := [
	{"id": "serena", "pos": Vector2(324, 434), "flip": false},
	{"id": "milo", "pos": Vector2(408, 426), "flip": false},
	{"id": "rax", "pos": Vector2(630, 434), "flip": true},
]

const MENU_ITEMS := ["Neues Spiel", "Steuerung", "Einstellungen"]

var menu_index := 0
var menu_labels: Array = []
var anim_frame := 0
var hero_sprites: Array = []
var flame: Sprite2D
var help_panel: PanelContainer
var settings_panel: PanelContainer
var pad_label: Label
var ui: CanvasLayer
var _locked := false

func _ready() -> void:
	_build_sky()
	_build_mountains()
	_build_scene()
	_build_campfire()
	_build_fireflies()
	_build_ui()
	# Idle-Animation der Helden (4 DTII-Frames)
	var ticker := Timer.new()
	ticker.wait_time = 0.18
	ticker.autostart = true
	ticker.timeout.connect(_tick)
	add_child(ticker)

func _tick() -> void:
	anim_frame += 1
	for i in hero_sprites.size():
		var s: Sprite2D = hero_sprites[i]
		s.texture = SpriteFactory.field_char(HEROES[i]["id"], false, anim_frame)

static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _build_sky() -> void:
	var sky := Sprite2D.new()
	sky.texture = SpriteFactory.gradient(8, 64, Color(0.03, 0.04, 0.13), Color(0.24, 0.13, 0.30))
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.centered = false
	sky.scale = Vector2(960.0 / 8, 540.0 / 64)
	sky.z_index = -20
	add_child(sky)
	# Funkelnde Sterne im oberen Bereich
	for i in 60:
		var star := Sprite2D.new()
		star.texture = SpriteFactory.circle(1 + (i % 2), Color(1, 1, 0.9))
		star.position = Vector2(fmod(i * 137.5, 960.0), fmod(i * 83.7, 280.0))
		star.modulate.a = randf_range(0.25, 0.9)
		star.z_index = -19
		add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_property(star, "modulate:a", randf_range(0.1, 0.4), randf_range(0.9, 2.4))
		tw.tween_property(star, "modulate:a", randf_range(0.6, 1.0), randf_range(0.9, 2.4))
	# Mond mit weichem Glutschein
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(40, Color(0.9, 0.9, 1.0))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.material = _additive()
	glow.position = Vector2(770, 88)
	glow.modulate.a = 0.16
	glow.z_index = -19
	add_child(glow)
	var moon := Sprite2D.new()
	moon.texture = SpriteFactory.circle(20, Color(0.92, 0.93, 0.98))
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	moon.position = glow.position
	moon.z_index = -18
	add_child(moon)

## Zwei Silhouetten-Bergketten, die vordere dunkler — einfache Tiefenstaffelung.
func _build_mountains() -> void:
	_ridge(300.0, 70.0, 0.55, Color(0.16, 0.14, 0.30), -16)
	_ridge(360.0, 55.0, 0.9, Color(0.10, 0.09, 0.21), -15)
	# Bodennebel, der langsam quer zieht
	for i in 2:
		var fog := Sprite2D.new()
		fog.texture = SpriteFactory.particle("smoke_04")
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fog.position = Vector2(240 + i * 480, 342 + i * 26)
		fog.scale = Vector2(5.0, 2.2)
		fog.modulate = Color(0.55, 0.6, 0.85, 0.07)
		fog.z_index = -14
		add_child(fog)
		var tw := fog.create_tween().set_loops()
		var dx := 50.0 if i == 0 else -50.0
		tw.tween_property(fog, "position:x", fog.position.x + dx, 9.0 + i * 3.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(fog, "position:x", fog.position.x, 9.0 + i * 3.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ridge(base_y: float, amp: float, freq: float, color: Color, z: int) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-10, 560))
	for i in 33:
		var x := i * 30.0
		var y := base_y - absf(sin(x * 0.011 * freq + freq * 7.0)) * amp \
			- sin(x * 0.037 * freq) * amp * 0.25
		pts.append(Vector2(x, y))
	pts.append(Vector2(970, 560))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	poly.z_index = z
	add_child(poly)

func _build_scene() -> void:
	# Wiesenhügel, auf dem die Gruppe lagert
	var hill := Sprite2D.new()
	hill.texture = SpriteFactory.circle(60, Color(0.11, 0.155, 0.115))
	hill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hill.position = Vector2(480, 572)
	hill.scale = Vector2(11.0, 3.6)
	hill.z_index = -10
	add_child(hill)
	for def in HEROES:
		var s := Sprite2D.new()
		s.texture = SpriteFactory.field_char(def["id"], false, 0)
		s.scale = Vector2(5, 5)
		s.position = def["pos"]
		s.flip_h = def["flip"]
		add_child(s)
		hero_sprites.append(s)
		# Weicher Bodenschatten
		var sh := Sprite2D.new()
		sh.texture = SpriteFactory.circle(12, Color(0, 0, 0, 0.35))
		sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sh.position = def["pos"] + Vector2(0, 68)
		sh.scale = Vector2(3.2, 1.0)
		sh.z_index = -1
		add_child(sh)

func _build_campfire() -> void:
	var base := Vector2(512, 486)
	# Holzscheite als zwei gekreuzte dunkle Balken — vor den Helden (z 5)
	for r in [0.5, -0.5]:
		var log_p := Polygon2D.new()
		log_p.polygon = PackedVector2Array([
			Vector2(-20, -4), Vector2(20, -4), Vector2(20, 4), Vector2(-20, 4)])
		log_p.color = Color(0.24, 0.15, 0.09)
		log_p.position = base + Vector2(0, 5)
		log_p.rotation = r
		log_p.z_index = 5
		add_child(log_p)
	# Glutschein (additiv, pulsierend)
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.particle("light_01")
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.material = _additive()
	glow.position = base
	glow.scale = Vector2(1.5, 1.1)
	glow.modulate = Color(1.0, 0.55, 0.2, 0.5)
	glow.z_index = 5
	add_child(glow)
	var gt := glow.create_tween().set_loops()
	gt.tween_property(glow, "modulate:a", 0.32, 0.5).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glow, "modulate:a", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	# Heller Feuerkern, auf dem die Flammenzunge reitet
	var core := Sprite2D.new()
	core.texture = SpriteFactory.particle("fire_01")
	core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	core.material = _additive()
	core.position = base + Vector2(0, -10)
	core.scale = Vector2(0.26, 0.22)
	core.modulate = Color(1.0, 0.75, 0.35, 0.95)
	core.z_index = 6
	add_child(core)
	var ct := core.create_tween().set_loops()
	ct.tween_property(core, "scale", Vector2(0.23, 0.25), 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ct.tween_property(core, "scale", Vector2(0.27, 0.21), 0.19) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Aufsteigende Flämmchen wie bei den Kampf-Fackeln
	var licks := CPUParticles2D.new()
	licks.position = base + Vector2(0, -12)
	licks.amount = 14
	licks.lifetime = 0.8
	licks.direction = Vector2(0, -1)
	licks.spread = 14.0
	licks.gravity = Vector2(0, -70)
	licks.initial_velocity_min = 14.0
	licks.initial_velocity_max = 34.0
	licks.scale_amount_min = 0.8
	licks.scale_amount_max = 1.8
	licks.color = Color(1.0, 0.62, 0.22)
	licks.texture = SpriteFactory.circle(3, Color.WHITE)
	licks.z_index = 6
	add_child(licks)
	# Züngelnde Flamme (Kenney-Partikeltextur, Skala wackelt)
	flame = Sprite2D.new()
	flame.texture = SpriteFactory.particle("flame_02")
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flame.material = _additive()
	flame.position = base + Vector2(0, -24)
	flame.scale = Vector2(0.46, 0.52)
	flame.modulate = Color(1.0, 0.7, 0.3, 0.95)
	flame.z_index = 7
	add_child(flame)
	var ft := flame.create_tween().set_loops()
	ft.tween_property(flame, "scale", Vector2(0.40, 0.60), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ft.tween_property(flame, "scale", Vector2(0.49, 0.48), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Aufsteigende Funken
	var sparks := CPUParticles2D.new()
	sparks.z_index = 6
	sparks.position = base + Vector2(0, -12)
	sparks.amount = 10
	sparks.lifetime = 1.4
	sparks.direction = Vector2(0, -1)
	sparks.spread = 16.0
	sparks.gravity = Vector2(0, -26)
	sparks.initial_velocity_min = 18.0
	sparks.initial_velocity_max = 42.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.1
	sparks.color = Color(1.0, 0.65, 0.25)
	sparks.texture = SpriteFactory.circle(2, Color.WHITE)
	add_child(sparks)
	# Warmes Flackerlicht auf der Gruppe
	var light := Fx.point_light(Color(1.0, 0.6, 0.25), 280.0, 1.4)
	light.position = base + Vector2(0, -14)
	add_child(light)
	Fx.flicker(light, 1.4)

func _build_fireflies() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(480, 420)
	p.amount = 12
	p.lifetime = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(440, 70)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color = Color(0.8, 1.0, 0.45, 0.7)
	p.texture = SpriteFactory.circle(2, Color.WHITE)
	p.material = _additive()
	add_child(p)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vig)
	# Logo mit sanftem Schweben
	var logo := _label("FABLE RPG", 68, Color(1.0, 0.85, 0.32), 96)
	logo.add_theme_constant_override("outline_size", 12)
	var lt := logo.create_tween().set_loops()
	lt.tween_property(logo, "position:y", 92.0, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lt.tween_property(logo, "position:y", 96.0, 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_label("Ein Mini-JRPG-Abenteuer", 19, Color(0.82, 0.82, 0.95), 176)
	# Startmenü
	for i in MENU_ITEMS.size():
		var l := _label(MENU_ITEMS[i], 24, Color.WHITE, 252 + i * 38)
		menu_labels.append(l)
	_redraw_menu()
	# Hilfe-Overlay (Steuerung), anfangs verborgen
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(300, 210)
	help_panel.custom_minimum_size = Vector2(360, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	help_panel.add_child(vb)
	var lines := [
		["— Steuerung —", 20, Color(1.0, 0.85, 0.32)],
		["Pfeiltasten / WASD — Bewegen", 17, Color.WHITE],
		["Z / Enter / Leertaste — Bestätigen, Reden", 17, Color.WHITE],
		["X / Esc — Abbrechen", 17, Color.WHITE],
		["Am Handy: eingeblendete Bildschirm-Tasten", 15, Color(0.75, 0.75, 0.9)],
		["Z: Schließen", 15, Color(0.75, 0.75, 0.9)],
	]
	for e in lines:
		var l := Label.new()
		l.text = e[0]
		l.add_theme_font_size_override("font_size", e[1])
		l.add_theme_color_override("font_color", e[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	help_panel.visible = false
	ui.add_child(help_panel)
	# Einstellungs-Overlay (Bildschirm-Tasten an/aus), anfangs verborgen
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(300, 220)
	settings_panel.custom_minimum_size = Vector2(360, 0)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 10)
	settings_panel.add_child(svb)
	var stitle := Label.new()
	stitle.text = "— Einstellungen —"
	stitle.add_theme_font_size_override("font_size", 20)
	stitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32))
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(stitle)
	pad_label = Label.new()
	pad_label.add_theme_font_size_override("font_size", 18)
	pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(pad_label)
	var shint := Label.new()
	shint.text = "Z: Umschalten   ·   X: Zurück"
	shint.add_theme_font_size_override("font_size", 15)
	shint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	shint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(shint)
	var shint2 := Label.new()
	shint2.text = "Tipp: 5-mal schnell tippen blendet das Pad wieder ein"
	shint2.add_theme_font_size_override("font_size", 13)
	shint2.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	shint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svb.add_child(shint2)
	_refresh_pad_label()
	settings_panel.visible = false
	ui.add_child(settings_panel)

func _refresh_pad_label() -> void:
	pad_label.text = "Bildschirm-Tasten (Pad):  %s" % ("AN" if GameState.touch_pad else "AUS")
	pad_label.add_theme_color_override("font_color",
		Color(0.55, 1.0, 0.6) if GameState.touch_pad else Color(1.0, 0.55, 0.5))

func _label(text: String, size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.custom_minimum_size = Vector2(960, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	ui.add_child(l)
	return l

func _redraw_menu() -> void:
	for i in menu_labels.size():
		var l: Label = menu_labels[i]
		var selected := i == menu_index
		l.text = ("> " if selected else "") + MENU_ITEMS[i]
		l.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.32) if selected else Color(0.8, 0.8, 0.88))

func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if help_panel.visible:
		if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
			AudioManager.play_sfx("menu")
			help_panel.visible = false
		return
	if settings_panel.visible:
		if event.is_action_pressed("confirm"):
			# Bildschirm-Tasten umschalten (wird sofort angewendet + gespeichert)
			AudioManager.play_sfx("buy")
			GameState.set_touch_pad(not GameState.touch_pad)
			_refresh_pad_label()
		elif event.is_action_pressed("cancel"):
			AudioManager.play_sfx("menu")
			settings_panel.visible = false
		return
	if event.is_action_pressed("move_up"):
		AudioManager.play_sfx("menu")
		menu_index = (menu_index - 1 + MENU_ITEMS.size()) % MENU_ITEMS.size()
		_redraw_menu()
	elif event.is_action_pressed("move_down"):
		AudioManager.play_sfx("menu")
		menu_index = (menu_index + 1) % MENU_ITEMS.size()
		_redraw_menu()
	elif event.is_action_pressed("confirm"):
		match menu_index:
			0:
				_locked = true
				AudioManager.play_sfx("buy")
				start_game.emit()
			1:
				AudioManager.play_sfx("menu")
				help_panel.visible = true
			2:
				AudioManager.play_sfx("menu")
				_refresh_pad_label()
				settings_panel.visible = true
