class_name SpriteFactory
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
	return Color.MAGENTA

## ---------- Charaktere (12x16, prozedural, 2 Laufframes) ----------

const HERO_PALETTES := {
	"serena": {"hair": Color(0.85, 0.65, 0.25), "body": Color(0.72, 0.18, 0.22), "trim": Color(0.90, 0.80, 0.60), "skin": Color(0.95, 0.80, 0.66), "pants": Color(0.38, 0.26, 0.16)},
	"milo": {"hair": Color(0.35, 0.30, 0.55), "body": Color(0.20, 0.30, 0.70), "trim": Color(0.75, 0.75, 0.95), "skin": Color(0.93, 0.78, 0.64), "pants": Color(0.24, 0.22, 0.45)},
	"npc_elder": {"hair": Color(0.85, 0.85, 0.85), "body": Color(0.45, 0.40, 0.30), "trim": Color(0.70, 0.65, 0.50), "skin": Color(0.90, 0.75, 0.62), "pants": Color(0.32, 0.29, 0.24)},
	"npc_kid": {"hair": Color(0.40, 0.25, 0.12), "body": Color(0.25, 0.55, 0.35), "trim": Color(0.85, 0.85, 0.60), "skin": Color(0.95, 0.80, 0.66), "pants": Color(0.30, 0.34, 0.30)},
	"npc_shop": {"hair": Color(0.55, 0.20, 0.35), "body": Color(0.60, 0.45, 0.20), "trim": Color(0.95, 0.90, 0.70), "skin": Color(0.94, 0.79, 0.65), "pants": Color(0.40, 0.28, 0.22)},
}

# Figuren-Schablone 12x16, wird pro Charakter mit seiner Palette eingefärbt.
# h/H Haar, s/S Haut, e Auge, b/B Oberteil, t Borte, l/L Hose, o Stiefel.
const CHAR_TPL := {
	"down": [[
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hhhhhhhh..",
		"..hssssssH..",
		"..ssessess..",
		"...SssssS...",
		"..tttttttt..",
		".bbbbbbbbbb.",
		".bbbttttbbb.",
		".sbbbbbbbbS.",
		"..BttttttB..",
		"..llllllll..",
		"..lll..lll..",
		"..Lll..ll...",
		"..oo...oo...",
		"..oo........",
	], [
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hhhhhhhh..",
		"..hssssssH..",
		"..ssessess..",
		"...SssssS...",
		"..tttttttt..",
		".bbbbbbbbbb.",
		".bbbttttbbb.",
		".Sbbbbbbbbs.",
		"..BttttttB..",
		"..llllllll..",
		"..lll..lll..",
		"...ll..llL..",
		"...oo...oo..",
		"........oo..",
	]],
	"side": [[
		"...hhhhh....",
		"..hhhhhhh...",
		"..hhhhhhhh..",
		"..hhhhssss..",
		"..Hhhhsses..",
		"...Hhhssss..",
		"..tttttt....",
		"..bbbbbbb...",
		"..bbbtbbb...",
		"..Bbbsbbb...",
		"..tttttt....",
		"..lllllll...",
		"...lll.ll...",
		"...ll...ll..",
		"...oo...oo..",
		"...oo...oo..",
	], [
		"...hhhhh....",
		"..hhhhhhh...",
		"..hhhhhhhh..",
		"..hhhhssss..",
		"..Hhhhsses..",
		"...Hhhssss..",
		"..tttttt....",
		"..bbbbbbb...",
		"..bbbtbbb...",
		"..Bbbsbbb...",
		"..tttttt....",
		"..lllllll...",
		"...llll.....",
		"....ll......",
		"....oo......",
		"....oo......",
	]],
	"up": [[
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hhhhhhhh..",
		"..hHhhhhHh..",
		"..hhhhhhhh..",
		"...hhhhhh...",
		"..tttttttt..",
		".bbbbbbbbbb.",
		".bbbbbbbbbb.",
		".sbbbbbbbbS.",
		"..BttttttB..",
		"..llllllll..",
		"..lll..lll..",
		"..Lll..ll...",
		"..oo...oo...",
		"..oo........",
	], [
		"...hhhhhh...",
		"..hhhhhhhh..",
		"..hhhhhhhh..",
		"..hHhhhhHh..",
		"..hhhhhhhh..",
		"...hhhhhh...",
		"..tttttttt..",
		".bbbbbbbbbb.",
		".bbbbbbbbbb.",
		".Sbbbbbbbbs.",
		"..BttttttB..",
		"..llllllll..",
		"..lll..lll..",
		"...ll..llL..",
		"...oo...oo..",
		"........oo..",
	]],
}

# Feldfigur aus dem CC0-Pack (Idle-Pose). dir wird ignoriert (DTII blickt
# nach rechts; das Feld spiegelt für „links").
static func character(id: String, dir: String, frame: int) -> Texture2D:
	return field_char(id, false, frame)

## Feldfigur mit Zustand: laufend → Lauf-Animation, sonst Idle (je 4 Frames).
static func field_char(id: String, walking: bool, frame: int) -> Texture2D:
	if id == "rax":
		return robot_field(walking, frame)
	var base: String = FIELD_DTII.get(id, "elf_f")
	var anim := "run" if walking else "idle"
	return dtii("%s_%s_anim_f%d" % [base, anim, frame % 4])

## (Alt, ungenutzt) prozedurale Feldfigur aus Row-Art.
static func character_art(id: String, dir: String, frame: int) -> Texture2D:
	var key := "chr_%s_%s_%d" % [id, dir, frame]
	if _cache.has(key):
		return _cache[key]
	var p: Dictionary = HERO_PALETTES.get(id, HERO_PALETTES["npc_kid"])
	var hair: Color = p["hair"]
	var body: Color = p["body"]
	var skin: Color = p["skin"]
	var pants: Color = p.get("pants", body.darkened(0.35))
	var pal := {
		"h": hair, "H": hair.darkened(0.30),
		"s": skin, "S": skin.darkened(0.18),
		"e": Color(0.10, 0.08, 0.12),
		"b": body, "B": body.darkened(0.28),
		"t": p["trim"],
		"l": pants, "L": pants.darkened(0.30),
		"o": Color(0.28, 0.19, 0.11),
	}
	var rows: Array = CHAR_TPL[dir][clampi(frame, 0, 1)]
	var img := _img(12, 16)
	for y in rows.size():
		var row: String = rows[y]
		for x in mini(row.length(), 12):
			if pal.has(row[x]):
				img.set_pixel(x, y, pal[row[x]])
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## ---------- Detaillierte Kampf-Sprites der Helden (blicken nach links) ----------

# Kampf-Sprites als Row-Art (26x28, blicken nach links), mit voller Schattierung.
const HERO_BATTLE_ART := {
	"serena": {
		# H/h Haar, s/S Haut, e Auge, r/R Harnisch, g Gold, w/W Klinge,
		# l/L Hose, b/B Stiefel
		"map": {"H": Color(0.95, 0.78, 0.32), "h": Color(0.72, 0.54, 0.18),
			"s": Color(0.96, 0.81, 0.67), "S": Color(0.80, 0.63, 0.50),
			"e": Color(0.20, 0.30, 0.55), "r": Color(0.78, 0.22, 0.26),
			"R": Color(0.54, 0.13, 0.17), "g": Color(0.94, 0.80, 0.38),
			"w": Color(0.88, 0.93, 1.0), "W": Color(0.62, 0.70, 0.84),
			"l": Color(0.34, 0.29, 0.27), "L": Color(0.24, 0.20, 0.19),
			"b": Color(0.42, 0.28, 0.16), "B": Color(0.30, 0.19, 0.10)},
		"rows": [
			"...ww.....................",
			"...wW.....HHHHHH..........",
			"...wW....HHHHHHHHH........",
			"...wW...HHHHHHHHHHHh......",
			"...wW...HHssssssHhHHh.....",
			"....wW..Hsessssh.hHHh.....",
			"....wW..Hssssssh..hHh.....",
			".....wW..SssssS...hh......",
			".....wW..gggggg...hh......",
			"....ggggg.rrrrrr..Rh......",
			"......gssrrrrrrrR.RR......",
			"......gssrrgggrrrR.RR.....",
			"........rrrrrrrrR.RR......",
			"........grrrrrrgR.RR......",
			"........gggggggg.RR.......",
			"........RrrrrrrR.RR.......",
			"........RrrrrrrR..R.......",
			".........ll..ll...........",
			".........ll..ll...........",
			".........ll..ll...........",
			".........Ll..lL...........",
			".........Ll..lL...........",
			"........bbb.bbb...........",
			"........bbb.bbb...........",
			"......bbbbb.bbbb..........",
			"......BbbbB.BbbB..........",
			"..........................",
			"..........................",
		]},
	"milo": {
		# p/P Hut, v/V Robe, t Saum, c Schal, o/O Orb, d/D Stab, g Gold
		"map": {"p": Color(0.32, 0.28, 0.66), "P": Color(0.20, 0.17, 0.46),
			"v": Color(0.26, 0.36, 0.76), "V": Color(0.17, 0.24, 0.55),
			"t": Color(0.80, 0.82, 0.96), "c": Color(0.65, 0.32, 0.65),
			"s": Color(0.94, 0.79, 0.65), "S": Color(0.78, 0.62, 0.48),
			"e": Color(0.15, 0.20, 0.40), "o": Color(0.35, 0.92, 1.0),
			"O": Color(0.95, 1.0, 1.0), "d": Color(0.48, 0.32, 0.16),
			"D": Color(0.34, 0.22, 0.10), "g": Color(0.95, 0.82, 0.35)},
		"rows": [
			"...............PP.........",
			"..............pPP.........",
			".............ppP..........",
			"...........ppppp..........",
			"...oo.....pppppppp........",
			"..oOOo...PppppppppP.......",
			"..oOOo..pppppppppppp......",
			"...oo...PPPPPPPPPPPP......",
			"....d....sssssssP.........",
			"....d....sessssSP.........",
			"....d....ssssssSP.........",
			"....d...ccccccccc.........",
			"...sds..vvvvvvvvvc........",
			"....d...vvvtttvvvc........",
			"....d...vvvvvvvvvV........",
			"....d...ggggggggV.........",
			"....d..vvvvvvvvvvv........",
			"....d..vvvvvvvvvvv........",
			"....d..vvvvvvvvvvV........",
			"....d..vvvvvvvvvvV........",
			"....d..vvvvvvvvvvV........",
			"....d.vvvvvvvvvvvvV.......",
			"....d.vvvvvvvvvvvvV.......",
			"....d.VvvvvvvvvvvVV.......",
			"....d.ttttttttttttt.......",
			".......DD....DD...........",
			"....D.....................",
			"..........................",
		]},
}

## Kampf-Sprite eines Helden aus dem CC0-Pack (16x28, idle f0..f3).
static func hero_battle(id: String) -> Texture2D:
	return hero_battle_frame(id, 0)

## anim: "idle" | "run" (DTII-Lauf-Frames) | "aim" (nur Rax, Schusspose).
static func hero_battle_frame(id: String, frame: int, anim := "idle") -> Texture2D:
	if id == "rax":
		return robot_battle_pose(anim, frame)
	var def: Dictionary = HERO_DTII.get(id, HERO_DTII["serena"])
	var set_name := "run" if anim == "run" else "idle"
	return dtii("%s_%s_anim_f%d" % [def["base"], set_name, frame % 4])

## Waffe eines Helden (kleines Overlay-Sprite), oder null.
static func hero_weapon(id: String) -> Texture2D:
	var def: Dictionary = HERO_DTII.get(id, {})
	if def.has("weapon"):
		return dtii(def["weapon"])
	return null

## (Alt, ungenutzt) prozedurales Helden-Kampfsprite aus Row-Art.
static func hero_battle_art(id: String) -> Texture2D:
	var key := "hero_battle_" + id
	if _cache.has(key):
		return _cache[key]
	var art: Dictionary = HERO_BATTLE_ART.get(id, HERO_BATTLE_ART["serena"])
	var rows: Array = art["rows"]
	var w: int = rows[0].length()
	var img := _img(w, rows.size())
	for y in rows.size():
		for x in mini(w, (rows[y] as String).length()):
			var ch: String = rows[y][x]
			if art["map"].has(ch):
				img.set_pixel(x, y, art["map"][ch])
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## ---------- Roboter-Held „Rax" (prozedural, mehrteilig animiert) ----------
## DTII hat keinen Roboter, und ein Roboter eignet sich bestens für scharfe,
## geometrische Pixel-Art. Vier Frames animieren Visor-Scan, Antennenblinken
## und den pulsierenden Brustkern — das Bild bleibt gestochen scharf (Nearest).
## Er blickt nach rechts (wie die DTII-Helden), im Kampf wird per flip_h gespiegelt.

const ROBOT_PAL := {
	"ml": Color(0.78, 0.83, 0.90), "mm": Color(0.52, 0.58, 0.67),
	"md": Color(0.30, 0.34, 0.42), "jt": Color(0.13, 0.15, 0.21),
	"eye": Color(0.45, 0.96, 1.0), "acc": Color(0.96, 0.63, 0.22),
}

## Vier Pulsphasen für den Brustkern (hell → dunkel → hell).
static func _robot_core(frame: int) -> Color:
	var lv: float = [1.0, 0.72, 0.5, 0.72][frame % 4]
	return Color(0.55, 0.22, 0.06).lerp(Color(1.0, 0.72, 0.32), lv)

static func robot_battle(frame: int) -> Texture2D:
	return robot_battle_pose("idle", frame)

## Posen: "idle" (Stand), "run" (Schwebe-Dash mit Düsenflamme, Beine angelegt),
## "aim" (breiter Stand, Kanone ausgefahren). Alle 28 px breit, damit Zentrum
## und Fußlinie über alle Posen identisch bleiben.
static func robot_battle_pose(pose: String, frame: int) -> Texture2D:
	if pose != "run" and pose != "aim":
		pose = "idle"
	var key := "robot_b_%s_%d" % [pose, frame % 4]
	if _cache.has(key):
		return _cache[key]
	var p := ROBOT_PAL
	var ml: Color = p["ml"]; var mm: Color = p["mm"]; var md: Color = p["md"]
	var jt: Color = p["jt"]; var eye: Color = p["eye"]; var acc: Color = p["acc"]
	var core := _robot_core(frame)
	var ant := Color(1.0, 0.38, 0.30) if (frame % 2 == 0 or pose == "aim") else Color(0.5, 0.19, 0.16)
	var img := _img(28, 28)
	# Antenne mit blinkender Spitze (in der Zielpose Dauerrot = "System scharf")
	img.set_pixel(9, 0, ant)
	img.fill_rect(Rect2i(9, 1, 1, 3), md)
	# Kopf-Kuppel
	img.fill_rect(Rect2i(6, 4, 12, 7), ml)
	img.set_pixel(6, 4, Color(0, 0, 0, 0)); img.set_pixel(17, 4, Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(6, 10, 12, 1), mm)
	img.fill_rect(Rect2i(17, 5, 1, 5), mm)
	# Visor (Front rechts) + wandernder Scan-Punkt (beim Zielen: volle Leiste)
	img.fill_rect(Rect2i(12, 5, 5, 1), md)
	img.fill_rect(Rect2i(12, 6, 5, 3), jt)
	if pose == "aim":
		img.fill_rect(Rect2i(12, 7, 5, 1), eye)
	else:
		var sx: int = 13 + [0, 1, 2, 1][frame % 4]
		img.set_pixel(sx, 7, eye); img.set_pixel(sx, 8, eye)
	# Hals
	img.fill_rect(Rect2i(10, 11, 4, 1), md)
	# Rumpf
	img.fill_rect(Rect2i(5, 11, 14, 9), mm)
	img.fill_rect(Rect2i(5, 11, 14, 1), ml)
	img.fill_rect(Rect2i(5, 11, 1, 9), ml)
	img.fill_rect(Rect2i(18, 11, 1, 9), md)
	img.fill_rect(Rect2i(5, 19, 14, 1), md)
	# Brustkern
	img.fill_rect(Rect2i(10, 13, 4, 4), core)
	img.fill_rect(Rect2i(11, 14, 2, 2), Color(1.0, 0.92, 0.66))
	# Schultern mit Akzentkappen
	img.fill_rect(Rect2i(3, 11, 3, 3), md); img.fill_rect(Rect2i(3, 11, 3, 1), acc)
	img.fill_rect(Rect2i(18, 11, 3, 3), md); img.fill_rect(Rect2i(18, 11, 3, 1), acc)
	# Linker Arm (Rückseite); beim Zielen greift er stützend zur Kanone
	if pose == "aim":
		img.fill_rect(Rect2i(3, 13, 3, 3), mm)
		img.fill_rect(Rect2i(5, 15, 12, 2), mm); img.fill_rect(Rect2i(5, 15, 12, 1), md)
	else:
		img.fill_rect(Rect2i(2, 13, 3, 6), mm); img.fill_rect(Rect2i(2, 13, 1, 6), md)
		img.fill_rect(Rect2i(2, 19, 3, 2), md)
	# Rechter Arm = Kanone (Front); beim Zielen ausgefahrener Lauf mit Mündung
	img.fill_rect(Rect2i(19, 12, 5, 3), md)
	if pose == "aim":
		img.fill_rect(Rect2i(19, 15, 8, 3), mm); img.fill_rect(Rect2i(19, 15, 8, 1), ml)
		img.fill_rect(Rect2i(25, 14, 2, 1), md)  # Mündungsbremse oben
		img.fill_rect(Rect2i(27, 15, 1, 3), jt)
		img.set_pixel(26, 16, eye); img.set_pixel(25, 16, eye)
	else:
		img.fill_rect(Rect2i(19, 15, 5, 3), mm); img.fill_rect(Rect2i(19, 15, 5, 1), ml)
		img.fill_rect(Rect2i(23, 16, 1, 2), jt)
		img.set_pixel(22, 16, eye)
	# Hüfte + Beine
	img.fill_rect(Rect2i(7, 20, 10, 2), md)
	match pose:
		"run":
			# Schwebe-Dash: Beine nach hinten angelegt, Düsenflamme darunter.
			img.fill_rect(Rect2i(5, 22, 4, 3), mm); img.fill_rect(Rect2i(3, 23, 3, 2), md)
			img.fill_rect(Rect2i(10, 22, 4, 3), mm); img.fill_rect(Rect2i(8, 24, 3, 2), md)
			var flame1 := Color(1.0, 0.78, 0.25); var flame2 := Color(1.0, 0.5, 0.15)
			if frame % 2 == 0:
				img.fill_rect(Rect2i(9, 25, 5, 2), flame1)
				img.fill_rect(Rect2i(7, 26, 3, 2), flame2)
			else:
				img.fill_rect(Rect2i(10, 25, 4, 2), flame2)
				img.fill_rect(Rect2i(8, 26, 2, 1), flame1)
		"aim":
			# Breiter Schützenstand: Beine gespreizt, Knie gebeugt.
			img.fill_rect(Rect2i(5, 22, 3, 3), mm); img.fill_rect(Rect2i(5, 22, 1, 3), md)
			img.fill_rect(Rect2i(3, 25, 5, 3), md)
			img.fill_rect(Rect2i(15, 22, 3, 3), mm); img.fill_rect(Rect2i(17, 22, 1, 3), md)
			img.fill_rect(Rect2i(15, 25, 5, 3), md)
		_:
			img.fill_rect(Rect2i(8, 22, 3, 5), mm); img.fill_rect(Rect2i(8, 22, 1, 5), md)
			img.fill_rect(Rect2i(13, 22, 3, 5), mm); img.fill_rect(Rect2i(15, 22, 1, 5), md)
			img.fill_rect(Rect2i(7, 26, 4, 2), md); img.fill_rect(Rect2i(13, 26, 4, 2), md)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## Richtige Rakete (blickt nach rechts, Drehung übernimmt die Flugbahn):
## Metallrumpf mit Lichtkante, roter Bugkegel, Leitwerk, Ring-Details;
## 2 Abgas-Frames — der große weiche Feuerschweif kommt zur Laufzeit
## als additives Kenney-Flammen-Sprite dazu.
static func rocket(frame: int) -> Texture2D:
	var key := "rocket_%d" % (frame % 2)
	if _cache.has(key):
		return _cache[key]
	var hull := Color(0.80, 0.82, 0.87); var lite := Color(0.95, 0.96, 1.0)
	var dark := Color(0.42, 0.45, 0.53); var joint := Color(0.25, 0.27, 0.33)
	var nose := Color(0.85, 0.22, 0.16); var nose_l := Color(1.0, 0.45, 0.35)
	var fin := Color(0.55, 0.58, 0.66)
	var img := _img(22, 10)
	# Rumpf (leicht spindelförmig): Mitte 4px hoch, Enden 2px
	img.fill_rect(Rect2i(5, 3, 11, 4), hull)
	img.fill_rect(Rect2i(5, 3, 11, 1), lite)      # Lichtkante oben
	img.fill_rect(Rect2i(5, 6, 11, 1), dark)      # Schattenkante unten
	# Bugkegel (zugespitzt)
	img.fill_rect(Rect2i(16, 3, 2, 4), nose)
	img.fill_rect(Rect2i(16, 3, 2, 1), nose_l)
	img.fill_rect(Rect2i(18, 4, 2, 2), nose)
	img.set_pixel(20, 4, nose); img.set_pixel(20, 5, nose)
	img.set_pixel(21, 4, nose_l)
	# Trennring + Bullauge
	img.fill_rect(Rect2i(15, 3, 1, 4), joint)
	img.set_pixel(12, 4, Color(0.45, 0.96, 1.0)); img.set_pixel(12, 5, Color(0.25, 0.6, 0.75))
	# Leitwerk hinten (oben/unten ausgestellt)
	img.fill_rect(Rect2i(4, 1, 3, 2), fin); img.set_pixel(4, 0, fin)
	img.fill_rect(Rect2i(4, 7, 3, 2), fin); img.set_pixel(4, 9, fin)
	img.fill_rect(Rect2i(5, 2, 2, 1), dark); img.fill_rect(Rect2i(5, 7, 2, 1), dark)
	# Heckplatte + Düse
	img.fill_rect(Rect2i(4, 3, 1, 4), joint)
	img.fill_rect(Rect2i(3, 4, 1, 2), joint)
	# Abgas-Kern direkt an der Düse (2 Frames, der weiche Rest ist Laufzeit-FX)
	if frame % 2 == 0:
		img.fill_rect(Rect2i(1, 4, 2, 2), Color(1.0, 0.85, 0.35))
		img.set_pixel(0, 4, Color(1.0, 0.55, 0.15)); img.set_pixel(0, 5, Color(1.0, 0.55, 0.15))
	else:
		img.fill_rect(Rect2i(1, 4, 2, 2), Color(1.0, 0.62, 0.2))
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## Unregelmäßiger Gesteinsbrocken für den Meteorregen: grauer Fels mit
## Poren, Lichtkante oben rechts und glühendem Saum unten links (Flugfront).
static func meteor_rock(variant: int) -> Texture2D:
	var key := "meteor_%d" % (variant % 4)
	if _cache.has(key):
		return _cache[key]
	var base := Color(0.42, 0.38, 0.35); var dark := Color(0.26, 0.23, 0.21)
	var lite := Color(0.58, 0.54, 0.50); var glow := Color(1.0, 0.55, 0.15)
	var w := 16; var hh := 13
	var img := _img(w, hh)
	var rs := RandomNumberGenerator.new()
	rs.seed = 991 + variant
	for y in hh:
		for x in w:
			var dx := (x - w * 0.5 + 0.5) / (w * 0.46)
			var dy := (y - hh * 0.5 + 0.5) / (hh * 0.46)
			var edge := dx * dx + dy * dy + rs.randf_range(-0.16, 0.16)
			if edge <= 1.0:
				var c := base
				if rs.randf() < 0.18:
					c = dark
				elif dx * 0.6 - dy * 0.8 > 0.35:
					c = lite  # Licht von oben rechts
				img.set_pixel(x, y, c)
	# Poren/Krater
	for i in 3 + variant % 2:
		var px := rs.randi_range(3, w - 4)
		var py := rs.randi_range(3, hh - 4)
		img.set_pixel(px, py, dark)
		img.set_pixel(px + 1, py, dark)
	# Glutsaum unten links (in Flugrichtung)
	for y in hh:
		for x in w:
			if img.get_pixel(x, y).a > 0:
				var lx := x - 1; var ly := y + 1
				var open_l := lx < 0 or img.get_pixel(lx, y).a == 0.0
				var open_b := ly >= hh or img.get_pixel(x, ly).a == 0.0
				if open_l or open_b:
					if (x + y * 2) % 3 != 0:
						img.set_pixel(x, y, glow)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## Fallende Fliegerbombe (Spitze unten), rot blinkendes Zünderlicht.
static func bomb(frame: int) -> Texture2D:
	var key := "bomb_%d" % (frame % 2)
	if _cache.has(key):
		return _cache[key]
	var body := Color(0.30, 0.33, 0.38); var lite := Color(0.48, 0.52, 0.58)
	var fin := Color(0.20, 0.22, 0.26); var warn := Color(0.95, 0.80, 0.20)
	var img := _img(10, 16)
	# Leitwerk oben
	img.fill_rect(Rect2i(1, 0, 2, 4), fin); img.fill_rect(Rect2i(7, 0, 2, 4), fin)
	img.fill_rect(Rect2i(4, 0, 2, 3), fin)
	# Korpus
	img.fill_rect(Rect2i(2, 3, 6, 9), body)
	img.fill_rect(Rect2i(2, 3, 1, 9), lite)
	img.fill_rect(Rect2i(3, 12, 4, 2), body)
	img.fill_rect(Rect2i(4, 14, 2, 2), body)  # Spitze
	# Warnstreifen + Zünderlicht
	img.fill_rect(Rect2i(2, 7, 6, 1), warn)
	var blink := Color(1.0, 0.25, 0.2) if frame % 2 == 0 else Color(0.45, 0.12, 0.1)
	img.set_pixel(5, 5, blink)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

static func robot_field(walking: bool, frame: int) -> Texture2D:
	var key := "robot_f_%d_%d" % [1 if walking else 0, frame % 4]
	if _cache.has(key):
		return _cache[key]
	var p := ROBOT_PAL
	var ml: Color = p["ml"]; var mm: Color = p["mm"]; var md: Color = p["md"]
	var jt: Color = p["jt"]; var eye: Color = p["eye"]
	var core := _robot_core(frame)
	var ant := Color(1.0, 0.38, 0.30) if frame % 2 == 0 else Color(0.5, 0.19, 0.16)
	var img := _img(16, 28)
	# Antenne
	img.set_pixel(7, 2, ant); img.fill_rect(Rect2i(7, 3, 1, 3), md)
	# Kopf
	img.fill_rect(Rect2i(5, 6, 7, 6), ml)
	img.fill_rect(Rect2i(5, 11, 7, 1), mm)
	img.fill_rect(Rect2i(8, 8, 3, 2), jt)
	var sx: int = 9 + [0, 1, 1, 0][frame % 4]
	img.set_pixel(sx, 8, eye)
	# Rumpf
	img.fill_rect(Rect2i(4, 12, 9, 7), mm)
	img.fill_rect(Rect2i(4, 12, 9, 1), ml)
	img.fill_rect(Rect2i(4, 12, 1, 7), ml)
	img.fill_rect(Rect2i(12, 12, 1, 7), md)
	img.fill_rect(Rect2i(7, 14, 3, 3), core)
	img.set_pixel(8, 15, Color(1.0, 0.92, 0.66))
	# Arme (rechts Kanone)
	img.fill_rect(Rect2i(2, 13, 2, 5), mm)
	img.fill_rect(Rect2i(13, 13, 3, 4), md); img.set_pixel(15, 14, jt)
	# Beine + Füße (beim Gehen abwechselnd angehoben)
	var lift_l := 2 if (walking and frame % 2 == 0) else 0
	var lift_r := 2 if (walking and frame % 2 == 1) else 0
	img.fill_rect(Rect2i(7, 19, 6, 1), md)
	img.fill_rect(Rect2i(5, 20 - lift_l, 3, 5), mm)
	img.fill_rect(Rect2i(9, 20 - lift_r, 3, 5), mm)
	img.fill_rect(Rect2i(4, 25 - lift_l, 4, 2), md)
	img.fill_rect(Rect2i(9, 25 - lift_r, 4, 2), md)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## ---------- Beschwörungen: Ifrit & Leviathan (prozedural) ----------
## Große Kino-Sprites für Milos Beschwörungen. Bewusst die größte Leinwand im
## Spiel (Ifrit 40x48), damit die Nearest-Skalierung im Kampf scharf bleibt.
## Der Leviathan ist modular (Kopf/Segment/Schwanz) — der Kampf setzt ihn zur
## Laufzeit entlang einer Kurve zusammen, so schlängelt er wirklich.
## Beide blicken nach rechts (im Kampf steht der Beschworene links der Gegner).

const IFRIT_PAL := {
	"body": Color(0.16, 0.10, 0.12), "body2": Color(0.26, 0.14, 0.15),
	"ember": Color(0.85, 0.25, 0.10), "org": Color(1.0, 0.55, 0.15),
	"hot": Color(1.0, 0.9, 0.45), "gold": Color(0.95, 0.78, 0.35),
}

static func ifrit(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "ifrit_%d" % f
	if _cache.has(key):
		return _cache[key]
	var p := IFRIT_PAL
	var body: Color = p["body"]; var body2: Color = p["body2"]
	var ember: Color = p["ember"]; var org: Color = p["org"]
	var hot: Color = p["hot"]; var gold: Color = p["gold"]
	var img := _img(40, 48)
	# Geschwungene Hörner, Spitzen glühen abwechselnd
	var tip := hot if f % 2 == 0 else org
	for i in 6:
		img.fill_rect(Rect2i(13 - i, 8 - i, 2, 2), body2)
		img.fill_rect(Rect2i(25 + i, 8 - i, 2, 2), body2)
	img.set_pixel(7, 2, tip); img.set_pixel(32, 2, tip)
	# Kopf mit Stirnwulst, weißglühenden Augen und Fangzähnen
	img.fill_rect(Rect2i(14, 7, 12, 8), body)
	img.fill_rect(Rect2i(14, 7, 12, 1), body2)
	img.fill_rect(Rect2i(19, 9, 2, 1), hot); img.fill_rect(Rect2i(23, 9, 2, 1), hot)
	img.set_pixel(20, 10, org); img.set_pixel(24, 10, org)
	img.fill_rect(Rect2i(18, 12, 7, 1), ember)
	img.set_pixel(19, 13, gold); img.set_pixel(22, 13, gold); img.set_pixel(24, 13, gold)
	# Flammenmähne: züngelt pro Frame anders (nur freie Pixel füllen)
	for x in range(12, 28):
		var hgt: int = 2 + ((x * 5 + f * 3) % 3)
		for y in range(7 - hgt, 7):
			if img.get_pixel(x, y).a < 0.01:
				img.set_pixel(x, y, hot if y <= 7 - hgt else (org if y < 5 else ember))
	# Schultern und Rumpf
	img.fill_rect(Rect2i(8, 15, 24, 4), body2)
	img.fill_rect(Rect2i(11, 19, 18, 13), body)
	img.fill_rect(Rect2i(12, 19, 16, 2), body2)
	# Pulsierende Glut-Risse in Brust und Bauch (2px hoch, damit sie leuchten)
	var crack: Color = org.lerp(hot, [1.0, 0.62, 0.3, 0.62][f])
	for c: Vector2i in [Vector2i(17, 21), Vector2i(18, 22), Vector2i(17, 23),
			Vector2i(18, 24), Vector2i(19, 25), Vector2i(23, 20), Vector2i(22, 21),
			Vector2i(23, 22), Vector2i(24, 23), Vector2i(20, 19)]:
		img.fill_rect(Rect2i(c.x, c.y, 1, 2), crack)
	img.fill_rect(Rect2i(19, 27, 3, 2), crack)
	img.set_pixel(20, 27, hot)
	# Arme mit Goldklauen: rechter (vorderer) greift nach vorn
	img.fill_rect(Rect2i(29, 16, 4, 7), body2)
	img.fill_rect(Rect2i(31, 21, 6, 5), body)
	img.fill_rect(Rect2i(31, 21, 6, 1), ember)
	img.set_pixel(37, 22, gold); img.set_pixel(37, 24, gold); img.set_pixel(36, 25, gold)
	img.fill_rect(Rect2i(6, 16, 4, 8), body)
	img.fill_rect(Rect2i(5, 23, 4, 3), body)
	img.set_pixel(4, 24, gold); img.set_pixel(4, 26, gold)
	# Unterkörper löst sich in hängende Flammenfetzen auf (schwebt)
	for x in range(12, 29):
		var dpt: int = 5 + ((x * 3 + f * 2) % 5) + (7 - absi(x - 20)) / 2
		for y in range(32, mini(32 + dpt, 47)):
			var t: float = float(y - 32) / float(dpt)
			var c := body2
			if t >= 0.85: c = hot
			elif t >= 0.6: c = org
			elif t >= 0.3: c = ember
			img.set_pixel(x, y, c)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

const LEV_PAL := {
	"deep": Color(0.06, 0.18, 0.30), "mid": Color(0.15, 0.45, 0.65),
	"light": Color(0.55, 0.85, 1.0), "belly": Color(0.85, 0.95, 1.0),
	"eye": Color(0.35, 1.0, 1.0),
}

static func leviathan_head(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "lev_head_%d" % f
	if _cache.has(key):
		return _cache[key]
	var p := LEV_PAL
	var deep: Color = p["deep"]; var mid: Color = p["mid"]
	var light: Color = p["light"]; var belly: Color = p["belly"]
	var img := _img(28, 22)
	var open := f >= 2  # Kiefer auf Frames 2/3 aufgerissen
	# Flossenkamm am Hinterkopf
	for i in 4:
		img.fill_rect(Rect2i(4 + i * 2, 5 - i % 2, 2, 3 + i % 2), light)
	# Schädel und zulaufende Schnauze
	img.fill_rect(Rect2i(3, 7, 17, 7), mid)
	img.fill_rect(Rect2i(3, 7, 17, 1), light)
	img.fill_rect(Rect2i(18, 8, 9, 4), mid)
	img.fill_rect(Rect2i(18, 8, 9, 1), light)
	# Glühendes Auge
	img.fill_rect(Rect2i(15, 9, 2, 2), p["eye"])
	img.set_pixel(16, 9, belly)
	# Oberkiefer-Zähne
	img.set_pixel(25, 12, belly); img.set_pixel(22, 12, belly); img.set_pixel(19, 12, belly)
	# Unterkiefer: geschlossen anliegend, offen nach unten geklappt
	if open:
		img.fill_rect(Rect2i(16, 15, 10, 3), deep)
		img.fill_rect(Rect2i(16, 15, 10, 1), mid)
		img.set_pixel(24, 14, belly); img.set_pixel(20, 14, belly)
	else:
		img.fill_rect(Rect2i(16, 13, 10, 3), deep)
	# Hals-Stummel (Anschluss an die Segmente) + Bauch
	img.fill_rect(Rect2i(0, 8, 4, 8), mid)
	img.fill_rect(Rect2i(0, 14, 12, 2), belly)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

static func leviathan_segment(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "lev_seg_%d" % f
	if _cache.has(key):
		return _cache[key]
	var p := LEV_PAL
	var img := _img(14, 14)
	# Rückenflosse schimmert (wandert leicht pro Frame)
	var fx: int = 5 + [0, 1, 1, 0][f]
	img.fill_rect(Rect2i(fx, 1, 2, 3), p["light"])
	img.set_pixel(fx + 1, 0, p["light"])
	# Körperring mit Licht oben, Bauchstreifen unten
	img.fill_rect(Rect2i(1, 4, 12, 7), p["mid"])
	img.fill_rect(Rect2i(1, 4, 12, 1), p["light"])
	img.fill_rect(Rect2i(1, 10, 12, 1), p["deep"])
	img.fill_rect(Rect2i(2, 8, 10, 2), p["belly"])
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

static func leviathan_tail(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "lev_tail_%d" % f
	if _cache.has(key):
		return _cache[key]
	var p := LEV_PAL
	var img := _img(16, 12)
	# Ansatz rechts (schließt an ein Segment an), läuft nach links spitz zu
	img.fill_rect(Rect2i(9, 3, 7, 6), p["mid"])
	img.fill_rect(Rect2i(9, 3, 7, 1), p["light"])
	img.fill_rect(Rect2i(10, 7, 6, 1), p["belly"])
	img.fill_rect(Rect2i(5, 4, 4, 4), p["mid"])
	# Gegabelte Schwanzflosse, Spitzen schimmern pro Frame
	var shine: Color = p["light"] if f % 2 == 0 else p["belly"]
	for i in 4:
		img.set_pixel(4 - i, 4 - i + 2, p["light"] if i < 3 else shine)
		img.set_pixel(4 - i, 6 + i, p["light"] if i < 3 else shine)
	img.set_pixel(0, 1, shine); img.set_pixel(0, 10, shine)
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## ---------- Gegner (String-Pixel-Art) ----------

const ENEMY_ART := {
	"slime": {
		"map": {"a": Color(0.36, 0.78, 0.42), "b": Color(0.20, 0.55, 0.28), "d": Color(0.12, 0.38, 0.20),
			"w": Color(0.92, 1.0, 0.94), "e": Color(0.06, 0.12, 0.07), "m": Color(0.10, 0.30, 0.14)},
		"rows": [
			"......aaaaaa......",
			"....aaaaaaaaaa....",
			"...aawwaaaaaaaa...",
			"..aawwwaaaaaaaaa..",
			"..aawwaaaaaaaaaa..",
			".aaaaaeaaaaeaaaaa.",
			".aaaaaeaaaaeaaaab.",
			".aaaaaaammaaaaaab.",
			"aaaaaaaaaaaaaaaabb",
			"aabbaaaaaaaaaabbaa",
			".abbbbaaaaaabbbba.",
			".abbbbbbbbbbbbbda.",
			"..adbbbbbbbbbbd...",
			"...ddddddddddd....",
		],
		"rows2": [
			"..................",
			"......aaaaaa......",
			"...aaaaaaaaaaaa...",
			"..aawwaaaaaaaaaa..",
			".aawwwaaaaaaaaaaa.",
			".aawwaaaaaaaaaaab.",
			"aaaaaeaaaaeaaaaaab",
			"aaaaaeaaaaeaaaaabb",
			"aaaaaaammmaaaaaabb",
			"aabbaaaaaaaaaabbaa",
			"aabbbbaaaaaabbbbaa",
			".abbbbbbbbbbbbbba.",
			".addbbbbbbbbbbdda.",
			"..dddddddddddddd..",
		]},
	"bat": {
		"map": {"a": Color(0.42, 0.30, 0.55), "b": Color(0.26, 0.17, 0.38), "d": Color(0.16, 0.10, 0.26),
			"f": Color(0.60, 0.45, 0.75), "e": Color(1.0, 0.30, 0.25), "t": Color(0.95, 0.95, 1.0), "n": Color(0.85, 0.45, 0.55)},
		"rows": [
			"......a....a......",
			"bb....aa..aa....bb",
			"dbb...anaana...bbd",
			"ddbb..afaafa..bbdd",
			"dbbbb.aeaaea.bbbbd",
			"bbabbbaaaaaabbbabb",
			".bbbbbaataaabbbbb.",
			"..dbbbaaaaaabbbd..",
			"...dbbaaffaabbd...",
			".....baa..aab.....",
			"......a....a......",
			"..................",
		],
		"rows2": [
			"......a....a......",
			"......aa..aa......",
			"......anaana......",
			".b....afaafa....b.",
			"..bb..aeaaea..bb..",
			"..bbb.aaaaaa.bbb..",
			"..dbbbaataaabbbd..",
			"...dbbaaaaaabbd...",
			"....dbaaffaabd....",
			".....baa..aab.....",
			"......a....a......",
			"..................",
		]},
	"frostwolf": {
		"map": {"a": Color(0.72, 0.83, 0.94), "b": Color(0.48, 0.62, 0.80), "d": Color(0.28, 0.40, 0.60),
			"w": Color(0.95, 0.99, 1.0), "e": Color(0.20, 0.95, 1.0), "i": Color(0.65, 0.95, 1.0),
			"n": Color(0.10, 0.15, 0.25), "t": Color(0.95, 0.99, 1.0)},
		"rows": [
			"............bb....",
			"....i..i...bbab...",
			".bb.bbbbbbb.baaab.",
			"bbbaaaaaaabbbaaaeb",
			".bbaaaaaaaaaaaaawn",
			".dbaaaaaaaaaaawtww",
			"..daaaaaaaaaab.ww.",
			"..dbaabbbbaab.....",
			"..dab..dab..bb....",
			"..dab..dab..bb....",
			"..dda..dda..bd....",
			"..................",
		],
		"rows2": [
			"...........bb.....",
			"...i..i....bbab...",
			".bb.bbbbbbb.baaab.",
			"bbbaaaaaaabbbaaaeb",
			".bbaaaaaaaaaaaaawn",
			".dbaaaaaaaaaaawtww",
			"..daaaaaaaaaab.ww.",
			"..dbaabbbbaab.....",
			".dab...dab...bb...",
			".dab...dab...bb...",
			".dda...dda...bd...",
			"..................",
		]},
	"eisgeist": {
		"map": {"a": Color(0.75, 0.87, 0.98, 0.88), "b": Color(0.50, 0.66, 0.88, 0.85), "d": Color(0.32, 0.46, 0.72, 0.80),
			"i": Color(0.85, 0.97, 1.0), "e": Color(0.25, 0.95, 1.0), "E": Color(0.95, 1.0, 1.0), "m": Color(0.22, 0.34, 0.58, 0.90)},
		"rows": [
			"..i..i..i..i....",
			"...iaaaaaai.....",
			"..aaaaaaaaaa....",
			".aaeeaaaaeea....",
			".aaeEaaaaeEa....",
			".aaaaaaaaaaaa...",
			"aaaaaammaaaaaa..",
			"aaaaaammaaaaaab.",
			".baaaaaaaaaaab..",
			".baaaaaaaaaab...",
			"..baaabaaaab....",
			"..ba.abba.ba....",
			"..b...bb...b....",
			"......ab........",
			"................",
		],
		"rows2": [
			".i..i..i..i.....",
			"...iaaaaaai.....",
			"..aaaaaaaaaa....",
			".aaeeaaaaeea....",
			".aaEeaaaaEea....",
			".aaaaaaaaaaaa...",
			"aaaaaammaaaaaa..",
			"aaaaaammaaaaaab.",
			".baaaaaaaaaaab..",
			".baaaaaaaaaab...",
			"..baaabaaaab....",
			"...ab.abba.ab...",
			"....b...bb..b...",
			"........ba......",
			"................",
		]},
	"skeleton": {
		"map": {"a": Color(0.90, 0.88, 0.80), "b": Color(0.65, 0.62, 0.54), "d": Color(0.20, 0.19, 0.16),
			"e": Color(0.90, 0.20, 0.15), "r": Color(0.55, 0.16, 0.16), "s": Color(0.75, 0.80, 0.88),
			"S": Color(0.50, 0.55, 0.65), "g": Color(0.85, 0.70, 0.30)},
		"rows": [
			"....aaaaaa..s.",
			"...aaaaaaaa.s.",
			"...aeaaaaea.s.",
			"...abababaa.s.",
			"....aaaaaa..s.",
			"...raaaaaar.s.",
			"..raabbbbaaggg",
			"..a.abbbba.aS.",
			"..a.abbbba.a..",
			"..b..aaaa..b..",
			".....abba.....",
			"....ab..ba....",
			"....ab..ba....",
			"....aa..aa....",
			"...ba....ab...",
			"..............",
		],
		"rows2": [
			"....aaaaaa..s.",
			"...aaaaaaaa.s.",
			"...aeaaaaea.s.",
			"...aaaaaaaa.s.",
			"....adddda..s.",
			"...raaaaaar.s.",
			"..raabbbbaaggg",
			"..a.abbbba.aS.",
			"..a.abbbba.a..",
			"..b..aaaa..b..",
			".....abba.....",
			"....ab..ba....",
			"....ba..ab....",
			"....aa..aa....",
			"...ab....ba...",
			"..............",
		]},
}

## Der Knochenkönig wird prozedural gezeichnet: 28x36, gehörnter Schädel mit
## glühenden Augen, Krone, Schulterpanzern, zerfetztem Umhang und Klauen.
static func _boss_img() -> Image:
	var img := _img(28, 36)
	var bone := Color(0.92, 0.90, 0.82)
	var bone2 := Color(0.66, 0.62, 0.54)
	var dark := Color(0.07, 0.05, 0.10)
	var gold := Color(0.95, 0.78, 0.20)
	var gold2 := Color(0.72, 0.56, 0.12)
	var cape := Color(0.38, 0.06, 0.11)
	var cape2 := Color(0.55, 0.11, 0.16)
	var horn := Color(0.30, 0.26, 0.34)
	var eye := Color(1.0, 0.15, 0.05)
	var eye2 := Color(1.0, 0.75, 0.25)
	# Umhang (hinter allem), unten zerfetzt
	img.fill_rect(Rect2i(3, 18, 22, 12), cape)
	for x in range(3, 25):
		var frays := (x * 7 + 3) % 5
		for i in frays:
			img.set_pixel(x, 30 + i, cape)
	# Schulterpanzer
	img.fill_rect(Rect2i(2, 17, 7, 3), cape2)
	img.fill_rect(Rect2i(19, 17, 7, 3), cape2)
	img.fill_rect(Rect2i(2, 16, 2, 1), cape2)
	img.fill_rect(Rect2i(24, 16, 2, 1), cape2)
	# Brustkorb mit Rippen und Wirbelsäule
	img.fill_rect(Rect2i(9, 20, 10, 7), dark)
	for ry in [20, 22, 24]:
		img.fill_rect(Rect2i(9, ry, 10, 1), bone)
	for sy in [21, 23, 25]:
		img.fill_rect(Rect2i(13, sy, 2, 1), bone2)
	# Arme mit Klauen
	img.fill_rect(Rect2i(6, 20, 2, 8), bone)
	img.fill_rect(Rect2i(20, 20, 2, 8), bone)
	img.set_pixel(6, 23, bone2)
	img.set_pixel(21, 23, bone2)
	img.fill_rect(Rect2i(5, 28, 4, 1), bone)
	img.fill_rect(Rect2i(19, 28, 4, 1), bone)
	for fx in [5, 7, 20, 22]:
		img.set_pixel(fx, 29, bone)
	# Gürtel mit glühendem Juwel
	img.fill_rect(Rect2i(9, 27, 10, 1), gold)
	img.fill_rect(Rect2i(13, 27, 2, 1), eye)
	# Beine und Füße
	img.fill_rect(Rect2i(10, 28, 2, 6), bone)
	img.fill_rect(Rect2i(16, 28, 2, 6), bone)
	img.set_pixel(10, 30, bone2)
	img.set_pixel(17, 30, bone2)
	img.fill_rect(Rect2i(9, 34, 4, 1), bone)
	img.fill_rect(Rect2i(16, 34, 4, 1), bone)
	# Hals + Schädel
	img.fill_rect(Rect2i(12, 17, 4, 1), bone2)
	img.fill_rect(Rect2i(7, 6, 14, 11), bone)
	img.fill_rect(Rect2i(19, 7, 1, 9), bone2)
	for p in [Vector2i(7, 6), Vector2i(20, 6), Vector2i(7, 16), Vector2i(20, 16)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	# Maul: grimmige Linie + Zahnreihe
	img.fill_rect(Rect2i(8, 14, 12, 1), dark)
	for tx in range(8, 20, 2):
		img.set_pixel(tx, 15, dark)
	# Nasenhöhle
	img.fill_rect(Rect2i(13, 12, 2, 2), dark)
	# Augenhöhlen mit Glut-Pupillen
	img.fill_rect(Rect2i(9, 9, 4, 3), dark)
	img.fill_rect(Rect2i(15, 9, 4, 3), dark)
	img.fill_rect(Rect2i(10, 10, 2, 1), eye)
	img.fill_rect(Rect2i(16, 10, 2, 1), eye)
	img.set_pixel(11, 10, eye2)
	img.set_pixel(17, 10, eye2)
	# Krone
	img.fill_rect(Rect2i(8, 4, 12, 1), gold)
	img.fill_rect(Rect2i(8, 5, 12, 1), gold2)
	for sx in [8, 13, 18]:
		img.fill_rect(Rect2i(sx, 2, 2, 2), gold)
	# Geschwungene Hörner, an den Schädel angebunden
	for i in 7:
		var hx := 6 - i / 2
		var hy := 6 - i
		img.set_pixel(hx, hy, horn)
		img.set_pixel(hx + 1, hy, horn)
		img.set_pixel(27 - hx, hy, horn)
		img.set_pixel(26 - hx, hy, horn)
		if i < 2:
			img.set_pixel(hx + 2, hy, horn)
			img.set_pixel(25 - hx, hy, horn)
	return img

## Der Frostkoloss: 30x38, massiger Eisgolem mit Kristallschultern,
## glühendem Frostkern in der Brust und eisblauen Glutaugen.
static func _boss2_img() -> Image:
	var img := _img(30, 38)
	var ice := Color(0.82, 0.91, 0.98)
	var ice2 := Color(0.55, 0.74, 0.92)
	var ice3 := Color(0.32, 0.52, 0.76)
	var deep := Color(0.12, 0.24, 0.44)
	var glow := Color(0.25, 0.95, 1.0)
	var white := Color(0.96, 1.0, 1.0)
	# Massige Schultern (breiter als der Kopf)
	img.fill_rect(Rect2i(6, 9, 18, 1), ice)
	img.fill_rect(Rect2i(4, 10, 22, 1), ice2)
	img.fill_rect(Rect2i(2, 11, 26, 3), ice2)
	img.fill_rect(Rect2i(2, 13, 26, 1), ice3)
	# Kristall-Spitzen auf den Schultern
	for sx in [3, 25]:
		img.fill_rect(Rect2i(sx, 7, 3, 2), ice)
		img.fill_rect(Rect2i(sx + 1, 5, 1, 2), ice)
		img.set_pixel(sx + 1, 4, white)
	# Arme mit klobigen Fäusten
	img.fill_rect(Rect2i(3, 14, 5, 11), ice2)
	img.fill_rect(Rect2i(22, 14, 5, 11), ice2)
	img.fill_rect(Rect2i(3, 14, 1, 11), ice3)
	img.fill_rect(Rect2i(26, 14, 1, 11), ice3)
	img.fill_rect(Rect2i(2, 25, 7, 4), ice3)
	img.fill_rect(Rect2i(21, 25, 7, 4), ice3)
	for kx in [3, 5, 7, 22, 24, 26]:
		img.set_pixel(kx, 24, white)
	# Rumpf mit Panzerplatten und Rissen
	img.fill_rect(Rect2i(9, 14, 12, 12), ice3)
	img.fill_rect(Rect2i(10, 15, 10, 2), ice2)
	img.fill_rect(Rect2i(10, 22, 10, 2), ice2)
	for cp in [Vector2i(11, 19), Vector2i(18, 20), Vector2i(12, 24), Vector2i(19, 15)]:
		img.set_pixel(cp.x, cp.y, deep)
	# Glühender Frostkern in der Brust
	img.fill_rect(Rect2i(13, 17, 4, 4), glow)
	img.fill_rect(Rect2i(14, 18, 2, 2), white)
	for gp in [Vector2i(12, 18), Vector2i(17, 19), Vector2i(14, 16), Vector2i(15, 21)]:
		img.set_pixel(gp.x, gp.y, glow)
	# Hüfte + stämmige Beine mit Fußplatten
	img.fill_rect(Rect2i(11, 26, 8, 2), deep)
	img.fill_rect(Rect2i(10, 28, 4, 7), ice2)
	img.fill_rect(Rect2i(16, 28, 4, 7), ice2)
	img.fill_rect(Rect2i(10, 28, 1, 7), ice3)
	img.fill_rect(Rect2i(19, 28, 1, 7), ice3)
	img.fill_rect(Rect2i(8, 35, 6, 2), ice3)
	img.fill_rect(Rect2i(16, 35, 6, 2), ice3)
	# Kopf: Eisblock mit Glutaugen und Kristallkrone
	img.fill_rect(Rect2i(11, 3, 8, 7), ice2)
	img.fill_rect(Rect2i(11, 3, 8, 1), ice)
	img.fill_rect(Rect2i(12, 5, 2, 2), deep)
	img.fill_rect(Rect2i(16, 5, 2, 2), deep)
	img.set_pixel(12, 5, glow)
	img.set_pixel(16, 5, glow)
	img.set_pixel(13, 6, glow)
	img.set_pixel(17, 6, glow)
	# Grimmiger Mund
	img.fill_rect(Rect2i(13, 8, 4, 1), deep)
	# Kristallzacken auf dem Kopf
	for hx in [11, 14, 17]:
		img.fill_rect(Rect2i(hx, 1, 2, 2), ice)
		img.set_pixel(hx, 0, white)
	return img

## Gegner-Sprites kommen aus dem CC0-Pack (4 animierte Frames pro Monster).
const ENEMY_FRAMES := 4

static func enemy(id: String) -> Texture2D:
	return enemy_frame(id, 0)

## Alle DTII-Monster haben eine Lauf-/Idle-Animation.
static func enemy_has_anim(id: String) -> bool:
	return MON_DTII.has(id)

static func enemy_frame(id: String, frame: int) -> Texture2D:
	var def: Dictionary = MON_DTII.get(id, MON_DTII["schlammschleim"])
	return dtii("%s_f%d" % [def["anim"], frame % ENEMY_FRAMES])

## Ist dieser Gegner ein großes Boss-Sprite (32x36 statt 16x16)?
static func enemy_is_big(id: String) -> bool:
	return MON_DTII.has(id) and MON_DTII[id]["big"]

## ---------- Effekt-Texturen ----------

static func circle(radius: int, color: Color) -> Texture2D:
	var key := "circle_%d_%s" % [radius, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var s := radius * 2
	var img := _img(s, s)
	for y in s:
		for x in s:
			var d := Vector2(x - radius + 0.5, y - radius + 0.5).length()
			if d < radius:
				var c := color
				c.a *= clamp(1.0 - d / radius, 0.0, 1.0)
				img.set_pixel(x, y, c)
	var t := _tex(img)
	_cache[key] = t
	return t

## Weicher Bodenschatten (Ellipse) — gibt Kämpfern optische Tiefe.
static func shadow(rx: int, ry: int) -> Texture2D:
	var key := "shadow_%d_%d" % [rx, ry]
	if _cache.has(key):
		return _cache[key]
	var img := _img(rx * 2, ry * 2)
	for y in ry * 2:
		for x in rx * 2:
			var d := Vector2((x - rx + 0.5) / rx, (y - ry + 0.5) / ry).length()
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.4 * (1.0 - d * d)))
	var t := _tex(img)
	_cache[key] = t
	return t

## Vertikaler Farbverlauf für stimmungsvolle Hintergründe.
static func gradient(w: int, h: int, top: Color, bottom: Color) -> Texture2D:
	var key := "grad_%d_%d_%s_%s" % [w, h, top.to_html(), bottom.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := _img(w, h)
	for y in h:
		var c := top.lerp(bottom, float(y) / (h - 1))
		for x in w:
			img.set_pixel(x, y, c)
	var t := _tex(img)
	_cache[key] = t
	return t

## Vignette: dunkler Rand, transparente Mitte — moderner Kino-Look.
static func vignette(w: int, h: int, strength := 0.55) -> Texture2D:
	var key := "vig_%d_%d_%.2f" % [w, h, strength]
	if _cache.has(key):
		return _cache[key]
	var img := _img(w, h)
	var center := Vector2(w / 2.0, h / 2.0)
	for y in h:
		for x in w:
			var d := (Vector2(x, y) - center).length() / (center.length())
			var a: float = clampf((d - 0.55) / 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * strength))
	var t := _tex(img)
	_cache[key] = t
	return t

## Geisterschädel für die „Armee der Verdammten“ des Knochenkönigs.
static func skull() -> Texture2D:
	if _cache.has("skull"):
		return _cache["skull"]
	var img := _img(12, 12)
	var bone_c := Color(0.92, 0.90, 0.98)
	var dark := Color(0.18, 0.06, 0.28)
	img.fill_rect(Rect2i(1, 1, 10, 7), bone_c)
	for p in [Vector2i(1, 1), Vector2i(10, 1), Vector2i(1, 7), Vector2i(10, 7)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	# Glühende Augenhöhlen + Nasenloch
	img.fill_rect(Rect2i(3, 3, 2, 2), dark)
	img.fill_rect(Rect2i(7, 3, 2, 2), dark)
	img.set_pixel(3, 3, Color(1.0, 0.3, 0.2))
	img.set_pixel(7, 3, Color(1.0, 0.3, 0.2))
	img.fill_rect(Rect2i(5, 5, 2, 1), dark)
	# Kiefer mit Zahnlücken
	img.fill_rect(Rect2i(3, 8, 6, 3), bone_c)
	for tx in [4, 6, 8]:
		img.set_pixel(tx, 9, dark)
	var t := _tex(img)
	_cache["skull"] = t
	return t

## Spitzer Eissplitter für den Eissturm des Frostkolosses.
static func shard() -> Texture2D:
	if _cache.has("shard"):
		return _cache["shard"]
	var img := _img(7, 12)
	var widths := [1, 2, 3, 3, 3, 3, 2, 2, 2, 1, 1, 1]
	for y in 12:
		var w: int = widths[y]
		var x0 := 3 - w / 2
		for x in w:
			img.set_pixel(x0 + x, y, Color(0.75, 0.90, 1.0) if x == 0 else Color(0.50, 0.72, 0.95))
	img.set_pixel(3, 0, Color(0.96, 1.0, 1.0))
	var t := _tex(img)
	_cache["shard"] = t
	return t

## Kleiner Knochen für den Knochensturm des Bosses.
static func bone() -> Texture2D:
	if _cache.has("bone"):
		return _cache["bone"]
	var img := _img(10, 4)
	var c := Color(0.92, 0.90, 0.82)
	img.fill_rect(Rect2i(1, 1, 8, 2), c)
	for p in [Vector2i(0, 0), Vector2i(0, 3), Vector2i(9, 0), Vector2i(9, 3)]:
		img.set_pixel(p.x, p.y, c)
	var t := _tex(img)
	_cache["bone"] = t
	return t

## ---------- Feld-Dekoration (HD-2D-Detailschicht) ----------

# Kleine Requisiten als Row-Art: Wandfackel, Eiskristall, Leuchtpilz.
const PROP_ART := {
	"torch": {
		"map": {"y": Color(1.0, 0.95, 0.55), "o": Color(1.0, 0.62, 0.15),
			"r": Color(0.85, 0.30, 0.08), "m": Color(0.30, 0.28, 0.32),
			"h": Color(0.42, 0.28, 0.14), "H": Color(0.30, 0.20, 0.10)},
		"rows": [
			"..yy..",
			".yyoy.",
			".yooo.",
			".ooro.",
			"..rr..",
			".mmmm.",
			"..hH..",
			"..hH..",
			"..hH..",
			"..hH..",
			".mmmm.",
			"......",
		]},
	"crystal": {
		"map": {"w": Color(0.92, 1.0, 1.0), "c": Color(0.55, 0.88, 1.0),
			"b": Color(0.25, 0.50, 0.85), "d": Color(0.15, 0.30, 0.60)},
		"rows": [
			"....w....",
			"...cw..c.",
			"...cc..cw",
			"..wccc.cc",
			"..cccc.cc",
			".ccwcccbc",
			".ccccbcbc",
			"ccbccbbc.",
			"cbbcbbbc.",
			".bbdbbd..",
			"..dbbd...",
			".........",
		]},
	"mushroom": {
		"map": {"v": Color(0.72, 0.45, 0.95), "l": Color(0.90, 0.75, 1.0),
			"d": Color(0.48, 0.25, 0.70), "s": Color(0.80, 0.78, 0.72)},
		"rows": [
			"..lvv..",
			".vvlvv.",
			".vdvvd.",
			"..ss...",
			"..ss.v.",
			"....lv.",
			"....s..",
		]},
}

## Requisiten-Sprite; flower0..flower3, tuft, pebble, crack, bones
## werden direkt gezeichnet, der Rest kommt aus PROP_ART.
static func prop(kind: String) -> Texture2D:
	if DTII_PROPS.has(kind):
		return dtii(DTII_PROPS[kind])
	var key := "prop_" + kind
	if _cache.has(key):
		return _cache[key]
	var img: Image
	if kind == "barrel":
		# Giftfass: grüner Blechkörper, rostige Ringe, blubbernder Überlauf
		img = _img(8, 10)
		img.fill_rect(Rect2i(1, 1, 6, 9), Color(0.28, 0.48, 0.24))
		img.fill_rect(Rect2i(1, 3, 6, 1), Color(0.42, 0.32, 0.18))
		img.fill_rect(Rect2i(1, 7, 6, 1), Color(0.42, 0.32, 0.18))
		img.fill_rect(Rect2i(2, 0, 4, 1), Color(0.55, 0.85, 0.30))
		img.set_pixel(1, 0, Color(0.55, 0.85, 0.30))
		img.set_pixel(2, 2, Color(0.38, 0.60, 0.30))
		img.set_pixel(2, 5, Color(0.38, 0.60, 0.30))
	elif kind == "coins":
		# Kleiner Münzhaufen
		img = _img(8, 5)
		var g1 := Color(1.0, 0.84, 0.30)
		var g2 := Color(0.80, 0.62, 0.16)
		img.fill_rect(Rect2i(1, 3, 6, 2), g2)
		img.fill_rect(Rect2i(2, 2, 4, 2), g1)
		img.set_pixel(3, 1, g1)
		img.set_pixel(4, 1, Color(1.0, 0.95, 0.65))
	elif kind == "sludge":
		# Giftschlamm-Pfütze
		img = _img(10, 5)
		var s1 := Color(0.30, 0.55, 0.20, 0.85)
		var s2 := Color(0.45, 0.75, 0.25, 0.85)
		img.fill_rect(Rect2i(1, 1, 8, 3), s1)
		img.set_pixel(0, 2, s1)
		img.set_pixel(9, 2, s1)
		img.set_pixel(3, 1, s2)
		img.set_pixel(6, 2, s2)
		img.set_pixel(4, 3, s2)
	elif PROP_ART.has(kind):
		var art: Dictionary = PROP_ART[kind]
		var rows: Array = art["rows"]
		img = _img(rows[0].length(), rows.size())
		for y in rows.size():
			for x in (rows[y] as String).length():
				var ch: String = rows[y][x]
				if art["map"].has(ch):
					img.set_pixel(x, y, art["map"][ch])
	elif kind.begins_with("flower"):
		img = _img(5, 6)
		var petal: Color = [Color(0.95, 0.92, 0.98), Color(0.90, 0.30, 0.35),
			Color(0.45, 0.55, 0.95), Color(0.95, 0.55, 0.75)][int(kind.substr(6)) % 4]
		img.set_pixel(2, 4, Color(0.20, 0.45, 0.20))
		img.set_pixel(2, 5, Color(0.20, 0.45, 0.20))
		for p: Vector2i in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 2)]:
			img.set_pixel(p.x, p.y, petal)
		img.set_pixel(2, 1, Color(0.98, 0.85, 0.30))
	elif kind == "tuft":
		img = _img(6, 5)
		var g1 := Color(0.36, 0.66, 0.30)
		var g2 := Color(0.24, 0.50, 0.22)
		for p: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(3, 0), Vector2i(3, 1),
				Vector2i(3, 2), Vector2i(5, 1), Vector2i(5, 2)]:
			img.set_pixel(p.x, p.y, g1)
		for p: Vector2i in [Vector2i(0, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(1, 4), Vector2i(3, 4)]:
			img.set_pixel(p.x, p.y, g2)
	elif kind == "pebble":
		img = _img(6, 4)
		img.fill_rect(Rect2i(1, 1, 3, 2), Color(0.50, 0.47, 0.52))
		img.set_pixel(2, 0, Color(0.60, 0.57, 0.62))
		img.fill_rect(Rect2i(4, 2, 2, 2), Color(0.42, 0.39, 0.45))
	elif kind == "crack":
		img = _img(9, 6)
		var dk := Color(0.10, 0.09, 0.14)
		for p: Vector2i in [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 3),
				Vector2i(4, 3), Vector2i(5, 2), Vector2i(5, 4), Vector2i(6, 4),
				Vector2i(7, 5), Vector2i(6, 1), Vector2i(8, 5)]:
			img.set_pixel(p.x, p.y, dk)
	elif kind == "bones":
		img = _img(8, 5)
		var bc := Color(0.88, 0.86, 0.78)
		var bd := Color(0.66, 0.63, 0.55)
		for p: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(0, 0), Vector2i(4, 0)]:
			img.set_pixel(p.x, p.y, bc)
		for p: Vector2i in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
				Vector2i(6, 2), Vector2i(6, 4)]:
			img.set_pixel(p.x, p.y, bd)
	elif kind == "icecrack":
		img = _img(9, 6)
		var ic := Color(0.85, 0.95, 1.0, 0.85)
		for p: Vector2i in [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 3),
				Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 3), Vector2i(4, 4), Vector2i(7, 4)]:
			img.set_pixel(p.x, p.y, ic)
	else:
		img = _img(2, 2, Color.MAGENTA)
	var t := _tex(img)
	_cache[key] = t
	return t
