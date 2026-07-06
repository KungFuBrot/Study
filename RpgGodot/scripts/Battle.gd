class_name Battle
extends Node2D
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Moderner Look: Partikel-Effekte, Hit-Stop, Geister-Trails, Kamerabeben,
## HP-Leisten, animierter Höhlenhintergrund mit Fackeln und Nebel sowie
## ein inszenierter Boss-Kampf (Kino-Balken, Wut-Phase, dramatischer Tod).

signal finished(victory: bool)
signal _choice_made

const BAR_W := 170

# Kampf-Aufstellung (Zickzack in der Tiefe): Serena vordere Reihe oben,
# Milo hintere Reihe Mitte (weiter rechts + kleiner → Tiefe), Rax vordere
# Reihe unten. pos = Mittelpunkt.
const BATTLE_FORMATION := {
	"serena": {"pos": Vector2(692, 178), "scale": 4.9},
	"milo": {"pos": Vector2(808, 242), "scale": 4.1},
	"rax": {"pos": Vector2(702, 300), "scale": 4.6},
}

var enemy_ids: Array = []
var arena_theme := "cave"  # "cave" | "frost" — von Main anhand der Karte gesetzt
var boss_def := {}         # ENEMIES-Definition des Bosses in diesem Kampf (falls vorhanden)
var heroes := []   # {data, sprite, home, hp_label, hp_fill, mp_fill}
var enemies := []  # {name, hp, max_hp, atk, def, gold, sprite, home, alive, ...}

var ui_state := "none"  # none | menu | target | item | ally
var menu_index := 0
var choice := -1
var menu_labels: Array = []
var current_menu: Array = []

var msg_label: Label
var menu_box: VBoxContainer
var party_box: VBoxContainer
var cursor: Polygon2D
var cam: Camera2D
var ui_layer: CanvasLayer
var boss_bar_fill: ColorRect
var boss_bar_holder: Control

func _ready() -> void:
	for id in enemy_ids:
		if GameState.ENEMIES[id].get("boss", false):
			boss_def = GameState.ENEMIES[id]
	_build_scene()
	_build_ui()
	if OS.get_environment("SPELLSHOT") != "":
		_spell_showcase()
	else:
		_run_battle()

## Debug: löst jeden Zauber-/Spezialeffekt aus und macht Screenshots am Höhepunkt
## (env SPELLSHOT=Zielordner). Nur zum visuellen Prüfen, kein Spielinhalt.
func _spell_showcase() -> void:
	var dir := OS.get_environment("SPELLSHOT")
	for u in heroes + enemies:
		(u["sprite"] as Sprite2D).position = u["home"]
		(u["sprite"] as Sprite2D).modulate.a = 1.0
	for e in enemies:
		e["hp"] = 99999  # unsterblich, damit alle Effekte auf volle Ziele treffen
	for i in heroes.size():
		heroes[i]["bob"] = _idle_bob(heroes[i]["sprite"], 2.0)
	for e in enemies:
		_idle_bob(e["sprite"], 1.6)
	_start_idle_animations()
	for h in heroes:
		h["data"]["mp"] = 60
	await get_tree().create_timer(1.0).timeout
	_snap(dir, "show_idle")
	_highlight_hero(heroes[2], true)
	await get_tree().create_timer(0.6).timeout
	_snap(dir, "show_turnarrow")
	_highlight_hero(heroes[2], false)
	# Milo Feuerball (Explosion einfangen)
	_fireball(heroes[1], heroes[1]["data"]["abilities"][0], enemies[0])
	await get_tree().create_timer(1.05).timeout
	_snap(dir, "show_fireball")
	await get_tree().create_timer(1.4).timeout
	# Rax Laser
	_laser(heroes[2], heroes[2]["data"]["abilities"][0], enemies[1])
	await get_tree().create_timer(0.55).timeout
	_snap(dir, "show_laser")
	await get_tree().create_timer(1.2).timeout
	# Rax Raketensalve
	_rocket_all(heroes[2], heroes[2]["data"]["abilities"][1])
	await get_tree().create_timer(0.95).timeout
	_snap(dir, "show_rockets")
	await get_tree().create_timer(1.6).timeout
	# Rax Ultimate
	_ultimate_rax(heroes[2])
	await get_tree().create_timer(1.95).timeout
	_snap(dir, "show_ultimate")
	await get_tree().create_timer(1.8).timeout
	get_tree().quit()

func _snap(dir: String, shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + shot_name + ".png")

## Farbstimmung des Schauplatzes (dunkle Höhle vs. Frostgrotte).
func _palette() -> Dictionary:
	if arena_theme == "frost":
		return {
			"bg_top": Color(0.08, 0.15, 0.26), "bg_bottom": Color(0.02, 0.05, 0.11),
			"floor_top": Color(0.20, 0.28, 0.40), "floor_bottom": Color(0.08, 0.12, 0.20),
			"stone": Color(0.34, 0.44, 0.58), "stal": Color(0.14, 0.22, 0.36, 0.9),
			"flame": Color(0.35, 0.80, 1.0), "glow": Color(0.25, 0.70, 1.0, 0.35),
			"fog": Color(0.70, 0.85, 1.0, 0.09), "hit": Color(0.55, 0.85, 1.0),
			"ray": Color(0.60, 0.85, 1.0, 0.05), "dust": Color(0.75, 0.92, 1.0, 0.55),
			"grade_top": Color(0.65, 0.85, 1.0, 0.08), "grade_bottom": Color(0.03, 0.10, 0.35, 0.20),
			"pool_hero": Color(0.65, 0.90, 1.0, 0.11), "pool_enemy": Color(0.45, 0.80, 1.0, 0.11),
			"fg": Color(0.02, 0.04, 0.09),
		}
	var boss_fight := not boss_def.is_empty()
	return {
		"bg_top": Color(0.16, 0.07, 0.12) if boss_fight else Color(0.13, 0.11, 0.22),
		"bg_bottom": Color(0.05, 0.03, 0.07),
		"floor_top": Color(0.22, 0.18, 0.27), "floor_bottom": Color(0.10, 0.08, 0.14),
		"stone": Color(0.28, 0.24, 0.34), "stal": Color(0.09, 0.06, 0.13, 0.85),
		"flame": Color(1.0, 0.60, 0.15), "glow": Color(1.0, 0.55, 0.15, 0.35),
		"fog": Color(0.55, 0.50, 0.75, 0.07), "hit": Color(1.0, 0.4, 0.3),
		"ray": Color(1.0, 0.80, 0.50, 0.05), "dust": Color(1.0, 0.85, 0.55, 0.50),
		"grade_top": Color(0.95, 0.65, 0.35, 0.07), "grade_bottom": Color(0.08, 0.10, 0.35, 0.17),
		"pool_hero": Color(1.0, 0.85, 0.55, 0.12), "pool_enemy": Color(0.70, 0.50, 1.0, 0.10),
		"fg": Color(0.03, 0.02, 0.06),
	}

## ---------- Aufbau ----------

func _build_scene() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(480, 270)
	add_child(cam)
	cam.make_current()
	var pal := _palette()
	# Hintergrund: weicher Farbverlauf passend zum Schauplatz.
	var bg := Sprite2D.new()
	bg.texture = SpriteFactory.gradient(8, 64, pal["bg_top"], pal["bg_bottom"])
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.centered = false
	bg.scale = Vector2(960.0 / 8, 540.0 / 64)
	bg.z_index = -20
	add_child(bg)
	# Stalagmiten-Silhouetten im Hintergrund
	for i in 7:
		var stal := Polygon2D.new()
		var w := 40.0 + fmod(i * 37.0, 50.0)
		var h := 120.0 + fmod(i * 73.0, 140.0)
		stal.polygon = PackedVector2Array([Vector2(-w / 2, 0), Vector2(0, -h), Vector2(w / 2, 0)])
		stal.color = pal["stal"]
		stal.position = Vector2(30 + i * 150.0, 360)
		stal.z_index = -15
		add_child(stal)
	# Boden mit Verlauf + Steine als Dekor
	var floor_s := Sprite2D.new()
	floor_s.texture = SpriteFactory.gradient(8, 32, pal["floor_top"], pal["floor_bottom"])
	floor_s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor_s.centered = false
	floor_s.position = Vector2(0, 340)
	floor_s.scale = Vector2(960.0 / 8, 200.0 / 32)
	floor_s.z_index = -12
	add_child(floor_s)
	for i in 24:
		var stone := Sprite2D.new()
		stone.texture = SpriteFactory.circle(3 + (i % 4), pal["stone"])
		stone.position = Vector2(40 + i * 39.0, 350 + fmod(i * 61.3, 160.0))
		stone.z_index = -11
		add_child(stone)
	_add_torch(Vector2(70, 160), pal)
	_add_torch(Vector2(890, 160), pal)
	_add_god_rays(pal)
	_add_fog(pal)
	_add_dust_motes(pal)
	_add_foreground_blur(pal)
	if arena_theme == "frost":
		_add_snow()

	# Alle Kämpfer starten außerhalb des Bildes und marschieren in _run_battle ein.
	for i in GameState.party.size():
		var data: Dictionary = GameState.party[i]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.hero_battle(data["id"])
		var form: Dictionary = BATTLE_FORMATION.get(data["id"],
			{"pos": Vector2(700 + (i % 2) * 60, 170 + i * 78), "scale": 4.0})
		var hscale: float = form["scale"]
		s.scale = Vector2(hscale, hscale)
		s.flip_h = true  # DTII-Figuren blicken nach rechts → zum Gegner (links) drehen
		var home: Vector2 = form["pos"]
		s.position = home + Vector2(340, 0)
		var foot_h: float = s.texture.get_height() * 0.5 - 1.0
		_attach_shadow(s, 9, 3, foot_h)
		_attach_glow_pool(s, foot_h, pal["pool_hero"])
		_attach_reflection(s, foot_h, 0.09)
		_attach_weapon(s, data["id"])
		add_child(s)
		heroes.append({"data": data, "sprite": s, "home": home, "ult_used": false, "frame": 0})

	for i in enemy_ids.size():
		var def: Dictionary = GameState.ENEMIES[enemy_ids[i]]
		var is_boss: bool = def.get("boss", false)
		var s := Sprite2D.new()
		s.texture = SpriteFactory.enemy(def["sprite"])
		s.scale = Vector2(6, 6) if is_boss else Vector2(6.5, 6.5)
		var home := Vector2(215, 232) if is_boss else Vector2(225 + (i % 2) * 100, 180 + i * 88)
		s.position = home - Vector2(500, 0)
		var refl: Sprite2D
		if is_boss:
			var foot: float = s.texture.get_height() * 0.5 + 0.5
			_attach_shadow(s, 13, 3, foot)
			_attach_glow_pool(s, foot, pal["pool_enemy"])
			refl = _attach_reflection(s, foot, 0.10)
			_attach_boss_aura(s, def.get("theme", "bone"))
		else:
			var foot_e: float = s.texture.get_height() * 0.5 - 1.0
			_attach_shadow(s, 9, 3, foot_e)
			_attach_glow_pool(s, foot_e, pal["pool_enemy"])
			refl = _attach_reflection(s, foot_e)
		add_child(s)
		enemies.append({"name": def["name"], "hp": def["hp"], "max_hp": def["hp"],
			"atk": def["atk"], "def": def["def"], "gold": def["gold"], "xp": def.get("xp", 0),
			"sprite": s, "home": home, "alive": true, "is_boss": is_boss,
			"id": def["sprite"], "frame": 0, "acts": 0, "enraged": false, "refl": refl})

## Weicher Schatten unter einem Kämpfer (als Kind, skaliert also mit).
func _attach_shadow(s: Sprite2D, rx: int, ry: int, foot_y: float) -> void:
	var sh := Sprite2D.new()
	sh.texture = SpriteFactory.shadow(rx, ry)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sh.position = Vector2(0, foot_y)
	sh.z_index = -1
	sh.show_behind_parent = true
	s.add_child(sh)

## Waffe des Helden als Overlay in die (linke, zum Gegner gewandte) Hand.
func _attach_weapon(s: Sprite2D, hero_id: String) -> void:
	var tex := SpriteFactory.hero_weapon(hero_id)
	if tex == null:
		return
	var w := Sprite2D.new()
	w.texture = tex
	# Der Held ist flip_h → die Waffenhand liegt bildlinks. In den Faustbereich
	# setzen (leicht unter Schultern) und kompakt halten, damit sie nicht dominiert.
	w.position = Vector2(-6, 1)
	w.scale = Vector2(0.85, 0.85)
	w.z_index = 1
	s.add_child(w)

## Additiver Lichtkreis unter dem Kämpfer — hebt ihn wie ein Spot hervor.
func _attach_glow_pool(s: Sprite2D, foot_y: float, color: Color) -> void:
	var pool := Sprite2D.new()
	pool.texture = SpriteFactory.circle(20, color)
	pool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pool.position = Vector2(0, foot_y)
	pool.scale = Vector2(1.6, 0.5)
	pool.z_index = -1
	pool.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = mat
	s.add_child(pool)
	# Sanftes Pulsieren des Bodenlichts — gibt jedem Kämpfer ruhiges „Atmen".
	var breath := pool.create_tween().set_loops()
	breath.tween_property(pool, "modulate:a", 0.5, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(pool, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Gespiegeltes Abbild unter den Füßen — der „nasse Boden“-Look aus HD-2D-Spielen.
func _attach_reflection(s: Sprite2D, foot_y: float, alpha := 0.15) -> Sprite2D:
	var r := Sprite2D.new()
	r.texture = s.texture
	r.flip_v = true
	r.flip_h = s.flip_h
	r.position = Vector2(0, foot_y * 2.0 + 1.0)
	r.modulate = Color(1, 1, 1, alpha)
	r.z_index = -2
	r.show_behind_parent = true
	s.add_child(r)
	return r

## Pulsierende Aura + aufsteigende Glut hinter dem Boss (rot bzw. eisblau).
func _attach_boss_aura(s: Sprite2D, theme: String) -> void:
	var aura_col := Color(0.20, 0.75, 1.0, 0.30) if theme == "frost" else Color(1.0, 0.15, 0.05, 0.30)
	var ember_col := Color(0.45, 0.85, 1.0, 0.8) if theme == "frost" else Color(1.0, 0.25, 0.08, 0.8)
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(40, aura_col)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.scale = Vector2(3.2, 3.6)
	glow.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	s.add_child(glow)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var ember := CPUParticles2D.new()
	ember.amount = 26
	ember.lifetime = 1.6
	ember.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember.emission_rect_extents = Vector2(15, 16)
	ember.direction = Vector2(0, -1)
	ember.spread = 20.0
	ember.gravity = Vector2(0, -18)
	ember.initial_velocity_min = 6.0
	ember.initial_velocity_max = 16.0
	ember.scale_amount_min = 0.5
	ember.scale_amount_max = 1.1
	ember.color = ember_col
	ember.texture = SpriteFactory.circle(3, Color.WHITE)
	s.add_child(ember)

## Fackel: flackerndes Licht + aufsteigende Glut (Flammenfarbe je Schauplatz).
func _add_torch(pos: Vector2, pal: Dictionary) -> void:
	var pole := ColorRect.new()
	pole.size = Vector2(8, 46)
	pole.position = pos + Vector2(-4, -6)
	pole.color = Color(0.28, 0.18, 0.10)
	pole.z_index = -10
	add_child(pole)
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(30, pal["glow"])
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.position = pos + Vector2(0, -14)
	glow.scale = Vector2(3, 3)
	glow.z_index = -9
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	var flicker := glow.create_tween().set_loops()
	flicker.tween_property(glow, "scale", Vector2(3.4, 3.4), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flicker.tween_property(glow, "scale", Vector2(2.8, 2.8), 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flicker.tween_property(glow, "scale", Vector2(3.2, 3.2), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var flame := CPUParticles2D.new()
	flame.position = pos + Vector2(0, -14)
	flame.amount = 14
	flame.lifetime = 0.7
	flame.direction = Vector2(0, -1)
	flame.spread = 16.0
	flame.gravity = Vector2(0, -60)
	flame.initial_velocity_min = 12.0
	flame.initial_velocity_max = 30.0
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.4
	flame.color = pal["flame"]
	flame.texture = SpriteFactory.circle(3, Color.WHITE)
	flame.z_index = -8
	add_child(flame)

## Lichtschächte von oben (HD-2D-Look): additive Keile, die sanft pulsieren.
func _add_god_rays(pal: Dictionary) -> void:
	for i in 4:
		var ray := Polygon2D.new()
		var w := 55.0 + (i % 2) * 45.0
		ray.polygon = PackedVector2Array([Vector2(-w * 0.25, 0), Vector2(w * 0.25, 0),
			Vector2(w, 580), Vector2(-w, 580)])
		ray.color = pal["ray"]
		ray.position = Vector2(150 + i * 220.0, -20)
		ray.rotation = 0.14 - i * 0.07
		ray.z_index = -3
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ray.material = mat
		add_child(ray)
		var pulse := ray.create_tween().set_loops()
		pulse.tween_property(ray, "modulate:a", 0.35, 2.2 + i * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ray, "modulate:a", 1.0, 2.2 + i * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Im Licht schwebende Staubkörnchen (additiv, sehr subtil).
func _add_dust_motes(pal: Dictionary) -> void:
	var dust := CPUParticles2D.new()
	dust.position = Vector2(480, 300)
	dust.amount = 26
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(500, 260)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 40.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	dust.color = pal["dust"]
	dust.texture = SpriteFactory.circle(2, Color.WHITE)
	dust.z_index = -2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dust.material = mat
	add_child(dust)

## Unscharfe dunkle Vordergrund-Silhouetten unten im Bild (Tilt-Shift-Illusion).
func _add_foreground_blur(pal: Dictionary) -> void:
	var spots := [Vector2(70, 545), Vector2(500, 570), Vector2(900, 550)]
	for i in spots.size():
		var blob := Sprite2D.new()
		blob.texture = SpriteFactory.circle(60, pal["fg"])
		blob.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		blob.position = spots[i]
		blob.scale = Vector2(3.6 + i * 0.6, 1.5)
		blob.modulate.a = 0.75
		blob.z_index = 15
		add_child(blob)
		var drift := blob.create_tween().set_loops()
		drift.tween_property(blob, "position:x", blob.position.x + 18.0 + i * 6.0, 6.0 + i * 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(blob, "position:x", blob.position.x, 6.0 + i * 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Träge dahinziehende Nebelschwaden geben dem Bild Tiefe.
func _add_fog(pal: Dictionary) -> void:
	for i in 4:
		var fog := Sprite2D.new()
		fog.texture = SpriteFactory.circle(60, pal["fog"])
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fog.scale = Vector2(6.0 + i, 2.2)
		fog.position = Vector2(150 + i * 260.0, 320 + i * 30.0)
		fog.z_index = -5
		add_child(fog)
		var drift := fog.create_tween().set_loops()
		var dx := 90.0 + i * 25.0
		drift.tween_property(fog, "position:x", fog.position.x + dx, 7.0 + i * 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(fog, "position:x", fog.position.x, 7.0 + i * 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Sanft rieselnder Schnee in der Frostgrotte.
func _add_snow() -> void:
	var snow := CPUParticles2D.new()
	snow.position = Vector2(480, -20)
	snow.amount = 70
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(520, 10)
	snow.direction = Vector2(0, 1)
	snow.spread = 12.0
	snow.gravity = Vector2(0, 12)
	snow.initial_velocity_min = 55.0
	snow.initial_velocity_max = 95.0
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.2
	snow.color = Color(0.95, 0.98, 1.0, 0.75)
	snow.texture = SpriteFactory.circle(2, Color.WHITE)
	snow.z_index = 20
	add_child(snow)

## Lebendige Idles: Held*innen und Monster durchlaufen ihre 4-Frame-Animation.
func _start_idle_animations() -> void:
	var frame_timer := Timer.new()
	frame_timer.wait_time = 0.16
	frame_timer.autostart = true
	frame_timer.timeout.connect(func():
		for e in enemies:
			if e["alive"] and SpriteFactory.enemy_has_anim(e["id"]):
				e["frame"] = (e["frame"] + 1) % SpriteFactory.ENEMY_FRAMES
				var tex := SpriteFactory.enemy_frame(e["id"], e["frame"])
				(e["sprite"] as Sprite2D).texture = tex
				if is_instance_valid(e["refl"]):
					(e["refl"] as Sprite2D).texture = tex
		for h in heroes:
			if h["data"]["hp"] > 0:
				h["frame"] = (h["frame"] + 1) % 4
				var tex := SpriteFactory.hero_battle_frame(h["data"]["id"], h["frame"])
				(h["sprite"] as Sprite2D).texture = tex)
	add_child(frame_timer)
	var glint_timer := Timer.new()
	glint_timer.wait_time = 2.6
	glint_timer.autostart = true
	glint_timer.timeout.connect(func():
		var h: Dictionary = heroes[randi() % heroes.size()]
		if h["data"]["hp"] <= 0:
			return
		var s: Sprite2D = h["sprite"]
		var glint := Sprite2D.new()
		glint.texture = SpriteFactory.circle(5, Color(1, 1, 1))
		glint.position = s.position + Vector2(-52, -44) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glint.material = mat
		glint.scale = Vector2(0.2, 0.2)
		add_child(glint)
		var tw := glint.create_tween()
		tw.tween_property(glint, "scale", Vector2(1.4, 1.4), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(glint, "rotation", 0.8, 0.4)
		tw.tween_property(glint, "modulate:a", 0.0, 0.22)
		tw.tween_callback(glint.queue_free))
	add_child(glint_timer)

func _idle_bob(s: Sprite2D, period: float) -> Tween:
	var tw := create_tween().set_loops()
	tw.tween_property(s, "position:y", s.position.y - 4.0, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s, "position:y", s.position.y, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer
	# Tilt-Shift-Tiefenunschärfe (nur die Bühne, UI kommt später obendrauf).
	layer.add_child(Fx.tilt_shift(2.2, 1.6, 0.46, 0.28))
	# Filmisches Color-Grading: warmes Licht oben, kühle Schatten unten.
	var pal := _palette()
	var grade := TextureRect.new()
	grade.texture = SpriteFactory.gradient(8, 64, pal["grade_top"], pal["grade_bottom"])
	grade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	grade.stretch_mode = TextureRect.STRETCH_SCALE
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(grade)
	# Vignette für den Kino-Look
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 378)
	panel.custom_minimum_size = Vector2(920, 148)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.12, 0.94)
	style.border_color = Color(0.75, 0.7, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 40)
	panel.add_child(hb)
	menu_box = VBoxContainer.new()
	menu_box.custom_minimum_size = Vector2(280, 0)
	hb.add_child(menu_box)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 8)
	hb.add_child(party_box)
	for h in heroes:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		party_box.add_child(row)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		row.add_child(l)
		h["hp_label"] = l
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 10)
		row.add_child(bars)
		h["hp_fill"] = _make_bar(bars, BAR_W, 10, Color(0.35, 0.95, 0.45))
		h["mp_fill"] = _make_bar(bars, 110, 10, Color(0.35, 0.55, 1.0))
	msg_label = Label.new()
	msg_label.position = Vector2(30, 84)
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(msg_label)
	cursor = Polygon2D.new()
	cursor.polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 8), Vector2(0, 16)])
	cursor.color = Color(1.0, 0.9, 0.3)
	cursor.visible = false
	add_child(cursor)
	var pulse := create_tween().set_loops()
	pulse.tween_property(cursor, "scale", Vector2(1.3, 1.3), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(cursor, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not boss_def.is_empty():
		_build_boss_bar()
	_refresh_party()

## Kleine Statusleiste (dunkler Rahmen + farbige Füllung); liefert die Füllung.
func _make_bar(parent: Control, w: int, h: int, color: Color) -> ColorRect:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	parent.add_child(holder)
	var bg := ColorRect.new()
	bg.size = Vector2(w, h)
	bg.color = Color(0, 0, 0, 0.6)
	holder.add_child(bg)
	var fill := ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(w - 2, h - 2)
	fill.color = color
	holder.add_child(fill)
	return fill

## Große Boss-HP-Leiste oben in der Mitte (erscheint beim Auftritt).
func _build_boss_bar() -> void:
	boss_bar_holder = Control.new()
	boss_bar_holder.position = Vector2(270, 52)
	boss_bar_holder.modulate.a = 0.0
	ui_layer.add_child(boss_bar_holder)
	var frost: bool = boss_def.get("theme", "bone") == "frost"
	var name_l := Label.new()
	name_l.text = "☠  %s  ☠" % boss_def["name"].to_upper()
	name_l.position = Vector2(0, -30)
	name_l.custom_minimum_size = Vector2(420, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color",
		Color(0.55, 0.9, 1.0) if frost else Color(1.0, 0.85, 0.3))
	name_l.add_theme_color_override("font_outline_color",
		Color(0.03, 0.10, 0.25) if frost else Color(0.25, 0.03, 0.03))
	name_l.add_theme_constant_override("outline_size", 6)
	boss_bar_holder.add_child(name_l)
	var bg := ColorRect.new()
	bg.size = Vector2(420, 16)
	bg.color = Color(0, 0, 0, 0.7)
	boss_bar_holder.add_child(bg)
	var border := ColorRect.new()
	border.size = Vector2(424, 20)
	border.position = Vector2(-2, -2)
	border.color = Color(0.15, 0.35, 0.6) if frost else Color(0.6, 0.15, 0.1)
	border.show_behind_parent = true
	bg.add_child(border)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.position = Vector2(1, 1)
	boss_bar_fill.size = Vector2(418, 14)
	boss_bar_fill.color = Color(0.25, 0.75, 1.0) if frost else Color(0.9, 0.2, 0.15)
	bg.add_child(boss_bar_fill)

func _refresh_party() -> void:
	for h in heroes:
		var d: Dictionary = h["data"]
		h["hp_label"].text = "%-7s Lv%2d  LP %3d/%3d  MP %2d/%2d" % \
			[d["name"], d.get("level", 1), d["hp"], d["max_hp"], d["mp"], d["max_mp"]]
		h["hp_label"].add_theme_color_override("font_color",
			Color(1, 0.4, 0.4) if d["hp"] <= d["max_hp"] / 4 else Color.WHITE)
		var hp_ratio: float = float(d["hp"]) / float(d["max_hp"])
		var hp_fill: ColorRect = h["hp_fill"]
		var tw := hp_fill.create_tween()
		tw.tween_property(hp_fill, "size:x", maxf((BAR_W - 2) * hp_ratio, 0.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hp_fill.color = Color(0.35, 0.95, 0.45) if hp_ratio > 0.5 \
			else (Color(0.95, 0.8, 0.25) if hp_ratio > 0.25 else Color(0.95, 0.3, 0.2))
		var mp_fill: ColorRect = h["mp_fill"]
		var mp_tw := mp_fill.create_tween()
		mp_tw.tween_property(mp_fill, "size:x", maxf(108.0 * d["mp"] / d["max_mp"], 0.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_boss_bar(e: Dictionary) -> void:
	if boss_bar_fill == null:
		return
	var ratio := clampf(float(e["hp"]) / e["max_hp"], 0.0, 1.0)
	var tw := boss_bar_fill.create_tween()
	tw.tween_property(boss_bar_fill, "size:x", 418.0 * ratio, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _say(text: String) -> void:
	msg_label.text = text

## ---------- Rundenablauf ----------

func _run_battle() -> void:
	# Gestaffelter Einmarsch: alle gleiten nacheinander eingeblendet an ihre
	# Position, dann beginnt das Idle-Wippen.
	await get_tree().create_timer(0.15).timeout
	var units: Array = heroes + enemies
	for i in units.size():
		var u: Dictionary = units[i]
		var s: Sprite2D = u["sprite"]
		s.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_property(s, "position", u["home"], 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(0.55 + units.size() * 0.09).timeout
	for i in heroes.size():
		heroes[i]["bob"] = _idle_bob(heroes[i]["sprite"], 2.0 + i * 0.3)
	for i in enemies.size():
		_idle_bob(enemies[i]["sprite"], 1.6 + i * 0.25)
	_start_idle_animations()
	if not boss_def.is_empty():
		await _boss_entrance()
	else:
		_say("Monster greifen an!")
	await get_tree().create_timer(0.9).timeout
	while true:
		for h in heroes:
			if h["data"]["hp"] <= 0 or not _any_enemy_alive():
				continue
			var fled: bool = await _hero_turn(h)
			if fled:
				finished.emit(true)
				return
			if not _any_enemy_alive():
				await _victory()
				return
		for e in enemies:
			if not e["alive"]:
				continue
			await _enemy_turn(e)
			if not GameState.party_alive():
				await _defeat()
				return

func _hero_turn(h: Dictionary) -> bool:
	var d: Dictionary = h["data"]
	while true:
		var cmd: int = await _menu([d["name"] + ":  Angriff", "Fähigkeit", "Item", "Fliehen"], h)
		match cmd:
			0:
				var t := await _pick_enemy()
				if t < 0: continue
				await _hero_attack(h, enemies[t])
				return false
			1:
				var used_ab: bool = await _ability_menu(h)
				if used_ab: return false
			2:
				var used: bool = await _item_menu(h)
				if used: return false
			3:
				_say("Fluchtversuch ...")
				await get_tree().create_timer(0.6).timeout
				if randf() < 0.6:
					_say("Erfolgreich geflohen!")
					AudioManager.play_sfx("flee")
					await get_tree().create_timer(0.8).timeout
					return true
				_say("Flucht gescheitert!")
				await get_tree().create_timer(0.7).timeout
				return false
	return false

## Untermenü: eine der Fähigkeiten (oder die Ultimative) wählen und ausführen.
func _ability_menu(h: Dictionary) -> bool:
	var d: Dictionary = h["data"]
	var abilities: Array = d["abilities"]
	var ult: Dictionary = d["ultimate"]
	var entries := []
	for ab in abilities:
		entries.append("%s (%d MP) — %s" % [ab["name"], ab["cost"], ab["desc"]])
	entries.append("★ %s — %s" % [ult["name"],
		"bereits eingesetzt" if h["ult_used"] else ult["desc"]])
	entries.append("Zurück")
	var pick: int = await _menu(entries, h)
	if pick == abilities.size():
		if h["ult_used"]:
			_say("Die ultimative Kraft ist in diesem Kampf bereits verbraucht!")
			AudioManager.play_sfx("error")
			return false
		h["ult_used"] = true
		match d["id"]:
			"serena": await _ultimate_serena(h)
			"rax": await _ultimate_rax(h)
			_: await _ultimate_milo(h)
		return true
	if pick > abilities.size():
		return false
	var ab: Dictionary = abilities[pick]
	if d["mp"] < ab["cost"]:
		_say("Nicht genug MP!")
		AudioManager.play_sfx("error")
		return false
	match ab["target"]:
		"all":
			d["mp"] -= ab["cost"]
			_refresh_party()
			if ab["kind"] == "rocket":
				await _rocket_all(h, ab)
			else:
				await _whirl_all(h, ab)
		"one":
			var t: int = await _pick_enemy()
			if t < 0: return false
			d["mp"] -= ab["cost"]
			_refresh_party()
			match ab["kind"]:
				"magic": await _fireball(h, ab, enemies[t])
				"beam": await _laser(h, ab, enemies[t])
				_: await _pierce(h, ab, enemies[t])
		"ally":
			var a: int = await _menu(_ally_entries(), h)
			d["mp"] -= ab["cost"]
			_refresh_party()
			await _heal_ally(h, ab, heroes[a])
	return true

## Auswahl-Einträge „Für <Name>" für alle Party-Mitglieder (beliebige Größe).
func _ally_entries() -> Array:
	var names := []
	for hh in heroes:
		names.append("Für " + hh["data"]["name"])
	return names

## ---------- Menüs (await auf Spieler-Eingabe) ----------

func _menu(entries: Array, h: Dictionary) -> int:
	_highlight_hero(h, true)
	current_menu = entries
	menu_index = 0
	ui_state = "menu"
	_redraw_menu()
	# Sanftes Einblenden des Menüs
	menu_box.modulate.a = 0.0
	var fade := menu_box.create_tween()
	fade.tween_property(menu_box, "modulate:a", 1.0, 0.15)
	await _choice_made
	_clear_menu()
	_highlight_hero(h, false)
	return choice

func _highlight_hero(h: Dictionary, on: bool) -> void:
	var s: Sprite2D = h["sprite"]
	s.modulate = Color(1.3, 1.3, 1.0) if on else Color.WHITE
	if on:
		if h.get("turn_arrow") != null:
			return
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(-13, -13), Vector2(13, -13), Vector2(0, 5)])
		arrow.color = Color(1.0, 0.9, 0.35)
		var base_y := s.position.y - 82.0
		arrow.position = Vector2(s.position.x, base_y)
		add_child(arrow)
		h["turn_arrow"] = arrow
		var tw := arrow.create_tween().set_loops()
		tw.tween_property(arrow, "position:y", base_y + 9.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(arrow, "position:y", base_y, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif h.get("turn_arrow") != null:
		(h["turn_arrow"] as Node).queue_free()
		h["turn_arrow"] = null

func _redraw_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	for i in current_menu.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		l.text = ("> " if i == menu_index else "  ") + str(current_menu[i])
		l.add_theme_color_override("font_color",
			Color.WHITE if i == menu_index else Color(0.65, 0.65, 0.72))
		menu_box.add_child(l)

func _clear_menu() -> void:
	ui_state = "none"
	for c in menu_box.get_children():
		c.queue_free()
	cursor.visible = false

func _pick_enemy() -> int:
	var alive := []
	for i in enemies.size():
		if enemies[i]["alive"]:
			alive.append(i)
	if alive.size() == 1:
		return alive[0]
	current_menu = alive
	menu_index = 0
	ui_state = "target"
	_update_cursor()
	_say("Ziel wählen (Z: OK, X: Zurück)")
	await _choice_made
	cursor.visible = false
	ui_state = "none"
	_say("")
	return choice

func _update_cursor() -> void:
	var e: Dictionary = enemies[current_menu[menu_index]]
	var s: Sprite2D = e["sprite"]
	var half_w: float = s.texture.get_width() * s.scale.x * 0.5
	cursor.visible = true
	cursor.position = s.position + Vector2(-half_w - 24, -10)

func _item_menu(h: Dictionary) -> bool:
	if GameState.inventory.is_empty():
		_say("Keine Items!")
		AudioManager.play_sfx("error")
		return false
	var names := GameState.inventory.keys()
	var entries := []
	for n in names:
		entries.append("%s x%d" % [n, GameState.inventory[n]])
	entries.append("Zurück")
	var pick: int = await _menu(entries, h)
	if pick >= names.size():
		return false
	var target: int = await _menu(_ally_entries(), h)
	var item_name: String = names[pick]
	var item: Dictionary = GameState.ITEMS[item_name]
	var td: Dictionary = heroes[target]["data"]
	GameState.use_item(item_name)
	td["hp"] = mini(td["hp"] + item["hp"], td["max_hp"])
	td["mp"] = mini(td["mp"] + item["mp"], td["max_mp"])
	AudioManager.play_sfx("heal")
	_sparkle(heroes[target]["sprite"].position, Color(0.4, 1.0, 0.5))
	_float_text(heroes[target]["sprite"].position, "+" + item_name, Color(0.5, 1.0, 0.6))
	_say("%s benutzt %s für %s." % [h["data"]["name"], item_name, td["name"]])
	_refresh_party()
	await get_tree().create_timer(0.8).timeout
	return true

func _unhandled_input(event: InputEvent) -> void:
	if ui_state == "menu":
		if event.is_action_pressed("move_up"): _menu_move(-1)
		elif event.is_action_pressed("move_down"): _menu_move(1)
		elif event.is_action_pressed("confirm"):
			choice = menu_index
			AudioManager.play_sfx("menu")
			_choice_made.emit()
	elif ui_state == "target":
		if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
			menu_index = (menu_index - 1 + current_menu.size()) % current_menu.size()
			AudioManager.play_sfx("menu")
			_update_cursor()
		elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
			menu_index = (menu_index + 1) % current_menu.size()
			AudioManager.play_sfx("menu")
			_update_cursor()
		elif event.is_action_pressed("confirm"):
			choice = current_menu[menu_index]
			AudioManager.play_sfx("menu")
			_choice_made.emit()
		elif event.is_action_pressed("cancel"):
			choice = -1
			_choice_made.emit()

func _menu_move(delta: int) -> void:
	menu_index = clampi(menu_index + delta, 0, current_menu.size() - 1)
	AudioManager.play_sfx("menu")
	_redraw_menu()

## ---------- Aktionen & Effekte ----------

func _hero_attack(h: Dictionary, e: Dictionary) -> void:
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	_say("%s greift an!" % h["data"]["name"])
	# Anspannung (Squash) vor dem Sprint — klassisches Squash & Stretch.
	var wind := create_tween()
	wind.tween_property(s, "scale", Vector2(5.5, 4.4), 0.09)
	wind.tween_property(s, "scale", Vector2(4.6, 5.4), 0.10)
	await wind.finished
	var strike_pos: Vector2 = es.position + Vector2(_strike_offset(e), 0)
	var tw := create_tween()
	tw.tween_property(s, "position", strike_pos, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector2(5, 5), 0.2)
	_ghost_trail(s, 0.2)
	await tw.finished
	AudioManager.play_sfx("slash")
	_slash_arc(es.position)
	_burst(es.position, Color(1.0, 0.9, 0.5), 10, 120)
	_impact_ring(es.position, Color(1, 1, 1, 0.7))
	var crit := randf() < 0.12
	await _hitstop(0.11 if crit else 0.06)
	var dmg: int = int(h["data"]["atk"] * randf_range(0.9, 1.2) * (1.6 if crit else 1.0)) - e["def"]
	if crit:
		_crit_fx(es.position)
	await _damage_enemy(e, maxi(dmg, 1))
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

## Kritischer Treffer: großer Schriftzug, extra Funken, stärkeres Beben.
func _crit_fx(pos: Vector2) -> void:
	_float_text(pos + Vector2(-30, -46), "KRITISCH!", Color(1.0, 0.62, 0.1), 36)
	_burst(pos, Color(1.0, 0.75, 0.2), 16, 200)
	_shake_camera(1.9)

## Angriffsposition: vor dem Gegner stehen, beim breiten Boss weiter außen.
func _strike_offset(e: Dictionary) -> float:
	var es: Sprite2D = e["sprite"]
	return es.texture.get_width() * es.scale.x * 0.5 + 30.0

func _whirl_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s entfesselt %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
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
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.25)
	await back.finished

func _fireball(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s wirkt %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.55, 0.15))
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.82, 0.35))
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 16.0, 0.22)
	await raise.finished
	# --- Aufladung: eine glühende Feuerkugel wächst in der Hand und pulsiert ---
	var hand := s.position + Vector2(-44, -4)
	var ball := Sprite2D.new()
	ball.texture = SpriteFactory.circle(15, Color(1.0, 0.5, 0.12))
	ball.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ball.position = hand
	ball.scale = Vector2(0.15, 0.15)
	var bmat := CanvasItemMaterial.new()
	bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ball.material = bmat
	var core := Sprite2D.new()
	core.texture = SpriteFactory.circle(8, Color(1.0, 0.96, 0.7))
	core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ball.add_child(core)
	var trail := CPUParticles2D.new()
	trail.amount = 34
	trail.lifetime = 0.4
	trail.direction = Vector2(1, 0)
	trail.spread = 30.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 95.0
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.6
	trail.color = Color(1.0, 0.5, 0.1, 0.85)
	trail.texture = SpriteFactory.circle(4, Color.WHITE)
	ball.add_child(trail)
	add_child(ball)
	AudioManager.play_sfx("charge")
	var charge := create_tween()
	charge.tween_property(ball, "scale", Vector2(1.1, 1.1), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(ball, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_SINE)
	await charge.finished
	# --- Abschuss: der große Feuerball rast zum Ziel und wächst dabei ---
	AudioManager.play_sfx("fire")
	var fly := create_tween()
	fly.tween_property(ball, "position", e["sprite"].position, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(ball, "scale", Vector2(2.7, 2.7), 0.34)
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
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.2)
	await back.finished

## Fokusstoß: schneller Sturmangriff, drei Hiebe, ignoriert die Verteidigung.
func _pierce(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s setzt %s ein!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var tw := create_tween()
	tw.tween_property(s, "position", es.position + Vector2(_strike_offset(e), 0), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(s, 0.14)
	await tw.finished
	for i in 3:
		AudioManager.play_sfx("slash")
		_slash_arc(es.position + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		_burst(es.position, Color(1.0, 0.95, 0.6), 7, 110)
		await get_tree().create_timer(0.11).timeout
	_impact_ring(es.position, Color(1.0, 0.95, 0.5, 0.8))
	var crit := randf() < 0.12
	await _hitstop(0.11 if crit else 0.06)
	var dmg: int = int((ab["power"] + d["atk"]) * randf_range(0.95, 1.15) * (1.6 if crit else 1.0))
	if crit:
		_crit_fx(es.position)
	await _damage_enemy(e, maxi(dmg, 1))
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

## ---------- Roboter-Held Rax: Laser, Raketen, Orbital-Ultimate ----------

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
	glow.color = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	seg.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = pts
	core.color = Color(1, 1, 1, 0.95)
	core.scale = Vector2(1, 0.4)
	seg.add_child(core)
	seg.scale = Vector2(1, 0.1)
	var tw := seg.create_tween()
	tw.tween_property(seg, "scale", Vector2(1, width), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(seg, "modulate:a", 0.0, 0.2)
	tw.tween_callback(seg.queue_free)

## Laserstoß: Kanone lädt cyan auf, dann ein gebündelter Strahl auf einen Gegner.
func _laser(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s feuert %s!" % [d["name"], ab["name"]])
	var muzzle := _cannon_muzzle(s)
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
	var ct := chg.create_tween()
	ct.tween_property(chg, "scale", Vector2(1.5, 1.5), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await ct.finished
	chg.queue_free()
	var target: Vector2 = e["sprite"].position
	AudioManager.play_sfx("laser")
	_beam(muzzle, target, Color(0.45, 0.95, 1.0, 0.9), 16.0, 0.16)
	_impact_ring(target, Color(0.6, 0.97, 1.0, 0.85))
	_burst(target, Color(0.6, 0.95, 1.0), 18, 180)
	_flash_screen(Color(0.4, 0.85, 1.0, 0.20))
	_shake_camera(1.7)
	await _hitstop(0.10)
	var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.9, 1.15)) - e["def"] / 2
	await _damage_enemy(e, maxi(dmg, 1))

## Eine einzelne Rakete fliegt im Bogen zum Ziel und detoniert.
func _launch_rocket(from: Vector2, to: Vector2) -> void:
	var r := Sprite2D.new()
	r.texture = SpriteFactory.circle(4, Color(0.95, 0.92, 0.86))
	r.position = from
	var smoke := CPUParticles2D.new()
	smoke.amount = 18
	smoke.lifetime = 0.45
	smoke.direction = Vector2(-1, 0)
	smoke.spread = 30.0
	smoke.gravity = Vector2(0, 20)
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 55.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	smoke.color = Color(1.0, 0.6, 0.25, 0.8)
	smoke.texture = SpriteFactory.circle(3, Color.WHITE)
	r.add_child(smoke)
	add_child(r)
	var mid := (from + to) * 0.5 + Vector2(0, -randf_range(50, 100))
	var t := create_tween()
	t.tween_property(r, "position", mid, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		r.queue_free()
		_explosion(to, 1.15)
		AudioManager.play_sfx("boom")
		_shake_camera(1.2))

## Raketensalve: zwei Wellen kleiner Raketen auf alle Gegner.
func _rocket_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s startet %s!" % [d["name"], ab["name"]])
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.6, 0.2))
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	for wave in 2:
		for e in alive:
			if not e["alive"]:
				continue
			var aim: Vector2 = e["sprite"].position + Vector2(randf_range(-16, 16), randf_range(-14, 14))
			_launch_rocket(_cannon_muzzle(s), aim)
			AudioManager.play_sfx("rocket")
			await get_tree().create_timer(0.09).timeout
		await get_tree().create_timer(0.18).timeout
	await get_tree().create_timer(0.35).timeout
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["mag"] * 0.7) * randf_range(0.9, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))

## Zielmarker, der über einem Gegner zusammenzieht (Orbital-Anvisierung).
func _target_reticle(pos: Vector2) -> void:
	var r := Sprite2D.new()
	r.texture = SpriteFactory.circle(20, Color(0.5, 0.95, 1.0, 0.55))
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.position = pos
	r.scale = Vector2(2.3, 2.3)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = m
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector2(0.7, 0.7), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(r, "modulate:a", 1.0, 0.4)
	tw.tween_callback(r.queue_free)

## Gewaltige Strahlensäule, die von oben auf einen Punkt niederfährt.
func _orbital_column(pos: Vector2) -> void:
	var col := Polygon2D.new()
	var w := 26.0
	col.polygon = PackedVector2Array([Vector2(-w, -540), Vector2(w, -540),
		Vector2(w * 0.45, 0), Vector2(-w * 0.45, 0)])
	col.color = Color(0.6, 0.95, 1.0, 0.85)
	col.position = pos
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	col.material = m
	col.scale = Vector2(0.15, 1)
	add_child(col)
	var tw := create_tween()
	tw.tween_property(col, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.14)
	tw.tween_property(col, "modulate:a", 0.0, 0.3)
	tw.tween_callback(col.queue_free)

## Rax' Ultimative „Orbitallaser": Zielmarker, dann niederfahrende Strahlensäulen
## auf alle Gegner mit weißem Blitz, Beben und Zeitlupe.
func _ultimate_rax(h: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s aktiviert sein Overload-Protokoll!" % d["name"])
	if h.has("bob"):
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(0.4, 0.9, 1.0))
	s.modulate = Color(1.4, 1.5, 1.7)
	_burst(s.position, Color(0.5, 0.95, 1.0), 16, 150)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ ORBITALLASER ★", Color(0.5, 0.9, 1.0))
	await get_tree().create_timer(0.5).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	for e in alive:
		_target_reticle(e["sprite"].position)
	await get_tree().create_timer(0.55).timeout
	AudioManager.play_sfx("laser")
	_flash_screen(Color(0.6, 0.9, 1.0, 0.5))
	_shake_camera(2.4)
	for e in alive:
		_orbital_column(e["sprite"].position)
		_explosion(e["sprite"].position, 1.6)
	AudioManager.play_sfx("bigboom")
	await _hitstop(0.16)
	s.modulate = Color.WHITE
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 2.5 + 40) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	_undim(dim)
	h["bob"] = _idle_bob(s, 2.0)

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

## Serenas Ultimative „Sternenklinge“: Blitz-Dashes durch alle Gegner,
## dann ein gewaltiger Kreuzschnitt mit weißem Blitz.
func _ultimate_serena(h: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s entfesselt ihre ultimative Kraft!" % d["name"])
	if h.has("bob"):
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.92, 0.45))
	s.modulate = Color(1.6, 1.5, 1.1)
	_burst(s.position, Color(1.0, 0.95, 0.5), 14, 130)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ STERNENKLINGE ★", Color(1.0, 0.9, 0.35))
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

## Milos Ultimative „Meteorregen“: brennende Meteore stürzen auf alle Gegner.
func _ultimate_milo(h: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s entfesselt seine ultimative Kraft!" % d["name"])
	if h.has("bob"):
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.55, 0.15))
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.8, 0.3))
	s.modulate = Color(1.5, 1.2, 1.6)
	var rise := create_tween()
	rise.tween_property(s, "position:y", s.position.y - 34.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("★ METEORREGEN ★", Color(1.0, 0.55, 0.2))
	await get_tree().create_timer(0.5).timeout
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Meteore schlagen gestaffelt im Gegnergebiet ein
	for i in 6:
		var target: Dictionary = alive[i % alive.size()]
		var impact: Vector2 = target["sprite"].position + Vector2(randf_range(-50, 50), randf_range(-30, 30))
		var meteor := Sprite2D.new()
		meteor.texture = SpriteFactory.circle(12, Color(1.0, 0.45, 0.1))
		var core := Sprite2D.new()
		core.texture = SpriteFactory.circle(6, Color(1.0, 0.9, 0.5))
		meteor.add_child(core)
		var trail := CPUParticles2D.new()
		trail.amount = 20
		trail.lifetime = 0.3
		trail.direction = Vector2(1, -1)
		trail.spread = 20.0
		trail.gravity = Vector2.ZERO
		trail.initial_velocity_min = 60.0
		trail.initial_velocity_max = 120.0
		trail.scale_amount_min = 0.6
		trail.scale_amount_max = 1.4
		trail.color = Color(1.0, 0.55, 0.1, 0.85)
		trail.texture = SpriteFactory.circle(4, Color.WHITE)
		meteor.add_child(trail)
		meteor.position = impact + Vector2(randf_range(120, 260), -420)
		add_child(meteor)
		AudioManager.play_sfx("meteor")
		var fall := create_tween()
		fall.tween_property(meteor, "position", impact, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_callback(func():
			meteor.queue_free()
			_explosion(impact)
			AudioManager.play_sfx("boom")
			_shake_camera(1.5))
		await get_tree().create_timer(0.16).timeout
	await get_tree().create_timer(0.5).timeout
	_flash_screen(Color(1.0, 0.6, 0.2, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.4)
	await _hitstop(0.14)
	s.modulate = Color.WHITE
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 2.5 + 40) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	_undim(dim)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)

## Heillicht: grüner Lichtring + Funken, heilt einen Verbündeten.
func _heal_ally(h: Dictionary, ab: Dictionary, target: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var td: Dictionary = target["data"]
	_say("%s wirkt %s auf %s!" % [d["name"], ab["name"], td["name"]])
	var s: Sprite2D = h["sprite"]
	_cast_circle(s.position + Vector2(0, 40), Color(0.45, 1.0, 0.55))
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
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.2)
	await back.finished

func _enemy_turn(e: Dictionary) -> void:
	var alive_heroes := []
	for h in heroes:
		if h["data"]["hp"] > 0:
			alive_heroes.append(h)
	if alive_heroes.is_empty():
		return
	e["acts"] += 1
	# In der Wut-Phase entfesselt der Boss einmalig seine Ultimative.
	if e["is_boss"] and e["enraged"] and not e.get("ult_used", false):
		e["ult_used"] = true
		await _boss_ultimate(e, alive_heroes)
		return
	# Kurzes Aufladen (Anspannen + rote Färbung) vor jeder Gegner-Aktion.
	var es: Sprite2D = e["sprite"]
	var base_scale: Vector2 = es.scale
	var windup := create_tween()
	windup.tween_property(es, "scale", base_scale * 1.15, 0.16)
	windup.parallel().tween_property(es, "modulate", Color(1.3, 0.8, 0.8), 0.16)
	windup.tween_property(es, "scale", base_scale, 0.12)
	windup.parallel().tween_property(es, "modulate", e.get("tint", Color.WHITE), 0.12)
	await windup.finished
	if e["is_boss"] and e["acts"] % 3 == 0:
		await _boss_aoe(e, alive_heroes)
		return
	var target: Dictionary = alive_heroes[randi() % alive_heroes.size()]
	_say("%s greift %s an!" % [e["name"], target["data"]["name"]])
	var tw := create_tween()
	tw.tween_property(es, "position", target["sprite"].position + Vector2(-60, 0), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if e["is_boss"]:
		_ghost_trail(es, 0.22)
	await tw.finished
	AudioManager.play_sfx("hit")
	_burst(target["sprite"].position, _palette()["hit"], 8, 110)
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.15)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	var back := create_tween()
	back.tween_property(es, "position", e["home"], 0.25).set_trans(Tween.TRANS_QUAD)
	await back.finished
	await get_tree().create_timer(0.25).timeout

## Boss-Spezial: Knochen- bzw. Eissturm prasselt auf die ganze Gruppe.
func _boss_aoe(e: Dictionary, targets: Array) -> void:
	var frost: bool = boss_def.get("theme", "bone") == "frost"
	_say("%s beschwört den %s!" % [e["name"], boss_def["aoe_name"]])
	AudioManager.play_sfx("roar")
	var es: Sprite2D = e["sprite"]
	var pump := create_tween()
	pump.tween_property(es, "scale", es.scale * 1.25, 0.35).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", es.scale, 0.15)
	await pump.finished
	_flash_screen(Color(0.3, 0.7, 1.0, 0.40) if frost else Color(1.0, 0.15, 0.1, 0.40))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.0)
	# Projektilhagel über den Helden (Knochen bzw. Eissplitter)
	var impact_col := Color(0.6, 0.9, 1.0) if frost else Color(0.9, 0.88, 0.8)
	for i in 12:
		var b := Sprite2D.new()
		b.texture = SpriteFactory.shard() if frost else SpriteFactory.bone()
		b.scale = Vector2(3, 3)
		b.rotation = randf() * TAU if not frost else randf_range(-0.3, 0.3)
		b.position = Vector2(randf_range(600, 860), -30)
		add_child(b)
		var fall := create_tween()
		fall.tween_interval(randf_range(0.0, 0.35))
		fall.tween_property(b, "position:y", randf_range(240, 360), randf_range(0.30, 0.5)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if not frost:
			fall.parallel().tween_property(b, "rotation", b.rotation + randf_range(-6.0, 6.0), 0.5)
		fall.tween_callback(func():
			_burst(b.position, impact_col, 5, 80)
			b.queue_free())
	await get_tree().create_timer(0.55).timeout
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.7, 0.9)) - t["data"]["def"], 1)
		_burst(t["sprite"].position, Color(0.5, 0.8, 1.0) if frost else Color(0.9, 0.4, 0.9), 8, 110)
		_damage_hero(t, dmg)
	await get_tree().create_timer(0.7).timeout

## Boss-Ultimative: „Armee der Verdammten“ (Geisterschädel-Welle) bzw.
## „Ewiger Winter“ (Eisspeere brechen unter den Helden hervor).
func _boss_ultimate(e: Dictionary, targets: Array) -> void:
	var frost: bool = boss_def.get("theme", "bone") == "frost"
	var ult_name: String = boss_def["ultimate_name"]
	_say("%s entfesselt: %s!" % [e["name"], ult_name])
	var dim := _dim_world(0.55)
	var es: Sprite2D = e["sprite"]
	var base: Vector2 = es.scale
	AudioManager.play_sfx("ult_charge")
	var pump := create_tween()
	pump.tween_property(es, "scale", base * 1.35, 0.55).set_trans(Tween.TRANS_QUAD)
	await pump.finished
	AudioManager.play_sfx("roar")
	_shake_camera(2.0)
	_ult_banner("☠ %s ☠" % ult_name.to_upper(),
		Color(0.55, 0.9, 1.0) if frost else Color(1.0, 0.45, 0.35))
	await get_tree().create_timer(0.6).timeout
	if frost:
		# Eisspeere brechen unter jedem Helden aus dem Boden
		AudioManager.play_sfx("bigboom")
		_flash_screen(Color(0.5, 0.8, 1.0, 0.5))
		_shake_camera(2.2)
		for t in targets:
			var pos: Vector2 = t["sprite"].position
			for k in 3:
				var spike := Sprite2D.new()
				spike.texture = SpriteFactory.shard()
				spike.scale = Vector2(4.5, 6.5)
				spike.position = pos + Vector2((k - 1) * 26.0, 110)
				spike.rotation = (k - 1) * 0.18
				add_child(spike)
				var rise := create_tween()
				rise.tween_interval(k * 0.06)
				rise.tween_property(spike, "position:y", pos.y + 4 + k * 7.0, 0.15) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				rise.tween_interval(0.55)
				rise.tween_property(spike, "modulate:a", 0.0, 0.3)
				rise.tween_callback(spike.queue_free)
			_burst(pos, Color(0.6, 0.9, 1.0), 14, 150)
		await get_tree().create_timer(0.5).timeout
	else:
		# Eine Welle geisterhafter Schädel fegt über das Schlachtfeld
		AudioManager.play_sfx("bigboom")
		_flash_screen(Color(1.0, 0.2, 0.15, 0.45))
		for i in 9:
			var sk := Sprite2D.new()
			sk.texture = SpriteFactory.skull()
			sk.scale = Vector2(4, 4)
			sk.modulate = Color(0.95, 0.8, 1.0, 0.85)
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sk.material = mat
			sk.position = Vector2(-60, 90 + (i % 5) * 55.0 + randf_range(-18, 18))
			add_child(sk)
			var fly := create_tween()
			fly.tween_interval(i * 0.07)
			fly.tween_property(sk, "position:x", 1040.0, randf_range(0.5, 0.75)) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fly.parallel().tween_property(sk, "position:y", sk.position.y + randf_range(-50, 50), 0.7)
			fly.tween_callback(sk.queue_free)
		await get_tree().create_timer(0.55).timeout
		for t in targets:
			_burst(t["sprite"].position, Color(0.85, 0.5, 1.0), 12, 140)
		_shake_camera(2.0)
		await get_tree().create_timer(0.35).timeout
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.95, 1.15)) - t["data"]["def"], 1)
		_damage_hero(t, dmg)
	var shrink := create_tween()
	shrink.tween_property(es, "scale", base, 0.3).set_trans(Tween.TRANS_QUAD)
	_undim(dim)
	await get_tree().create_timer(0.9).timeout

func _damage_hero(target: Dictionary, dmg: int) -> void:
	target["data"]["hp"] = maxi(target["data"]["hp"] - dmg, 0)
	_float_text(target["sprite"].position, str(dmg), Color(1.0, 0.45, 0.35))
	_shake(target["sprite"])
	_shake_camera()
	_refresh_party()
	if target["data"]["hp"] <= 0:
		var faint := create_tween()
		faint.tween_property(target["sprite"], "modulate", Color(0.4, 0.4, 0.55, 0.6), 0.4)
		faint.parallel().tween_property(target["sprite"], "rotation", -PI / 2, 0.4)

func _damage_enemy(e: Dictionary, dmg: int) -> void:
	e["hp"] -= dmg
	_float_text(e["sprite"].position + Vector2(0, -40 if e["is_boss"] else 0), str(dmg), Color(1, 1, 0.5))
	_shake(e["sprite"])
	_shake_camera(1.4 if e["is_boss"] else 1.0)
	if e["is_boss"]:
		_refresh_boss_bar(e)
	if e["hp"] <= 0:
		e["alive"] = false
		if e["is_boss"]:
			await _boss_death(e)
			return
		AudioManager.play_sfx("die")
		var s: Sprite2D = e["sprite"]
		_burst(s.position, Color(0.7, 0.6, 0.9), 14, 140)
		var tw := create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.45)
		tw.parallel().tween_property(s, "scale", s.scale * Vector2(1.3, 0.08), 0.45)
		await tw.finished
		(e["sprite"] as Sprite2D).visible = false
	else:
		# Wut-Phase: unter 40% LP wird der Boss schneller wütend und stärker.
		if e["is_boss"] and not e["enraged"] and e["hp"] < e["max_hp"] * 0.4:
			await _boss_enrage(e)
		await get_tree().create_timer(0.35).timeout

## Wut-Phase des Bosses: Aufschrei, Färbung, mehr Angriff (Farbe je Thema).
func _boss_enrage(e: Dictionary) -> void:
	var frost: bool = boss_def.get("theme", "bone") == "frost"
	e["enraged"] = true
	e["atk"] = int(e["atk"] * 1.35)
	AudioManager.play_sfx("charge")
	_say("%s tobt vor Wut!" % e["name"])
	var es: Sprite2D = e["sprite"]
	_flash_screen(Color(0.3, 0.7, 1.0, 0.35) if frost else Color(1.0, 0.1, 0.05, 0.35))
	_shake_camera(2.2)
	var rage_col := Color(0.5, 1.1, 1.7) if frost else Color(1.6, 0.5, 0.4)
	var tint := Color(0.85, 1.0, 1.2) if frost else Color(1.15, 0.85, 0.85)
	e["tint"] = tint
	var tw := create_tween()
	tw.tween_property(es, "modulate", rage_col, 0.3)
	tw.tween_property(es, "modulate", tint, 0.4)
	_burst(es.position, Color(0.3, 0.85, 1.0) if frost else Color(1.0, 0.2, 0.1), 22, 190)
	AudioManager.play_sfx("roar")
	await get_tree().create_timer(1.0).timeout

## Inszenierter Boss-Tod: Zeitlupe, Explosionskette, weißer Blitz, Zerfall.
func _boss_death(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	_say("%s bricht zusammen!" % e["name"])
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

func _shake(s: Sprite2D) -> void:
	var orig: Vector2 = s.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(s, "position:x", orig.x + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(s, "position:x", orig.x, 0.04)
	var flash := create_tween()
	flash.tween_property(s, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(s, "modulate", Color.WHITE, 0.15)
	# Kurzer Quetsch-Impuls verkauft die Wucht des Treffers.
	var base: Vector2 = s.scale
	var squash := create_tween()
	squash.tween_property(s, "scale", base * Vector2(1.12, 0.88), 0.06)
	squash.tween_property(s, "scale", base, 0.14) \
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
	l.scale = Vector2(0.3, 0.3)
	l.pivot_offset = Vector2(20, 20)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 44.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
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

## Partikel-Explosion mit Glut, Rauch und Lichtblitz. `power` skaliert die
## Wucht (1.0 = normal; >1 für große Feuerzauber → Stoßwelle, Glutregen).
func _explosion(pos: Vector2, power := 1.0) -> void:
	var flash := Sprite2D.new()
	flash.texture = SpriteFactory.circle(26, Color(1.0, 0.92, 0.66))
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flash.position = pos
	flash.scale = Vector2(0.3, 0.3)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = mat
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "scale", Vector2(2.4, 2.4) * power, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.parallel().tween_property(flash, "modulate:a", 0.0, 0.25 + 0.1 * (power - 1.0))
	ft.tween_callback(flash.queue_free)
	_burst(pos, Color(1.0, 0.55, 0.12), int(16 * power), 160 * power)
	_burst(pos, Color(1.0, 0.85, 0.4), int(10 * power), 120 * power)
	_burst(pos, Color(0.45, 0.40, 0.42, 0.6), int(8 * power), 60 * power)
	_impact_ring(pos, Color(1.0, 0.7, 0.3, 0.8))
	# Bei großen Explosionen eine zweite, verzögerte Stoßwelle + Glutregen.
	if power > 1.3:
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
	p.color = color
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
	# Drei schwere Stampfer
	for i in 3:
		AudioManager.play_sfx("stomp")
		_shake_camera(1.8)
		await get_tree().create_timer(0.42).timeout
	var frost: bool = boss_def.get("theme", "bone") == "frost"
	AudioManager.play_sfx("roar")
	_shake_camera(2.4)
	_flash_screen(Color(0.2, 0.6, 1.0, 0.35) if frost else Color(0.8, 0.1, 0.1, 0.35))
	var banner := Label.new()
	banner.text = "☠  %s  ☠" % boss_def["name"].to_upper()
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color",
		Color(0.55, 0.9, 1.0) if frost else Color(1.0, 0.85, 0.3))
	banner.add_theme_color_override("font_outline_color",
		Color(0.03, 0.10, 0.28) if frost else Color(0.3, 0.05, 0.05))
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
	_say(boss_def["entrance_line"])
	await get_tree().create_timer(1.6).timeout
	# Balken raus, Boss-HP-Leiste rein
	var out := create_tween().set_parallel(true)
	out.tween_property(bar_top, "position:y", -46.0, 0.3)
	out.tween_property(bar_bot, "position:y", 540.0, 0.3)
	out.chain().tween_callback(bar_top.queue_free)
	out.chain().tween_callback(bar_bot.queue_free)
	if boss_bar_holder != null:
		var bt := create_tween()
		bt.tween_property(boss_bar_holder, "modulate:a", 1.0, 0.5)

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

## ---------- Ende ----------

func _any_enemy_alive() -> bool:
	for e in enemies:
		if e["alive"]:
			return true
	return false

func _victory() -> void:
	var gold := 0
	var xp := 0
	for e in enemies:
		gold += e["gold"]
		xp += e.get("xp", 0)
	GameState.gold += gold
	var level_ups: Array = GameState.award_xp(xp)
	AudioManager.play_music("victory")
	_victory_banner()
	if not boss_def.is_empty():
		_say("%s ist besiegt!  %d Gold, %d EP!" % [boss_def["name"], gold, xp])
	else:
		_say("Sieg!  %d Gold und %d EP erbeutet!" % [gold, xp])
	# Münzregen über den Helden
	for i in 14:
		var coin := Sprite2D.new()
		coin.texture = SpriteFactory.circle(4, Color(1.0, 0.85, 0.25))
		coin.position = Vector2(randf_range(600, 820), randf_range(-40, 60))
		add_child(coin)
		var ct := create_tween()
		ct.tween_interval(randf_range(0.0, 0.5))
		ct.tween_property(coin, "position:y", 360.0, randf_range(0.5, 0.9)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ct.tween_property(coin, "modulate:a", 0.0, 0.25)
		ct.tween_callback(coin.queue_free)
	for h in heroes:
		if h["data"]["hp"] > 0:
			var s: Sprite2D = h["sprite"]
			var tw := create_tween()
			tw.tween_property(s, "position:y", s.position.y - 30.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "position:y", s.position.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.0).timeout
	# Stufenaufstiege feiern (heilt voll, LP/MP-Leisten aktualisieren).
	if not level_ups.is_empty():
		_refresh_party()
		for up in level_ups:
			AudioManager.play_sfx("heal")
			_say("%s erreicht Stufe %d!" % [up["name"], up["level"]])
			for h in heroes:
				if h["data"]["name"] == up["name"]:
					_sparkle(h["sprite"].position, Color(1.0, 0.92, 0.4))
					_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.45))
			await get_tree().create_timer(1.5).timeout
	# Boss-Siege schalten den Fortschritt frei.
	if enemy_ids.has("boss2"):
		GameState.boss2_defeated = true
	elif enemy_ids.has("boss"):
		GameState.boss_defeated = true
		GameState.apply_blessing()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(1.0, 0.9, 0.4))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.4))
		_say("Die Segnung des Königs durchströmt euch — ihr fühlt euch stärker!")
		await get_tree().create_timer(2.4).timeout
		_say("Im Nordosten birst krachend eine Barriere aus Eis ...")
		await get_tree().create_timer(2.2).timeout
	finished.emit(true)

## Großes „SIEG!“-Banner, das ins Bild ploppt.
func _victory_banner() -> void:
	var banner := Label.new()
	banner.text = "SIEG!"
	banner.add_theme_font_size_override("font_size", 64)
	banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	banner.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.0))
	banner.add_theme_constant_override("outline_size", 12)
	banner.custom_minimum_size = Vector2(960, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 130)
	banner.pivot_offset = Vector2(480, 40)
	banner.scale = Vector2(0.2, 0.2)
	banner.modulate.a = 0.0
	ui_layer.add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)

func _defeat() -> void:
	_say("Die Gruppe wurde besiegt ...")
	AudioManager.play_music("defeat")
	await get_tree().create_timer(2.5).timeout
	finished.emit(false)
