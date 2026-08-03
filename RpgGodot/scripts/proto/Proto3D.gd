class_name Proto3D
extends Node
## PROTOTYP: backt die 3D-Figur zu Pixel-Art-Sprites.
##
## Ablauf wie bei Dead Cells: orthografische Kamera, SEHR kleine Auflösung,
## keine Kantenglättung — daraus kommt die Pixeligkeit. Danach in 2D noch
## Farbstufen zusammenfassen (Palette) und eine dunkle Kontur ziehen, damit
## sich die Figur vom Hintergrund löst.
##
## Aufruf: env PROTO3D=<Zielordner> setzen und das Spiel NICHT headless starten
## (headless hat kein Rendergerät, der Viewport bliebe leer).

# Zielgrößen. 32x56 entspricht exakt dem heutigen 2D-Rig, ist also direkt
# vergleichbar; 48x84 zeigt, was ein feineres Raster brächte.
const SIZES := [Vector2i(32, 56), Vector2i(48, 84)]
const ANIMS := ["idle", "run", "attack", "hit", "down"]

# Farbstufen je Kanal. Wenige Stufen = deutliche Bänder wie in gemalter
# Pixel-Art; zu viele und es sieht aus wie ein verkleinerter 3D-Screenshot.
const LEVELS := 6

var _vp: SubViewport
var _rig: Rig3D
var _cam: Camera3D

func _build(size: Vector2i) -> void:
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
	# Bildhöhe knapp über Figurenhöhe, etwas Luft nach oben für erhobene Waffen.
	_cam.size = 2.45
	# Fast waagerecht: schaut die Kamera von oben herab, kippt die Figur im
	# Bild nach hinten und der Kopf läuft oben aus dem Rahmen. Die Kamera steht
	# auf der Seite, zu der die Figur blickt (negatives Z) — sonst sieht man
	# ihren Rücken statt ihres Gesichts.
	# look_at() braucht einen Node im Baum — hier ist die Kamera noch keiner.
	_cam.look_at_from_position(Vector3(3.4, 1.00, -1.5), Vector3(0, 0.95, 0), Vector3.UP)
	_vp.add_child(_cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.48, 0.60)
	env.ambient_light_energy = 1.35
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	# Dreipunktlicht: warmes Hauptlicht von vorn links oben, kühles schwaches
	# Fülllicht von der Gegenseite, und ein hartes Kantenlicht von hinten.
	# Das Kantenlicht macht den Unterschied — es zieht die Silhouette nach.
	_light(Vector3(-38, -30, -20), Color(1.0, 0.95, 0.86), 3.4)
	_light(Vector3(-20, 135, 10), Color(0.58, 0.68, 0.98), 1.1)
	_light(Vector3(-14, 210, 0), Color(1.0, 0.88, 0.74), 3.6)

	_rig = Rig3D.new()
	_rig.build_serena()
	# Die Figur ist nach +X gebaut. Gedreht so, dass ihre Blickrichtung mit der
	# Bildschirm-Rechtsachse der Kamera zusammenfällt — dieselbe Richtung wie
	# die 2D-Sprites, aber im Dreiviertelprofil statt reiner Seitenansicht.
	# 114 Grad hiesse exakt zur Bildschirm-Rechtsachse — das ergibt reines
	# Profil, also eine papierdünne Silhouette. 90 Grad dreht sie ein Stück
	# zur Kamera zurück: Dreiviertelansicht, Brust und Gesicht sichtbar.
	_rig.rotation_degrees = Vector3(0, 90, 0)
	_vp.add_child(_rig)

func _light(rot: Vector3, col: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot
	l.light_color = col
	l.light_energy = energy
	l.shadow_enabled = false
	_vp.add_child(l)

## Farbstufen zusammenfassen und dunkle Kontur ziehen.
static func _stylize(src: Image) -> Image:
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
			# Auf LEVELS Stufen je Kanal runden, danach leicht sättigen —
			# das trennt die Farbbänder sichtbar voneinander.
			var r := roundf(c.r * (LEVELS - 1)) / float(LEVELS - 1)
			var g := roundf(c.g * (LEVELS - 1)) / float(LEVELS - 1)
			var b := roundf(c.b * (LEVELS - 1)) / float(LEVELS - 1)
			var col := Color(r, g, b, 1.0)
			var lum := (r + g + b) / 3.0
			col = col.lerp(Color(lum, lum, lum), -0.18)  # Sättigung leicht hoch
			q.set_pixel(x, y, col)
	# Kontur: eine Spur dunkler als das Pixel dahinter, nicht hart schwarz.
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

## Backt alle Animationen in allen Zielgrößen und legt Streifen als PNG ab.
func run(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for size: Vector2i in SIZES:
		_build(size)
		for anim: String in ANIMS:
			var n := Rig3D.frames_of(anim)
			var strip := Image.create(size.x * n, size.y, false, Image.FORMAT_RGBA8)
			strip.fill(Color(0, 0, 0, 0))
			for f in n:
				_rig.apply(anim, f)
				# Zwei Bilder abwarten: das erste setzt die Transformationen,
				# das zweite rendert sie.
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := _stylize(_vp.get_texture().get_image())
				strip.blit_rect(img, Rect2i(0, 0, size.x, size.y),
					Vector2i(f * size.x, 0))
			var name := "%s_%dx%d" % [anim, size.x, size.y]
			strip.save_png("%s/%s.png" % [dir, name])
			print("gebacken: ", name, " (", n, " Bilder)")
		_vp.queue_free()
		await get_tree().process_frame
	print("PROTO3D fertig")
