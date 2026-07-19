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
const KENNEY_TILES := {
	"grass": Vector2i(0, 15), "tree": Vector2i(13, 10), "path": Vector2i(0, 25),
	"water": Vector2i(0, 0), "mount": Vector2i(6, 14),
}

# Mehrere gleichwertige Voll-Kacheln pro Terrain → bricht den Rastereindruck.
const KENNEY_VARIANTS := {
	"grass": [Vector2i(0, 15), Vector2i(1, 15), Vector2i(0, 16), Vector2i(1, 16)],
	"water": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"path": [Vector2i(0, 25), Vector2i(1, 25), Vector2i(0, 26), Vector2i(1, 26)],
}

## Kachel für Kartenposition (x,y) mit deterministischer Variation (falls vorhanden).
static func tile_at(kind: String, x: int, y: int) -> Texture2D:
	if KENNEY_VARIANTS.has(kind):
		var vs: Array = KENNEY_VARIANTS[kind]
		var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
		return _kenney(vs[h % vs.size()])
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
			return _tile_color("mount", x, y)
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
			return _tile_color("mount", x, y)
		"keep_icon":
			# Rotes Banner über dem Tor
			if x >= 7 and x <= 8 and y >= 1 and y < 4: return Color(0.72, 0.12, 0.14)
			# Zinnenkranz
			if y >= 4 and y < 6 and x > 2 and x < 14 and (x % 3 != 0): return Color(0.24, 0.21, 0.25)
			# Festungskörper mit dunklem Tor
			if y >= 6 and y < 14 and x > 2 and x < 14:
				if x >= 7 and x <= 9 and y >= 10: return Color(0.08, 0.06, 0.09)
				return Color(0.30, 0.26, 0.30) if n > 0.25 else Color(0.26, 0.22, 0.26)
			return _tile_color("grass", x, y)
		"town_icon":
			if y > 9 and x > 2 and x < 13: return Color(0.75, 0.68, 0.55)
			if y > 5 and y <= 9 and x > 1 and x < 14: return Color(0.66, 0.24, 0.20)
			return _tile_color("grass", x, y)
		"bridge":
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
			var g := _tile_color("grass", x, y)
			var lum := (g.r + g.g + g.b) / 3.0
			return Color(lum * 0.7 + 0.07, lum * 0.72 + 0.07, lum * 0.7 + 0.1)
	return Color.MAGENTA

## ---------- Charaktere (12x16, prozedural, 2 Laufframes) ----------
