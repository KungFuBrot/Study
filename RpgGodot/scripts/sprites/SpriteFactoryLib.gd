class_name SpriteFactoryLib
## Texturen für das Spiel. Umgebungs-Deko und Effekte werden prozedural erzeugt;
## Dungeon-Kacheln sowie Helden-/Monster-Kampfsprites stammen aus dem
## CC0-Pack "Dungeon Tileset II" von 0x72 (siehe assets/dtii/LICENSE.txt).

static var _cache := {}

const TILE := 16

## ---------- Dungeon Tileset II (CC0, 0x72) ----------

const DTII := "res://assets/dtii/frames/"

# Lädt einen Einzelframe als Textur (gecacht). name z. B. "skelet_idle_anim_f0".
static func dtii(name: String) -> Texture2D:
	var key := "dtii_" + name
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = load(DTII + name + ".png")
	_cache[key] = t
	return t

# Held → Basissprite (16x28) + Waffe fürs Kampfbild.
const HERO_DTII := {
	"serena": {"base": "elf_f", "weapon": "weapon_regular_sword"},
	"milo": {"base": "wizzard_m", "weapon": "weapon_green_magic_staff"},
}

# Gegner-ID → animiertes DTII-Sprite (alle 4 Frames), plus Kampfmaßstab.
const MON_DTII := {
	# Schlotwerk (Umweltverschmutzer)
	"schlammschleim": {"anim": "muddy_anim", "big": false},
	"qualmgeist": {"anim": "swampy_anim", "big": false},
	"muellgnom": {"anim": "goblin_idle_anim", "big": false},
	"boss": {"anim": "big_zombie_idle_anim", "big": true},
	# Konzernturm (Kapitalisten)
	"gierschlund": {"anim": "chort_idle_anim", "big": false},
	"paragraphengeist": {"anim": "necromancer_anim", "big": false},
	"zinshund": {"anim": "wogol_idle_anim", "big": false},
	"boss2": {"anim": "ogre_idle_anim", "big": true},
	# Hassfestung (Rassisten und Nationalisten)
	"hetzer": {"anim": "masked_orc_idle_anim", "big": false},
	"wutgeist": {"anim": "imp_idle_anim", "big": false},
	"schlaeger": {"anim": "orc_warrior_idle_anim", "big": false},
	"hassprediger": {"anim": "orc_shaman_idle_anim", "big": false},
	"boss3": {"anim": "big_demon_idle_anim", "big": true},
	# Die Leere (keine Emotionen, Einsamkeit, Gleichgültigkeit)
	"hohlgaenger": {"anim": "wizzard_f_idle_anim", "big": false},
	"grauschemen": {"anim": "ice_zombie_anim", "big": false},
	"namenlose": {"anim": "elf_f_idle_anim", "big": false},
	"boss4": {"anim": "skelet_idle_anim", "big": true},
}

# Dungeon-Kacheln aus DTII (der Rest bleibt prozedural).
const DTII_TILES := {
	"floor": "floor_1", "dwall": "wall_mid",
	"ice": "floor_2", "iwall": "wall_mid",
	"hfloor": "floor_3", "hwall": "wall_mid",
	# Mauerkrone: die Oberkante der Wand, eine Reihe über der Ziegelfront.
	"wall_crown": "wall_top_mid",
	# Dungeon-Ausgang: Leiter im Boden statt einer Erdkachel im Gemäuer.
	"exit": "floor_ladder",
}

# Requisiten, die direkt aus DTII-Frames kommen (statt PROP_ART).
const DTII_PROPS := {
	"banner_red": "wall_banner_red", "banner_yellow": "wall_banner_yellow",
	"crate": "crate", "goo": "wall_goo",
}

# Feldfiguren (Erkundung) → DTII-Basissprite (16x28). Identisch zu den
# Kampfsprites bei den Helden, damit die Party überall gleich aussieht.
const FIELD_DTII := {
	"serena": "elf_f", "milo": "wizzard_m",
	"npc_elder": "dwarf_m", "npc_kid": "lizard_m", "npc_shop": "dwarf_f",
}
const FIELD_SPRITE_H := 28  # DTII-Figurenhöhe (für die Bodenausrichtung im Feld)

## ---------- Kenney Particle Pack (CC0): weiche Rauch-/Feuer-/Blitztexturen ----------

const KPART := "res://assets/kenney/particles/"

static func particle(name: String) -> Texture2D:
	var key := "kp_" + name
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = load(KPART + name + ".png")
	_cache[key] = t
	return t

## Fels-/Bodenrauschen (FastNoiseLite-FBM): organische Struktur statt
## flacher Verläufe. Klein rendern und hochskalieren (linear) = weich.
static func noise_texture(w: int, h: int, dark: Color, base: Color, nseed: int, freq := 0.05) -> Texture2D:
	var key := "noise_%d_%d_%d_%f" % [w, h, nseed, freq]
	if _cache.has(key):
		return _cache[key]
	var n := FastNoiseLite.new()
	n.seed = nseed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = 4
	n.frequency = freq
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, dark.lerp(base, v))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## ---------- Kenney Roguelike/RPG Pack (CC0) für Überwelt-Bodenkacheln ----------

const KENNEY_SHEET := "res://assets/kenney/roguelikeSheet.png"
const KENNEY_STRIDE := 17  # 16px-Kacheln mit 1px Abstand

# Kartenzeichen → Kenney-Zelle (Spalte, Zeile). Nur Terrain; Häuser/Marker
# und Dungeon-Kacheln kommen weiterhin von anderswo.
# Der Weg lag früher auf (0,25) — das ist im Sheet ein Holzdielenboden für
# Innenräume und sah auf der Karte wie eine braune Platte aus. (6,0) ist
# echter Erdboden.
# Der Berg lag früher auf (6,14) — das ist ein einzelnes Felsbruchstück, das
# als Vollkachel eine Quadratmauer ergab. (7,0) ist glatter Fels als Fläche;
# die Form entsteht jetzt über die Übergangskanten.
const KENNEY_TILES := {
	"grass": Vector2i(0, 15), "tree": Vector2i(13, 10), "path": Vector2i(6, 0),
	"water": Vector2i(0, 0), "mount": Vector2i(7, 0),
}

# Mehrere gleichwertige Voll-Kacheln pro Terrain → bricht den Rastereindruck.
const KENNEY_VARIANTS := {
	"grass": [Vector2i(0, 15), Vector2i(1, 15), Vector2i(0, 16), Vector2i(1, 16)],
	"water": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"path": [Vector2i(6, 0), Vector2i(6, 1)],
	"mount": [Vector2i(7, 0), Vector2i(9, 0)],
}

# Der Kenney-Fels ist als helles Pflaster gedacht; als Gebirge muss er
# abgedunkelt und leicht kühl getönt werden, sonst wirkt er wie Beton.
const KENNEY_TINT := {"mount": Color(0.72, 0.74, 0.80)}

## ---------- Gelände-Übergänge (Autotiling) ----------

# Rangfolge des Geländes: Höherwertiges blutet in die Kachel des Niedrigeren
# hinein. Wasser liegt zuunterst (Land bildet das Ufer), Wege liegen obenauf.
# Gelände ohne Eintrag bekommt keine Übergänge (Dungeonböden, Brücken).
const TERRAIN_RANK := {"water": 0, "grass": 1, "path": 2, "mount": 3}

# Nachbar-Bitmaske, im Uhrzeigersinn ab Norden.
const M_N := 1
const M_NE := 2
const M_E := 4
const M_SE := 8
const M_S := 16
const M_SW := 32
const M_W := 64
const M_NW := 128

# Wie weit (in Pixeln) das höhere Gelände über die Kachelkante greift.
const EDGE_REACH := 7.0
# Wie stark das Rauschen die Kante auslenkt (0.55 ≈ ±2 Pixel Mäander).
const EDGE_WOBBLE := 0.55
# Kachelperiode des Kantenrauschens. Kleine Zahl = kleiner Kachel-Cache,
# große Zahl = weniger Wiederholung. 8 Kacheln = 128 px, das sieht niemand.
const EDGE_WRAP := 8

static var _edge_noise: FastNoiseLite

## Übergangskachel: Gelände `over` greift gemäß Nachbarmaske in die Kachel des
## darunter liegenden Geländes `under` hinein. Die Kante bleibt pixelscharf
## (Pixel-Art verträgt keinen Weichzeichner), mäandert aber durch tieffrequentes
## Rauschen um mehrere Pixel — das ist der Unterschied zwischen „Tabellenzelle"
## und „gewachsenem Gelände". Am Saum liegt eine Kontaktkante: Schatten an
## Land/Land-Übergängen, heller Schaum am Ufer.
## `tx`/`ty` sind die Kachelkoordinaten — das Rauschen läuft in Weltkoordinaten
## weiter, damit lange Ufer nicht in Kachelmustern zerfallen.
static func edge_overlay(over: String, under: String, mask: int, tx: int, ty: int) -> Texture2D:
	var vx := tx % EDGE_WRAP
	var vy := ty % EDGE_WRAP
	var key := "edge_%s_%s_%d_%d_%d" % [over, under, mask, vx, vy]
	if _cache.has(key):
		return _cache[key]
	if _edge_noise == null:
		_edge_noise = FastNoiseLite.new()
		_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_edge_noise.frequency = 0.11
		_edge_noise.seed = 4711
	var rim := Color(0.86, 0.95, 1.0, 0.5) if under == "water" else Color(0, 0, 0, 0.22)
	var src := _tile_image(over)
	var img := _img(TILE, TILE)
	for y in TILE:
		for x in TILE:
			var d := _edge_coverage(mask, x, y)
			if d <= 0.0:
				continue
			var n := _edge_noise.get_noise_2d(vx * TILE + x, vy * TILE + y)
			var t := d + n * EDGE_WOBBLE
			if t > 0.5:
				img.set_pixel(x, y, src.get_pixel(x, y))
			elif t > 0.30:
				img.set_pixel(x, y, rim)
	var t2 := _tex(img)
	_cache[key] = t2
	return t2

# Deckungsgrad an der Stelle (x,y): 1.0 an der Kachelkante zum höheren
# Gelände hin, 0.0 ab EDGE_REACH Pixeln Abstand.
static func _edge_coverage(mask: int, x: int, y: int) -> float:
	# Liegt das höhere Gelände auf beiden gegenüberliegenden Seiten, ist diese
	# Kachel ein schmaler Streifen (einreihiger Weg, enger Fluss). Dann greift
	# der Übergang von beiden Seiten — ohne Drosselung wäre der Streifen weg.
	var rx := EDGE_REACH * (0.5 if (mask & M_W) and (mask & M_E) else 1.0)
	var ry := EDGE_REACH * (0.5 if (mask & M_N) and (mask & M_S) else 1.0)
	var rd := minf(rx, ry)
	var d := 0.0
	if mask & M_N:
		d = maxf(d, 1.0 - float(y) / ry)
	if mask & M_S:
		d = maxf(d, 1.0 - float(TILE - 1 - y) / ry)
	if mask & M_W:
		d = maxf(d, 1.0 - float(x) / rx)
	if mask & M_E:
		d = maxf(d, 1.0 - float(TILE - 1 - x) / rx)
	# Diagonalen füllen nur dann die Ecke, wenn keine der beiden anliegenden
	# Seiten ohnehin schon deckt — sonst entstünde eine Doppelkante.
	if (mask & M_NW) and not (mask & (M_N | M_W)):
		d = maxf(d, 1.0 - Vector2(x, y).length() / rd)
	if (mask & M_NE) and not (mask & (M_N | M_E)):
		d = maxf(d, 1.0 - Vector2(TILE - 1 - x, y).length() / rd)
	if (mask & M_SW) and not (mask & (M_S | M_W)):
		d = maxf(d, 1.0 - Vector2(x, TILE - 1 - y).length() / rd)
	if (mask & M_SE) and not (mask & (M_S | M_E)):
		d = maxf(d, 1.0 - Vector2(TILE - 1 - x, TILE - 1 - y).length() / rd)
	return d

## Rohbild einer Kachel (für Übergänge). Kenney-Zellen werden direkt aus dem
## Sheet geschnitten — AtlasTexture-Bilder sind dafür nicht verlässlich.
static func _tile_image(kind: String) -> Image:
	var key := "timg_" + kind
	if _cache.has(key):
		return _cache[key]
	var img: Image
	if KENNEY_TILES.has(kind):
		img = _kenney_cell_image(KENNEY_TILES[kind], kind)
	else:
		img = tile(kind).get_image()
		img.convert(Image.FORMAT_RGBA8)
	_cache[key] = img
	return img

static var _kenney_img: Image

static func _kenney_image() -> Image:
	if _kenney_img == null:
		if _kenney_sheet == null:
			_kenney_sheet = load(KENNEY_SHEET)
		_kenney_img = _kenney_sheet.get_image()
		_kenney_img.convert(Image.FORMAT_RGBA8)
	return _kenney_img

static func _kenney_rect(cell: Vector2i) -> Rect2i:
	return Rect2i(cell.x * KENNEY_STRIDE, cell.y * KENNEY_STRIDE, TILE, TILE)

## Einzelzelle als Bild, bei getönten Geländearten gleich eingefärbt — damit
## Basiskachel und Übergangskante dieselbe Farbe haben.
static func _kenney_cell_image(cell: Vector2i, kind: String) -> Image:
	var img := _img(TILE, TILE)
	img.blit_rect(_kenney_image(), _kenney_rect(cell), Vector2i.ZERO)
	if KENNEY_TINT.has(kind):
		var t: Color = KENNEY_TINT[kind]
		for y in TILE:
			for x in TILE:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * t.r, c.g * t.g, c.b * t.b, c.a))
	return img

static func _kenney_tinted(cell: Vector2i, kind: String) -> Texture2D:
	var key := "ktint_%s_%d_%d" % [kind, cell.x, cell.y]
	if _cache.has(key):
		return _cache[key]
	var t := _tex(_kenney_cell_image(cell, kind))
	_cache[key] = t
	return t

## ---------- Bodenflecken ----------

# Große Gras- und Wegflächen bestehen aus wenigen sich wiederholenden Kacheln;
# ab etwa vier Kacheln Abstand erkennt das Auge das Muster. Diese Schicht legt
# unregelmäßige, weiche Flecken darüber — heller ausgetretener Boden, dunklere
# feuchte Stellen. Sie sitzen nicht im Kachelraster, sondern übergreifend.
# Achtung: das sind echte Farben, keine Faktoren. Werte über 1.0 klemmen auf
# Weiß und ergeben helle Kleckse statt Bodenvariation.
const PATCH_TINTS := {
	# feuchter Schatten, vertrocknet, moosig
	"grass": [Color(0.16, 0.28, 0.14), Color(0.44, 0.48, 0.20), Color(0.20, 0.38, 0.24)],
	# nass getreten, staubig, lehmig
	"path": [Color(0.26, 0.18, 0.12), Color(0.56, 0.45, 0.31), Color(0.36, 0.26, 0.17)],
	"mount": [Color(0.26, 0.28, 0.33), Color(0.56, 0.58, 0.62)],
}

## Weicher Fleck: eine ausgefranste Fläche, die die Kachel darunter tönt.
## `variant` wählt Form und Tönung, `kind` die Farbfamilie.
static func ground_patch(kind: String, variant: int) -> Texture2D:
	var key := "patch_%s_%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var tints: Array = PATCH_TINTS.get(kind, PATCH_TINTS["grass"])
	var tint: Color = tints[variant % tints.size()]
	if _edge_noise == null:
		_edge_noise = FastNoiseLite.new()
		_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_edge_noise.frequency = 0.11
		_edge_noise.seed = 4711
	var img := _img(TILE, TILE)
	var ox := (variant * 37) % 64
	var oy := (variant * 53) % 64
	for y in TILE:
		for x in TILE:
			# Radialer Abfall zur Kachelmitte, vom Rauschen aufgebrochen.
			var d := Vector2(x - 7.5, y - 7.5).length() / 9.0
			var n := _edge_noise.get_noise_2d(ox + x * 1.6, oy + y * 1.6)
			if 1.0 - d + n * 0.7 > 0.45:
				# Tönung als halbtransparente Farbe: multiplikativ wäre
				# korrekter, aber CanvasItem-Multiply kostet ein Material je
				# Sprite. Bei diesen kleinen Abweichungen genügt Alpha.
				var a: float = clampf((1.0 - d + n * 0.7 - 0.45) * 1.1, 0.0, 0.20)
				img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
	var t := _tex(img)
	_cache[key] = t
	return t

## ---------- Bäume (drei Kacheln hoch) ----------

# Im Sheet steht jeder Baum als 16x48-Säule (Krone, Mitte, Stamm) in drei
# Zellen übereinander. Angegeben ist die oberste Zelle. Bisher wurde nur der
# einzelne Busch (13,10) benutzt — daher der „Heckenwall"-Eindruck.
# Überwiegend Grüntöne, ein Herbstbaum als seltener Farbtupfer.
const KENNEY_TREES := [Vector2i(15, 9), Vector2i(16, 9), Vector2i(18, 9),
	Vector2i(15, 9), Vector2i(16, 9), Vector2i(14, 9)]
const TREE_H := TILE * 3

## Baum als eine 16x48-Textur; die 1px-Fugen des Sheets werden dabei entfernt.
static func tree_tex(variant: int) -> Texture2D:
	var key := "tree3_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var cell: Vector2i = KENNEY_TREES[variant % KENNEY_TREES.size()]
	var img := _img(TILE, TREE_H)
	for i in 3:
		img.blit_rect(_kenney_image(), _kenney_rect(cell + Vector2i(0, i)), Vector2i(0, i * TILE))
	var t := _tex(img)
	_cache[key] = t
	return t

## ---------- Dungeonböden: aufgehellt und variiert ----------

# Die DTII-Böden sind mit einem Mittelwert von 0.25 sehr dunkel. Zusammen mit
# Vignette, Farbgrading und Tiefenunschärfe (zusammen rund 0.5) blieb davon
# fast Schwarz übrig — man sah im Dungeon buchstäblich den Boden nicht. Also
# werden sie beim Laden angehoben; die Stimmung tragen weiterhin Grundlicht,
# Punktlichter und Vignette.
# Die drei Riss-Böden sind auffällige Einzelmotive — als gleichwertige
# Varianten wiederholen sie sich sichtbar. Deshalb bleibt floor_1 die Fläche,
# die Risse sind seltene Akzente.
const DTII_FLOOR_ACCENTS := ["floor_2", "floor_3", "floor_4"]
const DUNGEON_FLOORS := ["floor", "ice", "hfloor"]
# Aufhellung als Gamma, nicht als Faktor: die dunkle Fläche steigt deutlich,
# die ohnehin hellen Fugenränder kaum — ein linearer Faktor hatte daraus ein
# grelles Kachelgitter gemacht.
const FLOOR_GAMMA := 0.62
const WALL_GAMMA := 0.78

## Aufgehellte Kopie eines DTII-Frames (gecacht).
static func _lifted(frame: String, gamma: float) -> Texture2D:
	var key := "lift_%s_%f" % [frame, gamma]
	if _cache.has(key):
		return _cache[key]
	var img := dtii(frame).get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(pow(c.r, gamma), pow(c.g, gamma), pow(c.b, gamma), c.a))
	var t := _tex(img)
	_cache[key] = t
	return t

# Ruhige Fläche aus floor_1, jede achte Kachel ein Riss als Akzent.
static func _dungeon_floor(x: int, y: int) -> Texture2D:
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	if h % 8 == 0:
		return _lifted(DTII_FLOOR_ACCENTS[(h / 8) % DTII_FLOOR_ACCENTS.size()], FLOOR_GAMMA)
	return _lifted("floor_1", FLOOR_GAMMA)

## Kachel für Kartenposition (x,y) mit deterministischer Variation (falls vorhanden).
static func tile_at(kind: String, x: int, y: int) -> Texture2D:
	if DUNGEON_FLOORS.has(kind):
		return _dungeon_floor(x, y)
	if kind == "dwall" or kind == "iwall" or kind == "hwall":
		return _lifted("wall_mid", WALL_GAMMA)
	if kind == "wall_crown":
		return _lifted("wall_top_mid", WALL_GAMMA)
	if KENNEY_VARIANTS.has(kind):
		var vs: Array = KENNEY_VARIANTS[kind]
		var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
		var cell: Vector2i = vs[h % vs.size()]
		return _kenney_tinted(cell, kind) if KENNEY_TINT.has(kind) else _kenney(cell)
	return tile(kind)

static var _kenney_sheet: Texture2D

static func _kenney(cell: Vector2i) -> Texture2D:
	var key := "kenney_%d_%d" % [cell.x, cell.y]
	if _cache.has(key):
		return _cache[key]
	if _kenney_sheet == null:
		_kenney_sheet = load(KENNEY_SHEET)
	var at := AtlasTexture.new()
	at.atlas = _kenney_sheet
	at.region = Rect2(cell.x * KENNEY_STRIDE, cell.y * KENNEY_STRIDE, 16, 16)
	_cache[key] = at
	return at

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

## Dunkle 1px-Kontur um alle opaken Pixel — lässt Figuren deutlich hervortreten.
static func _outlined(img: Image, color := Color(0.06, 0.05, 0.09)) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := _img(w + 2, h + 2)
	out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(1, 1))
	for y in h + 2:
		for x in w + 2:
			if out.get_pixel(x, y).a > 0.01:
				continue
			# Nachbarn im QUELLBILD prüfen, sonst frisst sich die Kontur fort.
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var sx: int = x - 1 + d.x
				var sy: int = y - 1 + d.y
				if sx >= 0 and sy >= 0 and sx < w and sy < h \
						and img.get_pixel(sx, sy).a > 0.35:
					out.set_pixel(x, y, color)
					break
	return out

static func _img(w: int, h: int, base := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(base)
	return img

## Gefüllte Ellipse (für rundliche Körper wie den Spinnenleib).
static func _fill_ellipse(img: Image, ecx: int, ecy: int, rx: int, ry: int, col: Color) -> void:
	var w := img.get_width(); var h := img.get_height()
	for y in range(maxi(ecy - ry, 0), mini(ecy + ry + 1, h)):
		for x in range(maxi(ecx - rx, 0), mini(ecx + rx + 1, w)):
			var dx := float(x - ecx) / float(rx)
			var dy := float(y - ecy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)

## Dünne Linie zwischen zwei Punkten (Beine); zeichnet 1px, lückenlos.
static func _thick_line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var w := img.get_width(); var h := img.get_height()
	var steps := int(ceil(a.distance_to(b)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(maxi(steps, 1)))
		var x := int(round(p.x)); var y := int(round(p.y))
		if x >= 0 and x < w and y >= 0 and y < h:
			img.set_pixel(x, y, col)

# Deterministisches Rauschen, damit Tiles lebendig, aber stabil aussehen.
static func _n(x: int, y: int, seed_: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_ * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1103515245 & 0x7fffffff
	return float(h % 1000) / 1000.0

static func tile(kind: String) -> Texture2D:
	if DTII_TILES.has(kind):
		return dtii(DTII_TILES[kind])
	if KENNEY_TILES.has(kind):
		return _kenney(KENNEY_TILES[kind])
	var key := "tile_" + kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(TILE, TILE)
	for y in TILE:
		for x in TILE:
			img.set_pixel(x, y, _tile_color(kind, x, y))
	var t := _tex(img)
	_cache[key] = t
	return t

static func _tile_color(kind: String, x: int, y: int) -> Color:
	var n := _n(x, y, kind.hash())
	match kind:
		"grass":
			var c := Color(0.28, 0.55, 0.25)
			if n > 0.85: c = Color(0.34, 0.62, 0.28)
			elif n < 0.08: c = Color(0.22, 0.47, 0.21)
			return c
		"tree":
			var d := Vector2(x - 7.5, y - 6.0).length()
			if d < 6.5: return Color(0.10, 0.34, 0.13) if n < 0.7 else Color(0.16, 0.44, 0.16)
			if y > 11 and abs(x - 8) < 2: return Color(0.35, 0.23, 0.12)
			return _tile_color("grass", x, y)
		"water":
			var w := 0.5 + 0.5 * sin((x + y * 2.0) * 0.9)
			return Color(0.15, 0.30 + w * 0.10, 0.62 + w * 0.12)
		"path":
			var c2 := Color(0.72, 0.62, 0.42)
			if n > 0.88: c2 = Color(0.66, 0.55, 0.36)
			return c2
		"wall":
			if y % 5 == 0 or (x + (y / 5) * 3) % 8 == 0: return Color(0.42, 0.38, 0.36)
			return Color(0.58, 0.54, 0.50) if n > 0.15 else Color(0.52, 0.48, 0.45)
		"roof":
			if (x + y) % 4 == 0: return Color(0.52, 0.18, 0.16)
			return Color(0.66, 0.24, 0.20)
		"door":
			if x < 3 or x > 12: return _tile_color("wall", x, y)
			if y < 3: return _tile_color("wall", x, y)
			return Color(0.40, 0.26, 0.13) if (x % 4 != 0) else Color(0.30, 0.19, 0.10)
		"floor":
			if (x % 8 == 0) or (y % 8 == 0): return Color(0.26, 0.24, 0.30)
			return Color(0.36, 0.33, 0.40) if n > 0.2 else Color(0.32, 0.29, 0.36)
		"dwall":
			if y % 4 == 0 or (x + (y / 4) * 2) % 6 == 0: return Color(0.12, 0.11, 0.16)
			return Color(0.20, 0.18, 0.26)
		"wall_deep":
			# Mauermasse hinter der Krone: ruhige dunkle Fläche, damit das Auge
			# an der Kante hängen bleibt statt an endlosem Ziegelmuster.
			return Color(0.26, 0.25, 0.30) if n > 0.25 else Color(0.22, 0.21, 0.26)
		"mount":
			var ridge := absf(float(x) - 8.0) + float(15 - y) * 0.8
			if ridge < 6.0: return Color(0.55, 0.50, 0.46) if n > 0.3 else Color(0.62, 0.58, 0.54)
			return Color(0.40, 0.36, 0.34)
		"factory_icon":
			# Qualmwolken über den Schloten
			if y < 5 and (Vector2(x - 5, y - 3).length() < 2.3 or Vector2(x - 11, y - 2).length() < 2.0):
				return Color(0.42, 0.55, 0.34)
			# Zwei Schlote
			if y >= 5 and y < 9 and (x == 4 or x == 5 or x == 10 or x == 11):
				return Color(0.34, 0.31, 0.34)
			# Fabrikhalle mit Sheddach
			if y >= 9 and x > 1 and x < 15:
				if y <= 10: return Color(0.28, 0.25, 0.29)
				return Color(0.45, 0.41, 0.43) if (x % 4 != 0) else Color(0.38, 0.34, 0.37)
			# Der Rest bleibt frei: das Symbol steht auf dem echten Gelände,
			# sonst sitzt eine fremde Kachel als Loch in der Landschaft.
			return Color(0, 0, 0, 0)
		"ice":
			if (x * 2 + y) % 11 == 0: return Color(0.44, 0.62, 0.82)
			var ci := Color(0.62, 0.80, 0.94)
			if n > 0.85: ci = Color(0.74, 0.89, 0.99)
			elif n < 0.08: ci = Color(0.50, 0.68, 0.86)
			return ci
		"iwall":
			if y % 4 == 0 or (x + (y / 4) * 2) % 6 == 0: return Color(0.12, 0.20, 0.36)
			return Color(0.22, 0.34, 0.55) if n > 0.2 else Color(0.18, 0.29, 0.48)
		"tower_icon":
			# Schlanker Konzernturm mit goldener Spitze und Fensterbändern
			if x > 5 and x < 11:
				if y < 3: return Color(1.0, 0.84, 0.32)
				if y < 14:
					if y % 3 == 1 and x % 2 == 0: return Color(0.32, 0.52, 0.72)
					return Color(0.80, 0.78, 0.76)
			if y >= 13 and x > 3 and x < 13: return Color(0.58, 0.56, 0.58)
			return Color(0, 0, 0, 0)
		"keep_icon":
			# Rotes Banner über dem Tor
			if x >= 7 and x <= 8 and y >= 1 and y < 4: return Color(0.72, 0.12, 0.14)
			# Zinnenkranz
			if y >= 4 and y < 6 and x > 2 and x < 14 and (x % 3 != 0): return Color(0.24, 0.21, 0.25)
			# Festungskörper mit dunklem Tor
			if y >= 6 and y < 14 and x > 2 and x < 14:
				if x >= 7 and x <= 9 and y >= 10: return Color(0.08, 0.06, 0.09)
				return Color(0.30, 0.26, 0.30) if n > 0.25 else Color(0.26, 0.22, 0.26)
			return Color(0, 0, 0, 0)
		"town_icon":
			if y > 9 and x > 2 and x < 13: return Color(0.75, 0.68, 0.55)
			if y > 5 and y <= 9 and x > 1 and x < 14: return Color(0.66, 0.24, 0.20)
			return Color(0, 0, 0, 0)
		"bridge":
			# Steg mit freien Rändern: der Fluss läuft sichtbar darunter durch.
			if y < 2 or y > 13: return Color(0, 0, 0, 0)
			if y == 2 or y == 13: return Color(0.28, 0.19, 0.10)
			if y % 3 == 0: return Color(0.45, 0.32, 0.18)
			return Color(0.55, 0.40, 0.22)
		"void":
			# Die Leere: kalter, entsättigter Steinboden, fast ohne Struktur.
			if (x % 8 == 0) or (y % 8 == 0): return Color(0.15, 0.16, 0.19)
			var cv := Color(0.23, 0.24, 0.27)
			if n > 0.85: cv = Color(0.26, 0.27, 0.30)
			elif n < 0.1: cv = Color(0.20, 0.21, 0.24)
			return cv
		"vwall":
			if y % 4 == 0 or (x + (y / 4) * 2) % 6 == 0: return Color(0.09, 0.10, 0.13)
			return Color(0.16, 0.17, 0.21) if n > 0.2 else Color(0.13, 0.14, 0.18)
		"void_icon":
			# Ein einzelner grauer Monolith in totem, entsättigtem Umland.
			if x >= 7 and x <= 9 and y >= 2 and y < 14:
				return Color(0.30, 0.31, 0.34) if n > 0.3 else Color(0.23, 0.24, 0.27)
			if x >= 6 and x <= 10 and y >= 12 and y < 14: return Color(0.18, 0.19, 0.22)
			return Color(0, 0, 0, 0)
	return Color.MAGENTA

## ---------- Charaktere (12x16, prozedural, 2 Laufframes) ----------
