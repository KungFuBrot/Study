class_name BattleEnemyActions
extends BattleSummons
## Gegnerzuege: Nah-/Fernangriffe, Boss-Flaechenangriffe und Boss-Ultimates.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

func _enemy_turn(e: Dictionary) -> void:
	var alive_heroes := []
	for h in heroes:
		if h["data"]["hp"] > 0:
			alive_heroes.append(h)
	if alive_heroes.is_empty():
		return
	e["acts"] += 1
	# Wippen anhalten, solange der Gegner agiert (sonst kämpft der Bob-Loop
	# gegen die Angriffs-Tweens um die Position).
	_pause_bob(e)
	var bob_period := 1.9 if e["is_boss"] else 1.6
	# In der Wut-Phase entfesselt der Boss einmalig seine Ultimative.
	if e["is_boss"] and e["enraged"] and not e.get("ult_used", false):
		e["ult_used"] = true
		await _boss_ultimate(e, alive_heroes)
		_resume_bob(e, bob_period)
		return
	# In Stellung gehen: zurückweichen, ducken, bedrohlich aufglühen —
	# erst dann folgt der Sturmangriff (Anticipation wie bei den Helden).
	var es: Sprite2D = e["sprite"]
	var base_scale: Vector2 = es.get_meta("base_scale", es.scale)
	var ehome: Vector2 = e["home"]
	var amat := CanvasItemMaterial.new()
	amat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var aura := Sprite2D.new()
	aura.texture = SpriteFactory.particle("light_01")
	aura.material = amat
	aura.modulate = Color(1.0, 0.25, 0.15, 0.0)
	aura.position = es.position
	aura.scale = Vector2(0.5, 0.5) * (2.0 if e["is_boss"] else 1.0)
	aura.show_behind_parent = true
	add_child(aura)
	var at := create_tween()
	at.tween_property(aura, "modulate:a", 0.6, 0.3)
	at.tween_property(aura, "modulate:a", 0.0, 0.2)
	at.tween_callback(aura.queue_free)
	var windup := create_tween()
	windup.tween_property(es, "position:x", ehome.x - 26.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	windup.parallel().tween_property(es, "scale", base_scale * Vector2(1.10, 0.90), 0.22)
	windup.parallel().tween_property(es, "modulate", Color(1.35, 0.75, 0.75), 0.22)
	windup.tween_interval(0.14)
	windup.tween_property(es, "scale", base_scale * Vector2(0.94, 1.08), 0.09)
	windup.parallel().tween_property(es, "modulate", e.get("tint", Color.WHITE), 0.09)
	windup.tween_property(es, "scale", base_scale, 0.07)
	await windup.finished
	if e["is_boss"] and e["acts"] % 3 == 0:
		await _boss_aoe(e, alive_heroes)
		_resume_bob(e, bob_period)
		return
	var target: Dictionary = alive_heroes[randi() % alive_heroes.size()]
	var line: String = e.get("attack_line", "")
	if line != "":
		_say(line % [e["name"], target["data"]["name"]])
	else:
		_say("%s attacks %s!" % [e["name"], target["data"]["name"]])
	# „Die Stille" stürmt nicht — sie lässt die Leere unter dem Ziel aufreißen.
	if e["is_boss"] and boss_def.get("theme", "") == "void":
		await _void_grasp(e, target)
		_resume_bob(e, bob_period)
		await get_tree().create_timer(0.25).timeout
		return
	# Fernkämpfer werfen ihr Fraktions-Geschoss statt zu stürmen.
	if e.get("proj", "") != "":
		await _enemy_ranged(e, target)
		_resume_bob(e, bob_period)
		await get_tree().create_timer(0.25).timeout
		return
	# Abstoß-Staub, Anlauf-Lehnen und Geistertrail machen den Sturm wuchtig.
	var efoot := es.texture.get_height() * es.scale.y * 0.5 - 4.0
	_step_dust(ehome + Vector2(0, efoot))
	var charge_lean := create_tween()
	charge_lean.tween_property(es, "rotation", 0.12, 0.12).set_trans(Tween.TRANS_SINE)
	var tw := create_tween()
	tw.tween_property(es, "position", target["sprite"].position + Vector2(-60, 0), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(es, 0.22)
	await tw.finished
	AudioManager.play_sfx("hit")
	_burst(target["sprite"].position, _palette()["hit"], 8, 110)
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.15)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	var back := create_tween()
	back.tween_property(es, "position", e["home"], 0.25).set_trans(Tween.TRANS_QUAD)
	back.parallel().tween_property(es, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	await back.finished
	# Landung abfedern + Staub
	var settle := create_tween()
	settle.tween_property(es, "scale", base_scale * Vector2(1.06, 0.94), 0.07)
	settle.tween_property(es, "scale", base_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_step_dust(e["home"] + Vector2(0, efoot))
	_resume_bob(e, bob_period)
	await get_tree().create_timer(0.25).timeout

## Bézier-Bogenflug für Wurfgeschosse (tween_method-Helfer).
func _arc_step(t: float, node: Node2D, from: Vector2, mid: Vector2, to: Vector2) -> void:
	if not is_instance_valid(node):
		return
	var p1 := from.lerp(mid, t)
	var p2 := mid.lerp(to, t)
	node.position = p1.lerp(p2, t)

static var _paper_tex: Texture2D
## Kleines Schriftstück mit Textzeilen und rotem Stempel (Paragraphengeist).
func _paper_texture() -> Texture2D:
	if _paper_tex == null:
		var img := Image.create(7, 9, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.95, 0.95, 0.90))
		for yy: int in [2, 4, 6]:
			for xx in range(1, 6):
				img.set_pixel(xx, yy, Color(0.35, 0.35, 0.45))
		img.set_pixel(5, 7, Color(0.85, 0.20, 0.20))
		_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex

## Fernangriffe der Monster — jede Fraktion wirft ihr eigenes Geschoss.
func _enemy_ranged(e: Dictionary, target: Dictionary) -> void:
	var es: Sprite2D = e["sprite"]
	var from: Vector2 = es.position + Vector2(34, -8)
	var to: Vector2 = target["sprite"].position
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.15)) - target["data"]["def"], 1)
	# Abwurf-Impuls: kurz nach vorn schnellen und zurückfedern.
	var kick := create_tween()
	kick.tween_property(es, "position:x", es.position.x + 14.0, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick.tween_property(es, "position:x", es.position.x, 0.22) \
		.set_trans(Tween.TRANS_SINE)
	match e["proj"]:
		"sludge":
			# Giftschlamm-Klumpen im hohen Bogen; zerplatzt zu Spritzern + Pfütze
			AudioManager.play_sfx("splat")
			var glob := Sprite2D.new()
			glob.texture = SpriteFactory.circle(7, Color(0.45, 0.85, 0.20))
			glob.position = from
			add_child(glob)
			var wob := glob.create_tween().set_loops()
			wob.tween_property(glob, "scale", Vector2(1.25, 0.8), 0.09)
			wob.tween_property(glob, "scale", Vector2(0.85, 1.2), 0.09)
			var mid := (from + to) * 0.5 + Vector2(0, -95)
			var fly := create_tween()
			fly.tween_method(_arc_step.bind(glob, from, mid, to), 0.0, 1.0, 0.5)
			await fly.finished
			glob.queue_free()
			AudioManager.play_sfx("hit")
			_burst(to, Color(0.55, 1.0, 0.30), 14, 130)
			var pool := Sprite2D.new()
			pool.texture = SpriteFactory.prop("sludge")
			pool.position = to + Vector2(-16, 38)
			pool.scale = Vector2(3.5, 3.0)
			pool.z_index = -9
			add_child(pool)
			var pf := create_tween()
			pf.tween_interval(1.0)
			pf.tween_property(pool, "modulate:a", 0.0, 0.8)
			pf.tween_callback(pool.queue_free)
		"smog":
			# Qualmwolke wabert heran und hüllt das Ziel ein
			AudioManager.play_sfx("wave")
			var cloud := Sprite2D.new()
			cloud.texture = SpriteFactory.particle("smoke_04")
			cloud.position = from
			cloud.scale = Vector2(0.25, 0.25)
			cloud.modulate = Color(0.55, 0.70, 0.45, 0.0)
			cloud.z_index = 5
			add_child(cloud)
			var cfly := create_tween()
			cfly.tween_property(cloud, "modulate:a", 0.85, 0.15)
			cfly.parallel().tween_property(cloud, "position", to, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			cfly.parallel().tween_property(cloud, "scale", Vector2(0.6, 0.55), 0.55)
			cfly.parallel().tween_property(cloud, "rotation", 1.2, 0.55)
			await cfly.finished
			AudioManager.play_sfx("hit")
			_burst(to, Color(0.60, 0.75, 0.50), 10, 90)
			var fade := create_tween()
			fade.tween_property(cloud, "modulate:a", 0.0, 0.45)
			fade.parallel().tween_property(cloud, "scale", Vector2(0.85, 0.8), 0.45)
			fade.tween_callback(cloud.queue_free)
		"coin":
			# Drei Münzen im flachen Bogen — Geld regiert, Geld verletzt
			for k in 3:
				AudioManager.play_sfx("coin")
				var coin := Sprite2D.new()
				coin.texture = SpriteFactory.dtii("coin_anim_f0")
				coin.scale = Vector2(2.6, 2.6)
				coin.position = from
				add_child(coin)
				var cmid := (from + to) * 0.5 + Vector2(0, -40.0 - k * 14.0)
				var cf := create_tween()
				cf.tween_method(_arc_step.bind(coin, from, cmid,
					to + Vector2(randf_range(-14, 14), randf_range(-10, 10))), 0.0, 1.0, 0.3)
				cf.parallel().tween_property(coin, "rotation", TAU * 1.5, 0.3)
				cf.tween_callback(coin.queue_free)
				await get_tree().create_timer(0.14).timeout
			await get_tree().create_timer(0.2).timeout
			AudioManager.play_sfx("hit")
			_burst(to, Color(1.0, 0.85, 0.35), 14, 130)
		"page":
			# Flatterndes Schriftstück — Bürokratie als Wurfwaffe
			AudioManager.play_sfx("wave")
			var page := Sprite2D.new()
			page.texture = _paper_texture()
			page.scale = Vector2(3, 3)
			page.position = from
			add_child(page)
			var flut := page.create_tween().set_loops()
			flut.tween_property(page, "rotation", 0.5, 0.16).set_trans(Tween.TRANS_SINE)
			flut.tween_property(page, "rotation", -0.5, 0.16).set_trans(Tween.TRANS_SINE)
			var pmid := (from + to) * 0.5 + Vector2(0, -60)
			var pfly := create_tween()
			pfly.tween_method(_arc_step.bind(page, from, pmid, to), 0.0, 1.0, 0.6)
			await pfly.finished
			page.queue_free()
			AudioManager.play_sfx("slash")
			_burst(to, Color(0.95, 0.95, 0.90), 12, 120)
		"hate":
			# Gezackter Hassblitz schießt schnurgerade aufs Ziel
			AudioManager.play_sfx("screech")
			var bmat := CanvasItemMaterial.new()
			bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			var bolt := Sprite2D.new()
			bolt.texture = SpriteFactory.particle("spark_04")
			bolt.modulate = Color(1.0, 0.30, 0.20)
			bolt.material = bmat
			bolt.scale = Vector2(0.5, 0.28)
			bolt.position = from
			bolt.rotation = (to - from).angle()
			bolt.z_index = 5
			add_child(bolt)
			var bfly := create_tween()
			bfly.tween_property(bolt, "position", to, 0.22) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await bfly.finished
			bolt.queue_free()
			_flash_screen(Color(1.0, 0.20, 0.15, 0.16))
			AudioManager.play_sfx("hit")
			_burst(to, Color(1.0, 0.40, 0.30), 14, 140)
	_damage_hero(target, dmg)

## Münze schlägt auf: Klimpern + goldene Funken.
func _coin_impact(c: Sprite2D) -> void:
	AudioManager.play_sfx("coin")
	_burst(c.position, Color(1.0, 0.85, 0.35), 5, 80)
	c.queue_free()

## Boss-Spezial: Giftflut, Münzhagel oder Hasstirade über der ganzen Gruppe.
func _boss_aoe(e: Dictionary, targets: Array) -> void:
	var st := _style()
	var theme: String = boss_def.get("theme", "toxic")
	_say("%s winds up — %s!" % [e["name"], boss_def["aoe_name"]])
	AudioManager.play_sfx("roar")
	var es: Sprite2D = e["sprite"]
	var ebase: Vector2 = es.get_meta("base_scale", es.scale)
	var pump := create_tween()
	pump.tween_property(es, "scale", ebase * 1.25, 0.35).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", ebase, 0.15)
	await pump.finished
	_flash_screen(st["flash"])
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.0)
	match theme:
		"gold":
			# Münzhagel: Goldstücke prasseln klimpernd aufs Heldenfeld
			for i in 16:
				var c := Sprite2D.new()
				c.texture = SpriteFactory.dtii("coin_anim_f%d" % (i % 4))
				c.scale = Vector2(2.8, 2.8)
				c.position = Vector2(randf_range(600, 880), -30)
				add_child(c)
				var fall := create_tween()
				fall.tween_interval(randf_range(0.0, 0.4))
				fall.tween_property(c, "position:y", randf_range(250, 380), randf_range(0.28, 0.45)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fall.parallel().tween_property(c, "rotation", randf_range(3.0, 9.0), 0.5)
				fall.tween_callback(_coin_impact.bind(c))
		"hate":
			# Hasstirade: Schallringe aus der Fratze + Blitzsalve
			AudioManager.play_sfx("screech")
			for i in 3:
				_shockring(es.position + Vector2(50, -40), 0.14 * i)
			for i in 6:
				var bmat := CanvasItemMaterial.new()
				bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				var bolt := Sprite2D.new()
				bolt.texture = SpriteFactory.particle("spark_04")
				bolt.modulate = Color(1.0, 0.30, 0.20)
				bolt.material = bmat
				bolt.scale = Vector2(0.55, 0.30)
				bolt.position = es.position + Vector2(50, -40)
				var btarget: Vector2 = (targets[i % targets.size()]["sprite"] as Sprite2D).position \
					+ Vector2(randf_range(-30, 30), randf_range(-30, 30))
				bolt.rotation = (btarget - bolt.position).angle()
				bolt.z_index = 6
				add_child(bolt)
				var bfly := create_tween()
				bfly.tween_interval(i * 0.09)
				bfly.tween_property(bolt, "position", btarget, 0.20) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				bfly.tween_callback(_bolt_impact.bind(bolt))
		"void":
			# Grauschleier: eine fahle Woge der Gleichgültigkeit legt sich übers
			# Feld und entfärbt alles, dazu regnen kalte graue Splitter herab.
			AudioManager.play_sfx("wave")
			var veil := Sprite2D.new()
			veil.texture = SpriteFactory.circle(60, Color(0.62, 0.66, 0.74, 0.6))
			veil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			veil.position = Vector2(300, 360)
			veil.scale = Vector2(2.2, 1.4)
			veil.z_index = 5
			add_child(veil)
			var surge := create_tween()
			surge.tween_property(veil, "position", Vector2(800, 340), 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			surge.parallel().tween_property(veil, "scale", Vector2(5.0, 2.4), 0.6)
			surge.tween_property(veil, "modulate:a", 0.0, 0.4)
			surge.tween_callback(veil.queue_free)
			for i in 12:
				var shard := Sprite2D.new()
				shard.texture = SpriteFactory.circle(4, Color(0.70, 0.74, 0.82))
				shard.position = Vector2(randf_range(600, 880), -20)
				shard.scale = Vector2(0.7, 1.5)
				shard.rotation = randf_range(-0.3, 0.3)
				add_child(shard)
				var fall := create_tween()
				fall.tween_interval(randf_range(0.0, 0.35))
				fall.tween_property(shard, "position:y", randf_range(250, 380), randf_range(0.3, 0.5)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fall.tween_callback(_grey_impact.bind(shard))
		_:
			# Giftflut: Schlammwoge schwappt übers Feld, dazu Säurespritzer
			AudioManager.play_sfx("wave")
			var wave := Sprite2D.new()
			wave.texture = SpriteFactory.circle(60, Color(0.40, 0.75, 0.20, 0.75))
			wave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			wave.position = Vector2(300, 400)
			wave.scale = Vector2(2.0, 1.2)
			wave.z_index = 5
			add_child(wave)
			var surge := create_tween()
			surge.tween_property(wave, "position", Vector2(780, 340), 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			surge.parallel().tween_property(wave, "scale", Vector2(4.5, 2.0), 0.55)
			surge.tween_property(wave, "modulate:a", 0.0, 0.4)
			surge.tween_callback(wave.queue_free)
			for i in 12:
				var drop := Sprite2D.new()
				drop.texture = SpriteFactory.circle(4, Color(0.50, 0.95, 0.25))
				drop.position = Vector2(randf_range(600, 880), -20)
				drop.scale = Vector2(0.8, 1.6)
				add_child(drop)
				var fall := create_tween()
				fall.tween_interval(randf_range(0.0, 0.35))
				fall.tween_property(drop, "position:y", randf_range(250, 380), randf_range(0.3, 0.5)) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fall.tween_callback(_acid_impact.bind(drop))
	await get_tree().create_timer(0.55).timeout
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.7, 0.9)) - t["data"]["def"], 1)
		_burst(t["sprite"].position, st["burst"], 8, 110)
		_damage_hero(t, dmg)
	await get_tree().create_timer(0.7).timeout

## Hassblitz schlägt ein.
func _bolt_impact(bolt: Sprite2D) -> void:
	_burst(bolt.position, Color(1.0, 0.40, 0.30), 8, 110)
	bolt.queue_free()

## Säuretropfen zerplatzt.
func _acid_impact(drop: Sprite2D) -> void:
	_burst(drop.position, Color(0.60, 1.0, 0.30), 6, 90)
	drop.queue_free()

## Grauer Splitter des Grauschleiers zerstäubt.
func _grey_impact(shard: Sprite2D) -> void:
	_burst(shard.position, Color(0.72, 0.76, 0.84), 6, 90)
	shard.queue_free()

## Boss-Ultimative: „Schwarzer Himmel“ (Smogdecke + Säureregen),
## „Feindliche Übernahme“ (Münzstrudel + Riesenmünze) oder
## „Mauer des Hasses“ (Backsteinmauer wächst und kippt auf die Helden).
func _boss_ultimate(e: Dictionary, targets: Array) -> void:
	var st := _style()
	var theme: String = boss_def.get("theme", "toxic")
	var ult_name: String = boss_def["ultimate_name"]
	_say("%s unleashes: %s!" % [e["name"], ult_name])
	var dim := _dim_world(0.55)
	var es: Sprite2D = e["sprite"]
	var base: Vector2 = es.scale
	AudioManager.play_sfx("ult_charge")
	var pump := create_tween()
	pump.tween_property(es, "scale", base * 1.35, 0.55).set_trans(Tween.TRANS_QUAD)
	await pump.finished
	AudioManager.play_sfx("roar")
	_shake_camera(2.0)
	_ult_banner("☠ %s ☠" % ult_name.to_upper(), st["banner"])
	await get_tree().create_timer(0.6).timeout
	match theme:
		"gold": await _ult_uebernahme()
		"hate": await _ult_mauer(targets)
		"void": await _ult_vergessen(es.position)
		_: await _ult_schwarzer_himmel()
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.95, 1.15)) - t["data"]["def"], 1)
		_damage_hero(t, dmg)
	var shrink := create_tween()
	shrink.tween_property(es, "scale", base, 0.3).set_trans(Tween.TRANS_QUAD)
	_undim(dim)
	await get_tree().create_timer(0.9).timeout

## Schlotbaron: Schwarze Smogwolken rollen über den Himmel, dann Säureregen.
func _ult_schwarzer_himmel() -> void:
	AudioManager.play_sfx("wave")
	var clouds: Array = []
	for i in 5:
		var cl := Sprite2D.new()
		cl.texture = SpriteFactory.particle("smoke_04")
		cl.position = Vector2(-140.0 - i * 60.0, 60.0 + (i % 3) * 30.0)
		cl.scale = Vector2(1.3, 0.9)
		cl.modulate = Color(0.14, 0.17, 0.11, 0.92)
		cl.z_index = 6
		add_child(cl)
		clouds.append(cl)
		var roll := create_tween()
		roll.tween_property(cl, "position:x", 120.0 + i * 190.0, 0.9 + i * 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		roll.parallel().tween_property(cl, "rotation", 0.6, 1.0)
	await get_tree().create_timer(1.15).timeout
	_flash_screen(Color(0.5, 1.0, 0.3, 0.30))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	# Ätzender Regen hämmert auf die Heldenseite
	for i in 20:
		var drop := Sprite2D.new()
		drop.texture = SpriteFactory.circle(3, Color(0.55, 1.0, 0.25))
		drop.scale = Vector2(0.6, 3.4)
		drop.position = Vector2(randf_range(590, 900), randf_range(-60, 40))
		drop.z_index = 6
		add_child(drop)
		var fall := create_tween()
		fall.tween_interval(randf_range(0.0, 0.4))
		fall.tween_property(drop, "position:y", randf_range(250, 390), randf_range(0.18, 0.3)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_callback(_acid_impact.bind(drop))
	await get_tree().create_timer(0.9).timeout
	for cl: Sprite2D in clouds:
		var fade := create_tween()
		fade.tween_property(cl, "modulate:a", 0.0, 0.8)
		fade.tween_callback(cl.queue_free)

## „Die Stille": Das große Vergessen — alles Licht der Welt wird zur Gestalt
## gesogen, verdichtet sich zu einer wachsenden Leere-Kugel und kollabiert dann
## in einer entfärbenden Druckwelle, die das ganze Schlachtfeld erfasst.
func _ult_vergessen(center: Vector2) -> void:
	AudioManager.play_sfx("ult_charge")
	var vmat := CanvasItemMaterial.new()
	vmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Phase 1: das Licht wird eingesogen — Streifen konvergieren aufs Zentrum.
	for i in 40:
		var streak := Sprite2D.new()
		streak.texture = SpriteFactory.particle("light_01")
		streak.material = vmat
		streak.modulate = Color(0.72, 0.78, 0.9)
		streak.scale = Vector2(0.35, 0.35)
		var ang := randf() * TAU
		streak.position = center + Vector2(cos(ang), sin(ang)) * randf_range(260.0, 620.0)
		streak.z_index = 6
		add_child(streak)
		var pull := streak.create_tween()
		pull.tween_interval(randf_range(0.0, 0.5))
		pull.tween_property(streak, "position", center, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pull.parallel().tween_property(streak, "scale", Vector2(0.02, 0.02), 0.7)
		pull.tween_callback(streak.queue_free)
	# Wachsende Leere-Kugel (dunkel, verschluckt das Licht) mit fahlem Saum.
	var halo := Sprite2D.new()
	halo.texture = SpriteFactory.circle(48, Color(0.55, 0.60, 0.72, 0.5))
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.material = vmat
	halo.position = center
	halo.scale = Vector2(0.2, 0.2)
	halo.z_index = 6
	add_child(halo)
	var orb := Sprite2D.new()
	orb.texture = SpriteFactory.circle(48, Color(0.04, 0.04, 0.07))
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	orb.position = center
	orb.scale = Vector2(0.1, 0.1)
	orb.z_index = 6
	add_child(orb)
	var grow := create_tween()
	grow.tween_property(orb, "scale", Vector2(3.4, 3.4), 1.1).set_trans(Tween.TRANS_QUAD)
	grow.parallel().tween_property(halo, "scale", Vector2(3.8, 3.8), 1.1).set_trans(Tween.TRANS_QUAD)
	await grow.finished
	# Phase 2: Kollaps und entfärbende Druckwelle über das ganze Feld.
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(0.86, 0.89, 0.96, 0.7))
	_shake_camera(2.8)
	_shockwave(center)
	var collapse := create_tween()
	collapse.tween_property(orb, "scale", Vector2(0.05, 0.05), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	collapse.parallel().tween_property(halo, "scale", Vector2(0.05, 0.05), 0.14)
	collapse.tween_callback(orb.queue_free)
	collapse.tween_callback(halo.queue_free)
	# Expandierender grauer Ring als Schockfront.
	var ring := Sprite2D.new()
	ring.texture = SpriteFactory.circle(48, Color(0.78, 0.82, 0.9, 0.9))
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ring.material = vmat
	ring.position = center
	ring.scale = Vector2(0.1, 0.1)
	ring.z_index = 7
	add_child(ring)
	var expand := ring.create_tween()
	expand.tween_interval(0.14)
	expand.tween_property(ring, "scale", Vector2(26.0, 26.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expand.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	expand.tween_callback(ring.queue_free)
	await get_tree().create_timer(0.5).timeout

## Kreisender Münzstrudel (tween_method-Helfer): zieht sich spiralig zusammen.
func _orbit_step(t: float, node: Node2D, center: Vector2, r0: float, ang0: float) -> void:
	if not is_instance_valid(node):
		return
	var ang := ang0 + t * 9.0
	var r := lerpf(r0, 10.0, t)
	node.position = center + Vector2(cos(ang) * r, sin(ang) * r * 0.55)

## Monopolfürst: Münzstrudel saugt sich zusammen, dann zerschmettert
## eine Riesenmünze das Heldenfeld.
func _ult_uebernahme() -> void:
	var center := Vector2(760, 250)
	AudioManager.play_sfx("charge")
	var coins: Array = []
	for i in 22:
		var c := Sprite2D.new()
		c.texture = SpriteFactory.dtii("coin_anim_f%d" % (i % 4))
		c.scale = Vector2(2.4, 2.4)
		c.z_index = 6
		add_child(c)
		coins.append(c)
		var ang0 := randf() * TAU
		var r0 := randf_range(200, 320)
		_orbit_step(0.0, c, center, r0, ang0)
		var sp := create_tween()
		sp.tween_method(_orbit_step.bind(c, center, r0, ang0), 0.0, 1.0, 1.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sp.parallel().tween_property(c, "rotation", TAU * 3.0, 1.15)
	await get_tree().create_timer(1.2).timeout
	for c: Sprite2D in coins:
		c.queue_free()
	_flash_screen(Color(1.0, 0.9, 0.4, 0.4))
	# Riesenmünze stürzt herab
	var giant := Sprite2D.new()
	giant.texture = SpriteFactory.dtii("coin_anim_f0")
	giant.scale = Vector2(14, 14)
	giant.position = Vector2(center.x, -120)
	giant.z_index = 7
	add_child(giant)
	AudioManager.play_sfx("whistle")
	var gdrop := create_tween()
	gdrop.tween_property(giant, "position:y", 300.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gdrop.parallel().tween_property(giant, "rotation", TAU, 0.4)
	await gdrop.finished
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1, 1, 1, 0.6))
	_shake_camera(2.6)
	_burst(Vector2(center.x, 320), Color(1.0, 0.85, 0.3), 26, 220)
	_burst(Vector2(center.x, 320), Color(1.0, 0.97, 0.8), 18, 170)
	var out := create_tween()
	out.tween_property(giant, "modulate:a", 0.0, 0.5)
	out.parallel().tween_property(giant, "position:y", 340.0, 0.5)
	out.tween_callback(giant.queue_free)
	await get_tree().create_timer(0.4).timeout

## Der Spalter: Eine Backsteinmauer wächst vor den Helden empor —
## und kippt dann krachend auf sie.
func _ult_mauer(targets: Array) -> void:
	AudioManager.play_sfx("stomp")
	_shake_camera(1.6)
	var wall := Node2D.new()
	wall.position = Vector2(590, 400)  # Fußpunkt vor der Heldenreihe
	wall.z_index = 7
	add_child(wall)
	# Versetzte Backsteinreihen wachsen aus dem Boden
	for row in 9:
		for col in 2:
			var b := ColorRect.new()
			b.size = Vector2(34, 22)
			var off := 17.0 if row % 2 == 1 else 0.0
			b.position = Vector2(-42.0 + col * 35.0 + off, -24.0 - row * 23.0)
			b.color = [Color(0.42, 0.16, 0.14), Color(0.36, 0.13, 0.12),
				Color(0.30, 0.11, 0.11)][(row + col) % 3]
			wall.add_child(b)
	wall.scale = Vector2(1, 0.02)
	AudioManager.play_sfx("eruption")
	_shake_camera(2.0)
	# Staubfahne am Fuß der wachsenden Mauer
	var dust := CPUParticles2D.new()
	dust.position = wall.position
	dust.one_shot = true
	dust.explosiveness = 0.8
	dust.amount = 18
	dust.lifetime = 0.9
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.gravity = Vector2(0, 120)
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 140.0
	dust.scale_amount_min = 0.06
	dust.scale_amount_max = 0.14
	dust.color = Color(0.55, 0.40, 0.35, 0.7)
	dust.texture = SpriteFactory.particle("dirt_02")
	dust.emitting = true
	add_child(dust)
	var rise := create_tween()
	rise.tween_property(wall, "scale:y", 1.0, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished
	await get_tree().create_timer(0.5).timeout
	# Die Mauer kippt nach rechts auf die Heldenreihe
	AudioManager.play_sfx("roar")
	var tip := create_tween()
	tip.tween_property(wall, "rotation", PI / 2.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tip.finished
	_flash_screen(Color(1, 1, 1, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.8)
	for t in targets:
		_burst((t["sprite"] as Sprite2D).position, Color(0.85, 0.45, 0.35), 12, 150)
	# Die Mauer zerbirst in umherfliegende Ziegel
	for i in 12:
		var frag := ColorRect.new()
		frag.size = Vector2(16, 10)
		frag.color = [Color(0.42, 0.16, 0.14), Color(0.32, 0.12, 0.11)][i % 2]
		frag.position = Vector2(randf_range(600, 820), randf_range(370, 410))
		frag.rotation = randf() * TAU
		add_child(frag)
		var ft := create_tween()
		ft.tween_property(frag, "position",
			frag.position + Vector2(randf_range(-90, 90), randf_range(-130, -30)), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.parallel().tween_property(frag, "rotation", frag.rotation + randf_range(-5, 5), 0.6)
		ft.tween_property(frag, "position:y", 420.0, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ft.parallel().tween_property(frag, "modulate:a", 0.0, 0.35)
		ft.tween_callback(frag.queue_free)
	wall.queue_free()
	# Staub sanft auslaufen lassen statt hart zu löschen.
	dust.emitting = false
	var df := create_tween()
	df.tween_interval(1.2)
	df.tween_callback(dust.queue_free)
	await get_tree().create_timer(0.5).timeout

## „Die Stille"-Nahangriff: Unter dem Ziel reißt ein dunkler Riss auf, aus dem
## kalte graue Klauen nach oben greifen — kein Sturm, nur lautloses Zupacken.
func _void_grasp(e: Dictionary, target: Dictionary) -> void:
	var ts: Sprite2D = target["sprite"]
	var foot: float = ts.texture.get_height() * ts.scale.y * 0.5 - 6.0
	var base: Vector2 = ts.position + Vector2(0, foot)
	AudioManager.play_sfx("sizzle")
	var rift := Sprite2D.new()
	rift.texture = SpriteFactory.circle(28, Color(0.06, 0.06, 0.10, 0.9))
	rift.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rift.position = base
	rift.scale = Vector2(0.2, 0.05)
	rift.z_index = 3
	add_child(rift)
	var open := create_tween()
	open.tween_property(rift, "scale", Vector2(2.2, 0.5), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await open.finished
	var vmat := CanvasItemMaterial.new()
	vmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 7:
		var claw := Sprite2D.new()
		claw.texture = SpriteFactory.particle("spark_04")
		claw.material = vmat
		claw.modulate = Color(0.70, 0.74, 0.86)
		claw.scale = Vector2(0.3, 0.85)
		claw.position = base + Vector2(randf_range(-32, 32), 0)
		claw.rotation = randf_range(-0.3, 0.3)
		claw.z_index = 4
		add_child(claw)
		var grab := claw.create_tween()
		grab.tween_interval(i * 0.03)
		grab.tween_property(claw, "position:y", base.y - randf_range(60, 115), 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		grab.parallel().tween_property(claw, "scale", Vector2(0.5, 1.35), 0.22)
		grab.tween_property(claw, "modulate:a", 0.0, 0.25)
		grab.tween_callback(claw.queue_free)
	await get_tree().create_timer(0.24).timeout
	AudioManager.play_sfx("hit")
	_burst(ts.position, Color(0.78, 0.82, 0.92), 12, 130)
	var dmg := maxi(int(e["atk"] * randf_range(0.9, 1.15)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	var close := rift.create_tween()
	close.tween_property(rift, "scale", Vector2(0.1, 0.03), 0.3)
	close.parallel().tween_property(rift, "modulate:a", 0.0, 0.25)
	close.tween_callback(rift.queue_free)
