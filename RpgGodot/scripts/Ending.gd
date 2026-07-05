class_name Ending
extends Node2D
## Abspann nach dem Boss-Sieg: Sternenhimmel, Feuerwerk, die Helden auf einem
## Hügel und nacheinander einblendende Credits. Z startet ein neues Abenteuer.

signal restart

var _done := false
var _can_continue := false

func _ready() -> void:
	AudioManager.play_music("ending")
	_build_sky()
	_build_scene()
	_build_text()
	# Feuerwerk in lockerer Folge
	var timer := Timer.new()
	timer.wait_time = 0.9
	timer.autostart = true
	timer.timeout.connect(_firework)
	add_child(timer)

func _build_sky() -> void:
	var sky := Sprite2D.new()
	sky.texture = SpriteFactory.gradient(8, 64, Color(0.04, 0.03, 0.12), Color(0.16, 0.10, 0.28))
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.centered = false
	sky.scale = Vector2(960.0 / 8, 540.0 / 64)
	sky.z_index = -20
	add_child(sky)
	for i in 70:
		var star := Sprite2D.new()
		var size := 1 + (i % 2)
		star.texture = SpriteFactory.circle(size, Color(1, 1, 0.9))
		star.position = Vector2(fmod(i * 137.5, 960.0), fmod(i * 91.3, 330.0))
		star.modulate.a = randf_range(0.3, 1.0)
		star.z_index = -18
		add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_property(star, "modulate:a", randf_range(0.1, 0.4), randf_range(0.8, 2.2))
		tw.tween_property(star, "modulate:a", randf_range(0.7, 1.0), randf_range(0.8, 2.2))

func _build_scene() -> void:
	# Hügel, auf dem die Helden stehen
	var hill := Sprite2D.new()
	hill.texture = SpriteFactory.circle(60, Color(0.10, 0.16, 0.10))
	hill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hill.position = Vector2(480, 560)
	hill.scale = Vector2(9, 3.2)
	hill.z_index = -10
	add_child(hill)
	var ids := ["serena", "milo"]
	for i in ids.size():
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(ids[i], "down", 0)
		s.scale = Vector2(6, 6)
		s.position = Vector2(430 + i * 100, 420)
		add_child(s)
		var bob := s.create_tween().set_loops()
		bob.tween_property(s, "position:y", s.position.y - 6.0, 1.2 + i * 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(s, "position:y", s.position.y, 1.2 + i * 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_text() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
	var entries := [
		["DAS ABENTEUER IST VOLLBRACHT", 40, Color(1.0, 0.85, 0.3), 60],
		["Knochenkönig und Frostkoloss sind Geschichte.", 22, Color.WHITE, 140],
		["Frieden kehrt in Finsterhöhle und Frostgrotte ein,", 22, Color.WHITE, 175],
		["und Lindenhain feiert seine Helden.", 22, Color.WHITE, 210],
		["Serena  —  die Klinge des Lichts", 19, Color(0.95, 0.7, 0.7), 265],
		["Milo  —  der Meister der Flammen", 19, Color(0.7, 0.75, 0.95), 295],
		["Erbeutetes Gold: %d" % GameState.gold, 19, Color(1.0, 0.85, 0.3), 330],
		["— DANKE FÜRS SPIELEN —", 26, Color(1.0, 0.85, 0.3), 480],
	]
	for i in entries.size():
		var e: Array = entries[i]
		var l := Label.new()
		l.text = e[0]
		l.add_theme_font_size_override("font_size", e[1])
		l.add_theme_color_override("font_color", e[2])
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.custom_minimum_size = Vector2(960, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, e[3])
		l.modulate.a = 0.0
		layer.add_child(l)
		var tw := l.create_tween()
		tw.tween_interval(0.6 + i * 0.7)
		tw.tween_property(l, "modulate:a", 1.0, 0.8)
	# Hinweis zum Neustart erscheint zuletzt und blinkt sanft
	var hint := Label.new()
	hint.text = "Z: Neues Abenteuer beginnen"
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.custom_minimum_size = Vector2(960, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 515)
	hint.modulate.a = 0.0
	layer.add_child(hint)
	var ht := hint.create_tween()
	ht.tween_interval(0.6 + entries.size() * 0.7 + 0.5)
	ht.tween_callback(func(): _can_continue = true)
	ht.tween_property(hint, "modulate:a", 1.0, 0.6)
	ht.tween_callback(func():
		var blink := hint.create_tween().set_loops()
		blink.tween_property(hint, "modulate:a", 0.35, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		blink.tween_property(hint, "modulate:a", 1.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

func _firework() -> void:
	var pos := Vector2(randf_range(120, 840), randf_range(60, 240))
	var colors := [Color(1.0, 0.4, 0.3), Color(0.4, 0.8, 1.0), Color(1.0, 0.85, 0.3),
		Color(0.6, 1.0, 0.5), Color(0.9, 0.5, 1.0)]
	var color: Color = colors[randi() % colors.size()]
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = color
	p.texture = SpriteFactory.circle(3, Color.WHITE)
	p.emitting = true
	add_child(p)
	var flash := Sprite2D.new()
	flash.texture = SpriteFactory.circle(20, color)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flash.position = pos
	flash.scale = Vector2(0.3, 0.3)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
	var pt := p.create_tween()
	pt.tween_interval(2.0)
	pt.tween_callback(p.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") and _can_continue and not _done:
		_done = true
		AudioManager.play_sfx("menu")
		restart.emit()
