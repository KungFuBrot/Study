class_name AwRigs
extends AwRigsMonsters
## Helden-Rigs (Helen/Janosch/Wally) im AW-Flächenstil + öffentliche API,
## über die SpriteFactoryChars/SpriteFactory die gebackenen Frames beziehen.
## Teil der Kette: SpriteFactoryLib > AwRigEngine > AwRigsMonsters > AwRigs
## > SpriteFactoryChars > SpriteFactory.

## Gegner-IDs, die bereits als AW-Rig existieren (Milestone 0: Schlotwerk).
const AW_ENEMIES := {
	"schlammschleim": {"scale": 3.1}, "qualmgeist": {"scale": 3.0},
	"muellgnom": {"scale": 3.1}, "boss": {"scale": 2.35},
}
const AW_HEROES := ["serena", "milo", "rax"]

static var _rigs := {}

static func _rig(id: String) -> Dictionary:
	if _rigs.has(id):
		return _rigs[id]
	var rig: Dictionary
	match id:
		"serena": rig = _helen_rig()
		"milo": rig = _janosch_rig()
		"rax": rig = _wally_rig()
		"schlammschleim": rig = slime_rig()
		"qualmgeist": rig = wraith_rig()
		"muellgnom": rig = gnome_rig()
		"boss": rig = schlotbaron_rig()
		_: rig = slime_rig()
	_rigs[id] = rig
	return rig

## ---------- Öffentliche API ----------

static func aw_handles_hero(id: String) -> bool:
	return id in AW_HEROES

static func aw_handles_enemy(id: String) -> bool:
	return AW_ENEMIES.has(id)

static func aw_hero_frame(id: String, anim: String, frame: int) -> Texture2D:
	var rig := _rig(id)
	if not rig["anims"].has(anim):
		anim = "idle"
	return rig_tex("h_" + id, rig, anim, frame)

static func aw_enemy_tex(id: String, frame: int) -> Texture2D:
	return rig_tex("e_" + id, _rig(id), "idle", frame)

static func aw_enemy_scale(id: String) -> float:
	return AW_ENEMIES.get(id, {}).get("scale", 3.0)

## Frame-Anzahl einer Animation (für Abspiel-Schleifen im Kampf).
static func aw_anim_frames(id: String, anim: String) -> int:
	var rig := _rig(id)
	var adef: Dictionary = rig["anims"].get(anim, rig["anims"]["idle"])
	return int(adef["frames"])

static func aw_hero_has_anim(id: String, anim: String) -> bool:
	return aw_handles_hero(id) and _rig(id)["anims"].has(anim)

## ---------- Helen: Schwertkämpferin ----------

static func _helen_rig() -> Dictionary:
	var rig := humanoid({
		"size": Vector2i(48, 62), "hip": Vector2(24, 33),
		"skin": Color(0.97, 0.80, 0.66),
		"hair": Color(0.98, 0.80, 0.34), "hair_dk": Color(0.70, 0.52, 0.18),
		"top": Color(0.90, 0.30, 0.34), "top_dk": Color(0.58, 0.15, 0.19),
		"pants": Color(0.44, 0.38, 0.34), "pants_dk": Color(0.30, 0.25, 0.22),
		"boots": Color(0.52, 0.36, 0.22),
	})
	# Schwert an der nahen Faust: Parierstange, Klinge (nach oben), Knauf.
	rig["bones"]["weapon"] = {"parent": "arm_n_l", "pos": Vector2(0, 9.5)}
	var blade := Color(0.92, 0.96, 1.0)
	var blade_dk := Color(0.60, 0.68, 0.82)
	var gold := Color(0.95, 0.80, 0.38)
	rig["shapes"].append({"bone": "weapon", "kind": "poly", "col": gold, "pts": PackedVector2Array([
		Vector2(-3.0, -1.0), Vector2(3.0, -1.0), Vector2(3.0, 0.8), Vector2(-3.0, 0.8)])})
	rig["shapes"].append({"bone": "weapon", "kind": "quad", "col": blade, "w0": 2.4, "w1": 1.2, "len": -14.0})
	rig["shapes"].append({"bone": "weapon", "kind": "poly", "col": blade_dk, "pts": PackedVector2Array([
		Vector2(-1.2, -1.0), Vector2(-0.2, -1.0), Vector2(-0.2, -14.0), Vector2(-0.7, -14.0)])})
	rig["shapes"].append({"bone": "weapon", "kind": "disc", "c": Vector2(0, 2.0), "r": 1.4, "col": gold})
	# Kampfstellung: Klinge vor dem Körper, Beine gegrätscht. Die gesamte
	# Idle-Bewegung entsteht aus phasenversetzten Wellen (kein synchroner Snap)
	# → weiches, lebendiges "Atmen".
	var stance := {"leg_n_u": -0.16, "leg_n_l": 0.10, "leg_f_u": 0.18, "leg_f_l": 0.08,
		"arm_f_u": 0.16, "arm_f_l": -0.22}
	rig["anims"]["idle"] = {"frames": 16, "loop": true, "ease": true,
		"keys": [{"t": 0.0, "root": Vector2(0, 0.0), "j": _merge(stance, {"torso": 0.08,
			"head": 0.0, "arm_n_u": -0.40, "arm_n_l": -0.42, "weapon": 1.22})}],
		"waves": [
			{"bone": "root", "chan": "ry", "amp": 0.9, "freq": 1.0, "phase": 0.0},
			{"bone": "torso", "chan": "j", "amp": 0.035, "freq": 1.0, "phase": 0.12},
			{"bone": "head", "chan": "j", "amp": 0.06, "freq": 1.0, "phase": 0.40},
			{"bone": "arm_n_u", "chan": "j", "amp": 0.07, "freq": 1.0, "phase": 0.25},
			{"bone": "arm_n_l", "chan": "j", "amp": 0.06, "freq": 1.0, "phase": 0.55},
			{"bone": "arm_f_u", "chan": "j", "amp": 0.06, "freq": 1.0, "phase": 0.62},
			{"bone": "weapon", "chan": "j", "amp": 0.09, "freq": 1.0, "phase": 0.50},
		]}
	# Laufzyklus: Kontakt- und Passierposen, Arme gegenläufig, Klinge ruht.
	# 12 Frames + Sekundär-Wellen (Kopf/Klinge wippen im Doppeltakt).
	rig["anims"]["run"] = {"frames": 12, "loop": true, "ease": true,
		"waves": [
			{"bone": "head", "chan": "j", "amp": 0.04, "freq": 2.0, "phase": 0.1},
			{"bone": "weapon", "chan": "j", "amp": 0.10, "freq": 2.0, "phase": 0.0},
		], "keys": [
		{"t": 0.0, "root": Vector2(0, 0.8), "j": {"torso": 0.16, "head": -0.05,
			"leg_n_u": -0.85, "leg_n_l": 0.25, "leg_f_u": 0.75, "leg_f_l": 1.05,
			"arm_n_u": 0.65, "arm_n_l": -0.95, "arm_f_u": -0.75, "arm_f_l": -0.85, "weapon": 1.35}},
		{"t": 0.25, "root": Vector2(0, -1.4), "j": {"torso": 0.13, "head": -0.02,
			"leg_n_u": 0.15, "leg_n_l": 1.15, "leg_f_u": -0.30, "leg_f_l": 0.45,
			"arm_n_u": 0.10, "arm_n_l": -0.75, "arm_f_u": -0.20, "arm_f_l": -0.80, "weapon": 1.35}},
		{"t": 0.5, "root": Vector2(0, 0.8), "j": {"torso": 0.16, "head": -0.05,
			"leg_n_u": 0.75, "leg_n_l": 1.05, "leg_f_u": -0.85, "leg_f_l": 0.25,
			"arm_n_u": -0.75, "arm_n_l": -0.85, "arm_f_u": 0.65, "arm_f_l": -0.95, "weapon": 1.35}},
		{"t": 0.75, "root": Vector2(0, -1.4), "j": {"torso": 0.13, "head": -0.02,
			"leg_n_u": -0.30, "leg_n_l": 0.45, "leg_f_u": 0.15, "leg_f_l": 1.15,
			"arm_n_u": -0.20, "arm_n_l": -0.80, "arm_f_u": 0.10, "arm_f_l": -0.75, "weapon": 1.35}},
	]}
	# Schwerthieb: Ausholen über den Kopf, schneller Diagonalschnitt, Ausklang.
	rig["anims"]["attack"] = {"frames": 14, "loop": false, "ease": true, "keys": [
		{"t": 0.0, "root": Vector2(0, 0.3), "j": _merge(stance, {"torso": 0.06,
			"arm_n_u": -0.50, "arm_n_l": -0.55, "weapon": 0.60})},
		{"t": 0.30, "root": Vector2(-1.5, 0.5), "j": {"torso": -0.14, "head": 0.06,
			"leg_n_u": -0.25, "leg_n_l": 0.15, "leg_f_u": 0.32, "leg_f_l": 0.28,
			"arm_n_u": 2.85, "arm_n_l": -0.35, "weapon": -0.50,
			"arm_f_u": -0.50, "arm_f_l": -0.30}},
		{"t": 0.50, "root": Vector2(2.5, 1.0), "j": {"torso": 0.30, "head": -0.10,
			"leg_n_u": -0.50, "leg_n_l": 0.30, "leg_f_u": 0.65, "leg_f_l": 0.50,
			"arm_n_u": -1.05, "arm_n_l": -0.15, "weapon": 0.35,
			"arm_f_u": 0.50, "arm_f_l": -0.40}},
		{"t": 0.72, "root": Vector2(2.0, 1.2), "j": {"torso": 0.22, "head": -0.06,
			"leg_n_u": -0.50, "leg_n_l": 0.30, "leg_f_u": 0.65, "leg_f_l": 0.50,
			"arm_n_u": -1.35, "arm_n_l": -0.10, "weapon": 0.90,
			"arm_f_u": 0.45, "arm_f_l": -0.35}},
		{"t": 1.0, "root": Vector2(0, 0.3), "j": _merge(stance, {"torso": 0.06,
			"arm_n_u": -0.50, "arm_n_l": -0.55, "weapon": 0.60})},
	]}
	return rig

## ---------- Janosch: Magier mit Hut und Stab ----------

static func _janosch_rig() -> Dictionary:
	var robe := Color(0.32, 0.42, 0.86)
	var robe_dk := Color(0.20, 0.26, 0.60)
	var rig := humanoid({
		"size": Vector2i(48, 62), "hip": Vector2(24, 33),
		"skin": Color(0.94, 0.79, 0.65),
		"top": robe, "top_dk": robe_dk,
		"pants": Color(0.26, 0.24, 0.50), "pants_dk": Color(0.18, 0.16, 0.36),
		"boots": Color(0.32, 0.30, 0.40),
	})
	# Robensaum über den Oberschenkeln — VOR den nahen Gliedmaßen einfügen
	# (die letzten 8 Shapes des Builders sind nahes Bein/Stiefel/naher Arm).
	rig["shapes"].insert(rig["shapes"].size() - 8,
		{"bone": "root", "kind": "quad", "col": robe, "w0": 8.0, "w1": 11.0, "len": 10.0})
	rig["shapes"].insert(rig["shapes"].size() - 8,
		{"bone": "root", "kind": "poly", "col": robe_dk, "pts": PackedVector2Array([
			Vector2(-4.0, 0), Vector2(-1.8, 0), Vector2(-3.0, 10.0), Vector2(-5.5, 10.0)])})
	# Spitzhut mit Krempe (ersetzt Haar). hy = Kopfmitte (Neck -2.6, head_r 4.4).
	var hy := -2.6 - 4.4 + 1.0
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": robe_dk, "pts": PackedVector2Array([
		Vector2(0.4 - 7.6, hy + 0.6), Vector2(0.4 + 7.6, hy + 0.6),
		Vector2(0.4 + 6.2, hy - 1.8), Vector2(0.4 - 6.2, hy - 1.8)])})
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": robe, "pts": PackedVector2Array([
		Vector2(0.4 - 5.6, hy - 1.4), Vector2(0.4 + 5.6, hy - 1.4),
		Vector2(0.4 + 1.4, hy - 13.0), Vector2(0.4 - 1.0, hy - 13.0)])})
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": robe_dk, "pts": PackedVector2Array([
		Vector2(0.4 - 5.6, hy - 1.4), Vector2(0.4 - 2.4, hy - 1.4),
		Vector2(0.4 - 0.4, hy - 12.5), Vector2(0.4 - 1.0, hy - 13.0)])})
	# Stab in der nahen Hand: langer Stecken + Kristall-Orb
	rig["bones"]["weapon"] = {"parent": "arm_n_l", "pos": Vector2(0, 9.5)}
	rig["shapes"].append({"bone": "weapon", "kind": "quad", "col": Color(0.52, 0.36, 0.20),
		"w0": 1.8, "w1": 1.8, "len": 7.0})
	rig["shapes"].append({"bone": "weapon", "kind": "quad", "col": Color(0.52, 0.36, 0.20),
		"w0": 1.8, "w1": 1.5, "len": -16.0})
	rig["shapes"].append({"bone": "weapon", "kind": "disc", "c": Vector2(0, -17.5), "r": 2.8,
		"col": Color(0.45, 0.95, 1.0)})
	rig["shapes"].append({"bone": "weapon", "kind": "disc", "c": Vector2(0.6, -18.1), "r": 1.2,
		"col": Color(0.95, 1.0, 1.0)})
	var stance := {"leg_n_u": -0.10, "leg_n_l": 0.06, "leg_f_u": 0.12, "leg_f_l": 0.05,
		"arm_f_u": 0.12, "arm_f_l": -0.18}
	rig["anims"]["idle"] = {"frames": 16, "loop": true, "ease": true,
		"keys": [{"t": 0.0, "root": Vector2(0, 0.0), "j": _merge(stance, {"torso": 0.05,
			"head": 0.0, "arm_n_u": -0.20, "arm_n_l": -0.20, "weapon": 0.0})}],
		"waves": [
			{"bone": "root", "chan": "ry", "amp": 0.8, "freq": 1.0, "phase": 0.0},
			{"bone": "torso", "chan": "j", "amp": 0.03, "freq": 1.0, "phase": 0.15},
			{"bone": "head", "chan": "j", "amp": 0.05, "freq": 1.0, "phase": 0.42},
			{"bone": "arm_n_u", "chan": "j", "amp": 0.05, "freq": 1.0, "phase": 0.30},
			{"bone": "arm_n_l", "chan": "j", "amp": 0.05, "freq": 1.0, "phase": 0.58},
			{"bone": "arm_f_u", "chan": "j", "amp": 0.05, "freq": 1.0, "phase": 0.66},
			{"bone": "weapon", "chan": "j", "amp": 0.05, "freq": 1.0, "phase": 0.20},
		]}
	rig["anims"]["run"] = {"frames": 12, "loop": true, "ease": true,
		"waves": [{"bone": "head", "chan": "j", "amp": 0.04, "freq": 2.0, "phase": 0.1}], "keys": [
		{"t": 0.0, "root": Vector2(0, 0.8), "j": {"torso": 0.15, "head": -0.05,
			"leg_n_u": -0.80, "leg_n_l": 0.25, "leg_f_u": 0.70, "leg_f_l": 1.0,
			"arm_n_u": 0.35, "arm_n_l": -0.55, "weapon": 0.15, "arm_f_u": -0.65, "arm_f_l": -0.75}},
		{"t": 0.25, "root": Vector2(0, -1.3), "j": {"torso": 0.12, "head": -0.02,
			"leg_n_u": 0.15, "leg_n_l": 1.10, "leg_f_u": -0.28, "leg_f_l": 0.42,
			"arm_n_u": 0.10, "arm_n_l": -0.45, "weapon": 0.1, "arm_f_u": -0.15, "arm_f_l": -0.70}},
		{"t": 0.5, "root": Vector2(0, 0.8), "j": {"torso": 0.15, "head": -0.05,
			"leg_n_u": 0.70, "leg_n_l": 1.0, "leg_f_u": -0.80, "leg_f_l": 0.25,
			"arm_n_u": -0.45, "arm_n_l": -0.60, "weapon": 0.2, "arm_f_u": 0.55, "arm_f_l": -0.85}},
		{"t": 0.75, "root": Vector2(0, -1.3), "j": {"torso": 0.12, "head": -0.02,
			"leg_n_u": -0.28, "leg_n_l": 0.42, "leg_f_u": 0.15, "leg_f_l": 1.10,
			"arm_n_u": -0.15, "arm_n_l": -0.50, "weapon": 0.12, "arm_f_u": 0.10, "arm_f_l": -0.65}},
	]}
	# Beschwörung: beide Arme zum Himmel, Stab hoch, Robe im Zauberwind.
	# 10 Frames + Zittern (Stab bebt schnell, Kopf pendelt) = kraftvolles Kanalisieren.
	rig["anims"]["cast"] = {"frames": 10, "loop": true, "ease": true,
		"waves": [
			{"bone": "weapon", "chan": "j", "amp": 0.10, "freq": 3.0, "phase": 0.0},
			{"bone": "arm_n_u", "chan": "j", "amp": 0.05, "freq": 2.0, "phase": 0.2},
			{"bone": "head", "chan": "j", "amp": 0.04, "freq": 1.0, "phase": 0.3},
		], "keys": [
		{"t": 0.0, "root": Vector2(-0.5, 0.4), "j": _merge(stance, {"torso": -0.06, "head": 0.10,
			"arm_n_u": -2.55, "arm_n_l": -0.30, "weapon": 0.10, "arm_f_u": -2.30, "arm_f_l": -0.35})},
		{"t": 0.5, "root": Vector2(-0.5, -0.5), "j": _merge(stance, {"torso": -0.09, "head": 0.13,
			"arm_n_u": -2.70, "arm_n_l": -0.20, "weapon": -0.10, "arm_f_u": -2.45, "arm_f_l": -0.25})},
	]}
	return rig

## ---------- Wally: Kampfroboter ----------

static func _wally_rig() -> Dictionary:
	var metal_l := Color(0.74, 0.80, 0.88)
	var metal_m := Color(0.55, 0.62, 0.72)
	var metal_d := Color(0.34, 0.40, 0.50)
	var rig := humanoid({
		"size": Vector2i(48, 62), "hip": Vector2(24, 33),
		"skin": metal_l, "top": metal_m, "top_dk": metal_d,
		"pants": Color(0.46, 0.52, 0.62), "pants_dk": Color(0.30, 0.35, 0.44),
		"boots": Color(0.36, 0.40, 0.48),
		"head_r": 4.6, "shoulder_w": 10.5,
	})
	var hy := -2.6 - 4.6 + 1.0
	# Antenne mit roter Blinkspitze. Basis tief in die Schädelkuppe gezogen
	# (bis hy-1.5), damit sie sich bei Kopfdrehung nie ablöst.
	rig["shapes"].append({"bone": "head", "kind": "quad", "col": metal_d,
		"w0": 1.2, "w1": 1.0, "len": -4.5, "p0": Vector2(-1.8, hy - 1.5), "p1": Vector2(-0.4, hy - 1.5),
		"p2": Vector2(-0.4, hy - 10.4), "p3": Vector2(-1.8, hy - 10.4)})
	rig["shapes"].append({"bone": "head", "kind": "disc", "c": Vector2(-1.1, hy - 10.6), "r": 1.5,
		"col": Color(1.0, 0.40, 0.32)})
	# Visor: dunkles Band mit cyanem Scan-Schlitz (Front = rechts)
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": Color(0.14, 0.17, 0.24),
		"pts": PackedVector2Array([
			Vector2(0.4 - 1.0, hy - 2.4), Vector2(0.4 + 5.4, hy - 1.8),
			Vector2(0.4 + 5.4, hy + 1.6), Vector2(0.4 - 1.0, hy + 2.0)])})
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": Color(0.45, 0.96, 1.0),
		"pts": PackedVector2Array([
			Vector2(0.4 + 0.4, hy - 0.8), Vector2(0.4 + 4.6, hy - 0.5),
			Vector2(0.4 + 4.6, hy + 0.5), Vector2(0.4 + 0.4, hy + 0.6)])})
	# Warmer Brustkern
	rig["shapes"].append({"bone": "torso", "kind": "disc", "c": Vector2(1.5, -7.0), "r": 2.6,
		"col": Color(1.0, 0.72, 0.32)})
	rig["shapes"].append({"bone": "torso", "kind": "disc", "c": Vector2(1.5, -7.0), "r": 1.2,
		"col": Color(1.0, 0.92, 0.66)})
	# Kanonenlauf an der nahen Hand (über die Faust hinaus verlängert)
	rig["shapes"].append({"bone": "arm_n_l", "kind": "quad", "col": metal_d,
		"w0": 4.4, "w1": 3.8, "len": 8.5, "p0": Vector2(-2.2, 6.0), "p1": Vector2(2.2, 6.0),
		"p2": Vector2(1.9, 15.0), "p3": Vector2(-1.9, 15.0)})
	rig["shapes"].append({"bone": "arm_n_l", "kind": "disc", "c": Vector2(0, 15.0), "r": 1.6,
		"col": Color(0.45, 0.96, 1.0)})
	# Roboter: mechanischeres Idle (kleinere Amplitude, aber Servo-Zittern
	# im Doppeltakt am Arm) — wirkt wie eine unter Strom stehende Maschine.
	var stance := {"leg_n_u": -0.12, "leg_n_l": 0.08, "leg_f_u": 0.14, "leg_f_l": 0.06,
		"arm_f_u": 0.14, "arm_f_l": -0.20}
	rig["anims"]["idle"] = {"frames": 16, "loop": true, "ease": true,
		"keys": [{"t": 0.0, "root": Vector2(0, 0.0), "j": _merge(stance, {"torso": 0.04,
			"head": 0.0, "arm_n_u": 0.13, "arm_n_l": -0.33})}],
		"waves": [
			{"bone": "root", "chan": "ry", "amp": 0.5, "freq": 1.0, "phase": 0.0},
			{"bone": "head", "chan": "j", "amp": 0.04, "freq": 1.0, "phase": 0.35},
			{"bone": "arm_n_u", "chan": "j", "amp": 0.05, "freq": 2.0, "phase": 0.1},
			{"bone": "arm_n_l", "chan": "j", "amp": 0.04, "freq": 2.0, "phase": 0.5},
			{"bone": "arm_f_u", "chan": "j", "amp": 0.04, "freq": 1.0, "phase": 0.6},
		]}
	rig["anims"]["run"] = {"frames": 12, "loop": true, "ease": true, "keys": [
		{"t": 0.0, "root": Vector2(0, 0.8), "j": {"torso": 0.18, "head": -0.06,
			"leg_n_u": -0.85, "leg_n_l": 0.25, "leg_f_u": 0.75, "leg_f_l": 1.05,
			"arm_n_u": 0.60, "arm_n_l": -0.90, "arm_f_u": -0.70, "arm_f_l": -0.85}},
		{"t": 0.25, "root": Vector2(0, -1.4), "j": {"torso": 0.15, "head": -0.03,
			"leg_n_u": 0.15, "leg_n_l": 1.15, "leg_f_u": -0.30, "leg_f_l": 0.45,
			"arm_n_u": 0.10, "arm_n_l": -0.70, "arm_f_u": -0.18, "arm_f_l": -0.78}},
		{"t": 0.5, "root": Vector2(0, 0.8), "j": {"torso": 0.18, "head": -0.06,
			"leg_n_u": 0.75, "leg_n_l": 1.05, "leg_f_u": -0.85, "leg_f_l": 0.25,
			"arm_n_u": -0.70, "arm_n_l": -0.82, "arm_f_u": 0.60, "arm_f_l": -0.92}},
		{"t": 0.75, "root": Vector2(0, -1.4), "j": {"torso": 0.15, "head": -0.03,
			"leg_n_u": -0.30, "leg_n_l": 0.45, "leg_f_u": 0.15, "leg_f_l": 1.15,
			"arm_n_u": -0.18, "arm_n_l": -0.75, "arm_f_u": 0.10, "arm_f_l": -0.70}},
	]}
	# Schützenstand: Kanone waagerecht auf die Gegner gerichtet, leichtes
	# Rückstoß-Zittern des Laufs (schneller Servo-Wave am Unterarm).
	rig["anims"]["aim"] = {"frames": 8, "loop": true, "ease": true,
		"waves": [{"bone": "arm_n_l", "chan": "j", "amp": 0.05, "freq": 3.0, "phase": 0.0}],
		"keys": [
		{"t": 0.0, "root": Vector2(1.0, 0.6), "j": {"torso": 0.10, "head": 0.02,
			"leg_n_u": -0.38, "leg_n_l": 0.22, "leg_f_u": 0.45, "leg_f_l": 0.30,
			"arm_n_u": -1.62, "arm_n_l": 0.02, "arm_f_u": -1.10, "arm_f_l": -0.62}},
		{"t": 0.5, "root": Vector2(1.0, 0.9), "j": {"torso": 0.11, "head": 0.02,
			"leg_n_u": -0.38, "leg_n_l": 0.22, "leg_f_u": 0.45, "leg_f_l": 0.30,
			"arm_n_u": -1.58, "arm_n_l": 0.0, "arm_f_u": -1.06, "arm_f_l": -0.60}},
	]}
	return rig

## Basis-Pose + Abweichungen zusammenführen (Abweichungen gewinnen).
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k in over:
		out[k] = over[k]
	return out
