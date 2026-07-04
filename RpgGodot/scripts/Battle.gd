class_name Battle
extends Node2D
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Alle Animationen laufen über Tweens: Ausfallschritte, Treffer-Shake,
## Feuerball-Projektil, schwebende Schadenszahlen, Sieg-/Todeseffekte.

signal finished(victory: bool)
signal _choice_made

var enemy_ids: Array = []
var heroes := []   # {data, sprite, home, hp_label}
var enemies := []  # {name, hp, max_hp, atk, def, gold, sprite, home, alive}

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
	# Hintergrund: Höhlen-Verlauf mit Boden
	var bg := ColorRect.new()
	bg.size = Vector2(960, 540)
	bg.color = Color(0.10, 0.08, 0.16)
	add_child(bg)
	var floor_rect := ColorRect.new()
	floor_rect.position = Vector2(0, 340)
	floor_rect.size = Vector2(960, 200)
	floor_rect.color = Color(0.18, 0.15, 0.22)
	add_child(floor_rect)
	for i in 24:  # ein paar Steine als Dekor
		var stone := Sprite2D.new()
		stone.texture = SpriteFactory.circle(3 + (i % 4), Color(0.25, 0.22, 0.30))
		stone.position = Vector2(40 + i * 39.0, 350 + fmod(i * 61.3, 160.0))
		add_child(stone)

	# Alle Kämpfer starten außerhalb des Bildes und marschieren in _run_battle ein.
	for i in GameState.party.size():
		var data: Dictionary = GameState.party[i]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(data["id"], "side", 0)
		s.flip_h = true
		s.scale = Vector2(5, 5)
		var home := Vector2(700 + i * 40, 230 + i * 90)
		s.position = home + Vector2(340, 0)
		add_child(s)
		heroes.append({"data": data, "sprite": s, "home": home})

	for i in enemy_ids.size():
		var is_boss: bool = enemy_ids[i] == "boss"
		var def: Dictionary = GameState.ENEMIES[enemy_ids[i]]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.enemy(def["sprite"])
		s.scale = Vector2(7, 7) if is_boss else Vector2(5, 5)
		var home := Vector2(260, 250) if is_boss else Vector2(230 + (i % 2) * 90, 200 + i * 85)
		s.position = home - Vector2(400, 0)
		add_child(s)
		enemies.append({"name": def["name"], "hp": def["hp"], "max_hp": def["hp"],
			"atk": def["atk"], "def": def["def"], "gold": def["gold"],
			"sprite": s, "home": home, "alive": true, "is_boss": is_boss, "acts": 0})

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
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 410)
	panel.custom_minimum_size = Vector2(920, 115)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.94)
	style.border_color = Color(0.75, 0.7, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 40)
	panel.add_child(hb)
	menu_box = VBoxContainer.new()
	menu_box.custom_minimum_size = Vector2(280, 0)
	hb.add_child(menu_box)
	party_box = VBoxContainer.new()
	hb.add_child(party_box)
	for h in heroes:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		party_box.add_child(l)
		h["hp_label"] = l
	msg_label = Label.new()
	msg_label.position = Vector2(30, 20)
	msg_label.add_theme_font_size_override("font_size", 22)
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
	_refresh_party()

func _refresh_party() -> void:
	for h in heroes:
		var d: Dictionary = h["data"]
		h["hp_label"].text = "%-8s LP %3d/%3d   MP %2d/%2d" % \
			[d["name"], d["hp"], d["max_hp"], d["mp"], d["max_mp"]]
		h["hp_label"].add_theme_color_override("font_color",
			Color(1, 0.4, 0.4) if d["hp"] <= d["max_hp"] / 4 else Color.WHITE)

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
	cursor.visible = true
	cursor.position = (e["sprite"] as Sprite2D).position + Vector2(-70, -10)

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
	var tw := create_tween()
	tw.tween_property(s, "position", es.position + Vector2(60, 0), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	AudioManager.play_sfx("slash")
	_slash_arc(es.position)
	_sparks(es.position, Color(1.0, 0.9, 0.5))
	var dmg: int = int(h["data"]["atk"] * randf_range(0.9, 1.2)) - e["def"]
	await _damage_enemy(e, maxi(dmg, 1))
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished

func _whirl_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s entfesselt %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var tw := create_tween()
	tw.tween_property(s, "position", Vector2(420, 260), 0.25).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	AudioManager.play_sfx("whirl")
	var spin := create_tween()
	spin.tween_property(s, "rotation", TAU * 2, 0.5)
	spin.tween_callback(func(): s.rotation = 0.0)
	for e in enemies:
		if e["alive"]:
			_slash_arc(e["sprite"].position)
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
	# Feuerball-Projektil fliegt zum Ziel
	var ball := Sprite2D.new()
	ball.texture = SpriteFactory.circle(10, Color(1.0, 0.55, 0.15))
	ball.position = s.position + Vector2(-40, 0)
	add_child(ball)
	AudioManager.play_sfx("fire")
	var fly := create_tween()
	fly.tween_property(ball, "position", e["sprite"].position, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(ball, "scale", Vector2(1.8, 1.8), 0.4)
	await fly.finished
	ball.queue_free()
	_explosion(e["sprite"].position)
	AudioManager.play_sfx("boom")
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
	tw.tween_property(s, "position", es.position + Vector2(70, 0), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	for i in 3:
		AudioManager.play_sfx("slash")
		_slash_arc(es.position + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		_sparks(es.position, Color(1.0, 0.95, 0.6))
		await get_tree().create_timer(0.11).timeout
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
	windup.parallel().tween_property(es, "modulate", Color.WHITE, 0.12)
	await windup.finished
	if e["is_boss"] and e["acts"] % 3 == 0:
		await _boss_aoe(e, alive_heroes)
		return
	var target: Dictionary = alive_heroes[randi() % alive_heroes.size()]
	_say("%s greift %s an!" % [e["name"], target["data"]["name"]])
	var tw := create_tween()
	tw.tween_property(es, "position", target["sprite"].position + Vector2(-60, 0), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	AudioManager.play_sfx("hit")
	var dmg := maxi(int(e["atk"] * randf_range(0.85, 1.15)) - target["data"]["def"], 1)
	_damage_hero(target, dmg)
	var back := create_tween()
	back.tween_property(es, "position", e["home"], 0.25).set_trans(Tween.TRANS_QUAD)
	await back.finished
	await get_tree().create_timer(0.25).timeout

## Boss-Spezial: Knochensturm — trifft die ganze Gruppe, Bildschirm blitzt rot.
func _boss_aoe(e: Dictionary, targets: Array) -> void:
	_say("%s beschwört den Knochensturm!" % e["name"])
	AudioManager.play_sfx("roar")
	var es: Sprite2D = e["sprite"]
	var pump := create_tween()
	pump.tween_property(es, "scale", es.scale * 1.3, 0.35).set_trans(Tween.TRANS_QUAD)
	pump.tween_property(es, "scale", es.scale, 0.15)
	await pump.finished
	_flash_screen(Color(1.0, 0.15, 0.1, 0.45))
	AudioManager.play_sfx("boom")
	_shake_camera()
	for t in targets:
		var dmg := maxi(int(e["atk"] * randf_range(0.7, 0.9)) - t["data"]["def"], 1)
		_sparks(t["sprite"].position, Color(0.9, 0.4, 0.9))
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
	_float_text(e["sprite"].position, str(dmg), Color(1, 1, 0.5))
	_shake(e["sprite"])
	_shake_camera()
	if e["hp"] <= 0:
		e["alive"] = false
		AudioManager.play_sfx("die")
		var s: Sprite2D = e["sprite"]
		var tw := create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.45)
		tw.parallel().tween_property(s, "scale", s.scale * Vector2(1.3, 0.08), 0.45)
		await tw.finished
		(e["sprite"] as Sprite2D).visible = false
	else:
		await get_tree().create_timer(0.35).timeout

func _shake(s: Sprite2D) -> void:
	var orig: Vector2 = s.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(s, "position:x", orig.x + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(s, "position:x", orig.x, 0.04)
	var flash := create_tween()
	flash.tween_property(s, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(s, "modulate", Color.WHITE, 0.15)

func _shake_camera() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(cam, "offset", Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-14, -70)
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
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

func _explosion(pos: Vector2) -> void:
	for i in 10:
		var p := Sprite2D.new()
		p.texture = SpriteFactory.circle(5, Color(1.0, randf_range(0.3, 0.7), 0.1))
		p.position = pos
		add_child(p)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 80)
		var tw := create_tween()
		tw.tween_property(p, "position", pos + dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
		tw.tween_callback(p.queue_free)

## Kleine Funken, die bei Treffern nach außen spritzen.
func _sparks(pos: Vector2, color: Color) -> void:
	for i in 7:
		var p := Sprite2D.new()
		p.texture = SpriteFactory.circle(3, color)
		p.position = pos
		add_child(p)
		var dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(35, 90)
		var tw := create_tween()
		tw.tween_property(p, "position", pos + dir, 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)

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

## Boss-Auftritt: Brüllen, Kamerabeben, Namensbanner.
func _boss_entrance() -> void:
	AudioManager.play_sfx("roar")
	_shake_camera()
	_flash_screen(Color(0.8, 0.1, 0.1, 0.3))
	var banner := Label.new()
	banner.text = "☠  KNOCHENKÖNIG  ☠"
	banner.add_theme_font_size_override("font_size", 44)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	banner.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.05))
	banner.add_theme_constant_override("outline_size", 10)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(300, 140)
	banner.modulate.a = 0.0
	ui_layer.add_child(banner)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)
	_say("Der Herrscher der Finsterhöhle erhebt sich!")
	await get_tree().create_timer(1.4).timeout

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
