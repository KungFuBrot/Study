class_name BattleBossCine
extends BattleUi
## Boss-Inszenierung: Auftritt und Reveal, Wut-Phase, Phasenwechsel der Stille,
## dramatischer Boss-Tod.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

## Phasenwechsel von „Die Stille" (statt Wut): die Leere verdichtet sich, das
## Licht wird fahler, die Augen erlöschen zu kaltem Weiß. Der Angriff steigt.
func _boss4_phase(e: Dictionary) -> void:
	AudioManager.play_sfx("ult_charge")
	_say("%s simply stops being — the void around it devours the light." % e["name"])
	var es: Sprite2D = e["sprite"]
	_flash_screen(Color(0.85, 0.88, 0.96, 0.4))
	_shake_camera(1.8)
	var tint := Color(0.55, 0.60, 0.72)
	e["tint"] = tint
	es.set_meta("tint", tint)
	var tw := create_tween()
	tw.tween_property(es, "modulate", Color(1.7, 1.8, 2.0), 0.25)
	tw.tween_property(es, "modulate", tint, 0.55)
	if es.has_meta("eyes") and is_instance_valid(es.get_meta("eyes")):
		var ey: Sprite2D = es.get_meta("eyes")
		var et := create_tween()
		et.tween_property(ey, "modulate", Color(2.0, 0.25, 0.18, 1.0), 0.3)  # Augen lodern rot auf
		et.parallel().tween_property(ey, "scale", Vector2(2.6, 1.0), 0.3)
	# Splitter saugen einwärts — die Leere zieht sich enger um die Gestalt.
	var vmat := CanvasItemMaterial.new()
	vmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 18:
		var sh := Sprite2D.new()
		sh.texture = SpriteFactory.particle("spark_04")
		sh.material = vmat
		sh.modulate = Color(0.68, 0.73, 0.85)
		sh.scale = Vector2(0.4, 0.4)
		var ang := randf() * TAU
		sh.position = es.position + Vector2(cos(ang), sin(ang)) * randf_range(120.0, 240.0)
		sh.z_index = 6
		add_child(sh)
		var cv := sh.create_tween()
		cv.tween_interval(randf_range(0.0, 0.3))
		cv.tween_property(sh, "position", es.position + Vector2(0, -40), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		cv.parallel().tween_property(sh, "scale", Vector2(0.05, 0.05), 0.5)
		cv.tween_callback(sh.queue_free)
	await get_tree().create_timer(1.1).timeout

## Wut-Phase des Bosses: Aufschrei, Färbung, mehr Angriff (Farbe je Thema).
func _boss_enrage(e: Dictionary) -> void:
	e["enraged"] = true
	e["atk"] = int(e["atk"] * 1.35)
	# „Die Stille" wird nicht wütend — die Leere um sie herum vertieft sich nur.
	if boss_def.get("theme", "") == "void":
		await _boss4_phase(e)
		return
	AudioManager.play_sfx("charge")
	_say("%s flies into a rage!" % e["name"])
	var es: Sprite2D = e["sprite"]
	var st := _style()
	_flash_screen(st["flash"])
	_shake_camera(2.2)
	var rage_col: Color = st["rage"]
	# Bleibende Wut-Tönung: abgeschwächte Wutfarbe Richtung Weiß.
	var tint: Color = rage_col.lerp(Color.WHITE, 0.6)
	e["tint"] = tint
	es.set_meta("tint", tint)
	var tw := create_tween()
	tw.tween_property(es, "modulate", rage_col, 0.3)
	tw.tween_property(es, "modulate", tint, 0.4)
	# Die Augen-Glut lodert in der Wut dauerhaft heller
	if es.has_meta("eyes") and is_instance_valid(es.get_meta("eyes")):
		var ey: Sprite2D = es.get_meta("eyes")
		var et := create_tween()
		et.tween_property(ey, "modulate:a", 1.0, 0.3)
		et.parallel().tween_property(ey, "scale", Vector2(2.0, 1.0), 0.3)
	_burst(es.position, st["burst"], 22, 190)
	AudioManager.play_sfx("roar")
	await get_tree().create_timer(1.0).timeout

## Inszenierter Boss-Tod: Zeitlupe, Explosionskette, weißer Blitz, Zerfall.
func _boss_death(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	_say("%s collapses!" % e["name"])
	await _hitstop(0.25)
	AudioManager.play_sfx("roar")
	# Explosionskette über den ganzen Körper
	for i in 6:
		var off := Vector2(randf_range(-70, 70), randf_range(-100, 100))
		_explosion(s.position + off)
		AudioManager.play_sfx("boom")
		_shake_camera(1.6)
		await get_tree().create_timer(0.18).timeout
	_flash_screen(Color(1, 1, 1, 0.85))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.5)
	_burst(s.position, Color(1.0, 0.3, 0.1), 30, 260)
	_burst(s.position, Color(0.95, 0.9, 0.8), 24, 200)
	var tw := create_tween()
	tw.tween_property(s, "modulate", Color(2.0, 2.0, 2.0, 0.0), 1.1)
	tw.parallel().tween_property(s, "position:y", s.position.y + 60.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	s.visible = false
	if boss_bar_holder != null:
		var bt := boss_bar_holder.create_tween()
		bt.tween_property(boss_bar_holder, "modulate:a", 0.0, 0.5)
	await get_tree().create_timer(0.4).timeout

## Boss-Auftritt: Kino-Balken, Stampfen, Brüllen, Namensbanner, HP-Leiste.
func _boss_entrance() -> void:
	# Kino-Balken gleiten herein
	var bar_top := ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.size = Vector2(960, 46)
	bar_top.position = Vector2(0, -46)
	ui_layer.add_child(bar_top)
	var bar_bot := ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.size = Vector2(960, 46)
	bar_bot.position = Vector2(0, 540)
	ui_layer.add_child(bar_bot)
	var bars := create_tween().set_parallel(true)
	bars.tween_property(bar_top, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bars.tween_property(bar_bot, "position:y", 494.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var st := _style()
	# Erzähler kündigt an, dann materialisiert sich der Boss themengerecht.
	_say(boss_def["entrance_line"])
	var boss_e := {}
	for e in enemies:
		if e["is_boss"]:
			boss_e = e
	await _boss_reveal(boss_e, boss_def.get("theme", "toxic"))
	boss_e["bob"] = _idle_bob(boss_e["sprite"], 1.9)
	# Wortwechsel: der Boss stellt sich vor, die Helden antworten.
	for line: Array in boss_def.get("intro", []):
		_say("%s: \"%s\"" % [line[0], line[1]])
		await get_tree().create_timer(2.2).timeout
	AudioManager.play_sfx("roar")
	_shake_camera(2.4)
	_punch_zoom(0.14, Vector2(230, 240))
	_flash_screen(st["flash"])
	var banner := Label.new()
	banner.text = "☠  %s  ☠" % boss_def["name"].to_upper()
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", st["banner"])
	banner.add_theme_color_override("font_outline_color", st["banner_outline"])
	banner.add_theme_constant_override("outline_size", 12)
	banner.custom_minimum_size = Vector2(960, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 150)
	banner.pivot_offset = Vector2(480, 30)
	banner.modulate.a = 0.0
	banner.scale = Vector2(2.6, 2.6)
	ui_layer.add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)
	await get_tree().create_timer(1.2).timeout
	# Balken raus, Boss-HP-Leiste rein
	var out := create_tween().set_parallel(true)
	out.tween_property(bar_top, "position:y", -46.0, 0.3)
	out.tween_property(bar_bot, "position:y", 540.0, 0.3)
	out.chain().tween_callback(bar_top.queue_free)
	out.chain().tween_callback(bar_bot.queue_free)
	if boss_bar_holder != null:
		var bt := create_tween()
		bt.tween_property(boss_bar_holder, "modulate:a", 1.0, 0.5)

## Themengerechte Material-Werdung des Bosses: der Schlotbaron wälzt sich
## aus einem Schlammloch, der Monopolfürst schwebt im Goldregen herab,
## der Spalter verdichtet sich aus Glut und Schatten.
func _boss_reveal(e: Dictionary, theme: String) -> void:
	var s: Sprite2D = e["sprite"]
	var home: Vector2 = e["home"]
	var tint: Color = s.get_meta("tint", Color.WHITE)
	match theme:
		"gold":
			# Goldregen — dann fährt der Fürst wie mit dem Chef-Aufzug herab.
			var shower := CPUParticles2D.new()
			shower.position = home + Vector2(0, -260)
			shower.amount = 40
			shower.lifetime = 1.2
			shower.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			shower.emission_rect_extents = Vector2(70, 8)
			shower.direction = Vector2(0, 1)
			shower.spread = 8.0
			shower.gravity = Vector2(0, 320)
			shower.initial_velocity_min = 80.0
			shower.initial_velocity_max = 140.0
			shower.scale_amount_min = 0.5
			shower.scale_amount_max = 1.1
			shower.color = Color(1.0, 0.87, 0.4, 0.9)
			shower.texture = SpriteFactory.circle(2, Color.WHITE)
			add_child(shower)
			AudioManager.play_sfx("coin")
			s.position = home + Vector2(0, -320)
			s.modulate = Color(tint.r, tint.g, tint.b, 0.0)
			var down := create_tween()
			down.tween_property(s, "modulate:a", 1.0, 0.25)
			down.parallel().tween_property(s, "position:y", home.y, 0.9) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await down.finished
			AudioManager.play_sfx("stomp")
			_shake_camera(2.2)
			_burst(home + Vector2(0, 100), Color(1.0, 0.85, 0.35), 18, 170)
			shower.emitting = false
			var sf := create_tween()
			sf.tween_interval(1.4)
			sf.tween_callback(shower.queue_free)
		"hate":
			# Aus Glut und Schatten: erst ein schwarzer Schemen in einer
			# aufsteigenden Glutsäule, dann flutet die Farbe hinein.
			s.position = home
			s.modulate = Color(0, 0, 0, 0.0)
			AudioManager.play_sfx("screech")
			var col := CPUParticles2D.new()
			col.position = home + Vector2(0, 110)
			col.amount = 50
			col.lifetime = 1.1
			col.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			col.emission_rect_extents = Vector2(60, 6)
			col.direction = Vector2(0, -1)
			col.spread = 10.0
			col.gravity = Vector2(0, -240)
			col.initial_velocity_min = 90.0
			col.initial_velocity_max = 170.0
			col.scale_amount_min = 0.5
			col.scale_amount_max = 1.2
			col.color = Color(1.0, 0.35, 0.12, 0.9)
			col.texture = SpriteFactory.circle(2, Color.WHITE)
			add_child(col)
			var fade_in := create_tween()
			fade_in.tween_property(s, "modulate:a", 1.0, 0.7)
			await fade_in.finished
			_shockring(home + Vector2(0, -20), 0.0)
			AudioManager.play_sfx("eruption")
			_flash_screen(Color(1.0, 0.2, 0.1, 0.3))
			_shake_camera(1.8)
			var flood := create_tween()
			flood.tween_property(s, "modulate", tint, 0.6)
			col.emitting = false
			await flood.finished
			var cf := create_tween()
			cf.tween_interval(1.2)
			cf.tween_callback(col.queue_free)
		"void":
			# Aus dem Nichts: kein Getöse. Kalte Splitter fallen von überall nach
			# INNEN und verdichten sich zur Gestalt, die weißkalt aufscheint und
			# dann ins fahle Grau verebbt — als würde die Welt selbst erlöschen.
			s.position = home
			s.modulate = Color(1.8, 1.9, 2.1, 0.0)
			AudioManager.play_sfx("ult_charge")
			var vmat := CanvasItemMaterial.new()
			vmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			for i in 24:
				var sh := Sprite2D.new()
				sh.texture = SpriteFactory.particle("spark_04")
				sh.material = vmat
				sh.modulate = Color(0.70, 0.75, 0.86)
				sh.scale = Vector2(0.45, 0.45)
				var ang := randf() * TAU
				sh.position = home + Vector2(cos(ang), sin(ang)) * randf_range(170.0, 320.0)
				sh.z_index = 6
				add_child(sh)
				var cv := sh.create_tween()
				cv.tween_interval(randf_range(0.0, 0.45))
				cv.tween_property(sh, "position", home + Vector2(0, -30), 0.55) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				cv.parallel().tween_property(sh, "scale", Vector2(0.05, 0.05), 0.55)
				cv.tween_callback(sh.queue_free)
			var appear := create_tween()
			appear.tween_interval(0.5)
			appear.tween_property(s, "modulate", Color(1.9, 2.0, 2.2, 1.0), 0.5)
			await appear.finished
			_flash_screen(Color(0.85, 0.88, 0.96, 0.5))
			_shake_camera(1.0)
			var settle := create_tween()
			settle.tween_property(s, "modulate", tint, 0.9)
		_:
			# Aus dem Schlammloch: die Pfütze wächst, der Baron wälzt sich hoch.
			var pool := Sprite2D.new()
			pool.texture = SpriteFactory.circle(40, Color(0.35, 0.65, 0.18, 0.85))
			pool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			pool.position = home + Vector2(0, 110)
			pool.scale = Vector2(0.2, 0.06)
			pool.z_index = -9
			add_child(pool)
			AudioManager.play_sfx("splat")
			var grow := create_tween()
			grow.tween_property(pool, "scale", Vector2(3.6, 1.0), 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await grow.finished
			s.position = home + Vector2(0, 170)
			s.modulate = Color(tint.r, tint.g, tint.b, 0.0)
			AudioManager.play_sfx("wave")
			var rise := create_tween()
			rise.tween_property(s, "modulate:a", 1.0, 0.3)
			rise.parallel().tween_property(s, "position:y", home.y, 1.0) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			# Schlammtropfen perlen vom aufsteigenden Körper ab
			for k in 8:
				var drip := Sprite2D.new()
				drip.texture = SpriteFactory.circle(3, Color(0.45, 0.8, 0.2))
				drip.position = home + Vector2(randf_range(-70, 70), randf_range(-60, 40))
				add_child(drip)
				var dt := create_tween()
				dt.tween_interval(randf_range(0.3, 0.9))
				dt.tween_property(drip, "position:y", drip.position.y + randf_range(60, 130), 0.4) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				dt.parallel().tween_property(drip, "modulate:a", 0.0, 0.4)
				dt.tween_callback(drip.queue_free)
			await rise.finished
			_burst(home + Vector2(0, 70), Color(0.55, 1.0, 0.3), 14, 120)
			_shake_camera(1.6)
			var pf := create_tween()
			pf.tween_interval(0.8)
			pf.tween_property(pool, "modulate:a", 0.0, 0.8)
			pf.tween_callback(pool.queue_free)
	await get_tree().create_timer(0.3).timeout
