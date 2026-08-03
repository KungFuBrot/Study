class_name RigFactory
## Einheitlicher Figuren-Generator für ALLE Kampffiguren — Helden, Monster,
## Bosse.
##
## Warum: vorher standen 16px-DTII-Helden (Maßstab 4.0) neben dem prozeduralen
## Roboter und 16px-Monstern bzw. 32x36-Bossen (Maßstab 6.5-7.8). Dieselbe
## Szene hatte dadurch drei verschiedene Pixelgrößen und drei
## Zeichenhandschriften. Hier wird jede Figur mit derselben Lichtrichtung
## (oben links), derselben Tonwertleiter und farbiger Kontur gezeichnet, und
## alle stehen im Kampf auf Maßstab 2.0 — die Pixelgröße ist damit für jede
## Figur gleich. Die Leinwand wächst stattdessen mit der Figur:
## Held 32x56, Monster 52x52, Boss 112x128.
##
## Aufbau: erst wird eine Körperteil-Karte gezeichnet (welches Pixel gehört zu
## welchem Teil), danach wird jedes Teil über seine eigene Ausdehnung
## schattiert. Dadurch bekommt jedes Glied plastische Rundung, statt dass ein
## globaler Verlauf über die ganze Figur läuft.

const HERO_W := 32
const HERO_H := 56
const MON_W := 52
const MON_H := 52
const BOSS_W := 112
const BOSS_H := 128
## Einheitlicher Kampf-Maßstab aller Figuren (siehe BattleStage).
const BATTLE_SCALE := 2.0

# Schattierungsleiter: Anteil Licht → Farbstufe. Vier Stufen reichen für
# Pixel-Art; mehr wirkt matschig, weniger flach.
const RAMP := [0.80, 0.56, 0.28]

# --- Zeichenpuffer -----------------------------------------------------------

# Ein Körperteil ist ein Eintrag {col, wu, wv}: Farbe plus Achsengewichte der
# Schattierung. wu = Querrundung (Gliedmaßen), wv = Höhenverlauf (Rumpf, Kopf).
static var _parts: PackedInt32Array
static var _defs: Array = []
static var _detail: Dictionary  # Vector2i -> Color (Feindetails über der Schattierung)
static var W := HERO_W
static var H := HERO_H

## Verformungs-Kontext: alle Zeichen-Primitiven laufen durch _tp(). Damit
## bekommt jede Figur Atmen, Wabern und Federn, ohne dass ihre Zeichenfunktion
## davon etwas wissen muss — der Unterschied zwischen „Standbild mit Zucken"
## und „lebt".
static var _ctx_squash := 0.0
static var _ctx_shift := Vector2.ZERO
static var _foot := 51.0

static func _tp(p: Vector2) -> Vector2:
	return _sq(p, _ctx_squash) + _ctx_shift

static func _begin(w: int, h: int, foot := -1.0) -> void:
	W = w
	H = h
	_foot = foot if foot > 0.0 else float(h) - 5.0
	_ctx_squash = 0.0
	_ctx_shift = Vector2.ZERO
	_parts = PackedInt32Array()
	_parts.resize(W * H)
	_parts.fill(0)
	_defs = [{}]  # Index 0 = leer
	_detail = {}

static func _part(c: Color, u := 0.6, v := 0.4) -> int:
	_defs.append({"col": c, "wu": u, "wv": v})
	return _defs.size() - 1

## Achtung: nicht _set nennen — das kollidiert mit Object._set().
static func _put(x: int, y: int, id: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	_parts[y * W + x] = id

static func _rect(x0: int, y0: int, w: int, h: int, id: int) -> void:
	var a := _tp(Vector2(x0, y0))
	var b := _tp(Vector2(x0 + w, y0 + h))
	for y in range(int(round(a.y)), int(round(b.y))):
		for x in range(int(round(a.x)), int(round(b.x))):
			_put(x, y, id)

# Achtung: cx/cy laufen durch die Verformung, die Radien werden mitskaliert.
static func _ell(cx: float, cy: float, rx: float, ry: float, id: int) -> void:
	var c := _tp(Vector2(cx, cy))
	var srx: float = rx * (1.0 + _ctx_squash * 0.006)
	var sry: float = ry * (1.0 - _ctx_squash * 0.010)
	for y in range(int(floor(c.y - sry)), int(ceil(c.y + sry)) + 1):
		for x in range(int(floor(c.x - srx)), int(ceil(c.x + srx)) + 1):
			var dx := (x - c.x) / maxf(srx, 0.01)
			var dy := (y - c.y) / maxf(sry, 0.01)
			if dx * dx + dy * dy <= 1.0:
				_put(x, y, id)

## Glied: Strecke mit Radius — die Grundform für Arme, Beine, Klingen.
## Die Endpunkte gehen durch _ell und damit ebenfalls durch die Verformung.
static func _limb(a: Vector2, b: Vector2, r: float, id: int) -> void:
	var steps := int(ceil(a.distance_to(b))) * 2 + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		_ell(p.x, p.y, r, r, id)

## Kegelstumpf zwischen zwei Punkten: wie _limb, aber der Radius wandert von
## r0 auf r1. Damit lassen sich Rümpfe und Umhänge kippen — _taper kann das
## nicht, es zeichnet nur waagerechte Zeilen.
static func _cone(a: Vector2, b: Vector2, r0: float, r1: float, id: int) -> void:
	var steps := int(ceil(a.distance_to(b))) * 2 + 1
	for i in steps + 1:
		var f := float(i) / float(steps)
		var p := a.lerp(b, f)
		var r: float = lerpf(r0, r1, f)
		_ell(p.x, p.y, r, r, id)

## Stauchen/Strecken um die Standfläche. squash in Prozent: positiv drückt die
## Figur zusammen und macht sie breiter (Aufprall), negativ streckt sie.
static func _sq(p: Vector2, squash: float) -> Vector2:
	if is_zero_approx(squash):
		return p
	var cx := float(W) * 0.5
	return Vector2(cx + (p.x - cx) * (1.0 + squash * 0.006),
		_foot + (p.y - _foot) * (1.0 - squash * 0.010))

## Sich verjüngender Rumpf: Zeile für Zeile von w0 auf w1.
static func _taper(cx: float, y0: int, y1: int, w0: float, w1: float, id: int) -> void:
	for y in range(y0, y1 + 1):
		var t := float(y - y0) / maxf(float(y1 - y0), 1.0)
		var hw: float = lerpf(w0, w1, t) * 0.5
		var l := _tp(Vector2(cx - hw, y))
		var r := _tp(Vector2(cx + hw, y))
		for x in range(int(round(l.x)), int(round(r.x)) + 1):
			_put(x, int(round(l.y)), id)

static func _dot(x: int, y: int, c: Color) -> void:
	var p := _tp(Vector2(x, y))
	_detail[Vector2i(int(round(p.x)), int(round(p.y)))] = c

# --- Ausgabe ----------------------------------------------------------------

## Schattiert die Körperteil-Karte und setzt die farbige Kontur.
static func _render() -> Image:
	# Ausdehnung je Teil bestimmen — jedes Glied wird über SEINE Maße
	# schattiert, nicht über die ganze Figur.
	var lo := {}
	var hi := {}
	for y in H:
		for x in W:
			var id := _parts[y * W + x]
			if id == 0:
				continue
			if not lo.has(id):
				lo[id] = Vector2i(x, y)
				hi[id] = Vector2i(x, y)
			else:
				lo[id] = Vector2i(mini(lo[id].x, x), mini(lo[id].y, y))
				hi[id] = Vector2i(maxi(hi[id].x, x), maxi(hi[id].y, y))
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var id := _parts[y * W + x]
			if id == 0:
				continue
			var p: Dictionary = _defs[id]
			var base: Color = p["col"]
			var wu: float = p["wu"]
			var wv: float = p["wv"]
			var a: Vector2i = lo[id]
			var b: Vector2i = hi[id]
			var u := float(x - a.x) / maxf(float(b.x - a.x), 1.0)
			var v := float(y - a.y) / maxf(float(b.y - a.y), 1.0)
			# Licht von oben links: hell bei kleinem u und v.
			var l := 1.0 - (u * wu + v * wv) / maxf(wu + wv, 0.01)
			var c := base
			if l > RAMP[0]:
				c = base.lightened(0.30)
			elif l > RAMP[1]:
				c = base.lightened(0.11)
			elif l <= RAMP[2]:
				c = base.darkened(0.30)
			img.set_pixel(x, y, c)
	for k: Vector2i in _detail:
		if k.x >= 0 and k.y >= 0 and k.x < W and k.y < H:
			img.set_pixel(k.x, k.y, _detail[k])
	return _outline(img)

## Farbige Kontur: eine Spur dunkler als das Pixel dahinter statt hartem
## Schwarz — die Figur bleibt dadurch auch vor dunklem Hintergrund plastisch.
static func _outline(img: Image) -> Image:
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, Rect2i(0, 0, W, H), Vector2i.ZERO)
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.01:
				continue
			var near := Color(0, 0, 0, 0)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
					Vector2i(0, -1)]:
				var sx := x + d.x
				var sy := y + d.y
				if sx < 0 or sy < 0 or sx >= W or sy >= H:
					continue
				var c := img.get_pixel(sx, sy)
				if c.a > 0.5:
					near = c
					break
			if near.a > 0.5:
				out.set_pixel(x, y, Color(near.r * 0.28, near.g * 0.26, near.b * 0.32, 1.0))
	return out

# --- Figuren ----------------------------------------------------------------

static var _cache := {}

## Held im Kampf. anim siehe ANIMS: idle, walk, run, attack, cast, aim, hit,
## down, cheer. Seitenansicht.
static func battle(id: String, frame := 0, anim := "idle") -> Texture2D:
	return _figure(id, anim, frame, "side")

## Dieselbe Figur für die Erkundung. Der Aufrufer stellt sie auf Maßstab 0.5,
## dann steht sie so groß auf der Karte wie früher das 16x28-Sprite — nur mit
## der doppelten Pixeldichte und derselben Zeichnung wie im Kampf.
## dir: "side" | "down" (zum Betrachter) | "up" (von hinten).
static func field(id: String, walking: bool, frame := 0, dir := "side") -> Texture2D:
	return _figure(id, "walk" if walking else "idle", frame, dir)

static func _figure(id: String, anim: String, frame: int, view: String) -> Texture2D:
	var key := "f_%s_%s_%d_%s" % [id, anim, frame, view]
	if _cache.has(key):
		return _cache[key]
	_begin(HERO_W, HERO_H)
	var p := pose_at(anim, frame)
	var back := view == "up"
	match id:
		"milo":
			if view == "side": _milo(p)
			else: _milo_front(p, back)
		"rax":
			if view == "side": _rax(p)
			else: _rax_front(p, back)
		"npc_elder": _npc(p, view, NPC_LOOK["npc_elder"])
		"npc_kid": _npc(p, view, NPC_LOOK["npc_kid"])
		"npc_shop": _npc(p, view, NPC_LOOK["npc_shop"])
		_:
			if view == "side": _serena(p)
			else: _serena_front(p, back)
	var t := ImageTexture.create_from_image(_render())
	_cache[key] = t
	return t

# Dorfbewohner: Haar, Kleid, Borte, Gehstock+Bart.
const NPC_LOOK := {
	"npc_elder": {"hair": Color(0.86, 0.86, 0.88), "cloth": Color(0.44, 0.38, 0.28),
		"trim": Color(0.70, 0.64, 0.48), "old": true},
	"npc_kid": {"hair": Color(0.44, 0.28, 0.14), "cloth": Color(0.26, 0.54, 0.34),
		"trim": Color(0.86, 0.86, 0.60), "old": false},
	"npc_shop": {"hair": Color(0.58, 0.22, 0.34), "cloth": Color(0.62, 0.46, 0.20),
		"trim": Color(0.94, 0.90, 0.72), "old": false},
}

static func _npc(p: Dictionary, view: String, look: Dictionary) -> void:
	# Dorfbewohner stehen und gehen nur — sie greifen die Posenwerte für
	# Atmen und Schritt ab, brauchen aber keine Kampfposen.
	var lift := int(round(p["body"]))
	var swing := int(round(p["leg_f"]))
	if view == "side":
		_villager(lift, swing, look["hair"], look["cloth"], look["trim"], look["old"])
	else:
		_villager_front(lift, swing, look["hair"], look["cloth"], look["trim"],
			look["old"], view == "up")

## Dorfbewohner: gemeinsamer Körper, je Figur eigene Farben. `old` gibt einen
## Gehstock und einen langen Bart dazu.
static func _villager(lift: int, swing: int, hair_c: Color, cloth_c: Color,
		trim_c: Color, old: bool) -> void:
	var skin := _part(Color(0.92, 0.76, 0.62), 0.5, 0.5)
	var hair := _part(hair_c, 0.6, 0.4)
	var cloth := _part(cloth_c, 0.5, 0.5)
	var trim := _part(trim_c, 0.7, 0.3)
	var boot := _part(cloth_c.darkened(0.45), 0.7, 0.3)
	var wood := _part(Color(0.44, 0.30, 0.17), 0.8, 0.2)
	var top := 24 if old else 26      # Kinder sind kleiner
	_limb(Vector2(13, top + 14), Vector2(12 - swing, 49), 2.4, cloth)
	_limb(Vector2(18, top + 14), Vector2(20 + swing, 49), 2.4, cloth)
	_ell(12 - swing, 51, 3.2, 2.5, boot)
	_ell(20 + swing, 51, 3.2, 2.5, boot)
	_limb(Vector2(14, top + 2 + lift), Vector2(10, top + 11 + lift), 2.2, cloth)
	_taper(16, top + lift, top + 14, 15, 12, cloth)
	_rect(10, top + 7 + lift, 13, 1, trim)
	_ell(16, top - 9 + lift, 6.4, 6.8, hair)
	_ell(18, top - 8 + lift, 4.6, 5.4, skin)
	_dot(20, top - 8 + lift, Color(0.16, 0.12, 0.16))
	_dot(21, top - 8 + lift, Color(0.16, 0.12, 0.16))
	_limb(Vector2(19, top + 2 + lift), Vector2(23, top + 10 + lift), 2.2, cloth)
	if old:
		_ell(18, top - 2 + lift, 3.4, 3.0, hair)   # langer Bart
		_limb(Vector2(24, top + 12 + lift), Vector2(25, top - 10 + lift), 1.3, wood)

# Helen: Schwertkämpferin. Roter Waffenrock mit heller Borte, blondes
# Haar im Zopf, Schwert in der vorderen Hand.
static func _serena(p: Dictionary) -> void:
	var skin := _part(Color(0.94, 0.76, 0.61), 0.5, 0.5)
	var hair := _part(Color(0.86, 0.66, 0.24), 0.6, 0.4)
	var cloth := _part(Color(0.70, 0.16, 0.19), 0.5, 0.5)
	var trim := _part(Color(0.92, 0.84, 0.62), 0.7, 0.3)
	var pants := _part(Color(0.36, 0.25, 0.17), 0.8, 0.2)
	var boot := _part(Color(0.24, 0.17, 0.12), 0.7, 0.3)
	var steel := _part(Color(0.74, 0.78, 0.84), 0.85, 0.15)
	var grip := _part(Color(0.32, 0.21, 0.13), 0.8, 0.2)
	var leather := _part(Color(0.46, 0.31, 0.19), 0.75, 0.25)
	var cloth_shade := Color(0.70, 0.16, 0.19).darkened(0.34)

	var sq: float = p["squash"]
	var dy: float = p["body"]
	var lean: float = p["lean"]
	# Die Hüfte ist der Drehpunkt: alles darüber kippt mit `lean`, die Beine
	# bleiben am Boden. So entsteht Gewicht statt eines starren Verschiebens.
	# Hüfte, Brust, Kopf. Achtung: _cone/_limb sind Kapseln, sie ragen um den
	# Radius über die Endpunkte hinaus — die Punkte liegen deshalb weiter innen
	# als die sichtbare Silhouette.
	var hip := _sq(Vector2(16, 33 + dy), sq)
	var chest := _sq(_rot(Vector2(16, 26 + dy), hip, lean), sq)
	var neck := _sq(_rot(Vector2(17, 20 + dy), hip, lean), sq)
	var head := _sq(_rot(Vector2(16, 12 + dy + p["head"]), hip, lean), sq)
	var sh_f := _sq(_rot(Vector2(20, 24 + dy), hip, lean), sq)
	var sh_b := _sq(_rot(Vector2(13, 24 + dy), hip, lean), sq)
	var turn: float = p["turn"]

	# Beine: Fuß wandert, Knie folgt zur Hälfte.
	var foot_b := _sq(Vector2(12 - p["leg_b"], 48), sq)
	var foot_f := _sq(Vector2(20 + p["leg_f"], 48), sq)
	_limb(hip + Vector2(-2, 3), foot_b, 2.5, pants)
	_limb(hip + Vector2(3, 3), foot_f, 2.5, pants)
	_ell(foot_b.x, foot_b.y + 2, 3.3, 2.6, boot)
	_ell(foot_f.x, foot_f.y + 2, 3.3, 2.6, boot)

	# Hinterer Arm um die Schulter gedreht
	var hand_b := _rot(sh_b + Vector2(-3, 9), sh_b, p["arm_b"])
	_limb(sh_b, hand_b, 2.3, cloth)

	# Rumpf: unten Taille, oben Schultern.
	_cone(hip, chest, 5.8, 6.8, cloth)
	# Saumborte als flaches Band am unteren Rand des Waffenrocks
	var hem := hip + Vector2(0, 4)
	_limb(hem + Vector2(-5, 0), hem + Vector2(5, 0), 1.3, trim)
	var belt := hip.lerp(chest, 0.45)
	_limb(belt + Vector2(-5.5, 0), belt + Vector2(5.5, 0), 1.1, leather)
	_dot(int(belt.x), int(belt.y), Color(0.96, 0.82, 0.36))
	# Falten laufen mit dem Rumpf mit
	for i in 4:
		var f := hip.lerp(chest, 0.10 + i * 0.16)
		_dot(int(f.x) - 3, int(f.y), cloth_shade)
		_dot(int(f.x) + 3, int(f.y), cloth_shade)
	# Schulterstück
	_ell(sh_f.x, sh_f.y - 1, 3.4, 2.5, leather)
	_limb(neck + Vector2(-2, 0), neck + Vector2(1, 0), 1.8, skin)

	# Kopf. Der Zopf hängt mit `sway` nach — Nachlauf verkauft Bewegung mehr
	# als jede zusätzliche Gliedmaße.
	# Haarmasse liegt HINTER dem Gesicht, das Gesicht tritt klar hervor, das
	# Pony deckt nur die Stirn. Vorher verschluckte das Haar den halben Kopf.
	_ell(head.x - 2, head.y, 6.2, 6.6, hair)
	var braid := head + Vector2(-6 - p["sway"], 2)
	_limb(head + Vector2(-5, 1), braid + Vector2(-1, 11), 2.2, hair)
	_ell(head.x + 3 + turn, head.y + 1, 5.0, 5.6, skin)
	_ell(head.x + 1, head.y - 4.5, 5.4, 2.3, hair)
	var ex := int(round(head.x + 5 + turn))
	var ey := int(round(head.y + 1))
	_dot(ex, ey, Color(0.16, 0.12, 0.16))
	_dot(ex + 1, ey, Color(0.16, 0.12, 0.16))
	_dot(ex, ey - 1, Color(0.58, 0.42, 0.24))
	_dot(ex + 1, ey - 1, Color(0.58, 0.42, 0.24))
	_dot(ex, ey + 3, Color(0.80, 0.56, 0.47))

	# Vorderer Arm und Schwert: der Arm dreht um die Schulter, die Klinge
	# zusätzlich um die Hand — dadurch holt sie aus und zieht durch.
	var hand := _rot(sh_f + Vector2(4, 8), sh_f, p["arm_f"])
	var tip := _rot(hand + Vector2(3, -24), hand, p["wpn"] + p["arm_f"] * 0.4)
	_limb(sh_f, hand, 2.2, cloth)
	var grip_end := hand + (hand - tip).normalized() * 4.0
	_limb(hand, grip_end, 1.3, grip)
	_ell(hand.x, hand.y, 2.3, 2.0, skin)
	var across := (tip - hand).orthogonal().normalized() * 3.5
	var guard := hand.lerp(tip, 0.10)
	_limb(guard + across, guard - across, 0.8, steel)
	_limb(hand.lerp(tip, 0.12), tip, 1.4, steel)
	var edge := (tip - hand).orthogonal().normalized()
	for i in 20:
		var q := hand.lerp(tip, 0.15 + 0.85 * float(i) / 19.0) + edge
		_dot(int(round(q.x)), int(round(q.y)), Color(0.94, 0.96, 1.0))

# Janosch: Magier. Blauer Umhang, spitzer Hut, Stab mit grünem Stein.
static func _milo(p: Dictionary) -> void:
	var skin := _part(Color(0.92, 0.75, 0.60), 0.5, 0.5)
	var hair := _part(Color(0.32, 0.26, 0.44), 0.6, 0.4)
	var robe := _part(Color(0.21, 0.30, 0.66), 0.5, 0.5)
	var hat := _part(Color(0.17, 0.24, 0.55), 0.7, 0.3)
	var trim := _part(Color(0.72, 0.76, 0.94), 0.7, 0.3)
	var wood := _part(Color(0.44, 0.30, 0.17), 0.85, 0.15)
	var gem := _part(Color(0.35, 0.88, 0.45), 0.5, 0.5)
	var robe_shade := Color(0.21, 0.30, 0.66).darkened(0.36)
	var beard := _part(Color(0.62, 0.62, 0.70), 0.6, 0.4)

	var sq: float = p["squash"]
	var dy: float = p["body"]
	var lean: float = p["lean"]
	var hip := _sq(Vector2(16, 36 + dy), sq)
	var chest := _sq(_rot(Vector2(16, 25 + dy), hip, lean), sq)
	var head := _sq(_rot(Vector2(16, 16 + dy + p["head"]), hip, lean), sq)
	var sh_f := _sq(_rot(Vector2(20, 26 + dy), hip, lean), sq)
	var sh_b := _sq(_rot(Vector2(12, 26 + dy), hip, lean), sq)
	var turn: float = p["turn"]

	# Beine schauen nur unten aus der Kutte
	_limb(Vector2(14, 41), Vector2(13 - p["leg_b"], 49), 2.4, robe)
	_limb(Vector2(19, 41), Vector2(20 + p["leg_f"], 49), 2.4, robe)
	_ell(13 - p["leg_b"], 51, 3.2, 2.5, hair)
	_ell(20 + p["leg_f"], 51, 3.2, 2.5, hair)
	_limb(sh_b, _rot(sh_b + Vector2(-4, 8), sh_b, p["arm_b"]), 2.2, robe)
	# Kutte als gekippter Kegel; der Saum bleibt am Boden, das Wehen kommt
	# über `sway`.
	_cone(_sq(Vector2(16 + p["sway"] * 0.6, 47), sq), chest, 10.5, 7.0, robe)
	_limb(Vector2(6, 47), Vector2(26, 47), 1.0, trim)
	var belt := hip.lerp(chest, 0.35)
	_limb(belt + Vector2(-6, 0), belt + Vector2(6, 0), 0.8, trim)
	for i in 6:
		var f := _sq(Vector2(16, 30 + i * 3), sq)
		var spread := 3.0 + float(i) * 0.9
		_dot(int(f.x - spread + p["sway"] * 0.4), int(f.y), robe_shade)
		_dot(int(f.x + spread + p["sway"] * 0.4), int(f.y), robe_shade)
	# Kopf mit Hut und Bart
	_ell(head.x + 1 + turn, head.y, 5.0, 5.6, skin)
	_ell(head.x - 1, head.y - 3, 6.2, 4.2, hair)
	_ell(head.x + 2 + turn, head.y + 6, 3.2, 2.6, beard)
	_limb(head + Vector2(-7, -5), head + Vector2(9, -5), 1.0, hat)
	_cone(_sq(_rot(Vector2(16 + p["sway"] * 1.2, 3 + dy), hip, lean), sq),
		head + Vector2(0, -5), 1.5, 6.5, hat)
	_dot(int(head.x + 4 + turn), int(head.y), Color(0.13, 0.10, 0.15))
	_dot(int(head.x + 5 + turn), int(head.y), Color(0.13, 0.10, 0.15))
	_dot(int(head.x + 4 + turn), int(head.y - 1), Color(0.55, 0.50, 0.58))
	_dot(int(head.x + 5 + turn), int(head.y - 1), Color(0.55, 0.50, 0.58))
	# Stab dreht mit der Hand; der Stein glüht, wenn der Arm ausschlägt.
	var hand := _rot(sh_f + Vector2(3, 6), sh_f, p["arm_f"])
	var tip := _rot(hand + Vector2(3, -22), hand, p["wpn"] + p["arm_f"] * 0.5)
	_limb(hand + (hand - tip).normalized() * 8.0, tip, 1.4, wood)
	_ell(hand.x, hand.y, 2.1, 2.1, skin)
	var glow: float = clampf(absf(p["arm_f"]) / 30.0, 0.0, 1.0)
	_ell(tip.x, tip.y, 2.9 + glow, 2.9 + glow, gem)
	_dot(int(tip.x) - 1, int(tip.y) - 1, Color(0.82, 1.0, 0.86))
	if glow > 0.35:
		for i in 6:
			var ang := TAU * float(i) / 6.0
			_dot(int(tip.x + cos(ang) * (5.0 + glow * 2.0)),
				int(tip.y + sin(ang) * (5.0 + glow * 2.0)), Color(0.62, 1.0, 0.70))

# Wally: Roboter. Kastenkörper mit Kern, Visierkopf, Panzerplatten.
static func _rax(p: Dictionary) -> void:
	var shell := _part(Color(0.62, 0.64, 0.68), 0.55, 0.45)
	var dark := _part(Color(0.30, 0.31, 0.35), 0.7, 0.3)
	var visor := _part(Color(0.35, 0.82, 0.90), 0.6, 0.4)
	var core := _part(Color(0.98, 0.55, 0.16), 0.5, 0.5)
	var barrel := _part(Color(0.44, 0.45, 0.50), 0.85, 0.15)
	var seam := Color(0.22, 0.23, 0.27)

	var sq: float = p["squash"]
	var dy: float = p["body"]
	var lean: float = p["lean"]
	var hip := _sq(Vector2(17, 37 + dy), sq)
	var chest := _sq(_rot(Vector2(17, 26 + dy), hip, lean), sq)
	var head := _sq(_rot(Vector2(17, 14 + dy + p["head"]), hip, lean), sq)
	var sh_f := _sq(_rot(Vector2(22, 26 + dy), hip, lean), sq)
	var sh_b := _sq(_rot(Vector2(12, 26 + dy), hip, lean), sq)
	var turn: float = p["turn"]
	var by := int(round(dy))

	# Teleskopbeine
	_rect(11 - int(round(p["leg_b"])), 37, 5, 12, dark)
	_rect(18 + int(round(p["leg_f"])), 37, 5, 12, dark)
	_rect(9 - int(round(p["leg_b"])), 49, 8, 5, shell)
	_rect(17 + int(round(p["leg_f"])), 49, 8, 5, shell)
	_limb(sh_b, _rot(sh_b + Vector2(-4, 9), sh_b, p["arm_b"]), 2.4, dark)
	# Rumpfkasten kippt mit
	_cone(hip, chest, 8.0, 8.0, shell)
	_rect(10, 22 + by, 15, 2, dark)
	_rect(10, 36 + by, 15, 2, dark)
	for sy in range(25 + by, 36 + by):
		_dot(13, sy, seam)
		_dot(22, sy, seam)
	# Kern pulsiert mit dem Atem — der Roboter „lebt" über sein Licht.
	var pulse: float = 0.6 + absf(dy) * 0.5 + absf(p["arm_f"]) / 60.0
	_ell(17, 30 + by, 3.6, 3.6, dark)
	_ell(17, 30 + by, 2.0 + pulse * 0.8, 2.0 + pulse * 0.8, core)
	_dot(16, 29 + by, Color(1.0, 0.86, 0.55))
	_ell(sh_f.x, sh_f.y - 1, 3.4, 2.6, shell)
	# Kopf: Visier wandert mit `turn` — er schaut sich um.
	_rect(int(head.x) - 5, int(head.y) - 5, 11, 10, shell)
	_rect(int(head.x) - 4 + int(round(turn)), int(head.y) - 2, 9, 3, visor)
	_dot(int(head.x) - 3 + int(round(turn)), int(head.y) - 2, Color(0.82, 0.98, 1.0))
	_dot(int(head.x) - 2 + int(round(turn)), int(head.y) - 2, Color(0.82, 0.98, 1.0))
	_rect(int(head.x) - 1, int(head.y) - 9 - int(round(p["sway"])), 2, 4, dark)
	_dot(int(head.x), int(head.y) - 10 - int(round(p["sway"])), Color(1.0, 0.42, 0.30))
	_rect(int(head.x) - 2, int(head.y) + 5, 5, 3, dark)
	# Waffenarm dreht um die Schulter
	var elbow := _rot(sh_f + Vector2(4, 5), sh_f, p["arm_f"])
	var muzzle := _rot(elbow + Vector2(5, 0), elbow, p["arm_f"] * 0.5 + p["wpn"])
	_limb(sh_f, elbow, 2.4, shell)
	_limb(elbow, muzzle, 1.7, barrel)
	_dot(int(muzzle.x), int(muzzle.y), Color(0.18, 0.18, 0.22))
	if p["arm_f"] < -20.0:
		_dot(int(muzzle.x) + 1, int(muzzle.y), Color(1.0, 0.80, 0.40))

# --- Animationsschicht -------------------------------------------------------
## Zwischen „Figur zeichnen" und „Animation" liegt eine Handvoll Posenwerte.
## Eine Animation verändert nur diese Zahlen über Keyframes; die
## Zeichenfunktion wertet sie aus. Dadurch kostet eine neue Animation ein paar
## Zeilen Tabelle statt einer neuen Zeichnung.
##
## Gebacken wird bewusst Bild für Bild: gedrehte Pixel-Art wird bei 32x56
## matschig, gebackene Frames bleiben scharf.

## Ruhestellung. Alle Werte sind Versätze in Pixeln bzw. Winkel in Grad; 0
## heißt „wie gezeichnet".
const POSE_ZERO := {
	"body": 0.0,     # ganze Figur hoch/runter (Atmen, Sprung, Einknicken)
	"lean": 0.0,     # Oberkörper nach vorn (+) / hinten (-)
	"head": 0.0,     # Kopf zusätzlich zum Körper
	"arm_f": 0.0,    # vorderer Arm / Waffenhand: Winkel um die Schulter
	"arm_b": 0.0,    # hinterer Arm
	"leg_f": 0.0,    # vorderes Bein: Versatz nach vorn
	"leg_b": 0.0,    # hinteres Bein
	"wpn": 0.0,      # Waffe zusätzlich zum Arm
	"sway": 0.0,     # Haar, Umhang, Schwaden — Nachlauf der Bewegung
	"squash": 0.0,   # Stauchen (+) / Strecken (-) in Prozent
	"turn": 0.0,     # Kopf dreht zur Seite (Unruhe, Zucken)
}

## Animationstabelle. `frames` = gebackene Einzelbilder, `fps` = Abspieltempo,
## `keys` = Stützstellen über t=0..1. Fehlende Werte bleiben bei 0.
## Die Werte sind bewusst klein: die Figuren sind 32 px breit, da wirkt schon
## ein Pixel Versatz.
const ANIMS := {
	# Ruhig atmen, Gewicht verlagern, gelegentlich der Kopf — nie ganz still.
	"idle": {"fps": 7, "frames": 8, "loop": true, "keys": [
		{"t": 0.00, "body": 0.0, "sway": 0.0, "turn": 0.0},
		{"t": 0.25, "body": -1.0, "sway": 0.5, "arm_f": -3.0},
		{"t": 0.50, "body": -1.0, "sway": 0.9, "turn": 0.6},
		{"t": 0.75, "body": 0.0, "sway": 0.4, "arm_f": 2.0},
		{"t": 1.00, "body": 0.0, "sway": 0.0, "turn": 0.0},
	]},
	# Gehen: Beine im Gegentakt, Körper hebt sich im Schrittwechsel.
	"walk": {"fps": 9, "frames": 8, "loop": true, "keys": [
		{"t": 0.00, "leg_f": 2.5, "leg_b": -2.5, "body": 0.0, "arm_f": -10.0, "arm_b": 10.0},
		{"t": 0.25, "leg_f": 0.0, "leg_b": 0.0, "body": -1.0, "arm_f": 0.0, "arm_b": 0.0},
		{"t": 0.50, "leg_f": -2.5, "leg_b": 2.5, "body": 0.0, "arm_f": 10.0, "arm_b": -10.0},
		{"t": 0.75, "leg_f": 0.0, "leg_b": 0.0, "body": -1.0, "arm_f": 0.0, "arm_b": 0.0},
		{"t": 1.00, "leg_f": 2.5, "leg_b": -2.5, "body": 0.0, "arm_f": -10.0, "arm_b": 10.0},
	]},
	# Rennen: weiter ausgreifend, vorgelehnt, tiefer.
	"run": {"fps": 12, "frames": 8, "loop": true, "keys": [
		{"t": 0.00, "leg_f": 4.0, "leg_b": -4.0, "lean": 3.0, "body": 1.0,
			"arm_f": -22.0, "arm_b": 22.0, "sway": 1.4},
		{"t": 0.25, "leg_f": 0.0, "leg_b": 0.0, "lean": 3.0, "body": -2.0,
			"arm_f": 0.0, "arm_b": 0.0, "sway": 0.8},
		{"t": 0.50, "leg_f": -4.0, "leg_b": 4.0, "lean": 3.0, "body": 1.0,
			"arm_f": 22.0, "arm_b": -22.0, "sway": 1.4},
		{"t": 0.75, "leg_f": 0.0, "leg_b": 0.0, "lean": 3.0, "body": -2.0,
			"arm_f": 0.0, "arm_b": 0.0, "sway": 0.8},
		{"t": 1.00, "leg_f": 4.0, "leg_b": -4.0, "lean": 3.0, "body": 1.0,
			"arm_f": -22.0, "arm_b": 22.0, "sway": 1.4},
	]},
	# Schlag: ausholen (langsam), durchziehen (schnell), nachfedern.
	"attack": {"fps": 14, "frames": 10, "loop": false, "keys": [
		{"t": 0.00, "wpn": 0.0, "lean": 0.0},
		{"t": 0.30, "wpn": -55.0, "lean": -6.0, "arm_f": -25.0, "body": -1.0, "sway": -1.2},
		{"t": 0.42, "wpn": -62.0, "lean": -8.0, "arm_f": -30.0, "squash": -3.0},
		{"t": 0.58, "wpn": 75.0, "lean": 9.0, "arm_f": 35.0, "leg_f": 3.0, "squash": 4.0, "sway": 2.4},
		{"t": 0.78, "wpn": 52.0, "lean": 5.0, "arm_f": 22.0, "leg_f": 1.5, "sway": 1.0},
		{"t": 1.00, "wpn": 0.0, "lean": 0.0},
	]},
	# Zaubern: sammeln, aufrichten, entladen.
	"cast": {"fps": 11, "frames": 10, "loop": false, "keys": [
		{"t": 0.00, "arm_f": 0.0, "body": 0.0},
		{"t": 0.30, "arm_f": -18.0, "body": 1.0, "squash": 4.0, "lean": -4.0},
		{"t": 0.55, "arm_f": -30.0, "body": 2.0, "squash": 6.0, "sway": -1.0},
		{"t": 0.70, "arm_f": 40.0, "body": -3.0, "squash": -5.0, "lean": 6.0, "sway": 2.5},
		{"t": 0.85, "arm_f": 30.0, "body": -1.0, "sway": 1.2},
		{"t": 1.00, "arm_f": 0.0, "body": 0.0},
	]},
	# Zielen: Arm hoch, kurzer Rückstoß.
	"aim": {"fps": 12, "frames": 6, "loop": false, "keys": [
		{"t": 0.00, "arm_f": 0.0},
		{"t": 0.35, "arm_f": -34.0, "lean": -2.0},
		{"t": 0.55, "arm_f": -34.0, "lean": -2.0},
		{"t": 0.65, "arm_f": -28.0, "lean": -6.0, "body": -1.0, "squash": 3.0},
		{"t": 1.00, "arm_f": -34.0, "lean": -2.0},
	]},
	# Treffer: zurückgerissen, dann fangen.
	"hit": {"fps": 14, "frames": 6, "loop": false, "keys": [
		{"t": 0.00, "lean": 0.0},
		{"t": 0.20, "lean": -14.0, "body": -2.0, "arm_f": -20.0, "arm_b": -16.0,
			"leg_b": -2.0, "sway": -2.5, "squash": -4.0},
		{"t": 0.55, "lean": -6.0, "body": 0.0, "arm_f": -8.0, "sway": -1.0},
		{"t": 1.00, "lean": 0.0},
	]},
	# Zusammenbrechen: einknicken, nach hinten kippen, liegen bleiben.
	"down": {"fps": 9, "frames": 8, "loop": false, "keys": [
		{"t": 0.00, "lean": 0.0},
		{"t": 0.25, "lean": 8.0, "body": 2.0, "squash": 8.0, "head": 2.0},
		{"t": 0.60, "lean": -20.0, "body": 6.0, "squash": 14.0, "arm_f": -40.0,
			"arm_b": -30.0, "sway": -3.0},
		{"t": 1.00, "lean": -26.0, "body": 9.0, "squash": 18.0, "arm_f": -50.0,
			"arm_b": -40.0, "sway": -3.0},
	]},
	# Sieg: Waffe hoch, zweimal auffedern.
	"cheer": {"fps": 9, "frames": 10, "loop": true, "keys": [
		{"t": 0.00, "arm_f": -50.0, "wpn": -20.0, "body": 0.0},
		{"t": 0.25, "arm_f": -58.0, "wpn": -26.0, "body": -3.0, "squash": -4.0, "sway": 1.6},
		{"t": 0.50, "arm_f": -50.0, "wpn": -20.0, "body": 0.0, "squash": 3.0},
		{"t": 0.75, "arm_f": -56.0, "wpn": -24.0, "body": -2.0, "squash": -3.0, "sway": 1.2},
		{"t": 1.00, "arm_f": -50.0, "wpn": -20.0, "body": 0.0},
	]},
}

## Posenwerte einer Animation zum Frame `frame`.
static func pose_at(anim: String, frame: int) -> Dictionary:
	var a: Dictionary = ANIMS.get(anim, ANIMS["idle"])
	var n: int = a["frames"]
	var t := float(frame % n) / float(n) if a["loop"] else \
		float(mini(frame, n - 1)) / float(n - 1)
	var keys: Array = a["keys"]
	# Stützstellen links und rechts von t suchen.
	var i := 0
	while i < keys.size() - 2 and float(keys[i + 1]["t"]) < t:
		i += 1
	var k0: Dictionary = keys[i]
	var k1: Dictionary = keys[mini(i + 1, keys.size() - 1)]
	var span: float = maxf(float(k1["t"]) - float(k0["t"]), 0.0001)
	var f := clampf((t - float(k0["t"])) / span, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)  # weich ein- und ausblenden
	var out := {}
	for k: String in POSE_ZERO:
		var a0: float = k0.get(k, 0.0)
		var a1: float = k1.get(k, 0.0)
		out[k] = lerpf(a0, a1, f)
	return out

## Frameanzahl einer Animation (für Aufrufer, die durchtakten).
static func anim_frames(anim: String) -> int:
	return ANIMS.get(anim, ANIMS["idle"])["frames"]

static func anim_fps(anim: String) -> float:
	return float(ANIMS.get(anim, ANIMS["idle"])["fps"])

static func anim_loops(anim: String) -> bool:
	return ANIMS.get(anim, ANIMS["idle"])["loop"]

# Punkt um `pivot` drehen — für Arme, Waffen, Beine.
static func _rot(p: Vector2, pivot: Vector2, deg: float) -> Vector2:
	if is_zero_approx(deg):
		return p
	return pivot + (p - pivot).rotated(deg_to_rad(deg))

# --- Front- und Rückansicht (nur Erkundung) ---------------------------------
# Beim Blick nach oben/unten steht die Figur symmetrisch: beide Arme sichtbar,
# beide Beine nebeneinander. `back` lässt das Gesicht weg — man sieht nur
# Hinterkopf und Rücken.

## Gesicht (zwei Augen, angedeuteter Mund) oder bei `back` nichts.
static func _face(cx: int, cy: int, back: bool, brow: Color) -> void:
	if back:
		return
	_dot(cx - 2, cy, Color(0.16, 0.12, 0.16))
	_dot(cx + 2, cy, Color(0.16, 0.12, 0.16))
	_dot(cx - 2, cy - 1, brow)
	_dot(cx + 2, cy - 1, brow)
	_dot(cx, cy + 3, brow.darkened(0.2))

static func _serena_front(p: Dictionary, back: bool) -> void:
	var lift := int(round(p["body"]))
	var swing := int(round(p["leg_f"]))
	var skin := _part(Color(0.94, 0.76, 0.61), 0.5, 0.5)
	var hair := _part(Color(0.86, 0.66, 0.24), 0.6, 0.4)
	var cloth := _part(Color(0.70, 0.16, 0.19), 0.5, 0.5)
	var trim := _part(Color(0.92, 0.84, 0.62), 0.7, 0.3)
	var pants := _part(Color(0.36, 0.25, 0.17), 0.8, 0.2)
	var boot := _part(Color(0.24, 0.17, 0.12), 0.7, 0.3)
	var steel := _part(Color(0.74, 0.78, 0.84), 0.85, 0.15)
	_limb(Vector2(13, 37), Vector2(13 - swing, 49), 2.6, pants)
	_limb(Vector2(19, 37), Vector2(19 + swing, 49), 2.6, pants)
	_ell(13 - swing, 51, 3.2, 2.6, boot)
	_ell(19 + swing, 51, 3.2, 2.6, boot)
	_taper(16, 21 + lift, 34 + lift, 17, 13, cloth)
	_rect(9, 34 + lift, 15, 3, trim)
	_rect(9, 27 + lift, 15, 2, _part(Color(0.46, 0.31, 0.19), 0.75, 0.25))
	_limb(Vector2(9, 23 + lift), Vector2(7, 33 + lift), 2.2, cloth)
	_limb(Vector2(23, 23 + lift), Vector2(25, 33 + lift), 2.2, cloth)
	_ell(7, 35 + lift, 2.1, 2.1, skin)
	_ell(25, 35 + lift, 2.1, 2.1, skin)
	_ell(16, 13 + lift, 7.0, 7.2, hair)
	if not back:
		_ell(16, 14 + lift, 5.0, 5.6, skin)
		_ell(16, 9 + lift, 5.4, 2.5, hair)
	_face(16, 14 + lift, back, Color(0.62, 0.46, 0.28))
	# Schwert auf dem Rücken, wenn man sie von hinten sieht
	if back:
		_limb(Vector2(21, 32 + lift), Vector2(26, 12 + lift), 1.4, steel)

static func _milo_front(p: Dictionary, back: bool) -> void:
	var lift := int(round(p["body"]))
	var swing := int(round(p["leg_f"]))
	var skin := _part(Color(0.92, 0.75, 0.60), 0.5, 0.5)
	var hair := _part(Color(0.32, 0.26, 0.44), 0.6, 0.4)
	var robe := _part(Color(0.21, 0.30, 0.66), 0.5, 0.5)
	var hat := _part(Color(0.17, 0.24, 0.55), 0.7, 0.3)
	var trim := _part(Color(0.72, 0.76, 0.94), 0.7, 0.3)
	var wood := _part(Color(0.44, 0.30, 0.17), 0.85, 0.15)
	var gem := _part(Color(0.35, 0.88, 0.45), 0.5, 0.5)
	_limb(Vector2(14, 40), Vector2(14 - swing, 49), 2.4, robe)
	_limb(Vector2(19, 40), Vector2(19 + swing, 49), 2.4, robe)
	_taper(16, 22 + lift, 48, 15, 21, robe)
	_rect(6, 47, 21, 2, trim)
	_limb(Vector2(9, 25 + lift), Vector2(7, 35 + lift), 2.2, robe)
	_limb(Vector2(23, 25 + lift), Vector2(25, 35 + lift), 2.2, robe)
	if not back:
		_ell(16, 16 + lift, 5.2, 5.8, skin)
		_ell(16, 21 + lift, 3.4, 2.6, _part(Color(0.62, 0.62, 0.70), 0.6, 0.4))
	else:
		_ell(16, 16 + lift, 5.8, 5.4, hair)
	_rect(8, 11 + lift, 17, 2, hat)
	_taper(16, 3 + lift, 11 + lift, 3, 14, hat)
	_face(16, 16 + lift, back, Color(0.55, 0.50, 0.58))
	_limb(Vector2(25, 34 + lift), Vector2(26, 12 + lift), 1.4, wood)
	_ell(26, 10 + lift, 2.7, 2.7, gem)

static func _rax_front(p: Dictionary, back: bool) -> void:
	var lift := int(round(p["body"]))
	var swing := int(round(p["leg_f"]))
	var shell := _part(Color(0.62, 0.64, 0.68), 0.55, 0.45)
	var dark := _part(Color(0.30, 0.31, 0.35), 0.7, 0.3)
	var visor := _part(Color(0.35, 0.82, 0.90), 0.6, 0.4)
	var core := _part(Color(0.98, 0.55, 0.16), 0.5, 0.5)
	_rect(11 - swing, 37, 5, 12, dark)
	_rect(17 + swing, 37, 5, 12, dark)
	_rect(9 - swing, 49, 8, 5, shell)
	_rect(16 + swing, 49, 8, 5, shell)
	_rect(9, 22 + lift, 15, 16, shell)
	_rect(9, 22 + lift, 15, 2, dark)
	_rect(9, 36 + lift, 15, 2, dark)
	_limb(Vector2(8, 26 + lift), Vector2(6, 35 + lift), 2.3, dark)
	_limb(Vector2(24, 26 + lift), Vector2(26, 35 + lift), 2.3, dark)
	if not back:
		_ell(16, 30 + lift, 3.6, 3.6, dark)
		_ell(16, 30 + lift, 2.2, 2.2, core)
	else:
		_rect(12, 27 + lift, 9, 8, dark)      # Wartungsklappe auf dem Rücken
	_rect(11, 9 + lift, 11, 10, shell)
	if not back:
		_rect(12, 12 + lift, 9, 3, visor)
		_dot(13, 12 + lift, Color(0.82, 0.98, 1.0))
	_rect(15, 6 + lift, 2, 4, dark)
	_dot(16, 5 + lift, Color(1.0, 0.42, 0.30))
	_rect(14, 19 + lift, 5, 3, dark)

static func _villager_front(lift: int, swing: int, hair_c: Color, cloth_c: Color,
		trim_c: Color, old: bool, back: bool) -> void:
	var skin := _part(Color(0.92, 0.76, 0.62), 0.5, 0.5)
	var hair := _part(hair_c, 0.6, 0.4)
	var cloth := _part(cloth_c, 0.5, 0.5)
	var trim := _part(trim_c, 0.7, 0.3)
	var boot := _part(cloth_c.darkened(0.45), 0.7, 0.3)
	var wood := _part(Color(0.44, 0.30, 0.17), 0.8, 0.2)
	var top := 24 if old else 26
	_limb(Vector2(13, top + 14), Vector2(13 - swing, 49), 2.4, cloth)
	_limb(Vector2(19, top + 14), Vector2(19 + swing, 49), 2.4, cloth)
	_ell(13 - swing, 51, 3.0, 2.4, boot)
	_ell(19 + swing, 51, 3.0, 2.4, boot)
	_taper(16, top + lift, top + 14, 16, 13, cloth)
	_rect(9, top + 7 + lift, 15, 1, trim)
	_limb(Vector2(9, top + 2 + lift), Vector2(7, top + 11 + lift), 2.2, cloth)
	_limb(Vector2(23, top + 2 + lift), Vector2(25, top + 11 + lift), 2.2, cloth)
	_ell(16, top - 9 + lift, 6.6, 7.0, hair)
	if not back:
		_ell(16, top - 8 + lift, 4.8, 5.4, skin)
		if old:
			_ell(16, top - 3 + lift, 3.4, 2.8, hair)
	_face(16, top - 8 + lift, back, Color(0.62, 0.50, 0.38))
	if old:
		_limb(Vector2(25, top + 12 + lift), Vector2(26, top - 10 + lift), 1.3, wood)

# --- Gegner ------------------------------------------------------------------

const BOSSES := ["boss", "boss2", "boss3", "boss4"]
## Frames der Monster-Eigenbewegung. Acht statt vier: bei vier Bildern wirkt
## ein Wabern wie ein Ruckeln.
const MON_FRAMES := 8

static func is_boss(id: String) -> bool:
	return BOSSES.has(id)

## Eigenbewegung je Kreatur: Amplitude des Wabern/Stauchens, der Höhendrift
## und die Phasenverschiebung. Erst dadurch bekommt jedes Monster einen
## eigenen Rhythmus — vorher zuckten alle im selben Takt um einen Pixel.
## squash = wie stark es sich zusammenzieht, drift = wie weit es schwebt,
## hover = schwebt frei (Drift beidseitig statt nur nach oben).
const MON_IDLE := {
	"schlammschleim": {"squash": 11.0, "drift": 1.0, "phase": 0.0},
	"qualmgeist": {"squash": 3.5, "drift": 3.0, "phase": 0.3, "hover": true},
	"muellgnom": {"squash": 4.0, "drift": 1.0, "phase": 0.6},
	"gierschlund": {"squash": 9.0, "drift": 1.5, "phase": 0.15},
	"paragraphengeist": {"squash": 2.5, "drift": 3.5, "phase": 0.45, "hover": true},
	"zinshund": {"squash": 5.0, "drift": 1.5, "phase": 0.8},
	"hetzer": {"squash": 5.5, "drift": 1.0, "phase": 0.1},
	"wutgeist": {"squash": 8.0, "drift": 2.0, "phase": 0.55},
	"schlaeger": {"squash": 4.5, "drift": 1.0, "phase": 0.35},
	"hassprediger": {"squash": 3.0, "drift": 1.5, "phase": 0.7},
	"hohlgaenger": {"squash": 2.0, "drift": 1.0, "phase": 0.2},
	"grauschemen": {"squash": 3.0, "drift": 4.0, "phase": 0.5, "hover": true},
	"namenlose": {"squash": 1.5, "drift": 0.5, "phase": 0.9},
	"boss": {"squash": 5.0, "drift": 2.0, "phase": 0.0},
	"boss2": {"squash": 6.5, "drift": 2.0, "phase": 0.25},
	"boss3": {"squash": 4.5, "drift": 2.5, "phase": 0.5},
	"boss4": {"squash": 3.0, "drift": 3.0, "phase": 0.75, "hover": true},
}

## Monster oder Boss, frame 0..MON_FRAMES-1.
static func monster(id: String, frame := 0) -> Texture2D:
	var key := "m_%s_%d" % [id, frame]
	if _cache.has(key):
		return _cache[key]
	var big := is_boss(id)
	_begin(BOSS_W if big else MON_W, BOSS_H if big else MON_H,
		127.0 if big else 51.0)
	# Eigenbewegung als Kontext setzen — die Zeichenfunktionen unten wissen
	# nichts davon, alle Primitiven laufen ohnehin durch die Verformung.
	var mv: Dictionary = MON_IDLE.get(id, {"squash": 4.0, "drift": 1.0, "phase": 0.0})
	var ph := TAU * (float(frame % MON_FRAMES) / float(MON_FRAMES) + float(mv["phase"]))
	_ctx_squash = float(mv["squash"]) * sin(ph)
	var d := float(mv["drift"])
	_ctx_shift = Vector2(0, -d * (0.5 + 0.5 * sin(ph * (1.0 if mv.get("hover", false) else 2.0))))
	var f := frame % 4
	match id:
		"schlammschleim": _slime(f)
		"qualmgeist": _smog(f)
		"muellgnom": _gnome(f)
		"gierschlund": _greedmaw(f)
		"paragraphengeist": _clause(f)
		"zinshund": _hound(f)
		"hetzer": _rouser(f)
		"wutgeist": _rage(f)
		"schlaeger": _bruiser(f)
		"hassprediger": _preacher(f)
		"hohlgaenger": _hollow(f)
		"grauschemen": _shade(f)
		"namenlose": _nameless(f)
		"boss": _boss_baron(f)
		"boss2": _boss_prince(f)
		"boss3": _boss_divider(f)
		"boss4": _boss_silence(f)
		_: _slime(f)
	var t := ImageTexture.create_from_image(_render())
	_cache[key] = t
	return t

# Ruhiges Atmen über vier Frames: 0, -1, -1, 0.
static func _breath(frame: int) -> int:
	return -1 if (frame == 1 or frame == 2) else 0

# Auge mit Lichtpunkt — zwei Pixel reichen, damit eine Kreatur „schaut".
static func _eye(x: int, y: int, col: Color) -> void:
	_dot(x, y, col.lightened(0.45))
	_dot(x + 1, y, col)
	_dot(x, y + 1, col.darkened(0.35))
	_dot(x + 1, y + 1, col.darkened(0.35))

# Schlammschleim: zäher Tümpel mit Blasen, tropft an den Rändern.
static func _slime(frame: int) -> void:
	var b := _breath(frame)
	var body := _part(Color(0.36, 0.50, 0.20), 0.45, 0.55)
	var skin := _part(Color(0.48, 0.64, 0.26), 0.45, 0.55)
	_ell(26, 38 + b, 19, 13, body)
	_ell(24, 31 + b, 13, 9, skin)
	for i in 4:
		var dx := 12 + i * 9
		_limb(Vector2(dx, 46), Vector2(dx, 49 + (i % 2)), 2.0, body)
	_eye(20, 33 + b, Color(0.95, 1.0, 0.75))
	_eye(30, 33 + b, Color(0.95, 1.0, 0.75))
	_dot(21, 36 + b, Color(0.12, 0.16, 0.08))
	_dot(31, 36 + b, Color(0.12, 0.16, 0.08))
	for i in 5:
		var px := 14 + i * 7
		var py := 41 + ((i * 3) % 5) + b
		_dot(px, py, Color(0.62, 0.82, 0.34))
		_dot(px + 1, py, Color(0.52, 0.70, 0.28))

# Qualmgeist: Kapuze aus Rauch, unten in Schwaden aufgelöst.
static func _smog(frame: int) -> void:
	var b := _breath(frame)
	var smoke := _part(Color(0.46, 0.51, 0.42), 0.5, 0.5)
	var deep := _part(Color(0.30, 0.34, 0.27), 0.5, 0.5)
	_ell(26, 20 + b, 12, 13, smoke)
	_taper(26, 30 + b, 44, 22, 30, smoke)
	_ell(26, 22 + b, 8, 8, deep)
	for i in 5:
		var sx := 10 + i * 8
		_limb(Vector2(sx, 43), Vector2(sx + (2 if i % 2 == 0 else -2), 50), 2.6, smoke)
	_eye(21, 20 + b, Color(0.72, 1.0, 0.45))
	_eye(29, 20 + b, Color(0.72, 1.0, 0.45))
	for i in 3:
		_dot(18 + i * 8, 12 + b - i % 2, Color(0.44, 0.50, 0.42))

# Müllgnom: kleiner Kerl mit Topfhelm und prall gefülltem Sack.
static func _gnome(frame: int) -> void:
	var b := _breath(frame)
	var sack := _part(Color(0.56, 0.48, 0.32), 0.5, 0.5)
	var cloth := _part(Color(0.52, 0.39, 0.28), 0.55, 0.45)
	var skin := _part(Color(0.62, 0.58, 0.42), 0.5, 0.5)
	var metal := _part(Color(0.50, 0.46, 0.44), 0.7, 0.3)
	var rust := _part(Color(0.55, 0.32, 0.18), 0.6, 0.4)
	_ell(16, 30 + b, 12, 12, sack)
	_dot(12, 24 + b, Color(0.30, 0.26, 0.18))
	_dot(20, 23 + b, Color(0.30, 0.26, 0.18))
	_limb(Vector2(24, 40), Vector2(23, 48), 3.0, cloth)
	_limb(Vector2(31, 40), Vector2(32, 48), 3.0, cloth)
	_ell(23, 50, 4.0, 2.4, rust)
	_ell(32, 50, 4.0, 2.4, rust)
	_taper(28, 28 + b, 41, 16, 13, cloth)
	_rect(21, 34 + b, 15, 2, rust)
	_ell(29, 22 + b, 8, 8, skin)
	_ell(29, 17 + b, 10, 5, metal)
	_rect(19, 17 + b, 20, 2, metal)
	_eye(26, 22 + b, Color(1.0, 0.86, 0.40))
	_eye(32, 22 + b, Color(1.0, 0.86, 0.40))
	_dot(29, 26 + b, Color(0.30, 0.22, 0.16))
	_limb(Vector2(34, 30 + b), Vector2(41, 36 + b), 2.6, cloth)
	_ell(43, 37 + b, 3.4, 3.4, rust)

# Gierschlund: Geldsack, der zum Maul geworden ist.
static func _greedmaw(frame: int) -> void:
	var b := _breath(frame)
	var sack := _part(Color(0.52, 0.42, 0.20), 0.5, 0.5)
	var maw := _part(Color(0.30, 0.14, 0.10), 0.4, 0.6)
	var tooth := _part(Color(0.94, 0.92, 0.82), 0.6, 0.4)
	var gold := _part(Color(0.96, 0.78, 0.24), 0.5, 0.5)
	_ell(26, 34 + b, 19, 16, sack)
	_rect(14, 22 + b, 24, 4, sack)
	_dot(20, 21 + b, Color(0.78, 0.62, 0.26))
	_dot(32, 21 + b, Color(0.78, 0.62, 0.26))
	_ell(27, 38 + b, 13, 8, maw)
	for i in 6:
		var tx := 16 + i * 4
		_limb(Vector2(tx, 32 + b), Vector2(tx, 35 + b), 1.4, tooth)
		_limb(Vector2(tx + 2, 44 + b), Vector2(tx + 2, 41 + b), 1.4, tooth)
	_eye(19, 27 + b, Color(1.0, 0.90, 0.50))
	_eye(33, 27 + b, Color(1.0, 0.90, 0.50))
	for i in 3:
		_ell(40 + i * 3, 46 - i * 2, 2.4, 2.0, gold)
	_ell(11, 47, 2.4, 2.0, gold)

# Paragraphengeist: schwebende Robe aus Aktenpapier mit rotem Siegel.
static func _clause(frame: int) -> void:
	var b := _breath(frame)
	var paper := _part(Color(0.80, 0.76, 0.64), 0.5, 0.5)
	var hood := _part(Color(0.34, 0.32, 0.30), 0.5, 0.5)
	var seal := _part(Color(0.74, 0.14, 0.14), 0.5, 0.5)
	var ink := _part(Color(0.22, 0.22, 0.26), 0.6, 0.4)
	var line := _part(Color(0.44, 0.42, 0.36), 0.6, 0.4)
	var line_c := Color(0.44, 0.42, 0.36)
	_taper(26, 24 + b, 45, 18, 30, paper)
	# Zerfledderter Saum
	for i in 6:
		var fx := 12 + i * 6
		_limb(Vector2(fx, 44), Vector2(fx + (1 if i % 2 == 0 else -1), 48 + i % 3), 2.2, paper)
	# Spitze Kapuze statt Kugelkopf — das gibt der Figur eine Silhouette.
	_taper(26, 8 + b, 26 + b, 5, 22, hood)
	_ell(26, 21 + b, 6.5, 5.5, ink)           # Schattenhöhle darunter
	_eye(22, 20 + b, Color(0.95, 0.86, 0.55))
	_eye(28, 20 + b, Color(0.95, 0.86, 0.55))
	# Ärmel halten eine entrollte Urkunde vor den Körper
	_limb(Vector2(17, 29 + b), Vector2(19, 35 + b), 3.0, paper)
	_limb(Vector2(35, 29 + b), Vector2(33, 35 + b), 3.0, paper)
	_rect(17, 31 + b, 18, 11, paper)
	for i in 4:
		_rect(19, 33 + b + i * 2, 14, 1, line)  # Textzeilen
	_ell(31, 40 + b, 3.5, 3.0, seal)          # Siegel unter dem Text
	_dot(31, 39 + b, Color(0.98, 0.72, 0.62))
	# Zwei lose Blätter wehen mit
	_ell(43, 22 + b, 3.5, 4.5, paper)
	_ell(8, 28 + b, 3.5, 4.5, paper)
	_dot(43, 21 + b, line_c)
	_dot(8, 27 + b, line_c)

# Zinshund: vierbeiniger Eintreiber mit goldenem Halsband.
static func _hound(frame: int) -> void:
	var b := _breath(frame)
	var fur := _part(Color(0.34, 0.26, 0.20), 0.5, 0.5)
	var dark := _part(Color(0.22, 0.17, 0.13), 0.6, 0.4)
	var gold := _part(Color(0.92, 0.74, 0.26), 0.6, 0.4)
	_limb(Vector2(15, 36 + b), Vector2(14, 48), 2.6, dark)
	_limb(Vector2(21, 36 + b), Vector2(22, 48), 2.6, dark)
	_limb(Vector2(33, 36 + b), Vector2(32, 48), 2.6, dark)
	_limb(Vector2(39, 36 + b), Vector2(40, 48), 2.6, dark)
	_ell(27, 33 + b, 16, 9, fur)
	_limb(Vector2(12, 31 + b), Vector2(6, 24 + b), 2.0, fur)
	_ell(39, 27 + b, 8, 7, fur)
	_ell(46, 29 + b, 5, 3.4, fur)
	_limb(Vector2(36, 21 + b), Vector2(38, 17 + b), 2.0, dark)
	_limb(Vector2(42, 21 + b), Vector2(44, 18 + b), 2.0, dark)
	_eye(40, 26 + b, Color(1.0, 0.72, 0.30))
	_dot(50, 29 + b, Color(0.16, 0.12, 0.10))
	for i in 3:
		_dot(43 + i * 2, 31 + b, Color(0.92, 0.90, 0.82))
	_rect(33, 30 + b, 3, 7, gold)
	_ell(34, 36 + b, 2.6, 2.6, gold)

# Hetzer: schreit durch ein Megafon.
static func _rouser(frame: int) -> void:
	var b := _breath(frame)
	var cloth := _part(Color(0.44, 0.20, 0.18), 0.55, 0.45)
	var skin := _part(Color(0.76, 0.56, 0.44), 0.5, 0.5)
	var dark := _part(Color(0.24, 0.20, 0.22), 0.6, 0.4)
	var metal := _part(Color(0.56, 0.54, 0.52), 0.7, 0.3)
	_limb(Vector2(22, 36), Vector2(21, 48), 2.8, dark)
	_limb(Vector2(29, 36), Vector2(31, 48), 2.8, dark)
	_ell(21, 50, 3.8, 2.4, dark)
	_ell(31, 50, 3.8, 2.4, dark)
	_taper(26, 22 + b, 37, 17, 14, cloth)
	_rect(18, 30 + b, 17, 2, dark)
	_ell(28, 15 + b, 8, 8, skin)
	_ell(26, 11 + b, 9, 4, dark)
	_eye(30, 14 + b, Color(1.0, 0.72, 0.55))
	_dot(30, 18 + b, Color(0.30, 0.12, 0.12))
	_dot(31, 18 + b, Color(0.30, 0.12, 0.12))
	_limb(Vector2(32, 24 + b), Vector2(39, 19 + b), 2.4, cloth)
	_taper(43, 14 + b, 24 + b, 4, 14, metal)
	_dot(46, 15 + b, Color(0.86, 0.86, 0.90))

# Wutgeist: kleiner brennender Kobold.
static func _rage(frame: int) -> void:
	var b := _breath(frame)
	var body := _part(Color(0.62, 0.18, 0.14), 0.5, 0.5)
	var dark := _part(Color(0.36, 0.10, 0.10), 0.6, 0.4)
	var fire := _part(Color(1.0, 0.55, 0.18), 0.5, 0.5)
	_limb(Vector2(23, 38), Vector2(21, 47), 2.4, dark)
	_limb(Vector2(30, 38), Vector2(32, 47), 2.4, dark)
	_ell(26, 33 + b, 11, 10, body)
	_ell(26, 22 + b, 9, 9, body)
	# Hörner weit nach AUSSEN — vorher standen sie senkrecht hinter dem
	# Flammenkamm und waren dadurch unsichtbar.
	_limb(Vector2(19, 20 + b), Vector2(10, 12 + b), 2.4, dark)
	_limb(Vector2(33, 20 + b), Vector2(42, 12 + b), 2.4, dark)
	_limb(Vector2(10, 12 + b), Vector2(8, 8 + b), 1.4, dark)
	_limb(Vector2(42, 12 + b), Vector2(44, 8 + b), 1.4, dark)
	# Angewinkelte Arme mit Klauen — die Kreatur geht gleich los.
	_limb(Vector2(17, 30 + b), Vector2(11, 25 + b), 2.4, body)
	_limb(Vector2(35, 30 + b), Vector2(41, 25 + b), 2.4, body)
	for i in 3:
		_dot(9 - i % 2, 22 + b + i, Color(0.92, 0.86, 0.74))
		_dot(43 + i % 2, 22 + b + i, Color(0.92, 0.86, 0.74))
	_eye(21, 21 + b, Color(1.0, 0.92, 0.40))
	_eye(29, 21 + b, Color(1.0, 0.92, 0.40))
	# Flammenkamm zwischen den Hörnern
	for i in 3:
		_limb(Vector2(22 + i * 4, 15 + b), Vector2(22 + i * 4, 7 + b - (i % 2) * 2), 1.6, fire)
	_dot(25, 26 + b, Color(0.28, 0.06, 0.06))
	_dot(27, 26 + b, Color(0.28, 0.06, 0.06))

# Schläger: breiter Typ mit Knüppel.
static func _bruiser(frame: int) -> void:
	var b := _breath(frame)
	var cloth := _part(Color(0.42, 0.44, 0.49), 0.55, 0.45)
	var skin := _part(Color(0.72, 0.54, 0.42), 0.5, 0.5)
	var dark := _part(Color(0.28, 0.29, 0.33), 0.6, 0.4)
	var wood := _part(Color(0.42, 0.28, 0.16), 0.75, 0.25)
	_limb(Vector2(21, 37), Vector2(19, 48), 3.4, dark)
	_limb(Vector2(31, 37), Vector2(33, 48), 3.4, dark)
	_ell(19, 50, 4.4, 2.6, dark)
	_ell(33, 50, 4.4, 2.6, dark)
	_taper(26, 20 + b, 38, 26, 18, cloth)
	_rect(15, 32 + b, 23, 2, dark)
	_ell(27, 14 + b, 7, 6, skin)
	_ell(27, 10 + b, 8, 3, dark)
	_eye(29, 13 + b, Color(1.0, 0.80, 0.60))
	_dot(28, 17 + b, Color(0.32, 0.16, 0.12))
	_limb(Vector2(14, 24 + b), Vector2(9, 34 + b), 3.4, skin)
	_limb(Vector2(38, 24 + b), Vector2(44, 31 + b), 3.4, skin)
	_limb(Vector2(45, 32 + b), Vector2(49, 16 + b), 2.6, wood)
	_ell(49, 13 + b, 4.2, 4.2, wood)

# Hassprediger: Kutte, erhobenes Banner.
static func _preacher(frame: int) -> void:
	var b := _breath(frame)
	var robe := _part(Color(0.40, 0.23, 0.25), 0.5, 0.5)
	var hood := _part(Color(0.30, 0.17, 0.19), 0.5, 0.5)
	var flag := _part(Color(0.68, 0.12, 0.12), 0.5, 0.5)
	var wood := _part(Color(0.38, 0.26, 0.16), 0.8, 0.2)
	_taper(25, 20 + b, 48, 17, 26, robe)
	_ell(25, 16 + b, 9, 9, hood)
	_eye(21, 17 + b, Color(1.0, 0.42, 0.28))
	_eye(27, 17 + b, Color(1.0, 0.42, 0.28))
	_limb(Vector2(32, 26 + b), Vector2(38, 22 + b), 2.4, robe)
	_limb(Vector2(40, 46), Vector2(40, 10 + b), 1.6, wood)
	_rect(41, 11 + b, 10, 13, flag)
	_dot(46, 17 + b, Color(0.16, 0.04, 0.04))
	_dot(45, 16 + b, Color(0.16, 0.04, 0.04))
	_dot(47, 16 + b, Color(0.16, 0.04, 0.04))

# Hohlgänger: ausgezehrte Gestalt, Rippen unter der Haut, leere Höhlen statt
# Augen. Die Arme hängen bis unter die Knie — nichts an ihr ist gespannt.
static func _hollow(frame: int) -> void:
	var b := _breath(frame)
	var body := _part(Color(0.52, 0.54, 0.58), 0.5, 0.5)
	var dark := _part(Color(0.33, 0.35, 0.40), 0.6, 0.4)
	var hollow := _part(Color(0.16, 0.17, 0.21), 0.4, 0.6)
	_limb(Vector2(23, 34), Vector2(22, 49), 2.2, dark)
	_limb(Vector2(30, 34), Vector2(31, 49), 2.2, dark)
	_ell(22, 50, 3.0, 2.0, dark)
	_ell(31, 50, 3.0, 2.0, dark)
	# Schmaler Brustkorb, darunter eingefallener Bauch
	_taper(26, 17 + b, 27 + b, 16, 12, body)
	_taper(26, 27 + b, 36, 12, 13, dark)
	_ell(20, 19 + b, 3.6, 2.6, body)          # abfallende Schultern
	_ell(32, 19 + b, 3.6, 2.6, body)
	# Rippen
	for i in 3:
		_rect(21, 21 + b + i * 3, 11, 1, hollow)
	# Sehr lange Arme
	_limb(Vector2(19, 20 + b), Vector2(15, 41 + b), 2.0, body)
	_limb(Vector2(33, 20 + b), Vector2(38, 41 + b), 2.0, body)
	_ell(15, 43 + b, 2.4, 2.8, body)
	_ell(38, 43 + b, 2.4, 2.8, body)
	# Schmaler Schädel mit leeren Höhlen
	_ell(26, 10 + b, 6.0, 7.5, body)
	_ell(23, 10 + b, 2.0, 2.6, hollow)
	_ell(29, 10 + b, 2.0, 2.6, hollow)
	_rect(23, 15 + b, 7, 1, hollow)

# Grauschemen: verblasster Umriss, unten aufgelöst.
static func _shade(frame: int) -> void:
	var b := _breath(frame)
	var pale := _part(Color(0.56, 0.60, 0.66), 0.45, 0.55)
	var dim := _part(Color(0.38, 0.42, 0.48), 0.5, 0.5)
	_ell(26, 16 + b, 9.5, 10.5, pale)
	# Nach unten immer dünner und in einen Schleier auslaufend statt
	# abgeschnitten — vorher standen da sechs Stummel wie Beine.
	_taper(26, 25 + b, 38, 19, 24, pale)
	_taper(26, 38, 46, 24, 10, dim)
	for i in 5:
		var sx := 16 + i * 5
		_limb(Vector2(sx, 40), Vector2(sx + (2 if i % 2 == 0 else -2), 49 - i % 2), 1.8, dim)
	# Armschleier bleiben dicht am Körper — weiter außen standen sie als
	# Stöcke ab, statt wie Stoff zu hängen.
	_limb(Vector2(18, 23 + b), Vector2(14, 33 + b), 2.8, pale)
	_limb(Vector2(34, 23 + b), Vector2(38, 33 + b), 2.8, pale)
	_ell(26, 17 + b, 6, 7, dim)
	_eye(23, 15 + b, Color(0.86, 0.92, 1.0))
	_eye(29, 15 + b, Color(0.86, 0.92, 1.0))

# Namenlose: hohe Kragenkutte, gefaltete Hände, statt eines Gesichts eine
# glatte Platte mit einer einzigen Naht. Die Silhouette muss die Arbeit tun —
# es gibt bewusst keine Züge, an denen das Auge hängenbleiben könnte.
static func _nameless(frame: int) -> void:
	var b := _breath(frame)
	var robe := _part(Color(0.48, 0.48, 0.53), 0.5, 0.5)
	var face := _part(Color(0.78, 0.78, 0.82), 0.55, 0.45)
	var dark := _part(Color(0.30, 0.30, 0.35), 0.6, 0.4)
	var seam := Color(0.52, 0.52, 0.58)
	# Schmale Kutte: vorher war der Kegel so breit, dass die Figur wie ein
	# Grabstein aussah statt wie jemand, der dort steht.
	_taper(26, 23 + b, 48, 13, 21, robe)
	# Ärmel liegen AUSSERHALB der Kutte, sonst verschwinden sie darin
	_limb(Vector2(19, 26 + b), Vector2(16, 37 + b), 2.6, robe)
	_limb(Vector2(33, 26 + b), Vector2(36, 37 + b), 2.6, robe)
	_ell(16, 39 + b, 2.4, 2.2, dark)
	_ell(36, 39 + b, 2.4, 2.2, dark)
	_rect(20, 30 + b, 13, 1, dark)            # Gürtelschnur
	# Schmaler Kragen, kleiner Kopf
	_taper(26, 20 + b, 24 + b, 15, 12, dark)
	_ell(26, 14 + b, 6.2, 7.2, face)
	for sy in range(8 + b, 21 + b):
		_dot(26, sy, seam)                    # die einzige Naht
	_rect(16, 45, 20, 2, dark)                # Saum

# --- Bosse -------------------------------------------------------------------

# Schlotbaron: Industriekoloss mit zwei Schloten und glühenden Schlitzen.
static func _boss_baron(frame: int) -> void:
	var b := _breath(frame) * 2
	var iron := _part(Color(0.48, 0.50, 0.42), 0.5, 0.5)
	var dark := _part(Color(0.31, 0.33, 0.27), 0.6, 0.4)
	var pipe := _part(Color(0.39, 0.36, 0.33), 0.75, 0.25)
	var glow := _part(Color(0.55, 0.95, 0.30), 0.5, 0.5)
	var skin := _part(Color(0.48, 0.56, 0.34), 0.5, 0.5)
	_limb(Vector2(44, 92), Vector2(38, 120), 11, dark)
	_limb(Vector2(70, 92), Vector2(78, 120), 11, dark)
	_ell(37, 123, 15, 6, iron)
	_ell(79, 123, 15, 6, iron)
	_limb(Vector2(30, 62 + b), Vector2(22, 14 + b), 8, pipe)
	_limb(Vector2(48, 54 + b), Vector2(42, 6 + b), 7, pipe)
	_ell(22, 12 + b, 10, 4, dark)
	_ell(42, 4 + b, 9, 4, dark)
	_taper(58, 44 + b, 96 + b, 74, 52, iron)
	_rect(24, 70 + b, 68, 5, dark)
	for i in 9:
		_dot(28 + i * 8, 72 + b, Color(0.52, 0.54, 0.48))
	for i in 3:
		_rect(44 + i * 12, 56 + b, 6, 12, glow)
	_limb(Vector2(26, 52 + b), Vector2(14, 88 + b), 10, iron)
	_limb(Vector2(90, 52 + b), Vector2(102, 86 + b), 10, iron)
	_ell(12, 94 + b, 12, 11, dark)
	_ell(104, 92 + b, 12, 11, dark)
	_ell(64, 34 + b, 17, 15, skin)
	_rect(50, 30 + b, 30, 8, dark)
	_ell(58, 34 + b, 5, 4, glow)
	_ell(72, 34 + b, 5, 4, glow)
	_rect(52, 44 + b, 26, 4, pipe)
	_dot(64, 46 + b, Color(0.70, 1.0, 0.50))

# Monopolfürst: gewaltiger Magnat mit Zylinder, Monokel und Gehstock.
static func _boss_prince(frame: int) -> void:
	var b := _breath(frame) * 2
	var suit := _part(Color(0.33, 0.30, 0.39), 0.5, 0.5)
	var dark := _part(Color(0.21, 0.19, 0.26), 0.6, 0.4)
	var gold := _part(Color(0.92, 0.74, 0.24), 0.6, 0.4)
	var skin := _part(Color(0.86, 0.68, 0.54), 0.5, 0.5)
	var shirt := _part(Color(0.90, 0.88, 0.82), 0.5, 0.5)
	_limb(Vector2(48, 96), Vector2(42, 120), 11, dark)
	_limb(Vector2(72, 96), Vector2(78, 120), 11, dark)
	_ell(41, 123, 14, 6, dark)
	_ell(79, 123, 14, 6, dark)
	_ell(60, 78 + b, 40, 27, suit)
	_taper(60, 44 + b, 62 + b, 46, 66, suit)
	_ell(60, 80 + b, 22, 20, shirt)
	_rect(56, 62 + b, 8, 26, gold)
	_ell(60, 92 + b, 5, 4, gold)
	_limb(Vector2(24, 52 + b), Vector2(14, 84 + b), 9, suit)
	_limb(Vector2(96, 52 + b), Vector2(106, 82 + b), 9, suit)
	_ell(12, 90 + b, 10, 9, skin)
	_ell(108, 88 + b, 10, 9, skin)
	_limb(Vector2(108, 90 + b), Vector2(104, 122), 3, gold)
	_ell(60, 34 + b, 16, 15, skin)
	_rect(40, 22 + b, 40, 4, dark)
	_rect(46, 4 + b, 28, 19, dark)
	_rect(46, 18 + b, 28, 4, gold)
	_eye(52, 33 + b, Color(0.32, 0.26, 0.22))
	_ell(70, 34 + b, 6, 5, shirt)
	_ell(70, 34 + b, 4, 3, skin)
	_dot(69, 33 + b, Color(0.20, 0.16, 0.14))
	_limb(Vector2(76, 34 + b), Vector2(84, 44 + b), 1.2, gold)

# Der Spalter: gehörnte Gestalt mit gespaltener Maske.
static func _boss_divider(frame: int) -> void:
	var b := _breath(frame) * 2
	# Körper deutlich heller als der Umhang — sonst verschmelzen Rumpf, Arme
	# und Mantel zu einer einzigen roten Fläche.
	var flesh := _part(Color(0.62, 0.24, 0.21), 0.5, 0.5)
	var dark := _part(Color(0.32, 0.12, 0.14), 0.6, 0.4)
	var cloak := _part(Color(0.26, 0.09, 0.12), 0.5, 0.5)
	var bone := _part(Color(0.84, 0.80, 0.72), 0.55, 0.45)
	var mask_dark := _part(Color(0.24, 0.20, 0.22), 0.55, 0.45)
	var ember := _part(Color(1.0, 0.42, 0.14), 0.5, 0.5)
	_limb(Vector2(46, 94), Vector2(40, 120), 11, dark)
	_limb(Vector2(72, 94), Vector2(80, 120), 11, dark)
	_ell(39, 123, 14, 6, dark)
	_ell(81, 123, 14, 6, dark)
	_taper(58, 40 + b, 114, 84, 104, cloak)
	for i in 7:
		var fx := 12 + i * 15
		_limb(Vector2(fx, 108), Vector2(fx + (4 if i % 2 == 0 else -4), 124), 5, cloak)
	_taper(59, 44 + b, 96 + b, 62, 46, flesh)
	_rect(30, 66 + b, 58, 4, dark)
	_limb(Vector2(28, 50 + b), Vector2(16, 86 + b), 9, flesh)
	_limb(Vector2(90, 50 + b), Vector2(102, 86 + b), 9, flesh)
	for i in 3:
		_limb(Vector2(14 + i * 3, 92 + b), Vector2(9 + i * 4, 102 + b), 2.2, bone)
		_limb(Vector2(100 + i * 3, 92 + b), Vector2(103 + i * 4, 102 + b), 2.2, bone)
	_limb(Vector2(46, 24 + b), Vector2(30, 4 + b), 5, bone)
	_limb(Vector2(74, 24 + b), Vector2(90, 4 + b), 5, bone)
	# Maske: linke Hälfte hell, rechte dunkel, dazwischen ein zackiger Riss.
	_ell(60, 30 + b, 18, 17, bone)
	for y in range(14 + b, 48 + b):
		for x in range(60, 79):
			var dx := float(x - 60) / 18.0
			var dy := float(y - 30 - b) / 17.0
			if dx * dx + dy * dy <= 1.0:
				_put(x, y, mask_dark)
	for y in range(14 + b, 48 + b):
		_dot(59 + (y % 3) - 1, y, Color(0.10, 0.02, 0.03))
	_ell(52, 29 + b, 4, 3, ember)
	_ell(69, 29 + b, 4, 3, ember)
	for i in 5:
		_dot(52 + i * 3, 40 + b, Color(0.92, 0.88, 0.80))

# Die Stille: bleiches Spinnentier mit acht roten Augen.
static func _boss_silence(frame: int) -> void:
	var b := _breath(frame) * 2
	var pale := _part(Color(0.62, 0.62, 0.68), 0.5, 0.5)
	var dark := _part(Color(0.28, 0.28, 0.34), 0.6, 0.4)
	var eyec := Color(1.0, 0.20, 0.18)
	for i in 4:
		var sy := 58 + i * 7 + b
		var reach := 30 + i * 6
		var down := 96 + i * 7
		_limb(Vector2(42, sy), Vector2(56 - reach, sy - 12 + i * 5), 4, dark)
		_limb(Vector2(56 - reach, sy - 12 + i * 5), Vector2(50 - reach, down), 3, dark)
		_limb(Vector2(70, sy), Vector2(56 + reach, sy - 12 + i * 5), 4, dark)
		_limb(Vector2(56 + reach, sy - 12 + i * 5), Vector2(62 + reach, down), 3, dark)
	_ell(56, 84 + b, 33, 28, pale)
	_ell(56, 48 + b, 22, 19, pale)
	_ell(56, 40 + b, 15, 12, dark)
	for i in 4:
		_eye(40 + i * 8, 38 + b, eyec)
	for i in 3:
		_eye(44 + i * 8, 45 + b, eyec)
	_eye(68, 45 + b, eyec)
	_limb(Vector2(48, 56 + b), Vector2(44, 66 + b), 3, dark)
	_limb(Vector2(64, 56 + b), Vector2(68, 66 + b), 3, dark)
	for i in 4:
		_dot(56, 72 + b + i * 6, Color(0.24, 0.22, 0.28))
		_dot(50 + i, 76 + b + i * 4, Color(0.36, 0.34, 0.40))
		_dot(62 - i, 76 + b + i * 4, Color(0.36, 0.34, 0.40))
