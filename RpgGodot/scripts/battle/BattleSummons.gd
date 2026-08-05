class_name BattleSummons
extends BattleRaxActions
## Beschwoerungen: Ifrit, Leviathan und Bahamut mit ihren Kino-Sequenzen.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

## Beschwörungsportal am Boden: doppelter Zauberkreis, Ring und aufsteigende Funken.
func _summon_portal(pos: Vector2, color: Color) -> void:
	AudioManager.play_sfx("summon")
	_cast_circle(pos, color)
	_cast_circle(pos, color.lightened(0.35))
	_impact_ring(pos, color)
	var motes := CPUParticles2D.new()
	motes.position = pos
	motes.amount = 26
	motes.lifetime = 0.9
	motes.one_shot = true
	motes.explosiveness = 0.2
	motes.direction = Vector2(0, -1)
	motes.spread = 26.0
	motes.gravity = Vector2(0, -60)
	motes.initial_velocity_min = 60.0
	motes.initial_velocity_max = 140.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.3
	motes.color = Color(color.r, color.g, color.b, 0.9)
	motes.texture = SpriteFactory.circle(4, Color.WHITE)
	add_child(motes)
	motes.emitting = true
	get_tree().create_timer(1.4).timeout.connect(motes.queue_free)

## Feuersäule, die unter einem Gegner aus dem Boden bricht (Ifrits Höllenfeuer).
func _fire_pillar(pos: Vector2) -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var col := Polygon2D.new()
	var w := 30.0
	col.polygon = PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0),
		Vector2(w, -430), Vector2(-w, -430)])
	col.color = Fx.hot(Color(1.0, 0.5, 0.12, 0.9))
	col.position = pos + Vector2(0, 34)
	col.material = m
	col.scale = Vector2(1, 0.04)
	add_child(col)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-w * 0.22, 0), Vector2(w * 0.22, 0),
		Vector2(w * 0.4, -420), Vector2(-w * 0.4, -420)])
	core.color = Fx.hot(Color(1.0, 0.9, 0.5, 0.95), 1.4)
	core.material = m
	col.add_child(core)
	var tw := create_tween()
	tw.tween_property(col, "scale:y", 1.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.16)
	tw.tween_property(col, "modulate:a", 0.0, 0.3)
	tw.tween_callback(col.queue_free)
	_spell_light(pos, Color(1.0, 0.55, 0.15), 260.0, 0.55, 1.5)

## Ifrit: Feuerportal, der Dämon steigt aus dem Boden, Höllenfeuer-Eruption
## unter allen Gegnern. Wiederholbar (MP), freigeschaltet ab Stufe 3.
func _summon_ifrit(h: Dictionary, sm: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var org := Color(1.0, 0.55, 0.15)
	_say("%s summons %s!" % [d["name"], sm["name"]])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.65)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), org)
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.8, 0.3))
	_anim_cast(s)
	# Volles Zauberritual statt bloßem Aufsteigen (siehe _cast_ritual).
	var ritual := await _cast_ritual(h, Color(1.0, 0.62, 0.25))
	await get_tree().create_timer(0.8).timeout
	_ult_banner("◈ IFRIT ◈", org)
	var gate := Vector2(455, 372)
	_punch_zoom(0.10, gate + Vector2(0, -110))
	_summon_portal(gate, org)
	# Boden birst: dunkle Gesteinskeile fliegen aus dem Portal
	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, -14)])
		shard.color = Color(0.18, 0.12, 0.14)
		shard.position = gate
		shard.rotation = randf_range(-0.5, 0.5)
		add_child(shard)
		var stw := create_tween()
		stw.tween_property(shard, "position", gate +
			Vector2(randf_range(-90, 90), randf_range(-120, -30)), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(shard, "modulate:a", 0.0, 0.5)
		stw.tween_callback(shard.queue_free)
	await get_tree().create_timer(0.55).timeout
	# Ifrit steigt aus dem Feuer, Frames werden lebendig getickt
	var ifr := Sprite2D.new()
	ifr.texture = SpriteFactory.ifrit(0)
	ifr.position = gate + Vector2(0, 130)
	ifr.scale = Vector2(4.6, 4.6)
	ifr.modulate = Color(0.4, 0.2, 0.2, 0.0)
	add_child(ifr)
	# Ifrits Präsenz beleuchtet die Arena (Kind → skaliert mit dem Sprite)
	var ilight := Fx.point_light(Color(1.0, 0.55, 0.2), 65.0, 1.4)
	ifr.add_child(ilight)
	Fx.flicker(ilight, 1.4)
	var fr := [0]
	var tick := Timer.new()
	tick.wait_time = 0.16
	tick.autostart = true
	ifr.add_child(tick)
	tick.timeout.connect(func():
		fr[0] += 1
		ifr.texture = SpriteFactory.ifrit(fr[0]))
	AudioManager.play_sfx("roar")
	_burst(gate, org, 22, 190)
	_explosion(gate, 1.1)
	_shake_camera(1.2)
	var up := create_tween()
	up.tween_property(ifr, "position", gate + Vector2(0, -105), 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	up.parallel().tween_property(ifr, "modulate", Color(1.25, 1.05, 0.9, 1.0), 0.4)
	await up.finished
	# Aufladen: Glutschein hinter dem Dämon schwillt an
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(60, Color(1.0, 0.45, 0.12, 0.5))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.position = ifr.position
	glow.z_index = -1
	glow.scale = Vector2(0.3, 0.3)
	add_child(glow)
	AudioManager.play_sfx("charge")
	var gtw := create_tween()
	gtw.tween_property(glow, "scale", Vector2(3.2, 3.2), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.55).timeout
	_ult_banner("HELLFIRE", Color(1.0, 0.75, 0.25))
	glow.queue_free()
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Hitzeflimmern über der Gegnerzone, solange die Eruption tobt
	var haze := ColorRect.new()
	haze.position = Vector2(40, 120)
	haze.size = Vector2(430, 300)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.material = Fx.heat_haze_material()
	ui_layer.add_child(haze)
	ui_layer.move_child(haze, 3)
	get_tree().create_timer(1.8).timeout.connect(haze.queue_free)
	# Eruption: gestaffelte Feuersäulen unter jedem Gegner
	for e in alive:
		var pos: Vector2 = e["sprite"].position
		_cast_circle(pos + Vector2(0, 34), Color(1.0, 0.3, 0.1))
		_fire_pillar(pos)
		_explosion(pos, 1.3)
		AudioManager.play_sfx("eruption")
		_shake_camera(1.4)
		await get_tree().create_timer(0.14).timeout
	await get_tree().create_timer(0.3).timeout
	_flash_screen(Color(1.0, 0.55, 0.15, 0.6))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	_punch_zoom(0.12, Vector2(300, 280))
	await _hitstop(0.14)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 1.7 + sm["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	# Ifrit verglüht nach oben
	_burst(ifr.position, org, 26, 170)
	var out := create_tween()
	out.tween_property(ifr, "modulate", Color(1.6, 0.8, 0.4, 0.0), 0.5)
	out.parallel().tween_property(ifr, "position:y", ifr.position.y - 60.0, 0.5)
	out.tween_callback(ifr.queue_free)
	s.modulate = Color.WHITE
	_undim(dim)
	await _cast_ritual_end(h, ritual)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)

## Baut den modularen Schlangenkörper: Kopf, Segmente, Schwanz als Kinder.
func _leviathan_body(scale_f: float) -> Node2D:
	var body := Node2D.new()
	var parts: Array = []
	var tail := Sprite2D.new()
	tail.texture = SpriteFactory.leviathan_tail(0)
	var segs := 10
	for i in range(segs, 0, -1):
		var seg := Sprite2D.new()
		seg.texture = SpriteFactory.leviathan_segment(i % 4)
		seg.scale = Vector2.ONE * scale_f * (0.75 + 0.25 * (1.0 - float(i) / segs))
		seg.visible = false
		body.add_child(seg)
	tail.scale = Vector2.ONE * scale_f * 0.75
	tail.visible = false
	body.add_child(tail)
	var head := Sprite2D.new()
	head.texture = SpriteFactory.leviathan_head(0)
	head.scale = Vector2.ONE * scale_f
	head.visible = false
	var hlight := Fx.point_light(Color(0.4, 0.9, 1.0), 55.0, 1.2)
	head.add_child(hlight)
	Fx.pulse(hlight, 1.2, 0.9)
	body.add_child(head)
	# Reihenfolge für die Kurven-Platzierung: Kopf zuerst, dann Segmente, Schwanz
	parts.append(head)
	for i in segs:
		parts.append(body.get_child(segs - 1 - i))
	parts.append(tail)
	body.set_meta("parts", parts)
	return body

## Platziert alle Schlangenteile entlang einer Bogenkurve mit Sinus-Schlängeln.
func _serpent_place(body: Node2D, t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var parts: Array = body.get_meta("parts")
	for i in parts.size():
		var ti: float = t - float(i) * 0.045
		var node: Sprite2D = parts[i]
		if ti <= 0.0 or ti >= 1.0:
			node.visible = ti > 0.0
			continue
		node.visible = true
		var u := 1.0 - ti
		var pos: Vector2 = p0 * u * u + p1 * 2.0 * u * ti + p2 * ti * ti
		var der: Vector2 = (p1 - p0) * 2.0 * u + (p2 - p1) * 2.0 * ti
		var dir := der.normalized()
		var ripple := sin(t * 9.0 - float(i) * 0.8) * 12.0 * minf(1.0, ti * 4.0)
		node.position = pos + Vector2(-dir.y, dir.x) * ripple
		node.rotation = dir.angle()
		node.flip_v = absf(node.rotation) > PI * 0.55
		var f := int(t * 14.0 + i) % 4
		if i == 0:
			node.texture = SpriteFactory.leviathan_head(f)
		elif i == parts.size() - 1:
			node.texture = SpriteFactory.leviathan_tail(f)
		else:
			node.texture = SpriteFactory.leviathan_segment(f)

## Leviathan: die Arena flutet, die Seeschlange bricht aus dem Strudel und
## fegt über die Gegner, dann begräbt eine Flutwelle alles. Ab Stufe 5.
func _summon_leviathan(h: Dictionary, sm: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var blue := Color(0.4, 0.8, 1.0)
	_say("%s summons %s!" % [d["name"], sm["name"]])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.6)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), blue)
	_cast_circle(s.position + Vector2(0, 40), Color(0.7, 0.95, 1.0))
	_anim_cast(s)
	# Volles Zauberritual statt bloßem Aufsteigen (siehe _cast_ritual).
	var ritual := await _cast_ritual(h, Color(0.55, 0.90, 1.0))
	await get_tree().create_timer(0.8).timeout
	_ult_banner("◈ LEVIATHAN ◈", blue)
	_punch_zoom(0.08, Vector2(400, 330))
	# Die Arena läuft mit Wasser voll (echter Shimmer-Shader)
	var water := Polygon2D.new()
	water.polygon = PackedVector2Array([Vector2(0, 0), Vector2(960, 0),
		Vector2(960, 220), Vector2(0, 220)])
	water.color = Color(0.25, 0.55, 0.85, 0.55)
	water.material = Fx.water_material()
	water.position = Vector2(0, 560)
	water.z_index = -2
	add_child(water)
	AudioManager.play_sfx("wave")
	var flood := create_tween()
	flood.tween_property(water, "position:y", 350.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flood.finished
	# Strudel, dann bricht die Schlange heraus und stürzt über die Gegnerreihe
	var pool := Vector2(260, 372)
	_summon_portal(pool, blue)
	_impact_ring(pool, Color(0.7, 0.95, 1.0))
	await get_tree().create_timer(0.4).timeout
	var serp := _leviathan_body(4.0)
	add_child(serp)
	AudioManager.play_sfx("roar")
	AudioManager.play_sfx("splash")
	_burst(pool, Color(0.75, 0.92, 1.0), 30, 240)
	_shake_camera(1.6)
	var p0 := pool + Vector2(-20, 40)
	var p1 := Vector2(180, -70)
	var p2 := Vector2(640, 430)
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	var hit_done := {}
	var step := func(t: float) -> void:
		_serpent_place(serp, t, p0, p1, p2)
		# Beim Überflug: Gischt und Ringe über jedem Gegner
		var u := 1.0 - t
		var head_pos: Vector2 = p0 * u * u + p1 * 2.0 * u * t + p2 * t * t
		for e in alive:
			var key: int = e["sprite"].get_instance_id()
			if not hit_done.has(key) and absf(head_pos.x - e["sprite"].position.x) < 40.0:
				hit_done[key] = true
				_impact_ring(e["sprite"].position, blue)
				_burst(e["sprite"].position + Vector2(0, -20), Color(0.75, 0.92, 1.0), 14, 150)
				AudioManager.play_sfx("splash")
	var sweep := create_tween()
	sweep.tween_method(step, 0.0, 1.0, 1.7)
	await sweep.finished
	_burst(p2 + Vector2(0, -40), Color(0.75, 0.92, 1.0), 26, 220)
	serp.queue_free()
	await get_tree().create_timer(0.15).timeout
	# Flutwellen-Finale: eine Wasserwand fegt von rechts über die Gegner
	var wave := Polygon2D.new()
	wave.polygon = PackedVector2Array([Vector2(0, 0), Vector2(90, -80),
		Vector2(150, -220), Vector2(235, -245), Vector2(310, -140),
		Vector2(370, -40), Vector2(410, 0)])
	wave.color = Color(0.3, 0.6, 0.92, 0.85)
	wave.material = Fx.water_material()
	# Steigt mittig aus der Flut auf (rechts der Gegner, links der Helden)
	# und bricht dann nach links über die Gegnerreihe.
	wave.position = Vector2(255, 470)
	wave.scale = Vector2(1, 0.05)
	wave.z_index = 1
	add_child(wave)
	var foam := CPUParticles2D.new()
	foam.position = Vector2(190, -230)
	foam.amount = 40
	foam.lifetime = 0.4
	foam.direction = Vector2(-1, -0.3)
	foam.spread = 30.0
	foam.gravity = Vector2(0, 240)
	foam.initial_velocity_min = 120.0
	foam.initial_velocity_max = 260.0
	foam.scale_amount_min = 0.6
	foam.scale_amount_max = 1.6
	foam.color = Color(0.9, 0.97, 1.0, 0.9)
	foam.texture = SpriteFactory.circle(4, Color.WHITE)
	wave.add_child(foam)
	foam.emitting = true
	AudioManager.play_sfx("wave")
	var wtw := create_tween()
	wtw.tween_property(wave, "scale:y", 1.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wtw.tween_property(wave, "position:x", -560.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.45).timeout
	_flash_screen(Color(0.5, 0.8, 1.0, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	_punch_zoom(0.12, Vector2(300, 300))
	_shockwave(Vector2(280, 300))
	await _hitstop(0.16)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 1.9 + sm["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	wave.queue_free()
	# Wasser läuft ab
	var drain := create_tween()
	drain.tween_property(water, "position:y", 570.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	drain.parallel().tween_property(water, "modulate:a", 0.0, 0.7)
	drain.tween_callback(water.queue_free)
	s.modulate = Color.WHITE
	_undim(dim)
	await _cast_ritual_end(h, ritual)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)

## Draconische Silhouette für Bahamut: dunkler Körper mit Schwingen, glühender
## Kern und Augen (alles additiv). Gibt den Wurzelknoten zurück.
## Bahamut (Milos 3. Beschwörung, nach dem 3. Bosssieg): Der Drachenkönig fährt
## über dem Gegnerfeld herab, lädt am Maul die „Megaflare" und entlädt einen
## gewaltigen Strahl über die gesamte Reihe. Milos stärkste Beschwörung.
func _summon_bahamut(h: Dictionary, sm: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var gold := Color(1.0, 0.72, 0.3)
	_say("%s summons %s!" % [d["name"], sm["name"]])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.66)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), gold)
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.9, 0.6))
	_anim_cast(s)
	# Volles Zauberritual statt bloßem Aufsteigen (siehe _cast_ritual).
	var ritual := await _cast_ritual(h, Color(1.0, 0.88, 0.55))
	await get_tree().create_timer(0.8).timeout
	_ult_banner("◈ BAHAMUT ◈", gold)
	_punch_zoom(0.08, Vector2(360, 300))
	# Drache fährt aus einem Portal hoch über dem Gegnerfeld herein.
	var origin := Vector2(250, -40)
	_summon_portal(Vector2(250, 90), gold)
	var bsc := 3.4
	var drag := Sprite2D.new()
	drag.texture = SpriteFactory.bahamut(0)
	drag.position = origin
	drag.scale = Vector2(bsc, bsc)
	drag.z_index = 6
	add_child(drag)
	# Flügelschlag-Frames werden lebendig getickt (Bewegungsanimation).
	var bfr := [0]
	var btick := Timer.new()
	btick.wait_time = 0.13
	btick.autostart = true
	drag.add_child(btick)
	btick.timeout.connect(func():
		bfr[0] += 1
		drag.texture = SpriteFactory.bahamut(bfr[0]))
	# Drachenpräsenz beleuchtet das Feld (Kind → skaliert mit dem Sprite).
	var blight := Fx.point_light(Color(1.0, 0.7, 0.3), 62.0, 1.2)
	drag.add_child(blight)
	Fx.flicker(blight, 1.2)
	AudioManager.play_sfx("roar")
	var descend := drag.create_tween()
	descend.tween_property(drag, "position:y", 100.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await descend.finished
	_shake_camera(1.2)
	# Sanftes Schweben, während sich die Megaflare am Maul auflädt.
	var hover := drag.create_tween().set_loops()
	hover.tween_property(drag, "position:y", 92.0, 0.6).set_trans(Tween.TRANS_SINE)
	hover.tween_property(drag, "position:y", 104.0, 0.6).set_trans(Tween.TRANS_SINE)
	# Fixer Ursprungspunkt des Strahls am Maul — bobbt bewusst NICHT mit,
	# damit der Schwenk sich sauber nur am unteren Ende auffächert.
	var maw := Vector2(250.0, 100.0 + 20.0 * bsc)
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var orb := Sprite2D.new()
	orb.texture = SpriteFactory.particle("flare_01")
	orb.material = cmat
	orb.position = maw
	orb.scale = Vector2(0.05, 0.05)
	orb.modulate = Color(1.0, 0.8, 0.4)
	orb.z_index = 7
	add_child(orb)
	AudioManager.play_sfx("charge")
	var charge := orb.create_tween()
	charge.tween_property(orb, "scale", Vector2(0.9, 0.9), 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	charge.parallel().tween_property(orb, "modulate", Color(1.0, 0.95, 0.8), 0.9)
	# Funken saugen in den Ladepunkt.
	for i in 14:
		var sp := Sprite2D.new()
		sp.texture = SpriteFactory.particle("spark_04")
		sp.material = cmat
		sp.modulate = gold
		sp.scale = Vector2(0.3, 0.3)
		sp.position = maw + Vector2(randf_range(-90, 90), randf_range(-70, 70))
		sp.z_index = 7
		add_child(sp)
		var suck := sp.create_tween()
		suck.tween_interval(randf_range(0.0, 0.5))
		suck.tween_property(sp, "position", maw, 0.4).set_trans(Tween.TRANS_QUAD)
		suck.parallel().tween_property(sp, "scale", Vector2(0.05, 0.05), 0.4)
		suck.tween_callback(sp.queue_free)
	await charge.finished
	hover.kill()
	# Entladung: ein breiter Megaflare-Strahl bricht über das Gegnerfeld.
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Strahl entspringt am Maul (position = maw) und reicht weit übers Feld
	# hinaus, damit er auch im geschwenkten Zustand voll deckt.
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(-16, 0), Vector2(16, 0),
		Vector2(120, 600), Vector2(-120, 600)])
	beam.color = Color(1.0, 0.9, 0.6, 0.0)
	beam.position = maw
	beam.material = cmat
	beam.z_index = 7
	add_child(beam)
	var core_beam := Polygon2D.new()
	core_beam.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0),
		Vector2(52, 600), Vector2(-52, 600)])
	core_beam.color = Color(1, 1, 1, 0.0)
	core_beam.position = maw
	core_beam.material = cmat
	core_beam.z_index = 8
	add_child(core_beam)
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1.0, 0.92, 0.7, 0.6))
	_shake_camera(2.4)
	_punch_zoom(0.14, Vector2(300, 320))
	var bt := create_tween()
	bt.tween_property(beam, "color:a", 0.85, 0.12)
	bt.parallel().tween_property(core_beam, "color:a", 0.95, 0.12)
	var orb_fade := orb.create_tween()
	orb_fade.tween_property(orb, "scale", Vector2(1.7, 1.7), 0.12)
	orb_fade.parallel().tween_property(orb, "modulate:a", 0.0, 0.6)
	orb_fade.tween_callback(orb.queue_free)
	_shockwave(Vector2(maw.x, maw.y + 120.0))
	# Nach dem Auflösen fegt der Strahl um seinen fixen Ursprung leicht nach
	# rechts und links — nur das ferne Ende wandert, das Maul bleibt fix.
	var sweep := create_tween()
	sweep.tween_property(beam, "rotation", 0.14, 0.30).set_trans(Tween.TRANS_SINE)
	sweep.parallel().tween_property(core_beam, "rotation", 0.14, 0.30).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(beam, "rotation", -0.14, 0.52).set_trans(Tween.TRANS_SINE)
	sweep.parallel().tween_property(core_beam, "rotation", -0.14, 0.52).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(beam, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	sweep.parallel().tween_property(core_beam, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	await _hitstop(0.18)
	# Schaden trifft, während der Strahl über die Gegner hinwegfegt.
	for e in alive:
		if e["alive"]:
			_burst(e["sprite"].position, Color(1.0, 0.9, 0.6), 18, 200)
			var dmg: int = int((d["mag"] * 2.1 + sm["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	# Der Schadensdurchlauf kann länger dauern als der Schwenk (mehrere Gegner
	# = mehrere Auflöse-Animationen). Ist der Sweep dann schon fertig, dürfen wir
	# NICHT erneut auf sein finished-Signal warten — das käme nie wieder und der
	# Strahl/Drache bliebe für immer stehen (Hänger). Nur warten, wenn er läuft.
	if sweep.is_running():
		await sweep.finished
	var bfade := beam.create_tween()
	bfade.tween_property(beam, "color:a", 0.0, 0.4)
	bfade.parallel().tween_property(core_beam, "color:a", 0.0, 0.4)
	bfade.tween_callback(beam.queue_free)
	bfade.tween_callback(core_beam.queue_free)
	# Der Drache steigt zurück in den Himmel und verblasst.
	var leave := drag.create_tween()
	leave.tween_property(drag, "position:y", -80.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.parallel().tween_property(drag, "modulate:a", 0.0, 0.6)
	leave.tween_callback(drag.queue_free)
	s.modulate = Color.WHITE
	_undim(dim)
	await _cast_ritual_end(h, ritual)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)
