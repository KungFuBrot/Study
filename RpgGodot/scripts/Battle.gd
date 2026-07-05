class_name Battle
extends Node2D
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Moderner Look: Partikel-Effekte, Hit-Stop, Geister-Trails, Kamerabeben,
## HP-Leisten, animierter Höhlenhintergrund mit Fackeln und Nebel sowie
## ein inszenierter Boss-Kampf (Kino-Balken, Wut-Phase, dramatischer Tod).

signal finished(victory: bool)
signal _choice_made

const BAR_W := 170

var enemy_ids: Array = []
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
	_build_scene()
	_build_ui()
	_run_battle()

## ---------- Aufbau ----------

func _build_scene() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(480, 270)
	add_child(cam)
	cam.make_current()
	var has_boss := enemy_ids.has("boss")
	# Hintergrund: weicher Höhlen-Verlauf, bei Bosskämpfen bedrohlich rötlich.
	var bg := Sprite2D.new()
	bg.texture = SpriteFactory.gradient(8, 64,
		Color(0.16, 0.07, 0.12) if has_boss else Color(0.13, 0.11, 0.22),
		Color(0.05, 0.03, 0.07))
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
		stal.color = Color(0.09, 0.06, 0.13, 0.85)
		stal.position = Vector2(30 + i * 150.0, 360)
		stal.z_index = -15
		add_child(stal)
	# Boden mit Verlauf + Steine als Dekor
	var floor_s := Sprite2D.new()
	floor_s.texture = SpriteFactory.gradient(8, 32, Color(0.22, 0.18, 0.27), Color(0.10, 0.08, 0.14))
	floor_s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor_s.centered = false
	floor_s.position = Vector2(0, 340)
	floor_s.scale = Vector2(960.0 / 8, 200.0 / 32)
	floor_s.z_index = -12
	add_child(floor_s)
	for i in 24:
		var stone := Sprite2D.new()
		stone.texture = SpriteFactory.circle(3 + (i % 4), Color(0.28, 0.24, 0.34))
		stone.position = Vector2(40 + i * 39.0, 350 + fmod(i * 61.3, 160.0))
		stone.z_index = -11
		add_child(stone)
	_add_torch(Vector2(70, 160))
	_add_torch(Vector2(890, 160))
	_add_fog()

	# Alle Kämpfer starten außerhalb des Bildes und marschieren in _run_battle ein.
	for i in GameState.party.size():
		var data: Dictionary = GameState.party[i]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(data["id"], "side", 0)
		s.flip_h = true
		s.scale = Vector2(5, 5)
		var home := Vector2(700 + i * 40, 230 + i * 90)
		s.position = home + Vector2(340, 0)
		_attach_shadow(s, 9, 3, 8.5)
		add_child(s)
		heroes.append({"data": data, "sprite": s, "home": home})

	for i in enemy_ids.size():
		var is_boss: bool = enemy_ids[i] == "boss"
		var def: Dictionary = GameState.ENEMIES[enemy_ids[i]]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.enemy(def["sprite"])
		s.scale = Vector2(7, 7) if is_boss else Vector2(5, 5)
		var home := Vector2(215, 235) if is_boss else Vector2(230 + (i % 2) * 90, 200 + i * 85)
		s.position = home - Vector2(500, 0)
		if is_boss:
			_attach_shadow(s, 13, 3, 18.5)
			_attach_boss_aura(s)
		else:
			_attach_shadow(s, 9, 3, 7.0)
		add_child(s)
		enemies.append({"name": def["name"], "hp": def["hp"], "max_hp": def["hp"],
			"atk": def["atk"], "def": def["def"], "gold": def["gold"],
			"sprite": s, "home": home, "alive": true, "is_boss": is_boss,
			"acts": 0, "enraged": false})

## Weicher Schatten unter einem Kämpfer (als Kind, skaliert also mit).
func _attach_shadow(s: Sprite2D, rx: int, ry: int, foot_y: float) -> void:
	var sh := Sprite2D.new()
	sh.texture = SpriteFactory.shadow(rx, ry)
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sh.position = Vector2(0, foot_y)
	sh.z_index = -1
	sh.show_behind_parent = true
	s.add_child(sh)

## Dunkelrote Aura + pulsierendes Glühen hinter dem Boss.
func _attach_boss_aura(s: Sprite2D) -> void:
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(40, Color(1.0, 0.15, 0.05, 0.30))
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
	ember.color = Color(1.0, 0.25, 0.08, 0.8)
	ember.texture = SpriteFactory.circle(3, Color.WHITE)
	s.add_child(ember)

## Fackel: flackerndes Licht + aufsteigende Glut.
func _add_torch(pos: Vector2) -> void:
	var pole := ColorRect.new()
	pole.size = Vector2(8, 46)
	pole.position = pos + Vector2(-4, -6)
	pole.color = Color(0.28, 0.18, 0.10)
	pole.z_index = -10
	add_child(pole)
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(30, Color(1.0, 0.55, 0.15, 0.35))
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
	flame.color = Color(1.0, 0.6, 0.15, 0.9)
	flame.texture = SpriteFactory.circle(3, Color.WHITE)
	flame.z_index = -8
	add_child(flame)

## Träge dahinziehende Nebelschwaden geben dem Bild Tiefe.
func _add_fog() -> void:
	for i in 4:
		var fog := Sprite2D.new()
		fog.texture = SpriteFactory.circle(60, Color(0.55, 0.50, 0.75, 0.07))
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

func _idle_bob(s: Sprite2D, period: float) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(s, "position:y", s.position.y - 4.0, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s, "position:y", s.position.y, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer
	# Vignette für den Kino-Look
	var vig := TextureRect.new()
	vig.texture = SpriteFactory.vignette(240, 135)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 410)
	panel.custom_minimum_size = Vector2(920, 115)
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
		l.add_theme_font_size_override("font_size", 17)
		row.add_child(l)
		h["hp_label"] = l
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 10)
		row.add_child(bars)
		h["hp_fill"] = _make_bar(bars, BAR_W, 10, Color(0.35, 0.95, 0.45))
		h["mp_fill"] = _make_bar(bars, 110, 10, Color(0.35, 0.55, 1.0))
	msg_label = Label.new()
	msg_label.position = Vector2(30, 18)
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
	if enemy_ids.has("boss"):
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
	var name_l := Label.new()
	name_l.text = "☠  KNOCHENKÖNIG  ☠"
	name_l.position = Vector2(0, -30)
	name_l.custom_minimum_size = Vector2(420, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_l.add_theme_color_override("font_outline_color", Color(0.25, 0.03, 0.03))
	name_l.add_theme_constant_override("outline_size", 6)
	boss_bar_holder.add_child(name_l)
	var bg := ColorRect.new()
	bg.size = Vector2(420, 16)
	bg.color = Color(0, 0, 0, 0.7)
	boss_bar_holder.add_child(bg)
	var border := ColorRect.new()
	border.size = Vector2(424, 20)
	border.position = Vector2(-2, -2)
	border.color = Color(0.6, 0.15, 0.1)
	border.show_behind_parent = true
	bg.add_child(border)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.position = Vector2(1, 1)
	boss_bar_fill.size = Vector2(418, 14)
	boss_bar_fill.color = Color(0.9, 0.2, 0.15)
	bg.add_child(boss_bar_fill)

func _refresh_party() -> void:
	for h in heroes:
		var d: Dictionary = h["data"]
		h["hp_label"].text = "%-8s LP %3d/%3d   MP %2d/%2d" % \
			[d["name"], d["hp"], d["max_hp"], d["mp"], d["max_mp"]]
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
	# Einmarsch: alle gleiten an ihre Position, dann beginnt das Idle-Wippen.
	await get_tree().create_timer(0.15).timeout
	var intro := create_tween().set_parallel(true)
	for u in heroes + enemies:
		intro.tween_property(u["sprite"], "position", u["home"], 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await intro.finished
	for i in heroes.size():
		_idle_bob(heroes[i]["sprite"], 2.0 + i * 0.3)
	for i in enemies.size():
		_idle_bob(enemies[i]["sprite"], 1.6 + i * 0.25)
	if enemy_ids.has("boss"):
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

## Untermenü: eine der Fähigkeiten des Helden wählen und ausführen.
func _ability_menu(h: Dictionary) -> bool:
	var d: Dictionary = h["data"]
	var abilities: Array = d["abilities"]
	var entries := []
	for ab in abilities:
		entries.append("%s (%d MP) — %s" % [ab["name"], ab["cost"], ab["desc"]])
	entries.append("Zurück")
	var pick: int = await _menu(entries, h)
	if pick >= abilities.size():
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
			await _whirl_all(h, ab)
		"one":
			var t: int = await _pick_enemy()
			if t < 0: return false
			d["mp"] -= ab["cost"]
			_refresh_party()
			if ab["kind"] == "magic":
				await _fireball(h, ab, enemies[t])
			else:
				await _pierce(h, ab, enemies[t])
		"ally":
			var a: int = await _menu(["Für Serena", "Für Milo"], h)
			d["mp"] -= ab["cost"]
			_refresh_party()
			await _heal_ally(h, ab, heroes[a])
	return true

## ---------- Menüs (await auf Spieler-Eingabe) ----------

func _menu(entries: Array, h: Dictionary) -> int:
	_highlight_hero(h, true)
	current_menu = entries
	menu_index = 0
	ui_state = "menu"
	_redraw_menu()
	await _choice_made
	_clear_menu()
	_highlight_hero(h, false)
	return choice

func _highlight_hero(h: Dictionary, on: bool) -> void:
	(h["sprite"] as Sprite2D).modulate = Color(1.3, 1.3, 1.0) if on else Color.WHITE

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
	var target: int = await _menu(["Für Serena", "Für Milo"], h)
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
	var strike_pos: Vector2 = es.position + Vector2(_strike_offset(e), 0)
	var tw := create_tween()
	tw.tween_property(s, "position", strike_pos, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(s, 0.22)
	await tw.finished
	AudioManager.play_sfx("slash")
	_slash_arc(es.position)
	_burst(es.position, Color(1.0, 0.9, 0.5), 10, 120)
	_impact_ring(es.position, Color(1, 1, 1, 0.7))
	await _hitstop(0.06)
	var dmg: int = int(h["data"]["atk"] * randf_range(0.9, 1.2)) - e["def"]
	await _damage_enemy(e, maxi(dmg, 1))
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

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
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 14.0, 0.2)
	await raise.finished
	# Feuerball mit glühendem Kern und Funkenschweif fliegt zum Ziel
	var ball := Sprite2D.new()
	ball.texture = SpriteFactory.circle(10, Color(1.0, 0.55, 0.15))
	ball.position = s.position + Vector2(-40, 0)
	var core := Sprite2D.new()
	core.texture = SpriteFactory.circle(5, Color(1.0, 0.95, 0.6))
	ball.add_child(core)
	var trail := CPUParticles2D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.direction = Vector2(1, 0)
	trail.spread = 25.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 30.0
	trail.initial_velocity_max = 70.0
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	trail.color = Color(1.0, 0.5, 0.1, 0.8)
	trail.texture = SpriteFactory.circle(4, Color.WHITE)
	ball.add_child(trail)
	add_child(ball)
	AudioManager.play_sfx("fire")
	var fly := create_tween()
	fly.tween_property(ball, "position", e["sprite"].position, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(ball, "scale", Vector2(1.8, 1.8), 0.4)
	await fly.finished
	ball.queue_free()
	_explosion(e["sprite"].position)
	_flash_screen(Color(1.0, 0.6, 0.2, 0.20))
	AudioManager.play_sfx("boom")
	await _hitstop(0.07)
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
	await _hitstop(0.06)
	var dmg: int = int((ab["power"] + d["atk"]) * randf_range(0.95, 1.15))
	await _damage_enemy(e, maxi(dmg, 1))
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

## Heillicht: grüner Lichtring + Funken, heilt einen Verbündeten.
func _heal_ally(h: Dictionary, ab: Dictionary, target: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var td: Dictionary = target["data"]
	_say("%s wirkt %s auf %s!" % [d["name"], ab["name"], td["name"]])
	var s: Sprite2D = h["sprite"]
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
	# Kurzes Aufladen (Anspannen + rote Färbung) vor jeder Gegner-Aktion.
	var es: Sprite2D = e["sprite"]
	var base_scale: Vector2 = es.scale
	var windup := create_tween()
	windup.tween_property(es, "scale", base_scale * 1.15, 0.16)
	windup.parallel().tween_property(es, "modulate", Color(1.3, 0.8, 0.8), 0.16)
	windup.tween_property(es, "scale", base_scale, 0.12)
	windup.parallel().tween_property(es, "modulate",
		Color(1.15, 0.85, 0.85) if e["enraged"] else Color.WHITE, 0.12)
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
	_burst(target["sprite"].position, Color(1.0, 0.4, 0.3), 8, 110)
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.15)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	var back := create_tween()
	back.tween_property(es, "position", e["home"], 0.25).set_trans(Tween.TRANS_QUAD)
	await back.finished
	await get_tree().create_timer(0.25).timeout

## Boss-Spezial: Knochensturm — Knochenhagel prasselt auf die ganze Gruppe.
func _boss_aoe(e: Dictionary, targets: Array) -> void:
	_say("%s beschwört den Knochensturm!" % e["name"])
	AudioManager.play_sfx("roar")
	var es: Sprite2D = e["sprite"]
	var pump := create_tween()
	pump.tween_property(es, "scale", es.scale * 1.25, 0.35).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", es.scale, 0.15)
	await pump.finished
	_flash_screen(Color(1.0, 0.15, 0.1, 0.40))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.0)
	# Knochenhagel über den Helden
	for i in 12:
		var b := Sprite2D.new()
		b.texture = SpriteFactory.bone()
		b.scale = Vector2(3, 3)
		b.rotation = randf() * TAU
		b.position = Vector2(randf_range(600, 860), -30)
		add_child(b)
		var fall := create_tween()
		fall.tween_interval(randf_range(0.0, 0.35))
		fall.tween_property(b, "position:y", randf_range(240, 360), randf_range(0.30, 0.5)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(b, "rotation", b.rotation + randf_range(-6.0, 6.0), 0.5)
		fall.tween_callback(func():
			_burst(b.position, Color(0.9, 0.88, 0.8), 5, 80)
			b.queue_free())
	await get_tree().create_timer(0.55).timeout
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.7, 0.9)) - t["data"]["def"], 1)
		_burst(t["sprite"].position, Color(0.9, 0.4, 0.9), 8, 110)
		_damage_hero(t, dmg)
	await get_tree().create_timer(0.7).timeout

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

## Wut-Phase des Bosses: rote Färbung, Aufschrei, mehr Angriff.
func _boss_enrage(e: Dictionary) -> void:
	e["enraged"] = true
	e["atk"] = int(e["atk"] * 1.35)
	AudioManager.play_sfx("charge")
	_say("Der Knochenkönig tobt vor Wut!")
	var es: Sprite2D = e["sprite"]
	_flash_screen(Color(1.0, 0.1, 0.05, 0.35))
	_shake_camera(2.2)
	var tw := create_tween()
	tw.tween_property(es, "modulate", Color(1.6, 0.5, 0.4), 0.3)
	tw.tween_property(es, "modulate", Color(1.15, 0.85, 0.85), 0.4)
	_burst(es.position, Color(1.0, 0.2, 0.1), 22, 190)
	AudioManager.play_sfx("roar")
	await get_tree().create_timer(1.0).timeout

## Inszenierter Boss-Tod: Zeitlupe, Explosionskette, weißer Blitz, Zerfall.
func _boss_death(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	_say("Der Knochenkönig bricht zusammen!")
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

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-14, -70)
	l.add_theme_font_size_override("font_size", 30)
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

## Partikel-Explosion mit Glut, Rauch und Lichtblitz.
func _explosion(pos: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.texture = SpriteFactory.circle(26, Color(1.0, 0.9, 0.6))
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	flash.position = pos
	flash.scale = Vector2(0.3, 0.3)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = mat
	add_child(flash)
	var ft := create_tween()
	ft.tween_property(flash, "scale", Vector2(2.4, 2.4), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.parallel().tween_property(flash, "modulate:a", 0.0, 0.25)
	ft.tween_callback(flash.queue_free)
	_burst(pos, Color(1.0, 0.55, 0.12), 16, 160)
	_burst(pos, Color(0.45, 0.40, 0.42, 0.6), 8, 60)
	_impact_ring(pos, Color(1.0, 0.7, 0.3, 0.8))

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
	AudioManager.play_sfx("roar")
	_shake_camera(2.4)
	_flash_screen(Color(0.8, 0.1, 0.1, 0.35))
	var banner := Label.new()
	banner.text = "☠  KNOCHENKÖNIG  ☠"
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	banner.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.05))
	banner.add_theme_constant_override("outline_size", 12)
	banner.position = Vector2(230, 150)
	banner.pivot_offset = Vector2(250, 30)
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
	_say("Der Herrscher der Finsterhöhle erhebt sich!")
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
	for e in enemies:
		gold += e["gold"]
	GameState.gold += gold
	AudioManager.play_music("victory")
	if enemy_ids.has("boss"):
		GameState.boss_defeated = true
		_say("Der Knochenkönig ist besiegt!  %d Gold erbeutet!" % gold)
	else:
		_say("Sieg!  %d Gold erbeutet!" % gold)
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
	await get_tree().create_timer(2.2).timeout
	finished.emit(true)

func _defeat() -> void:
	_say("Die Gruppe wurde besiegt ...")
	AudioManager.play_music("defeat")
	await get_tree().create_timer(2.5).timeout
	finished.emit(false)
