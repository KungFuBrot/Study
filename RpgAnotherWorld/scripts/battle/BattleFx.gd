class_name BattleFx
extends BattleBase
## Wiederverwendbare Kampf-Effekte: Partikel, Beben, Hit-Stop, Schadenszahlen,
## Kamera (Idle/Zoom), Licht, Banner, Projektile, Bewegung (_sprint).
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

## Kleiner Staubstoß an den Füßen — verkauft Abstoß und Landung.
func _step_dust(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 6
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = Color(0.75, 0.72, 0.68, 0.5)
	p.texture = SpriteFactory.circle(2, Color.WHITE)
	p.emitting = true
	add_child(p)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(p.queue_free)

## Kurzer Sprint mit Lauf-Frames (DTII-run bzw. Rax-Schwebe-Dash) + Geistertrail.
## Der agierende Held zeichnet über seinen Nachbarn (z_index 2) — sonst
## verdeckt z. B. Rax den vortretenden Zauberer; zu Hause gilt wieder die
## Aufstellungsreihenfolge.
func _sprint(h: Dictionary, to: Vector2, dur: float) -> void:
	var s: Sprite2D = h["sprite"]
	s.z_index = 2
	h["anim"] = "run"
	var foot_y := s.texture.get_height() * s.scale.y * 0.5 - 4.0
	_step_dust(s.position + Vector2(0, foot_y))
	var frames := create_tween().set_loops()
	frames.tween_interval(0.06)
	frames.tween_callback(func():
		h["frame"] = (h["frame"] + 1) \
			% SpriteFactory.hero_anim_frames(h["data"]["id"], "run")
		s.texture = SpriteFactory.hero_battle_frame(h["data"]["id"], h["frame"], "run"))
	_ghost_trail(s, dur)
	# In Laufrichtung lehnen, am Ziel aufrichten und abfedern.
	var lean := create_tween()
	lean.tween_property(s, "rotation", -0.09 if to.x < s.position.x else 0.09,
		minf(0.12, dur * 0.5)).set_trans(Tween.TRANS_SINE)
	var tw := create_tween()
	tw.tween_property(s, "position", to, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	frames.kill()
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var settle := create_tween()
	settle.tween_property(s, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	settle.parallel().tween_property(s, "scale", base * Vector2(1.05, 0.94), 0.07)
	settle.tween_property(s, "scale", base, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_step_dust(to + Vector2(0, foot_y))
	h["anim"] = "idle"
	s.texture = SpriteFactory.hero_battle_frame(h["data"]["id"], h["frame"], "idle")
	if to.is_equal_approx(h["home"]):
		s.z_index = 0

## Spielt eine gebackene AW-Rig-Animation über dur Sekunden einmal ab, danach
## kehrt die Figur zu ihren Idle-Frames zurück. Nebenläufig nutzbar (nicht
## awaiten) — bricht ab, sobald eine andere Aktion h["anim"] übernimmt.
func _play_aw_anim(h: Dictionary, anim: String, dur: float) -> void:
	var id: String = h["data"]["id"]
	if not SpriteFactory.aw_hero_has_anim(id, anim):
		return
	var s: Sprite2D = h["sprite"]
	h["anim"] = anim
	var n := SpriteFactory.hero_anim_frames(id, anim)
	for f in n:
		if h["anim"] != anim or not is_instance_valid(s):
			return
		s.texture = SpriteFactory.hero_battle_frame(id, f, anim)
		await get_tree().create_timer(dur / n).timeout
	if h["anim"] == anim:
		h["anim"] = "idle"
		s.texture = SpriteFactory.hero_battle_frame(id, h["frame"], "idle")

## Kurzer Mündungsblitz am Lauf (additives Kenney-Blitz-Sprite, dreht in
## Schussrichtung, blitzt einmal auf und verschwindet).
func _muzzle_flash(pos: Vector2, angle: float) -> void:
	var flash := Sprite2D.new()
	flash.texture = SpriteFactory.particle("muzzle_02")
	flash.position = pos
	flash.rotation = angle - PI / 2
	flash.scale = Vector2(0.28, 0.28)
	flash.modulate = Color(1.0, 0.9, 0.5)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = m
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2(0.42, 0.42), 0.04)
	tw.tween_property(flash, "modulate:a", 0.0, 0.06)
	tw.tween_callback(flash.queue_free)

## Fliegendes MG-Geschoss: eine kleine Leuchtspur-Kugel saust vom Lauf zum Ziel,
## zieht einen kurzen Glühschweif hinter sich her und zerplatzt beim Einschlag in
## Funken. Sehr schnell, damit das Dauerfeuer flüssig bleibt.
func _fire_bullet(from: Vector2, to: Vector2) -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var b := Sprite2D.new()
	b.texture = SpriteFactory.bullet()
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.position = from
	b.rotation = (to - from).angle()
	b.scale = Vector2(2.4, 2.4)
	b.material = m
	# Kurzer Glühschweif direkt hinter der Kugel.
	var trail := Sprite2D.new()
	trail.texture = SpriteFactory.circle(3, Color(1.0, 0.8, 0.4))
	trail.position = Vector2(-7, 0)
	trail.scale = Vector2(2.6, 0.7)
	trail.material = m
	b.add_child(trail)
	add_child(b)
	var dur: float = maxf(from.distance_to(to) / 4200.0, 0.045)
	var tw := b.create_tween()
	tw.tween_property(b, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_burst(to, Color(1.0, 0.85, 0.4), 4, 90)
		b.queue_free())

## Screen-Stoßwelle: Verzerrungs-Ring mit chromatischer Aberration läuft vom
## Weltpunkt nach außen. Max. eine gleichzeitig (Vollbild-Shader).
func _shockwave(pos: Vector2) -> void:
	if shock_live:
		return
	shock_live = true
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := Fx.shockwave_material()
	mat.set_shader_parameter("center", pos / Vector2(960, 540))
	rect.material = mat
	ui_layer.add_child(rect)
	# Vor Panel/Text einsortieren (Kinder 0-2 sind Blur/Grade/Vignette),
	# damit die UI nicht mitwabert.
	ui_layer.move_child(rect, 3)
	var tw := create_tween()
	tw.tween_method(func(r: float): mat.set_shader_parameter("radius", r), 0.0, 0.9, 0.5)
	tw.tween_callback(func():
		shock_live = false
		rect.queue_free())

## Kurzlebiges Zauberlicht am Effektort: klingt über dur ab und räumt sich weg.
func _spell_light(pos: Vector2, color: Color, radius: float, dur: float, energy := 1.2) -> void:
	if live_lights >= 8:
		return
	live_lights += 1
	var l := Fx.point_light(color, radius, energy)
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, dur)
	tw.tween_callback(func():
		live_lights -= 1
		l.queue_free())

## Kurze Wirk-Pose: zurücklehnen + strecken, während der Zauberkreis aufleuchtet.
func _anim_cast(s: Sprite2D) -> void:
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var tw := create_tween()
	tw.tween_property(s, "rotation", 0.12, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "scale", base * Vector2(0.95, 1.08), 0.18)
	tw.tween_property(s, "rotation", 0.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(s, "scale", base, 0.25)

## Kritischer Treffer: großer Schriftzug, extra Funken, stärkeres Beben.
func _crit_fx(pos: Vector2) -> void:
	_float_text(pos + Vector2(-30, -46), "CRITICAL!", Color(1.0, 0.62, 0.1), 36)
	_burst(pos, Color(1.0, 0.75, 0.2), 16, 200)
	_shake_camera(1.9)
	_punch_zoom(0.07, pos)

## Angriffsposition: vor dem Gegner stehen, beim breiten Boss weiter außen.
func _strike_offset(e: Dictionary) -> float:
	var es: Sprite2D = e["sprite"]
	return es.texture.get_width() * es.scale.x * 0.5 + 30.0

## Beschwörungs-Gemurmel: ein kleiner Mund-Overlay öffnet und schließt sich
## im Sprechrhythmus auf dem Gesicht des Zauberers (DTII-Sprite hat keine
## eigenen Gesichts-Frames). Räumt sich nach dur Sekunden selbst weg.
func _chant(s: Sprite2D, dur: float) -> void:
	var mouth := Sprite2D.new()
	mouth.texture = SpriteFactory.circle(2, Color(0.30, 0.10, 0.10))
	mouth.position = Vector2(-3.0, -3.2)
	mouth.scale = Vector2(0.6, 0.4)
	mouth.z_index = 1
	s.add_child(mouth)
	var tw := mouth.create_tween().set_loops()
	tw.tween_property(mouth, "scale", Vector2(0.5, 0.85), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mouth, "scale", Vector2(0.65, 0.3), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mouth, "scale", Vector2(0.55, 0.65), 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(mouth):
			mouth.queue_free())

## Nachbilder der Waffe während eines schnellen Schwungs/Stoßes.
func _weapon_trail(wp: Sprite2D, dur: float) -> void:
	var steps := maxi(int(dur / 0.03), 2)
	for i in steps:
		await get_tree().create_timer(0.03).timeout
		if not is_instance_valid(wp):
			return
		var g := Sprite2D.new()
		g.texture = wp.texture
		g.offset = wp.offset
		g.modulate = Color(0.8, 0.9, 1.0, 0.5)
		g.z_index = 1
		add_child(g)
		g.global_transform = wp.global_transform
		var gt := g.create_tween()
		gt.tween_property(g, "modulate:a", 0.0, 0.15)
		gt.tween_callback(g.queue_free)

## Kreuzschnitt: zwei gegenläufige Lichtklingen reißen über dem Ziel auf.
func _cross_slash(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ang in [-0.6, 0.65]:
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(-78, -4), Vector2(0, -7), Vector2(78, -4),
			Vector2(78, 4), Vector2(0, 7), Vector2(-78, 4)])
		blade.color = Color(1, 1, 1, 0.95)
		blade.material = mat
		blade.position = pos
		blade.rotation = ang
		blade.scale = Vector2(0.15, 1.0)
		add_child(blade)
		var bt := create_tween()
		bt.tween_property(blade, "scale", Vector2(1.25, 1.0), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bt.tween_property(blade, "modulate:a", 0.0, 0.22)
		bt.tween_callback(blade.queue_free)
	_flash_screen(Color(1, 1, 1, 0.30))
	_burst(pos, Color(1.0, 0.98, 0.85), 14, 190)
	_spell_light(pos, Color(1.0, 0.95, 0.7), 200.0, 0.4)

## Violette Sternenfunken, die beim Klingentanz aufblitzen.
func _star_sparks(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var p := Sprite2D.new()
	p.texture = SpriteFactory.particle("star_07")
	p.position = pos + Vector2(randf_range(-20, 20), randf_range(-24, 8))
	p.scale = Vector2(0.10, 0.10)
	p.modulate = Color(0.85, 0.70, 1.0, 0.9)
	p.material = mat
	p.z_index = 6
	add_child(p)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(0.3, 0.3), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "rotation", 1.5, 0.28)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.28)
	tw.tween_callback(p.queue_free)


## Weltposition der Mündung (die Kanone sitzt nach flip_h bildlinks/vorn).
func _cannon_muzzle(s: Sprite2D) -> Vector2:
	return s.position + Vector2(-52, -6)

## Leuchtender Energiestrahl von A nach B (additiv, kurzer Auf-/Abblendimpuls).
func _beam(from: Vector2, to: Vector2, color: Color, width: float, hold: float) -> void:
	var seg := Node2D.new()
	seg.position = from
	seg.rotation = (to - from).angle()
	add_child(seg)
	var length := from.distance_to(to)
	var pts := PackedVector2Array([Vector2(0, -0.5), Vector2(length, -0.5),
		Vector2(length, 0.5), Vector2(0, 0.5)])
	var glow := Polygon2D.new()
	glow.polygon = pts
	glow.color = Fx.hot(color)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	seg.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = pts
	core.color = Fx.hot(Color(1, 1, 1, 0.95), 1.4)
	core.scale = Vector2(1, 0.4)
	seg.add_child(core)
	seg.scale = Vector2(1, 0.1)
	_spell_light((from + to) * 0.5, color, 220.0, 0.4)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale", Vector2(1, width), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(seg, "modulate:a", 0.0, 0.2)
	tw.tween_callback(seg.queue_free)

## Zielmarker, der über einem Gegner zusammenzieht (Orbital-Anvisierung).
## Zielumgrenzung des GEGNER-Feldes (Bounding-Box aller lebenden Gegner + Rand),
## nie auf die Heldenseite hinausragend. Von Meteorregen und Orbitallaser genutzt.
func _enemy_field_rect(alive: Array) -> Dictionary:
	if alive.is_empty():
		return {"x0": 150.0, "x1": 380.0, "y0": 170.0, "y1": 360.0,
			"cx": 265.0, "cy": 265.0, "ax": 115.0, "ay": 95.0}
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for e in alive:
		var p: Vector2 = e["sprite"].position
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	x0 -= 55.0
	x1 = minf(x1 + 55.0, 470.0)  # Sicherheitsgrenze: nie auf die Heldenseite
	y0 -= 40.0
	y1 += 48.0
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1,
		"cx": (x0 + x1) * 0.5, "cy": (y0 + y1) * 0.5,
		"ax": (x1 - x0) * 0.5, "ay": (y1 - y0) * 0.5}

## Dunkelt den Schauplatz ab (hinter den Kämpfern) für Ultimate-Inszenierungen.
func _dim_world(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.size = Vector2(960, 540)
	rect.z_index = -4
	add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", alpha, 0.3)
	return rect

func _undim(rect: ColorRect) -> void:
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.4)
	tw.tween_callback(rect.queue_free)

## Aufploppender Namenszug einer Ultimate-Attacke.
func _ult_banner(text: String, color: Color) -> void:
	var banner := Label.new()
	banner.text = text
	banner.add_theme_font_size_override("font_size", 42)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.10))
	banner.add_theme_constant_override("outline_size", 10)
	banner.custom_minimum_size = Vector2(960, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 120)
	banner.pivot_offset = Vector2(480, 26)
	banner.scale = Vector2(2.2, 2.2)
	banner.modulate.a = 0.0
	ui_layer.add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)
	tw.tween_callback(banner.queue_free)

## Kleineres Namensbanner für Spezialattacken (Monster-Spezials, Boss-AoE):
## ploppt mittig auf und verschwindet schnell wieder — die kleine Schwester
## des Ult-Banners.
func _attack_banner(text: String, color: Color) -> void:
	var banner := Label.new()
	banner.text = text
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.10))
	banner.add_theme_constant_override("outline_size", 8)
	banner.custom_minimum_size = Vector2(960, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 96)
	banner.pivot_offset = Vector2(480, 18)
	banner.scale = Vector2(1.8, 1.8)
	banner.modulate.a = 0.0
	ui_layer.add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.75)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(banner.queue_free)

## Kurzer weißer Glanzblitz an der Waffe (Anticipation vor dem Schlag).
func _weapon_glint(wp: Sprite2D) -> void:
	if wp == null or not is_instance_valid(wp):
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var g := Sprite2D.new()
	g.texture = SpriteFactory.particle("star_07")
	g.modulate = Color(1.0, 1.0, 0.92, 0.0)
	g.material = mat
	g.scale = Vector2(0.06, 0.06)
	g.position = Vector2(0, -26)  # nahe der Klingenspitze
	g.z_index = 2
	wp.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(g, "scale", Vector2(0.22, 0.22), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "rotation", 1.2, 0.2)
	tw.tween_property(g, "modulate:a", 0.0, 0.1)
	tw.tween_callback(g.queue_free)

## Träge Idle-Kamera: minimales Atmen in Zoom und Position, wirkt „gefilmt".
func _camera_idle() -> void:
	if cam_idle != null:
		cam_idle.kill()
	cam_idle = create_tween().set_loops()
	cam_idle.tween_property(cam, "zoom", Vector2(1.015, 1.015), 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_idle.parallel().tween_property(cam, "position", Vector2(484, 268), 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_idle.tween_property(cam, "zoom", Vector2.ONE, 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_idle.parallel().tween_property(cam, "position", Vector2(480, 270), 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Kurzer Kamera-Stoß auf einen Fokuspunkt — Zoom-Punch für große Momente.
## (Nutzt zoom/position; _shake_camera rüttelt am offset — kein Konflikt.)
func _punch_zoom(strength: float, focus: Vector2) -> void:
	if cam_idle != null:
		cam_idle.kill()
		cam_idle = null
	var base_pos := Vector2(480, 270)
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2.ONE * (1.0 + strength), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "position", base_pos + (focus - base_pos) * 0.2, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(cam, "zoom", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "position", base_pos, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_camera_idle)

## Aufblitzender Schallring (Hasstirade).
func _shockring(pos: Vector2, delay: float) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Sprite2D.new()
	ring.texture = SpriteFactory.particle("circle_05")
	ring.position = pos
	ring.scale = Vector2(0.1, 0.07)
	ring.modulate = Color(1.0, 0.35, 0.25, 0.0)
	ring.material = mat
	ring.z_index = 6
	add_child(ring)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(ring, "modulate:a", 0.9, 0.05)
	tw.tween_property(ring, "scale", Vector2(2.4, 1.6), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)

func _shake(s: Sprite2D, recoil := 0.0) -> void:
	var orig: Vector2 = s.position
	var tw := create_tween()
	if recoil != 0.0:
		# Gerichteter Rückstoß: der Treffer schleudert die Figur in Trefferrichtung
		# (Held nach rechts, Gegner nach links), dann federt sie gedämpft zurück.
		tw.tween_property(s, "position:x", orig.x + recoil * 17.0, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "position:x", orig.x - recoil * 5.0, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(s, "position:x", orig.x, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		for i in 4:
			tw.tween_property(s, "position:x", orig.x + (8 if i % 2 == 0 else -8), 0.04)
		tw.tween_property(s, "position:x", orig.x, 0.04)
	var flash := create_tween()
	flash.tween_property(s, "modulate", Fx.hot(Color(1.0, 0.45, 0.4), 1.6), 0.08)
	# Zurück zur Grundtönung (Themen-Tint bzw. Wutfärbung), nicht stur zu Weiß.
	flash.tween_property(s, "modulate", s.get_meta("tint", Color.WHITE), 0.15)
	# Quetsch-Impuls + Rotations-Wobble verkaufen die Wucht des Treffers.
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var squash := create_tween()
	squash.tween_property(s, "scale", base * Vector2(1.12, 0.88), 0.06)
	squash.tween_property(s, "scale", base, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wob := create_tween()
	wob.tween_property(s, "rotation", 0.09, 0.05)
	wob.tween_property(s, "rotation", -0.06, 0.07)
	wob.tween_property(s, "rotation", 0.0, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake_camera(strength := 1.0) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(cam, "offset",
			Vector2(randf_range(-7, 7), randf_range(-5, 5)) * strength, 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

## Kurze Zeitlupe beim Aufprall — lässt Treffer wuchtig wirken.
func _hitstop(dur: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

## Verblassende Nachbilder während eines Sturmangriffs.
func _ghost_trail(s: Sprite2D, dur: float) -> void:
	for i in 3:
		await get_tree().create_timer(dur / 3.5).timeout
		var g := Sprite2D.new()
		g.texture = s.texture
		g.flip_h = s.flip_h
		g.scale = s.scale
		g.position = s.position
		g.modulate = Color(0.6, 0.75, 1.0, 0.45)
		add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.28)
		tw.tween_callback(g.queue_free)

func _float_text(pos: Vector2, text: String, color: Color, size := 30) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-14, -70)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.scale = Vector2(0.2, 0.2)
	l.pivot_offset = Vector2(20, 20)
	add_child(l)
	# Überschwingender Pop, dann leicht bogenförmig davonschweben.
	var drift := randf_range(-24.0, 24.0)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:x", l.position.x + drift, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.55)
	tw.tween_callback(l.queue_free)

func _slash_arc(pos: Vector2) -> void:
	var arc := Polygon2D.new()
	arc.polygon = PackedVector2Array([Vector2(-30, -34), Vector2(6, -6), Vector2(-26, 30), Vector2(-12, -4)])
	arc.color = Color(1, 1, 1, 0.9)
	arc.position = pos
	add_child(arc)
	var tw := create_tween()
	tw.tween_property(arc, "rotation", 0.9, 0.18)
	tw.parallel().tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.tween_callback(arc.queue_free)

## Explosion aus echten Partikeltexturen (Kenney CC0): Lichtblitz,
## rollender Feuerball, aufquellender Rauch, Trümmer und Brandfleck.
## `power` skaliert die Wucht (>1 für große Feuerzauber → Stoßwelle, Glutregen).
func _explosion(pos: Vector2, power := 1.0) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Greller Kernblitz
	var flash := Sprite2D.new()
	flash.texture = SpriteFactory.particle("flare_01")
	flash.modulate = Fx.hot(Color(1.0, 0.95, 0.8))
	flash.position = pos
	flash.scale = Vector2(0.25, 0.25)
	flash.material = mat
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "scale", Vector2(1.5, 1.5) * power, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.parallel().tween_property(flash, "modulate:a", 0.0, 0.24 + 0.1 * (power - 1.0))
	ft.tween_callback(flash.queue_free)
	# Rollender Feuerball: zwei rotierende Feuer-Sprites, die aufblähen
	for i in 2:
		var fire := Sprite2D.new()
		fire.texture = SpriteFactory.particle("fire_01")
		fire.position = pos + Vector2(randf_range(-8, 8), randf_range(-6, 4))
		fire.rotation = randf_range(0.0, TAU)
		fire.scale = Vector2.ONE * 0.12
		fire.material = mat
		fire.modulate = Color(1.0, 0.75, 0.35) if i == 0 else Color(1.0, 0.5, 0.2)
		add_child(fire)
		var ff := create_tween()
		ff.tween_property(fire, "scale", Vector2.ONE * (0.55 + 0.25 * i) * power, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ff.parallel().tween_property(fire, "rotation", fire.rotation + randf_range(-1.4, 1.4), 0.45)
		ff.parallel().tween_property(fire, "position:y", fire.position.y - 22.0 - 10.0 * i, 0.45)
		ff.parallel().tween_property(fire, "modulate:a", 0.0, 0.42 + 0.08 * i)
		ff.tween_callback(fire.queue_free)
	# Aufquellender Rauch (normal geblendet, steigt und verweht)
	var smoke := CPUParticles2D.new()
	smoke.position = pos + Vector2(0, -6)
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.amount = int(6 * power)
	smoke.lifetime = 1.1
	smoke.direction = Vector2(0, -1)
	smoke.spread = 40.0
	smoke.gravity = Vector2(0, -50)
	smoke.initial_velocity_min = 24.0
	smoke.initial_velocity_max = 60.0 * power
	smoke.scale_amount_min = 0.12
	smoke.scale_amount_max = 0.30 * power
	smoke.color = Color(0.42, 0.40, 0.40, 0.5)
	smoke.texture = SpriteFactory.particle("smoke_04")
	smoke.emitting = true
	add_child(smoke)
	get_tree().create_timer(2.0).timeout.connect(smoke.queue_free)
	# Trümmer, die im Bogen wegfliegen
	var debris := CPUParticles2D.new()
	debris.position = pos
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = int(7 * power)
	debris.lifetime = 0.6
	debris.direction = Vector2(0, -1)
	debris.spread = 65.0
	debris.gravity = Vector2(0, 500)
	debris.initial_velocity_min = 90.0
	debris.initial_velocity_max = 190.0 * power
	debris.scale_amount_min = 0.04
	debris.scale_amount_max = 0.10
	debris.color = Color(0.5, 0.42, 0.36)
	debris.texture = SpriteFactory.particle("dirt_02")
	debris.emitting = true
	add_child(debris)
	get_tree().create_timer(1.2).timeout.connect(debris.queue_free)
	# Brandfleck am Boden, der langsam verblasst
	var scorch := Sprite2D.new()
	scorch.texture = SpriteFactory.particle("scorch_01")
	scorch.position = pos + Vector2(0, 26)
	scorch.scale = Vector2(0.6, 0.28) * power
	scorch.modulate = Color(0.1, 0.08, 0.08, 0.55)
	scorch.rotation = randf_range(-0.2, 0.2)
	scorch.z_index = -9
	add_child(scorch)
	var sct := scorch.create_tween()
	sct.tween_interval(1.6)
	sct.tween_property(scorch, "modulate:a", 0.0, 2.2)
	sct.tween_callback(scorch.queue_free)
	_burst(pos, Color(1.0, 0.55, 0.12), int(12 * power), 160 * power)
	_impact_ring(pos, Color(1.0, 0.7, 0.3, 0.8))
	_spell_light(pos, Color(1.0, 0.6, 0.25), 180.0 * power, 0.45)
	# Bei großen Explosionen eine zweite, verzögerte Stoßwelle + Glutregen.
	if power > 1.3:
		_shockwave(pos)
		_impact_ring(pos, Color(1.0, 0.85, 0.5, 0.6))
		var embers := CPUParticles2D.new()
		embers.position = pos
		embers.one_shot = true
		embers.explosiveness = 0.85
		embers.amount = int(18 * power)
		embers.lifetime = 0.8
		embers.direction = Vector2(0, -1)
		embers.spread = 70.0
		embers.gravity = Vector2(0, 320)
		embers.initial_velocity_min = 80.0 * power
		embers.initial_velocity_max = 200.0 * power
		embers.scale_amount_min = 0.5
		embers.scale_amount_max = 1.6
		embers.color = Color(1.0, 0.6, 0.2)
		embers.texture = SpriteFactory.circle(3, Color.WHITE)
		embers.emitting = true
		add_child(embers)
		var et := embers.create_tween()
		et.tween_interval(1.4)
		et.tween_callback(embers.queue_free)

## Einmaliger Partikel-Ausbruch (CPUParticles2D, räumt sich selbst auf).
func _burst(pos: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color = Fx.hot(color)
	p.texture = SpriteFactory.circle(3, Color.WHITE)
	p.emitting = true
	add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)

## Rotierender Zauberkreis unter dem Wirker: kreisende Lichter + Glühen.
func _cast_circle(pos: Vector2, color: Color) -> void:
	var pivot := Node2D.new()
	pivot.position = pos
	pivot.scale = Vector2(1, 0.33)  # flach gedrückt → Bodenkreis in Pseudo-3D
	add_child(pivot)
	# Flaches Glühen bleibt unrotiert, nur die Lichter kreisen.
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(24, Color(color.r, color.g, color.b, 0.35))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.position = pos
	glow.scale = Vector2(2.2, 0.7)
	glow.modulate = Fx.hot(Color.WHITE, 1.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	var gt := glow.create_tween()
	gt.tween_property(glow, "modulate:a", 0.0, 0.8)
	gt.tween_callback(glow.queue_free)
	for i in 8:
		var orb := Sprite2D.new()
		orb.texture = SpriteFactory.circle(4, color)
		orb.modulate = Fx.hot(Color.WHITE)
		var ang := TAU * i / 8.0
		orb.position = Vector2(cos(ang) * 46, sin(ang) * 46)
		pivot.add_child(orb)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation", TAU * 1.5, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "modulate:a", 0.0, 0.8)
	tw.tween_callback(pivot.queue_free)

## Expandierender Stoßwellen-Ring am Aufprallpunkt.
func _impact_ring(pos: Vector2, color: Color) -> void:
	var ring := Sprite2D.new()
	ring.texture = SpriteFactory.circle(24, color)
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ring.modulate = Fx.hot(Color.WHITE)
	ring.position = pos
	ring.scale = Vector2(0.2, 0.2)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)

## Kurzer Vollbild-Blitz (z. B. beim Knochensturm des Bosses).
func _flash_screen(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.45)
	tw.tween_callback(rect.queue_free)

func _sparkle(pos: Vector2, color: Color) -> void:
	for i in 8:
		var p := Sprite2D.new()
		p.texture = SpriteFactory.circle(4, color)
		p.position = pos + Vector2(randf_range(-30, 30), randf_range(10, 40))
		add_child(p)
		var tw := create_tween()
		tw.tween_property(p, "position:y", p.position.y - 50.0, 0.6)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
		tw.tween_callback(p.queue_free)
