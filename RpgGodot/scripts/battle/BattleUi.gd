class_name BattleUi
extends BattleStage
## Kampf-UI: Partyleiste, Bossleiste, Auswahlmenues, Zielwahl, Item-Menue,
## Eingabe-Handling (_unhandled_input).
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

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
	# Menü in einem ScrollContainer: bei vielen Einträgen (z. B. Milos volle
	# Fähigkeitenliste) rollt der Ausschnitt mit, damit die Auswahl immer
	# sichtbar bleibt statt unten aus dem Panel zu laufen.
	menu_scroll_c = ScrollContainer.new()
	menu_scroll_c.custom_minimum_size = Vector2(300, 126)
	menu_scroll_c.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll_c.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Weder Rahmen noch Scrollbalken dürfen Tastatur-Fokus greifen — sonst
	# verschluckt der Scrollbalken die Hoch/Runter-Eingaben der Menüführung.
	menu_scroll_c.focus_mode = Control.FOCUS_NONE
	menu_scroll_c.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	hb.add_child(menu_scroll_c)
	menu_box = VBoxContainer.new()
	menu_box.custom_minimum_size = Vector2(280, 0)
	menu_scroll_c.add_child(menu_box)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 5)
	hb.add_child(party_box)
	for h in heroes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		party_box.add_child(row)
		# Porträt: Kopfausschnitt des Kampf-Sprites, gerahmt, blickt wie im
		# Kampf nach links.
		var pf := PanelContainer.new()
		var pstyle := StyleBoxFlat.new()
		pstyle.bg_color = Color(0.10, 0.10, 0.22)
		pstyle.border_color = Color(0.75, 0.7, 0.5)
		pstyle.set_border_width_all(2)
		pstyle.set_corner_radius_all(6)
		pstyle.set_content_margin_all(2)
		pf.add_theme_stylebox_override("panel", pstyle)
		row.add_child(pf)
		var port := TextureRect.new()
		var tex: Texture2D = SpriteFactory.hero_battle(h["data"]["id"])
		# DTII-Frames haben oben viel Transparenz — erst den tatsächlich
		# gefüllten Bereich ermitteln, dann dessen oberes Drittel als Kopf.
		var used: Rect2i = tex.get_image().get_used_rect()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(used.position.x, used.position.y,
			used.size.x, maxi(int(used.size.y * 0.62), 1))
		port.texture = at
		port.custom_minimum_size = Vector2(34, 34)
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.flip_h = true
		pf.add_child(port)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(col)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		col.add_child(l)
		h["hp_label"] = l
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 10)
		col.add_child(bars)
		h["hp_fill"] = _make_bar(bars, BAR_W, 10, Color(0.35, 0.95, 0.45))
		h["mp_fill"] = _make_bar(bars, 110, 10, Color(0.35, 0.55, 1.0), Color(0.65, 0.75, 1.0, 0.85))
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
## Dahinter liegt eine „Ghost"-Füllung, die Verluste verzögert nachzieht —
## der klassische Damage-Lag-Balken.
func _make_bar(parent: Control, w: int, h: int, color: Color,
		ghost_color := Color(1.0, 0.55, 0.4, 0.85)) -> ColorRect:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	parent.add_child(holder)
	var bg := ColorRect.new()
	bg.size = Vector2(w, h)
	bg.color = Color(0, 0, 0, 0.6)
	holder.add_child(bg)
	var ghost := ColorRect.new()
	ghost.position = Vector2(1, 1)
	ghost.size = Vector2(w - 2, h - 2)
	ghost.color = ghost_color
	holder.add_child(ghost)
	var fill := ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(w - 2, h - 2)
	fill.color = color
	holder.add_child(fill)
	fill.set_meta("ghost", ghost)
	return fill

## Große Boss-HP-Leiste oben in der Mitte (erscheint beim Auftritt).
func _build_boss_bar() -> void:
	boss_bar_holder = Control.new()
	boss_bar_holder.position = Vector2(270, 52)
	boss_bar_holder.modulate.a = 0.0
	ui_layer.add_child(boss_bar_holder)
	var st := _style()
	var name_l := Label.new()
	name_l.text = "☠  %s  ☠" % boss_def["name"].to_upper()
	name_l.position = Vector2(0, -30)
	name_l.custom_minimum_size = Vector2(420, 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", st["banner"])
	name_l.add_theme_color_override("font_outline_color", st["banner_outline"])
	name_l.add_theme_constant_override("outline_size", 6)
	boss_bar_holder.add_child(name_l)
	var bg := ColorRect.new()
	bg.size = Vector2(420, 16)
	bg.color = Color(0, 0, 0, 0.7)
	boss_bar_holder.add_child(bg)
	var border := ColorRect.new()
	border.size = Vector2(424, 20)
	border.position = Vector2(-2, -2)
	border.color = st["bar_border"]
	border.show_behind_parent = true
	bg.add_child(border)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.position = Vector2(1, 1)
	boss_bar_fill.size = Vector2(418, 14)
	boss_bar_fill.color = st["bar"]
	bg.add_child(boss_bar_fill)

func _refresh_party() -> void:
	for h in heroes:
		var d: Dictionary = h["data"]
		h["hp_label"].text = "%-7s Lv%2d  HP %3d/%3d  MP %2d/%2d" % \
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
		_lag_ghost(hp_fill, maxf((BAR_W - 2) * hp_ratio, 0.0))
		var mp_fill: ColorRect = h["mp_fill"]
		var mp_tw := mp_fill.create_tween()
		mp_tw.tween_property(mp_fill, "size:x", maxf(108.0 * d["mp"] / d["max_mp"], 0.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_lag_ghost(mp_fill, maxf(108.0 * d["mp"] / d["max_mp"], 0.0))

## Zieht die Ghost-Füllung eines Balkens mit Verzögerung nach.
func _lag_ghost(fill: ColorRect, target_w: float) -> void:
	var ghost: ColorRect = fill.get_meta("ghost")
	var tw := ghost.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(ghost, "size:x", target_w, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_boss_bar(e: Dictionary) -> void:
	if boss_bar_fill == null:
		return
	var ratio := clampf(float(e["hp"]) / e["max_hp"], 0.0, 1.0)
	var tw := boss_bar_fill.create_tween()
	tw.tween_property(boss_bar_fill, "size:x", 418.0 * ratio, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Auswahl-Einträge „Für <Name>" für alle Party-Mitglieder (beliebige Größe).
func _ally_entries() -> Array:
	var names := []
	for hh in heroes:
		names.append("For " + hh["data"]["name"])
	return names


func _menu(entries: Array, h: Dictionary, dim_indices: Array = []) -> int:
	_highlight_hero(h, true)
	current_menu = entries
	menu_dim = dim_indices
	# Vorauswahl ist immer die oberste AKTIVE (nicht gesperrte) Fähigkeit.
	menu_index = _first_selectable()
	ui_state = "menu"
	menu_scroll_c.scroll_vertical = 0
	_build_menu_rows()
	_refresh_menu_highlight()
	# Erst nach dem Layout der frisch erzeugten Labels lässt sich die
	# Scrollposition sauber setzen — sonst landet ensure_control_visible daneben
	# (der aktive Eintrag rutschte oben aus dem Rahmen). Zwei Frames warten,
	# dann den aktiven Eintrag exakt an den oberen Rand rollen.
	menu_box.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_active_to_top()
	var fade := menu_box.create_tween()
	fade.tween_property(menu_box, "modulate:a", 1.0, 0.15)
	await _choice_made
	_clear_menu()
	_highlight_hero(h, false)
	return choice

## Erster nicht gesperrter (aktiver) Menüeintrag — die Standard-Vorauswahl.
func _first_selectable() -> int:
	for i in current_menu.size():
		if not menu_dim.has(i):
			return i
	return 0

## Nächster aktiver Eintrag ab `from` in Richtung `delta` (überspringt gesperrte).
## Gibt `from` zurück, wenn in dieser Richtung nichts Aktives mehr kommt.
func _next_selectable(from: int, delta: int) -> int:
	var i := from + delta
	while i >= 0 and i < current_menu.size():
		if not menu_dim.has(i):
			return i
		i += delta
	return from

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

## Kampfbereitschaft: Wenn ein Held am Zug ist, tritt er einen Schritt vor,
## richtet sich auf und hebt die Waffe in Anschlag; danach entspannt er wieder.
## Umschließt den ganzen Zug (in _run_battle), damit es nicht bei jedem Untermenü
## zuckt. Nur Position:x/Scale/Waffenwinkel — Bob (position:y) bleibt unberührt.
## Verbrauchter Zug: die Figur wird leicht ausgegraut, bis die Runde herum ist.
## Gefallene bleiben unberührt — die haben ihre eigene Einfärbung.
func _set_spent(h: Dictionary, spent: bool) -> void:
	if h.is_empty() or not is_instance_valid(h["sprite"]):
		return
	if h["data"]["hp"] <= 0:
		return
	var s: Sprite2D = h["sprite"]
	var ziel := Color(0.40, 0.42, 0.50) if spent else Color.WHITE
	s.create_tween().tween_property(s, "modulate", ziel, 0.25) \
		.set_trans(Tween.TRANS_SINE)

func _ready_pose(h: Dictionary, on: bool) -> void:
	if h["data"]["hp"] <= 0:
		return
	var s: Sprite2D = h["sprite"]
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var wp: Sprite2D = h.get("weapon")
	var tw := create_tween()
	if on:
		tw.tween_property(s, "position:x", h["home"].x - 18.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "scale", base * Vector2(1.05, 1.05), 0.22) \
			.set_trans(Tween.TRANS_SINE)
		if wp != null and is_instance_valid(wp):
			var rest: float = wp.get_meta("rest", WEAPON_REST)
			wp.create_tween().tween_property(wp, "rotation", rest - 0.55, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(s, "position:x", h["home"].x, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(s, "scale", base, 0.2).set_trans(Tween.TRANS_SINE)
		if wp != null and is_instance_valid(wp):
			var rest: float = wp.get_meta("rest", WEAPON_REST)
			wp.create_tween().tween_property(wp, "rotation", rest, 0.2).set_trans(Tween.TRANS_SINE)

## Baut die Menü-Zeilen EINMAL beim Öffnen auf. (Bei jeder Navigation nur den
## Highlight ändern statt alles neu zu erzeugen — sonst geraten Layout und
## Auto-Scroll durcheinander, und man kann z. B. nicht mehr nach oben rollen.)
func _build_menu_rows() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	menu_rows = []
	for i in current_menu.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		menu_box.add_child(l)
		menu_rows.append(l)

## Aktualisiert nur Text/Farbe je Zeile (das Scrollen erledigen die Aufrufer).
func _refresh_menu_highlight() -> void:
	for i in menu_rows.size():
		var l: Label = menu_rows[i]
		l.text = ("> " if i == menu_index else "  ") + str(current_menu[i])
		var col := Color.WHITE if i == menu_index else Color(0.65, 0.65, 0.72)
		if menu_dim.has(i):
			# Gesperrte Einträge bleiben durchgängig gedämpft (nie vorgewählt).
			col = Color(0.42, 0.42, 0.5)
		l.add_theme_color_override("font_color", col)

## Rollt den aktiven Eintrag exakt an den OBEREN Rand (beim Öffnen des Menüs).
func _scroll_active_to_top() -> void:
	if not is_instance_valid(menu_scroll_c):
		return
	if menu_index < 0 or menu_index >= menu_rows.size():
		return
	var row: Control = menu_rows[menu_index]
	if is_instance_valid(row):
		menu_scroll_c.scroll_vertical = int(row.position.y)

## Rollt minimal, damit der aktive Eintrag sichtbar bleibt (bei Navigation).
func _scroll_keep_visible() -> void:
	if not is_instance_valid(menu_scroll_c):
		return
	if menu_index < 0 or menu_index >= menu_rows.size():
		return
	var row: Control = menu_rows[menu_index]
	if is_instance_valid(row):
		menu_scroll_c.ensure_control_visible(row)

func _clear_menu() -> void:
	ui_state = "none"
	for c in menu_box.get_children():
		c.queue_free()
	menu_rows = []
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
	_say("Choose a target (Z: OK, X: Back)")
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
		_say("No items!")
		AudioManager.play_sfx("error")
		return false
	var names := GameState.inventory.keys()
	var entries := []
	for n in names:
		entries.append("%s x%d" % [n, GameState.inventory[n]])
	entries.append("Back")
	var pick: int = await _menu(entries, h)
	if pick < 0 or pick >= names.size():
		return false
	var target: int = await _menu(_ally_entries(), h)
	if target < 0:  # B/X = Zurück
		return false
	var item_name: String = names[pick]
	var item: Dictionary = GameState.ITEMS[item_name]
	var td: Dictionary = heroes[target]["data"]
	GameState.use_item(item_name)
	td["hp"] = mini(td["hp"] + item["hp"], td["max_hp"])
	td["mp"] = mini(td["mp"] + item["mp"], td["max_mp"])
	# Falls das Item einen Gefallenen zurückholt: aufrappeln lassen.
	_restore_if_revived(heroes[target])
	AudioManager.play_sfx("heal")
	_sparkle(heroes[target]["sprite"].position, Color(0.4, 1.0, 0.5))
	_float_text(heroes[target]["sprite"].position, "+" + item_name, Color(0.5, 1.0, 0.6))
	_say("%s uses %s on %s." % [h["data"]["name"], item_name, td["name"]])
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
		elif event.is_action_pressed("cancel"):
			# B / X ist immer Zurück bzw. Überspringen.
			choice = -1
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
	var ni := _next_selectable(menu_index, delta)
	if ni == menu_index:
		return  # kein weiterer aktiver Eintrag in dieser Richtung
	menu_index = ni
	AudioManager.play_sfx("menu")
	_refresh_menu_highlight()
	_scroll_keep_visible()
