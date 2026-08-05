class_name Field
extends Node2D
## Erkundungsmodus: baut die Karte aus MapData, steuert Heldin + Begleiter,
## NPC-Dialoge, Shop und Zufallskämpfe (nur wo die Karte es erlaubt).

const TILE := 16
const STEP_TIME := 0.18
# DTII-Feldfiguren sind 16x28: horizontal in der 16er-Kachel zentrieren (x-2)
# und so anheben, dass die Füße auf dem Kachelboden stehen (y -(28-16)).
# Die Rig-Figuren sind 32x56. Seit sie erwachsene Proportionen haben (kleiner
# Kopf, längere Beine), wurden sie auf Maßstab 0.5 zu klein zum Erkennen —
# jetzt etwas größer, gut anderthalb Kacheln hoch wie in klassischen JRPGs.
# Der Versatz wird aus dem Maßstab abgeleitet, damit die Füße unabhängig davon
# auf dem Kachelboden stehen und die Figur mittig über der Kachel sitzt.
const FIELD_CHAR_SCALE := 0.42 / RigFactory.BAKE
# Halbe Sprite-Breite und volle Höhe der gebackenen Figur — daraus ergibt sich
# der Versatz, damit die Füße auf dem Kachelboden stehen und die Figur mittig
# über der Kachel sitzt, unabhängig vom Maßstab.
const SPR_HALF_W := RigFactory.HERO_W * RigFactory.BAKE / 2.0
const SPR_H := RigFactory.HERO_H * RigFactory.BAKE
const CHAR_OFFSET := Vector2(6.0 / FIELD_CHAR_SCALE - SPR_HALF_W,
	16.0 / FIELD_CHAR_SCALE - SPR_H)

# Verkleinerung des thronenden Bosses auf der Karte.
const FIELD_BOSS_SCALE := 0.30 / RigFactory.BAKE

# Feld-Bosse: welcher Boss in welchem Dungeon thront (bis sein Flag gesetzt ist).
const FIELD_BOSSES := {
	"dungeon": {"id": "boss", "tile": Vector2i(18, 10), "flag": "boss_defeated",
		"glow": Color(0.45, 1.0, 0.20, 0.35)},
	"dungeon2": {"id": "boss2", "tile": Vector2i(18, 10), "flag": "boss2_defeated",
		"glow": Color(1.0, 0.80, 0.20, 0.35)},
	"dungeon3": {"id": "boss3", "tile": Vector2i(18, 10), "flag": "boss3_defeated",
		"glow": Color(1.0, 0.15, 0.05, 0.35)},
	"dungeon4": {"id": "boss4", "tile": Vector2i(18, 10), "flag": "boss4_defeated",
		"glow": Color(0.70, 0.76, 0.90, 0.30)},
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
var water_tiles: Array = []  # Wasser-Sprites (für die Gift-Tönung der Plage 1)

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
	# Unheimlich heißt nicht schwarz: das Grundlicht bleibt so hoch, dass man
	# den Boden liest, aber es ist kalt und entsättigt. Die Bedrohung kommt aus
	# dem Kontrast — enge, farbige Lichtinseln in einer fahlen Umgebung.
	# Schlotwerk: giftgrüner Dunst, Schleim trieft von den Wänden.
	"dungeon": {"ambient": Color(0.52, 0.64, 0.50), "lantern": Color(0.72, 1.0, 0.52),
		"wall_prop": "goo", "light": Color(0.55, 0.95, 0.35)},
	# Konzernturm: kaltes Marmorlicht mit goldenen Kronleuchter-Kristallen.
	"dungeon2": {"ambient": Color(0.60, 0.58, 0.54), "lantern": Color(1.0, 0.88, 0.55),
		"wall_prop": "crystal", "light": Color(1.0, 0.85, 0.45)},
	# Hassfestung: rote Banner, glutrote Fackelschächte.
	"dungeon3": {"ambient": Color(0.58, 0.44, 0.44), "lantern": Color(1.0, 0.62, 0.34),
		"wall_prop": "banner_red", "light": Color(1.0, 0.42, 0.22)},
	# Die Leere: fahles, farbloses Dämmerlicht, kalte graue Kristallsplitter.
	"dungeon4": {"ambient": Color(0.50, 0.54, 0.62), "lantern": Color(0.70, 0.76, 0.90),
		"wall_prop": "crystal", "light": Color(0.70, 0.78, 0.90)},
}

# Kacheln, die einen Kontaktschatten auf den Boden darunter werfen.
const SOLID_ABOVE := ["t", "m", "R", "W", "D", "#", "I", "Y"]

# Zeichen, die als Objekt AUF dem Grundgelände stehen (siehe _terrain_at).
# Berge fehlen hier bewusst: sie sind selbst Gelände und bekommen dadurch
# ausgefranste Felskanten statt einer Quadratmauer.
const OBJECT_CHARS := ["t", "R", "W", "D", "b", "#", "I", "Y", "N",
	"T", "C", "F", "H", "V", "X"]
# Portale, die im Gebirge liegen statt auf der Wiese.
const OBJECT_GROUND := {"C": "mount", "F": "mount"}
# Dungeonwände — bekommen Front/Krone/Masse je nach Lage (siehe _wall_variant).
const WALL_CHARS := ["#", "I", "Y", "N"]
# Nachbarreihenfolge für die Übergangs-Bitmaske: im Uhrzeigersinn ab Norden.
const NEIGHBOR_DIRS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

func _ready() -> void:
	add_child(Fx.glow_environment())
	map = MapData.get_map(map_id)
	_build_tiles()
	_spawn_npcs()
	_spawn_party()
	_add_lighting()
	_build_ui()
	_add_exit_markers()
	_add_barrier_shimmer()
	_add_ambience()

## CanvasModulate dunkelt dunkle Karten ab; Laterne am Spieler und
## flackernde Wandlichter bringen das HD-2D-Licht zurück.
func _add_lighting() -> void:
	if not LIGHTING.has(map_id):
		# Auch Tageslicht-Karten leicht abdunkeln — gedecktere, realistischere
		# Grundstimmung statt Bilderbuch-Helligkeit.
		# Auch draußen kein Bilderbuchtag: kühl und leicht entsättigt, damit
		# das Tal bedrückt wirkt statt freundlich.
		var soft := CanvasModulate.new()
		soft.color = Color(0.80, 0.80, 0.88)
		add_child(soft)
		return
	var cfg: Dictionary = LIGHTING[map_id]
	var cm := CanvasModulate.new()
	cm.color = cfg["ambient"]
	add_child(cm)
	var lantern := Fx.point_light(cfg["lantern"], 135.0, 1.25)
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
## Offene Ausgänge sichtbar machen. Bisher musste man die Kachel raten, auf der
## ein Übergang liegt — ein ruhig pulsierender Fußabdruck zeigt sie jetzt an.
func _add_exit_markers() -> void:
	for portal in map["portals"]:
		if portal.has("locked_until") and not GameState.is_unlocked(portal["locked_until"]):
			continue   # verriegelte Übergänge haben ihr eigenes Flimmern
		var p: Vector2i = portal["pos"]
		var mark := Sprite2D.new()
		mark.texture = SpriteFactory.circle(9, Color(1.0, 0.93, 0.62, 0.30))
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		mark.position = Vector2(p.x * TILE + 8, p.y * TILE + 11)
		mark.scale = Vector2(1.0, 0.5)
		mark.z_index = 1          # über dem Boden, unter den Figuren
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mark.material = m
		add_child(mark)
		var tw := mark.create_tween().set_loops()
		tw.tween_property(mark, "scale", Vector2(1.25, 0.62), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(mark, "modulate:a", 0.55, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(mark, "scale", Vector2(1.0, 0.5), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(mark, "modulate:a", 1.0, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _add_barrier_shimmer() -> void:
	for portal in map["portals"]:
		if not portal.has("locked_until") or GameState.is_unlocked(portal["locked_until"]):
			continue
		var p: Vector2i = portal["pos"]
		# Barrierenfarbe passend zum Ziel: goldene Konzern-Versiegelung,
		# roter Hass-Wall, grauer Riss der Leere, sonst eisblau.
		var bcol := Color(0.45, 0.85, 1.0, 0.5)
		if portal["to"] == "dungeon2":
			bcol = Color(1.0, 0.85, 0.30, 0.5)
		elif portal["to"] == "dungeon3":
			bcol = Color(1.0, 0.35, 0.25, 0.5)
		elif portal["to"] == "dungeon4":
			bcol = Color(0.62, 0.66, 0.74, 0.55)
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
		"dungeon4":
			# Fahle Staubkörnchen schweben regungslos in der Leere
			p.amount = 20
			p.emission_rect_extents = Vector2(190, 120)
			p.position = Vector2(6, 8)
			p.direction = Vector2(0, -1)
			p.gravity = Vector2(0, -1)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 5.0
			p.color = Color(0.74, 0.78, 0.86, 0.35)
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
			var terr := _terrain_at(x, y)
			var s := Sprite2D.new()
			s.texture = SpriteFactory.tile_at(terr, x, y)
			s.centered = false
			s.position = Vector2(x * TILE, y * TILE)
			if terr == "water":
				s.material = Fx.water_material()  # sanftes Wogen + Glanzlichter
				water_tiles.append(s)
			add_child(s)
			_add_ground_patch(x, y, terr)
			_add_terrain_edges(x, y, terr)
			var ch := row[x]
			if OBJECT_CHARS.has(ch):
				_place_map_object(ch, x, y)
	_add_tile_details()
	_add_plague_signs()

## Gelände unter einer Kartenposition. Bäume, Berge, Häuser, Wände und
## Portalsymbole sind Objekte, die auf dem Grundgelände der Karte STEHEN —
## dadurch laufen Gras, Ufer und Wege ununterbrochen darunter hindurch,
## statt an jeder Blockkante hart abzubrechen.
func _terrain_at(x: int, y: int) -> String:
	var rows: Array = map["rows"]
	if y < 0 or y >= rows.size():
		return ""
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return ""
	var ch := row[x]
	if ch == "b":
		return "water"  # die Brücke steht im Fluss
	if OBJECT_GROUND.has(ch):
		return OBJECT_GROUND[ch]
	if OBJECT_CHARS.has(ch):
		return map.get("ground", "grass")
	return MapData.TILE_FOR_CHAR[ch]

## Unregelmäßige Flecken auf etwa jeder fünften Boden-Kachel. Sie brechen die
## Wiederholung der wenigen Grundkacheln auf — ohne sie erkennt man auf großen
## Flächen sofort das Raster.
func _add_ground_patch(x: int, y: int, terr: String) -> void:
	if not SpriteFactory.PATCH_TINTS.has(terr):
		return
	var h := ((x * 92837111) ^ (y * 689287499)) & 0x7fffffff
	if h % 5 != 0:
		return
	var s := Sprite2D.new()
	s.texture = SpriteFactory.ground_patch(terr, (h / 5) % 12)
	s.centered = false
	s.position = Vector2(x * TILE, y * TILE)
	add_child(s)

## Übergänge: jedes höherrangige Nachbargelände greift in diese Kachel hinein
## (Ufer, Wegränder). Ohne das stoßen Gras/Weg/Wasser mit Linealkanten
## aneinander und die Karte wirkt wie ein Tabellenblatt.
func _add_terrain_edges(x: int, y: int, terr: String) -> void:
	var rank: int = SpriteFactory.TERRAIN_RANK.get(terr, -1)
	if rank < 0:
		return
	var masks := {}
	for i in NEIGHBOR_DIRS.size():
		var d: Vector2i = NEIGHBOR_DIRS[i]
		var nt := _terrain_at(x + d.x, y + d.y)
		if SpriteFactory.TERRAIN_RANK.get(nt, -1) > rank:
			masks[nt] = int(masks.get(nt, 0)) | (1 << i)
	var kinds: Array = masks.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool:
		return SpriteFactory.TERRAIN_RANK[a] < SpriteFactory.TERRAIN_RANK[b])
	for k: String in kinds:
		var ov := Sprite2D.new()
		ov.texture = SpriteFactory.edge_overlay(k, terr, masks[k], x, y)
		ov.centered = false
		ov.position = Vector2(x * TILE, y * TILE)
		add_child(ov)

## Objekt auf dem Grundgelände: Baum, Berg, Hauswand, Portalsymbol, Dungeonwand.
func _place_map_object(ch: String, x: int, y: int) -> void:
	if ch == "t":
		_place_tree(x, y)
		return
	var s := Sprite2D.new()
	s.texture = SpriteFactory.tile_at(_wall_variant(ch, x, y), x, y)
	s.centered = false
	s.position = Vector2(x * TILE, y * TILE)
	s.z_index = 2
	add_child(s)

## Dungeonwände dreistufig statt überall dieselbe Ziegelfläche: die Reihe am
## Boden zeigt die Ziegelfront, die Reihe darüber die Mauerkrone, alles
## dahinter bleibt dunkle Masse. Erst dadurch liest man im Dunkeln, wo der
## begehbare Boden aufhört.
func _wall_variant(ch: String, x: int, y: int) -> String:
	var kind: String = MapData.TILE_FOR_CHAR[ch]
	if not WALL_CHARS.has(ch):
		return kind
	if MapData.WALKABLE.has(_char_at(x, y + 1)):
		return kind  # Ziegelfront zum Boden hin
	if MapData.WALKABLE.has(_char_at(x, y + 2)):
		return "wall_crown"
	return "wall_deep"

func _char_at(x: int, y: int) -> String:
	var rows: Array = map["rows"]
	if y < 0 or y >= rows.size():
		return ""
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return ""
	return row[x]

## Baum als 16x48-Säule: Krone ragt zwei Kacheln nach oben, Fuß steht auf der
## eigenen Kachel. Weil die Reihen von oben nach unten gebaut werden,
## überdecken vordere Bäume automatisch die dahinterliegenden.
func _place_tree(x: int, y: int) -> void:
	var n := _tile_noise(x, y)
	var s := Sprite2D.new()
	s.texture = SpriteFactory.tree_tex(int(n * 977.0))
	s.centered = false
	s.position = Vector2(x * TILE, y * TILE + TILE - SpriteFactory.TREE_H)
	s.z_index = 3
	add_child(s)
	var sh := Sprite2D.new()
	sh.texture = SpriteFactory.shadow(7, 3)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sh.position = Vector2(x * TILE + 8, y * TILE + 13)
	sh.z_index = 1
	add_child(sh)

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

## ---------- Plagen-Spuren (Story-Schicht) ----------
## Sichtbare Zeichen der drei Plagen in Dorf und Überwelt: vergiftetes Wasser,
## Geldeintreiber & verarmtes Volk, Krieg & Gewalt. Jede besiegte Plage nimmt
## ihre Spuren mit — die Welt heilt sichtbar mit jedem Sieg.
func _add_plague_signs() -> void:
	if map_id == "town":
		if not GameState.boss_defeated:
			_plague_toxic_town()
		if not GameState.boss2_defeated:
			_plague_greed_town()
		if not GameState.boss3_defeated:
			_plague_war_town()
	elif map_id == "world":
		if not GameState.boss_defeated:
			_plague_toxic_world()
		if not GameState.boss2_defeated:
			_plague_greed_world()
		if not GameState.boss3_defeated:
			_plague_war_world()

## Träge aufsteigende Rauchsäule (Kriegszeichen am Horizont).
func _smoke_plume(pos: Vector2, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 3.2
	p.preprocess = 3.2
	p.direction = Vector2(0.15, -1)
	p.spread = 8.0
	p.gravity = Vector2(2, -14)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = col
	p.texture = SpriteFactory.particle("smoke_07")
	p.z_index = 6
	add_child(p)

## Giftblasen, die träge aus verseuchtem Wasser/Schlamm aufsteigen.
func _toxic_bubbles(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 6
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 4)
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, -4)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color = Color(0.55, 0.85, 0.30, 0.6)
	p.texture = SpriteFactory.circle(1, Color.WHITE)
	p.z_index = 2
	add_child(p)

## Plage 1 im Dorf: das Wasser ist vergiftet — Schlammpfützen, Giftfässer und
## grüner Brodem im Süden, wo der braune Bach ins Dorf sickert.
func _plague_toxic_town() -> void:
	for t: Vector2i in [Vector2i(3, 10), Vector2i(2, 7), Vector2i(6, 11),
			Vector2i(16, 10), Vector2i(13, 12), Vector2i(7, 12)]:
		_place_prop("sludge", t.x, t.y, _tile_noise(t.x, t.y))
	for t: Vector2i in [Vector2i(2, 12), Vector2i(17, 11)]:
		_place_prop("barrel", t.x, t.y, _tile_noise(t.x, t.y))
	_toxic_bubbles(Vector2(3 * TILE + 8, 10 * TILE + 10))
	_toxic_bubbles(Vector2(16 * TILE + 8, 10 * TILE + 10))
	var l := Fx.point_light(Color(0.55, 0.95, 0.35), 46.0, 0.55)
	l.position = Vector2(4 * TILE, 11 * TILE)
	add_child(l)
	Fx.pulse(l, 0.55, 1.8)

## Plage 2 im Dorf: Pfändungsbescheide kleben an den Haustüren, beschlagnahmter
## Hausrat stapelt sich davor — die Eintreiber des Monopolfürsten waren hier.
func _plague_greed_town() -> void:
	for d: Vector2i in [Vector2i(4, 3), Vector2i(14, 3)]:
		var s := Sprite2D.new()
		s.texture = SpriteFactory.prop("notice")
		s.centered = false
		s.position = Vector2(d.x * TILE + 6, d.y * TILE + 5)
		s.z_index = 2
		add_child(s)
	_place_prop("crate", 5, 4, 0.30)
	_place_prop("coins", 6, 4, 0.55)
	_place_prop("crate", 12, 4, 0.70)
	_place_prop("coins", 13, 4, 0.20)

## Plage 3 im Dorf: hinterm Südwestwald steht Kriegsrauch, roter Widerschein
## flackert über den Bäumen, Glutasche weht herein — der Spalter rückt näher.
func _plague_war_town() -> void:
	_smoke_plume(Vector2(2 * TILE + 8, 13 * TILE), Color(0.25, 0.22, 0.24, 0.75))
	_smoke_plume(Vector2(5 * TILE, 13 * TILE + 8), Color(0.32, 0.28, 0.28, 0.6))
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(22, Color(1.0, 0.30, 0.12, 0.18))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.material = _additive()
	glow.position = Vector2(3 * TILE, 13 * TILE + 4)
	glow.scale = Vector2(2.2, 1.1)
	glow.z_index = 6
	add_child(glow)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.5, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "modulate:a", 1.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for t: Vector2i in [Vector2i(4, 11), Vector2i(6, 12)]:
		_place_prop("crack", t.x, t.y, _tile_noise(t.x, t.y))
	_place_prop("bones", 3, 12, 0.4)
	# Glutasche weht von Südwesten herein.
	var p := CPUParticles2D.new()
	p.position = Vector2(3 * TILE, 12 * TILE)
	p.amount = 10
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.direction = Vector2(0.5, -0.4)
	p.spread = 30.0
	p.gravity = Vector2(6, -3)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.color = Color(1.0, 0.45, 0.2, 0.5)
	p.texture = SpriteFactory.circle(1, Color.WHITE)
	p.z_index = 6
	add_child(p)

## Plage 1 auf der Überwelt: der Fluss führt Giftbrühe — trübes Wasser,
## Blasen und Schlammränder an den Ufern. Nach dem Sieg glitzert er wieder.
func _plague_toxic_world() -> void:
	for s: Sprite2D in water_tiles:
		s.modulate = Color(0.72, 0.68, 0.42)
	for t: Vector2i in [Vector2i(10, 3), Vector2i(13, 7), Vector2i(10, 9), Vector2i(13, 12)]:
		_place_prop("sludge", t.x, t.y, _tile_noise(t.x, t.y))
	_toxic_bubbles(Vector2(11 * TILE + 12, 4 * TILE))
	_toxic_bubbles(Vector2(11 * TILE + 12, 8 * TILE))
	_toxic_bubbles(Vector2(11 * TILE + 12, 12 * TILE))

## Plage 2 auf der Überwelt: die Tributstraße zum Konzernturm — Zollkisten und
## eingetriebene Münzhaufen säumen den Pass, goldener Schein über dem Tor.
func _plague_greed_world() -> void:
	_place_prop("crate", 17, 3, 0.30)
	_place_prop("coins", 19, 3, 0.60)
	_place_prop("coins", 16, 4, 0.25)
	_place_prop("crate", 19, 4, 0.75)
	_place_prop("coins", 17, 6, 0.45)
	var l := Fx.point_light(Color(1.0, 0.85, 0.45), 52.0, 0.7)
	l.position = Vector2(18 * TILE + 8, 3 * TILE)
	add_child(l)
	Fx.pulse(l, 0.7, 1.6)

## Plage 3 auf der Überwelt: über der Hassfestung steht Kriegsrauch, Glut
## treibt übers Land, der Boden ringsum ist aufgerissen und voller Gebeine.
func _plague_war_world() -> void:
	_smoke_plume(Vector2(4 * TILE + 8, 13 * TILE + 2), Color(0.22, 0.20, 0.22, 0.8))
	_smoke_plume(Vector2(3 * TILE + 4, 13 * TILE + 8), Color(0.30, 0.26, 0.26, 0.6))
	var l := Fx.point_light(Color(1.0, 0.35, 0.15), 60.0, 0.8)
	l.position = Vector2(4 * TILE + 8, 13 * TILE + 8)
	add_child(l)
	Fx.pulse(l, 0.8, 1.1)
	for t: Vector2i in [Vector2i(5, 13), Vector2i(2, 12)]:
		_place_prop("crack", t.x, t.y, _tile_noise(t.x, t.y))
	_place_prop("bones", 6, 13, 0.5)
	_place_prop("bones", 2, 13, 0.8)
	# Glutflocken treiben über die Ebene vor der Festung.
	var p := CPUParticles2D.new()
	p.position = Vector2(4 * TILE, 12 * TILE)
	p.amount = 12
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.direction = Vector2(0.4, -0.5)
	p.spread = 30.0
	p.gravity = Vector2(5, -4)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 11.0
	p.color = Color(1.0, 0.45, 0.2, 0.5)
	p.texture = SpriteFactory.circle(1, Color.WHITE)
	p.z_index = 6
	add_child(p)

func _spawn_npcs() -> void:
	for npc in map["npcs"]:
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(npc["id"], "down", 0)
		s.centered = false
		s.offset = _char_offset(s.texture)
		s.scale = Vector2(FIELD_CHAR_SCALE, FIELD_CHAR_SCALE)
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
		# Die Rig-Bosse sind für den Kampf ausgelegt (112x128). Auf der Karte
		# müssen sie auf etwa zwei Kacheln herunter, sonst füllt der Boss den
		# halben Bildschirm.
		bs.scale = Vector2(FIELD_BOSS_SCALE, FIELD_BOSS_SCALE)
		# Sprite mittig über der Kachel, Füße auf dem Kachelboden.
		var tw2 := bs.texture.get_width() * FIELD_BOSS_SCALE
		var th := bs.texture.get_height() * FIELD_BOSS_SCALE
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
	player.offset = _char_offset(player.texture)
	player.scale = Vector2(FIELD_CHAR_SCALE, FIELD_CHAR_SCALE)
	player.z_index = 10
	add_child(player)
	_attach_drop_shadow(player)
	follower = Sprite2D.new()
	follower.centered = false
	follower.offset = _char_offset(follower.texture)
	follower.scale = Vector2(FIELD_CHAR_SCALE, FIELD_CHAR_SCALE)
	follower.z_index = 9
	add_child(follower)
	_attach_drop_shadow(follower)
	follower2 = Sprite2D.new()
	follower2.centered = false
	follower2.offset = _char_offset(follower2.texture)
	follower2.scale = Vector2(FIELD_CHAR_SCALE, FIELD_CHAR_SCALE)
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
	# Die Figur steht auf FIELD_CHAR_SCALE — Kinder erben das, also müssen
	# Ort und Größe des Schattens gegengerechnet werden.
	sh.position = Vector2(6, 15) / FIELD_CHAR_SCALE
	sh.scale = Vector2(1.0, 1.0) / FIELD_CHAR_SCALE
	sh.show_behind_parent = true
	s.add_child(sh)

## Kleiner Staubstoß dort, wo der Fuß abstößt. Ohne ihn wirkt Bewegung wie
## Gleiten auf Eis — der Abdruck verkauft das Gewicht.
func _step_dust(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 4
	p.lifetime = 0.34
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 26)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 15.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	p.color = Color(0.72, 0.70, 0.64, 0.42)
	p.texture = SpriteFactory.circle(2, Color.WHITE)
	p.z_index = 4
	p.emitting = true
	add_child(p)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(p.queue_free)

## Abfedern beim Aufkommen: kurz stauchen, dann zurück. Zwei Prozent reichen —
## mehr wirkt wie Gummi.
func _step_squash(s: Sprite2D) -> void:
	var base := Vector2(FIELD_CHAR_SCALE, FIELD_CHAR_SCALE)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", base * Vector2(1.07, 0.93), STEP_TIME * 0.35) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "scale", base, STEP_TIME * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Derselbe Versatz wie CHAR_OFFSET, aber aus der Textur gerechnet statt aus den
## Rig-Konstanten. Noetig, seit Figuren auch aus anderen Quellen kommen koennen
## (LPC-Vorschau, andere Leinwandgroesse) — sonst haengen sie neben der Kachel
## oder schweben darueber.
func _char_offset(tex: Texture2D) -> Vector2:
	if tex == null:
		return CHAR_OFFSET
	# Leerraum unter den Fuessen abziehen: die LPC-Zelle ist quadratisch und
	# laesst unten Platz, wodurch die Figur ueber ihrer Kachel zu schweben
	# schien — man traf die Ausgaenge dadurch schwerer, als es aussah.
	var pad := 0.0
	if tex.get_width() == tex.get_height():
		pad = tex.get_height() * 0.06
	return Vector2(6.0 / FIELD_CHAR_SCALE - tex.get_width() / 2.0,
		16.0 / FIELD_CHAR_SCALE - tex.get_height() + pad)

func _dir_name(d: Vector2i) -> String:
	if d.y > 0: return "down"
	if d.y < 0: return "up"
	return "side"

func _update_sprites() -> void:
	# Blickrichtung: nach oben/unten gibt es eigene Ansichten (Rücken bzw.
	# Gesicht), seitwärts wird die Seitenansicht gespiegelt.
	var pd := _dir_name(facing)
	player.texture = SpriteFactory.field_char("serena", moving, anim_frame, pd)
	player.flip_h = pd == "side" and facing.x < 0
	var fd := player_tile - follower_tile
	if fd == Vector2i.ZERO:
		fd = facing
	var fdn := _dir_name(fd)
	follower.texture = SpriteFactory.field_char("milo", moving, anim_frame, fdn)
	follower.flip_h = fdn == "side" and fd.x < 0
	var fd2 := follower_tile - follower2_tile
	if fd2 == Vector2i.ZERO:
		fd2 = fd
	var fd2n := _dir_name(fd2)
	follower2.texture = SpriteFactory.field_char("rax", moving, anim_frame, fd2n)
	follower2.flip_h = fd2n == "side" and fd2.x < 0

func _process(delta: float) -> void:
	# Weiterlaufende Idle-/Lauf-Animation (4 Frames, ~7 fps).
	anim_accum += delta
	if anim_accum >= 0.14:
		anim_accum -= 0.14
		anim_frame = (anim_frame + 1) % 16
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
	_step_dust(_tile_pos(old) + Vector2(8, 15))
	_step_squash(player)
	# Die Kamera schaut ein Stück in Laufrichtung voraus, statt starr auf der
	# Figur zu kleben — das nimmt der Bewegung die Steifheit.
	if is_instance_valid(camera):
		var lead := Vector2(facing) * 9.0
		var ct := camera.create_tween()
		ct.tween_property(camera, "position", Vector2(6, 8) + lead, STEP_TIME * 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
			if portal.has("locked_until") and not GameState.is_unlocked(portal["locked_until"]):
				AudioManager.play_sfx("error")
				dialog_name.text = portal.get("locked_name", "Barrier")
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
	# Kräftige Vignette: sie drückt die Ränder zu und lenkt den Blick auf die
	# Figur — das trägt die unheimliche Stimmung, ohne die Mitte zu verdunkeln.
	vig.texture = SpriteFactory.vignette(240, 135, 0.55)
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
	title.text = "— Greta's Shop —   (Z: Buy, X: Back)"
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
		l.text = "%s%s  %d G  (owned: %d) — %s" % [cursor, item_name, item["price"], owned, item["desc"]]
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
