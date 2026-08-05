class_name BattleHeroActions
extends BattleDamage
## Aktionen von Helen (Klingen-Skills) und Janosch (Feuer, Heilung, Meteor)
## samt zugehoeriger Spezial-Effekte.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

func _hero_attack(h: Dictionary, e: Dictionary) -> void:
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	_say("%s attacks!" % h["data"]["name"])
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	# 1) Ausholen: zurücklehnen, Waffe über die Schulter reißen (Anticipation),
	# dazu ein kurzer Glanzblitz auf der Klinge.
	_weapon_glint(wp)
	var wind := create_tween()
	wind.tween_property(s, "rotation", 0.16, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wind.parallel().tween_property(s, "scale", base * Vector2(0.94, 1.07), 0.13)
	if wp != null:
		wind.parallel().tween_property(wp, "rotation", 2.0, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await wind.finished
	# 2) Sprint zum Gegner: nach vorn lehnen, Lauf-Frames, Geistertrail.
	var strike_pos: Vector2 = es.position + Vector2(_strike_offset(e), 0)
	var lean := create_tween()
	lean.tween_property(s, "rotation", -0.10, 0.16)
	lean.parallel().tween_property(s, "scale", base, 0.16)
	await _sprint(h, strike_pos, 0.16)
	_pose(h, "attack", 0.55)
	# 3) Kombo, Schlag 1: Waffe schwingt in einem Ruck durch den Gegner (mit
	# Nachbildern), der Körper macht einen Ausfallschritt hinterher.
	if wp != null:
		_weapon_trail(wp, 0.12)
		var swing := create_tween()
		swing.tween_property(wp, "rotation", -1.9, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var lunge := create_tween()
	lunge.tween_property(s, "position:x", strike_pos.x - 12.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.parallel().tween_property(s, "rotation", -0.22, 0.08)
	AudioManager.play_sfx("slash")
	_slash_arc(es.position)
	_burst(es.position, Color(1.0, 0.9, 0.5), 10, 120)
	# Gesamtschaden wird auf beide Schläge verteilt; die Wucht (und die
	# Crit-Chance) trägt der zweite Treffer.
	var total: int = maxi(int(h["data"]["atk"] * randf_range(0.9, 1.2)) - e["def"], 2)
	await _hitstop(0.05)
	await _damage_enemy(e, maxi(int(total * 0.45), 1))
	# Schlag 2: Rückhand — sofern der Gegner noch steht. Kurzer Rücksprung,
	# dann reißt die Klinge in der Gegenrichtung durch.
	if e["alive"]:
		# Rückhand aus der Gegenrichtung. Wer drei Schwünge hat (Helen), wechselt
		# zufällig — sonst sieht jeder zweite Schlag gleich aus.
		_pose(h, "attack2" if randf() < 0.5 else "attack3", 0.55)
		var hop := create_tween()
		hop.tween_property(s, "position:x", strike_pos.x + 26.0, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.parallel().tween_property(s, "rotation", 0.14, 0.10)
		if wp != null:
			_weapon_trail(wp, 0.10)
			var back_swing := create_tween()
			back_swing.tween_property(wp, "rotation", 1.6, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await hop.finished
		AudioManager.play_sfx("slash")
		_slash_arc(es.position + Vector2(6, -8))
		_burst(es.position, Color(1.0, 0.95, 0.7), 12, 150)
		_impact_ring(es.position, Color(1, 1, 1, 0.7))
		var crit := randf() < 0.12
		_shake_camera(1.2)
		_punch_zoom(0.05, es.position)
		await _hitstop(0.12 if crit else 0.07)
		if crit:
			_crit_fx(es.position)
		await _damage_enemy(e, maxi(int(total * 0.55 * (2.0 if crit else 1.0)), 1))
	# 4) Rückzug: aufrichten, Waffe zurück in Ruhehaltung, heimsprinten.
	var settle := create_tween()
	settle.tween_property(s, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if wp != null:
		settle.parallel().tween_property(wp, "rotation", wp.get_meta("rest", WEAPON_REST), 0.18)
	await _sprint(h, h["home"], 0.22)
	s.rotation = 0.0
	s.scale = base

## Vorbereitungspose vor einer Fähigkeit (wie beim Roboterlaser): der Held
## tritt vor und sammelt sichtbar Kraft — Zauberkreis, aufglühende Aura,
## einlaufende Funken, Wirk-Pose, Sammelton. Erst danach folgt die Wirkung.
## Signaturgeste je Fähigkeit — läuft NACH dem gemeinsamen Kraftsammeln, damit
## jede Fähigkeit ihren eigenen Auftakt hat statt nur denselben Windup.
func _signature(h: Dictionary, gesture: String, color: Color) -> void:
	if gesture == "" or h.is_empty() or not is_instance_valid(h["sprite"]):
		return
	var s: Sprite2D = h["sprite"]
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var start := s.position
	match gesture:
		"whirl":
			# Vorzeichnen des Wirbels: zwei enge Kreise mit Nachbildern.
			_ghost_trail(s, 0.5)
			var tw := create_tween()
			for i in 2:
				tw.tween_property(s, "position", start + Vector2(-18, -10), 0.12) \
					.set_trans(Tween.TRANS_SINE)
				tw.tween_property(s, "position", start + Vector2(18, 6), 0.12) \
					.set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "position", start, 0.10)
			_weapon_glint(h.get("weapon"))
		"pierce":
			# Zielen: tief in die Knie, Klinge waagerecht ausrichten.
			var tw := create_tween()
			tw.tween_property(s, "scale", base * Vector2(1.14, 0.86), 0.16) \
				.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(s, "position:x", start.x + 14.0, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(s, "scale", base, 0.14)
			_beam(s.position + Vector2(-30, -4), s.position + Vector2(-260, -4),
				Color(color, 0.35), 2.0, 0.22)
		"dance":
			# Pentagramm in die Luft treten: fünf kurze Versätze.
			var tw := create_tween()
			for i in 5:
				var a := TAU * (i * 2) / 5.0 - PI * 0.5
				tw.tween_property(s, "position", start + Vector2(cos(a), sin(a)) * 16.0, 0.07) \
					.set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "position", start, 0.08)
			_sparkle(start, color)
		"storm":
			# Klinge über den Kopf reißen, Wind zieht an.
			var tw := create_tween()
			tw.tween_property(s, "position:y", start.y - 22.0, 0.20) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(s, "rotation", -0.22, 0.20)
			tw.tween_property(s, "position:y", start.y, 0.14) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(s, "rotation", 0.0, 0.14)
			for i in 3:
				_burst(start + Vector2(randf_range(-40, 40), randf_range(-30, 20)),
					color, 6, 120)
		"sky":
			# Zum Himmel zeigen — von dort kommt der Einschlag.
			var tw := create_tween()
			tw.tween_property(s, "rotation", -0.16, 0.18).set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
			_spell_light(start + Vector2(0, -70), color, 190.0, 0.7, 0.9)
			_beam(start + Vector2(-6, -30), start + Vector2(-30, -300),
				Color(color, 0.30), 6.0, 0.35)
		"call":
			# Beschwörungsformel: die Figur hebt ab, Ringe laufen nach außen.
			var tw := create_tween()
			tw.tween_property(s, "position:y", start.y - 16.0, 0.30) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "position:y", start.y, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			for i in 3:
				_impact_ring(start + Vector2(0, 34), Color(color, 0.5))
				await get_tree().create_timer(0.09).timeout
		"tech":
			# Systemprüfung: Abtastlinie, dann rastet die Haltung ein.
			var scan := Sprite2D.new()
			scan.texture = SpriteFactory.circle(4, color)
			scan.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var mt := CanvasItemMaterial.new()
			mt.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			scan.material = mt
			scan.scale = Vector2(9.0, 0.5)
			scan.position = start + Vector2(0, -46)
			add_child(scan)
			var st := create_tween()
			st.tween_property(scan, "position:y", start.y + 40.0, 0.34)
			st.parallel().tween_property(scan, "modulate:a", 0.0, 0.34)
			st.tween_callback(scan.queue_free)
			var tw := create_tween()
			tw.tween_property(s, "scale", base * Vector2(0.94, 1.08), 0.12)
			tw.tween_property(s, "scale", base, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.30).timeout

func _stance(h: Dictionary, color: Color, sfx := "charge", gesture := "") -> void:
	var s: Sprite2D = h["sprite"]
	await _sprint(h, h["home"] + Vector2(-56, 4), 0.18)
	_cast_circle(s.position + Vector2(0, 40), color)
	# Wirkpose: Stab nach vorn, Stein glüht auf — hält über die ganze
	# Sammelphase, die je nach Zauber gut eine Sekunde dauert.
	_pose(h, "cast", 1.6)
	_anim_cast(s)
	if sfx == "summon":
		_chant(s, 1.1)  # der Zauberer murmelt die Beschwörungsformel
	AudioManager.play_sfx(sfx)
	_spell_light(s.position, color, 150.0, 0.8, 1.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Aura glüht hinter der Figur auf und verlischt wieder
	var aura := Sprite2D.new()
	aura.texture = SpriteFactory.particle("light_01")
	aura.material = mat
	aura.modulate = Color(color, 0.0)
	aura.position = s.position
	aura.scale = Vector2(0.4, 0.4)
	add_child(aura)
	var at := create_tween()
	at.tween_property(aura, "modulate:a", 0.75, 0.28)
	at.parallel().tween_property(aura, "scale", Vector2(1.0, 1.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	at.tween_property(aura, "modulate:a", 0.0, 0.25)
	at.tween_callback(aura.queue_free)
	# Funken laufen von außen in die Figur
	for i in 6:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color(1, 1, 1))
		spark.material = mat
		spark.modulate = color.lightened(0.4)
		spark.position = s.position + Vector2(randf_range(-52, 52), randf_range(-46, 46))
		add_child(spark)
		var st := spark.create_tween()
		st.tween_interval(i * 0.04)
		st.tween_property(spark, "position", s.position, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.parallel().tween_property(spark, "scale", Vector2(0.3, 0.3), 0.24)
		st.tween_callback(spark.queue_free)
	# Wucht: die Figur stemmt sich hoch, der Boden gibt einen Ring ab, die
	# Kamera zieht an und hält kurz die Luft an. Ohne das wirkte selbst die
	# Ultimate wie ein gewöhnlicher Schlag.
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var rise := create_tween()
	rise.tween_property(s, "position:y", s.position.y - 16.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(s, "scale", base * Vector2(0.92, 1.12), 0.30) \
		.set_trans(Tween.TRANS_SINE)
	rise.tween_property(s, "position:y", s.position.y, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rise.parallel().tween_property(s, "scale", base, 0.16)
	var ring := Sprite2D.new()
	ring.texture = SpriteFactory.particle("circle_05")
	ring.material = mat
	ring.modulate = Color(color, 0.85)
	ring.position = s.position + Vector2(0, 40)
	ring.scale = Vector2(0.05, 0.02)
	add_child(ring)
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(0.9, 0.34), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	rt.tween_callback(ring.queue_free)
	_shake_camera(1.6)
	_punch_zoom(0.08, s.position)
	await get_tree().create_timer(0.55).timeout
	await _hitstop(0.06)
	await _signature(h, gesture, color)

func _whirl_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s unleashes %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	# Konzentration: vortreten, Kraft sammeln, dann erst der Wirbel.
	await _stance(h, Color(1.0, 0.95, 0.5), "charge", "whirl")
	var tw := create_tween()
	tw.tween_property(s, "position", Vector2(430, 260), 0.25).set_trans(Tween.TRANS_QUAD)
	_ghost_trail(s, 0.25)
	await tw.finished
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.95, 0.5))
	AudioManager.play_sfx("whirl")
	var spin := create_tween()
	spin.tween_property(s, "rotation", TAU * 2, 0.5)
	spin.tween_callback(func(): s.rotation = 0.0)
	for e in enemies:
		if e["alive"]:
			_slash_arc(e["sprite"].position)
			_burst(e["sprite"].position, Color(0.9, 0.95, 1.0), 8, 100)
	await spin.finished
	for e in enemies:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["atk"] * 0.6) * randf_range(0.9, 1.1)) - e["def"]
			await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.25)

func _fireball(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s casts %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	# Beschwörungspose: vortreten und Kraft sammeln, dann aufsteigen.
	await _stance(h, Color(1.0, 0.6, 0.2), "summon", "sky")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.82, 0.35))
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 16.0, 0.22)
	await raise.finished
	# --- Aufladung: eine glühende Feuerkugel wächst in der Hand und pulsiert ---
	var hand := s.position + Vector2(-44, -4)
	var ball := Sprite2D.new()
	ball.texture = SpriteFactory.particle("fire_01")
	ball.position = hand
	ball.scale = Vector2(0.04, 0.04)
	var bmat := CanvasItemMaterial.new()
	bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ball.material = bmat
	ball.modulate = Color(1.0, 0.62, 0.2)
	var core := Sprite2D.new()
	core.texture = SpriteFactory.particle("flare_01")
	core.scale = Vector2(0.45, 0.45)
	core.modulate = Color(1.0, 0.95, 0.7)
	ball.add_child(core)
	# Wabern: das Feuer dreht langsam, damit es lebt
	var churn := ball.create_tween().set_loops()
	churn.tween_property(core, "rotation", TAU, 1.2)
	var trail := CPUParticles2D.new()
	trail.amount = 20
	trail.lifetime = 0.4
	trail.direction = Vector2(1, 0)
	trail.spread = 30.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 95.0
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.45
	trail.color = Color(1.0, 0.5, 0.1, 0.8)
	trail.texture = SpriteFactory.particle("flame_02")
	ball.add_child(trail)
	add_child(ball)
	AudioManager.play_sfx("charge")
	var charge := create_tween()
	charge.tween_property(ball, "scale", Vector2(0.30, 0.30), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(ball, "scale", Vector2(0.26, 0.26), 0.12).set_trans(Tween.TRANS_SINE)
	await charge.finished
	# --- Abschuss: der große Feuerball rast zum Ziel und wächst dabei ---
	AudioManager.play_sfx("fire")
	var fly := create_tween()
	fly.tween_property(ball, "position", e["sprite"].position, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(ball, "scale", Vector2(0.7, 0.7), 0.34)
	fly.parallel().tween_property(ball, "rotation", TAU, 0.34)
	await fly.finished
	ball.queue_free()
	# --- Einschlag: große Explosion, Blitz, Beben, Zeitlupe ---
	_explosion(e["sprite"].position, 1.9)
	_flash_screen(Color(1.0, 0.62, 0.25, 0.34))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.1)
	await _hitstop(0.11)
	var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.9, 1.15)) - e["def"] / 2
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.2)

## Fokusstoß: Konzentration, drei blitzschnelle Durchstöße quer durch den
## Gegner (mit Körper- und Waffen-Nachbildern, Seiten im Wechsel), kurze
## Stille — dann reißt der Kreuzschnitt auf. Ignoriert die Verteidigung.
func _pierce(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s uses %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	await _stance(h, Color(1.0, 0.95, 0.5), "charge", "pierce")
	var center: Vector2 = es.position
	var grip_x: float = wp.get_meta("grip_x", -7.0) if wp != null else -7.0
	var passes := [
		[center + Vector2(96, -10), center + Vector2(-98, 8)],
		[center + Vector2(-98, 16), center + Vector2(96, -14)],
		[center + Vector2(98, 12), center + Vector2(-96, -10)],
	]
	for p: Array in passes:
		var from: Vector2 = p[0]
		var to: Vector2 = p[1]
		var dir_right: bool = to.x > from.x
		# Blitz-Reposition zur Startseite, Klinge nach vorn gerichtet.
		s.position = from
		s.flip_h = not dir_right
		if wp != null:
			wp.position.x = -grip_x if dir_right else grip_x
			wp.rotation = 1.35 if dir_right else -1.35
		_burst(from, Color(1.0, 0.98, 0.8, 0.7), 5, 60)
		var dash := create_tween()
		dash.tween_property(s, "position", to, 0.11) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(s, 0.11)
		if wp != null:
			_weapon_trail(wp, 0.11)
		AudioManager.play_sfx("slash")
		_slash_arc(center + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
		_burst(center, Color(1.0, 0.95, 0.6), 7, 110)
		await dash.finished
		await get_tree().create_timer(0.05).timeout
	# Landen, Waffe senken, ein Atemzug Stille ...
	s.flip_h = true
	if wp != null:
		wp.position.x = grip_x
		wp.rotation = wp.get_meta("rest", WEAPON_REST)
	s.position = center + Vector2(-96, 0)
	await get_tree().create_timer(0.26).timeout
	# ... dann reißt der Kreuzschnitt auf.
	_cross_slash(center)
	AudioManager.play_sfx("bigboom")
	_impact_ring(es.position, Color(1.0, 0.95, 0.5, 0.8))
	_shake_camera(1.8)
	var crit := randf() < 0.12
	await _hitstop(0.12 if crit else 0.08)
	var dmg: int = int((ab["power"] + d["atk"]) * randf_range(0.95, 1.15) * (1.6 if crit else 1.0))
	if crit:
		_crit_fx(es.position)
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.22)

## Serenas Klingentanz: fünf Blitzschritte im Pentagramm um das Ziel,
## dann steigt sie auf und fährt mit dem Fallstreich nieder.
func _blade_dance(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s dances the %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	await _stance(h, Color(0.75, 0.60, 1.0), "charge", "dance")
	var center: Vector2 = es.position
	var grip_x: float = wp.get_meta("grip_x", -7.0) if wp != null else -7.0
	# Fünf Schnitte: Startpunkte in Pentagramm-Reihenfolge um das Ziel,
	# jeder Schritt schneidet durchs Zentrum.
	for i in 5:
		if not e["alive"]:
			break
		var ang := -PI / 2.0 + i * (TAU * 2.0 / 5.0)
		var from := center + Vector2(cos(ang), sin(ang) * 0.7) * 120.0
		var to := center - (from - center) * 0.9
		var dir_right: bool = to.x > from.x
		s.position = from
		s.flip_h = not dir_right
		if wp != null:
			wp.position.x = -grip_x if dir_right else grip_x
			wp.rotation = 1.35 if dir_right else -1.35
		_burst(from, Color(0.80, 0.65, 1.0, 0.7), 5, 60)
		var dash := create_tween()
		dash.tween_property(s, "position", to, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(s, 0.10)
		if wp != null:
			_weapon_trail(wp, 0.10)
		AudioManager.play_sfx("slash")
		_slash_arc(center + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
		_star_sparks(center)
		await dash.finished
		var pass_dmg := maxi(int((ab["power"] + d["atk"] * 0.35) * randf_range(0.9, 1.1)), 1)
		await _damage_enemy(e, pass_dmg)
	# Waffe in Ruheposition, Blick wieder nach links
	s.flip_h = true
	if wp != null:
		wp.position.x = grip_x
		wp.rotation = wp.get_meta("rest", WEAPON_REST)
	if not e["alive"]:
		# Das Ziel fiel schon im Tanz — elegant zurückgleiten.
		await _sprint(h, h["home"], 0.22)
		return
	# Finisher: hoch über das Ziel steigen, ein Atemzug ...
	AudioManager.play_sfx("whirl")
	var leap := create_tween()
	leap.tween_property(s, "position", center + Vector2(10, -240), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ghost_trail(s, 0.28)
	await leap.finished
	await get_tree().create_timer(0.18).timeout
	# ... dann der Fallstreich
	if wp != null:
		wp.rotation = 2.4
		_weapon_trail(wp, 0.14)
	var slam := create_tween()
	slam.tween_property(s, "position", center + Vector2(6, -6), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(s, 0.13)
	await slam.finished
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(0.85, 0.75, 1.0, 0.35))
	_impact_ring(es.position, Color(0.80, 0.65, 1.0, 0.8))
	_cross_slash(center)
	_shake_camera(2.0)
	var crit := randf() < 0.18
	await _hitstop(0.14 if crit else 0.09)
	if crit:
		_crit_fx(es.position)
	var dmg: int = int((ab["power"] * 2.5 + d["atk"]) * randf_range(0.95, 1.15) * (1.6 if crit else 1.0))
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.24)

## Serenas Ultimative „Sternenklinge“: Blitz-Dashes durch alle Gegner,
## dann ein gewaltiger Kreuzschnitt mit weißem Blitz.
func _ultimate_serena(h: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s unleashes her ultimate power!" % d["name"])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.92, 0.45))
	s.modulate = Color(1.6, 1.5, 1.1)
	_burst(s.position, Color(1.0, 0.95, 0.5), 14, 130)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ STARBLADE ★", Color(1.0, 0.9, 0.35))
	await get_tree().create_timer(0.5).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Sieben Blitz-Durchgänge kreuz und quer durch die Gegnerreihen
	var dash := create_tween()
	for i in 7:
		var target: Dictionary = alive[i % alive.size()]
		var es: Sprite2D = target["sprite"]
		var side := 1.0 if i % 2 == 0 else -1.0
		var from := es.position + Vector2(side * randf_range(160, 240), randf_range(-70, 70))
		var to := es.position + Vector2(-side * randf_range(160, 240), randf_range(-70, 70))
		dash.tween_property(s, "position", from, 0.0)
		dash.tween_callback(func():
			AudioManager.play_sfx("slash")
			_slash_arc(es.position + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
			_burst(es.position, Color(1.0, 0.95, 0.6), 7, 130)
			_ghost_trail(s, 0.09))
		dash.tween_property(s, "position", to, 0.09)
		dash.tween_interval(0.04)
	await dash.finished
	# Finale: riesiger Kreuzschnitt über dem Schlachtfeld
	s.position = Vector2(300, 120)
	for rot in [0.8, -0.8]:
		var arc := Polygon2D.new()
		arc.polygon = PackedVector2Array([Vector2(-220, -14), Vector2(220, -14), Vector2(240, 0), Vector2(220, 14), Vector2(-220, 14), Vector2(-240, 0)])
		arc.color = Color(1, 1, 0.9, 0.9)
		arc.position = Vector2(260, 240)
		arc.rotation = rot
		arc.scale = Vector2(0.1, 0.1)
		add_child(arc)
		var at := create_tween()
		at.tween_property(arc, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		at.tween_property(arc, "modulate:a", 0.0, 0.35)
		at.tween_callback(arc.queue_free)
	_flash_screen(Color(1, 1, 1, 0.8))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.4)
	_punch_zoom(0.12, Vector2(280, 250))
	await _hitstop(0.16)
	s.modulate = Color.WHITE
	for e in alive:
		if e["alive"]:
			var dmg := int((d["atk"] * 2.5 + 30) * randf_range(0.95, 1.1))
			await _damage_enemy(e, dmg)
	_undim(dim)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)

## Ein Schritt eines fallenden Meteors: Kopf + die beiden Schweif-Emitter
## (Feuer, Rauch) wandern gemeinsam entlang der Bahn — so bleibt die Spur hinter
## dem Brocken stehen, statt als starres Sprite mitzukippen.
func _meteor_step(t: float, meteor: Sprite2D, trail: CPUParticles2D, smoke: CPUParticles2D,
		from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(meteor):
		return
	var p := from.lerp(to, t)
	meteor.position = p
	if is_instance_valid(trail):
		trail.position = p
	if is_instance_valid(smoke):
		smoke.position = p

## Meteorregen (Janoschs MP-Zauber): brennende Meteore stürzen auf alle Gegner.
## Wird über die "all"-Fähigkeiten-Dispatch aufgerufen; das Bob-Wippen managt
## dort der _pause_bob/_resume_bob-Rahmen (hier NICHT selbst anfassen).
func _meteor_rain(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s conjures a rain of meteors!" % d["name"])
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.55, 0.15))
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.8, 0.3))
	_chant(s, 1.3)
	s.modulate = Color(1.5, 1.2, 1.6)
	var rise := create_tween()
	rise.tween_property(s, "position:y", s.position.y - 34.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ METEOR RAIN ★", Color(1.0, 0.55, 0.2))
	await get_tree().create_timer(0.5).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Gesteinsbrocken prasseln NUR über dem Gegnerfeld nieder (nie auf der
	# Heldenseite): jeder zweite gezielt auf einen Gegner, der Rest wahllos
	# innerhalb der Gegner-Zone.
	var fr: Dictionary = _enemy_field_rect(alive)
	for i in 13:
		var impact: Vector2
		if i % 2 == 0 and alive.size() > 0:
			var target: Dictionary = alive[(i / 2) % alive.size()]
			impact = target["sprite"].position + Vector2(randf_range(-34, 34), randf_range(-22, 22))
		else:
			impact = Vector2(randf_range(fr["x0"], fr["x1"]), randf_range(fr["y0"], fr["y1"]))
		impact.x = clampf(impact.x, fr["x0"], fr["x1"])
		impact.y = clampf(impact.y, fr["y0"], fr["y1"])
		var big := randf_range(2.2, 3.8)  # Brocken unterschiedlicher Größe
		var meteor := Sprite2D.new()
		meteor.texture = SpriteFactory.meteor_rock(i)
		meteor.scale = Vector2(big, big)
		meteor.rotation = randf_range(-0.4, 0.4)
		# DYNAMISCHER Kometenschweif: zwei eigenständige Emitter (Feuer + Rauch)
		# folgen dem Kopf und legen eine echte Spur entlang der Flugbahn ab — kein
		# starres Flammensprite mehr, das beim Taumeln in die Flugrichtung kippt.
		var fmat := CanvasItemMaterial.new()
		fmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var trail := CPUParticles2D.new()
		trail.amount = 30
		trail.lifetime = 0.55
		trail.direction = Vector2(0, -1)
		trail.spread = 42.0
		trail.gravity = Vector2(0, -30)
		trail.initial_velocity_min = 8.0
		trail.initial_velocity_max = 42.0
		trail.scale_amount_min = 0.10
		trail.scale_amount_max = 0.24
		trail.color = Color(1.0, 0.55, 0.15, 0.9)
		trail.texture = SpriteFactory.particle("fire_01")
		trail.material = fmat
		trail.z_index = -1
		var smoke := CPUParticles2D.new()
		smoke.amount = 16
		smoke.lifetime = 0.75
		smoke.direction = Vector2(0, -1)
		smoke.spread = 46.0
		smoke.gravity = Vector2(0, -12)
		smoke.initial_velocity_min = 5.0
		smoke.initial_velocity_max = 24.0
		smoke.scale_amount_min = 0.10
		smoke.scale_amount_max = 0.24
		smoke.color = Color(0.5, 0.28, 0.16, 0.5)
		smoke.texture = SpriteFactory.particle("smoke_07")
		smoke.z_index = -2
		var start: Vector2 = impact + Vector2(randf_range(150, 320), -460)
		meteor.position = start
		trail.position = start
		smoke.position = start
		add_child(smoke)
		add_child(trail)
		add_child(meteor)
		if i % 2 == 0:
			AudioManager.play_sfx("meteor")
		var dur := randf_range(0.36, 0.5)
		var mimpact := impact
		var mbig := big
		var fall := create_tween()
		fall.tween_method(_meteor_step.bind(meteor, trail, smoke, start, impact), 0.0, 1.0, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Brocken taumelt jetzt frei (der Schweif ist unabhängig, dreht nicht mit).
		fall.parallel().tween_property(meteor, "rotation", meteor.rotation + randf_range(0.6, 1.4), dur)
		fall.tween_callback(func():
			meteor.queue_free()
			trail.emitting = false
			smoke.emitting = false
			get_tree().create_timer(0.7).timeout.connect(func():
				if is_instance_valid(trail):
					trail.queue_free()
				if is_instance_valid(smoke):
					smoke.queue_free())
			_explosion(mimpact, 0.9 + mbig * 0.16)
			AudioManager.play_sfx("boom")
			_shake_camera(1.5))
		await get_tree().create_timer(0.11).timeout
	await get_tree().create_timer(0.5).timeout
	_flash_screen(Color(1.0, 0.6, 0.2, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.4)
	_punch_zoom(0.12, Vector2(280, 250))
	await _hitstop(0.14)
	s.modulate = Color.WHITE
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 1.4 + ab["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	_undim(dim)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

## Heillicht: grüner Lichtring + Funken, heilt einen Verbündeten.
func _heal_ally(h: Dictionary, ab: Dictionary, target: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var td: Dictionary = target["data"]
	_say("%s casts %s on %s!" % [d["name"], ab["name"], td["name"]])
	var s: Sprite2D = h["sprite"]
	# Beschwörungspose vor dem Heilzauber.
	await _stance(h, Color(0.45, 1.0, 0.55), "summon", "call")
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 12.0, 0.2)
	await raise.finished
	AudioManager.play_sfx("heal")
	var ring := Sprite2D.new()
	ring.texture = SpriteFactory.circle(30, Color(0.45, 1.0, 0.55, 0.7))
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ring.position = target["sprite"].position
	ring.scale = Vector2(0.2, 0.2)
	add_child(ring)
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	rt.tween_callback(ring.queue_free)
	_sparkle(target["sprite"].position, Color(0.5, 1.0, 0.6))
	var amount := int(ab["power"] + d["mag"] * 0.5)
	td["hp"] = mini(td["hp"] + amount, td["max_hp"])
	_float_text(target["sprite"].position, "+%d" % amount, Color(0.5, 1.0, 0.6))
	_refresh_party()
	await get_tree().create_timer(0.7).timeout
	await _sprint(h, h["home"], 0.2)

## Sturmschnitt (Serena, Basis-Einzelziel): EIN einziger blitzschneller
## Iaido-Durchzug mit einem waagerechten Schnittstrahl — bewusst anders als der
## dreifache Durchstoß + Kreuzschnitt des Fokusstoßes.
func _storm_cut(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var wp: Sprite2D = h.get("weapon")
	var es: Sprite2D = e["sprite"]
	_say("%s draws %s!" % [d["name"], ab["name"]])
	var center: Vector2 = es.position
	var grip_x: float = wp.get_meta("grip_x", -7.0) if wp != null else -7.0
	# Blitz auf die rechte Seite, Klinge in Ausgangsstellung.
	s.position = center + Vector2(122, -6)
	s.flip_h = false
	if wp != null:
		wp.position.x = -grip_x
		wp.rotation = 1.2
	_burst(s.position, Color(0.9, 0.97, 1.0, 0.7), 6, 70)
	await get_tree().create_timer(0.14).timeout
	AudioManager.play_sfx("slash")
	var dash := create_tween()
	dash.tween_property(s, "position", center + Vector2(-122, 6), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(s, 0.13)
	if wp != null:
		_weapon_trail(wp, 0.13)
	# Ein einzelner, breiter waagerechter Schnittstrahl quer durchs Ziel.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(-95, -3), Vector2(95, -3),
		Vector2(95, 3), Vector2(-95, 3)])
	blade.color = Color(1, 1, 1, 0.95)
	blade.material = mat
	blade.position = center
	blade.scale = Vector2(0.1, 1.0)
	blade.z_index = 4
	add_child(blade)
	var bt := blade.create_tween()
	bt.tween_property(blade, "scale", Vector2(1.35, 1.0), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bt.tween_property(blade, "modulate:a", 0.0, 0.2)
	bt.tween_callback(blade.queue_free)
	await dash.finished
	_burst(center, Color(0.9, 0.97, 1.0), 12, 150)
	_shake_camera(1.2)
	await _hitstop(0.07)
	s.flip_h = true
	if wp != null:
		wp.position.x = grip_x
		wp.rotation = wp.get_meta("rest", WEAPON_REST)
	var dmg: int = int((ab["power"] + d["atk"] * 0.5) * randf_range(0.9, 1.1)) - e["def"]
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.2)

## Klingensturm (Serena, alle): kein Wirbel auf der Stelle wie Klingenwirbel,
## sondern eine Windböe quer übers Feld, aus der über jedem Gegner nacheinander
## ein kleiner rotierender Klingen-Tornado aufreißt.
func _blade_storm(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var wp: Sprite2D = h.get("weapon")
	_say("%s unleashes %s!" % [d["name"], ab["name"]])
	await _stance(h, Color(0.75, 0.92, 1.0), "charge", "storm")
	# Klinge senkrecht hochreißen — Startsignal des Sturms.
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 18.0, 0.18).set_trans(Tween.TRANS_SINE)
	if wp != null and is_instance_valid(wp):
		wp.create_tween().tween_property(wp, "rotation", -1.9, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await raise.finished
	AudioManager.play_sfx("whirl")
	_flash_screen(Color(0.7, 0.9, 1.0, 0.18))
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Windböe quer übers Gegnerfeld.
	var wind := CPUParticles2D.new()
	wind.position = Vector2(500, 235)
	wind.amount = 40
	wind.lifetime = 0.6
	wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wind.emission_rect_extents = Vector2(30, 130)
	wind.direction = Vector2(-1, 0)
	wind.spread = 12.0
	wind.gravity = Vector2.ZERO
	wind.initial_velocity_min = 260.0
	wind.initial_velocity_max = 470.0
	wind.scale_amount_min = 0.3
	wind.scale_amount_max = 0.7
	wind.color = Color(0.8, 0.92, 1.0, 0.6)
	wind.texture = SpriteFactory.particle("spark_04")
	wind.z_index = 5
	add_child(wind)
	get_tree().create_timer(0.7).timeout.connect(func(): if is_instance_valid(wind): wind.emitting = false)
	get_tree().create_timer(1.7).timeout.connect(func(): if is_instance_valid(wind): wind.queue_free())
	for i in alive.size():
		_blade_tornado(alive[i]["sprite"].position, i * 0.12)
	await get_tree().create_timer(0.12 * alive.size() + 0.5).timeout
	_shake_camera(1.8)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["atk"] * 0.6) * randf_range(0.9, 1.1)) - e["def"]
			await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.22)

## Kurzlebiger, rotierender Klingen-Tornado über einem Gegner (für Klingensturm).
func _blade_tornado(pos: Vector2, delay: float) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var t := Node2D.new()
	t.position = pos
	t.scale = Vector2(0.2, 0.2)
	t.modulate.a = 0.0
	t.z_index = 4
	for k in 3:
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([Vector2(-4, -46), Vector2(4, -46),
			Vector2(2, 46), Vector2(-2, 46)])
		blade.color = Color(0.85, 0.95, 1.0, 0.9)
		blade.material = mat
		blade.rotation = k * TAU / 3.0
		t.add_child(blade)
	add_child(t)
	var tw := t.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(t, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(t, "scale", Vector2(1.1, 1.45), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "rotation", TAU * 2.5, 0.42)
	tw.tween_callback(_tornado_hit.bind(pos))
	tw.tween_property(t, "modulate:a", 0.0, 0.18)
	tw.tween_callback(t.queue_free)

func _tornado_hit(pos: Vector2) -> void:
	AudioManager.play_sfx("slash")
	_burst(pos, Color(0.85, 0.95, 1.0), 12, 160)
