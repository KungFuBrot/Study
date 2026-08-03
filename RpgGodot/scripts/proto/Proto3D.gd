class_name Proto3D
extends Node
## Backt alle 3D-Figuren zu Pixel-Art-Sprite-Blättern.
##
## Ablauf wie bei Motion Twin: orthografische Kamera, SEHR kleine Auflösung,
## keine Kantenglättung — daraus kommt die Pixeligkeit. Danach in 2D die
## Farbstufen zusammenfassen und eine dunkle Kontur ziehen, damit sich die
## Figur vom Hintergrund löst.
##
## Aufruf: env PROTO3D=<Zielordner> setzen und das Spiel NICHT headless starten
## (headless hat kein Rendergerät, der Viewport bliebe leer). Ergebnis sind
## PNG-Streifen `<id>_<anim>[_<ansicht>].png`, die RigFactory zur Laufzeit lädt.

# Farbstufen je Kanal. Wenige Stufen = deutliche Bänder wie in gemalter
# Pixel-Art; zu viele und es sieht aus wie ein verkleinerter 3D-Screenshot.
const LEVELS := 6

var _vp: SubViewport
var _cam: Camera3D
var _rig: Rig3D

func _make_viewport(size: Vector2i, cam_size: float) -> void:
	_vp = SubViewport.new()
	_vp.size = size
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Kantenglättung aus: die harte Treppe IST der Look.
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.use_taa = false
	add_child(_vp)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = cam_size
	# Fast waagerecht und auf der Seite, zu der die Figur blickt. Schaut die
	# Kamera von oben herab, kippt die Figur im Bild nach hinten; steht sie
	# hinter der Figur, sieht man nur Rücken.
	var d := cam_size / 2.10
	_cam.look_at_from_position(Vector3(3.4 * d, 0.50 * cam_size, -1.5 * d),
		Vector3(0, 0.46 * cam_size, 0), Vector3.UP)
	_vp.add_child(_cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Hell backen: die Szenen dunkeln die Figuren über CanvasModulate und
	# Vignette ein ZWEITES Mal ab. Wer schon dunkel gebacken ist, wird dort
	# zur Silhouette.
	env.ambient_light_color = Color(0.52, 0.52, 0.58)
	env.ambient_light_energy = 1.50
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	# Dreipunktlicht. Das harte Kantenlicht von hinten macht den Unterschied —
	# es zieht die Silhouette nach, dadurch löst sich die Figur vom Grund.
	# Fülllicht und Kantenlicht waren zu stark: sie überstrahlten die
	# Eigenfarben, alles wurde blaustichig und blass. Jetzt setzt das
	# Hauptlicht die Farbe, die anderen beiden modellieren nur noch.
	_light(Vector3(-38, -30, -20), Color(1.0, 0.95, 0.86), 3.8)
	_light(Vector3(-20, 135, 10), Color(0.70, 0.76, 0.95), 0.5)
	_light(Vector3(-14, 210, 0), Color(1.0, 0.90, 0.78), 2.4)

func _light(rot: Vector3, col: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot
	l.light_color = col
	l.light_energy = energy
	l.shadow_enabled = false
	_vp.add_child(l)

func _make_rig(id: String, turn: float) -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.queue_free()
	var s := Figures3D.spec(id)
	_rig = Rig3D.new()
	match String(s.get("form", "human")):
		"blob": _rig.build_blob(s)
		"quad": _rig.build_quadruped(s)
		"spider": _rig.build_spider(s)
		_: _rig.build_humanoid(s)
	# Die Figuren sind nach +X gebaut. 90 Grad dreht sie in Dreiviertelansicht
	# nach rechts — exakt zur Bildschirmachse wäre reines, papierdünnes Profil.
	_rig.rotation_degrees = Vector3(0, turn, 0)
	_vp.add_child(_rig)

## Farbstufen zusammenfassen und dunkle Kontur ziehen.
static func stylize(src: Image) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var q := Image.create(w, h, false, Image.FORMAT_RGBA8)
	q.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var r := roundf(c.r * (LEVELS - 1)) / float(LEVELS - 1)
			var g := roundf(c.g * (LEVELS - 1)) / float(LEVELS - 1)
			var b := roundf(c.b * (LEVELS - 1)) / float(LEVELS - 1)
			var col := Color(r, g, b, 1.0)
			var lum := (r + g + b) / 3.0
			col = col.lerp(Color(lum, lum, lum), -0.18)  # Sättigung leicht hoch
			q.set_pixel(x, y, col)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(q, Rect2i(0, 0, w, h), Vector2i.ZERO)
	for y in h:
		for x in w:
			if q.get_pixel(x, y).a > 0.01:
				continue
			var near := Color(0, 0, 0, 0)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
					Vector2i(0, -1)]:
				var sx := x + d.x
				var sy := y + d.y
				if sx < 0 or sy < 0 or sx >= w or sy >= h:
					continue
				if q.get_pixel(sx, sy).a > 0.5:
					near = q.get_pixel(sx, sy)
					break
			if near.a > 0.5:
				out.set_pixel(x, y, Color(near.r * 0.22, near.g * 0.20, near.b * 0.28, 1.0))
	return out

func _bake_strip(id: String, anim: String, size: Vector2i, suffix: String,
		dir: String) -> void:
	var n := Rig3D.frames_of(anim)
	var strip := Image.create(size.x * n, size.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for f in n:
		_rig.apply(anim, f)
		# Zwei Bilder abwarten: das erste setzt die Transformationen, das
		# zweite rendert sie.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := stylize(_vp.get_texture().get_image())
		strip.blit_rect(img, Rect2i(0, 0, size.x, size.y), Vector2i(f * size.x, 0))
	strip.save_png("%s/%s_%s%s.png" % [dir, id, anim, suffix])

## Backt alle Figuren, Animationen und Feldansichten.
func run(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var done := 0
	for klass: String in [Figures3D.HERO, Figures3D.MON, Figures3D.BOSS]:
		var size: Vector2i = Figures3D.CANVAS[klass]
		_make_viewport(size, Figures3D.CAM_SIZE[klass])
		for id: String in Figures3D.F:
			if Figures3D.klass(id) != klass:
				continue
			_make_rig(id, 90.0)
			for anim: String in Figures3D.ANIMS[klass]:
				await _bake_strip(id, anim, size, "", dir)
				done += 1
			# Feldansichten: dieselbe Figur, nur gedreht. In 3D kostet das
			# nichts — beim Zeichnen war jede Richtung eine eigene Zeichnung.
			if Figures3D.FIELD_IDS.has(id):
				for view: String in Figures3D.FIELD_VIEWS:
					if view == "side":
						continue
					_make_rig(id, Figures3D.FIELD_VIEWS[view])
					for anim: String in ["idle", "walk"]:
						await _bake_strip(id, anim, size, "_" + view, dir)
						done += 1
					_make_rig(id, 90.0)
			print("fertig: ", id)
		_vp.queue_free()
		await get_tree().process_frame
	print("PROTO3D fertig — ", done, " Streifen")
