class_name Field
extends Node2D
## Erkundungsmodus: baut die Karte aus MapData, steuert Heldin + Begleiter,
## NPC-Dialoge, Shop und Zufallskämpfe (nur wo die Karte es erlaubt).

const TILE := 16
const STEP_TIME := 0.18
# DTII-Feldfiguren sind 16x28: horizontal in der 16er-Kachel zentrieren (x-2)
# und so anheben, dass die Füße auf dem Kachelboden stehen (y -(28-16)).
const CHAR_OFFSET := Vector2(-2, -12)

# Feld-Bosse: welcher Boss in welchem Dungeon thront (bis sein Flag gesetzt ist).
const FIELD_BOSSES := {
	"dungeon": {"id": "boss", "tile": Vector2i(18, 10), "flag": "boss_defeated",
		"glow": Color(0.45, 1.0, 0.20, 0.35)},
	"dungeon2": {"id": "boss2", "tile": Vector2i(18, 10), "flag": "boss2_defeated",
		"glow": Color(1.0, 0.80, 0.20, 0.35)},
	"dungeon3": {"id": "boss3", "tile": Vector2i(18, 10), "flag": "boss3_defeated",
		"glow": Color(1.0, 0.15, 0.05, 0.35)},
}

var map_id := "town"
var spawn_id := "start"
var exact_pos := Vector2i(-1, -1)

var map: Dictionary
var player_tile: Vector2i
var facing := Vector2i(0, 1)
var moving := false
var walk_frame := 0
var anim_frame := 0      # laufender Animationsindex (0..3) für Idle/Lauf
var anim_accum := 0.0    # Zeitzähler für den Frame-Wechsel
var steps_since_battle := 0
var state := "move"  # move | dialogue | shop | locked (Übergang läuft)

var player: Sprite2D
var follower: Sprite2D
var follower_tile: Vector2i
var follower2: Sprite2D       # zweiter Begleiter (Roboter Rax)
var follower2_tile: Vector2i
var camera: Camera2D
var npc_nodes := {}  # Vector2i -> npc dict

# UI
var ui: CanvasLayer
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var dialog_lines: Array = []
var dialog_after_shop := false
var shop_panel: PanelContainer
var shop_labels: Array = []
var shop_gold: Label
var shop_index := 0
var hud: Label

# Dunkle Karten: Grundlicht + Laternenfarbe + Wandschmuck (Fackel/Kristall).
const LIGHTING := {
	# Schlotwerk: giftgrüner Dunst, Schleim trieft von den Wänden.
	"dungeon": {"ambient": Color(0.32, 0.42, 0.32), "lantern": Color(0.85, 1.0, 0.60),
		"wall_prop": "goo", "light": Color(0.55, 0.95, 0.35)},
	# Konzernturm: kaltes Marmorlicht mit goldenen Kronleuchter-Kristallen.
	"dungeon2": {"ambient": Color(0.44, 0.42, 0.36), "lantern": Color(1.0, 0.92, 0.65),
		"wall_prop": "crystal", "light": Color(1.0, 0.85, 0.45)},
	# Hassfestung: rote Banner, glutrote Fackelschächte.
	"dungeon3": {"ambient": Color(0.42, 0.28, 0.28), "lantern": Color(1.0, 0.72, 0.45),
		"wall_prop": "banner_red", "light": Color(1.0, 0.42, 0.22)},
}

# Kacheln, die einen Kontaktschatten auf den Boden darunter werfen.
const SOLID_ABOVE := ["t", "m", "R", "W", "D", "#", "I", "Y"]

func _ready() -> void:
	add_child(Fx.glow_environment())
	map = MapData.get_map(map_id)
	_build_tiles()
	_spawn_npcs()
	_spawn_party()
	_add_lighting()
	_build_ui()
	_add_barrier_shimmer()
	_add_ambience()

## CanvasModulate dunkelt dunkle Karten ab; Laterne am Spieler und
## flackernde Wandlichter bringen das HD-2D-Licht zurück.
func _add_lighting() -> void:
	if not LIGHTING.has(map_id):
		# Auch Tageslicht-Karten leicht abdunkeln — gedecktere, realistischere
		# Grundstimmung statt Bilderbuch-Helligkeit.
		var soft := CanvasModulate.new()
		soft.color = Color(0.86, 0.84, 0.88)
		add_child(soft)
		return
	var cfg: Dictionary = LIGHTING[map_id]
	var cm := CanvasModulate.new()
	cm.color = cfg["ambient"]
	add_child(cm)
	var lantern := Fx.point_light(cfg["lantern"], 90.0, 1.1)
	lantern.position = Vector2(6, 8)
	player.add_child(lantern)
	# Wandlichter überall dort, wo unter einer Wand freier Boden liegt.
	var rows: Array = map["rows"]
	var candidates: Array[Vector2i] = []
	for y in range(rows.size() - 1):
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if (ch == "#" or ch == "I" or ch == "Y") and MapData.WALKABLE.has((rows[y + 1] as String)[x]):
				candidates.append(Vector2i(x, y))
	var step := maxi(2, candidates.size() / 9)
	var placed := 0
	for i in range(0, candidates.size(), step):
		if placed >= 10:
			break
		placed += 1
		var c: Vector2i = candidates[i]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.prop(cfg["wall_prop"])
		s.centered = false
		s.z_index = 2
		add_child(s)
		var lcol: Color = cfg.get("light", Color(1.0, 0.70, 0.35))
		match cfg["wall_prop"]:
			"torch":
				s.position = Vector2(c.x * TILE + 5, c.y * TILE + 3)
				var l := Fx.point_light(lcol, 55.0, 1.1)
				l.position = Vector2(c.x * TILE + 8, c.y * TILE + 6)
				add_child(l)
				Fx.flicker(l, 1.1)
				# Glutschein direkt an der Flamme
				var halo := Sprite2D.new()
				halo.texture = SpriteFactory.circle(6, Color(lcol.r, lcol.g, lcol.b, 0.45))
				halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				halo.material = _additive()
				halo.position = Vector2(c.x * TILE + 8, c.y * TILE + 5)
				halo.z_index = 3
				add_child(halo)
			"goo":
				# Triefender Giftschleim: Overlay direkt auf der Wandkachel,
				# darunter ein waberndes grünes Glimmen.
				s.position = Vector2(c.x * TILE, c.y * TILE)
				var l := Fx.point_light(lcol, 50.0, 0.9)
				l.position = Vector2(c.x * TILE + 8, c.y * TILE + 16)
				add_child(l)
				Fx.pulse(l, 0.9, 1.6 + randf() * 0.9)
			"banner_red":
				# Banner hängt an der Wand, davor flackert eine Fackelschale.
				s.position = Vector2(c.x * TILE, c.y * TILE)
				var l := Fx.point_light(lcol, 58.0, 1.0)
				l.position = Vector2(c.x * TILE + 8, c.y * TILE + 18)
				add_child(l)
				Fx.flicker(l, 1.0)
			_:
				s.position = Vector2(c.x * TILE + 3, c.y * TILE + 4)
				var l := Fx.point_light(lcol, 48.0, 0.9)
				l.position = Vector2(c.x * TILE + 8, c.y * TILE + 10)
				add_child(l)
				Fx.pulse(l, 0.9, 1.4 + randf() * 0.8)

static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

## Versiegelte Portale schimmern eisig, solange sie verschlossen sind.
func _add_barrier_shimmer() -> void:
	for portal in map["portals"]:
		if not portal.has("locked_until") or GameState.get(portal["locked_until"]):
			continue
		var p: Vector2i = portal["pos"]
		# Barrierenfarbe passend zum Ziel: goldene Konzern-Versiegelung,
		# roter Hass-Wall, sonst eisblau.
		var bcol := Color(0.45, 0.85, 1.0, 0.5)
		if portal["to"] == "dungeon2":
			bcol = Color(1.0, 0.85, 0.30, 0.5)
		elif portal["to"] == "dungeon3":
			bcol = Color(1.0, 0.35, 0.25, 0.5)
		var shimmer := Sprite2D.new()
		shimmer.texture = SpriteFactory.circle(10, bcol)
		shimmer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		shimmer.position = Vector2(p.x * TILE + 8, p.y * TILE + 8)
		shimmer.z_index = 6
		add_child(shimmer)
		var tw := shimmer.create_tween().set_loops()
		tw.tween_property(shimmer, "modulate:a", 0.25, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(shimmer, "modulate:a", 1.0, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Dezente Umgebungspartikel je Karte: Blätter, Staub oder Schneetreiben.
func _add_ambience() -> void:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(190, 8)
	p.position = Vector2(6, -110)
	p.z_index = 30
	match map_id:
		"town":
			p.direction = Vector2(0.3, 1)
			p.gravity = Vector2(4, 8)
			p.initial_velocity_min = 18.0
			p.initial_velocity_max = 34.0
			p.color = Color(0.55, 0.75, 0.35, 0.8)
			p.texture = SpriteFactory.circle(2, Color.WHITE)
		"dungeon":
			# Giftgrüne Smogbläschen steigen träge auf
			p.emission_rect_extents = Vector2(190, 120)
			p.position = Vector2(6, 8)
			p.direction = Vector2(0, -1)
			p.gravity = Vector2(0, -3)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 9.0
			p.color = Color(0.55, 0.90, 0.35, 0.35)
			p.texture = SpriteFactory.circle(2, Color.WHITE)
		"dungeon2":
			# Goldener Geldstaub rieselt von den Kronleuchtern
			p.amount = 34
			p.direction = Vector2(0.1, 1)
			p.gravity = Vector2(0, 5)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 22.0
			p.color = Color(1.0, 0.88, 0.45, 0.7)
			p.texture = SpriteFactory.circle(1, Color.WHITE)
		"dungeon3":
			# Glutasche treibt durch die Festung
			p.emission_rect_extents = Vector2(190, 120)
			p.position = Vector2(6, 8)
			p.direction = Vector2(-0.2, -1)
			p.gravity = Vector2(-3, -5)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 11.0
			p.color = Color(1.0, 0.45, 0.20, 0.45)
			p.texture = SpriteFactory.circle(1, Color.WHITE)
		"world":
			p.amount = 16
			p.emission_rect_extents = Vector2(190, 120)
			p.position = Vector2(6, 8)
			p.direction = Vector2(0.2, -0.3)
			p.gravity = Vector2(2, -2)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 9.0
			p.color = Color(1.0, 0.95, 0.6, 0.5)
			p.texture = SpriteFactory.circle(1, Color.WHITE)
		_:
			p.queue_free()
			return
	# Am Spieler verankert, damit das Treiben die Kamera begleitet.
	player.add_child(p)
	if map_id == "world":
		_add_cloud_shadows()

## Weiche Wolkenschatten, die träge über die Überwelt ziehen.
func _add_cloud_shadows() -> void:
	var rows: Array = map["rows"]
	var mw: float = (rows[0] as String).length() * TILE
	var mh: float = rows.size() * TILE
	for i in 3:
		var cl := Sprite2D.new()
		cl.texture = SpriteFactory.circle(60, Color(0, 0, 0, 0.10))
		cl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cl.scale = Vector2(3.0 + i, 1.7 + i * 0.5)
		cl.position = Vector2(mw * (0.15 + 0.3 * i), mh * (0.2 + 0.28 * i))
		cl.z_index = 28
		add_child(cl)
		var dur := 46.0 + i * 14.0
		var tw := cl.create_tween().set_loops()
		tw.tween_property(cl, "position:x", cl.position.x + mw * 0.35, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(cl, "position:x", cl.position.x, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_tiles() -> void:
	var rows: Array = map["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var kind: String = MapData.TILE_FOR_CHAR[ch]
			var s := Sprite2D.new()
			s.texture = SpriteFactory.tile_at(kind, x, y)
			s.centered = false
			s.position = Vector2(x * TILE, y * TILE)
			if kind == "water":
				s.material = Fx.water_material()  # sanftes Wogen + Glanzlichter
			add_child(s)
	_add_tile_details()

## Detailschicht über den Kacheln: Kontaktschatten unter massiven Kacheln
## (verankert Wände und Bäume am Boden) plus gestreute Requisiten.
func _add_tile_details() -> void:
	var rows: Array = map["rows"]
	var shade := 0.5 if LIGHTING.has(map_id) else 0.3
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if MapData.WALKABLE.has(ch) and y > 0 and SOLID_ABOVE.has((rows[y - 1] as String)[x]):
				var sh := Sprite2D.new()
				sh.texture = SpriteFactory.gradient(16, 10, Color(0, 0, 0, shade), Color(0, 0, 0, 0))
				sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				sh.centered = false
				sh.position = Vector2(x * TILE, y * TILE)
				sh.z_index = 1
				add_child(sh)
			var n := _tile_noise(x, y)
			match ch:
				"g":
					if n < 0.09:
						_place_prop("flower%d" % (int(n * 1000.0) % 4), x, y, n)
					elif n < 0.18:
						_place_prop("tuft", x, y, n)
				"f":
					# Schlotwerk: Risse, Giftfässer, Schlammpfützen, Mutantenpilze
					if n < 0.05:
						_place_prop("pebble", x, y, n)
					elif n < 0.09:
						_place_prop("crack", x, y, n)
					elif n < 0.115:
						_place_prop("barrel", x, y, n)
					elif n < 0.14:
						_place_prop("sludge", x, y, n)
					elif n > 0.975:
						_place_mushroom(x, y)
				"i":
					# Konzernturm: Münzhaufen und Frachtkisten
					if n < 0.05:
						_place_prop("coins", x, y, n)
					elif n < 0.08:
						_place_prop("crate", x, y, n)
				"y":
					# Hassfestung: Risse, Schutt, Knochen
					if n < 0.05:
						_place_prop("crack", x, y, n)
					elif n < 0.08:
						_place_prop("pebble", x, y, n)
					elif n < 0.105:
						_place_prop("bones", x, y, n)

func _tile_noise(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)

func _place_prop(kind: String, x: int, y: int, n: float) -> void:
	var s := Sprite2D.new()
	s.texture = SpriteFactory.prop(kind)
	s.centered = false
	# Pseudo-zufälliger Versatz, damit kein Raster entsteht.
	var ox := 2 + int(n * 977.0) % 6
	var oy := 3 + int(n * 389.0) % 6
	s.position = Vector2(x * TILE + ox, y * TILE + oy)
	s.z_index = 1
	add_child(s)

## Leuchtpilz mit additivem Schein — kleine Lichtinseln im dunklen Dungeon.
func _place_mushroom(x: int, y: int) -> void:
	var s := Sprite2D.new()
	s.texture = SpriteFactory.prop("mushroom")
	s.centered = false
	s.position = Vector2(x * TILE + 4, y * TILE + 7)
	s.z_index = 1
	add_child(s)
	var halo := Sprite2D.new()
	halo.texture = SpriteFactory.circle(9, Color(0.70, 0.45, 1.0, 0.40))
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.material = _additive()
	halo.position = Vector2(x * TILE + 7, y * TILE + 10)
	halo.z_index = 2
	add_child(halo)
	var tw := halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.55, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(halo, "modulate:a", 1.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_npcs() -> void:
	for npc in map["npcs"]:
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(npc["id"], "down", 0)
		s.centered = false
		s.offset = CHAR_OFFSET
		s.position = Vector2(npc["pos"].x * TILE + 2, npc["pos"].y * TILE)
		s.z_index = 5
		add_child(s)
		_attach_drop_shadow(s)
		npc_nodes[npc["pos"]] = npc
	# Boss thront hinten im Dungeon, bis er besiegt ist.
	if FIELD_BOSSES.has(map_id):
		var cfg: Dictionary = FIELD_BOSSES[map_id]
		if GameState.get(cfg["flag"]):
			return
		var boss_tile: Vector2i = cfg["tile"]
		var bs := Sprite2D.new()
		bs.texture = SpriteFactory.enemy(cfg["id"])
		bs.centered = false
		# Sprite mittig über der Kachel, Füße auf dem Kachelboden.
		var tw2 := bs.texture.get_width()
		var th := bs.texture.get_height()
		bs.position = Vector2(boss_tile.x * TILE + 8 - tw2 / 2.0, boss_tile.y * TILE + TILE - th + 1)
		bs.z_index = 5
		add_child(bs)
		# Glühen unter dem Boss macht schon von Weitem klar: Gefahr!
		var glow := Sprite2D.new()
		glow.texture = SpriteFactory.circle(16, cfg["glow"])
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.position = Vector2(boss_tile.x * TILE + 8, boss_tile.y * TILE + 12)
		glow.z_index = 4
		add_child(glow)
		# Bodenschatten + echtes Punktlicht in der Bossfarbe
		var bsh := Sprite2D.new()
		bsh.texture = SpriteFactory.shadow(11, 3)
		bsh.position = Vector2(boss_tile.x * TILE + 8, boss_tile.y * TILE + 14)
		bsh.z_index = 4
		add_child(bsh)
		var gc: Color = cfg["glow"]
		var bl := Fx.point_light(Color(gc.r, gc.g, gc.b), 70.0, 1.2)
		bl.position = glow.position
		add_child(bl)
		Fx.pulse(bl, 1.2, 1.2)
		var pulse := glow.create_tween().set_loops()
		pulse.tween_property(glow, "scale", Vector2(1.6, 1.0), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "scale", Vector2(1.1, 0.7), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var bob := create_tween().set_loops()
		bob.tween_property(bs, "position:y", bs.position.y - 2.0, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(bs, "position:y", bs.position.y, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Der thronende Boss atmet/wabert durch seine 4 Animationsframes.
		var boss_id: String = cfg["id"]
		var af := {"i": 0}
		var atimer := Timer.new()
		atimer.wait_time = 0.18
		atimer.autostart = true
		atimer.timeout.connect(func():
			af["i"] = (af["i"] + 1) % SpriteFactory.ENEMY_FRAMES
			bs.texture = SpriteFactory.enemy_frame(boss_id, af["i"]))
		add_child(atimer)
		npc_nodes[boss_tile] = {"boss": true, "battle_id": cfg["id"],
			"name": GameState.ENEMIES[cfg["id"]]["name"], "pos": boss_tile}

func _spawn_party() -> void:
	if exact_pos.x >= 0:
		player_tile = exact_pos
	else:
		player_tile = map["spawns"][spawn_id]
	follower_tile = player_tile
	follower2_tile = player_tile
	player = Sprite2D.new()
	player.centered = false
	player.offset = CHAR_OFFSET
	player.z_index = 10
	add_child(player)
	_attach_drop_shadow(player)
	follower = Sprite2D.new()
	follower.centered = false
	follower.offset = CHAR_OFFSET
	follower.z_index = 9
	add_child(follower)
	_attach_drop_shadow(follower)
	follower2 = Sprite2D.new()
	follower2.centered = false
	follower2.offset = CHAR_OFFSET
	follower2.z_index = 8
	add_child(follower2)
	_attach_drop_shadow(follower2)
	player.position = _tile_pos(player_tile)
	follower.position = _tile_pos(follower_tile)
	follower2.position = _tile_pos(follower2_tile)
	_update_sprites()

	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	var rows: Array = map["rows"]
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = (rows[0] as String).length() * TILE
	camera.limit_bottom = rows.size() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.position = Vector2(6, 8)
	camera.make_current()

func _tile_pos(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + 2, t.y * TILE)

## Weicher Bodenschatten unter einer 12x16-Figur (verankert sie optisch).
func _attach_drop_shadow(s: Sprite2D) -> void:
	var sh := Sprite2D.new()
	sh.texture = SpriteFactory.shadow(5, 2)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sh.position = Vector2(6, 15)
	sh.show_behind_parent = true
	s.add_child(sh)

func _dir_name(d: Vector2i) -> String:
	if d.y > 0: return "down"
	if d.y < 0: return "up"
	return "side"

func _update_sprites() -> void:
	player.texture = SpriteFactory.field_char("serena", moving, anim_frame)
	player.flip_h = facing.x < 0
	var fd := player_tile - follower_tile
	if fd == Vector2i.ZERO:
		fd = facing
	follower.texture = SpriteFactory.field_char("milo", moving, anim_frame)
	follower.flip_h = fd.x < 0
	var fd2 := follower_tile - follower2_tile
	if fd2 == Vector2i.ZERO:
		fd2 = fd
	follower2.texture = SpriteFactory.field_char("rax", moving, anim_frame)
	follower2.flip_h = fd2.x < 0

func _process(delta: float) -> void:
	# Weiterlaufende Idle-/Lauf-Animation (4 Frames, ~7 fps).
	anim_accum += delta
	if anim_accum >= 0.14:
		anim_accum -= 0.14
		anim_frame = (anim_frame + 1) % 4
		if is_instance_valid(player):
			_update_sprites()
	if state == "move" and not moving:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("move_up"): dir = Vector2i(0, -1)
		elif Input.is_action_pressed("move_down"): dir = Vector2i(0, 1)
		elif Input.is_action_pressed("move_left"): dir = Vector2i(-1, 0)
		elif Input.is_action_pressed("move_right"): dir = Vector2i(1, 0)
		if dir != Vector2i.ZERO:
			_try_step(dir)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		match state:
			"move": _try_interact()
			"dialogue": _advance_dialogue()
			"shop": _shop_buy()
	elif event.is_action_pressed("cancel") and state == "shop":
		_close_shop()
	elif state == "shop":
		if event.is_action_pressed("move_up"): _shop_move(-1)
		elif event.is_action_pressed("move_down"): _shop_move(1)

func _try_step(dir: Vector2i) -> void:
	facing = dir
	var target := player_tile + dir
	if npc_nodes.has(target):
		# In den Boss hineinlaufen startet den Kampf direkt (Bestätigen geht weiterhin auch).
		var npc: Dictionary = npc_nodes[target]
		if npc.get("boss", false):
			state = "locked"
			GameState.main.start_battle([npc["battle_id"]], map_id, player_tile)
			return
		_update_sprites()
		return
	if not MapData.is_walkable(map, target):
		_update_sprites()
		return
	moving = true
	var old := player_tile
	var old_follower := follower_tile
	player_tile = target
	walk_frame = 1 - walk_frame
	_update_sprites()
	AudioManager.play_sfx("step")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "position", _tile_pos(player_tile), STEP_TIME)
	tw.tween_property(follower, "position", _tile_pos(old), STEP_TIME)
	tw.tween_property(follower2, "position", _tile_pos(old_follower), STEP_TIME)
	await tw.finished
	follower_tile = old
	follower2_tile = old_follower
	moving = false
	_after_step()

func _after_step() -> void:
	for portal in map["portals"]:
		if portal["pos"] == player_tile:
			# Versiegelte Portale (z. B. Frostgrotte) erst nach Freischaltung.
			if portal.has("locked_until") and not GameState.get(portal["locked_until"]):
				AudioManager.play_sfx("error")
				dialog_name.text = portal.get("locked_name", "Barriere")
				dialog_lines = [portal["locked_msg"]]
				dialog_after_shop = false
				state = "dialogue"
				_advance_dialogue()
				return
			state = "locked"  # Eingaben sperren während des Wechsels
			GameState.main.goto_map(portal["to"], portal["spawn"])
			return
	if map["encounters"]:
		steps_since_battle += 1
		if steps_since_battle > 4 and randf() < 0.12:
			steps_since_battle = 0
			state = "locked"
			GameState.main.start_battle(GameState.random_encounter(map_id), map_id, player_tile)

func _try_interact() -> void:
	var target := player_tile + facing
	if not npc_nodes.has(target):
		return
	var npc: Dictionary = npc_nodes[target]
	if npc.get("boss", false):
		state = "locked"
		GameState.main.start_battle([npc["battle_id"]], map_id, player_tile)
		return
	dialog_lines = (npc["lines"] as Array).duplicate()
	dialog_after_shop = npc.get("shop", false)
	dialog_name.text = npc["name"]
	state = "dialogue"
	AudioManager.play_sfx("menu")
	_advance_dialogue()

func _advance_dialogue() -> void:
	if dialog_lines.is_empty():
		dialog_panel.visible = false
		if dialog_after_shop:
			_open_shop()
		else:
			state = "move"
		return
	dialog_panel.visible = true
	dialog_text.text = dialog_lines.pop_front()

## ---------- UI ----------

# Color-Grade je Karte: [oben (Licht), unten (Schatten)] — HD-2D-Filmlook.
const GRADES := {
	"town": [Color(1.0, 0.85, 0.55, 0.08), Color(0.15, 0.10, 0.35, 0.12)],
	"world": [Color(1.0, 0.90, 0.65, 0.06), Color(0.10, 0.12, 0.35, 0.10)],
	"dungeon": [Color(0.60, 0.95, 0.35, 0.08), Color(0.04, 0.12, 0.03, 0.20)],
	"dungeon2": [Color(1.0, 0.88, 0.50, 0.09), Color(0.12, 0.08, 0.02, 0.16)],
	"dungeon3": [Color(1.0, 0.45, 0.30, 0.08), Color(0.10, 0.02, 0.02, 0.20)],
}

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# Tilt-Shift-Tiefenunschärfe zuerst, damit HUD und Textboxen scharf bleiben.
	ui.add_child(Fx.tilt_shift(4.5, 3.0, 0.5, 0.16))

	# Filmisches Color-Grading + Vignette über der ganzen Karte
	var g: Array = GRADES.get(map_id, GRADES["world"])
	var grade := TextureRect.new()
	grade.texture = SpriteFactory.gradient(8, 64, g[0], g[1])
	grade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	grade.stretch_mode = TextureRect.STRETCH_SCALE
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(grade)
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135, 0.45)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vig)

	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 18)
	ui.add_child(hud)
	_refresh_hud()

	dialog_panel = _make_panel(Rect2(80, 400, 800, 120))
	var vb := VBoxContainer.new()
	dialog_panel.add_child(vb)
	dialog_name = Label.new()
	dialog_name.add_theme_font_size_override("font_size", 16)
	dialog_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(dialog_name)
	dialog_text = Label.new()
	dialog_text.add_theme_font_size_override("font_size", 20)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dialog_text)

	shop_panel = _make_panel(Rect2(280, 140, 400, 220))
	var svb := VBoxContainer.new()
	shop_panel.add_child(svb)
	var title := Label.new()
	title.text = "— Gretas Laden —   (Z: Kaufen, X: Zurück)"
	title.add_theme_font_size_override("font_size", 16)
	svb.add_child(title)
	shop_gold = Label.new()
	shop_gold.add_theme_font_size_override("font_size", 16)
	shop_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	svb.add_child(shop_gold)
	for item_name in GameState.ITEMS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		svb.add_child(l)
		shop_labels.append([l, item_name])

func _make_panel(rect: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.custom_minimum_size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.16, 0.92)
	style.border_color = Color(0.75, 0.7, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", style)
	p.visible = false
	ui.add_child(p)
	return p

func _refresh_hud() -> void:
	hud.text = "%s   |   Gold: %d" % [map["name"], GameState.gold]

func _open_shop() -> void:
	state = "shop"
	shop_index = 0
	shop_panel.visible = true
	_refresh_shop()

func _refresh_shop() -> void:
	shop_gold.text = "Gold: %d" % GameState.gold
	for i in shop_labels.size():
		var l: Label = shop_labels[i][0]
		var item_name: String = shop_labels[i][1]
		var item: Dictionary = GameState.ITEMS[item_name]
		var cursor := "> " if i == shop_index else "  "
		var owned: int = GameState.inventory.get(item_name, 0)
		l.text = "%s%s  %d G  (Besitz: %d) — %s" % [cursor, item_name, item["price"], owned, item["desc"]]
		l.add_theme_color_override("font_color", Color.WHITE if i == shop_index else Color(0.7, 0.7, 0.75))

func _shop_move(delta: int) -> void:
	shop_index = clampi(shop_index + delta, 0, shop_labels.size() - 1)
	AudioManager.play_sfx("menu")
	_refresh_shop()

func _shop_buy() -> void:
	var item_name: String = shop_labels[shop_index][1]
	var price: int = GameState.ITEMS[item_name]["price"]
	if GameState.gold >= price:
		GameState.gold -= price
		GameState.add_item(item_name)
		AudioManager.play_sfx("buy")
	else:
		AudioManager.play_sfx("error")
	_refresh_shop()
	_refresh_hud()

func _close_shop() -> void:
	shop_panel.visible = false
	state = "move"
	AudioManager.play_sfx("menu")
