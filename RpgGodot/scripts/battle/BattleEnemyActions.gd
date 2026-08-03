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
	# In der Wut-Phase entfesselt der Boss seine erste Ultimative; ein paar
	# Züge später (oder wenn er fast fällt) folgt einmalig die zweite.
	if e["is_boss"] and e["enraged"] and not e.get("ult_used", false):
		e["ult_used"] = true
		e["ult_act"] = e["acts"]
		await _boss_ultimate(e, alive_heroes, 0)
		_resume_bob(e, bob_period)
		return
	if e["is_boss"] and e["enraged"] and e.get("ult_used", false) \
			and not e.get("ult2_used", false) \
			and (e["acts"] - e.get("ult_act", 0) >= 3 or e["hp"] < e["max_hp"] * 0.2):
		e["ult2_used"] = true
		await _boss_ultimate(e, alive_heroes, 1)
		_resume_bob(e, bob_period)
		return
	# Normale Monster entfesseln alle 3 Züge ihre benannte Spezialattacke —
	# mit eigener Inszenierung (Banner + Ladephase) statt des Standard-Windups.
	var sp: Dictionary = e.get("special", {})
	if not e["is_boss"] and not sp.is_empty() and e["acts"] % 3 == 0:
		await _enemy_special(e, alive_heroes)
		_resume_bob(e, bob_period)
		await get_tree().create_timer(0.25).timeout
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
	# Ausholen und Vorschnellen der Figur selbst (siehe RigFactory.MON_ANIMS) —
	# der Tween darunter bewegt zusätzlich den ganzen Sprite.
	_epose(e, "attack", 0.70)
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
	# Große Bühne wie bei den Ultimates: Welt abdunkeln, Namensbanner,
	# Themen-Funken laufen in den Boss ein, dann Entfesselung mit Stoßwelle.
	var dim := _dim_world(0.4)
	_attack_banner("◆ %s ◆" % String(boss_def["aoe_name"]).to_upper(), st["banner"])
	AudioManager.play_sfx("roar")
	var es: Sprite2D = e["sprite"]
	var ebase: Vector2 = es.get_meta("base_scale", es.scale)
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 8:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color.WHITE)
		spark.material = cmat
		spark.modulate = (st["burst"] as Color).lightened(0.3)
		spark.position = es.position + Vector2(randf_range(-110, 110), randf_range(-100, 100))
		spark.z_index = 5
		add_child(spark)
		var stw := spark.create_tween()
		stw.tween_interval(i * 0.045)
		stw.tween_property(spark, "position", es.position + Vector2(0, -20), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		stw.parallel().tween_property(spark, "scale", Vector2(0.4, 0.4), 0.3)
		stw.tween_callback(spark.queue_free)
	_spell_light(es.position, st["burst"], 240.0, 0.9)
	var pump := create_tween()
	pump.tween_property(es, "scale", ebase * 1.25, 0.55).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", ebase, 0.15)
	await pump.finished
	_flash_screen(st["flash"])
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.4)
	_shockwave(es.position + Vector2(30, -30))
	_punch_zoom(0.09, es.position)
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
	_undim(dim)
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

## Boss-Ultimative — jeder Boss hat zwei (idx 0/1). Erste: „Schwarzer Himmel",
## „Feindliche Übernahme", „Mauer des Hasses", „Das große Vergessen". Zweite:
## „Kernschmelze", „Börsencrash", „Verwerfungslinie", „Oblivion" (Weltabschaltung).
func _boss_ultimate(e: Dictionary, targets: Array, idx := 0) -> void:
	var st := _style()
	var theme: String = boss_def.get("theme", "toxic")
	var ult_name: String = boss_def["ultimate_name"] if idx == 0 \
		else boss_def.get("ultimate2_name", boss_def["ultimate_name"])
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
		"gold":
			if idx == 0: await _ult_uebernahme()
			else: await _ult_crash(targets)
		"hate":
			if idx == 0: await _ult_mauer(targets)
			else: await _ult_spalt(e, targets)
		"void":
			if idx == 0: await _ult_vergessen(es.position, targets)
			else: await _ult_oblivion(targets)
		_:
			if idx == 0: await _ult_schwarzer_himmel()
			else: await _ult_meltdown()
	for t in targets:
		# Die zweite Ultimative ist der Verzweiflungsschlag — sie trifft härter.
		var mul := randf_range(0.95, 1.15) if idx == 0 else randf_range(1.05, 1.25)
		var dmg := maxi(int(e["atk"] * mul) - t["data"]["def"], 1)
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

## Leiser Ascheregen über dem ganzen Feld (Leere-Ultimates).
func _void_ash(dur: float) -> void:
	var ash := CPUParticles2D.new()
	ash.position = Vector2(480, -20)
	ash.amount = 40
	ash.lifetime = 2.2
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(480, 10)
	ash.direction = Vector2(0, 1)
	ash.spread = 12.0
	ash.gravity = Vector2(0, 26)
	ash.initial_velocity_min = 30.0
	ash.initial_velocity_max = 70.0
	ash.scale_amount_min = 0.5
	ash.scale_amount_max = 1.1
	ash.color = Color(0.72, 0.74, 0.80, 0.7)
	ash.texture = SpriteFactory.circle(2, Color.WHITE)
	ash.z_index = 6
	ash.emitting = true
	add_child(ash)
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(ash):
			ash.emitting = false)
	get_tree().create_timer(dur + 2.4).timeout.connect(func():
		if is_instance_valid(ash):
			ash.queue_free())

## „Die Stille": Das große Vergessen — alles Licht der Welt wird zur Gestalt
## gesogen, verdichtet sich zu einer wachsenden Leere-Kugel und kollabiert dann
## in einer entfärbenden Druckwelle. Auch die Helden verlieren dabei sichtbar
## ihre Farben, und stille Asche rieselt über das Feld.
func _ult_vergessen(center: Vector2, targets: Array) -> void:
	AudioManager.play_sfx("ult_charge")
	_void_ash(2.6)
	# Das Vergessen greift nach den Helden: ihre Farben laufen langsam aus.
	var drained := []
	for t in targets:
		var ts: Sprite2D = t["sprite"]
		drained.append([ts, ts.modulate])
		var dt := ts.create_tween()
		dt.tween_property(ts, "modulate", Color(0.52, 0.54, 0.60), 0.9)
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
	# Mit der Druckwelle kehren die Farben der Helden zögernd zurück.
	for pair: Array in drained:
		if is_instance_valid(pair[0]):
			var rt := (pair[0] as Sprite2D).create_tween()
			rt.tween_interval(0.2)
			rt.tween_property(pair[0], "modulate", pair[1], 0.6)
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

## Gezackter Bodenriss-Streifen (Polygonpunkte), Ursprung links bei x=0 —
## Grundform für die Riss-Ultimates (Kernschmelze, Verwerfungslinie).
func _crack_polygon(length: float) -> PackedVector2Array:
	var n := maxi(int(length / 50.0), 4)
	var step := length / n
	var top := PackedVector2Array()
	for i in n + 1:
		top.append(Vector2(i * step,
			randf_range(-7.0, -2.0) if i % 2 == 0 else randf_range(2.0, 7.0)))
	var poly := PackedVector2Array(top)
	for i in range(n, -1, -1):
		poly.append(Vector2(i * step, top[i].y + randf_range(6.0, 10.0)))
	return poly

## Schlotbaron Ult 2: „Core Meltdown" — der Fabrikkern geht durch: Warnblinken,
## ein glühender Riss reißt quer über den Boden, Eruptionen wandern die Linie
## entlang Richtung Helden, Hitzeflimmern — dann birst der Kern.
func _ult_meltdown() -> void:
	AudioManager.play_sfx("alarm")
	for i in 3:
		_flash_screen(Color(1.0, 0.15, 0.05, 0.20))
		_shake_camera(0.6)
		await get_tree().create_timer(0.26).timeout
	# Glühender Riss reißt von der Bossseite zur Heldenseite auf.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var crack := Polygon2D.new()
	crack.polygon = _crack_polygon(800.0)
	crack.color = Color(1.0, 0.45, 0.10)
	crack.material = mat
	crack.position = Vector2(90, 402)
	crack.scale = Vector2(0.0, 1.0)
	crack.z_index = -8
	add_child(crack)
	AudioManager.play_sfx("eruption")
	var rip := create_tween()
	rip.tween_property(crack, "scale:x", 1.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_camera(1.8)
	await rip.finished
	# Glutpuls im Riss, Hitzeflimmern überm Feld, solange der Kern kocht.
	var pulse := crack.create_tween().set_loops(4)
	pulse.tween_property(crack, "modulate", Color(1.4, 0.9, 0.5), 0.18)
	pulse.tween_property(crack, "modulate", Color.WHITE, 0.18)
	var haze := ColorRect.new()
	haze.position = Vector2(60, 120)
	haze.size = Vector2(840, 320)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.material = Fx.heat_haze_material()
	ui_layer.add_child(haze)
	ui_layer.move_child(haze, 3)
	get_tree().create_timer(2.6).timeout.connect(haze.queue_free)
	# Eruptionen wandern den Riss entlang Richtung Helden.
	for x: float in [200.0, 360.0, 520.0, 680.0, 820.0]:
		AudioManager.play_sfx("boom")
		_explosion(Vector2(x, 395), randf_range(1.0, 1.3))
		_shake_camera(1.6)
		await get_tree().create_timer(0.22).timeout
	# Der Kern birst.
	await get_tree().create_timer(0.25).timeout
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1.0, 0.6, 0.2, 0.6))
	_shockwave(Vector2(520, 380))
	_shake_camera(3.0)
	_punch_zoom(0.12, Vector2(520, 370))
	_explosion(Vector2(520, 385), 2.6)
	# Riss verglüht.
	var cool := create_tween()
	cool.tween_interval(0.6)
	cool.tween_property(crack, "modulate:a", 0.0, 0.9)
	cool.tween_callback(crack.queue_free)
	await get_tree().create_timer(0.8).timeout

## Absturz-Schritt des Kurspfeils (tween_method-Helfer für den Börsencrash).
func _crash_step(t: float, chart: Line2D, head: Polygon2D,
		from: Vector2, to: Vector2, idx: int) -> void:
	if not is_instance_valid(chart) or not is_instance_valid(head):
		return
	var p := from.lerp(to, t)
	chart.set_point_position(idx, p)
	head.position = p
	head.rotation = (to - from).angle()

## Monopolfürst Ult 2: „Market Crash" — eine glühend rote Chartlinie hackt
## sich zackig über den Himmel abwärts und stürzt am Ende als Pfeil mitten in
## die Heldenreihe; Münzen spritzen wie Schrapnell.
func _ult_crash(targets: Array) -> void:
	var hc := Vector2.ZERO
	for t in targets:
		hc += (t["sprite"] as Sprite2D).position
	hc /= targets.size()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var chart := Line2D.new()
	chart.width = 7.0
	chart.default_color = Color(1.0, 0.22, 0.15)
	chart.material = mat
	chart.z_index = 7
	add_child(chart)
	# Pfeilspitze, die dem Linienende folgt.
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(18, 0), Vector2(-10, -11), Vector2(-10, 11)])
	head.color = Color(1.0, 0.30, 0.20)
	head.material = mat
	head.z_index = 7
	add_child(head)
	# Zackenkurs: jede Erholung nur ein kurzes Aufbäumen vor dem nächsten Sturz.
	var pts: Array = [Vector2(60, 150), Vector2(190, 190), Vector2(260, 140),
		Vector2(400, 240), Vector2(470, 185), Vector2(610, 300)]
	chart.add_point(pts[0])
	head.position = pts[0]
	for i in range(1, pts.size()):
		chart.add_point(pts[i])
		head.position = pts[i]
		head.rotation = (pts[i] - pts[i - 1]).angle()
		AudioManager.play_sfx("coin")
		_shake_camera(0.5)
		await get_tree().create_timer(0.16).timeout
	# Der finale Absturz: steil hinab in die Heldenreihe.
	AudioManager.play_sfx("whistle")
	var last: Vector2 = pts[pts.size() - 1]
	chart.add_point(last)
	var pl := create_tween()
	pl.tween_method(_crash_step.bind(chart, head, last, hc,
		chart.get_point_count() - 1), 0.0, 1.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pl.finished
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1.0, 0.55, 0.25, 0.5))
	_shockwave(hc)
	_shake_camera(3.0)
	_punch_zoom(0.12, hc)
	_explosion(hc, 1.6)
	_burst(hc, Color(1.0, 0.85, 0.35), 24, 220)
	# Münz-Schrapnell fliegt in Bögen davon.
	for i in 10:
		var c := Sprite2D.new()
		c.texture = SpriteFactory.dtii("coin_anim_f%d" % (i % 4))
		c.scale = Vector2(2.4, 2.4)
		c.position = hc
		add_child(c)
		var to := hc + Vector2(randf_range(-180, 180), randf_range(-40, 30))
		var mid := (hc + to) * 0.5 + Vector2(0, -randf_range(60, 140))
		var cf := create_tween()
		cf.tween_method(_arc_step.bind(c, hc, mid, to), 0.0, 1.0, randf_range(0.4, 0.6))
		cf.parallel().tween_property(c, "rotation", randf_range(3.0, 8.0), 0.6)
		cf.tween_property(c, "modulate:a", 0.0, 0.2)
		cf.tween_callback(c.queue_free)
	# Der Chart verglüht.
	var fade := create_tween()
	fade.tween_property(chart, "modulate:a", 0.0, 0.5)
	fade.parallel().tween_property(head, "modulate:a", 0.0, 0.5)
	fade.tween_callback(chart.queue_free)
	fade.tween_callback(head.queue_free)
	await get_tree().create_timer(0.6).timeout

## Der Spalter Ult 2: „Fault Line" — die Faust fährt in den Boden, ein dunkler
## Riss mit glühender Kante rast unter die Helden, und aus ihm brechen
## Glut-Geysire nacheinander unter jedem einzelnen hervor.
func _ult_spalt(e: Dictionary, targets: Array) -> void:
	var es: Sprite2D = e["sprite"]
	var ehome: Vector2 = es.position
	# Fausthieb: vorschnellen und in den Boden rammen.
	AudioManager.play_sfx("stomp")
	var punch := create_tween()
	punch.tween_property(es, "position", ehome + Vector2(46, 26), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await punch.finished
	_shake_camera(2.2)
	_burst(es.position + Vector2(40, 60), Color(0.9, 0.5, 0.35), 14, 150)
	_step_dust(es.position + Vector2(40, 70))
	# Dunkler Riss mit glühender Kante rast zur Heldenseite.
	var start := Vector2(es.position.x + 60, 405)
	var length := 880.0 - start.x
	var gmat := CanvasItemMaterial.new()
	gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Polygon2D.new()
	glow.polygon = _crack_polygon(length)
	glow.color = Color(1.0, 0.30, 0.15, 0.8)
	glow.material = gmat
	glow.position = start
	glow.scale = Vector2(0.0, 1.6)
	glow.z_index = -8
	add_child(glow)
	var crack := Polygon2D.new()
	crack.polygon = _crack_polygon(length)
	crack.color = Color(0.08, 0.04, 0.05)
	crack.position = start
	crack.scale = Vector2(0.0, 1.0)
	crack.z_index = -8
	add_child(crack)
	AudioManager.play_sfx("eruption")
	var rip := create_tween()
	rip.tween_property(crack, "scale:x", 1.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rip.parallel().tween_property(glow, "scale:x", 1.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_camera(1.8)
	await rip.finished
	# Glut-Geysire brechen nacheinander unter jedem Helden hervor.
	for t in targets:
		var ts: Sprite2D = t["sprite"]
		AudioManager.play_sfx("boom")
		_impact_ring(Vector2(ts.position.x, 400), Color(1.0, 0.4, 0.25, 0.8))
		var gey := CPUParticles2D.new()
		gey.position = Vector2(ts.position.x, 402)
		gey.one_shot = true
		gey.explosiveness = 0.9
		gey.amount = 16
		gey.lifetime = 0.6
		gey.direction = Vector2(0, -1)
		gey.spread = 14.0
		gey.gravity = Vector2(0, 500)
		gey.initial_velocity_min = 260.0
		gey.initial_velocity_max = 420.0
		gey.scale_amount_min = 0.8
		gey.scale_amount_max = 1.8
		gey.color = Color(1.0, 0.5, 0.2)
		gey.texture = SpriteFactory.circle(3, Color.WHITE)
		gey.emitting = true
		add_child(gey)
		get_tree().create_timer(1.4).timeout.connect(gey.queue_free)
		_burst(ts.position, Color(1.0, 0.45, 0.30), 12, 150)
		_shake_camera(1.8)
		await get_tree().create_timer(0.24).timeout
	# Finale: die Verwerfung entlädt sich unter der ganzen Reihe.
	var hc := Vector2.ZERO
	for t in targets:
		hc += (t["sprite"] as Sprite2D).position
	hc /= targets.size()
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1.0, 0.25, 0.15, 0.45))
	_shockwave(hc)
	_shake_camera(2.8)
	_punch_zoom(0.11, hc)
	# Der Riss schließt sich, der Spalter weicht zurück.
	var seal := create_tween()
	seal.tween_interval(0.4)
	seal.tween_property(crack, "modulate:a", 0.0, 0.7)
	seal.parallel().tween_property(glow, "modulate:a", 0.0, 0.7)
	seal.tween_callback(crack.queue_free)
	seal.tween_callback(glow.queue_free)
	var back := create_tween()
	back.tween_property(es, "position", ehome, 0.3).set_trans(Tween.TRANS_QUAD)
	await back.finished
	await get_tree().create_timer(0.4).timeout

## „Die Stille" Ult 2: „Oblivion" — die Welt wird abgeschaltet. Finsternis und
## Ascheregen, ein toter Mond steigt hinter dem Feld auf und fegt graue
## Strahlen über die Helden — dann kollabiert das Bild wie ein alter
## Röhrenfernseher zu einer weißen Linie, einem Punkt, Stille ... und kehrt
## mit dem Knall zurück.
func _ult_oblivion(targets: Array) -> void:
	# Phase 1: tiefe Finsternis legt sich über die Welt, stille Asche fällt.
	AudioManager.play_sfx("wave")
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.05, 0.0)
	veil.size = Vector2(960, 540)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = -3
	add_child(veil)
	var vt := veil.create_tween()
	vt.tween_property(veil, "color:a", 0.5, 0.8)
	_void_ash(3.4)
	await get_tree().create_timer(0.9).timeout
	# Phase 2: ein toter Mond steigt hinter dem Schlachtfeld auf.
	AudioManager.play_sfx("ult_charge")
	var mmat := CanvasItemMaterial.new()
	mmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := Sprite2D.new()
	halo.texture = SpriteFactory.circle(80, Color(0.55, 0.60, 0.72, 0.45))
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.material = mmat
	halo.position = Vector2(310, 640)
	halo.scale = Vector2(1.5, 1.5)
	halo.z_index = -2
	add_child(halo)
	var moon := Sprite2D.new()
	moon.texture = SpriteFactory.circle(64, Color(0.16, 0.17, 0.22))
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	moon.position = Vector2(310, 640)
	moon.z_index = -2
	add_child(moon)
	var rise := create_tween()
	rise.tween_property(moon, "position:y", 130.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(halo, "position:y", 130.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rise.finished
	# Phase 3: graue Strahlen fegen nacheinander über jeden Helden.
	for t in targets:
		var ts: Sprite2D = t["sprite"]
		AudioManager.play_sfx("sizzle")
		_beam(moon.position, ts.position, Color(0.70, 0.75, 0.88), 3.0, 0.10)
		_burst(ts.position, Color(0.78, 0.82, 0.92), 10, 120)
		_shake_camera(1.2)
		await get_tree().create_timer(0.28).timeout
	await get_tree().create_timer(0.3).timeout
	# Phase 4: die Welt wird abgeschaltet — Kollaps zur weißen Linie, zum Punkt.
	var off := CanvasLayer.new()
	off.layer = 25  # über Bühne UND UI — nichts bleibt sichtbar
	add_child(off)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(960, 540)
	off.add_child(black)
	var white := ColorRect.new()
	white.color = Color(0.96, 0.97, 1.0)
	white.size = Vector2(960, 540)
	white.pivot_offset = Vector2(480, 270)
	white.modulate.a = 0.0
	off.add_child(white)
	AudioManager.play_sfx("bigboom")
	var tv := create_tween()
	tv.tween_property(white, "modulate:a", 1.0, 0.08)
	tv.tween_property(white, "scale:y", 0.004, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tv.tween_interval(0.15)
	tv.tween_property(white, "scale:x", 0.002, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tv.finished
	# Einen Atemzug lang: nichts. Absolute Stille.
	await get_tree().create_timer(0.7).timeout
	# ... und die Welt kehrt mit dem Knall zurück.
	off.queue_free()
	AudioManager.play_sfx("nuke")
	_flash_screen(Color(1, 1, 1, 0.9))
	var hc := Vector2.ZERO
	for t in targets:
		hc += (t["sprite"] as Sprite2D).position
	hc /= targets.size()
	_shockwave(hc)
	_shake_camera(3.4)
	_punch_zoom(0.15, hc)
	for t in targets:
		_burst((t["sprite"] as Sprite2D).position, Color(0.82, 0.86, 0.96), 16, 190)
	# Mond und Schleier vergehen.
	var out := create_tween()
	out.tween_property(moon, "modulate:a", 0.0, 0.6)
	out.parallel().tween_property(halo, "modulate:a", 0.0, 0.6)
	out.parallel().tween_property(veil, "color:a", 0.0, 0.6)
	out.tween_callback(moon.queue_free)
	out.tween_callback(halo.queue_free)
	out.tween_callback(veil.queue_free)
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

## Signalfarbe einer Monster-Spezialattacke (Banner, Aura, Funken).
func _special_color(kind: String, proj: String) -> Color:
	match kind:
		"frenzy": return Color(1.0, 0.45, 0.30)
		"slam": return Color(0.95, 0.70, 0.35)
		"drain": return Color(0.72, 0.78, 0.90)
		_:
			match proj:
				"sludge": return Color(0.55, 1.0, 0.30)
				"smog": return Color(0.60, 0.75, 0.50)
				"coin": return Color(1.0, 0.85, 0.35)
				"page": return Color(0.95, 0.95, 0.90)
				_: return Color(1.0, 0.40, 0.30)  # hate
	return Color.WHITE

## Benannte Monster-Spezialattacke (alle 3 Züge): Name als Banner, Ladephase
## mit Aura und einlaufenden Funken, dann die Wirkung je nach "kind".
func _enemy_special(e: Dictionary, targets: Array) -> void:
	var sp: Dictionary = e["special"]
	var col := _special_color(sp["kind"], e.get("proj", ""))
	_say("%s unleashes %s!" % [e["name"], sp["name"]])
	_attack_banner("— %s —" % sp["name"], col)
	AudioManager.play_sfx("charge")
	var es: Sprite2D = e["sprite"]
	var base: Vector2 = es.get_meta("base_scale", es.scale)
	var amat := CanvasItemMaterial.new()
	amat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Aura glüht hinter dem Monster auf, Funken laufen von außen ein.
	var aura := Sprite2D.new()
	aura.texture = SpriteFactory.particle("light_01")
	aura.material = amat
	aura.modulate = Color(col, 0.0)
	aura.position = es.position
	aura.scale = Vector2(0.55, 0.55)
	aura.show_behind_parent = true
	add_child(aura)
	var at := create_tween()
	at.tween_property(aura, "modulate:a", 0.8, 0.3)
	at.parallel().tween_property(aura, "scale", Vector2(1.1, 1.1), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	at.tween_property(aura, "modulate:a", 0.0, 0.25)
	at.tween_callback(aura.queue_free)
	for i in 6:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color.WHITE)
		spark.material = amat
		spark.modulate = col.lightened(0.4)
		spark.position = es.position + Vector2(randf_range(-60, 60), randf_range(-55, 55))
		add_child(spark)
		var stw := spark.create_tween()
		stw.tween_interval(i * 0.04)
		stw.tween_property(spark, "position", es.position, 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		stw.tween_callback(spark.queue_free)
	_spell_light(es.position, col, 170.0, 0.7)
	var pump := create_tween()
	pump.tween_property(es, "scale", base * 1.16, 0.4).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", base, 0.14)
	await pump.finished
	match sp["kind"]:
		"barrage": await _special_barrage(e, targets)
		"frenzy": await _special_frenzy(e, targets[randi() % targets.size()])
		"slam": await _special_slam(e, targets)
		"drain": await _special_drain(e, targets[randi() % targets.size()])

## Salven-Geschoss schlägt ein: Funkenstoß in der Signalfarbe.
func _barrage_impact(glob: Sprite2D, col: Color) -> void:
	AudioManager.play_sfx("hit")
	_burst(glob.position, col, 8, 110)
	glob.queue_free()

## Spezial „Salve": das Fraktionsgeschoss prasselt in Bögen auf ALLE Helden
## nieder — zwei Geschosse pro Held, zeitversetzt abgefeuert.
func _special_barrage(e: Dictionary, targets: Array) -> void:
	var es: Sprite2D = e["sprite"]
	var from: Vector2 = es.position + Vector2(30, -10)
	var col := _special_color("barrage", e.get("proj", ""))
	AudioManager.play_sfx("wave")
	var shots := targets.size() * 2
	for k in shots:
		var t: Dictionary = targets[k % targets.size()]
		var to: Vector2 = (t["sprite"] as Sprite2D).position \
			+ Vector2(randf_range(-18, 18), randf_range(-14, 14))
		var glob := Sprite2D.new()
		match e.get("proj", ""):
			"coin":
				glob.texture = SpriteFactory.dtii("coin_anim_f%d" % (k % 4))
				glob.scale = Vector2(2.6, 2.6)
			"page":
				glob.texture = _paper_texture()
				glob.scale = Vector2(3.0, 3.0)
			"smog":
				glob.texture = SpriteFactory.particle("smoke_04")
				glob.scale = Vector2(0.28, 0.28)
				glob.modulate = Color(0.55, 0.70, 0.45)
			"hate":
				glob.texture = SpriteFactory.particle("spark_04")
				glob.scale = Vector2(0.45, 0.26)
				glob.modulate = Color(1.0, 0.30, 0.20)
				var hmat := CanvasItemMaterial.new()
				hmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glob.material = hmat
			_:
				glob.texture = SpriteFactory.circle(6, Color(0.45, 0.85, 0.20))
		glob.position = from
		glob.z_index = 5
		add_child(glob)
		var mid := (from + to) * 0.5 + Vector2(0, -randf_range(60, 130))
		var fly := create_tween()
		fly.tween_interval(k * 0.09)
		fly.tween_method(_arc_step.bind(glob, from, mid, to), 0.0, 1.0, 0.34)
		fly.parallel().tween_property(glob, "rotation", randf_range(2.0, 5.0), 0.34)
		fly.tween_callback(_barrage_impact.bind(glob, col))
	await get_tree().create_timer(shots * 0.09 + 0.45).timeout
	_shake_camera(1.6)
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.65, 0.85)) - t["data"]["def"], 1)
		_damage_hero(t, dmg)
	await get_tree().create_timer(0.3).timeout

## Spezial „Raserei": drei blitzschnelle Sturmdurchgänge quer durch EIN Ziel,
## Seiten im Wechsel, mit Geistertrail und Hiebspuren.
func _special_frenzy(e: Dictionary, target: Dictionary) -> void:
	var es: Sprite2D = e["sprite"]
	var center: Vector2 = (target["sprite"] as Sprite2D).position
	AudioManager.play_sfx("roar")
	for i in 3:
		if target["data"]["hp"] <= 0:
			break
		var side := 1.0 if i % 2 == 0 else -1.0
		var from := center + Vector2(-side * randf_range(120, 160), randf_range(-30, 30))
		var to := center + Vector2(side * randf_range(120, 160), randf_range(-30, 30))
		es.position = from
		var dash := create_tween()
		dash.tween_property(es, "position", to, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(es, 0.12)
		AudioManager.play_sfx("slash")
		_slash_arc(center + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
		_burst(center, Color(1.0, 0.5, 0.35), 7, 110)
		await dash.finished
		var dmg := maxi(int(e["atk"] * randf_range(0.4, 0.5)) - target["data"]["def"], 1)
		_damage_hero(target, dmg)
		await get_tree().create_timer(0.06).timeout
	_shake_camera(1.5)
	var back := create_tween()
	back.tween_property(es, "position", e["home"], 0.3).set_trans(Tween.TRANS_QUAD)
	await back.finished

## Spezial „Bodenschlag": hoch aufspringen, ein Atemzug in der Luft — dann
## krachend vor der Heldenreihe einschlagen: Stoßwelle, Staub, Trümmer, AoE.
func _special_slam(e: Dictionary, targets: Array) -> void:
	var es: Sprite2D = e["sprite"]
	var base: Vector2 = es.get_meta("base_scale", es.scale)
	var center := Vector2.ZERO
	for t in targets:
		center += (t["sprite"] as Sprite2D).position
	center /= targets.size()
	center += Vector2(-70, 10)  # vor der Heldenreihe aufschlagen
	AudioManager.play_sfx("stomp")
	# Absprung: ducken, dann hoch übers Feld.
	var crouch := create_tween()
	crouch.tween_property(es, "scale", base * Vector2(1.15, 0.8), 0.16)
	await crouch.finished
	var leap := create_tween()
	leap.tween_property(es, "position", Vector2(center.x, -90.0), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap.parallel().tween_property(es, "scale", base * Vector2(0.9, 1.12), 0.34)
	_ghost_trail(es, 0.34)
	await leap.finished
	await get_tree().create_timer(0.22).timeout
	AudioManager.play_sfx("whistle")
	var drop := create_tween()
	drop.tween_property(es, "position", center, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(1, 1, 1, 0.4))
	_shockwave(center)
	_shake_camera(2.6)
	_punch_zoom(0.08, center)
	_impact_ring(center + Vector2(0, 26), Color(0.95, 0.75, 0.45, 0.8))
	var foot := es.texture.get_height() * es.scale.y * 0.5
	_step_dust(center + Vector2(-20, foot * 0.5))
	_step_dust(center + Vector2(20, foot * 0.5))
	# Trümmer fliegen bogenförmig davon.
	var debris := CPUParticles2D.new()
	debris.position = center + Vector2(0, foot * 0.4)
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 12
	debris.lifetime = 0.7
	debris.direction = Vector2(0, -1)
	debris.spread = 70.0
	debris.gravity = Vector2(0, 420)
	debris.initial_velocity_min = 90.0
	debris.initial_velocity_max = 210.0
	debris.scale_amount_min = 0.05
	debris.scale_amount_max = 0.12
	debris.color = Color(0.55, 0.42, 0.34)
	debris.texture = SpriteFactory.particle("dirt_02")
	debris.emitting = true
	add_child(debris)
	get_tree().create_timer(1.4).timeout.connect(debris.queue_free)
	es.scale = base * Vector2(1.2, 0.8)
	var unsquash := create_tween()
	unsquash.tween_property(es, "scale", base, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _hitstop(0.09)
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.7, 0.9)) - t["data"]["def"], 1)
		_burst((t["sprite"] as Sprite2D).position, Color(0.9, 0.7, 0.4), 8, 120)
		_damage_hero(t, dmg)
	await get_tree().create_timer(0.3).timeout
	# Zurück auf die eigene Seite springen.
	var ret := create_tween()
	ret.tween_property(es, "position", e["home"], 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_ghost_trail(es, 0.4)
	await ret.finished

## Spezial „Lebensentzug": fahle Lebensfäden fließen im Bogen vom Ziel zum
## Monster, das sich sichtbar daran labt (Selbstheilung).
func _special_drain(e: Dictionary, target: Dictionary) -> void:
	var es: Sprite2D = e["sprite"]
	var ts: Sprite2D = target["sprite"]
	AudioManager.play_sfx("sizzle")
	var vmat := CanvasItemMaterial.new()
	vmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Kalter Schein legt sich ums Ziel.
	var halo := Sprite2D.new()
	halo.texture = SpriteFactory.particle("light_01")
	halo.material = vmat
	halo.modulate = Color(0.72, 0.78, 0.92, 0.0)
	halo.position = ts.position
	halo.scale = Vector2(0.5, 0.5)
	add_child(halo)
	var ht := create_tween()
	ht.tween_property(halo, "modulate:a", 0.7, 0.25)
	ht.tween_interval(0.7)
	ht.tween_property(halo, "modulate:a", 0.0, 0.3)
	ht.tween_callback(halo.queue_free)
	# Lebensfäden lösen sich vom Helden und fließen zum Monster.
	for i in 14:
		var wisp := Sprite2D.new()
		wisp.texture = SpriteFactory.circle(3, Color(0.80, 0.86, 1.0))
		wisp.material = vmat
		wisp.position = ts.position + Vector2(randf_range(-24, 24), randf_range(-34, 20))
		wisp.z_index = 5
		add_child(wisp)
		var mid := (wisp.position + es.position) * 0.5 + Vector2(0, -randf_range(30, 90))
		var wt := create_tween()
		wt.tween_interval(i * 0.05)
		wt.tween_method(_arc_step.bind(wisp, wisp.position, mid,
			es.position + Vector2(10, -6)), 0.0, 1.0, 0.4)
		wt.parallel().tween_property(wisp, "scale", Vector2(0.5, 0.5), 0.4)
		wt.tween_callback(wisp.queue_free)
	await get_tree().create_timer(0.55).timeout
	AudioManager.play_sfx("hit")
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.05)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	# Das Monster labt sich: Selbstheilung + kaltes Aufglimmen.
	var heal := maxi(int(dmg * 0.6), 1)
	e["hp"] = mini(e["hp"] + heal, e["max_hp"])
	_float_text(es.position, "+%d" % heal, Color(0.55, 1.0, 0.6))
	_sparkle(es.position, Color(0.75, 0.85, 1.0))
	var glow := create_tween()
	glow.tween_property(es, "modulate", Color(1.2, 1.3, 1.45), 0.2)
	glow.tween_property(es, "modulate", e.get("tint", Color.WHITE), 0.35)
	await get_tree().create_timer(0.5).timeout
