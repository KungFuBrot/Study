class_name SpriteFactory
## Erzeugt alle Texturen zur Laufzeit (Pixel-Art, 16px-Raster) — keine Assets nötig.

static var _cache := {}

const TILE := 16

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

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
		"cave":
			var d2 := Vector2(x - 7.5, y - 9.0).length()
			if d2 < 4.5: return Color(0.05, 0.04, 0.08)
			return _tile_color("mount", x, y)
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
	"serena": {"hair": Color(0.85, 0.65, 0.25), "body": Color(0.72, 0.18, 0.22), "trim": Color(0.90, 0.80, 0.60), "skin": Color(0.95, 0.80, 0.66)},
	"milo": {"hair": Color(0.35, 0.30, 0.55), "body": Color(0.20, 0.30, 0.70), "trim": Color(0.75, 0.75, 0.95), "skin": Color(0.93, 0.78, 0.64)},
	"npc_elder": {"hair": Color(0.85, 0.85, 0.85), "body": Color(0.45, 0.40, 0.30), "trim": Color(0.70, 0.65, 0.50), "skin": Color(0.90, 0.75, 0.62)},
	"npc_kid": {"hair": Color(0.40, 0.25, 0.12), "body": Color(0.25, 0.55, 0.35), "trim": Color(0.85, 0.85, 0.60), "skin": Color(0.95, 0.80, 0.66)},
	"npc_shop": {"hair": Color(0.55, 0.20, 0.35), "body": Color(0.60, 0.45, 0.20), "trim": Color(0.95, 0.90, 0.70), "skin": Color(0.94, 0.79, 0.65)},
}

static func character(id: String, dir: String, frame: int) -> Texture2D:
	var key := "chr_%s_%s_%d" % [id, dir, frame]
	if _cache.has(key):
		return _cache[key]
	var p: Dictionary = HERO_PALETTES.get(id, HERO_PALETTES["npc_kid"])
	var img := _img(12, 16)
	var hair: Color = p["hair"]
	var body: Color = p["body"]
	var trim: Color = p["trim"]
	var skin: Color = p["skin"]
	var dark := Color(0.1, 0.1, 0.12)
	# Kopf
	img.fill_rect(Rect2i(3, 2, 6, 5), skin)
	# Haare je Blickrichtung
	img.fill_rect(Rect2i(2, 1, 8, 2), hair)
	if dir == "up":
		img.fill_rect(Rect2i(3, 3, 6, 3), hair)
	elif dir == "side":
		img.fill_rect(Rect2i(2, 2, 3, 3), hair)
		img.set_pixel(7, 4, dark)  # ein Auge seitlich
	else:
		img.set_pixel(4, 4, dark)
		img.set_pixel(7, 4, dark)
	# Körper
	img.fill_rect(Rect2i(3, 7, 6, 5), body)
	img.fill_rect(Rect2i(3, 7, 6, 1), trim)
	# Arme
	img.fill_rect(Rect2i(2, 8, 1, 3), body)
	img.fill_rect(Rect2i(9, 8, 1, 3), body)
	# Beine mit Laufanimation
	var off := 1 if frame == 1 else 0
	img.fill_rect(Rect2i(4, 12 + off, 2, 3 - off), dark)
	img.fill_rect(Rect2i(6, 12 + (1 - off), 2, 3 - (1 - off)), dark)
	var t := _tex(img)
	_cache[key] = t
	return t

## ---------- Gegner (String-Pixel-Art) ----------

const ENEMY_ART := {
	"slime": {
		"map": {"a": Color(0.30, 0.75, 0.40), "b": Color(0.18, 0.55, 0.28), "e": Color(0.05, 0.10, 0.06), "w": Color(0.85, 0.98, 0.88)},
		"rows": [
			"......aaaa......",
			"....aaaaaaaa....",
			"...aaaaaaaaaa...",
			"..aawaaaaaawaa..",
			"..aaeaaaaaaeaa..",
			".aaaaaaaaaaaaaa.",
			".aaaaabbbbaaaaa.",
			"aaaaaaaaaaaaaaaa",
			"abaaaaaaaaaaaaba",
			"abbaaaaaaaaaabba",
			".abbbbbbbbbbbba.",
			"..abbbbbbbbbba..",
		]},
	"bat": {
		"map": {"a": Color(0.35, 0.25, 0.45), "b": Color(0.22, 0.15, 0.30), "e": Color(0.95, 0.25, 0.25), "f": Color(0.55, 0.40, 0.65)},
		"rows": [
			"b..............b",
			"bb....a..a....bb",
			"bbb..aaaaaa..bbb",
			"bbbb.aeaaea.bbbb",
			"bbbbbaaaaaabbbbb",
			"fbbbbaaaaaabbbbf",
			".fbbbaafaabbbbf.",
			"..fbbaaaaaabbf..",
			"...f.aa..aa.f...",
			".....a....a.....",
		]},
	"skeleton": {
		"map": {"a": Color(0.88, 0.86, 0.78), "b": Color(0.60, 0.58, 0.50), "e": Color(0.05, 0.05, 0.08), "r": Color(0.55, 0.15, 0.15)},
		"rows": [
			"...aaaaaa...",
			"..aaaaaaaa..",
			"..aeaaaaea..",
			"..aaaaaaaa..",
			"...abbbba...",
			"....aaaa....",
			"..raaaaaar..",
			".raabaabaar.",
			".a.abaaba.a.",
			".a.aaaaaa.a.",
			"...abaaba...",
			"...abaaba...",
			"...aa..aa...",
			"..ba....ab..",
			"..a......a..",
			".aa......aa.",
		]},
	"boss": {
		"map": {"a": Color(0.88, 0.86, 0.78), "d": Color(0.10, 0.09, 0.12), "e": Color(1.0, 0.20, 0.15),
			"g": Color(0.95, 0.78, 0.20), "c": Color(0.45, 0.10, 0.15)},
		"rows": [
			".....g..g..g..g.....",
			".....gggggggggg.....",
			"....aaaaaaaaaaaa....",
			"....aaaaaaaaaaaa....",
			"....aaeeaaaaeeaa....",
			"....aaeeaaaaeeaa....",
			"....aaaaaddaaaaa....",
			"....adadadadadaa....",
			".....aaaaaaaaaa.....",
			"..ccaaaaaaaaaaaacc..",
			".ccaadadadadadaaacc.",
			".ccaaaaaaaaaaaaaacc.",
			".cc.aadadadadaa..cc.",
			".cc..aaaaaaaaaa..cc.",
			".....aadaadaa.......",
			".....aaa..aaa.......",
			".....aa....aa.......",
			"....aaa....aaa......",
		]},
}

static func enemy(id: String) -> Texture2D:
	var key := "enemy_" + id
	if _cache.has(key):
		return _cache[key]
	var art: Dictionary = ENEMY_ART[id]
	var rows: Array = art["rows"]
	var w: int = rows[0].length()
	var img := _img(w, rows.size())
	for y in rows.size():
		for x in w:
			var ch: String = rows[y][x]
			if art["map"].has(ch):
				img.set_pixel(x, y, art["map"][ch])
	var t := _tex(img)
	_cache[key] = t
	return t

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
