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
		"ice":
			if (x * 2 + y) % 11 == 0: return Color(0.44, 0.62, 0.82)
			var ci := Color(0.62, 0.80, 0.94)
			if n > 0.85: ci = Color(0.74, 0.89, 0.99)
			elif n < 0.08: ci = Color(0.50, 0.68, 0.86)
			return ci
		"iwall":
			if y % 4 == 0 or (x + (y / 4) * 2) % 6 == 0: return Color(0.12, 0.20, 0.36)
			return Color(0.22, 0.34, 0.55) if n > 0.2 else Color(0.18, 0.29, 0.48)
		"icecave":
			var d3 := Vector2(x - 7.5, y - 9.0).length()
			if d3 < 4.5: return Color(0.04, 0.08, 0.16)
			var ridge2 := absf(float(x) - 8.0) + float(15 - y) * 0.8
			if ridge2 < 6.0: return Color(0.60, 0.72, 0.86) if n > 0.3 else Color(0.68, 0.80, 0.92)
			return Color(0.45, 0.54, 0.68)
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
	"frostwolf": {
		"map": {"a": Color(0.68, 0.80, 0.93), "b": Color(0.36, 0.50, 0.70), "e": Color(0.25, 0.95, 1.0), "w": Color(0.92, 0.97, 1.0)},
		"rows": [
			"...........bb...",
			".b........bab...",
			".bb......baaab..",
			".babbbbbaaaaaeb.",
			"..baaaaaaaaaaab.",
			"..baaaaaaaaawww.",
			"...baaaaaaaab...",
			"...bab..baab....",
			"...ba....ba.....",
			"...b.....b......",
		]},
	"eisgeist": {
		"map": {"a": Color(0.72, 0.85, 0.98, 0.85), "b": Color(0.45, 0.62, 0.85, 0.85), "e": Color(0.20, 0.90, 1.0)},
		"rows": [
			"....aaaaaa....",
			"..aaaaaaaaaa..",
			".aaaeaaaaeaaa.",
			".aaaeaaaaeaaa.",
			".aaaaaaaaaaaa.",
			"aaaaabaabaaaaa",
			"aaaaaabbaaaaaa",
			".aaaaaaaaaaaa.",
			".aabaaaaaabaa.",
			"..aa.aaaa.aa..",
			"..a...aa...a..",
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

static func enemy(id: String) -> Texture2D:
	var key := "enemy_" + id
	if _cache.has(key):
		return _cache[key]
	if id == "boss":
		var bt := _tex(_boss_img())
		_cache[key] = bt
		return bt
	if id == "boss2":
		var bt2 := _tex(_boss2_img())
		_cache[key] = bt2
		return bt2
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
	var key := "vig_%d_%d" % [w, h]
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
