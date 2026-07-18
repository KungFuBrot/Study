class_name BattleDamage
extends BattleBossCine
## Schadensabwicklung fuer Helden und Gegner inkl. Ohnmacht, Gegner-Zerfall
## und Ausloesen der Boss-Wutphase.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

func _damage_hero(target: Dictionary, dmg: int) -> void:
	# In Deckung: der Treffer wird stark abgefedert; das Schild blitzt auf.
	if target.get("defending", false):
		dmg = maxi(int(round(dmg * 0.4)), 1)
		_float_text(target["sprite"].position + Vector2(0, -22), "Block!", Color(0.6, 0.85, 1.0))
		_burst(target["sprite"].position + Vector2(-18, -8), Color(0.65, 0.88, 1.0), 10, 100)
		if target.get("guard") != null and is_instance_valid(target["guard"]):
			var g: Node2D = target["guard"]
			var ft := g.create_tween()
			ft.tween_property(g, "modulate:a", 1.0, 0.05)
			ft.tween_property(g, "modulate:a", 0.6, 0.25)
	target["data"]["hp"] = maxi(target["data"]["hp"] - dmg, 0)
	_float_text(target["sprite"].position, str(dmg), Color(1.0, 0.45, 0.35))
	_shake(target["sprite"], 1.0)  # Held wird nach rechts (von den Gegnern weg) geworfen
	_shake_camera()
	_refresh_party()
	if target["data"]["hp"] <= 0:
		# Gefallene wippen nicht mehr — sonst „atmet" der Ohnmächtige weiter.
		_pause_bob(target)
		_end_defend(target)  # Schild verschwindet mit dem Ohnmächtigen
		var faint := create_tween()
		faint.tween_property(target["sprite"], "modulate", Color(0.4, 0.4, 0.55, 0.6), 0.4)
		faint.parallel().tween_property(target["sprite"], "rotation", -PI / 2, 0.4)

func _damage_enemy(e: Dictionary, dmg: int) -> void:
	e["hp"] -= dmg
	_float_text(e["sprite"].position + Vector2(0, -40 if e["is_boss"] else 0), str(dmg), Color(1, 1, 0.5))
	# Bosse stehen bombenfest; normale Gegner werden nach links (von den Helden weg) geworfen.
	_shake(e["sprite"], 0.0 if e["is_boss"] else -1.0)
	_shake_camera(1.4 if e["is_boss"] else 1.0)
	if e["is_boss"]:
		_refresh_boss_bar(e)
	if e["hp"] <= 0:
		e["alive"] = false
		_pause_bob(e)
		if e["is_boss"]:
			await _boss_death(e)
			return
		AudioManager.play_sfx("die")
		var s: Sprite2D = e["sprite"]
		_burst(s.position, Color(0.7, 0.6, 0.9), 14, 140)
		# Der Körper zerfällt in glühende Pixelblöcke (Dissolve-Shader);
		# Schatten/Glow/Spiegelung (Kinder) blenden parallel aus.
		var dm := Fx.dissolve_material()
		s.material = dm
		var tw := create_tween()
		tw.tween_method(func(p: float): dm.set_shader_parameter("progress", p),
			0.0, 1.0, 0.55)
		for c in s.get_children():
			if c is CanvasItem:
				var ct := create_tween()
				ct.tween_property(c, "modulate:a", 0.0, 0.35)
		# Der schwarze Bodennebel verweht mit dem Monster.
		if e.get("mist") != null and is_instance_valid(e["mist"]):
			(e["mist"] as CPUParticles2D).emitting = false
		await tw.finished
		(e["sprite"] as Sprite2D).visible = false
	else:
		# Wut-Phase: unter 40% LP wird der Boss schneller wütend und stärker.
		if e["is_boss"] and not e["enraged"] and e["hp"] < e["max_hp"] * 0.4:
			await _boss_enrage(e)
		await get_tree().create_timer(0.35).timeout
