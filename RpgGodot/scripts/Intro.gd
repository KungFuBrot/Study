class_name Intro
extends Node2D
## Erzähl-Auftakt nach „Neues Spiel": drei Kapitel Text über Nachthimmel
## und Bergsilhouette, Z blättert weiter (letzte Seite startet das Spiel).

signal done

const PAGES := [
	[
		"Es war einmal ein Tal,",
		"in dem der Fluss wie flüssiges Glas glitzerte.",
		"",
		"Lindenhain lebte von seinem Wasser —",
		"und von seiner Gemeinschaft.",
	],
	[
		"Doch dann kamen die drei Plagen:",
		"",
		"Das Schlotwerk kippte seinen Giftschlamm in den Fluss.",
		"Der Konzernturm presste die Dörfer bis aufs Mark aus.",
		"Und in einer Festung im Südwesten wurde Hass gepredigt.",
	],
	[
		"Drei Gefährten brechen auf, das Tal zu befreien:",
		"",
		"Helen, die Klinge des Lichts.",
		"Janosch, der Meister der Flammen.",
		"Wally, das Herz aus Stahl.",
		"",
		"Ihre Reise beginnt am rauchenden Schlotwerk ...",
	],
]

var page := -1
var page_labels: Array = []
var ui: CanvasLayer
var hint: Label
var _finished := false

func _ready() -> void:
	_build_sky()
	ui = CanvasLayer.new()
	add_child(ui)
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vig)
	hint = Label.new()
	hint.text = "Z: Weiter"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.custom_minimum_size = Vector2(960, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 500)
	ui.add_child(hint)
	var blink := hint.create_tween().set_loops()
	blink.tween_property(hint, "modulate:a", 0.35, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blink.tween_property(hint, "modulate:a", 1.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_page()

func _build_sky() -> void:
	var sky := Sprite2D.new()
	sky.texture = SpriteFactory.gradient(8, 64, Color(0.03, 0.04, 0.12), Color(0.18, 0.10, 0.24))
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky.centered = false
	sky.scale = Vector2(960.0 / 8, 540.0 / 64)
	sky.z_index = -20
	add_child(sky)
	for i in 50:
		var star := Sprite2D.new()
		star.texture = SpriteFactory.circle(1 + (i % 2), Color(1, 1, 0.9))
		star.position = Vector2(fmod(i * 137.5, 960.0), fmod(i * 91.3, 320.0))
		star.modulate.a = randf_range(0.2, 0.8)
		star.z_index = -19
		add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_property(star, "modulate:a", randf_range(0.1, 0.35), randf_range(0.9, 2.4))
		tw.tween_property(star, "modulate:a", randf_range(0.55, 0.95), randf_range(0.9, 2.4))
	# Ferne Bergkette am Horizont
	var pts := PackedVector2Array()
	pts.append(Vector2(-10, 560))
	for i in 33:
		var x := i * 30.0
		pts.append(Vector2(x, 400.0 - absf(sin(x * 0.008 + 5.0)) * 70.0))
	pts.append(Vector2(970, 560))
	var ridge := Polygon2D.new()
	ridge.polygon = pts
	ridge.color = Color(0.09, 0.08, 0.18)
	ridge.z_index = -16
	add_child(ridge)

func _next_page() -> void:
	page += 1
	if page >= PAGES.size():
		if not _finished:
			_finished = true
			AudioManager.play_sfx("menu")
			done.emit()
		return
	AudioManager.play_sfx("menu")
	# Alte Zeilen ausblenden, neue gestaffelt einblenden
	for l: Label in page_labels:
		var out := l.create_tween()
		out.tween_property(l, "modulate:a", 0.0, 0.3)
		out.tween_callback(l.queue_free)
	page_labels.clear()
	var lines: Array = PAGES[page]
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		var headline: bool = page == 0 and i == 0
		l.add_theme_font_size_override("font_size", 24 if headline else 21)
		l.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.4) if headline else Color(0.92, 0.92, 0.98))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.custom_minimum_size = Vector2(960, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 140 + i * 40)
		l.modulate.a = 0.0
		ui.add_child(l)
		page_labels.append(l)
		var tw := l.create_tween()
		tw.tween_interval(0.25 + i * 0.55)
		tw.tween_property(l, "modulate:a", 1.0, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("confirm"):
		_next_page()
	elif event.is_action_pressed("cancel"):
		# Ganz überspringen
		page = PAGES.size()
		_next_page()
