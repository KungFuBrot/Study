class_name SpriteFactoryChars
extends SpriteFactoryLib
## Helden- und Roboter-Sprites: Feld-/Kampfgrafiken, Waffen, Posen,
## Raketen/Meteor/Bombe.
## Teil der SpriteFactory-Kette: SpriteFactoryLib > SpriteFactoryChars > SpriteFactory.

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
	return field_char(id, false, frame, dir)

## Feldfigur mit Zustand: laufend → Beinausschlag, sonst nur Atmen (4 Frames).
## Kommt aus derselben RigFactory wie die Kampfsprites; der Aufrufer stellt sie
## auf FIELD_SCALE, damit sie auf der Karte so groß steht wie früher das
## 16x28-Sprite — bei doppelter Pixeldichte.
static func field_char(id: String, walking: bool, frame: int, dir := "side") -> Texture2D:
	return RigFactory.field(id, walking, frame, dir)

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

## Kampfsprite eines Helden. Kommt seit dem Rig-Umbau aus RigFactory: alle
## Kampffiguren (Helden, Monster, Bosse) werden dort in derselben Auflösung,
## Lichtrichtung und Tonwertleiter gezeichnet und im Kampf einheitlich auf
## RigFactory.BATTLE_SCALE gestellt.
## anim: "idle" | "run" | "attack" | "aim" | "hit".
static func hero_battle_frame(id: String, frame: int, anim := "idle") -> Texture2D:
	# Nur mit LPCMOCK=1: Helen kommt zum Vorzeigen aus den LPC-Blaettern.
	if id == "serena" and LpcMock.active():
		var l := LpcMock.hero(frame, anim)
		if l != null:
			return l
	return RigFactory.battle(id, frame, anim)

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
	# Wally kommt wie alle anderen aus dem Rig; nur wenn dort ein Streifen
	# fehlt, greift die alte 28x28-Zeichnung darunter.
	var rig := RigFactory.battle("rax", frame, pose)
	if rig != null:
		return rig
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
