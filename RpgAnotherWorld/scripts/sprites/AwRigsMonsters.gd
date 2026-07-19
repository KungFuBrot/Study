class_name AwRigsMonsters
extends AwRigEngine
## AW-Flächen-Rigs der Schlotwerk-Gegner: Schlotbaron (Boss), Sludge Slime,
## Smog Wraith, Scrap Gnome. Alle blicken nach RECHTS (zu den Helden).
## Teil der Kette: SpriteFactoryLib > AwRigEngine > AwRigsMonsters > AwRigs
## > SpriteFactoryChars > SpriteFactory.
##
## WICHTIG (Pilot-Lehre): Farben ~2x heller anlegen als "richtig" wirkend —
## CanvasModulate-Ambiente (~0.65), Monster-Tint (~0.8) und Vignette dimmen.

## ---------- Schlotbaron: massiger Industrie-Schlamm-Koloss ----------
## Silhouette: Buckel oben links, Schädel ragt tief nach rechts zu den Helden,
## zwei qualmende Schlote auf dem Rücken, Ofenrost glüht in der Brust, der
## Unterleib ist eine zähe Schlammglocke (er ist aus dem Klärbecken gestiegen).

static func schlotbaron_rig() -> Dictionary:
	var body := Color(0.44, 0.52, 0.46)      # Grundmasse
	var body_dk := Color(0.30, 0.36, 0.32)   # Schattenseite
	var body_dp := Color(0.20, 0.25, 0.22)   # tiefster Ton (Bauchseite, Maulhöhle)
	var rim := Color(0.74, 0.90, 0.80)       # kalte Mondlicht-Rückenkante
	var metal := Color(0.36, 0.40, 0.44)     # Schlot-Rohre
	var metal_l := Color(0.58, 0.65, 0.70)
	var smoke := Color(0.56, 0.64, 0.59)
	var smoke2 := Color(0.45, 0.53, 0.48)
	var tox := Color(0.62, 1.0, 0.38)        # Giftglühen
	var tox_hot := Color(0.86, 1.0, 0.72)
	var sludge := Color(0.36, 0.44, 0.38)
	var bones := {
		"root": {"parent": "", "pos": Vector2.ZERO},
		"torso": {"parent": "root", "pos": Vector2(0, -8)},
		"head": {"parent": "torso", "pos": Vector2(24, -46)},
		"jaw": {"parent": "head", "pos": Vector2(16, 6)},
		"arm_f_u": {"parent": "torso", "pos": Vector2(-16, -40)},
		"arm_f_l": {"parent": "arm_f_u", "pos": Vector2(0, 22)},
		"arm_n_u": {"parent": "torso", "pos": Vector2(24, -34)},
		"arm_n_l": {"parent": "arm_n_u", "pos": Vector2(0, 21)},
		"stack1": {"parent": "torso", "pos": Vector2(-14, -52)},
		"stack2": {"parent": "torso", "pos": Vector2(-32, -40)},
		"puff1": {"parent": "stack1", "pos": Vector2(0, -16)},
		"puff2": {"parent": "stack2", "pos": Vector2(0, -14)},
	}
	var s: Array = []
	# --- Ferner Arm (hinter dem Rumpf, dunkel) ---
	s.append({"bone": "arm_f_u", "kind": "disc", "c": Vector2.ZERO, "r": 7.0, "col": body_dk})
	s.append({"bone": "arm_f_u", "kind": "quad", "col": body_dk, "w0": 13.0, "w1": 10.0, "len": 22.0})
	s.append({"bone": "arm_f_l", "kind": "disc", "c": Vector2.ZERO, "r": 5.0, "col": body_dk})
	s.append({"bone": "arm_f_l", "kind": "quad", "col": body_dp, "w0": 10.0, "w1": 8.0, "len": 18.0})
	s.append({"bone": "arm_f_l", "kind": "disc", "c": Vector2(0, 18), "r": 4.5, "col": body_dp})
	# --- Schlote auf dem Buckel (hinter dem Rumpf gezeichnet, im Rumpf verankert) ---
	for st: Array in [["stack1", 9.0, 16.0], ["stack2", 8.0, 14.0]]:
		s.append({"bone": st[0], "kind": "quad", "col": metal, "w0": st[1], "w1": st[1] * 0.92, "len": -st[2] - 6.0})
		s.append({"bone": st[0], "kind": "poly", "col": metal_l, "pts": PackedVector2Array([
			Vector2(st[1] * 0.5 - 2.0, -st[2] - 6.0), Vector2(st[1] * 0.5, -st[2] - 6.0),
			Vector2(st[1] * 0.5, 2.0), Vector2(st[1] * 0.5 - 2.0, 2.0)])})
		# Mündungsrand (oben am Rohr)
		var mw: float = st[1] * 0.5 + 1.0
		var my: float = -st[2] - 6.0
		s.append({"bone": st[0], "kind": "poly", "col": metal_l, "pts": PackedVector2Array([
			Vector2(-mw, my), Vector2(mw, my), Vector2(mw, my + 3.0), Vector2(-mw, my + 3.0)])})
	# Qualm: überlappt die Schlotmündungen (bleibt EIN zusammenhängendes Teil)
	s.append({"bone": "puff1", "kind": "disc", "c": Vector2(0, 2), "r": 6.0, "col": smoke2})
	s.append({"bone": "puff1", "kind": "disc", "c": Vector2(2, -4), "r": 4.5, "col": smoke})
	s.append({"bone": "puff2", "kind": "disc", "c": Vector2(0, 2), "r": 5.0, "col": smoke2})
	s.append({"bone": "puff2", "kind": "disc", "c": Vector2(2, -3), "r": 3.6, "col": smoke})
	# --- Rumpf: massiger Buckel, Kopf-Ansatz rechts ---
	s.append({"bone": "torso", "kind": "poly", "col": body, "pts": PackedVector2Array([
		Vector2(-42, -6), Vector2(-40, -34), Vector2(-24, -52), Vector2(-2, -60),
		Vector2(16, -56), Vector2(28, -44), Vector2(32, -28), Vector2(28, -8),
		Vector2(16, 6), Vector2(-24, 8)])})
	# Mondbeschienene Rückenkante (macht den AW-Look) + zweite Lichtstufe
	s.append({"bone": "torso", "kind": "poly", "col": rim, "pts": PackedVector2Array([
		Vector2(-40, -34), Vector2(-24, -52), Vector2(-2, -60), Vector2(16, -56),
		Vector2(12, -52), Vector2(-4, -55), Vector2(-22, -47), Vector2(-36, -31)])})
	s.append({"bone": "torso", "kind": "poly", "col": body_dk, "pts": PackedVector2Array([
		Vector2(-42, -6), Vector2(-40, -34), Vector2(-32, -30), Vector2(-32, -6),
		Vector2(-26, 6), Vector2(-24, 8)])})
	# --- Ofenrost in der Brust: Panel + 3 Glutschlitze + heißer Kern ---
	s.append({"bone": "torso", "kind": "poly", "col": body_dp, "pts": PackedVector2Array([
		Vector2(8, -34), Vector2(26, -30), Vector2(28, -12), Vector2(10, -10)])})
	for i in 3:
		var sy := -29.0 + i * 6.0
		s.append({"bone": "torso", "kind": "poly", "col": tox, "pts": PackedVector2Array([
			Vector2(11, sy), Vector2(25, sy + 1.4), Vector2(25, sy + 3.4), Vector2(11, sy + 2.4)])})
	s.append({"bone": "torso", "kind": "poly", "col": tox_hot, "pts": PackedVector2Array([
		Vector2(15, -23.4), Vector2(21, -22.6), Vector2(21, -20.9), Vector2(15, -21.6)])})
	# --- Kopf: gesenkter Schädel, ragt zu den Helden ---
	s.append({"bone": "head", "kind": "poly", "col": body, "pts": PackedVector2Array([
		Vector2(-8, -12), Vector2(10, -14), Vector2(26, -8), Vector2(32, 0),
		Vector2(28, 6), Vector2(12, 9), Vector2(-6, 8), Vector2(-10, -2)])})
	s.append({"bone": "head", "kind": "poly", "col": rim, "pts": PackedVector2Array([
		Vector2(-8, -12), Vector2(10, -14), Vector2(26, -8), Vector2(22, -6),
		Vector2(8, -11), Vector2(-6, -9)])})
	# Stirnwulst über dem Auge (Schattenfläche)
	s.append({"bone": "head", "kind": "poly", "col": body_dk, "pts": PackedVector2Array([
		Vector2(6, -8), Vector2(26, -4), Vector2(28, 0), Vector2(6, -3)])})
	# Glühendes Auge: Keil + heller Kern
	s.append({"bone": "head", "kind": "poly", "col": tox, "pts": PackedVector2Array([
		Vector2(12, -3), Vector2(24, -1), Vector2(24, 2), Vector2(13, 0)])})
	s.append({"bone": "head", "kind": "poly", "col": tox_hot, "pts": PackedVector2Array([
		Vector2(15, -2), Vector2(21, -0.6), Vector2(21, 0.8), Vector2(15, -0.4)])})
	# --- Unterkiefer + Gift-Sabber ---
	s.append({"bone": "jaw", "kind": "poly", "col": body_dk, "pts": PackedVector2Array([
		Vector2(-10, -1), Vector2(14, -2), Vector2(13, 5), Vector2(-8, 6)])})
	s.append({"bone": "jaw", "kind": "poly", "col": tox, "pts": PackedVector2Array([
		Vector2(7, 4), Vector2(10, 4), Vector2(9, 12), Vector2(8, 12)])})
	s.append({"bone": "jaw", "kind": "disc", "c": Vector2(8.5, 12), "r": 1.6, "col": tox})
	# --- Naher Arm: wuchtig, mit Dreiklauen-Pranke ---
	s.append({"bone": "arm_n_u", "kind": "disc", "c": Vector2.ZERO, "r": 8.0, "col": body})
	s.append({"bone": "arm_n_u", "kind": "quad", "col": body, "w0": 15.0, "w1": 11.0, "len": 21.0})
	s.append({"bone": "arm_n_u", "kind": "poly", "col": rim, "pts": PackedVector2Array([
		Vector2(5.5, 0), Vector2(7.5, 0), Vector2(5.5, 21.0), Vector2(3.8, 21.0)])})
	s.append({"bone": "arm_n_l", "kind": "disc", "c": Vector2.ZERO, "r": 5.5, "col": body})
	s.append({"bone": "arm_n_l", "kind": "quad", "col": body_dk, "w0": 11.0, "w1": 9.0, "len": 17.0})
	s.append({"bone": "arm_n_l", "kind": "disc", "c": Vector2(0, 17), "r": 5.0, "col": body_dk})
	for i in 3:
		var fx := -4.0 + i * 4.0
		s.append({"bone": "arm_n_l", "kind": "poly", "col": body_dp, "pts": PackedVector2Array([
			Vector2(fx - 1.6, 15.0), Vector2(fx + 1.6, 15.0), Vector2(fx + 0.6, 24.0), Vector2(fx - 0.6, 24.0)])})
	# --- Schlammglocke statt Beinen (er steckt im eigenen Morast) ---
	s.append({"bone": "root", "kind": "poly", "col": sludge, "pts": PackedVector2Array([
		Vector2(-30, 0), Vector2(20, 0), Vector2(30, 10), Vector2(36, 22),
		Vector2(30, 26), Vector2(-34, 26), Vector2(-40, 20), Vector2(-36, 8)])})
	s.append({"bone": "root", "kind": "poly", "col": body_dp, "pts": PackedVector2Array([
		Vector2(-30, 0), Vector2(20, 0), Vector2(26, 6), Vector2(-34, 6)])})
	# Giftpfützen-Streifen am Saum
	s.append({"bone": "root", "kind": "poly", "col": tox, "pts": PackedVector2Array([
		Vector2(-24, 24), Vector2(-6, 23), Vector2(-8, 26), Vector2(-22, 26)])})
	s.append({"bone": "root", "kind": "poly", "col": tox, "pts": PackedVector2Array([
		Vector2(10, 25), Vector2(26, 24), Vector2(24, 27), Vector2(12, 27)])})
	var rig := {"size": Vector2i(124, 124), "origin": Vector2(58, 92), "bones": bones,
		"shapes": s, "anims": {}}
	# Idle: schweres Heben und Senken der Masse, Kopf nickt gegenläufig, die
	# Pranke pendelt, der Qualm quillt gegenphasig aus den Schloten.
	rig["anims"]["idle"] = {"frames": 8, "loop": true, "ease": true, "keys": [
		{"t": 0.0, "root": Vector2(0, 0), "j": {"torso": 0.0, "head": 0.02, "jaw": 0.0,
			"arm_n_u": -0.04, "arm_n_l": 0.05, "arm_f_u": 0.03},
			"off": {"puff1": Vector2(0, 0), "puff2": Vector2(1.5, -2.0)}},
		{"t": 0.5, "root": Vector2(0, 2.0), "j": {"torso": 0.025, "head": -0.05, "jaw": 0.06,
			"arm_n_u": 0.05, "arm_n_l": -0.04, "arm_f_u": -0.03},
			"off": {"puff1": Vector2(1.5, -2.5), "puff2": Vector2(0, 0)}},
	]}
	return rig

## ---------- Sludge Slime: zäher Giftschlamm-Blob ----------

static func slime_rig() -> Dictionary:
	var base := Color(0.58, 0.76, 0.46)
	var dk := Color(0.42, 0.58, 0.34)
	var dp := Color(0.28, 0.42, 0.24)
	var shine := Color(0.76, 0.94, 0.60)
	var tox := Color(0.80, 1.0, 0.50)
	var eye_dk := Color(0.10, 0.16, 0.08)
	var bones := {
		"root": {"parent": "", "pos": Vector2.ZERO},
		"crest": {"parent": "root", "pos": Vector2(-1, -12)},
		"lump": {"parent": "root", "pos": Vector2(-12, -4)},
	}
	var s: Array = []
	# Basispfütze (breiter als der Körper — er zerläuft)
	s.append({"bone": "root", "kind": "poly", "col": dp, "pts": PackedVector2Array([
		Vector2(-20, -3), Vector2(19, -3), Vector2(22, 1), Vector2(-23, 1)])})
	# Hauptmasse
	s.append({"bone": "root", "kind": "poly", "col": base, "pts": PackedVector2Array([
		Vector2(-17, -1), Vector2(-19, -7), Vector2(-13, -13), Vector2(-4, -16),
		Vector2(6, -15), Vector2(13, -11), Vector2(17, -5), Vector2(18, -1)])})
	# Schattenseite links
	s.append({"bone": "root", "kind": "poly", "col": dk, "pts": PackedVector2Array([
		Vector2(-17, -1), Vector2(-19, -7), Vector2(-13, -13), Vector2(-10, -11),
		Vector2(-14, -6), Vector2(-13, -1)])})
	# Atmende Kuppe (überlappt die Hauptmasse, bewegt sich mit "crest")
	s.append({"bone": "crest", "kind": "poly", "col": base, "pts": PackedVector2Array([
		Vector2(-10, 6), Vector2(-11, -1), Vector2(-5, -5), Vector2(3, -4),
		Vector2(9, 0), Vector2(10, 6)])})
	s.append({"bone": "crest", "kind": "poly", "col": shine, "pts": PackedVector2Array([
		Vector2(-8, -1), Vector2(-5, -4), Vector2(1, -3.4), Vector2(-3, -0.5)])})
	# Augen auf der Kuppe (dunkle Höhlen + Giftglühen)
	s.append({"bone": "crest", "kind": "disc", "c": Vector2(1, 1), "r": 2.2, "col": eye_dk})
	s.append({"bone": "crest", "kind": "disc", "c": Vector2(7, 2), "r": 1.9, "col": eye_dk})
	s.append({"bone": "crest", "kind": "disc", "c": Vector2(1.4, 0.7), "r": 0.9, "col": tox})
	s.append({"bone": "crest", "kind": "disc", "c": Vector2(7.3, 1.7), "r": 0.8, "col": tox})
	# Seitlicher Tropf-Lappen (schwappt eigenständig, bleibt verbunden)
	s.append({"bone": "lump", "kind": "poly", "col": dk, "pts": PackedVector2Array([
		Vector2(-4, 3), Vector2(-6, -3), Vector2(-1, -6), Vector2(4, -3), Vector2(5, 3)])})
	var rig := {"size": Vector2i(48, 40), "origin": Vector2(24, 36), "bones": bones,
		"shapes": s, "anims": {}}
	rig["anims"]["idle"] = {"frames": 6, "loop": true, "ease": true, "keys": [
		{"t": 0.0, "off": {"crest": Vector2(0, 0), "lump": Vector2(0, 0)}},
		{"t": 0.5, "off": {"crest": Vector2(0.8, 2.2), "lump": Vector2(-1.0, 1.2)}},
	]}
	return rig

## ---------- Smog Wraith: schwebender Qualmgeist ----------

static func wraith_rig() -> Dictionary:
	var body := Color(0.68, 0.74, 0.76)
	var dk := Color(0.50, 0.57, 0.60)
	var dp := Color(0.34, 0.40, 0.44)
	var glow := Color(0.84, 1.0, 0.55)
	var bones := {
		"root": {"parent": "", "pos": Vector2.ZERO},
		"tail": {"parent": "root", "pos": Vector2(0, -2)},
		"body": {"parent": "tail", "pos": Vector2(0, -14)},
		"head": {"parent": "body", "pos": Vector2(1, -11)},
		"arm_n": {"parent": "body", "pos": Vector2(4, -8)},
		"arm_f": {"parent": "body", "pos": Vector2(-4, -8)},
	}
	var s: Array = []
	# Ferner Rauch-Arm
	s.append({"bone": "arm_f", "kind": "disc", "c": Vector2.ZERO, "r": 2.6, "col": dk})
	s.append({"bone": "arm_f", "kind": "quad", "col": dk, "w0": 5.0, "w1": 2.4, "len": 10.0, "shift": -2.0})
	# Rauchschweif (unten auslaufend, gekrümmt)
	s.append({"bone": "tail", "kind": "poly", "col": dk, "pts": PackedVector2Array([
		Vector2(-7, -14), Vector2(7, -14), Vector2(5, -6), Vector2(8, -1),
		Vector2(3, 1), Vector2(-2, -2), Vector2(-6, -6)])})
	s.append({"bone": "tail", "kind": "poly", "col": dp, "pts": PackedVector2Array([
		Vector2(5, -6), Vector2(8, -1), Vector2(3, 1), Vector2(1, -3)])})
	# Rumpf-Kutte
	s.append({"bone": "body", "kind": "poly", "col": body, "pts": PackedVector2Array([
		Vector2(-8, -12), Vector2(8, -12), Vector2(10, -2), Vector2(7, 2),
		Vector2(-6, 2), Vector2(-9, -4)])})
	s.append({"bone": "body", "kind": "poly", "col": dk, "pts": PackedVector2Array([
		Vector2(-8, -12), Vector2(-4, -12), Vector2(-5, 1), Vector2(-6, 2), Vector2(-9, -4)])})
	# Kapuzenkopf mit dunkler Gesichtshöhle + Glühaugen
	s.append({"bone": "head", "kind": "disc", "c": Vector2(0, -3), "r": 6.5, "col": body})
	s.append({"bone": "head", "kind": "poly", "col": dp, "pts": PackedVector2Array([
		Vector2(1, -8), Vector2(6, -5), Vector2(6, 0), Vector2(1, 2)])})
	s.append({"bone": "head", "kind": "disc", "c": Vector2(3.2, -4.2), "r": 1.1, "col": glow})
	s.append({"bone": "head", "kind": "disc", "c": Vector2(5.4, -3.4), "r": 0.9, "col": glow})
	# Naher Rauch-Arm (greift nach vorn)
	s.append({"bone": "arm_n", "kind": "disc", "c": Vector2.ZERO, "r": 2.8, "col": body})
	s.append({"bone": "arm_n", "kind": "quad", "col": body, "w0": 5.4, "w1": 2.6, "len": 11.0, "shift": 3.0})
	s.append({"bone": "arm_n", "kind": "disc", "c": Vector2(3.0, 11.0), "r": 2.0, "col": body})
	var rig := {"size": Vector2i(44, 48), "origin": Vector2(21, 44), "bones": bones,
		"shapes": s, "anims": {}}
	# Schweben: auf und ab, Schweif pendelt gegenphasig, Arme wogen.
	rig["anims"]["idle"] = {"frames": 8, "loop": true, "ease": true, "keys": [
		{"t": 0.0, "root": Vector2(0, 0), "j": {"tail": 0.06, "body": -0.03,
			"arm_n": -0.15, "arm_f": 0.10, "head": 0.02}},
		{"t": 0.5, "root": Vector2(0, -3.0), "j": {"tail": -0.08, "body": 0.03,
			"arm_n": 0.10, "arm_f": -0.12, "head": -0.03}},
	]}
	return rig

## ---------- Scrap Gnome: kleiner Müllsammler mit Topfhelm ----------

static func gnome_rig() -> Dictionary:
	var rig := humanoid({
		"size": Vector2i(40, 44), "hip": Vector2(19, 26),
		"torso_len": 9.0, "arm_upper": 7.0, "arm_lower": 6.5,
		"leg_upper": 7.5, "leg_lower": 7.0, "head_r": 5.4,
		"hip_w": 9.0, "shoulder_w": 10.0,
		"skin": Color(0.78, 0.84, 0.62),
		"top": Color(0.58, 0.51, 0.40), "top_dk": Color(0.42, 0.36, 0.28),
		"pants": Color(0.46, 0.41, 0.33), "pants_dk": Color(0.33, 0.29, 0.24),
		"boots": Color(0.40, 0.34, 0.26),
	})
	# Topfhelm (rostiges Metall) über dem Schädel + Nietenkante
	var hy := -3.0 - 5.4 + 1.0
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": Color(0.60, 0.53, 0.46),
		"pts": PackedVector2Array([
			Vector2(0.4 - 6.6, hy - 0.5), Vector2(0.4 - 5.0, hy - 5.8), Vector2(0.4 + 5.4, hy - 5.6),
			Vector2(0.4 + 6.8, hy - 0.5), Vector2(0.4 + 7.6, hy + 0.8), Vector2(0.4 - 7.4, hy + 0.8)])})
	rig["shapes"].append({"bone": "head", "kind": "poly", "col": Color(0.76, 0.68, 0.57),
		"pts": PackedVector2Array([
			Vector2(0.4 - 5.0, hy - 5.8), Vector2(0.4 + 5.4, hy - 5.6),
			Vector2(0.4 + 4.6, hy - 4.6), Vector2(0.4 - 4.2, hy - 4.8)])})
	# Glühende Gift-Schutzbrille
	rig["shapes"].append({"bone": "head", "kind": "disc", "c": Vector2(3.4, hy - 0.6), "r": 1.4,
		"col": Color(0.85, 1.0, 0.55)})
	# Schrott-Sack über der fernen Schulter
	rig["shapes"].insert(0, {"bone": "torso", "kind": "poly", "col": Color(0.42, 0.39, 0.33),
		"pts": PackedVector2Array([
			Vector2(-3, -9), Vector2(-12, -13), Vector2(-15, -6), Vector2(-11, 0), Vector2(-4, -1)])})
	rig["anims"]["idle"] = {"frames": 6, "loop": true, "ease": true, "keys": [
		{"t": 0.0, "root": Vector2(0, 0.4), "j": {"torso": 0.05, "head": -0.03,
			"arm_n_u": 0.10, "arm_n_l": -0.25, "arm_f_u": -0.06,
			"leg_n_u": -0.10, "leg_n_l": 0.06, "leg_f_u": 0.12, "leg_f_l": 0.05}},
		{"t": 0.5, "root": Vector2(0, -0.4), "j": {"torso": 0.01, "head": 0.03,
			"arm_n_u": 0.16, "arm_n_l": -0.32, "arm_f_u": -0.10,
			"leg_n_u": -0.10, "leg_n_l": 0.06, "leg_f_u": 0.12, "leg_f_l": 0.05}},
	]}
	return rig
