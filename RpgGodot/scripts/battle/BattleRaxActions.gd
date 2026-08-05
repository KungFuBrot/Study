class_name BattleRaxActions
extends BattleHeroActions
## Aktionen des Kampfroboters Wally: MG, Laser, Raketen, Nuke, Plasmalanze,
## Reparatur und Orbitallaser-Ultimate.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

## Rax' Standardangriff: anhaltendes Maschinengewehrfeuer auf EINEN Gegner.
## Eine Salve schneller Leuchtspur-Schüsse (Mündungsblitz, Rückstoß, Funken,
## ratterndes MG-Geräusch). Der Gesamtschaden wird vorab gewürfelt und erst am
## Ende als eine Zahl gebucht — so gibt es nur eine Todes-/Wutprüfung und keine
## Zahlenflut, während die vielen Schüsse rein optisch/akustisch rattern.
func _rax_gun(h: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	_say("%s opens up with the machine gun!" % d["name"])
	# In den Schützenstand schweben und einrasten (wie beim Laser).
	var fire_pos: Vector2 = h["home"] + Vector2(-58, 6)
	await _sprint(h, fire_pos, 0.2)
	h["anim"] = "aim"
	_hero_tex(h, "aim")
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var snap := create_tween()
	snap.tween_property(s, "scale", base * Vector2(1.06, 0.94), 0.06)
	snap.tween_property(s, "scale", base, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await snap.finished
	# Minigun hervorholen — sie liefert auch den Punkt, an dem es blitzt.
	var gun := _rax_equip(h, "minigun", Vector2(-27, 15))
	# Gesamtschaden wie beim Nahkampf, nur minimal stärker (Signaturangriff).
	var rounds := 14
	var total: int = maxi(int(d["atk"] * randf_range(1.0, 1.3)) - e["def"], rounds)
	for i in rounds:
		if not e["alive"] or not is_instance_valid(es):
			break
		var muzzle: Vector2 = _rax_muzzle(gun)
		var target: Vector2 = es.position + Vector2(randf_range(-12, 12), randf_range(-18, 18))
		_muzzle_flash(muzzle, (target - muzzle).angle())
		_fire_bullet(muzzle, target)
		AudioManager.play_sfx("mgun")
		# Rückstoß: der Roboter ruckelt bei jedem Schuss kurz nach hinten.
		var jit := create_tween()
		jit.tween_property(s, "position:x", fire_pos.x + 6.0, 0.03)
		jit.tween_property(s, "position:x", fire_pos.x, 0.05)
		if is_instance_valid(gun):
			# Die Waffe ruckt mit — sonst schwebt sie ruhig neben dem Rückstoß.
			var gj := gun.create_tween()
			gj.tween_property(gun, "position:x", gun.position.x + 5.0, 0.03)
			gj.tween_property(gun, "position:x", gun.position.x, 0.05)
		if i % 4 == 3:
			_shake(es)
			_shake_camera(0.5)
		await get_tree().create_timer(0.055).timeout
	# Ausklang, dann der gesammelte Schaden als eine Zahl (eine Todesprüfung).
	_flash_screen(Color(1.0, 0.8, 0.4, 0.12))
	_shake_camera(1.2)
	_rax_stow(gun)
	if e["alive"]:
		await _damage_enemy(e, total)
	# Zurück in die Reihe.
	h["anim"] = "idle"
	_hero_tex(h, "idle")
	s.position = fire_pos
	await _sprint(h, h["home"], 0.2)

## Laserstoß: Kanone lädt cyan auf, dann ein gebündelter Strahl auf einen Gegner.
func _laser(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s fires %s!" % [d["name"], ab["name"]])
	# 1) In Schussposition schweben und in den breiten Stand einrasten.
	var fire_pos: Vector2 = h["home"] + Vector2(-64, 6)
	await _sprint(h, fire_pos, 0.2)
	h["anim"] = "aim"
	_hero_tex(h, "aim")
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var snap := create_tween()
	snap.tween_property(s, "scale", base * Vector2(1.06, 0.94), 0.06)
	snap.tween_property(s, "scale", base, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Strahlgewehr hervorholen — der Strahl tritt aus seinem Fokuskristall aus.
	var rifle := _rax_equip(h, "laser", Vector2(-20, 8))
	await get_tree().create_timer(0.3).timeout
	var muzzle := _rax_muzzle(rifle)
	# 2) Aufladen: wachsende, bebende Energiekugel, Funken laufen in die
	# Mündung, dazu Licht und steigender Ladeton.
	var chg := Sprite2D.new()
	chg.texture = SpriteFactory.circle(11, Color(0.5, 0.97, 1.0))
	chg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chg.position = muzzle
	chg.scale = Vector2(0.1, 0.1)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	chg.material = m
	add_child(chg)
	AudioManager.play_sfx("charge")
	_spell_light(muzzle, Color(0.5, 0.9, 1.0), 150.0, 0.85, 1.0)
	for i in 9:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color(0.7, 0.97, 1.0))
		spark.material = m
		spark.position = muzzle + Vector2(randf_range(-46, 46), randf_range(-40, 40))
		add_child(spark)
		var st := spark.create_tween()
		st.tween_interval(i * 0.05)
		st.tween_property(spark, "position", muzzle, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.parallel().tween_property(spark, "scale", Vector2(0.3, 0.3), 0.28)
		st.tween_callback(spark.queue_free)
	var ct := chg.create_tween()
	ct.tween_property(chg, "scale", Vector2(1.2, 1.2), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.tween_property(chg, "scale", Vector2(1.5, 1.4), 0.09)
	ct.tween_property(chg, "scale", Vector2(1.35, 1.5), 0.08)
	ct.tween_property(chg, "scale", Vector2(1.7, 1.7), 0.08)
	await ct.finished
	chg.queue_free()
	# 3) Feuern: Mündungsblitz, Strahl, Rückstoß schiebt Rax nach hinten.
	var target: Vector2 = e["sprite"].position
	AudioManager.play_sfx("laser")
	_beam(muzzle, target, Color(0.45, 0.95, 1.0, 0.9), 18.0, 0.18)
	_burst(muzzle, Color(0.7, 0.97, 1.0), 8, 90)
	var recoil := create_tween()
	recoil.tween_property(s, "position:x", fire_pos.x + 16.0, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil.tween_property(s, "position:x", fire_pos.x, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_impact_ring(target, Color(0.6, 0.97, 1.0, 0.85))
	_burst(target, Color(0.6, 0.95, 1.0), 18, 180)
	_flash_screen(Color(0.4, 0.85, 1.0, 0.20))
	_shake_camera(1.7)
	await _hitstop(0.10)
	_rax_stow(rifle)
	var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.9, 1.15)) - e["def"] / 2
	await _damage_enemy(e, maxi(dmg, 1))
	# 4) Zurück in die Reihe.
	h["anim"] = "idle"
	_hero_tex(h, "idle")
	await _sprint(h, h["home"], 0.2)

## Eine einzelne Rakete: steigt erst steil aus dem Rohr, kippt dann entlang
## einer Bézier-Bahn ins Ziel und detoniert beim Aufprall. Das Sprite dreht
## sich in Flugrichtung, das Abgas flackert in 2 Frames, Rauch bleibt hängen.
func _launch_rocket(from: Vector2, to: Vector2) -> void:
	var r := Sprite2D.new()
	r.texture = SpriteFactory.rocket(0)
	r.scale = Vector2(2.0, 2.0)
	r.position = from
	# Weicher Feuerschweif: additives Kenney-Flammen-Sprite hinter der Düse.
	var exhaust := Sprite2D.new()
	exhaust.texture = SpriteFactory.particle("flame_05")
	exhaust.rotation = -PI / 2  # Flamme zeigt nach links (nach hinten)
	exhaust.position = Vector2(-16, 0)
	exhaust.scale = Vector2(0.16, 0.30)
	exhaust.modulate = Color(1.0, 0.75, 0.35, 0.95)
	var exm := CanvasItemMaterial.new()
	exm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	exhaust.material = exm
	r.add_child(exhaust)
	# Rauchfaden: eigenständiger Emitter (KEIN Kind der Rakete), der ihr am
	# Heck folgt und träge, lang lebende Puffs ablegt — die Flugbahn bleibt
	# als hängender Faden in der Luft stehen und verweht nach dem Einschlag.
	var smoke := CPUParticles2D.new()
	smoke.amount = 90
	smoke.lifetime = 1.9
	smoke.direction = Vector2(0, -1)
	smoke.spread = 180.0
	smoke.gravity = Vector2(0, -12)
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 8.0
	smoke.scale_amount_min = 0.05
	smoke.scale_amount_max = 0.11
	smoke.color = Color(0.85, 0.84, 0.82, 0.6)
	smoke.texture = SpriteFactory.particle("smoke_07")
	smoke.position = from
	add_child(smoke)
	add_child(r)
	# Mündungsblitz am Startrohr
	var muzzle := Sprite2D.new()
	muzzle.texture = SpriteFactory.particle("muzzle_02")
	muzzle.position = from
	muzzle.rotation = (to - from).angle() - PI / 2
	muzzle.scale = Vector2(0.4, 0.4)
	muzzle.material = exm
	muzzle.modulate = Color(1.0, 0.85, 0.5)
	add_child(muzzle)
	var mt := muzzle.create_tween()
	mt.tween_property(muzzle, "modulate:a", 0.0, 0.12)
	mt.tween_callback(muzzle.queue_free)
	# Abgasflamme flackern lassen
	var flick := create_tween().set_loops()
	flick.tween_interval(0.05)
	flick.tween_callback(func():
		r.texture = SpriteFactory.rocket(randi() % 2)
		exhaust.scale = Vector2(randf_range(0.13, 0.19), randf_range(0.26, 0.36)))
	# Quadratische Bézier-Bahn: Kontrollpunkt hoch über dem Startrohr →
	# steiler Aufstieg, dann Sturz ins Ziel.
	var ctrl := from + Vector2(randf_range(-40, 10), -randf_range(110, 170))
	var dur := randf_range(0.62, 0.78)
	var tw := create_tween()
	tw.tween_method(_rocket_step.bind(r, smoke, from, ctrl, to), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		flick.kill()
		r.queue_free()
		_explosion(to, 1.15)
		_spell_light(to, Color(1.0, 0.6, 0.25), 160.0, 0.4)
		AudioManager.play_sfx("boom")
		_shake_camera(1.2)
		# Der Rauchfaden bleibt stehen und verweht von selbst.
		smoke.emitting = false
		get_tree().create_timer(2.0).timeout.connect(smoke.queue_free))

## Ein Schritt auf der Bézier-Bahn einer Rakete: Position + Blickrichtung;
## der Rauch-Emitter hängt am Heck (gegen die Flugrichtung versetzt).
func _rocket_step(t: float, r: Sprite2D, smoke: CPUParticles2D,
		from: Vector2, ctrl: Vector2, to: Vector2) -> void:
	if not is_instance_valid(r):
		return
	var u := 1.0 - t
	r.position = u * u * from + 2.0 * u * t * ctrl + t * t * to
	var deriv: Vector2 = 2.0 * u * (ctrl - from) + 2.0 * t * (to - ctrl)
	r.rotation = deriv.angle()
	if is_instance_valid(smoke):
		smoke.position = r.position - deriv.normalized() * 20.0

## Raketensalve: zwei Wellen kleiner Raketen auf alle Gegner.
func _rocket_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s launches %s!" % [d["name"], ab["name"]])
	# In Feuerposition schweben und den Schützenstand einnehmen.
	await _sprint(h, h["home"] + Vector2(-58, 6), 0.2)
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.6, 0.2))
	h["anim"] = "aim"
	_hero_tex(h, "aim")
	# Raketenwerfer schultern — aus seinem Rohr kommen die Raketen.
	var tube := _rax_equip(h, "launcher", Vector2(-20, 6))
	await get_tree().create_timer(0.4).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	for wave in 2:
		for e in alive:
			if not e["alive"]:
				continue
			var aim: Vector2 = e["sprite"].position + Vector2(randf_range(-16, 16), randf_range(-14, 14))
			var mz := _rax_muzzle(tube)
			_muzzle_flash(mz, (aim - mz).angle())
			_launch_rocket(mz, aim)
			AudioManager.play_sfx("rocket")
			if is_instance_valid(tube):
				# Rückstoß des Rohrs nach hinten
				var rk := tube.create_tween()
				rk.tween_property(tube, "position:x", tube.position.x + 7.0, 0.05)
				rk.tween_property(tube, "position:x", tube.position.x, 0.09)
			await get_tree().create_timer(0.09).timeout
		await get_tree().create_timer(0.18).timeout
	# Warten, bis auch die langsamen Raketen eingeschlagen sind.
	await get_tree().create_timer(0.8).timeout
	_rax_stow(tube)
	h["anim"] = "idle"
	_hero_tex(h, "idle")
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["mag"] * 0.7) * randf_range(0.9, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.2)

## Nuke: Rax markiert alle Ziele; der Blick schwenkt in den Himmel, die Bombe
## saust vorbei, dann zurück zum Feld — Weißblitz, Schockwelle, Atompilz mit
## Nachrauch, massiver Flächenschaden. Nur EINMAL pro Kampf einsetzbar.
func _nuke(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s calls in %s!" % [d["name"], ab["name"]])
	# Vortreten und den Uplink aufbauen (Schützenstand, Antenne dauerrot).
	await _sprint(h, h["home"] + Vector2(-58, 6), 0.2)
	h["anim"] = "aim"
	_hero_tex(h, "aim")
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	if alive.is_empty():
		return
	var center := Vector2.ZERO
	for e in alive:
		center += (e["sprite"] as Sprite2D).position
	center /= alive.size()
	# Er baut eine Startrampe auf; von ihr steigt die Bombe in den Himmel, bevor
	# sie weiter oben die Flugbahn übernimmt.
	var ramp := _rax_equip(h, "ramp", Vector2(-34, 30))
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(ramp):
		var lift := Sprite2D.new()
		lift.texture = SpriteFactory.bomb(0)
		lift.scale = Vector2(2.0, 2.0)
		lift.position = _rax_muzzle(ramp)
		lift.rotation = -0.95
		add_child(lift)
		AudioManager.play_sfx("rocket")
		var lt := create_tween()
		lt.tween_property(lift, "position", lift.position + Vector2(150, -260), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lt.parallel().tween_property(lift, "modulate:a", 0.0, 0.55)
		lt.tween_callback(lift.queue_free)
		await lt.finished
	# Zielerfassung + Warnton
	for e in alive:
		_crosshair(e["sprite"].position)
	AudioManager.play_sfx("alarm")
	await get_tree().create_timer(0.4).timeout
	_rax_stow(ramp)
	# Kino-Einschub: Der Blick schwenkt hinauf in den Himmel (Wolken, Vögel),
	# die Bombe saust quer durchs Bild, dann zurück zum Schlachtfeld — und der
	# Sprengkopf stürzt auf die Gegner.
	await _nuke_sky_sequence()
	# Bombe fällt pfeifend und leicht taumelnd, Zünderlicht blinkt.
	var b := Sprite2D.new()
	b.texture = SpriteFactory.bomb(0)
	b.scale = Vector2(3.4, 3.4)
	b.position = Vector2(center.x + 36, -60)
	b.rotation = -0.15
	add_child(b)
	var blink := create_tween().set_loops()
	blink.tween_interval(0.07)
	blink.tween_callback(func():
		b.texture = SpriteFactory.bomb(randi() % 2))
	AudioManager.play_sfx("whistle")
	var fall := create_tween()
	fall.tween_property(b, "position", center + Vector2(0, 14), 0.92) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(b, "rotation", 0.2, 0.92) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fall.finished
	blink.kill()
	b.queue_free()
	# Detonation: langer Weißblitz, alles bebt — und zwar richtig.
	AudioManager.play_sfx("nuke")
	_flash_screen(Color(1, 1, 1, 0.95))
	_shockwave(center)
	_shake_camera(3.6)
	_punch_zoom(0.2, center)
	_explosion(center, 3.4)
	for e in alive:
		_explosion((e["sprite"] as Sprite2D).position, 1.6)
	_mushroom_cloud(center, 1.6)
	# Nachschlag: zweite Druckwelle + zweite Explosion, wenn der Blitz abklingt.
	get_tree().create_timer(0.55).timeout.connect(func():
		_shockwave(center + Vector2(30, -20))
		_explosion(center + Vector2(randf_range(-50, 50), randf_range(-30, 10)), 2.0)
		_shake_camera(2.2))
	# Hitzeflimmern über dem Schlachtfeld, solange der Pilz steht.
	var haze := ColorRect.new()
	haze.position = Vector2(20, 90)
	haze.size = Vector2(470, 330)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.material = Fx.heat_haze_material()
	ui_layer.add_child(haze)
	ui_layer.move_child(haze, 3)
	get_tree().create_timer(2.0).timeout.connect(haze.queue_free)
	await _hitstop(0.2)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.95, 1.15)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	h["anim"] = "idle"
	_hero_tex(h, "idle")
	await _sprint(h, h["home"], 0.2)

## Kino-Sequenz vor dem Nuke-Einschlag: eine eigene, NICHT vom Ambiente
## abgedunkelte CanvasLayer (heller Tageshimmel) gleitet von oben herein (=
## der Blick schwenkt hinauf), Wolken ziehen, Vögel flattern; die Bombe saust
## quer durchs Bild; dann gleitet der Himmel wieder hoch (Schwenk zurück).
func _nuke_sky_sequence() -> void:
	var sky := CanvasLayer.new()
	sky.layer = 20  # über Bühne UND UI
	sky.offset = Vector2(0, -540)  # startet oberhalb, aus dem Bild geschoben
	add_child(sky)
	# Himmelsverlauf (kräftiges Blau oben, heller Dunst am Horizont).
	var grad := TextureRect.new()
	grad.texture = SpriteFactory.gradient(8, 64, Color(0.30, 0.56, 0.92), Color(0.78, 0.88, 0.98))
	grad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.size = Vector2(960, 540)
	sky.add_child(grad)
	# Dunstige Sonne oben rechts.
	var sun := Sprite2D.new()
	sun.texture = SpriteFactory.circle(60, Color(1.0, 0.97, 0.85, 0.85))
	sun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sun.position = Vector2(760, 150)
	sun.scale = Vector2(1.4, 1.4)
	sky.add_child(sun)
	# Wolkenbänke ziehen träge nach rechts.
	for c: Array in [[Vector2(180, 150), 1.4], [Vector2(520, 240), 1.8],
			[Vector2(340, 380), 1.2], [Vector2(720, 330), 1.5]]:
		var cloud := Node2D.new()
		cloud.position = c[0]
		cloud.scale = Vector2(c[1], c[1])
		sky.add_child(cloud)
		for off: Vector2 in [Vector2(-26, 5), Vector2(-10, -6), Vector2(6, -8),
				Vector2(22, 0), Vector2(4, 7), Vector2(-16, 7)]:
			var puff := Sprite2D.new()
			puff.texture = SpriteFactory.circle(18, Color(1, 1, 1, 0.92))
			puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			puff.position = off
			puff.scale = Vector2(1.3, 0.95)
			cloud.add_child(puff)
		var drift := cloud.create_tween()
		drift.tween_property(cloud, "position:x", c[0].x + 70.0, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Vögel: schlichte Möwen-Silhouetten, flattern und ziehen durchs Bild.
	var up := PackedVector2Array([Vector2(-8, 1), Vector2(-3, -5), Vector2(0, -1),
		Vector2(3, -5), Vector2(8, 1)])
	var dn := PackedVector2Array([Vector2(-8, -3), Vector2(-3, 1), Vector2(0, -2),
		Vector2(3, 1), Vector2(8, -3)])
	for k in 5:
		var bird := Line2D.new()
		bird.width = 2.2
		bird.default_color = Color(0.16, 0.17, 0.24)
		bird.joint_mode = Line2D.LINE_JOINT_ROUND
		bird.points = up
		var by := 120.0 + k * 34.0
		bird.position = Vector2(120.0 + k * 150.0, by)
		bird.scale = Vector2(1.0 + (k % 2) * 0.5, 1.0 + (k % 2) * 0.5)
		sky.add_child(bird)
		var flap := bird.create_tween().set_loops()
		flap.tween_interval(0.24)
		flap.tween_callback(func(): bird.points = dn)
		flap.tween_interval(0.24)
		flap.tween_callback(func(): bird.points = up)
		var glide := bird.create_tween()
		glide.tween_property(bird, "position", bird.position + Vector2(90.0, -14.0), 6.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Schwenk hinauf: der Himmel gleitet von oben ins Bild.
	var tin := create_tween()
	tin.tween_property(sky, "offset", Vector2.ZERO, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tin.finished
	await get_tree().create_timer(0.5).timeout
	# Die Bombe zieht gemächlich von oben rechts nach unten links durchs Bild.
	# Nase zeigt in Flugrichtung (bomb-Sprite zeigt nativ nach unten → +1.27 rad).
	var wb := Sprite2D.new()
	wb.texture = SpriteFactory.bomb(0)
	wb.scale = Vector2(3.0, 3.0)
	wb.position = Vector2(1080.0, 80.0)
	wb.rotation = 1.27
	sky.add_child(wb)
	# Kondensstreifen: eigenständiger Emitter (NICHT Kind der Bombe, sonst
	# verdreht die Bombenrotation die Partikelrichtung). local_coords=false +
	# quasi keine Startgeschwindigkeit → die Puffs bleiben als Spur liegen,
	# während der Emitter der Bombe folgt.
	var trail := CPUParticles2D.new()
	trail.amount = 55
	trail.lifetime = 1.1
	trail.local_coords = false
	trail.spread = 20.0
	trail.gravity = Vector2(0, 6)
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 8.0
	trail.scale_amount_min = 0.16
	trail.scale_amount_max = 0.34
	trail.color = Color(0.92, 0.92, 0.95, 0.7)
	trail.texture = SpriteFactory.particle("smoke_07")
	trail.position = wb.position
	sky.add_child(trail)
	trail.emitting = true
	AudioManager.play_sfx("whistle")
	var fly := create_tween()
	fly.tween_property(wb, "position", Vector2(-150.0, 470.0), 1.4)
	fly.parallel().tween_property(trail, "position", Vector2(-150.0, 470.0), 1.4)
	await fly.finished
	trail.emitting = false
	wb.queue_free()
	await get_tree().create_timer(0.3).timeout
	# Schwenk zurück: der Himmel gleitet wieder hoch, das Schlachtfeld erscheint.
	var tout := create_tween()
	tout.tween_property(sky, "offset", Vector2(0, -540), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tout.finished
	sky.queue_free()

## Atompilz: heißer Stamm wächst hoch, glühende Kappe wölbt sich auf,
## Glutpartikel steigen — alles additiv und selbstaufräumend.
## `size` skaliert Höhe, Breite und Partikelmenge.
func _mushroom_cloud(pos: Vector2, size := 1.0) -> void:
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var stem := Sprite2D.new()
	stem.texture = SpriteFactory.circle(24, Color(1.0, 0.62, 0.25, 0.75))
	stem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stem.material = addm
	stem.position = pos
	stem.scale = Vector2(1.2 * size, 0.4)
	add_child(stem)
	var st := create_tween()
	st.tween_property(stem, "scale", Vector2(1.5, 4.8) * size, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.parallel().tween_property(stem, "position:y", pos.y - 80.0 * size, 0.8)
	st.tween_property(stem, "modulate:a", 0.0, 0.9)
	st.tween_callback(stem.queue_free)
	# Glühende Pilzkappe aus echten Rauch-Puffs (additiv = Feuerschein) ...
	for i in 6:
		var puff := Sprite2D.new()
		puff.texture = SpriteFactory.particle("smoke_04")
		puff.material = addm
		puff.modulate = Color(1.0, lerpf(0.75, 0.45, i / 5.0), 0.2, 0.85)
		puff.position = pos + Vector2(randf_range(-8, 8), -10)
		puff.rotation = randf_range(0.0, TAU)
		puff.scale = Vector2(0.12, 0.12)
		add_child(puff)
		var side := randf_range(-52, 52) * (0.4 + i * 0.15) * size
		var pt := create_tween()
		pt.tween_interval(0.12 + i * 0.05)
		pt.tween_property(puff, "position", pos + Vector2(side, (-152.0 - i * 14.0) * size), 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(puff, "scale", Vector2.ONE * (0.5 + i * 0.09) * size, 1.1)
		pt.parallel().tween_property(puff, "rotation", puff.rotation + randf_range(-0.8, 0.8), 1.1)
		pt.parallel().tween_property(puff, "modulate:a", 0.0, 1.3)
		pt.tween_callback(puff.queue_free)
	# ... darüber dunkler Nachrauch, der träge weiterzieht
	for i in 4:
		var gray := Sprite2D.new()
		gray.texture = SpriteFactory.particle("smoke_04")
		gray.modulate = Color(0.35, 0.33, 0.33, 0.0)
		gray.position = pos + Vector2(randf_range(-24, 24), (-60.0 - i * 22.0) * size)
		gray.rotation = randf_range(0.0, TAU)
		gray.scale = Vector2(0.25, 0.25) * size
		add_child(gray)
		var gt := create_tween()
		gt.tween_interval(0.5 + i * 0.2)
		gt.tween_property(gray, "modulate:a", 0.5, 0.4)
		gt.parallel().tween_property(gray, "position:y", gray.position.y - 95.0 * size, 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		gt.parallel().tween_property(gray, "scale", Vector2(0.7, 0.7) * size, 2.0)
		gt.tween_property(gray, "modulate:a", 0.0, 0.8)
		gt.tween_callback(gray.queue_free)
	var emb := CPUParticles2D.new()
	emb.position = pos
	emb.amount = int(40 * size)
	emb.lifetime = 1.2
	emb.one_shot = true
	emb.explosiveness = 0.9
	emb.direction = Vector2(0, -1)
	emb.spread = 55.0
	emb.gravity = Vector2(0, -60)
	emb.initial_velocity_min = 60.0 * size
	emb.initial_velocity_max = 190.0 * size
	emb.color = Color(1.0, 0.55, 0.15, 0.9)
	emb.texture = SpriteFactory.circle(2, Color.WHITE)
	emb.emitting = true
	add_child(emb)
	get_tree().create_timer(2.4).timeout.connect(emb.queue_free)
	_spell_light(pos, Color(1.0, 0.6, 0.2), 420.0 * size, 1.4, 2.0)

## Zielerfassungs-Fadenkreuz: leuchtender Ring + vier Striche, das aufploppt,
## kurz hält und wieder verschwindet.
func _crosshair(pos: Vector2) -> void:
	var ch := Node2D.new()
	ch.position = pos
	ch.z_index = 3
	var col := Color(1.0, 0.12, 0.10)  # kräftiges Rot
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for k in 25:
		var a := TAU * k / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 27.0)
	ring.points = pts
	ring.width = 2.6
	ring.default_color = col
	ring.material = m
	ch.add_child(ring)
	for dir: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var tick := Line2D.new()
		tick.points = PackedVector2Array([dir * 14.0, dir * 39.0])
		tick.width = 2.6
		tick.default_color = col
		tick.material = m
		ch.add_child(tick)
	add_child(ch)
	ch.scale = Vector2(1.8, 1.8)
	ch.modulate.a = 0.0
	var tw := ch.create_tween()
	tw.tween_property(ch, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(ch, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(ch, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ch.queue_free)

## Der Orbitallaser-Strahl: eine leuchtende Säule von oben mit hellem Kern und
## Boden-Glut, die dem Einschlagpunkt folgt. Gibt den beweglichen Strahl zurück.
func _orbital_beam_make(pos: Vector2) -> Node2D:
	var beam := Node2D.new()
	beam.position = pos
	beam.z_index = 2
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var w := 30.0
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-w, -560), Vector2(w, -560),
		Vector2(w * 0.35, 0), Vector2(-w * 0.35, 0)])
	glow.color = Color(0.5, 0.9, 1.0, 0.5)
	glow.material = m
	beam.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-w * 0.4, -560), Vector2(w * 0.4, -560),
		Vector2(w * 0.14, 0), Vector2(-w * 0.14, 0)])
	core.color = Color(1, 1, 1, 0.95)
	core.material = m
	beam.add_child(core)
	var base := Sprite2D.new()
	base.texture = SpriteFactory.circle(20, Color(0.75, 0.97, 1.0))
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	base.scale = Vector2(2.4, 1.0)
	base.material = m
	beam.add_child(base)
	add_child(beam)
	beam.scale = Vector2(0.1, 1.0)
	beam.create_tween().tween_property(beam, "scale", Vector2(1, 1), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return beam

## Glühender Spur-Fleck des Orbitallasers: eingebranntes Metall, das weißglühend
## aufsetzt und dann langsam abkühlt (weiß → gelb → orange → tiefrot → dunkel).
## `depth` (Nähe zur Kamera) skaliert Größe und Helligkeit für den Tiefeneindruck.
func _molten_spot(pos: Vector2, depth: float) -> void:
	# Dauerhafte Brandnarbe darunter (kühlt nie ganz zurück, bleibt liegen).
	var scorch := Sprite2D.new()
	scorch.texture = SpriteFactory.particle("scorch_01")
	scorch.position = pos
	scorch.scale = Vector2(0.34, 0.2) * depth
	scorch.modulate = Color(0.06, 0.05, 0.05, 0.0)
	scorch.z_index = -9
	add_child(scorch)
	var sc: Tween = scorch.create_tween()
	sc.tween_property(scorch, "modulate:a", 0.6, 0.3)
	sc.tween_interval(2.6)
	sc.tween_property(scorch, "modulate:a", 0.0, 1.6)
	sc.tween_callback(scorch.queue_free)
	# Das glühende Metall selbst: additiver Fleck, der die Farbstufen durchläuft.
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(10, Color(1, 1, 1))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.position = pos
	glow.material = m
	glow.z_index = 0
	# Am Boden liegend: horizontal breiter als hoch, mit der Tiefe skaliert.
	glow.scale = Vector2(1.5, 0.8) * depth
	glow.modulate = Color(1.7, 1.55, 1.15)  # weißglühend
	add_child(glow)
	var cool: Tween = glow.create_tween()
	cool.tween_property(glow, "modulate", Color(1.6, 1.15, 0.4), 0.5)   # gelb
	cool.tween_property(glow, "modulate", Color(1.3, 0.6, 0.16), 1.0)   # orange
	cool.tween_property(glow, "modulate", Color(0.85, 0.22, 0.07), 1.4) # tiefrot
	cool.tween_property(glow, "modulate", Color(0.3, 0.06, 0.03, 0.0), 1.5)  # erkaltet
	cool.tween_callback(glow.queue_free)
	# Beim Abkühlen zieht sich das Metall leicht zusammen.
	var sh: Tween = glow.create_tween()
	sh.tween_property(glow, "scale", Vector2(1.0, 0.55) * depth, 4.4).set_trans(Tween.TRANS_SINE)

## Ein Schritt des Orbitallaser-Sweeps: bewegt den Strahl entlang der liegenden
## Acht, zieht eine dichte glühende Metallspur und erfasst passierte Gegner
## (Funken + Licht; der Schaden folgt gesammelt am Ende). Über die Bahntiefe
## werden Strahlbreite und Spur skaliert, damit ein Vorne/Hinten-Eindruck entsteht.
func _orbital_step(t: float, beam: Node2D, cx: float, cy: float, aa: float, bb: float,
		rot: float, alive: Array, hit: Dictionary, state: Dictionary) -> void:
	if not is_instance_valid(beam):
		return
	var ang := t * TAU
	# Liegende Acht (Lemniskate): lx = sin, ly = sin·cos — dann um rot gekippt,
	# damit die Bahn schräg verläuft (wirkt wie „nach hinten und vorne fahren").
	var lx := aa * sin(ang)
	var ly := bb * sin(ang) * cos(ang)
	var p := Vector2(cx + lx * cos(rot) - ly * sin(rot), cy + lx * sin(rot) + ly * cos(rot))
	beam.position = p
	# Tiefe: weiter oben im Feld = weiter „hinten" = schmaler/kleiner, weiter unten
	# = näher an der Kamera = breiter/größer. Ergibt räumliche Vor-/Zurück-Fahrt.
	var depth := clampf(remap(p.y, cy - bb, cy + bb, 0.62, 1.32), 0.5, 1.5)
	beam.scale = Vector2(depth, 1.0)
	beam.z_index = 2 + int(p.y * 0.05)  # vordere Bahnabschnitte über hintere
	state["n"] += 1
	var n := int(state["n"])
	# Dichte, lückenlose Glutspur — jeder Fleck kühlt einzeln ab (Kopf hell, Schweif rot).
	if n % 4 == 0:
		_molten_spot(p, depth)
	# Anhaltendes Zischen des einbrennenden Metalls.
	if n % 20 == 0:
		AudioManager.play_sfx("sizzle")
	for e in alive:
		var esp: Sprite2D = e["sprite"]
		if e["alive"] and not hit.has(esp) and p.distance_to(esp.position) < 52.0:
			hit[esp] = true
			_burst(esp.position, Color(0.7, 0.97, 1.0), 8, 120)
			_spell_light(esp.position, Color(0.6, 0.9, 1.0), 120.0, 0.3)

## Rax' Ultimative „Orbitallaser": Fadenkreuze erfassen die Gegner und
## verschwinden wieder; dann fährt der Strahl von oben herab und zieht langsam
## eine schräge, liegende Acht über das Gegnerfeld und brennt dabei eine
## glühende Metallspur in den Boden, die langsam abkühlt.
func _ultimate_rax(h: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s activates its overload protocol!" % d["name"])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(0.4, 0.9, 1.0))
	s.modulate = Color(1.4, 1.5, 1.7)
	_burst(s.position, Color(0.5, 0.95, 1.0), 16, 150)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ ORBITAL LASER ★", Color(0.5, 0.9, 1.0))
	await get_tree().create_timer(0.5).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Er holt ein Funkgerät hervor und spricht die Zielkoordinaten hinauf —
	# die Anzeige blinkt im Takt, dann kommt die Antwort von oben.
	var radio := _rax_equip(h, "radio", Vector2(-18, 6))
	if is_instance_valid(radio):
		var blink := radio.create_tween().set_loops(4)
		blink.tween_property(radio, "modulate", Color(1.5, 1.7, 1.8), 0.14)
		blink.tween_property(radio, "modulate", Color.WHITE, 0.14)
	# Phase 1: Fadenkreuze erfassen die Gegner und verschwinden wieder.
	for e in alive:
		_crosshair(e["sprite"].position)
	AudioManager.play_sfx("charge")
	await get_tree().create_timer(1.05).timeout
	_rax_stow(radio)
	# Phase 2: Der Strahl fährt von oben herab und zieht eine 8 übers Gegnerfeld.
	var fr: Dictionary = _enemy_field_rect(alive)
	var cx: float = fr["cx"]
	var cy: float = fr["cy"]
	# Deutlich größere 8 als das reine Gegner-Feld, leicht schräg gekippt.
	var aa: float = maxf(fr["ax"] * 1.35, 135.0)
	var bb: float = maxf(fr["ay"] * 1.35, 96.0)
	var rot: float = deg_to_rad(20.0)
	var beam := _orbital_beam_make(Vector2(cx, cy))
	AudioManager.play_sfx("laser")
	_shake_camera(1.6)
	await get_tree().create_timer(0.22).timeout
	# Bewegung als gebundene Methode (kein mehrzeiliges Lambda mit Folgeargumenten
	# in tween_method — das bricht in GDScript). hit/state sind Referenz-Dicts.
	var hit := {}
	var state := {"n": 0}
	var sweep := create_tween()
	sweep.tween_method(_orbital_step.bind(beam, cx, cy, aa, bb, rot, alive, hit, state),
		0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	await sweep.finished
	# Abschluss: greller Blitz, Einschlag, Strahl abbauen.
	_flash_screen(Color(0.6, 0.9, 1.0, 0.45))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	var bt := beam.create_tween()
	bt.tween_property(beam, "modulate:a", 0.0, 0.35)
	bt.tween_callback(beam.queue_free)
	await _hitstop(0.14)
	s.modulate = Color.WHITE
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 2.5 + 40) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	_undim(dim)
	h["bob"] = _idle_bob(s, 2.0)

## Plasmalanze (Rax, Einzelziel): ein KÖRPERLICHER Plasmaspeer (kein Strahl wie
## der Laserstoß) formt sich an der Mündung und rast rotierend durch das Ziel.
func _plasma_lance(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s hurls the %s!" % [d["name"], ab["name"]])
	var fire_pos: Vector2 = h["home"] + Vector2(-64, 6)
	await _sprint(h, fire_pos, 0.2)
	h["anim"] = "aim"
	_hero_tex(h, "aim")
	# Die Lanze wird als Gerät hervorgeholt und dann geschleudert.
	var launcher := _rax_equip(h, "lance", Vector2(-20, 8))
	await get_tree().create_timer(0.3).timeout
	var muzzle: Vector2 = _rax_muzzle(launcher)
	_rax_stow(launcher)
	var target: Vector2 = e["sprite"].position
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var lance := Node2D.new()
	var lbody := Polygon2D.new()
	lbody.polygon = PackedVector2Array([Vector2(-48, 0), Vector2(6, -7),
		Vector2(42, 0), Vector2(6, 7)])
	lbody.color = Color(0.7, 0.5, 1.0, 0.95)
	lance.add_child(lbody)
	var lcore := Polygon2D.new()
	lcore.polygon = PackedVector2Array([Vector2(-32, 0), Vector2(4, -3),
		Vector2(32, 0), Vector2(4, 3)])
	lcore.color = Color(1, 1, 1, 0.95)
	lance.add_child(lcore)
	lance.material = mat
	lance.position = muzzle
	lance.rotation = (target - muzzle).angle()
	lance.scale = Vector2(0.3, 0.3)
	lance.z_index = 6
	add_child(lance)
	AudioManager.play_sfx("charge")
	_spell_light(muzzle, Color(0.7, 0.5, 1.0), 140.0, 0.6)
	var form := lance.create_tween()
	form.tween_property(lance, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await form.finished
	AudioManager.play_sfx("laser")
	var recoil := create_tween()
	recoil.tween_property(s, "position:x", fire_pos.x + 18.0, 0.06)
	recoil.tween_property(s, "position:x", fire_pos.x, 0.24).set_trans(Tween.TRANS_SINE)
	var fly := lance.create_tween()
	fly.tween_property(lance, "position", target, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(lance, "rotation", lance.rotation + TAU, 0.16)
	_lance_trail(lance, 0.16)
	await fly.finished
	# Durchstoß: die Lanze schießt hinter das Ziel und verpufft.
	var dirv: Vector2 = (target - muzzle).normalized()
	var through := lance.create_tween()
	through.tween_property(lance, "position", target + dirv * 95.0, 0.1)
	through.parallel().tween_property(lance, "modulate:a", 0.0, 0.13)
	through.tween_callback(lance.queue_free)
	_impact_ring(target, Color(0.78, 0.55, 1.0, 0.85))
	_burst(target, Color(0.82, 0.62, 1.0), 20, 200)
	_flash_screen(Color(0.6, 0.4, 1.0, 0.22))
	_shake_camera(1.9)
	await _hitstop(0.11)
	var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.9, 1.15)) - e["def"] / 2
	await _damage_enemy(e, maxi(dmg, 1))
	h["anim"] = "idle"
	_hero_tex(h, "idle")
	await _sprint(h, h["home"], 0.2)

## Violette Nachbild-Spur der fliegenden Plasmalanze.
func _lance_trail(lance: Node2D, dur: float) -> void:
	var steps := maxi(int(dur / 0.025), 2)
	for i in steps:
		await get_tree().create_timer(0.025).timeout
		if not is_instance_valid(lance):
			return
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var g := Sprite2D.new()
		g.texture = SpriteFactory.particle("light_01")
		g.material = mat
		g.modulate = Color(0.7, 0.5, 1.0, 0.5)
		g.scale = Vector2(0.35, 0.2)
		g.rotation = lance.rotation
		g.position = lance.position
		g.z_index = 5
		add_child(g)
		var gt := g.create_tween()
		gt.tween_property(g, "modulate:a", 0.0, 0.16)
		gt.tween_callback(g.queue_free)

## Reparatur (Rax, Verbündeten-Heilung): technisch statt magisch — ein Strom
## cyanfarbener Naniten fliegt zum Ziel, ein hexagonaler Tech-Ring und
## Schweißfunken schließen die Schäden. Klar anders als Milos grünes Heillicht.
func _repair_ally(h: Dictionary, ab: Dictionary, target: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var td: Dictionary = target["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s runs %s on %s." % [d["name"], ab["name"], td["name"]])
	# Kurzer technischer „Impuls" statt Zauberpose.
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var pulse := create_tween()
	pulse.tween_property(s, "scale", base * Vector2(0.94, 1.08), 0.12)
	pulse.tween_property(s, "scale", base, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("charge")
	var tp: Vector2 = target["sprite"].position
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 16:
		var nan := Sprite2D.new()
		nan.texture = SpriteFactory.circle(2, Color(0.5, 0.9, 1.0))
		nan.material = mat
		nan.position = s.position + Vector2(-30, -10) \
			+ Vector2(randf_range(-10, 10), randf_range(-10, 10))
		nan.z_index = 5
		add_child(nan)
		var fly := nan.create_tween()
		fly.tween_interval(i * 0.03)
		fly.tween_property(nan, "position",
			tp + Vector2(randf_range(-24, 24), randf_range(-30, 20)), 0.35) \
			.set_trans(Tween.TRANS_SINE)
		fly.tween_property(nan, "modulate:a", 0.0, 0.3)
		fly.tween_callback(nan.queue_free)
	await get_tree().create_timer(0.52).timeout
	AudioManager.play_sfx("heal")
	# Hexagonaler Tech-Ring dreht sich auf.
	var hexpts := PackedVector2Array()
	for k in 6:
		var a := k * TAU / 6.0
		hexpts.append(Vector2(cos(a), sin(a)) * 28.0)
	var hex := Line2D.new()
	hex.points = hexpts
	hex.closed = true
	hex.width = 3.0
	hex.default_color = Color(0.5, 0.9, 1.0)
	hex.material = mat
	var hn := Node2D.new()
	hn.position = tp
	hn.scale = Vector2(0.3, 0.3)
	hn.z_index = 5
	hn.add_child(hex)
	add_child(hn)
	var ht := hn.create_tween()
	ht.tween_property(hn, "scale", Vector2(1.7, 1.7), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ht.parallel().tween_property(hn, "rotation", TAU * 0.5, 0.45)
	ht.parallel().tween_property(hn, "modulate:a", 0.0, 0.45)
	ht.tween_callback(hn.queue_free)
	# Schweißfunken (warm) — technisch, nicht magisch-grün.
	_burst(tp, Color(1.0, 0.8, 0.4), 12, 130)
	var amount := int(ab["power"] + d["mag"] * 0.5)
	td["hp"] = mini(td["hp"] + amount, td["max_hp"])
	_float_text(tp, "+%d" % amount, Color(0.5, 0.9, 1.0))
	_refresh_party()
	await get_tree().create_timer(0.7).timeout
