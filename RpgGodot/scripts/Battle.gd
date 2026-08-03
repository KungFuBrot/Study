class_name Battle
extends BattleEnemyActions
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Diese Datei enthaelt den Ablauf: _ready, Rundenschleife, Heldenzug,
## Faehigkeiten-Menue, Sieg/Niederlage sowie die Screenshot-Showcases.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

func _ready() -> void:
	for id in enemy_ids:
		if GameState.ENEMIES[id].get("boss", false):
			boss_def = GameState.ENEMIES[id]
	_build_scene()
	_build_ui()
	if OS.get_environment("SPELLSHOT") != "":
		_spell_showcase()
	elif OS.get_environment("BOSSSHOT") != "":
		_boss_showcase()
	elif OS.get_environment("MENUSHOT") != "":
		_menu_showcase()
	else:
		_run_battle()

## Debug: öffnet Milos volle Fähigkeitenliste (mit gesperrten Einträgen) und
## fährt sie per Tastatur rauf und runter — prüft Auto-Scroll + Überspringen
## gesperrter Einträge. env MENUSHOT=Zielordner.
func _menu_showcase() -> void:
	var dir := OS.get_environment("MENUSHOT")
	for i in heroes.size():
		heroes[i]["bob"] = _idle_bob(heroes[i]["sprite"], 2.0)
	# Milo hat die längste Liste (5? bzw. 2 aktiv + 3 gesperrte Summons + Ult + Zurück).
	_ability_menu(heroes[1])  # bewusst NICHT awaiten: öffnet das Menü und wartet
	await get_tree().create_timer(0.35).timeout
	_snap(dir, "menu_top")
	for i in 7:
		_menu_move(1)
		await get_tree().create_timer(0.16).timeout
		_snap(dir, "menu_down_%d" % i)
	for i in 7:
		_menu_move(-1)
		await get_tree().create_timer(0.16).timeout
		_snap(dir, "menu_up_%d" % i)
	get_tree().quit()

## Debug: spielt AoE + Ultimate des aktuellen Bosses ab und macht Screenshots
## (env BOSSSHOT=Zielordner). Nur zum visuellen Prüfen, kein Spielinhalt.
func _boss_showcase() -> void:
	var dir := OS.get_environment("BOSSSHOT")
	var suffix: String = boss_def.get("theme", "x")
	for u in heroes + enemies:
		(u["sprite"] as Sprite2D).position = u["home"]
	for i in heroes.size():
		heroes[i]["bob"] = _idle_bob(heroes[i]["sprite"], 2.0)
	_start_idle_animations()
	for h in heroes:
		h["data"]["hp"] = 999
		h["data"]["max_hp"] = 999
	var e: Dictionary = enemies[0]
	await get_tree().create_timer(0.8).timeout
	_snap(dir, "boss_idle_" + suffix)
	# Leerlauf-Gesten prüfen: Boss schnaubt, ein Held reckt/wirbelt.
	_boss_snort(e)
	_hero_antic(heroes[0])
	_hero_antic(heroes[2])
	await get_tree().create_timer(0.35).timeout
	_snap(dir, "boss_antic_" + suffix)
	await get_tree().create_timer(1.0).timeout
	await _boss_aoe(e, heroes)
	_snap(dir, "boss_aoe_" + suffix)
	await get_tree().create_timer(0.5).timeout
	e["hp"] = int(e["max_hp"] * 0.3)
	await _boss_enrage(e)
	await _boss_ultimate(e, heroes, 0)
	_snap(dir, "boss_ult_" + suffix)
	await get_tree().create_timer(1.0).timeout
	await _boss_ultimate(e, heroes, 1)
	_snap(dir, "boss_ult2_" + suffix)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

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
	# Kampfbereitschaft (Vortreten + Waffe in Anschlag) einfangen
	_ready_pose(heroes[0], true)
	await get_tree().create_timer(0.35).timeout
	_snap(dir, "show_ready")
	_ready_pose(heroes[0], false)
	_highlight_hero(heroes[2], false)
	# Serena Normalangriff (Ausholen + Waffenschwung einfangen)
	_hero_attack(heroes[0], enemies[2])
	await get_tree().create_timer(0.42).timeout
	_snap(dir, "show_attack")
	await get_tree().create_timer(1.2).timeout
	# Serena Sturmschnitt (einzelner Iaido-Durchzug)
	_storm_cut(heroes[0], heroes[0]["data"]["abilities"][1], enemies[1])
	await get_tree().create_timer(0.55).timeout
	_snap(dir, "show_stormcut")
	await get_tree().create_timer(1.1).timeout
	# Serena Fokusstoß (Durchstöße + Kreuzschnitt)
	_pierce(heroes[0], heroes[0]["data"]["abilities"][2], enemies[1])
	await get_tree().create_timer(1.25).timeout
	_snap(dir, "show_pierce_1")
	await get_tree().create_timer(0.5).timeout
	_snap(dir, "show_pierce_2")
	await get_tree().create_timer(1.3).timeout
	# Serena Klingentanz (Sternschritte + Fallstreich)
	_blade_dance(heroes[0], heroes[0]["data"]["abilities"][3], enemies[1])
	await get_tree().create_timer(1.6).timeout
	_snap(dir, "show_dance_1")
	await get_tree().create_timer(1.15).timeout
	_snap(dir, "show_dance_2")
	await get_tree().create_timer(1.0).timeout
	# Serena Klingensturm (wandernder Klingen-Tornado über allen Gegnern)
	_blade_storm(heroes[0], heroes[0]["data"]["abilities"][4])
	await get_tree().create_timer(0.9).timeout
	_snap(dir, "show_bladestorm")
	await get_tree().create_timer(1.6).timeout
	# Milo Feuerball (Explosion einfangen)
	_fireball(heroes[1], heroes[1]["data"]["abilities"][0], enemies[0])
	await get_tree().create_timer(1.85).timeout
	_snap(dir, "show_fireball")
	await get_tree().create_timer(1.2).timeout
	# Rax Standardangriff: Maschinengewehrfeuer auf einen Gegner
	_rax_gun(heroes[2], enemies[1])
	await get_tree().create_timer(0.9).timeout
	_snap(dir, "show_mgun")
	await get_tree().create_timer(1.6).timeout
	# Rax Reparatur (Naniten + Tech-Ring, heilt Milo)
	_repair_ally(heroes[2], heroes[2]["data"]["abilities"][1], heroes[1])
	await get_tree().create_timer(0.85).timeout
	_snap(dir, "show_repair")
	await get_tree().create_timer(1.2).timeout
	# Rax Laser
	_laser(heroes[2], heroes[2]["data"]["abilities"][0], enemies[1])
	await get_tree().create_timer(0.55).timeout
	_snap(dir, "show_laser")
	await get_tree().create_timer(1.2).timeout
	# Rax Plasmalanze (fliegender Plasmaspeer)
	_plasma_lance(heroes[2], heroes[2]["data"]["abilities"][4], enemies[1])
	await get_tree().create_timer(0.65).timeout
	_snap(dir, "show_lance")
	await get_tree().create_timer(1.2).timeout
	# Rax Raketensalve
	_rocket_all(heroes[2], heroes[2]["data"]["abilities"][2])
	await get_tree().create_timer(1.55).timeout
	_snap(dir, "show_rockets")
	await get_tree().create_timer(2.0).timeout
	# Rax Ultimate: Orbitallaser (Fadenkreuze -> liegende 8 mit Bodenflammen)
	_ultimate_rax(heroes[2])
	await get_tree().create_timer(1.8).timeout
	_snap(dir, "show_orbit_cross")
	await get_tree().create_timer(1.9).timeout
	_snap(dir, "show_orbit_beam")
	await get_tree().create_timer(2.4).timeout
	# Milos Beschwörungen (Level freischalten, MP auffüllen)
	heroes[1]["data"]["level"] = 5
	heroes[1]["data"]["mp"] = 99
	var summons: Array = heroes[1]["data"]["summons"]
	_summon_ifrit(heroes[1], summons[0])
	await get_tree().create_timer(2.2).timeout
	_snap(dir, "show_ifrit_1")
	await get_tree().create_timer(0.6).timeout
	_snap(dir, "show_ifrit_2")
	await get_tree().create_timer(3.0).timeout
	heroes[1]["data"]["mp"] = 99
	_summon_leviathan(heroes[1], summons[1])
	await get_tree().create_timer(3.0).timeout
	_snap(dir, "show_leviathan_1")
	await get_tree().create_timer(1.35).timeout
	_snap(dir, "show_leviathan_2")
	await get_tree().create_timer(1.0).timeout
	_snap(dir, "show_leviathan_3")
	await get_tree().create_timer(2.5).timeout
	# Milo Bahamut (Drachenkönig + Megaflare)
	heroes[1]["data"]["mp"] = 99
	_summon_bahamut(heroes[1], summons[2])
	await get_tree().create_timer(3.4).timeout
	_snap(dir, "show_bahamut_1")
	await get_tree().create_timer(1.2).timeout
	_snap(dir, "show_bahamut_2")
	await get_tree().create_timer(2.5).timeout
	# Milo Meteorregen (Gesteinsbrocken über dem ganzen Feld)
	_meteor_rain(heroes[1], heroes[1]["data"]["abilities"][2])
	await get_tree().create_timer(2.1).timeout
	_snap(dir, "show_meteor_1")
	await get_tree().create_timer(0.6).timeout
	_snap(dir, "show_meteor_2")
	await get_tree().create_timer(2.4).timeout
	# Übungsgegner wiederbeleben, damit die Nuke Ziele hat
	for e in enemies:
		e["alive"] = true
		e["hp"] = 999
		var esp: Sprite2D = e["sprite"]
		esp.visible = true
		esp.material = null
		esp.modulate = Color.WHITE
	# Rax Nuke zuletzt — sie reißt vermutlich alle Übungsgegner um.
	_nuke(heroes[2], heroes[2]["data"]["abilities"][3])
	await get_tree().create_timer(1.3).timeout
	_snap(dir, "show_nuke_1")
	await get_tree().create_timer(0.75).timeout
	_snap(dir, "show_nuke_2")
	await get_tree().create_timer(1.8).timeout
	# Monster-Spezialattacken: alle 4 Arten am wiederbelebten Übungsgegner prüfen.
	for h in heroes:
		h["data"]["hp"] = 999
		h["data"]["max_hp"] = 999
	var se: Dictionary = enemies[0]
	se["alive"] = true
	se["hp"] = 999
	se["max_hp"] = 999
	var ses: Sprite2D = se["sprite"]
	ses.visible = true
	ses.material = null
	ses.modulate = se.get("tint", Color.WHITE)
	ses.position = se["home"]
	var kinds := [["Sludge Flood", "barrage"], ["Blind Fury", "frenzy"],
		["Scrap Avalanche", "slam"], ["Soul Siphon", "drain"]]
	for i in kinds.size():
		se["special"] = {"name": kinds[i][0], "kind": kinds[i][1]}
		await _enemy_special(se, heroes)
		_snap(dir, "show_special_%s" % kinds[i][1])
		await get_tree().create_timer(0.4).timeout
	get_tree().quit()

func _snap(dir: String, shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + shot_name + ".png")

func _run_battle() -> void:
	# Gestaffelter Einmarsch: alle gleiten nacheinander eingeblendet an ihre
	# Position, dann beginnt das Idle-Wippen.
	await get_tree().create_timer(0.15).timeout
	var units: Array = heroes + enemies
	for i in units.size():
		var u: Dictionary = units[i]
		var s: Sprite2D = u["sprite"]
		s.modulate.a = 0.0
		# Der Boss marschiert nicht ein — er bekommt seinen großen Auftritt.
		if u.get("is_boss", false):
			s.position = u["home"]
			continue
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_property(s, "position", u["home"], 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(0.55 + units.size() * 0.09).timeout
	for i in heroes.size():
		heroes[i]["bob"] = _idle_bob(heroes[i]["sprite"], 2.0 + i * 0.3)
	for i in enemies.size():
		if not enemies[i]["is_boss"]:
			enemies[i]["bob"] = _idle_bob(enemies[i]["sprite"], 1.6 + i * 0.25)
	_start_idle_animations()
	_start_idle_antics()
	_camera_idle()
	if not boss_def.is_empty():
		await _boss_entrance()
	else:
		_say("Monsters attack!")
	await get_tree().create_timer(0.9).timeout
	while true:
		for h in heroes:
			if h["data"]["hp"] <= 0 or not _any_enemy_alive():
				continue
			_ready_pose(h, true)
			var fled: bool = await _hero_turn(h)
			_ready_pose(h, false)
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
	# Zu Beginn des eigenen Zuges verfällt die Deckung des letzten Zuges.
	_end_defend(h)
	while true:
		var cmd: int = await _menu([d["name"] + ":  Attack", "Ability",
			"Defend", "Item", "Flee"], h)
		match cmd:
			0:
				var t := await _pick_enemy()
				if t < 0: continue
				_pause_bob(h)
				# Rax feuert statt eines Nahkampfschlags sein MG auf das Ziel.
				if h["data"]["id"] == "rax":
					await _rax_gun(h, enemies[t])
				else:
					await _hero_attack(h, enemies[t])
				_resume_bob(h, 2.0)
				return false
			1:
				var used_ab: bool = await _ability_menu(h)
				if used_ab: return false
			2:
				await _defend(h)
				return false
			3:
				var used: bool = await _item_menu(h)
				if used: return false
			4:
				_say("Trying to flee ...")
				await get_tree().create_timer(0.6).timeout
				if randf() < 0.6:
					_say("Got away safely!")
					AudioManager.play_sfx("flee")
					await get_tree().create_timer(0.8).timeout
					return true
				_say("Couldn't escape!")
				await get_tree().create_timer(0.7).timeout
				return false
	return false

## Verteidigen: Der Held greift diesen Zug nicht an, geht in Deckung und nimmt
## bis zum nächsten eigenen Zug deutlich weniger Schaden. Ein schimmerndes
## Schild bleibt als Anzeige vor ihm stehen.
func _defend(h: Dictionary) -> void:
	h["defending"] = true
	# Deckungspose hält bis zum nächsten eigenen Zug.
	_pose(h, "block", 6.0)
	_say("%s takes cover — the next hit will be softened." % h["data"]["name"])
	AudioManager.play_sfx("charge")
	var s: Sprite2D = h["sprite"]
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	# Kurze Brems-/Duck-Pose: leicht zurück, breiter Stand.
	var tw := create_tween()
	tw.tween_property(s, "scale", base * Vector2(1.1, 0.9), 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "scale", base, 0.2).set_trans(Tween.TRANS_SINE)
	# Schild vor dem Helden (zur Gegnerseite = links) — additives Wappenschild.
	_end_defend_node(h)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shield := Node2D.new()
	var pts := PackedVector2Array([Vector2(-11, -14), Vector2(11, -14),
		Vector2(11, 4), Vector2(0, 16), Vector2(-11, 4)])
	var body := Polygon2D.new()
	body.polygon = pts
	body.color = Color(0.35, 0.65, 1.0, 0.45)
	shield.add_child(body)
	var edge := Line2D.new()
	edge.points = pts
	edge.closed = true
	edge.width = 2.0
	edge.default_color = Color(0.75, 0.9, 1.0)
	shield.add_child(edge)
	shield.material = mat
	shield.scale = Vector2(2.3, 2.3)
	shield.modulate = Color(1, 1, 1, 0.0)
	var fh := s.texture.get_height() * s.scale.y * 0.5
	shield.position = s.position + Vector2(-fh * 0.55, -fh * 0.3)
	shield.z_index = 3
	add_child(shield)
	h["guard"] = shield
	var st := shield.create_tween().set_loops()
	st.tween_property(shield, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
	st.tween_property(shield, "modulate:a", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
	_burst(shield.position, Color(0.6, 0.85, 1.0), 10, 90)
	await get_tree().create_timer(0.6).timeout

## Untermenü: Fähigkeiten, Beschwörungen (Milo) oder die Ultimative wählen.
func _ability_menu(h: Dictionary) -> bool:
	var d: Dictionary = h["data"]
	var abilities: Array = d["abilities"]
	var summons: Array = d.get("summons", [])
	var ult: Dictionary = d.get("ultimate", {})
	var has_ult: bool = not ult.is_empty()
	var entries := []
	var dim := []
	for ab in abilities:
		if not GameState.skill_unlocked(d, ab):
			dim.append(entries.size())
			entries.append("%s — %s" % [ab["name"], GameState.skill_lock_hint(d, ab)])
		elif ab.get("once", false) and _once_used(h, ab):
			dim.append(entries.size())
			entries.append("%s — already used" % ab["name"])
		else:
			entries.append("%s (%d MP) — %s" % [ab["name"], ab["cost"], ab["desc"]])
	for sm in summons:
		if not GameState.skill_unlocked(d, sm):
			dim.append(entries.size())
			entries.append("◈ %s — %s" % [sm["name"], GameState.skill_lock_hint(d, sm)])
		elif sm.get("once", false) and _once_used(h, sm):
			dim.append(entries.size())
			entries.append("◈ %s — already summoned" % sm["name"])
		else:
			entries.append("◈ %s (%d MP) — %s" % [sm["name"], sm["cost"], sm["desc"]])
	var ult_idx := -1
	if has_ult:
		ult_idx = entries.size()
		entries.append("★ %s — %s" % [ult["name"],
			"already used" if h["ult_used"] else ult["desc"]])
	entries.append("Back")
	var pick: int = await _menu(entries, h, dim)
	if pick < 0:  # B/X = Zurück
		return false
	if pick >= abilities.size() and pick < abilities.size() + summons.size():
		var sm: Dictionary = summons[pick - abilities.size()]
		if not GameState.skill_unlocked(d, sm):
			_say("%s is still %s!" % [sm["name"], GameState.skill_lock_hint(d, sm)])
			AudioManager.play_sfx("error")
			return false
		if sm.get("once", false) and _once_used(h, sm):
			_say("%s has already been summoned this battle!" % sm["name"])
			AudioManager.play_sfx("error")
			return false
		if d["mp"] < sm["cost"]:
			_say("Not enough MP!")
			AudioManager.play_sfx("error")
			return false
		d["mp"] -= sm["cost"]
		if sm.get("once", false):
			_mark_once_used(h, sm)
		_refresh_party()
		match sm["id"]:
			"ifrit": await _summon_ifrit(h, sm)
			"leviathan": await _summon_leviathan(h, sm)
			"bahamut": await _summon_bahamut(h, sm)
		return true
	if has_ult and pick == ult_idx:
		if h["ult_used"]:
			_say("Your ultimate power is already spent this battle!")
			AudioManager.play_sfx("error")
			return false
		h["ult_used"] = true
		match d["id"]:
			"serena": await _ultimate_serena(h)
			"rax": await _ultimate_rax(h)
		return true
	if pick >= abilities.size():  # „Zurück"
		return false
	var ab: Dictionary = abilities[pick]
	if not GameState.skill_unlocked(d, ab):
		_say("%s is still %s!" % [ab["name"], GameState.skill_lock_hint(d, ab)])
		AudioManager.play_sfx("error")
		return false
	if ab.get("once", false) and _once_used(h, ab):
		_say("%s is already spent this battle!" % ab["name"])
		AudioManager.play_sfx("error")
		return false
	if d["mp"] < ab["cost"]:
		_say("Not enough MP!")
		AudioManager.play_sfx("error")
		return false
	if ab.get("once", false):
		_mark_once_used(h, ab)
	match ab["target"]:
		"all":
			d["mp"] -= ab["cost"]
			_refresh_party()
			_pause_bob(h)
			match ab["kind"]:
				"rocket": await _rocket_all(h, ab)
				"nuke": await _nuke(h, ab)
				"meteor": await _meteor_rain(h, ab)
				"bladestorm": await _blade_storm(h, ab)
				_: await _whirl_all(h, ab)
			_resume_bob(h, 2.0)
		"one":
			var t: int = await _pick_enemy()
			if t < 0: return false
			d["mp"] -= ab["cost"]
			_refresh_party()
			_pause_bob(h)
			match ab["kind"]:
				"magic": await _fireball(h, ab, enemies[t])
				"beam": await _laser(h, ab, enemies[t])
				"dance": await _blade_dance(h, ab, enemies[t])
				"stormcut": await _storm_cut(h, ab, enemies[t])
				"lance": await _plasma_lance(h, ab, enemies[t])
				_: await _pierce(h, ab, enemies[t])
			_resume_bob(h, 2.0)
		"ally":
			var a: int = await _menu(_ally_entries(), h)
			if a < 0:  # B/X = Zurück, ohne MP zu verbrauchen
				return false
			d["mp"] -= ab["cost"]
			_refresh_party()
			_pause_bob(h)
			if ab["kind"] == "repair":
				await _repair_ally(h, ab, heroes[a])
			else:
				await _heal_ally(h, ab, heroes[a])
			_resume_bob(h, 2.0)
			_restore_if_revived(heroes[a])
	return true

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
		_say("%s is defeated!  %d gold, %d XP!" % [boss_def["name"], gold, xp])
	else:
		_say("Victory!  Looted %d gold and %d XP!" % [gold, xp])
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
	# Siegesjubel: die Überlebenden hüpfen zweimal mit Squash-Landung und recken
	# triumphierend die Waffe. Bob vorher anhalten, damit die Sprünge sauber von
	# der Grundhöhe (home.y) starten statt gegen das Wippen zu kämpfen.
	for h in heroes:
		if h["data"]["hp"] <= 0:
			continue
		_pause_bob(h)
		var s: Sprite2D = h["sprite"]
		var base: Vector2 = s.get_meta("base_scale", s.scale)
		var home_y: float = h["home"].y
		var tw := create_tween()
		for j in 2:
			tw.tween_property(s, "position:y", home_y - 34.0, 0.22) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(s, "scale", base * Vector2(0.95, 1.07), 0.22)
			tw.tween_property(s, "position:y", home_y, 0.24) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(s, "scale", base, 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var wp: Sprite2D = h.get("weapon")
		if wp != null and is_instance_valid(wp):
			var rest: float = wp.get_meta("rest", WEAPON_REST)
			var wt := wp.create_tween()
			wt.tween_property(wp, "rotation", rest - 1.4, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			wt.tween_interval(0.7)
			wt.tween_property(wp, "rotation", rest, 0.3).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(2.0).timeout
	# Stufenaufstiege feiern (heilt voll, LP/MP-Leisten aktualisieren).
	if not level_ups.is_empty():
		_refresh_party()
		for up in level_ups:
			AudioManager.play_sfx("heal")
			_say("%s reaches level %d!" % [up["name"], up["level"]])
			for h in heroes:
				if h["data"]["name"] == up["name"]:
					_sparkle(h["sprite"].position, Color(1.0, 0.92, 0.4))
					_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.45))
			await get_tree().create_timer(1.5).timeout
			if up.has("unlock"):
				AudioManager.play_sfx("summon")
				_say("%s can now summon %s!" % [up["name"], up["unlock"]])
				await get_tree().create_timer(1.8).timeout
	# Boss-Siege schalten den Fortschritt frei.
	if enemy_ids.has("boss4"):
		GameState.boss4_defeated = true
	elif enemy_ids.has("boss3"):
		GameState.boss3_defeated = true
		GameState.apply_blessing3()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(1.0, 0.95, 0.7))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.95, 0.7))
		_say("The shadow scatters. Down in the courtyard, neighbors are talking again — the Blessing of United Hearts flows through you!")
		await get_tree().create_timer(2.4).timeout
		await _announce_unlocked_tier()
		if GameState.boss_defeated and GameState.boss2_defeated:
			_say("But the last plague brings no peace — in the north, a gray rift tears open without a sound.")
			await get_tree().create_timer(2.4).timeout
			_say("No bird sings near it anymore. What waits there neither hates nor loves: the Void.")
			await get_tree().create_timer(2.4).timeout
	elif enemy_ids.has("boss2"):
		GameState.boss2_defeated = true
		GameState.apply_blessing2()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(1.0, 0.9, 0.4))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.4))
		_say("The Prince's hoard flows back into the valley — field by field, house by house. The Blessing of Shared Prosperity strengthens you!")
		await get_tree().create_timer(2.4).timeout
		await _announce_unlocked_tier()
		if GameState.boss_defeated and GameState.boss3_defeated:
			_say("And in the north a gray rift tears open — the Void awaits.")
			await get_tree().create_timer(2.4).timeout
	elif enemy_ids.has("boss"):
		GameState.boss_defeated = true
		GameState.apply_blessing()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(0.7, 1.0, 0.5))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(0.7, 1.0, 0.5))
		_say("The sludge drains away, and for the first time in years the air smells of rain — the Blessing of Clear Water flows through you!")
		await get_tree().create_timer(2.4).timeout
		await _announce_unlocked_tier()
		if GameState.boss2_defeated and GameState.boss3_defeated:
			_say("And in the north a gray rift tears open — the Void awaits.")
			await get_tree().create_timer(2.4).timeout
	finished.emit(true)

## Verkündet die gerade freigeschaltete Fähigkeits-Stufe. Da die Siegel jetzt
## nach ANZAHL der Bosssiege fallen (nicht nach bestimmtem Boss), richtet sich
## die Meldung nach dem neuen Zählerstand — egal welcher Dungeon zuerst fiel.
func _announce_unlocked_tier() -> void:
	var n: int = GameState.bosses_defeated_count()
	var names := {
		1: "Focus Pierce, Rocket Salvo and Ifrit's Pact",
		2: "Blade Dance, Nuke and Leviathan's Pact",
		3: "Blade Storm, Plasma Lance and Bahamut's Pact",
	}
	if names.has(n):
		_say("A seal shatters — %s awaken!" % names[n])
		await get_tree().create_timer(2.4).timeout

## Großes „SIEG!“-Banner, das ins Bild ploppt.
func _victory_banner() -> void:
	var banner := Label.new()
	banner.text = "VICTORY!"
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
	_say("The party has fallen ...")
	AudioManager.play_music("defeat")
	await get_tree().create_timer(2.5).timeout
	finished.emit(false)
