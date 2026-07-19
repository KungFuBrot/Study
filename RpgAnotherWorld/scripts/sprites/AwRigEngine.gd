class_name AwRigEngine
extends SpriteFactoryLib
## Rig-Engine für den Another-World-Flächenstil (Eric Chahi): Figuren sind
## Skelette aus Bones (Gelenk-Hierarchie, Forward-Kinematik), an denen flache
## Polygon-Formen hängen. Posen werden als Keyframes definiert, interpoliert
## und zu ImageTexture-Frames GEBACKEN — dadurch bleibt die gesamte
## Sprite2D-Pipeline des Kampfes (Tint, Dissolve, Spiegelung) unangetastet.
##
## Warum Bones: Teile können konstruktionsbedingt nicht "in der Luft schweben"
## (Lehre aus dem verworfenen Piloten) — jedes Teil hängt an einem Gelenk,
## Gelenke werden durch überlappende Scheiben geschlossen. Zusätzlich prüft
## `count_parts()` jede gebackene Frame-Alpha-Maske auf Zusammenhang.
##
## Rig-Format (Dictionary):
##   size: Vector2i            Leinwand in px
##   origin: Vector2           Leinwand-Position des Root-Bones
##   bones: {name: {parent: String ("" = Root), pos: Vector2}}
##     pos = Pivot-Versatz im (rotierten) Koordinatensystem des Parents.
##   shapes: [ {bone, kind, col, ...} ]  in Malreihenfolge:
##     kind "quad": {p0..p3 ODER w0,w1,len (Trapez entlang lokal +Y)}
##     kind "poly": {pts: PackedVector2Array} (bone-lokal)
##     kind "disc": {c: Vector2, r: float}
##   anims: {name: {frames: int, loop: bool, ease: bool, keys: [
##     {t: 0..1, j: {bone: rot}, off: {bone: Vector2}, root: Vector2} ],
##     waves: [ {bone, chan, amp, freq, phase} ] }}
##     waves = kontinuierliche Sinus-Kanäle ADDITIV über der Keyframe-Pose.
##     chan: "j" (Rotation), "ox"/"oy" (Bone-Offset), "rx"/"ry" (Root-Offset).
##     Wert = amp * sin(TAU * (freq*t + phase)). Weil jeder Bone seine eigene
##     Phase/Frequenz trägt, laufen die Teile NIE synchron → organischer Fluss.

## ---------- Backen ----------

## Gebackener, gecachter Frame. rig_id muss eindeutig sein (Cache-Schlüssel).
static func rig_tex(rig_id: String, rig: Dictionary, anim: String, frame: int) -> Texture2D:
	var adef: Dictionary = rig["anims"].get(anim, rig["anims"]["idle"])
	var f := frame % int(adef["frames"])
	var key := "awrig_%s_%s_%d" % [rig_id, anim, f]
	if _cache.has(key):
		return _cache[key]
	var t := _tex(bake(rig, anim, f))
	_cache[key] = t
	return t

## Rastert einen Animations-Frame des Rigs auf seine Leinwand.
static func bake(rig: Dictionary, anim: String, frame: int) -> Image:
	var adef: Dictionary = rig["anims"].get(anim, rig["anims"]["idle"])
	var n := int(adef["frames"])
	var f := frame % n
	# Bei Loops liegt der letzte Frame VOR t=1.0 (nahtloser Zyklus).
	var t := float(f) / float(n) if adef.get("loop", true) else \
		(float(f) / float(maxi(n - 1, 1)))
	var pose := pose_at(adef, t)
	if adef.has("waves"):
		_apply_waves(pose, adef["waves"], t)
	return _rasterize(rig, pose)

## Addiert kontinuierliche Sinus-Kanäle auf die interpolierte Keyframe-Pose.
## Verändert `pose` in-place (pose_at liefert bei Loops ohnehin frische Dicts).
static func _apply_waves(pose: Dictionary, waves: Array, t: float) -> void:
	for wv: Dictionary in waves:
		var v: float = wv["amp"] * sin(TAU * (wv.get("freq", 1.0) * t + wv.get("phase", 0.0)))
		var bone: String = wv["bone"]
		match wv.get("chan", "j"):
			"j":
				pose["j"][bone] = pose["j"].get(bone, 0.0) + v
			"ox":
				pose["off"][bone] = (pose["off"].get(bone, Vector2.ZERO) as Vector2) + Vector2(v, 0)
			"oy":
				pose["off"][bone] = (pose["off"].get(bone, Vector2.ZERO) as Vector2) + Vector2(0, v)
			"rx":
				pose["root"] = (pose["root"] as Vector2) + Vector2(v, 0)
			"ry":
				pose["root"] = (pose["root"] as Vector2) + Vector2(0, v)

## Interpolierte Pose zum Zeitpunkt t (0..1). Keys müssen nach t sortiert sein.
static func pose_at(adef: Dictionary, t: float) -> Dictionary:
	var keys: Array = adef["keys"]
	if keys.size() == 1:
		return _lerp_pose(keys[0], keys[0], 0.0)  # frische Kopie (Waves mutieren!)
	var loop: bool = adef.get("loop", true)
	var a: Dictionary
	var b: Dictionary
	var span := 0.0
	var local := 0.0
	# Segment [a..b] suchen, in dem t liegt; bei Loop wickelt das letzte
	# Segment zurück zum ersten Key.
	var found := false
	for i in keys.size() - 1:
		if t >= keys[i]["t"] and t < keys[i + 1]["t"]:
			a = keys[i]
			b = keys[i + 1]
			span = b["t"] - a["t"]
			local = t - a["t"]
			found = true
			break
	if not found:
		a = keys[keys.size() - 1]
		if loop:
			b = keys[0]
			span = (1.0 - a["t"]) + b["t"]
			local = t - a["t"] if t >= a["t"] else (1.0 - a["t"]) + t
		else:
			return _lerp_pose(a, a, 0.0)  # frische Kopie
	var u := local / maxf(span, 0.0001)
	if adef.get("ease", true):
		u = u * u * (3.0 - 2.0 * u)  # smoothstep: An- und Abschwellen der Bewegung
	return _lerp_pose(a, b, u)

static func _lerp_pose(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {"j": {}, "off": {}, "root": Vector2.ZERO}
	var ja: Dictionary = a.get("j", {})
	var jb: Dictionary = b.get("j", {})
	for k in ja.keys() + jb.keys():
		if out["j"].has(k):
			continue
		out["j"][k] = lerpf(ja.get(k, 0.0), jb.get(k, 0.0), u)
	var oa: Dictionary = a.get("off", {})
	var ob: Dictionary = b.get("off", {})
	for k in oa.keys() + ob.keys():
		if out["off"].has(k):
			continue
		out["off"][k] = (oa.get(k, Vector2.ZERO) as Vector2).lerp(ob.get(k, Vector2.ZERO), u)
	out["root"] = (a.get("root", Vector2.ZERO) as Vector2).lerp(b.get("root", Vector2.ZERO), u)
	return out

## Forward-Kinematik: Welt-Transform (Leinwand-Raum) je Bone.
static func _bone_xforms(rig: Dictionary, pose: Dictionary) -> Dictionary:
	var bones: Dictionary = rig["bones"]
	var rots: Dictionary = pose.get("j", {})
	var offs: Dictionary = pose.get("off", {})
	var root_off: Vector2 = pose.get("root", Vector2.ZERO)
	var xf := {}
	# Bones sind in Definitionsreihenfolge angelegt; Parents stehen vor
	# ihren Kindern (Dictionary behält die Einfügereihenfolge).
	for name in bones.keys():
		var b: Dictionary = bones[name]
		var rot: float = rots.get(name, 0.0) + b.get("rest", 0.0)
		var pos: Vector2 = b.get("pos", Vector2.ZERO) + (offs.get(name, Vector2.ZERO) as Vector2)
		var parent: String = b.get("parent", "")
		var local := Transform2D(rot, pos)
		if parent == "":
			xf[name] = Transform2D(rot, rig["origin"] + root_off + pos)
		else:
			xf[name] = (xf[parent] as Transform2D) * local
	return xf

static func _rasterize(rig: Dictionary, pose: Dictionary) -> Image:
	var size: Vector2i = rig["size"]
	var img := _img(size.x, size.y)
	var xf := _bone_xforms(rig, pose)
	for shape in rig["shapes"]:
		var m: Transform2D = xf[shape["bone"]]
		var col: Color = shape["col"]
		match shape.get("kind", "poly"):
			"disc":
				var c: Vector2 = m * (shape.get("c", Vector2.ZERO) as Vector2)
				_aw_disc(img, c, shape["r"], col)
			"quad":
				var pts := _quad_points(shape)
				var world := PackedVector2Array()
				for p in pts:
					world.append(m * p)
				_aw_poly(img, world, col)
			_:
				var world2 := PackedVector2Array()
				for p in shape["pts"]:
					world2.append(m * (p as Vector2))
				_aw_poly(img, world2, col)
	return img

## Trapez entlang lokal +Y: w0 = Breite am Pivot, w1 = Breite am Ende,
## len darf negativ sein (Teil ragt nach oben, z. B. Torso).
static func _quad_points(shape: Dictionary) -> PackedVector2Array:
	if shape.has("p0"):
		return PackedVector2Array([shape["p0"], shape["p1"], shape["p2"], shape["p3"]])
	var w0: float = shape["w0"]
	var w1: float = shape.get("w1", w0)
	var l: float = shape["len"]
	var sx: float = shape.get("shift", 0.0)  # seitlicher Versatz des Endes
	return PackedVector2Array([
		Vector2(-w0 * 0.5, 0), Vector2(w0 * 0.5, 0),
		Vector2(w1 * 0.5 + sx, l), Vector2(-w1 * 0.5 + sx, l)])

## ---------- Rasterizer (Scanline, even-odd) ----------

static func _aw_poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var ymin := 99999.0
	var ymax := -99999.0
	for p in pts:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	for y in range(maxi(int(ymin), 0), mini(int(ymax) + 1, h)):
		var fy := float(y) + 0.5
		var xs: Array[float] = []
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			for x in range(maxi(int(round(xs[k])), 0), mini(int(round(xs[k + 1])), w)):
				img.set_pixel(x, y, col)
			k += 2

static func _aw_disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(int(c.y - r), 0), mini(int(c.y + r) + 2, h)):
		for x in range(maxi(int(c.x - r), 0), mini(int(c.x + r) + 2, w)):
			if Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length() <= r:
				img.set_pixel(x, y, col)

## ---------- Qualitäts-Validator ----------

## Zählt zusammenhängende Alpha-Inseln (4er-Nachbarschaft). Ein sauberes Rig
## liefert 1 — mehr bedeutet "Teile schweben in der Luft" (deklarierte
## Ausnahmen wie abgelöste Qualmwolken erlaubt der Aufrufer über max_parts).
static func count_parts(img: Image, min_px := 3) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var seen := {}
	var parts := 0
	for sy in h:
		for sx in w:
			var start := sy * w + sx
			if seen.has(start) or img.get_pixel(sx, sy).a < 0.01:
				continue
			# Flood-Fill über einen expliziten Stapel (kein Rekursionslimit).
			var stack: Array[int] = [start]
			seen[start] = true
			var count := 0
			while not stack.is_empty():
				var cur: int = stack.pop_back()
				count += 1
				var cx := cur % w
				var cy := cur / w
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := cx + d.x
					var ny := cy + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var idx := ny * w + nx
					if seen.has(idx) or img.get_pixel(nx, ny).a < 0.01:
						continue
					seen[idx] = true
					stack.append(idx)
			if count >= min_px:
				parts += 1
	return parts

## ---------- Parametrischer Humanoid-Bauer ----------
## Erzeugt Bones + Shapes einer Seitenansicht-Figur (blickt nach RECHTS).
## Gelenke werden durch Scheiben geschlossen; ferne Gliedmaßen sind dunkler
## (einfaches AW-Tiefensignal). cfg-Farben: skin, hair, hair_dk, top, top_dk,
## pants, pants_dk, boots. Maße über cfg (Defaults = erwachsene Figur).
static func humanoid(cfg: Dictionary) -> Dictionary:
	# Proportionen: schlank und ~5.5 Kopfhöhen groß (heroischer als die erste,
	# gedrungene Fassung). Kopf klein, Torso/Beine lang, Gliedmaßen dünn.
	var size: Vector2i = cfg.get("size", Vector2i(48, 62))
	var hip: Vector2 = cfg.get("hip", Vector2(24, 33))
	var torso_l: float = cfg.get("torso_len", 15.5)
	var arm_u: float = cfg.get("arm_upper", 10.5)
	var arm_l: float = cfg.get("arm_lower", 9.5)
	var leg_u: float = cfg.get("leg_upper", 13.0)
	var leg_l: float = cfg.get("leg_lower", 12.0)
	var head_r: float = cfg.get("head_r", 4.4)
	var arm_w: float = cfg.get("arm_w", 2.9)
	var leg_w: float = cfg.get("leg_w", 3.8)
	var skin: Color = cfg["skin"]
	var top: Color = cfg["top"]
	var top_dk: Color = cfg["top_dk"]
	var pants: Color = cfg["pants"]
	var pants_dk: Color = cfg["pants_dk"]
	var boots: Color = cfg["boots"]
	var far_mul: Color = Color(0.62, 0.60, 0.66)  # ferne Gliedmaßen abdunkeln
	var bones := {
		"root": {"parent": "", "pos": Vector2.ZERO},
		"torso": {"parent": "root", "pos": Vector2.ZERO},
		"head": {"parent": "torso", "pos": Vector2(0, -torso_l)},
		"arm_f_u": {"parent": "torso", "pos": Vector2(0, -torso_l + 1.5)},
		"arm_f_l": {"parent": "arm_f_u", "pos": Vector2(0, arm_u)},
		"arm_n_u": {"parent": "torso", "pos": Vector2(0, -torso_l + 1.5)},
		"arm_n_l": {"parent": "arm_n_u", "pos": Vector2(0, arm_u)},
		"leg_f_u": {"parent": "root", "pos": Vector2(-1.0, 0)},
		"leg_f_l": {"parent": "leg_f_u", "pos": Vector2(0, leg_u)},
		"leg_n_u": {"parent": "root", "pos": Vector2(1.0, 0)},
		"leg_n_l": {"parent": "leg_n_u", "pos": Vector2(0, leg_u)},
	}
	var hip_w: float = cfg.get("hip_w", 7.0)
	var sho_w: float = cfg.get("shoulder_w", 9.5)
	var s: Array = []
	# --- Ferne Gliedmaßen (hinter dem Rumpf) ---
	_limb(s, "arm_f_u", "arm_f_l", arm_u, arm_l, arm_w, arm_w * 0.78, top * far_mul, skin * far_mul, 1.8)
	_limb(s, "leg_f_u", "leg_f_l", leg_u, leg_l, leg_w, leg_w * 0.74, pants * far_mul, pants_dk * far_mul, 0.0)
	s.append({"bone": "leg_f_l", "kind": "poly", "col": boots * far_mul, "pts": PackedVector2Array([
		Vector2(-1.8, leg_l - 3.2), Vector2(1.8, leg_l - 3.2), Vector2(5.0, leg_l), Vector2(-1.8, leg_l)])})
	# --- Rumpf: schlankes Trapez (Schultern breiter) + dunkles Rückenband ---
	s.append({"bone": "torso", "kind": "quad", "col": top,
		"w0": hip_w, "w1": sho_w, "len": -torso_l - 2.0})
	s.append({"bone": "torso", "kind": "poly", "col": top_dk, "pts": PackedVector2Array([
		Vector2(-hip_w * 0.5, 0), Vector2(-hip_w * 0.5 + 2.2, 0),
		Vector2(-sho_w * 0.5 + 2.2, -torso_l - 2.0),
		Vector2(-sho_w * 0.5, -torso_l - 2.0)])})
	# Hüftpartie (Hose) über dem Beinansatz
	s.append({"bone": "root", "kind": "quad", "col": pants, "w0": hip_w, "w1": hip_w - 0.5, "len": 3.5})
	s.append({"bone": "root", "kind": "disc", "c": Vector2(-1.8, 1.0), "r": 2.7, "col": pants})
	s.append({"bone": "root", "kind": "disc", "c": Vector2(1.8, 1.0), "r": 2.7, "col": pants})
	# --- Kopf: schlanker Hals, kleiner Schädel, Haar (hinten), Gesichtsfläche ---
	s.append({"bone": "head", "kind": "quad", "col": skin, "w0": 2.8, "w1": 3.2, "len": -2.6})
	s.append({"bone": "head", "kind": "disc", "c": Vector2(0.4, -2.6 - head_r + 1.0), "r": head_r, "col": skin})
	if cfg.has("hair"):
		var hair: Color = cfg["hair"]
		var hy := -2.6 - head_r + 1.0
		# Haarkappe: obere Kopfhälfte + Hinterkopf, kleine Stirnkante
		s.append({"bone": "head", "kind": "poly", "col": hair, "pts": PackedVector2Array([
			Vector2(0.4 + head_r - 1.0, hy - 1.0), Vector2(0.4 + head_r * 0.6, hy - head_r + 0.4),
			Vector2(0.4 - head_r * 0.7, hy - head_r - 0.6), Vector2(0.4 - head_r - 1.6, hy - 1.2),
			Vector2(0.4 - head_r - 1.2, hy + head_r * 0.9), Vector2(0.4 - head_r + 1.2, hy + head_r * 0.5)])})
		s.append({"bone": "head", "kind": "poly", "col": cfg.get("hair_dk", hair.darkened(0.3)),
			"pts": PackedVector2Array([
				Vector2(0.4 - head_r - 1.4, hy - 0.8), Vector2(0.4 - head_r + 0.6, hy - 0.6),
				Vector2(0.4 - head_r + 1.0, hy + head_r * 0.6), Vector2(0.4 - head_r - 1.2, hy + head_r * 0.9)])})
	# --- Nahe Gliedmaßen (vor dem Rumpf) ---
	_limb(s, "leg_n_u", "leg_n_l", leg_u, leg_l, leg_w, leg_w * 0.74, pants, pants_dk, 0.0)
	s.append({"bone": "leg_n_l", "kind": "poly", "col": boots, "pts": PackedVector2Array([
		Vector2(-1.8, leg_l - 3.2), Vector2(1.8, leg_l - 3.2), Vector2(5.0, leg_l), Vector2(-1.8, leg_l)])})
	_limb(s, "arm_n_u", "arm_n_l", arm_u, arm_l, arm_w, arm_w * 0.78, top, skin, 1.8)
	return {"size": size, "origin": hip, "bones": bones, "shapes": s, "anims": {}}

## Zweigliedrige Gliedmaße: Ober-/Unterteil als Trapeze + Gelenk-/Endscheiben.
## Die Gelenkscheiben sind bewusst etwas größer als die Trapezbreite, damit
## sich bei starker Beugung nie ein Haarriss zwischen den Segmenten öffnet
## (der Zusammenhangs-Validator wäre sonst empfindlich).
static func _limb(s: Array, upper: String, lower: String, ul: float, ll: float,
		w0: float, w1: float, col_u: Color, col_l: Color, hand_r: float) -> void:
	s.append({"bone": upper, "kind": "disc", "c": Vector2.ZERO, "r": w0 * 0.62, "col": col_u})
	s.append({"bone": upper, "kind": "quad", "col": col_u, "w0": w0, "w1": w0 * 0.9, "len": ul})
	# Ellenbogen: Scheibe am Unterteil-Pivot UND am Oberteil-Ende → doppelt
	# abgedeckt, egal wie stark das Gelenk knickt.
	s.append({"bone": upper, "kind": "disc", "c": Vector2(0, ul), "r": w0 * 0.52, "col": col_u})
	s.append({"bone": lower, "kind": "disc", "c": Vector2.ZERO, "r": w0 * 0.56, "col": col_u})
	s.append({"bone": lower, "kind": "quad", "col": col_l, "w0": w0 * 0.9, "w1": w1, "len": ll})
	if hand_r > 0.0:
		s.append({"bone": lower, "kind": "disc", "c": Vector2(0, ll), "r": hand_r, "col": col_l})
