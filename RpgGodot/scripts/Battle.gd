class_name Battle
extends Node2D
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Moderner Look: Partikel-Effekte, Hit-Stop, Geister-Trails, Kamerabeben,
## HP-Leisten, animierter Höhlenhintergrund mit Fackeln und Nebel sowie
## ein inszenierter Boss-Kampf (Kino-Balken, Wut-Phase, dramatischer Tod).

signal finished(victory: bool)
signal _choice_made

const BAR_W := 170
const WEAPON_REST := -0.35  # Ruhewinkel der Waffe (leicht zum Gegner geneigt)
# Griffposition (Faust) und Ruhewinkel pro Held — Schwert kampfbereit
# geneigt, Stab aufrecht neben dem Körper aufgesetzt.
const WEAPON_GRIP := {
	"serena": {"pos": Vector2(-5, 4), "rest": -0.35, "wscale": 0.85},
	"milo": {"pos": Vector2(-6, 2), "rest": 0.18, "wscale": 0.6},
}

# Kampf-Aufstellung (Zickzack in der Tiefe): Serena vordere Reihe oben,
# Milo hintere Reihe Mitte (weiter rechts + kleiner → Tiefe), Rax vordere
# Reihe unten. pos = Mittelpunkt. Milo weit genug rechts und Rax weit genug
# links, dass Milos Vortreten (_stance, -56 px) niemanden überlappt.
const BATTLE_FORMATION := {
	"serena": {"pos": Vector2(692, 178), "scale": 4.9},
	"milo": {"pos": Vector2(842, 236), "scale": 4.8},
	"rax": {"pos": Vector2(662, 306), "scale": 4.6},
}

var enemy_ids: Array = []
var arena_theme := "toxic"  # "toxic" | "gold" | "hate" — von Main anhand der Karte gesetzt

# Inszenierungs-Farben je Boss-Thema (Banner, Blitze, Wut-Phase, Auren).
const THEME_STYLE := {
	"toxic": {"flash": Color(0.45, 1.0, 0.25, 0.40), "banner": Color(0.60, 1.0, 0.35),
		"banner_outline": Color(0.05, 0.18, 0.03), "bar": Color(0.45, 0.95, 0.25),
		"bar_border": Color(0.20, 0.45, 0.10), "rage": Color(0.6, 1.5, 0.45),
		"aura": Color(0.45, 1.0, 0.15, 0.30), "ember": Color(0.55, 1.0, 0.20, 0.8),
		"burst": Color(0.55, 1.0, 0.30)},
	"gold": {"flash": Color(1.0, 0.85, 0.25, 0.40), "banner": Color(1.0, 0.87, 0.35),
		"banner_outline": Color(0.25, 0.15, 0.02), "bar": Color(1.0, 0.80, 0.20),
		"bar_border": Color(0.50, 0.35, 0.08), "rage": Color(1.6, 1.2, 0.5),
		"aura": Color(1.0, 0.75, 0.15, 0.30), "ember": Color(1.0, 0.85, 0.25, 0.8),
		"burst": Color(1.0, 0.85, 0.35)},
	"hate": {"flash": Color(1.0, 0.15, 0.10, 0.40), "banner": Color(1.0, 0.45, 0.35),
		"banner_outline": Color(0.28, 0.03, 0.03), "bar": Color(0.95, 0.20, 0.15),
		"bar_border": Color(0.55, 0.10, 0.08), "rage": Color(1.7, 0.45, 0.35),
		"aura": Color(1.0, 0.15, 0.05, 0.30), "ember": Color(1.0, 0.25, 0.08, 0.8),
		"burst": Color(1.0, 0.40, 0.30)},
}

## Stil des aktuellen Boss-Themas (Fallback: Arena-Thema).
func _style() -> Dictionary:
	return THEME_STYLE.get(boss_def.get("theme", arena_theme), THEME_STYLE["toxic"])
var boss_def := {}         # ENEMIES-Definition des Bosses in diesem Kampf (falls vorhanden)
var heroes := []   # {data, sprite, home, hp_label, hp_fill, mp_fill}
var enemies := []  # {name, hp, max_hp, atk, def, gold, sprite, home, alive, ...}

var ui_state := "none"  # none | menu | target | item | ally
var menu_index := 0
var choice := -1
var menu_labels: Array = []
var current_menu: Array = []
var menu_dim: Array = []  # Indizes gesperrter (grauer) Menüeinträge

var msg_label: Label
var menu_box: VBoxContainer
var party_box: VBoxContainer
var cursor: Polygon2D
var cam: Camera2D
var cam_idle: Tween
var live_lights := 0  # Deckel für kurzlebige Zauberlichter (Web-Performance)
var shock_live := false
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
	elif OS.get_environment("BOSSSHOT") != "":
		_boss_showcase()
	else:
		_run_battle()

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
	await _boss_ultimate(e, heroes)
	_snap(dir, "boss_ult_" + suffix)
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
	# Serena Fokusstoß (Durchstöße + Kreuzschnitt)
	_pierce(heroes[0], heroes[0]["data"]["abilities"][1], enemies[1])
	await get_tree().create_timer(1.25).timeout
	_snap(dir, "show_pierce_1")
	await get_tree().create_timer(0.5).timeout
	_snap(dir, "show_pierce_2")
	await get_tree().create_timer(1.3).timeout
	# Serena Klingentanz (Sternschritte + Fallstreich)
	_blade_dance(heroes[0], heroes[0]["data"]["abilities"][2], enemies[1])
	await get_tree().create_timer(1.6).timeout
	_snap(dir, "show_dance_1")
	await get_tree().create_timer(1.15).timeout
	_snap(dir, "show_dance_2")
	await get_tree().create_timer(1.0).timeout
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
	# Rax Laser
	_laser(heroes[2], heroes[2]["data"]["abilities"][0], enemies[1])
	await get_tree().create_timer(0.55).timeout
	_snap(dir, "show_laser")
	await get_tree().create_timer(1.2).timeout
	# Rax Raketensalve
	_rocket_all(heroes[2], heroes[2]["data"]["abilities"][1])
	await get_tree().create_timer(1.55).timeout
	_snap(dir, "show_rockets")
	await get_tree().create_timer(2.0).timeout
	# Rax Ultimate
	_ultimate_rax(heroes[2])
	await get_tree().create_timer(1.95).timeout
	_snap(dir, "show_ultimate")
	await get_tree().create_timer(1.8).timeout
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
	# Milo Meteorregen (Gesteinsbrocken über dem ganzen Feld)
	_ultimate_milo(heroes[1])
	await get_tree().create_timer(2.1).timeout
	_snap(dir, "show_meteor_1")
	await get_tree().create_timer(0.6).timeout
	_snap(dir, "show_meteor_2")
	await get_tree().create_timer(2.4).timeout
	# Übungsgegner wiederbeleben, damit die Atombombe Ziele hat
	for e in enemies:
		e["alive"] = true
		e["hp"] = 999
		var esp: Sprite2D = e["sprite"]
		esp.visible = true
		esp.material = null
		esp.modulate = Color.WHITE
	# Rax Atombombe zuletzt — sie reißt vermutlich alle Übungsgegner um.
	_nuke(heroes[2], heroes[2]["data"]["abilities"][2])
	await get_tree().create_timer(1.3).timeout
	_snap(dir, "show_nuke_1")
	await get_tree().create_timer(0.75).timeout
	_snap(dir, "show_nuke_2")
	await get_tree().create_timer(1.8).timeout
	get_tree().quit()

func _snap(dir: String, shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + shot_name + ".png")

## Farbstimmung des Schauplatzes (Schlotwerk giftgrün, Konzernturm golden,
## Hassfestung blutrot).
func _palette() -> Dictionary:
	var boss_fight := not boss_def.is_empty()
	match arena_theme:
		"gold":
			return {
				"bg_top": Color(0.18, 0.14, 0.08) if boss_fight else Color(0.15, 0.12, 0.09),
				"bg_bottom": Color(0.05, 0.04, 0.03),
				"floor_top": Color(0.30, 0.27, 0.24), "floor_bottom": Color(0.13, 0.11, 0.09),
				"stone": Color(0.42, 0.38, 0.30), "stal": Color(0.12, 0.09, 0.05, 0.85),
				"flame": Color(1.0, 0.80, 0.30), "glow": Color(1.0, 0.75, 0.25, 0.35),
				"fog": Color(0.85, 0.75, 0.50, 0.07), "hit": Color(1.0, 0.80, 0.30),
				"ray": Color(1.0, 0.85, 0.45, 0.06), "dust": Color(1.0, 0.88, 0.50, 0.55),
				"grade_top": Color(1.0, 0.85, 0.40, 0.08), "grade_bottom": Color(0.10, 0.06, 0.20, 0.16),
				"pool_hero": Color(1.0, 0.90, 0.60, 0.12), "pool_enemy": Color(1.0, 0.80, 0.35, 0.11),
				"fg": Color(0.04, 0.03, 0.02), "ambient": Color(0.68, 0.62, 0.52),
			}
		"hate":
			return {
				"bg_top": Color(0.19, 0.05, 0.06) if boss_fight else Color(0.14, 0.06, 0.08),
				"bg_bottom": Color(0.05, 0.02, 0.03),
				"floor_top": Color(0.24, 0.15, 0.16), "floor_bottom": Color(0.10, 0.06, 0.07),
				"stone": Color(0.32, 0.22, 0.22), "stal": Color(0.10, 0.04, 0.05, 0.85),
				"flame": Color(1.0, 0.45, 0.15), "glow": Color(1.0, 0.35, 0.12, 0.35),
				"fog": Color(0.70, 0.35, 0.35, 0.07), "hit": Color(1.0, 0.35, 0.25),
				"ray": Color(1.0, 0.45, 0.30, 0.05), "dust": Color(1.0, 0.55, 0.35, 0.50),
				"grade_top": Color(1.0, 0.45, 0.30, 0.08), "grade_bottom": Color(0.10, 0.02, 0.04, 0.20),
				"pool_hero": Color(1.0, 0.75, 0.55, 0.12), "pool_enemy": Color(1.0, 0.35, 0.25, 0.11),
				"fg": Color(0.04, 0.01, 0.02), "ambient": Color(0.66, 0.52, 0.52),
			}
		_:  # toxic
			return {
				"bg_top": Color(0.09, 0.15, 0.08) if boss_fight else Color(0.10, 0.13, 0.10),
				"bg_bottom": Color(0.03, 0.05, 0.03),
				"floor_top": Color(0.20, 0.25, 0.18), "floor_bottom": Color(0.09, 0.12, 0.08),
				"stone": Color(0.30, 0.34, 0.26), "stal": Color(0.07, 0.10, 0.06, 0.85),
				"flame": Color(0.55, 1.0, 0.30), "glow": Color(0.50, 1.0, 0.25, 0.35),
				"fog": Color(0.55, 0.80, 0.40, 0.08), "hit": Color(0.70, 1.0, 0.35),
				"ray": Color(0.65, 1.0, 0.45, 0.05), "dust": Color(0.75, 1.0, 0.55, 0.50),
				"grade_top": Color(0.60, 1.0, 0.40, 0.07), "grade_bottom": Color(0.03, 0.10, 0.20, 0.17),
				"pool_hero": Color(0.90, 1.0, 0.65, 0.12), "pool_enemy": Color(0.55, 1.0, 0.40, 0.10),
				"fg": Color(0.02, 0.04, 0.02), "ambient": Color(0.60, 0.68, 0.58),
			}

## ---------- Aufbau ----------

func _build_scene() -> void:
	add_child(Fx.glow_environment())
	cam = Camera2D.new()
	cam.position = Vector2(480, 270)
	add_child(cam)
	cam.make_current()
	var pal := _palette()
	# Abgedunkeltes Ambiente + echte 2D-Lichter (Fackeln, Zauber) wie im Feld.
	var cm := CanvasModulate.new()
	cm.color = pal["ambient"]
	add_child(cm)
	# Hintergrund: weicher Farbverlauf passend zum Schauplatz.
	var bg := Sprite2D.new()
	bg.texture = SpriteFactory.gradient(8, 64, pal["bg_top"], pal["bg_bottom"])
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.centered = false
	bg.scale = Vector2(960.0 / 8, 540.0 / 64)
	bg.z_index = -20
	add_child(bg)
	# Felswand mit echter Struktur hinter den Silhouetten: FastNoiseLite-FBM
	# statt flachem Verlauf — die Fackeln haben damit etwas zu beleuchten.
	var wall := Sprite2D.new()
	wall.texture = SpriteFactory.noise_texture(240, 100,
		pal["bg_bottom"], (pal["stal"] as Color).lightened(0.18), 7, 0.06)
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wall.centered = false
	wall.scale = Vector2(4, 4)
	wall.position = Vector2(0, -20)
	wall.z_index = -19
	wall.modulate = Color(1, 1, 1, 0.62)
	add_child(wall)
	# Drei Tiefen-Silhouetten-Ebenen mit langsamem Sinus-Drift: ferne Ebene
	# hell/dunstig Richtung Himmel, nahe Ebene dunkel — Faux-Parallax.
	var stal_col: Color = pal["stal"]
	var layer_specs: Array = [
		{"z": -17, "y": 330.0, "n": 9, "h0": 80.0, "hv": 80.0, "w0": 70.0,
			"col": stal_col.lerp(pal["bg_top"], 0.55), "amp": 5.0, "dur": 17.0},
		{"z": -15, "y": 355.0, "n": 7, "h0": 120.0, "hv": 140.0, "w0": 40.0,
			"col": stal_col, "amp": 9.0, "dur": 12.0},
		{"z": -14, "y": 378.0, "n": 5, "h0": 150.0, "hv": 170.0, "w0": 90.0,
			"col": stal_col.darkened(0.4), "amp": 14.0, "dur": 9.0},
	]
	for li in layer_specs.size():
		var spec: Dictionary = layer_specs[li]
		var layer := Node2D.new()
		layer.z_index = spec["z"]
		add_child(layer)
		var n: int = spec["n"]
		for i in n:
			var stal := Polygon2D.new()
			var w: float = spec["w0"] + fmod(i * 37.0 + li * 23.0, 50.0)
			var hh: float = spec["h0"] + fmod(i * 73.0 + li * 41.0, spec["hv"])
			stal.polygon = PackedVector2Array([Vector2(-w / 2, 0), Vector2(0, -hh), Vector2(w / 2, 0)])
			stal.color = spec["col"]
			stal.position = Vector2(fmod(30.0 + i * (980.0 / n) + li * 57.0, 1000.0) - 20.0, spec["y"])
			layer.add_child(stal)
		var drift := layer.create_tween().set_loops()
		drift.tween_property(layer, "position:x", spec["amp"], spec["dur"] * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(layer, "position:x", -spec["amp"], spec["dur"] * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_add_sky(pal)
	# Boden mit Verlauf + Steine als Dekor
	var floor_s := Sprite2D.new()
	floor_s.texture = SpriteFactory.gradient(8, 32, pal["floor_top"], pal["floor_bottom"])
	floor_s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor_s.centered = false
	floor_s.position = Vector2(0, 340)
	floor_s.scale = Vector2(960.0 / 8, 200.0 / 32)
	floor_s.z_index = -12
	add_child(floor_s)
	# Bodenstruktur: felsiges Rauschen über dem Verlauf (halbtransparent)
	var floor_tex := Sprite2D.new()
	floor_tex.texture = SpriteFactory.noise_texture(240, 50,
		(pal["floor_bottom"] as Color).darkened(0.25),
		(pal["floor_top"] as Color).lightened(0.08), 11, 0.09)
	floor_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor_tex.centered = false
	floor_tex.position = Vector2(0, 340)
	floor_tex.scale = Vector2(4, 4)
	floor_tex.z_index = -12
	floor_tex.modulate = Color(1, 1, 1, 0.55)
	add_child(floor_tex)
	for i in 24:
		var stone := Sprite2D.new()
		stone.texture = SpriteFactory.circle(3 + (i % 4), pal["stone"])
		stone.position = Vector2(40 + i * 39.0, 350 + fmod(i * 61.3, 160.0))
		stone.z_index = -11
		add_child(stone)
	# Verstreute Requisiten machen den Boden glaubwürdig (je Schauplatz).
	var prop_kinds: Array
	match arena_theme:
		"gold": prop_kinds = ["coins", "crate", "pebble"]
		"hate": prop_kinds = ["bones", "crack", "pebble"]
		_: prop_kinds = ["barrel", "sludge", "crack"]
	for i in 6:
		var pr := Sprite2D.new()
		pr.texture = SpriteFactory.prop(prop_kinds[i % prop_kinds.size()])
		pr.position = Vector2(60 + fmod(i * 157.0, 840.0), 365 + fmod(i * 83.0, 140.0))
		pr.scale = Vector2(3, 3)
		pr.z_index = -10
		pr.modulate = Color(0.9, 0.88, 0.9)
		add_child(pr)
	_add_torch(Vector2(70, 160), pal)
	_add_torch(Vector2(890, 160), pal)
	# Weiches Fülllicht über der Gegnerseite: die Torches stehen am Rand,
	# ohne Aufheller stünden die Monster fast im Schwarzen.
	# Kühleres, etwas schwächeres Licht über der Monsterseite — unheimlicher,
	# aber hell genug, dass die dunkleren Kreaturen lesbar bleiben.
	var fill := Fx.point_light(Color(0.86, 0.90, 1.0), 430.0, 0.95)
	fill.position = Vector2(280, 235)
	add_child(fill)
	Fx.pulse(fill, 0.95, 2.6)
	# ... und über der Heldenseite, warm getönt — sonst säuft vor allem
	# Rax' graues Metall im dunklen Ambiente ab.
	var fill_h := Fx.point_light(Color(1.0, 0.88, 0.72), 380.0, 0.9)
	fill_h.position = Vector2(750, 245)
	add_child(fill_h)
	Fx.pulse(fill_h, 0.9, 3.1)
	_add_god_rays(pal)
	_add_fog(pal)
	_add_dust_motes(pal)
	_add_foreground_blur(pal)
	_add_theme_weather()

	# Alle Kämpfer starten außerhalb des Bildes und marschieren in _run_battle ein.
	for i in GameState.party.size():
		var data: Dictionary = GameState.party[i]
		var s := Sprite2D.new()
		s.texture = SpriteFactory.hero_battle(data["id"])
		var form: Dictionary = BATTLE_FORMATION.get(data["id"],
			{"pos": Vector2(700 + (i % 2) * 60, 170 + i * 78), "scale": 4.0})
		var hscale: float = form["scale"]
		s.scale = Vector2(hscale, hscale)
		# Kanonische Größe festhalten: alle Squash-/Pose-Tweens lesen sie von
		# hier statt von s.scale — sonst friert ein überlappender Tween einen
		# gestauchten Wert als "Normalgröße" ein und die Figur driftet.
		s.set_meta("base_scale", s.scale)
		s.flip_h = true  # DTII-Figuren blicken nach rechts → zum Gegner (links) drehen
		var home: Vector2 = form["pos"]
		s.position = home + Vector2(340, 0)
		var foot_h: float = s.texture.get_height() * 0.5 - 1.0
		_attach_shadow(s, 9, 3, foot_h)
		_attach_glow_pool(s, foot_h, pal["pool_hero"])
		_attach_reflection(s, foot_h, 0.09)
		var wp := _attach_weapon(s, data["id"])
		add_child(s)
		heroes.append({"data": data, "sprite": s, "home": home, "ult_used": false,
			"frame": 0, "weapon": wp, "anim": "idle"})

	for i in enemy_ids.size():
		var def: Dictionary = GameState.ENEMIES[enemy_ids[i]]
		var is_boss: bool = def.get("boss", false)
		var s := Sprite2D.new()
		s.texture = SpriteFactory.enemy(def["sprite"])
		s.scale = Vector2(7.2, 7.2) if is_boss else Vector2(6.5, 6.5)
		s.set_meta("base_scale", s.scale)
		var home := Vector2(222, 222) if is_boss else Vector2(225 + (i % 2) * 100, 180 + i * 88)
		s.position = home - Vector2(500, 0)
		var refl: Sprite2D
		var mist: CPUParticles2D = null
		if is_boss:
			var foot: float = s.texture.get_height() * 0.5 + 0.5
			_attach_shadow(s, 13, 3, foot)
			_attach_glow_pool(s, foot, pal["pool_enemy"])
			refl = _attach_reflection(s, foot, 0.10)
			_attach_boss_aura(s, def.get("theme", "toxic"))
			_attach_boss_life(s, def.get("theme", "toxic"), def["sprite"])
			# Träges Gewichts-Schwanken — der Koloss steht nie ganz still.
			var sway := create_tween().set_loops()
			sway.tween_property(s, "rotation", 0.015, 2.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sway.tween_property(s, "rotation", -0.015, 2.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			var foot_e: float = s.texture.get_height() * 0.5 - 1.0
			_attach_shadow(s, 9, 3, foot_e)
			_attach_glow_pool(s, foot_e, pal["pool_enemy"])
			refl = _attach_reflection(s, foot_e)
			mist = _attach_menace(s, home, foot_e)
		# Themen-Tönung, zusätzlich abgedunkelt und leicht ins Violette
		# entsättigt — die Monster lauern im Halbdunkel. Die Spiegelung
		# erbt die Färbung als Kind automatisch.
		var dark := Color(0.90, 0.88, 0.94) if is_boss else Color(0.78, 0.75, 0.86)
		var tint: Color = def.get("tint", Color.WHITE) * dark
		s.modulate = tint
		s.set_meta("tint", tint)
		add_child(s)
		enemies.append({"name": def["name"], "hp": def["hp"], "max_hp": def["hp"],
			"atk": def["atk"], "def": def["def"], "gold": def["gold"], "xp": def.get("xp", 0),
			"sprite": s, "home": home, "alive": true, "is_boss": is_boss,
			"id": def["sprite"], "frame": 0, "acts": 0, "enraged": false, "refl": refl,
			"tint": tint, "proj": def.get("proj", ""), "mist": mist,
			"attack_line": def.get("attack_line", "")})

## Lebendiger Himmel über der Arena: pulsierende Glut in der Höhle,
## wogende Aurora-Bänder in der Frostgrotte.
func _add_sky(pal: Dictionary) -> void:
	if arena_theme == "toxic":
		# Wabernde Smogschwaden ziehen als Bänder unter der Hallendecke entlang
		for i in 3:
			var band := Polygon2D.new()
			var pts := PackedVector2Array()
			var y0 := 34.0 + i * 30.0
			for k in 13:
				pts.append(Vector2(k * 80.0, y0 + sin(k * 0.9 + i * 1.7) * 16.0))
			for k in range(12, -1, -1):
				pts.append(Vector2(k * 80.0, y0 + 24.0 + sin(k * 0.9 + i * 1.7) * 16.0))
			band.polygon = pts
			band.color = Color(0.45, 0.85, 0.30, 0.05 + 0.02 * i)
			band.z_index = -18
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			band.material = mat
			add_child(band)
			var tw := band.create_tween().set_loops()
			tw.tween_property(band, "modulate", Color(0.8, 1.25, 0.7, 1.0), 3.2 + i * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(band, "position:x", -22.0, 3.2 + i * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(band, "modulate", Color(1.1, 1.0, 0.6, 0.7), 3.6 + i * 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(band, "position:x", 22.0, 3.6 + i * 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	# Pulsierende Glutblasen: golden im Konzernturm, blutrot in der Hassfestung
	var blob_col := Color(1.0, 0.80, 0.30, 0.10) if arena_theme == "gold" \
		else Color(1.0, 0.30, 0.12, 0.10)
	for i in 4:
		var blob := Sprite2D.new()
		blob.texture = SpriteFactory.circle(26, blob_col)
		blob.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		blob.position = Vector2(120 + i * 240.0, 70 + fmod(i * 53.0, 60.0))
		blob.scale = Vector2(2.5 + (i % 2), 1.6)
		blob.z_index = -18
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		blob.material = mat
		add_child(blob)
		var tw := blob.create_tween().set_loops()
		tw.tween_property(blob, "modulate:a", 0.4, 2.2 + i * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(blob, "modulate:a", 1.0, 2.6 + i * 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
## Liefert das Waffen-Sprite zurück, damit Angriffe es schwingen können.
func _attach_weapon(s: Sprite2D, hero_id: String) -> Sprite2D:
	var tex := SpriteFactory.hero_weapon(hero_id)
	if tex == null:
		return null
	var w := Sprite2D.new()
	w.texture = tex
	# Der Held ist flip_h → die Waffenhand liegt bildlinks. Der Griff (unteres
	# Textur-Ende) wird per offset zum Drehpunkt: die Waffe schwingt um die
	# Faust statt um die Klingenmitte.
	w.offset = Vector2(0, -tex.get_height() * 0.5 + 3.0)
	var grip: Dictionary = WEAPON_GRIP.get(hero_id, {"pos": Vector2(-7, 3), "rest": WEAPON_REST})
	w.position = grip["pos"]
	w.rotation = grip["rest"]
	w.set_meta("rest", grip["rest"])
	w.set_meta("grip_x", (grip["pos"] as Vector2).x)
	var ws: float = grip.get("wscale", 0.85)  # Milos Stab z. B. etwas kleiner
	w.scale = Vector2(ws, ws)
	w.z_index = 1
	s.add_child(w)
	return w

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

## Pulsierende Aura + aufsteigende Glut hinter dem Boss (Farbe je Thema).
func _attach_boss_aura(s: Sprite2D, theme: String) -> void:
	var st: Dictionary = THEME_STYLE.get(theme, THEME_STYLE["toxic"])
	var aura_col: Color = st["aura"]
	var ember_col: Color = st["ember"]
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

## Gesichtsposition der Boss-Sprites (lokale Pixel, Ursprung Sprite-Mitte).
const BOSS_FACE := {
	"boss": Vector2(3, -3), "boss2": Vector2(3, -4), "boss3": Vector2(1, -5),
}

## Lebenszeichen des Bosses: glimmende Augen-Glut (mit Blinzeln), giftiger
## Atem aus dem Maul und ein tiefes Grollen mit Auren-Flackern.
func _attach_boss_life(s: Sprite2D, theme: String, sprite_id: String) -> void:
	var st: Dictionary = THEME_STYLE.get(theme, THEME_STYLE["toxic"])
	var face: Vector2 = BOSS_FACE.get(sprite_id, Vector2(2, -7))
	# Glut in den Augenhöhlen: kleiner additiver Schein, der pulsiert
	# und hin und wieder kurz erlischt (Blinzeln).
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var eyes := Sprite2D.new()
	eyes.texture = SpriteFactory.circle(3, Color(1.0, 0.9, 0.8))
	eyes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	eyes.material = mat
	eyes.position = face
	eyes.scale = Vector2(1.4, 0.7)
	eyes.modulate = Color(st["ember"].r, st["ember"].g, st["ember"].b, 0.55)
	s.add_child(eyes)
	s.set_meta("eyes", eyes)
	var pulse := eyes.create_tween().set_loops()
	pulse.tween_property(eyes, "modulate:a", 0.30, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(eyes, "modulate:a", 0.60, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var blink := Timer.new()
	blink.wait_time = randf_range(3.0, 6.0)
	blink.autostart = true
	blink.timeout.connect(func():
		blink.wait_time = randf_range(3.0, 6.0)
		if not is_instance_valid(eyes):
			return
		var b := create_tween()
		b.tween_property(eyes, "scale:y", 0.06, 0.07)
		b.tween_property(eyes, "scale:y", 0.7, 0.09))
	s.add_child(blink)
	# Atem: schwerer Dunst quillt rhythmisch aus dem Maul (Themenfarbe).
	var breath := CPUParticles2D.new()
	breath.position = face + Vector2(3, 3)
	breath.amount = 5
	breath.lifetime = 1.4
	breath.direction = Vector2(1, 0.25)
	breath.spread = 14.0
	breath.gravity = Vector2(4, -5)
	breath.initial_velocity_min = 4.0
	breath.initial_velocity_max = 9.0
	breath.scale_amount_min = 0.010
	breath.scale_amount_max = 0.022
	breath.color = Color(st["ember"].r, st["ember"].g, st["ember"].b, 0.28)
	breath.texture = SpriteFactory.particle("smoke_07")
	breath.show_behind_parent = false
	s.add_child(breath)
	# Grollen: alle paar Sekunden ein tiefer Laut + kurzes Aufflammen der Aura.
	var growl := Timer.new()
	growl.wait_time = randf_range(6.0, 10.0)
	growl.autostart = true
	growl.timeout.connect(func():
		growl.wait_time = randf_range(6.0, 10.0)
		if not is_instance_valid(s) or not s.visible:
			return
		AudioManager.play_sfx("growl")
		var flare := create_tween()
		flare.tween_property(eyes, "modulate:a", 1.0, 0.15)
		flare.tween_property(eyes, "modulate:a", 0.5, 0.5))
	s.add_child(growl)

## Grusel-Aufsatz für normale Monster: schwarzer Bodennebel wabert um die
## Füße, und in unregelmäßigen Abständen zuckt die Kreatur unruhig.
func _attach_menace(s: Sprite2D, home: Vector2, foot_local: float) -> CPUParticles2D:
	var mist := CPUParticles2D.new()
	mist.position = home + Vector2(0, foot_local * 6.5 - 2.0)
	mist.amount = 7
	mist.lifetime = 2.6
	mist.preprocess = 2.6
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(34, 5)
	mist.direction = Vector2(0, -1)
	mist.spread = 24.0
	mist.gravity = Vector2(0, -6)
	mist.initial_velocity_min = 3.0
	mist.initial_velocity_max = 9.0
	mist.scale_amount_min = 0.14
	mist.scale_amount_max = 0.30
	mist.color = Color(0.03, 0.02, 0.06, 0.4)
	mist.texture = SpriteFactory.particle("smoke_07")
	mist.z_index = 1
	add_child(mist)
	var twitch := Timer.new()
	twitch.wait_time = randf_range(2.2, 4.6)
	twitch.autostart = true
	twitch.timeout.connect(func():
		twitch.wait_time = randf_range(2.2, 4.6)
		if not is_instance_valid(s) or not s.visible:
			return
		var tw := create_tween()
		tw.tween_property(s, "rotation", 0.05, 0.05)
		tw.tween_property(s, "rotation", -0.04, 0.06)
		tw.tween_property(s, "rotation", 0.0, 0.07))
	add_child(twitch)
	return mist

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
	# Echtes Punktlicht: die Fackel beleuchtet Wand und Boden ringsum.
	var light := Fx.point_light(pal["flame"], 240.0, 1.0)
	light.position = pos + Vector2(0, -14)
	add_child(light)
	Fx.flicker(light, 1.0)
	# Echte, züngelnde Flamme: additives Kenney-Flammen-Sprite, das im
	# Flackertakt Höhe und Neigung wechselt.
	var tongue := Sprite2D.new()
	tongue.texture = SpriteFactory.particle("flame_02")
	tongue.position = pos + Vector2(0, -22)
	tongue.scale = Vector2(0.14, 0.16)
	tongue.modulate = Color(pal["flame"], 0.95)
	tongue.material = mat
	tongue.z_index = -8
	add_child(tongue)
	var lick := tongue.create_tween().set_loops()
	lick.tween_property(tongue, "scale", Vector2(0.12, 0.19), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lick.parallel().tween_property(tongue, "rotation", 0.10, 0.16)
	lick.tween_property(tongue, "scale", Vector2(0.15, 0.14), 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lick.parallel().tween_property(tongue, "rotation", -0.08, 0.13)
	lick.tween_property(tongue, "scale", Vector2(0.13, 0.17), 0.19) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lick.parallel().tween_property(tongue, "rotation", 0.0, 0.19)
	var flame := CPUParticles2D.new()
	flame.position = pos + Vector2(0, -14)
	flame.amount = 10
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
## Schauplatz-Wetter: giftige Bläschen, goldener Glitzerregen oder Glutasche.
func _add_theme_weather() -> void:
	var p := CPUParticles2D.new()
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.texture = SpriteFactory.circle(2, Color.WHITE)
	p.z_index = 20
	match arena_theme:
		"gold":
			# Goldstaub rieselt wie feiner Konfettiregen
			p.position = Vector2(480, -20)
			p.amount = 50
			p.emission_rect_extents = Vector2(520, 10)
			p.direction = Vector2(0.08, 1)
			p.spread = 10.0
			p.gravity = Vector2(0, 10)
			p.initial_velocity_min = 35.0
			p.initial_velocity_max = 65.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 1.0
			p.color = Color(1.0, 0.87, 0.40, 0.75)
		"hate":
			# Glutasche wirbelt nach oben
			p.position = Vector2(480, 560)
			p.amount = 46
			p.emission_rect_extents = Vector2(520, 10)
			p.direction = Vector2(-0.15, -1)
			p.spread = 16.0
			p.gravity = Vector2(-6, -22)
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 60.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.1
			p.color = Color(1.0, 0.42, 0.15, 0.7)
		_:
			# Giftblasen steigen träge aus dem Boden
			p.position = Vector2(480, 560)
			p.amount = 36
			p.emission_rect_extents = Vector2(520, 10)
			p.direction = Vector2(0, -1)
			p.spread = 8.0
			p.gravity = Vector2(0, -10)
			p.initial_velocity_min = 18.0
			p.initial_velocity_max = 40.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.4
			p.color = Color(0.55, 1.0, 0.30, 0.45)
	add_child(p)

## Lebendige Idles: Held*innen und Monster durchlaufen ihre 4-Frame-Animation.
func _start_idle_animations() -> void:
	# Jede Figur taktet ihre Frames eigenständig und leicht unterschiedlich
	# schnell — im globalen Gleichtakt wirkte die Szene wie ein starres GIF.
	for e in enemies:
		_unit_ticker(randf_range(0.13, 0.19), func():
			if e["alive"] and SpriteFactory.enemy_has_anim(e["id"]):
				e["frame"] = (e["frame"] + 1) % SpriteFactory.ENEMY_FRAMES
				var tex := SpriteFactory.enemy_frame(e["id"], e["frame"])
				(e["sprite"] as Sprite2D).texture = tex
				if is_instance_valid(e["refl"]):
					(e["refl"] as Sprite2D).texture = tex)
	for h in heroes:
		_unit_ticker(randf_range(0.13, 0.19), func():
			if h["data"]["hp"] > 0:
				h["frame"] = (h["frame"] + 1) % 4
				(h["sprite"] as Sprite2D).texture = \
					SpriteFactory.hero_battle_frame(h["data"]["id"], h["frame"], h["anim"]))
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

## Eigener Frame-Ticker pro Figur (leicht versetzte Perioden = organisches Bild).
func _unit_ticker(period: float, cb: Callable) -> void:
	var t := Timer.new()
	t.wait_time = period
	t.autostart = true
	t.timeout.connect(cb)
	add_child(t)

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

## Idle-Wippen zentral anhalten/neustarten — verhindert, dass ein laufender
## Bob-Loop in Dash-/Teleport-Animationen hineinpfuscht oder doppelt stapelt.
func _pause_bob(u: Dictionary) -> void:
	if u.get("bob") != null:
		(u["bob"] as Tween).kill()
		u["bob"] = null

func _resume_bob(u: Dictionary, period: float) -> void:
	_pause_bob(u)
	u["bob"] = _idle_bob(u["sprite"], period)

## Ein wiederbelebter Held rappelt sich auf (Pose + Wippen zurücksetzen).
func _restore_if_revived(hero: Dictionary) -> void:
	if hero["data"]["hp"] <= 0:
		return
	var s: Sprite2D = hero["sprite"]
	if absf(s.rotation) > 0.01 or s.modulate.a < 0.95:
		var tw := create_tween()
		tw.tween_property(s, "rotation", 0.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate", Color.WHITE, 0.35)
		_resume_bob(hero, 2.0)

func _idle_bob(s: Sprite2D, period: float) -> Tween:
	var tw := create_tween().set_loops()
	tw.tween_property(s, "position:y", s.position.y - 4.0, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s, "position:y", s.position.y, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Leerlauf-Gesten: wenn eine Figur gerade nichts tut, macht sie ab und zu
## etwas — Helden verlagern das Gewicht, recken sich, wirbeln die Waffe; Bosse
## verlagern drohend das Gewicht, schnauben und lassen die Augen aufflammen.
## Alles nur Transform-/Partikel-Spielereien: das Idle-Wippen (position:y) und
## der Frame-Ticker (Textur) bleiben unangetastet, und laufende Rotations-Loops
## (Boss-Schwanken, Augen-Puls) übernehmen nach der Geste wieder — ein neuerer
## Tween gewinnt nur während seiner Laufzeit pro Frame.
func _start_idle_antics() -> void:
	for h in heroes:
		_schedule_antic(h, true)
	for e in enemies:
		if e.get("is_boss", false):
			_schedule_antic(e, false)

## Ein Timer je Figur, der sich nach jeder Geste auf ein neues Zufallsintervall
## setzt — so bleiben die Figuren entsynchronisiert und wirken nie im Gleichtakt.
func _schedule_antic(u: Dictionary, is_hero: bool) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = randf_range(3.5, 7.5)
	t.timeout.connect(func():
		if not is_instance_valid(t):
			return
		_do_idle_antic(u, is_hero)
		t.wait_time = randf_range(3.5, 7.5)
		t.start())
	add_child(t)
	t.start()

## Führt eine Geste aus — aber nur, wenn die Figur wirklich in Ruhe ist. Das
## laufende Idle-Wippen (bob != null) ist genau dieses Ruhesignal: bei jeder
## Aktion wird der Bob per _pause_bob abgeschaltet, also ruht die Figur nur,
## solange er läuft.
func _do_idle_antic(u: Dictionary, is_hero: bool) -> void:
	if u.get("bob") == null:
		return
	var s: Sprite2D = u["sprite"]
	if not is_instance_valid(s):
		return
	if is_hero:
		if u["data"]["hp"] <= 0:
			return
		_hero_antic(u)
	elif u.get("alive", false):
		_boss_antic(u)

## Kleine Ruhe-Geste eines Helden (zufällig aus drei Varianten).
func _hero_antic(h: Dictionary) -> void:
	var s: Sprite2D = h["sprite"]
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var wp: Sprite2D = h.get("weapon")
	match randi() % 3:
		0:  # Gewicht verlagern: sacht hin- und herlehnen und aufrichten.
			var tw := create_tween()
			tw.tween_property(s, "rotation", 0.06, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(s, "rotation", -0.05, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(s, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		1:  # Recken: kurze Squash-Stretch-Streckung und zurück.
			var tw := create_tween()
			tw.tween_property(s, "scale", base * Vector2(0.95, 1.06), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", base * Vector2(1.03, 0.97), 0.16)
			tw.tween_property(s, "scale", base, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		2:  # Waffe wirbeln (mit Waffe) bzw. Visor-Blitz + Nicken (Rax).
			if wp != null and is_instance_valid(wp):
				var rest: float = wp.get_meta("rest", WEAPON_REST)
				_weapon_trail(wp, 0.36)
				var tw := wp.create_tween()
				tw.tween_property(wp, "rotation", rest + TAU, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				tw.tween_callback(func(): if is_instance_valid(wp): wp.rotation = rest)
			else:
				_visor_glint(s)
				var tw := create_tween()
				tw.tween_property(s, "rotation", 0.05, 0.16).set_trans(Tween.TRANS_SINE)
				tw.tween_property(s, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_SINE)

## Kurzer blauer Lichtwisch über Rax' Visor (er hat keine Waffe zum Wirbeln).
func _visor_glint(s: Sprite2D) -> void:
	var g := Sprite2D.new()
	g.texture = SpriteFactory.circle(4, Color(0.6, 0.95, 1.0))
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.position = s.position + Vector2(-14, -30)
	g.scale = Vector2(0.25, 0.7)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "position:x", s.position.x + 14.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(g, "scale", Vector2(1.1, 0.4), 0.32)
	tw.tween_property(g, "modulate:a", 0.0, 0.14)
	tw.tween_callback(g.queue_free)

## Kleine Ruhe-Geste eines Bosses (drohender als bei den Helden).
func _boss_antic(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	match randi() % 3:
		0:  # Drohend das Gewicht verlagern + tiefes Grollen + Augen aufflammen.
			AudioManager.play_sfx("growl")
			_boss_eye_flare(e)
			var tw := create_tween()
			tw.tween_property(s, "rotation", 0.09, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(s, "rotation", -0.07, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(s, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		1:  # Schnauben: kräftiger Dunststoß aus dem Maul + Augen kurz heller.
			_boss_snort(e)
		2:  # Schulterrollen: schwerer Squash mit kleinem Bodenbeben.
			var tw := create_tween()
			tw.tween_property(s, "scale", base * Vector2(1.04, 0.95), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", base * Vector2(0.98, 1.03), 0.22)
			tw.tween_property(s, "scale", base, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_shake_camera(0.4)

## Boss-Augen kurz hell auflodern lassen (nutzt das im Setup abgelegte "eyes").
func _boss_eye_flare(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	if s.has_meta("eyes") and is_instance_valid(s.get_meta("eyes")):
		var ey: Sprite2D = s.get_meta("eyes")
		var tw := create_tween()
		tw.tween_property(ey, "modulate:a", 1.0, 0.15)
		tw.tween_property(ey, "modulate:a", 0.55, 0.5)

## Schnauben: kurzer, kräftiger Rauchstoß aus dem Maul (Themenfarbe) + Grollen
## + Augen-Flackern + kleiner Kopf-Ruck.
func _boss_snort(e: Dictionary) -> void:
	var s: Sprite2D = e["sprite"]
	AudioManager.play_sfx("growl")
	_boss_eye_flare(e)
	var face: Vector2 = BOSS_FACE.get(e["id"], Vector2(2, -7)) + Vector2(3, 3)
	var ember: Color = _style()["ember"]
	var puff := CPUParticles2D.new()
	puff.position = face
	puff.one_shot = true
	puff.explosiveness = 0.85
	puff.amount = 9
	puff.lifetime = 0.7
	puff.direction = Vector2(1, 0.25)
	puff.spread = 22.0
	puff.gravity = Vector2(6, -8)
	puff.initial_velocity_min = 8.0
	puff.initial_velocity_max = 18.0
	puff.scale_amount_min = 0.012
	puff.scale_amount_max = 0.026
	puff.color = Color(ember.r, ember.g, ember.b, 0.42)
	puff.texture = SpriteFactory.particle("smoke_07")
	puff.emitting = true
	s.add_child(puff)
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(puff):
			puff.queue_free())
	var tw := create_tween()
	tw.tween_property(s, "rotation", -0.05, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)

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
		_say("Monster greifen an!")
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
	while true:
		var cmd: int = await _menu([d["name"] + ":  Angriff", "Fähigkeit", "Item", "Fliehen"], h)
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

## Untermenü: Fähigkeiten, Beschwörungen (Milo) oder die Ultimative wählen.
func _ability_menu(h: Dictionary) -> bool:
	var d: Dictionary = h["data"]
	var abilities: Array = d["abilities"]
	var summons: Array = d.get("summons", [])
	var ult: Dictionary = d["ultimate"]
	var entries := []
	var dim := []
	for ab in abilities:
		if not GameState.skill_unlocked(d, ab):
			dim.append(entries.size())
			entries.append("%s — %s" % [ab["name"], GameState.skill_lock_hint(d, ab)])
		else:
			entries.append("%s (%d MP) — %s" % [ab["name"], ab["cost"], ab["desc"]])
	for sm in summons:
		if not GameState.skill_unlocked(d, sm):
			dim.append(entries.size())
			entries.append("◈ %s — %s" % [sm["name"], GameState.skill_lock_hint(d, sm)])
		else:
			entries.append("◈ %s (%d MP) — %s" % [sm["name"], sm["cost"], sm["desc"]])
	entries.append("★ %s — %s" % [ult["name"],
		"bereits eingesetzt" if h["ult_used"] else ult["desc"]])
	entries.append("Zurück")
	var pick: int = await _menu(entries, h, dim)
	if pick >= abilities.size() and pick < abilities.size() + summons.size():
		var sm: Dictionary = summons[pick - abilities.size()]
		if not GameState.skill_unlocked(d, sm):
			_say("%s ist noch %s!" % [sm["name"], GameState.skill_lock_hint(d, sm)])
			AudioManager.play_sfx("error")
			return false
		if d["mp"] < sm["cost"]:
			_say("Nicht genug MP!")
			AudioManager.play_sfx("error")
			return false
		d["mp"] -= sm["cost"]
		_refresh_party()
		match sm["id"]:
			"ifrit": await _summon_ifrit(h, sm)
			"leviathan": await _summon_leviathan(h, sm)
		return true
	if pick == abilities.size() + summons.size():
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
	if pick > abilities.size() + summons.size():
		return false
	var ab: Dictionary = abilities[pick]
	if not GameState.skill_unlocked(d, ab):
		_say("%s ist noch %s!" % [ab["name"], GameState.skill_lock_hint(d, ab)])
		AudioManager.play_sfx("error")
		return false
	if d["mp"] < ab["cost"]:
		_say("Nicht genug MP!")
		AudioManager.play_sfx("error")
		return false
	match ab["target"]:
		"all":
			d["mp"] -= ab["cost"]
			_refresh_party()
			_pause_bob(h)
			match ab["kind"]:
				"rocket": await _rocket_all(h, ab)
				"nuke": await _nuke(h, ab)
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
				_: await _pierce(h, ab, enemies[t])
			_resume_bob(h, 2.0)
		"ally":
			var a: int = await _menu(_ally_entries(), h)
			d["mp"] -= ab["cost"]
			_refresh_party()
			_pause_bob(h)
			await _heal_ally(h, ab, heroes[a])
			_resume_bob(h, 2.0)
			_restore_if_revived(heroes[a])
	return true

## Auswahl-Einträge „Für <Name>" für alle Party-Mitglieder (beliebige Größe).
func _ally_entries() -> Array:
	var names := []
	for hh in heroes:
		names.append("Für " + hh["data"]["name"])
	return names

## ---------- Menüs (await auf Spieler-Eingabe) ----------

func _menu(entries: Array, h: Dictionary, dim_indices: Array = []) -> int:
	_highlight_hero(h, true)
	current_menu = entries
	menu_dim = dim_indices
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

## Kampfbereitschaft: Wenn ein Held am Zug ist, tritt er einen Schritt vor,
## richtet sich auf und hebt die Waffe in Anschlag; danach entspannt er wieder.
## Umschließt den ganzen Zug (in _run_battle), damit es nicht bei jedem Untermenü
## zuckt. Nur Position:x/Scale/Waffenwinkel — Bob (position:y) bleibt unberührt.
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

func _redraw_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	for i in current_menu.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		l.text = ("> " if i == menu_index else "  ") + str(current_menu[i])
		var col := Color.WHITE if i == menu_index else Color(0.65, 0.65, 0.72)
		if menu_dim.has(i):
			col = Color(0.62, 0.62, 0.68) if i == menu_index else Color(0.42, 0.42, 0.5)
		l.add_theme_color_override("font_color", col)
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
	# Falls das Item einen Gefallenen zurückholt: aufrappeln lassen.
	_restore_if_revived(heroes[target])
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
		h["frame"] = (h["frame"] + 1) % 4
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

func _hero_attack(h: Dictionary, e: Dictionary) -> void:
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	_say("%s greift an!" % h["data"]["name"])
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	# 1) Ausholen: zurücklehnen, Waffe über die Schulter reißen (Anticipation).
	var wind := create_tween()
	wind.tween_property(s, "rotation", 0.16, 0.13) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wind.parallel().tween_property(s, "scale", base * Vector2(0.94, 1.07), 0.13)
	if wp != null:
		wind.parallel().tween_property(wp, "rotation", 2.0, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await wind.finished
	# 2) Sprint zum Gegner: nach vorn lehnen, Lauf-Frames, Geistertrail.
	var strike_pos: Vector2 = es.position + Vector2(_strike_offset(e), 0)
	var lean := create_tween()
	lean.tween_property(s, "rotation", -0.10, 0.16)
	lean.parallel().tween_property(s, "scale", base, 0.16)
	await _sprint(h, strike_pos, 0.16)
	# 3) Durchziehen: Waffe schwingt in einem Ruck durch den Gegner (mit
	# Nachbildern), der Körper macht einen Ausfallschritt hinterher.
	if wp != null:
		_weapon_trail(wp, 0.12)
		var swing := create_tween()
		swing.tween_property(wp, "rotation", -1.9, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var lunge := create_tween()
	lunge.tween_property(s, "position:x", strike_pos.x - 12.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.parallel().tween_property(s, "rotation", -0.22, 0.08)
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
	# 4) Rückzug: aufrichten, Waffe zurück in Ruhehaltung, heimsprinten.
	var settle := create_tween()
	settle.tween_property(s, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if wp != null:
		settle.parallel().tween_property(wp, "rotation", wp.get_meta("rest", WEAPON_REST), 0.18)
	await _sprint(h, h["home"], 0.22)
	s.rotation = 0.0
	s.scale = base

## Rax' Standardangriff: anhaltendes Maschinengewehrfeuer auf EINEN Gegner.
## Eine Salve schneller Leuchtspur-Schüsse (Mündungsblitz, Rückstoß, Funken,
## ratterndes MG-Geräusch). Der Gesamtschaden wird vorab gewürfelt und erst am
## Ende als eine Zahl gebucht — so gibt es nur eine Todes-/Wutprüfung und keine
## Zahlenflut, während die vielen Schüsse rein optisch/akustisch rattern.
func _rax_gun(h: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	_say("%s eröffnet das Maschinengewehrfeuer!" % d["name"])
	# In den Schützenstand schweben und einrasten (wie beim Laser).
	var fire_pos: Vector2 = h["home"] + Vector2(-58, 6)
	await _sprint(h, fire_pos, 0.2)
	h["anim"] = "aim"
	s.texture = SpriteFactory.robot_battle_pose("aim", 0)
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var snap := create_tween()
	snap.tween_property(s, "scale", base * Vector2(1.06, 0.94), 0.06)
	snap.tween_property(s, "scale", base, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await snap.finished
	# Gesamtschaden wie beim Nahkampf, nur minimal stärker (Signaturangriff).
	var rounds := 14
	var total: int = maxi(int(d["atk"] * randf_range(1.0, 1.3)) - e["def"], rounds)
	for i in rounds:
		if not e["alive"] or not is_instance_valid(es):
			break
		var muzzle: Vector2 = s.position + Vector2(-52, -6)
		var target: Vector2 = es.position + Vector2(randf_range(-12, 12), randf_range(-18, 18))
		_muzzle_flash(muzzle, (target - muzzle).angle())
		_fire_bullet(muzzle, target)
		AudioManager.play_sfx("mgun")
		# Rückstoß: der Roboter ruckelt bei jedem Schuss kurz nach hinten.
		var jit := create_tween()
		jit.tween_property(s, "position:x", fire_pos.x + 6.0, 0.03)
		jit.tween_property(s, "position:x", fire_pos.x, 0.05)
		if i % 4 == 3:
			_shake(es)
			_shake_camera(0.5)
		await get_tree().create_timer(0.055).timeout
	# Ausklang, dann der gesammelte Schaden als eine Zahl (eine Todesprüfung).
	_flash_screen(Color(1.0, 0.8, 0.4, 0.12))
	_shake_camera(1.2)
	if e["alive"]:
		await _damage_enemy(e, total)
	# Zurück in die Reihe.
	h["anim"] = "idle"
	s.texture = SpriteFactory.robot_battle_pose("idle", 0)
	s.position = fire_pos
	await _sprint(h, h["home"], 0.2)

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
	_float_text(pos + Vector2(-30, -46), "KRITISCH!", Color(1.0, 0.62, 0.1), 36)
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

## Vorbereitungspose vor einer Fähigkeit (wie beim Roboterlaser): der Held
## tritt vor und sammelt sichtbar Kraft — Zauberkreis, aufglühende Aura,
## einlaufende Funken, Wirk-Pose, Sammelton. Erst danach folgt die Wirkung.
func _stance(h: Dictionary, color: Color, sfx := "charge") -> void:
	var s: Sprite2D = h["sprite"]
	await _sprint(h, h["home"] + Vector2(-56, 4), 0.18)
	_cast_circle(s.position + Vector2(0, 40), color)
	_anim_cast(s)
	if sfx == "summon":
		_chant(s, 1.1)  # der Zauberer murmelt die Beschwörungsformel
	AudioManager.play_sfx(sfx)
	_spell_light(s.position, color, 150.0, 0.8, 1.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Aura glüht hinter der Figur auf und verlischt wieder
	var aura := Sprite2D.new()
	aura.texture = SpriteFactory.particle("light_01")
	aura.material = mat
	aura.modulate = Color(color, 0.0)
	aura.position = s.position
	aura.scale = Vector2(0.4, 0.4)
	add_child(aura)
	var at := create_tween()
	at.tween_property(aura, "modulate:a", 0.75, 0.28)
	at.parallel().tween_property(aura, "scale", Vector2(1.0, 1.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	at.tween_property(aura, "modulate:a", 0.0, 0.25)
	at.tween_callback(aura.queue_free)
	# Funken laufen von außen in die Figur
	for i in 6:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color(1, 1, 1))
		spark.material = mat
		spark.modulate = color.lightened(0.4)
		spark.position = s.position + Vector2(randf_range(-52, 52), randf_range(-46, 46))
		add_child(spark)
		var st := spark.create_tween()
		st.tween_interval(i * 0.04)
		st.tween_property(spark, "position", s.position, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.parallel().tween_property(spark, "scale", Vector2(0.3, 0.3), 0.24)
		st.tween_callback(spark.queue_free)
	await get_tree().create_timer(0.55).timeout

func _whirl_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s entfesselt %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	# Konzentration: vortreten, Kraft sammeln, dann erst der Wirbel.
	await _stance(h, Color(1.0, 0.95, 0.5))
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
	await _sprint(h, h["home"], 0.25)

func _fireball(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s wirkt %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	# Beschwörungspose: vortreten und Kraft sammeln, dann aufsteigen.
	await _stance(h, Color(1.0, 0.6, 0.2), "summon")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.82, 0.35))
	var raise := create_tween()
	raise.tween_property(s, "position:y", s.position.y - 16.0, 0.22)
	await raise.finished
	# --- Aufladung: eine glühende Feuerkugel wächst in der Hand und pulsiert ---
	var hand := s.position + Vector2(-44, -4)
	var ball := Sprite2D.new()
	ball.texture = SpriteFactory.particle("fire_01")
	ball.position = hand
	ball.scale = Vector2(0.04, 0.04)
	var bmat := CanvasItemMaterial.new()
	bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ball.material = bmat
	ball.modulate = Color(1.0, 0.62, 0.2)
	var core := Sprite2D.new()
	core.texture = SpriteFactory.particle("flare_01")
	core.scale = Vector2(0.45, 0.45)
	core.modulate = Color(1.0, 0.95, 0.7)
	ball.add_child(core)
	# Wabern: das Feuer dreht langsam, damit es lebt
	var churn := ball.create_tween().set_loops()
	churn.tween_property(core, "rotation", TAU, 1.2)
	var trail := CPUParticles2D.new()
	trail.amount = 20
	trail.lifetime = 0.4
	trail.direction = Vector2(1, 0)
	trail.spread = 30.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 40.0
	trail.initial_velocity_max = 95.0
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.45
	trail.color = Color(1.0, 0.5, 0.1, 0.8)
	trail.texture = SpriteFactory.particle("flame_02")
	ball.add_child(trail)
	add_child(ball)
	AudioManager.play_sfx("charge")
	var charge := create_tween()
	charge.tween_property(ball, "scale", Vector2(0.30, 0.30), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge.tween_property(ball, "scale", Vector2(0.26, 0.26), 0.12).set_trans(Tween.TRANS_SINE)
	await charge.finished
	# --- Abschuss: der große Feuerball rast zum Ziel und wächst dabei ---
	AudioManager.play_sfx("fire")
	var fly := create_tween()
	fly.tween_property(ball, "position", e["sprite"].position, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(ball, "scale", Vector2(0.7, 0.7), 0.34)
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
	await _sprint(h, h["home"], 0.2)

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

## Fokusstoß: Konzentration, drei blitzschnelle Durchstöße quer durch den
## Gegner (mit Körper- und Waffen-Nachbildern, Seiten im Wechsel), kurze
## Stille — dann reißt der Kreuzschnitt auf. Ignoriert die Verteidigung.
func _pierce(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s setzt %s ein!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	await _stance(h, Color(1.0, 0.95, 0.5))
	var center: Vector2 = es.position
	var grip_x: float = wp.get_meta("grip_x", -7.0) if wp != null else -7.0
	var passes := [
		[center + Vector2(96, -10), center + Vector2(-98, 8)],
		[center + Vector2(-98, 16), center + Vector2(96, -14)],
		[center + Vector2(98, 12), center + Vector2(-96, -10)],
	]
	for p: Array in passes:
		var from: Vector2 = p[0]
		var to: Vector2 = p[1]
		var dir_right: bool = to.x > from.x
		# Blitz-Reposition zur Startseite, Klinge nach vorn gerichtet.
		s.position = from
		s.flip_h = not dir_right
		if wp != null:
			wp.position.x = -grip_x if dir_right else grip_x
			wp.rotation = 1.35 if dir_right else -1.35
		_burst(from, Color(1.0, 0.98, 0.8, 0.7), 5, 60)
		var dash := create_tween()
		dash.tween_property(s, "position", to, 0.11) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(s, 0.11)
		if wp != null:
			_weapon_trail(wp, 0.11)
		AudioManager.play_sfx("slash")
		_slash_arc(center + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
		_burst(center, Color(1.0, 0.95, 0.6), 7, 110)
		await dash.finished
		await get_tree().create_timer(0.05).timeout
	# Landen, Waffe senken, ein Atemzug Stille ...
	s.flip_h = true
	if wp != null:
		wp.position.x = grip_x
		wp.rotation = wp.get_meta("rest", WEAPON_REST)
	s.position = center + Vector2(-96, 0)
	await get_tree().create_timer(0.26).timeout
	# ... dann reißt der Kreuzschnitt auf.
	_cross_slash(center)
	AudioManager.play_sfx("bigboom")
	_impact_ring(es.position, Color(1.0, 0.95, 0.5, 0.8))
	_shake_camera(1.8)
	var crit := randf() < 0.12
	await _hitstop(0.12 if crit else 0.08)
	var dmg: int = int((ab["power"] + d["atk"]) * randf_range(0.95, 1.15) * (1.6 if crit else 1.0))
	if crit:
		_crit_fx(es.position)
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.22)

## Serenas Klingentanz: fünf Blitzschritte im Pentagramm um das Ziel,
## dann steigt sie auf und fährt mit dem Fallstreich nieder.
func _blade_dance(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	_say("%s tanzt den %s!" % [d["name"], ab["name"]])
	var s: Sprite2D = h["sprite"]
	var es: Sprite2D = e["sprite"]
	var wp: Sprite2D = h["weapon"]
	await _stance(h, Color(0.75, 0.60, 1.0))
	var center: Vector2 = es.position
	var grip_x: float = wp.get_meta("grip_x", -7.0) if wp != null else -7.0
	# Fünf Schnitte: Startpunkte in Pentagramm-Reihenfolge um das Ziel,
	# jeder Schritt schneidet durchs Zentrum.
	for i in 5:
		if not e["alive"]:
			break
		var ang := -PI / 2.0 + i * (TAU * 2.0 / 5.0)
		var from := center + Vector2(cos(ang), sin(ang) * 0.7) * 120.0
		var to := center - (from - center) * 0.9
		var dir_right: bool = to.x > from.x
		s.position = from
		s.flip_h = not dir_right
		if wp != null:
			wp.position.x = -grip_x if dir_right else grip_x
			wp.rotation = 1.35 if dir_right else -1.35
		_burst(from, Color(0.80, 0.65, 1.0, 0.7), 5, 60)
		var dash := create_tween()
		dash.tween_property(s, "position", to, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_ghost_trail(s, 0.10)
		if wp != null:
			_weapon_trail(wp, 0.10)
		AudioManager.play_sfx("slash")
		_slash_arc(center + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
		_star_sparks(center)
		await dash.finished
		var pass_dmg := maxi(int((ab["power"] + d["atk"] * 0.35) * randf_range(0.9, 1.1)), 1)
		await _damage_enemy(e, pass_dmg)
	# Waffe in Ruheposition, Blick wieder nach links
	s.flip_h = true
	if wp != null:
		wp.position.x = grip_x
		wp.rotation = wp.get_meta("rest", WEAPON_REST)
	if not e["alive"]:
		# Das Ziel fiel schon im Tanz — elegant zurückgleiten.
		await _sprint(h, h["home"], 0.22)
		return
	# Finisher: hoch über das Ziel steigen, ein Atemzug ...
	AudioManager.play_sfx("whirl")
	var leap := create_tween()
	leap.tween_property(s, "position", center + Vector2(10, -240), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ghost_trail(s, 0.28)
	await leap.finished
	await get_tree().create_timer(0.18).timeout
	# ... dann der Fallstreich
	if wp != null:
		wp.rotation = 2.4
		_weapon_trail(wp, 0.14)
	var slam := create_tween()
	slam.tween_property(s, "position", center + Vector2(6, -6), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ghost_trail(s, 0.13)
	await slam.finished
	AudioManager.play_sfx("bigboom")
	_flash_screen(Color(0.85, 0.75, 1.0, 0.35))
	_impact_ring(es.position, Color(0.80, 0.65, 1.0, 0.8))
	_cross_slash(center)
	_shake_camera(2.0)
	var crit := randf() < 0.18
	await _hitstop(0.14 if crit else 0.09)
	if crit:
		_crit_fx(es.position)
	var dmg: int = int((ab["power"] * 2.5 + d["atk"]) * randf_range(0.95, 1.15) * (1.6 if crit else 1.0))
	await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.24)

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

## Laserstoß: Kanone lädt cyan auf, dann ein gebündelter Strahl auf einen Gegner.
func _laser(h: Dictionary, ab: Dictionary, e: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s feuert %s!" % [d["name"], ab["name"]])
	# 1) In Schussposition schweben und in den breiten Stand einrasten.
	var fire_pos: Vector2 = h["home"] + Vector2(-64, 6)
	await _sprint(h, fire_pos, 0.2)
	h["anim"] = "aim"
	s.texture = SpriteFactory.robot_battle_pose("aim", 0)
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	var snap := create_tween()
	snap.tween_property(s, "scale", base * Vector2(1.06, 0.94), 0.06)
	snap.tween_property(s, "scale", base, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var muzzle := _cannon_muzzle(s)
	# 2) Aufladen: wachsende, bebende Energiekugel, Funken laufen in die
	# Mündung, dazu Licht und steigender Ladeton.
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
	_spell_light(muzzle, Color(0.5, 0.9, 1.0), 150.0, 0.85, 1.0)
	for i in 9:
		var spark := Sprite2D.new()
		spark.texture = SpriteFactory.circle(3, Color(0.7, 0.97, 1.0))
		spark.material = m
		spark.position = muzzle + Vector2(randf_range(-46, 46), randf_range(-40, 40))
		add_child(spark)
		var st := spark.create_tween()
		st.tween_interval(i * 0.05)
		st.tween_property(spark, "position", muzzle, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.parallel().tween_property(spark, "scale", Vector2(0.3, 0.3), 0.28)
		st.tween_callback(spark.queue_free)
	var ct := chg.create_tween()
	ct.tween_property(chg, "scale", Vector2(1.2, 1.2), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.tween_property(chg, "scale", Vector2(1.5, 1.4), 0.09)
	ct.tween_property(chg, "scale", Vector2(1.35, 1.5), 0.08)
	ct.tween_property(chg, "scale", Vector2(1.7, 1.7), 0.08)
	await ct.finished
	chg.queue_free()
	# 3) Feuern: Mündungsblitz, Strahl, Rückstoß schiebt Rax nach hinten.
	var target: Vector2 = e["sprite"].position
	AudioManager.play_sfx("laser")
	_beam(muzzle, target, Color(0.45, 0.95, 1.0, 0.9), 18.0, 0.18)
	_burst(muzzle, Color(0.7, 0.97, 1.0), 8, 90)
	var recoil := create_tween()
	recoil.tween_property(s, "position:x", fire_pos.x + 16.0, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil.tween_property(s, "position:x", fire_pos.x, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_impact_ring(target, Color(0.6, 0.97, 1.0, 0.85))
	_burst(target, Color(0.6, 0.95, 1.0), 18, 180)
	_flash_screen(Color(0.4, 0.85, 1.0, 0.20))
	_shake_camera(1.7)
	await _hitstop(0.10)
	var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.9, 1.15)) - e["def"] / 2
	await _damage_enemy(e, maxi(dmg, 1))
	# 4) Zurück in die Reihe.
	h["anim"] = "idle"
	s.texture = SpriteFactory.robot_battle_pose("idle", 0)
	await _sprint(h, h["home"], 0.2)

## Eine einzelne Rakete: steigt erst steil aus dem Rohr, kippt dann entlang
## einer Bézier-Bahn ins Ziel und detoniert beim Aufprall. Das Sprite dreht
## sich in Flugrichtung, das Abgas flackert in 2 Frames, Rauch bleibt hängen.
func _launch_rocket(from: Vector2, to: Vector2) -> void:
	var r := Sprite2D.new()
	r.texture = SpriteFactory.rocket(0)
	r.scale = Vector2(2.0, 2.0)
	r.position = from
	# Weicher Feuerschweif: additives Kenney-Flammen-Sprite hinter der Düse.
	var exhaust := Sprite2D.new()
	exhaust.texture = SpriteFactory.particle("flame_05")
	exhaust.rotation = -PI / 2  # Flamme zeigt nach links (nach hinten)
	exhaust.position = Vector2(-16, 0)
	exhaust.scale = Vector2(0.16, 0.30)
	exhaust.modulate = Color(1.0, 0.75, 0.35, 0.95)
	var exm := CanvasItemMaterial.new()
	exm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	exhaust.material = exm
	r.add_child(exhaust)
	# Rauchfaden: eigenständiger Emitter (KEIN Kind der Rakete), der ihr am
	# Heck folgt und träge, lang lebende Puffs ablegt — die Flugbahn bleibt
	# als hängender Faden in der Luft stehen und verweht nach dem Einschlag.
	var smoke := CPUParticles2D.new()
	smoke.amount = 90
	smoke.lifetime = 1.9
	smoke.direction = Vector2(0, -1)
	smoke.spread = 180.0
	smoke.gravity = Vector2(0, -12)
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 8.0
	smoke.scale_amount_min = 0.05
	smoke.scale_amount_max = 0.11
	smoke.color = Color(0.85, 0.84, 0.82, 0.6)
	smoke.texture = SpriteFactory.particle("smoke_07")
	smoke.position = from
	add_child(smoke)
	add_child(r)
	# Mündungsblitz am Startrohr
	var muzzle := Sprite2D.new()
	muzzle.texture = SpriteFactory.particle("muzzle_02")
	muzzle.position = from
	muzzle.rotation = (to - from).angle() - PI / 2
	muzzle.scale = Vector2(0.4, 0.4)
	muzzle.material = exm
	muzzle.modulate = Color(1.0, 0.85, 0.5)
	add_child(muzzle)
	var mt := muzzle.create_tween()
	mt.tween_property(muzzle, "modulate:a", 0.0, 0.12)
	mt.tween_callback(muzzle.queue_free)
	# Abgasflamme flackern lassen
	var flick := create_tween().set_loops()
	flick.tween_interval(0.05)
	flick.tween_callback(func():
		r.texture = SpriteFactory.rocket(randi() % 2)
		exhaust.scale = Vector2(randf_range(0.13, 0.19), randf_range(0.26, 0.36)))
	# Quadratische Bézier-Bahn: Kontrollpunkt hoch über dem Startrohr →
	# steiler Aufstieg, dann Sturz ins Ziel.
	var ctrl := from + Vector2(randf_range(-40, 10), -randf_range(110, 170))
	var dur := randf_range(0.62, 0.78)
	var tw := create_tween()
	tw.tween_method(_rocket_step.bind(r, smoke, from, ctrl, to), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		flick.kill()
		r.queue_free()
		_explosion(to, 1.15)
		_spell_light(to, Color(1.0, 0.6, 0.25), 160.0, 0.4)
		AudioManager.play_sfx("boom")
		_shake_camera(1.2)
		# Der Rauchfaden bleibt stehen und verweht von selbst.
		smoke.emitting = false
		get_tree().create_timer(2.0).timeout.connect(smoke.queue_free))

## Ein Schritt auf der Bézier-Bahn einer Rakete: Position + Blickrichtung;
## der Rauch-Emitter hängt am Heck (gegen die Flugrichtung versetzt).
func _rocket_step(t: float, r: Sprite2D, smoke: CPUParticles2D,
		from: Vector2, ctrl: Vector2, to: Vector2) -> void:
	if not is_instance_valid(r):
		return
	var u := 1.0 - t
	r.position = u * u * from + 2.0 * u * t * ctrl + t * t * to
	var deriv: Vector2 = 2.0 * u * (ctrl - from) + 2.0 * t * (to - ctrl)
	r.rotation = deriv.angle()
	if is_instance_valid(smoke):
		smoke.position = r.position - deriv.normalized() * 20.0

## Raketensalve: zwei Wellen kleiner Raketen auf alle Gegner.
func _rocket_all(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s startet %s!" % [d["name"], ab["name"]])
	# In Feuerposition schweben und den Schützenstand einnehmen.
	await _sprint(h, h["home"] + Vector2(-58, 6), 0.2)
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.6, 0.2))
	h["anim"] = "aim"
	s.texture = SpriteFactory.robot_battle_pose("aim", 0)
	AudioManager.play_sfx("charge")
	await get_tree().create_timer(0.4).timeout
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
	# Warten, bis auch die langsamen Raketen eingeschlagen sind.
	await get_tree().create_timer(0.8).timeout
	h["anim"] = "idle"
	s.texture = SpriteFactory.robot_battle_pose("idle", 0)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["mag"] * 0.7) * randf_range(0.9, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	await _sprint(h, h["home"], 0.2)

## Atombombe: Rax markiert alle Ziele, ein Sprengkopf fällt pfeifend vom
## Himmel — Weißblitz, Schockwelle, Atompilz, massiver Flächenschaden.
func _nuke(h: Dictionary, ab: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	_say("%s fordert %s an!" % [d["name"], ab["name"]])
	# Vortreten und den Uplink aufbauen (Schützenstand, Antenne dauerrot).
	await _sprint(h, h["home"] + Vector2(-58, 6), 0.2)
	h["anim"] = "aim"
	s.texture = SpriteFactory.robot_battle_pose("aim", 0)
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	if alive.is_empty():
		return
	var center := Vector2.ZERO
	for e in alive:
		center += (e["sprite"] as Sprite2D).position
	center /= alive.size()
	# Zielmarkierung + Warnton
	for e in alive:
		_target_reticle(e["sprite"].position)
	AudioManager.play_sfx("alarm")
	await get_tree().create_timer(0.6).timeout
	# Bombe fällt pfeifend und leicht taumelnd, Zünderlicht blinkt.
	var b := Sprite2D.new()
	b.texture = SpriteFactory.bomb(0)
	b.scale = Vector2(3.4, 3.4)
	b.position = Vector2(center.x + 36, -60)
	b.rotation = -0.15
	add_child(b)
	var blink := create_tween().set_loops()
	blink.tween_interval(0.07)
	blink.tween_callback(func():
		b.texture = SpriteFactory.bomb(randi() % 2))
	AudioManager.play_sfx("whistle")
	var fall := create_tween()
	fall.tween_property(b, "position", center + Vector2(0, 14), 0.92) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(b, "rotation", 0.2, 0.92) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fall.finished
	blink.kill()
	b.queue_free()
	# Detonation: langer Weißblitz, alles bebt — und zwar richtig.
	AudioManager.play_sfx("nuke")
	_flash_screen(Color(1, 1, 1, 0.95))
	_shockwave(center)
	_shake_camera(3.6)
	_punch_zoom(0.2, center)
	_explosion(center, 3.4)
	for e in alive:
		_explosion((e["sprite"] as Sprite2D).position, 1.6)
	_mushroom_cloud(center, 1.6)
	# Nachschlag: zweite Druckwelle + zweite Explosion, wenn der Blitz abklingt.
	get_tree().create_timer(0.55).timeout.connect(func():
		_shockwave(center + Vector2(30, -20))
		_explosion(center + Vector2(randf_range(-50, 50), randf_range(-30, 10)), 2.0)
		_shake_camera(2.2))
	# Hitzeflimmern über dem Schlachtfeld, solange der Pilz steht.
	var haze := ColorRect.new()
	haze.position = Vector2(20, 90)
	haze.size = Vector2(470, 330)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.material = Fx.heat_haze_material()
	ui_layer.add_child(haze)
	ui_layer.move_child(haze, 3)
	get_tree().create_timer(2.0).timeout.connect(haze.queue_free)
	await _hitstop(0.2)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((ab["power"] + d["mag"]) * randf_range(0.95, 1.15)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	h["anim"] = "idle"
	s.texture = SpriteFactory.robot_battle_pose("idle", 0)
	await _sprint(h, h["home"], 0.2)

## Atompilz: heißer Stamm wächst hoch, glühende Kappe wölbt sich auf,
## Glutpartikel steigen — alles additiv und selbstaufräumend.
## `size` skaliert Höhe, Breite und Partikelmenge.
func _mushroom_cloud(pos: Vector2, size := 1.0) -> void:
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var stem := Sprite2D.new()
	stem.texture = SpriteFactory.circle(24, Color(1.0, 0.62, 0.25, 0.75))
	stem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stem.material = addm
	stem.position = pos
	stem.scale = Vector2(1.2 * size, 0.4)
	add_child(stem)
	var st := create_tween()
	st.tween_property(stem, "scale", Vector2(1.5, 4.8) * size, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	st.parallel().tween_property(stem, "position:y", pos.y - 80.0 * size, 0.8)
	st.tween_property(stem, "modulate:a", 0.0, 0.9)
	st.tween_callback(stem.queue_free)
	# Glühende Pilzkappe aus echten Rauch-Puffs (additiv = Feuerschein) ...
	for i in 6:
		var puff := Sprite2D.new()
		puff.texture = SpriteFactory.particle("smoke_04")
		puff.material = addm
		puff.modulate = Color(1.0, lerpf(0.75, 0.45, i / 5.0), 0.2, 0.85)
		puff.position = pos + Vector2(randf_range(-8, 8), -10)
		puff.rotation = randf_range(0.0, TAU)
		puff.scale = Vector2(0.12, 0.12)
		add_child(puff)
		var side := randf_range(-52, 52) * (0.4 + i * 0.15) * size
		var pt := create_tween()
		pt.tween_interval(0.12 + i * 0.05)
		pt.tween_property(puff, "position", pos + Vector2(side, (-152.0 - i * 14.0) * size), 1.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(puff, "scale", Vector2.ONE * (0.5 + i * 0.09) * size, 1.1)
		pt.parallel().tween_property(puff, "rotation", puff.rotation + randf_range(-0.8, 0.8), 1.1)
		pt.parallel().tween_property(puff, "modulate:a", 0.0, 1.3)
		pt.tween_callback(puff.queue_free)
	# ... darüber dunkler Nachrauch, der träge weiterzieht
	for i in 4:
		var gray := Sprite2D.new()
		gray.texture = SpriteFactory.particle("smoke_04")
		gray.modulate = Color(0.35, 0.33, 0.33, 0.0)
		gray.position = pos + Vector2(randf_range(-24, 24), (-60.0 - i * 22.0) * size)
		gray.rotation = randf_range(0.0, TAU)
		gray.scale = Vector2(0.25, 0.25) * size
		add_child(gray)
		var gt := create_tween()
		gt.tween_interval(0.5 + i * 0.2)
		gt.tween_property(gray, "modulate:a", 0.5, 0.4)
		gt.parallel().tween_property(gray, "position:y", gray.position.y - 95.0 * size, 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		gt.parallel().tween_property(gray, "scale", Vector2(0.7, 0.7) * size, 2.0)
		gt.tween_property(gray, "modulate:a", 0.0, 0.8)
		gt.tween_callback(gray.queue_free)
	var emb := CPUParticles2D.new()
	emb.position = pos
	emb.amount = int(40 * size)
	emb.lifetime = 1.2
	emb.one_shot = true
	emb.explosiveness = 0.9
	emb.direction = Vector2(0, -1)
	emb.spread = 55.0
	emb.gravity = Vector2(0, -60)
	emb.initial_velocity_min = 60.0 * size
	emb.initial_velocity_max = 190.0 * size
	emb.color = Color(1.0, 0.55, 0.15, 0.9)
	emb.texture = SpriteFactory.circle(2, Color.WHITE)
	emb.emitting = true
	add_child(emb)
	get_tree().create_timer(2.4).timeout.connect(emb.queue_free)
	_spell_light(pos, Color(1.0, 0.6, 0.2), 420.0 * size, 1.4, 2.0)

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
	col.color = Fx.hot(Color(0.6, 0.95, 1.0, 0.85))
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
	if h.get("bob") != null:
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
	_punch_zoom(0.12, Vector2(280, 250))
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
	if h.get("bob") != null:
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
	_punch_zoom(0.12, Vector2(280, 250))
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
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.55)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.55, 0.15))
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.8, 0.3))
	_chant(s, 1.3)
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
	# Gesteinsbrocken prasseln über das GANZE Feld: jeder zweite gezielt auf
	# einen Gegner, der Rest schlägt wahllos zwischen den Reihen ein.
	for i in 13:
		var impact: Vector2
		if i % 2 == 0 and alive.size() > 0:
			var target: Dictionary = alive[(i / 2) % alive.size()]
			impact = target["sprite"].position + Vector2(randf_range(-40, 40), randf_range(-24, 24))
		else:
			impact = Vector2(randf_range(60, 900), randf_range(230, 390))
		var big := randf_range(2.2, 3.8)  # Brocken unterschiedlicher Größe
		var meteor := Sprite2D.new()
		meteor.texture = SpriteFactory.meteor_rock(i)
		meteor.scale = Vector2(big, big)
		meteor.rotation = randf_range(-0.4, 0.4)
		# Feuerschweif: additive Flamme, die dem Brocken nach oben rechts folgt
		var tail := Sprite2D.new()
		tail.texture = SpriteFactory.particle("flame_05")
		tail.rotation = PI * 0.25  # zeigt nach oben rechts (gegen Flugrichtung)
		tail.position = Vector2(14, -12)
		tail.scale = Vector2(0.2, 0.45)
		tail.modulate = Color(1.0, 0.6, 0.2, 0.9)
		var tmat := CanvasItemMaterial.new()
		tmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		tail.material = tmat
		meteor.add_child(tail)
		var trail := CPUParticles2D.new()
		trail.amount = 18
		trail.lifetime = 0.4
		trail.direction = Vector2(1, -1)
		trail.spread = 24.0
		trail.gravity = Vector2.ZERO
		trail.initial_velocity_min = 50.0
		trail.initial_velocity_max = 110.0
		trail.scale_amount_min = 0.06
		trail.scale_amount_max = 0.14
		trail.color = Color(1.0, 0.55, 0.1, 0.8)
		trail.texture = SpriteFactory.particle("smoke_07")
		meteor.add_child(trail)
		meteor.position = impact + Vector2(randf_range(140, 300), -440)
		add_child(meteor)
		if i % 2 == 0:
			AudioManager.play_sfx("meteor")
		var dur := randf_range(0.34, 0.48)
		var fall := create_tween()
		fall.tween_property(meteor, "position", impact, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Nur leicht taumeln — der Feuerschweif ist ein Kind und würde bei
		# starker Drehung plötzlich in Flugrichtung zeigen.
		fall.parallel().tween_property(meteor, "rotation", meteor.rotation + randf_range(0.25, 0.6), dur)
		fall.tween_callback(func():
			meteor.queue_free()
			_explosion(impact, 0.9 + big * 0.16)
			AudioManager.play_sfx("boom")
			_shake_camera(1.5))
		await get_tree().create_timer(0.11).timeout
	await get_tree().create_timer(0.5).timeout
	_flash_screen(Color(1.0, 0.6, 0.2, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.4)
	_punch_zoom(0.12, Vector2(280, 250))
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

## ---------- Beschwörungen (Milo): Ifrit & Leviathan ----------

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

## Beschwörungsportal am Boden: doppelter Zauberkreis, Ring und aufsteigende Funken.
func _summon_portal(pos: Vector2, color: Color) -> void:
	AudioManager.play_sfx("summon")
	_cast_circle(pos, color)
	_cast_circle(pos, color.lightened(0.35))
	_impact_ring(pos, color)
	var motes := CPUParticles2D.new()
	motes.position = pos
	motes.amount = 26
	motes.lifetime = 0.9
	motes.one_shot = true
	motes.explosiveness = 0.2
	motes.direction = Vector2(0, -1)
	motes.spread = 26.0
	motes.gravity = Vector2(0, -60)
	motes.initial_velocity_min = 60.0
	motes.initial_velocity_max = 140.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.3
	motes.color = Color(color.r, color.g, color.b, 0.9)
	motes.texture = SpriteFactory.circle(4, Color.WHITE)
	add_child(motes)
	motes.emitting = true
	get_tree().create_timer(1.4).timeout.connect(motes.queue_free)

## Feuersäule, die unter einem Gegner aus dem Boden bricht (Ifrits Höllenfeuer).
func _fire_pillar(pos: Vector2) -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var col := Polygon2D.new()
	var w := 30.0
	col.polygon = PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0),
		Vector2(w, -430), Vector2(-w, -430)])
	col.color = Fx.hot(Color(1.0, 0.5, 0.12, 0.9))
	col.position = pos + Vector2(0, 34)
	col.material = m
	col.scale = Vector2(1, 0.04)
	add_child(col)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-w * 0.22, 0), Vector2(w * 0.22, 0),
		Vector2(w * 0.4, -420), Vector2(-w * 0.4, -420)])
	core.color = Fx.hot(Color(1.0, 0.9, 0.5, 0.95), 1.4)
	core.material = m
	col.add_child(core)
	var tw := create_tween()
	tw.tween_property(col, "scale:y", 1.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.16)
	tw.tween_property(col, "modulate:a", 0.0, 0.3)
	tw.tween_callback(col.queue_free)
	_spell_light(pos, Color(1.0, 0.55, 0.15), 260.0, 0.55, 1.5)

## Ifrit: Feuerportal, der Dämon steigt aus dem Boden, Höllenfeuer-Eruption
## unter allen Gegnern. Wiederholbar (MP), freigeschaltet ab Stufe 3.
func _summon_ifrit(h: Dictionary, sm: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var org := Color(1.0, 0.55, 0.15)
	_say("%s beschwört %s!" % [d["name"], sm["name"]])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.65)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), org)
	_cast_circle(s.position + Vector2(0, 40), Color(1.0, 0.8, 0.3))
	_anim_cast(s)
	_chant(s, 1.8)
	s.modulate = Color(1.5, 1.2, 0.9)
	var rise := create_tween()
	rise.tween_property(s, "position:y", s.position.y - 30.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("◈ IFRIT ◈", org)
	var gate := Vector2(455, 372)
	_punch_zoom(0.10, gate + Vector2(0, -110))
	_summon_portal(gate, org)
	# Boden birst: dunkle Gesteinskeile fliegen aus dem Portal
	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, -14)])
		shard.color = Color(0.18, 0.12, 0.14)
		shard.position = gate
		shard.rotation = randf_range(-0.5, 0.5)
		add_child(shard)
		var stw := create_tween()
		stw.tween_property(shard, "position", gate +
			Vector2(randf_range(-90, 90), randf_range(-120, -30)), 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(shard, "modulate:a", 0.0, 0.5)
		stw.tween_callback(shard.queue_free)
	await get_tree().create_timer(0.55).timeout
	# Ifrit steigt aus dem Feuer, Frames werden lebendig getickt
	var ifr := Sprite2D.new()
	ifr.texture = SpriteFactory.ifrit(0)
	ifr.position = gate + Vector2(0, 130)
	ifr.scale = Vector2(4.6, 4.6)
	ifr.modulate = Color(0.4, 0.2, 0.2, 0.0)
	add_child(ifr)
	# Ifrits Präsenz beleuchtet die Arena (Kind → skaliert mit dem Sprite)
	var ilight := Fx.point_light(Color(1.0, 0.55, 0.2), 65.0, 1.4)
	ifr.add_child(ilight)
	Fx.flicker(ilight, 1.4)
	var fr := [0]
	var tick := Timer.new()
	tick.wait_time = 0.16
	tick.autostart = true
	ifr.add_child(tick)
	tick.timeout.connect(func():
		fr[0] += 1
		ifr.texture = SpriteFactory.ifrit(fr[0]))
	AudioManager.play_sfx("roar")
	_burst(gate, org, 22, 190)
	_explosion(gate, 1.1)
	_shake_camera(1.2)
	var up := create_tween()
	up.tween_property(ifr, "position", gate + Vector2(0, -105), 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	up.parallel().tween_property(ifr, "modulate", Color(1.25, 1.05, 0.9, 1.0), 0.4)
	await up.finished
	# Aufladen: Glutschein hinter dem Dämon schwillt an
	var glow := Sprite2D.new()
	glow.texture = SpriteFactory.circle(60, Color(1.0, 0.45, 0.12, 0.5))
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.position = ifr.position
	glow.z_index = -1
	glow.scale = Vector2(0.3, 0.3)
	add_child(glow)
	AudioManager.play_sfx("charge")
	var gtw := create_tween()
	gtw.tween_property(glow, "scale", Vector2(3.2, 3.2), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.55).timeout
	_ult_banner("HÖLLENFEUER", Color(1.0, 0.75, 0.25))
	glow.queue_free()
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	# Hitzeflimmern über der Gegnerzone, solange die Eruption tobt
	var haze := ColorRect.new()
	haze.position = Vector2(40, 120)
	haze.size = Vector2(430, 300)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.material = Fx.heat_haze_material()
	ui_layer.add_child(haze)
	ui_layer.move_child(haze, 3)
	get_tree().create_timer(1.8).timeout.connect(haze.queue_free)
	# Eruption: gestaffelte Feuersäulen unter jedem Gegner
	for e in alive:
		var pos: Vector2 = e["sprite"].position
		_cast_circle(pos + Vector2(0, 34), Color(1.0, 0.3, 0.1))
		_fire_pillar(pos)
		_explosion(pos, 1.3)
		AudioManager.play_sfx("eruption")
		_shake_camera(1.4)
		await get_tree().create_timer(0.14).timeout
	await get_tree().create_timer(0.3).timeout
	_flash_screen(Color(1.0, 0.55, 0.15, 0.6))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	_punch_zoom(0.12, Vector2(300, 280))
	await _hitstop(0.14)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 1.7 + sm["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	# Ifrit verglüht nach oben
	_burst(ifr.position, org, 26, 170)
	var out := create_tween()
	out.tween_property(ifr, "modulate", Color(1.6, 0.8, 0.4, 0.0), 0.5)
	out.parallel().tween_property(ifr, "position:y", ifr.position.y - 60.0, 0.5)
	out.tween_callback(ifr.queue_free)
	s.modulate = Color.WHITE
	_undim(dim)
	var back := create_tween()
	back.tween_property(s, "position", h["home"], 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	h["bob"] = _idle_bob(s, 2.0)

## Baut den modularen Schlangenkörper: Kopf, Segmente, Schwanz als Kinder.
func _leviathan_body(scale_f: float) -> Node2D:
	var body := Node2D.new()
	var parts: Array = []
	var tail := Sprite2D.new()
	tail.texture = SpriteFactory.leviathan_tail(0)
	var segs := 10
	for i in range(segs, 0, -1):
		var seg := Sprite2D.new()
		seg.texture = SpriteFactory.leviathan_segment(i % 4)
		seg.scale = Vector2.ONE * scale_f * (0.75 + 0.25 * (1.0 - float(i) / segs))
		seg.visible = false
		body.add_child(seg)
	tail.scale = Vector2.ONE * scale_f * 0.75
	tail.visible = false
	body.add_child(tail)
	var head := Sprite2D.new()
	head.texture = SpriteFactory.leviathan_head(0)
	head.scale = Vector2.ONE * scale_f
	head.visible = false
	var hlight := Fx.point_light(Color(0.4, 0.9, 1.0), 55.0, 1.2)
	head.add_child(hlight)
	Fx.pulse(hlight, 1.2, 0.9)
	body.add_child(head)
	# Reihenfolge für die Kurven-Platzierung: Kopf zuerst, dann Segmente, Schwanz
	parts.append(head)
	for i in segs:
		parts.append(body.get_child(segs - 1 - i))
	parts.append(tail)
	body.set_meta("parts", parts)
	return body

## Platziert alle Schlangenteile entlang einer Bogenkurve mit Sinus-Schlängeln.
func _serpent_place(body: Node2D, t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var parts: Array = body.get_meta("parts")
	for i in parts.size():
		var ti: float = t - float(i) * 0.045
		var node: Sprite2D = parts[i]
		if ti <= 0.0 or ti >= 1.0:
			node.visible = ti > 0.0
			continue
		node.visible = true
		var u := 1.0 - ti
		var pos: Vector2 = p0 * u * u + p1 * 2.0 * u * ti + p2 * ti * ti
		var der: Vector2 = (p1 - p0) * 2.0 * u + (p2 - p1) * 2.0 * ti
		var dir := der.normalized()
		var ripple := sin(t * 9.0 - float(i) * 0.8) * 12.0 * minf(1.0, ti * 4.0)
		node.position = pos + Vector2(-dir.y, dir.x) * ripple
		node.rotation = dir.angle()
		node.flip_v = absf(node.rotation) > PI * 0.55
		var f := int(t * 14.0 + i) % 4
		if i == 0:
			node.texture = SpriteFactory.leviathan_head(f)
		elif i == parts.size() - 1:
			node.texture = SpriteFactory.leviathan_tail(f)
		else:
			node.texture = SpriteFactory.leviathan_segment(f)

## Leviathan: die Arena flutet, die Seeschlange bricht aus dem Strudel und
## fegt über die Gegner, dann begräbt eine Flutwelle alles. Ab Stufe 5.
func _summon_leviathan(h: Dictionary, sm: Dictionary) -> void:
	var d: Dictionary = h["data"]
	var s: Sprite2D = h["sprite"]
	var blue := Color(0.4, 0.8, 1.0)
	_say("%s beschwört %s!" % [d["name"], sm["name"]])
	if h.get("bob") != null:
		(h["bob"] as Tween).kill()
	var dim := _dim_world(0.6)
	AudioManager.play_sfx("ult_charge")
	_cast_circle(s.position + Vector2(0, 40), blue)
	_cast_circle(s.position + Vector2(0, 40), Color(0.7, 0.95, 1.0))
	_anim_cast(s)
	_chant(s, 1.8)
	s.modulate = Color(0.9, 1.2, 1.6)
	var rise := create_tween()
	rise.tween_property(s, "position:y", s.position.y - 30.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	_ult_banner("◈ LEVIATHAN ◈", blue)
	_punch_zoom(0.08, Vector2(400, 330))
	# Die Arena läuft mit Wasser voll (echter Shimmer-Shader)
	var water := Polygon2D.new()
	water.polygon = PackedVector2Array([Vector2(0, 0), Vector2(960, 0),
		Vector2(960, 220), Vector2(0, 220)])
	water.color = Color(0.25, 0.55, 0.85, 0.55)
	water.material = Fx.water_material()
	water.position = Vector2(0, 560)
	water.z_index = -2
	add_child(water)
	AudioManager.play_sfx("wave")
	var flood := create_tween()
	flood.tween_property(water, "position:y", 350.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flood.finished
	# Strudel, dann bricht die Schlange heraus und stürzt über die Gegnerreihe
	var pool := Vector2(260, 372)
	_summon_portal(pool, blue)
	_impact_ring(pool, Color(0.7, 0.95, 1.0))
	await get_tree().create_timer(0.4).timeout
	var serp := _leviathan_body(4.0)
	add_child(serp)
	AudioManager.play_sfx("roar")
	AudioManager.play_sfx("splash")
	_burst(pool, Color(0.75, 0.92, 1.0), 30, 240)
	_shake_camera(1.6)
	var p0 := pool + Vector2(-20, 40)
	var p1 := Vector2(180, -70)
	var p2 := Vector2(640, 430)
	var alive := []
	for e in enemies:
		if e["alive"]:
			alive.append(e)
	var hit_done := {}
	var step := func(t: float) -> void:
		_serpent_place(serp, t, p0, p1, p2)
		# Beim Überflug: Gischt und Ringe über jedem Gegner
		var u := 1.0 - t
		var head_pos: Vector2 = p0 * u * u + p1 * 2.0 * u * t + p2 * t * t
		for e in alive:
			var key: int = e["sprite"].get_instance_id()
			if not hit_done.has(key) and absf(head_pos.x - e["sprite"].position.x) < 40.0:
				hit_done[key] = true
				_impact_ring(e["sprite"].position, blue)
				_burst(e["sprite"].position + Vector2(0, -20), Color(0.75, 0.92, 1.0), 14, 150)
				AudioManager.play_sfx("splash")
	var sweep := create_tween()
	sweep.tween_method(step, 0.0, 1.0, 1.7)
	await sweep.finished
	_burst(p2 + Vector2(0, -40), Color(0.75, 0.92, 1.0), 26, 220)
	serp.queue_free()
	await get_tree().create_timer(0.15).timeout
	# Flutwellen-Finale: eine Wasserwand fegt von rechts über die Gegner
	var wave := Polygon2D.new()
	wave.polygon = PackedVector2Array([Vector2(0, 0), Vector2(90, -80),
		Vector2(150, -220), Vector2(235, -245), Vector2(310, -140),
		Vector2(370, -40), Vector2(410, 0)])
	wave.color = Color(0.3, 0.6, 0.92, 0.85)
	wave.material = Fx.water_material()
	# Steigt mittig aus der Flut auf (rechts der Gegner, links der Helden)
	# und bricht dann nach links über die Gegnerreihe.
	wave.position = Vector2(255, 470)
	wave.scale = Vector2(1, 0.05)
	wave.z_index = 1
	add_child(wave)
	var foam := CPUParticles2D.new()
	foam.position = Vector2(190, -230)
	foam.amount = 40
	foam.lifetime = 0.4
	foam.direction = Vector2(-1, -0.3)
	foam.spread = 30.0
	foam.gravity = Vector2(0, 240)
	foam.initial_velocity_min = 120.0
	foam.initial_velocity_max = 260.0
	foam.scale_amount_min = 0.6
	foam.scale_amount_max = 1.6
	foam.color = Color(0.9, 0.97, 1.0, 0.9)
	foam.texture = SpriteFactory.circle(4, Color.WHITE)
	wave.add_child(foam)
	foam.emitting = true
	AudioManager.play_sfx("wave")
	var wtw := create_tween()
	wtw.tween_property(wave, "scale:y", 1.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wtw.tween_property(wave, "position:x", -560.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.45).timeout
	_flash_screen(Color(0.5, 0.8, 1.0, 0.55))
	AudioManager.play_sfx("bigboom")
	_shake_camera(2.2)
	_punch_zoom(0.12, Vector2(300, 300))
	_shockwave(Vector2(280, 300))
	await _hitstop(0.16)
	for e in alive:
		if e["alive"]:
			var dmg: int = int((d["mag"] * 1.9 + sm["power"]) * randf_range(0.95, 1.1)) - e["def"] / 2
			await _damage_enemy(e, maxi(dmg, 1))
	wave.queue_free()
	# Wasser läuft ab
	var drain := create_tween()
	drain.tween_property(water, "position:y", 570.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	drain.parallel().tween_property(water, "modulate:a", 0.0, 0.7)
	drain.tween_callback(water.queue_free)
	s.modulate = Color.WHITE
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
	# Beschwörungspose vor dem Heilzauber.
	await _stance(h, Color(0.45, 1.0, 0.55), "summon")
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
	await _sprint(h, h["home"], 0.2)

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
		_say("%s greift %s an!" % [e["name"], target["data"]["name"]])
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

## Münze schlägt auf: Klimpern + goldene Funken.
func _coin_impact(c: Sprite2D) -> void:
	AudioManager.play_sfx("coin")
	_burst(c.position, Color(1.0, 0.85, 0.35), 5, 80)
	c.queue_free()

## Boss-Spezial: Giftflut, Münzhagel oder Hasstirade über der ganzen Gruppe.
func _boss_aoe(e: Dictionary, targets: Array) -> void:
	var st := _style()
	var theme: String = boss_def.get("theme", "toxic")
	_say("%s holt aus — %s!" % [e["name"], boss_def["aoe_name"]])
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

## Boss-Ultimative: „Schwarzer Himmel“ (Smogdecke + Säureregen),
## „Feindliche Übernahme“ (Münzstrudel + Riesenmünze) oder
## „Mauer des Hasses“ (Backsteinmauer wächst und kippt auf die Helden).
func _boss_ultimate(e: Dictionary, targets: Array) -> void:
	var st := _style()
	var theme: String = boss_def.get("theme", "toxic")
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
	_ult_banner("☠ %s ☠" % ult_name.to_upper(), st["banner"])
	await get_tree().create_timer(0.6).timeout
	match theme:
		"gold": await _ult_uebernahme()
		"hate": await _ult_mauer(targets)
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

func _damage_hero(target: Dictionary, dmg: int) -> void:
	target["data"]["hp"] = maxi(target["data"]["hp"] - dmg, 0)
	_float_text(target["sprite"].position, str(dmg), Color(1.0, 0.45, 0.35))
	_shake(target["sprite"], 1.0)  # Held wird nach rechts (von den Gegnern weg) geworfen
	_shake_camera()
	_refresh_party()
	if target["data"]["hp"] <= 0:
		# Gefallene wippen nicht mehr — sonst „atmet" der Ohnmächtige weiter.
		_pause_bob(target)
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

## Wut-Phase des Bosses: Aufschrei, Färbung, mehr Angriff (Farbe je Thema).
func _boss_enrage(e: Dictionary) -> void:
	e["enraged"] = true
	e["atk"] = int(e["atk"] * 1.35)
	AudioManager.play_sfx("charge")
	_say("%s tobt vor Wut!" % e["name"])
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
		_say("%s: „%s“" % [line[0], line[1]])
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
			_say("%s erreicht Stufe %d!" % [up["name"], up["level"]])
			for h in heroes:
				if h["data"]["name"] == up["name"]:
					_sparkle(h["sprite"].position, Color(1.0, 0.92, 0.4))
					_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.45))
			await get_tree().create_timer(1.5).timeout
			if up.has("unlock"):
				AudioManager.play_sfx("summon")
				_say("%s kann nun %s beschwören!" % [up["name"], up["unlock"]])
				await get_tree().create_timer(1.8).timeout
	# Boss-Siege schalten den Fortschritt frei.
	if enemy_ids.has("boss3"):
		GameState.boss3_defeated = true
	elif enemy_ids.has("boss2"):
		GameState.boss2_defeated = true
		GameState.apply_blessing2()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(1.0, 0.9, 0.4))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(1.0, 0.9, 0.4))
		_say("Der Hort des Fürsten fließt zurück ins Land — sein Dank stärkt euch!")
		await get_tree().create_timer(2.4).timeout
		_say("Die letzten Siegel fallen: Klingentanz, Atombombe und Leviathans Pakt!")
		await get_tree().create_timer(2.4).timeout
		_say("Im Südwesten bröckelt der Wall aus Misstrauen um die Hassfestung ...")
		await get_tree().create_timer(2.2).timeout
	elif enemy_ids.has("boss"):
		GameState.boss_defeated = true
		GameState.apply_blessing()
		_refresh_party()
		AudioManager.play_sfx("heal")
		for h in heroes:
			_sparkle(h["sprite"].position, Color(0.7, 1.0, 0.5))
			_cast_circle(h["sprite"].position + Vector2(0, 40), Color(0.7, 1.0, 0.5))
		_say("Der Fluss atmet auf — die Segnung des klaren Wassers durchströmt euch!")
		await get_tree().create_timer(2.4).timeout
		_say("Siegel gebrochen: Fokusstoß, Raketensalve und Ifrits Pakt erwachen!")
		await get_tree().create_timer(2.4).timeout
		_say("Im Nordosten springen die goldenen Tore des Konzernturms auf ...")
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
