class_name SpriteFactory
extends SpriteFactoryChars
## Oeffentliche Fassade (alle Aufrufe laufen ueber SpriteFactory.*):
## Beschwoerungen, Gegner/Bosse, Requisiten und kleine Hilfstexturen.
## Teil der SpriteFactory-Kette: SpriteFactoryLib > SpriteFactoryChars > SpriteFactory.

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

## Bahamut, Janoschs stärkste Beschwörung (3. Bosssieg): der Drachenkönig
## schwebt über dem Gegnerfeld und speit die „Megaflare" nach UNTEN. Darum
## blickt er zum Betrachter herab — Kopf/Maul zeigen nach unten (Strahl-
## Ursprung), die Schwingen spannen nach oben-außen und schlagen pro Frame.
const BAHA_PAL := {
	"dark": Color(0.18, 0.14, 0.10), "mid": Color(0.32, 0.24, 0.14),
	"lite": Color(0.60, 0.44, 0.22), "memb": Color(0.26, 0.13, 0.11),
	"memb2": Color(0.46, 0.25, 0.15), "bone": Color(0.86, 0.80, 0.58),
	"hot": Color(1.0, 0.86, 0.42), "ember": Color(1.0, 0.5, 0.16),
}

static func bahamut(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "bahamut_%d" % f
	if _cache.has(key):
		return _cache[key]
	var p := BAHA_PAL
	var dark: Color = p["dark"]; var mid: Color = p["mid"]; var lite: Color = p["lite"]
	var memb: Color = p["memb"]; var memb2: Color = p["memb2"]; var bone: Color = p["bone"]
	var hot: Color = p["hot"]; var ember: Color = p["ember"]
	var img := _img(52, 48)
	var cx := 26
	var flap: int = [0, -4, -6, -3][f]  # Flügelspitzen heben und senken sich
	# --- Schwingen (hinter dem Körper, symmetrisch gefüllt) ---
	for side: int in [-1, 1]:
		var sx := cx + side * 5       # Schulteransatz
		var span := 25               # Spannweite nach außen
		for step in range(span + 1):
			var t := float(step) / float(span)
			var x := sx + side * step
			if x < 0 or x > 51:
				continue
			# Vorderkante hebt sich nach außen (verstärkt durch den Flügelschlag)
			var top_y := int(round(lerp(16.0, 8.0 + flap, t)))
			# Hinterkante fällt ab und ist leicht gezackt (Drachenmembran)
			var scallop := int(round(2.0 * absf(sin(t * 9.0))))
			var bot_y := int(round(lerp(18.0, 25.0, t))) - scallop
			for y in range(top_y, bot_y + 1):
				if y < 0 or y > 47:
					continue
				img.set_pixel(x, y, memb2 if y - top_y <= 1 else memb)
			# Knochenspeiche entlang der Vorderkante
			if top_y >= 0 and top_y <= 47:
				img.set_pixel(x, top_y, bone if t > 0.55 else lite)
	# --- Schwanz ragt zwischen den Schwingen nach oben ---
	for i in range(11):
		var tw: int = maxi(1, 3 - i / 4)
		img.fill_rect(Rect2i(cx - tw, 13 - i, tw * 2, 1), mid if i % 2 == 0 else dark)
	# --- Rumpf/Hals (senkrecht, Kopf unten) ---
	img.fill_rect(Rect2i(cx - 5, 14, 10, 18), mid)
	img.fill_rect(Rect2i(cx - 4, 14, 8, 18), dark)
	for y in range(16, 31, 3):  # Brust-Panzerplatten schimmern
		img.fill_rect(Rect2i(cx - 3, y, 6, 1), lite)
	img.fill_rect(Rect2i(cx - 2, 21, 4, 4), ember)  # glühender Brustkern
	img.set_pixel(cx, 22, hot); img.set_pixel(cx - 1, 23, hot)
	# --- Kopf (unten, dem Gegnerfeld zugewandt) ---
	img.fill_rect(Rect2i(cx - 6, 30, 12, 8), dark)
	img.fill_rect(Rect2i(cx - 6, 30, 12, 2), mid)
	for i in range(7):  # Hörner nach oben-hinten
		img.set_pixel(cx - 5 - i / 2, 30 - i, bone)
		img.set_pixel(cx + 5 + i / 2, 30 - i, bone)
	# Glühende Augenbrauen/Augen
	img.fill_rect(Rect2i(cx - 5, 32, 3, 2), hot)
	img.fill_rect(Rect2i(cx + 2, 32, 3, 2), hot)
	img.set_pixel(cx - 4, 32, Color(1, 1, 0.85)); img.set_pixel(cx + 3, 32, Color(1, 1, 0.85))
	# Aufgerissener Oberkiefer mit Zähnen
	img.fill_rect(Rect2i(cx - 4, 37, 8, 2), dark)
	for tx: int in [cx - 3, cx - 1, cx + 1, cx + 3]:
		img.set_pixel(tx, 39, Color(0.95, 0.92, 0.8))
	# Offener Rachen mit Glut — hier entspringt die Megaflare (~y 42-44)
	img.fill_rect(Rect2i(cx - 3, 40, 6, 4), ember)
	img.fill_rect(Rect2i(cx - 2, 41, 4, 3), hot)
	img.set_pixel(cx, 43, Color(1, 1, 0.9))
	var t := _tex(_outlined(img))
	_cache[key] = t
	return t

## Endboss „Die Stille" als dunkles Spinnentier mit rot glühenden Augen.
## Frontal zum Betrachter aufgerichtet: großer Hinterleib oben, Vorderkörper
## unten mit acht roten Augen und Fängen; acht geknickte Beine spreizen sich.
## 4 Frames = leichtes Zucken der Beine (Bewegungsanimation). Der zusätzliche
## additive Augen-Glimmer kommt im Kampf über _attach_boss_life obendrauf.
static func spider_boss(frame: int) -> Texture2D:
	var f := frame % 4
	var key := "spider_%d" % f
	if _cache.has(key):
		return _cache[key]
	var w := 46; var h := 40; var cx := 23
	var img := _img(w, h)
	var dark := Color(0.09, 0.08, 0.11)
	var mid := Color(0.16, 0.14, 0.19)
	var edge := Color(0.27, 0.23, 0.31)
	var legd := Color(0.07, 0.06, 0.09)
	var legj := Color(0.22, 0.17, 0.26)
	var eyer := Color(1.0, 0.13, 0.10)
	var eyeh := Color(1.0, 0.62, 0.45)
	var fang := Color(0.46, 0.42, 0.48)
	var mark := Color(0.42, 0.05, 0.07)
	var flap: int = [0, -1, -2, -1][f]
	# --- Acht geknickte Beine (hinter dem Körper) ---
	var base_y := [19, 21, 24, 27]
	var knee_dx := [10, 15, 18, 16]
	var knee_dy := [-9, -7, -3, 1]
	var foot_dx := [14, 19, 21, 18]
	var foot_dy := [10, 12, 10, 7]
	for side: int in [-1, 1]:
		for i in 4:
			var base := Vector2(cx + side * 5, base_y[i])
			var knee := Vector2(cx + side * knee_dx[i], base_y[i] + knee_dy[i] + flap)
			var foot := Vector2(cx + side * foot_dx[i], base_y[i] + foot_dy[i])
			_thick_line(img, base, knee, legd)
			_thick_line(img, knee, foot, legd)
			if knee.x >= 0 and knee.x < w and knee.y >= 0 and knee.y < h:
				img.set_pixel(int(knee.x), int(knee.y), legj)  # Gelenk
	# --- Hinterleib (großer Bulb oben) ---
	_fill_ellipse(img, cx, 12, 12, 10, dark)
	_fill_ellipse(img, cx, 10, 9, 7, mid)  # oberer Schimmer
	img.set_pixel(cx - 5, 6, edge); img.set_pixel(cx + 4, 6, edge)
	# Dunkelrote Sanduhr-Markierung (schmal in der Mitte, breit an den Enden)
	for my in range(6, 18):
		var half: int = 1 + absi(11 - my) / 2
		for mx in range(cx - half, cx + half + 1):
			img.set_pixel(mx, my, mark)
	# --- Vorderkörper/Kopf (unten, dem Betrachter zu) ---
	_fill_ellipse(img, cx, 24, 9, 7, dark)
	_fill_ellipse(img, cx, 23, 6, 4, mid)
	# --- Acht rot glühende Augen ---
	var main_eyes := [Vector2(cx - 4, 22), Vector2(cx + 3, 22)]
	for e: Vector2 in main_eyes:
		img.fill_rect(Rect2i(int(e.x), int(e.y), 2, 2), eyer)
		img.set_pixel(int(e.x), int(e.y), eyeh)
	for e: Vector2 in [Vector2(cx - 6, 20), Vector2(cx - 1, 19), Vector2(cx + 2, 19),
			Vector2(cx + 6, 20), Vector2(cx - 7, 24), Vector2(cx + 7, 24)]:
		img.set_pixel(int(e.x), int(e.y), eyer)
	# --- Cheliceren/Fänge (unten, nach innen gebogen) ---
	for side: int in [-1, 1]:
		var fxb := cx + side * 3
		img.fill_rect(Rect2i(fxb - (1 if side < 0 else 0), 28, 2, 3), dark)
		img.set_pixel(fxb, 31, fang)  # heller Fangzahn-Spitz
	img.set_pixel(cx - 5, 28, legj); img.set_pixel(cx + 5, 28, legj)  # Pedipalpen
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
	# Der Endboss ist ein eigens gezeichnetes Spinnentier statt eines DTII-Frames.
	if id == "boss4":
		return spider_boss(frame)
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

## Leuchtspur-Geschoss (MG-Kugel): kleine, längliche Kugel, heller Kern innen,
## nach außen ins Orange auslaufend — additiv gezeichnet wirkt sie glühend.
static func bullet() -> Texture2D:
	var key := "bullet"
	if _cache.has(key):
		return _cache[key]
	var img := _img(9, 4)
	for y in 4:
		for x in 9:
			var dx := (x - 4.0) / 4.5
			var dy := (y - 1.5) / 2.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, Color(1.0, 0.97, 0.75).lerp(Color(1.0, 0.55, 0.15), d))
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
