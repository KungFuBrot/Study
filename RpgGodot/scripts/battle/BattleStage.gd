class_name BattleStage
extends BattleFx
## Arena-Aufbau und Ambiente: Hintergrund, Themen-Palette, Wetter, Fackeln,
## Schatten/Waffen/Auren an Sprites, Idle-Animationen und -Macken.
## Teil der Battle-Vererbungskette (siehe CLAUDE.md):
## BattleBase > BattleFx > BattleStage > BattleUi > BattleBossCine > BattleDamage
## > BattleHeroActions > BattleRaxActions > BattleSummons > BattleEnemyActions > Battle

var _pal_cache: Dictionary = {}

# Himmel, Boden und Fels waren so dunkel angelegt, dass von der ganzen
# Tiefenstaffelung im fertigen Bild nichts mehr ankam: Ambiente, Vignette und
# Farbgrading nehmen zusammen rund die Hälfte weg, und aus 0.18 wird dabei
# 0.09 — also Schwarz. Die Kulisse wird deshalb angehoben; dunkel bleiben
# jetzt die Silhouetten, und die heben sich gegen den helleren Himmel ab.
const STAGE_LIFT := {
	"bg_top": 2.4, "bg_bottom": 2.0,
	"floor_top": 1.8, "floor_bottom": 1.8, "stone": 1.35,
	# Grundlicht: seit die Figuren aus dem Rig kommen (eigene, teils dunkle
	# Farben statt heller DTII-Grautöne) war die alte Abdunklung zu viel.
	# Etwas zurückgenommen für die düstere Grundstimmung — die Figuren stehen
	# jetzt in engen Lichtinseln statt in gleichmäßiger Helligkeit.
	"ambient": 1.05,
}

## Farbstimmung des Schauplatzes, angehoben (Schlotwerk giftgrün,
## Konzernturm golden, Hassfestung blutrot).
func _palette() -> Dictionary:
	if _pal_cache.is_empty():
		_pal_cache = _palette_raw()
		for k: String in STAGE_LIFT:
			var c: Color = _pal_cache[k]
			var f: float = STAGE_LIFT[k]
			_pal_cache[k] = Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0),
				minf(c.b * f, 1.0), c.a)
	return _pal_cache

func _palette_raw() -> Dictionary:
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
		"void":
			return {
				"bg_top": Color(0.12, 0.13, 0.16) if boss_fight else Color(0.11, 0.12, 0.15),
				"bg_bottom": Color(0.03, 0.03, 0.04),
				"floor_top": Color(0.22, 0.23, 0.26), "floor_bottom": Color(0.08, 0.09, 0.11),
				"stone": Color(0.30, 0.31, 0.35), "stal": Color(0.06, 0.07, 0.09, 0.85),
				"flame": Color(0.78, 0.83, 0.92), "glow": Color(0.70, 0.78, 0.90, 0.28),
				"fog": Color(0.55, 0.58, 0.66, 0.09), "hit": Color(0.82, 0.86, 0.94),
				"ray": Color(0.70, 0.76, 0.88, 0.05), "dust": Color(0.72, 0.76, 0.85, 0.45),
				"grade_top": Color(0.60, 0.66, 0.78, 0.06), "grade_bottom": Color(0.05, 0.06, 0.10, 0.20),
				"pool_hero": Color(0.80, 0.85, 0.92, 0.10), "pool_enemy": Color(0.70, 0.76, 0.86, 0.10),
				"fg": Color(0.02, 0.02, 0.03), "ambient": Color(0.60, 0.63, 0.70),
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


## Kulissen-Silhouette je Schauplatz. Vorher standen überall dieselben
## Dreiecke — dadurch sahen alle vier Arenen gleich aus und die Kulisse las
## sich als Farbverlauf. Grundlinie ist y = 0, die Form wächst nach oben.
func _skyline_shape(i: int, w: float, h: float) -> PackedVector2Array:
	var hw := w * 0.5
	match arena_theme:
		"gold":
			# Konzernturm: gestufter Hochhausriegel mit Antennenspitze.
			var sw := hw * 0.34
			return PackedVector2Array([
				Vector2(-hw, 0), Vector2(-hw, -h * 0.72),
				Vector2(-hw * 0.62, -h * 0.72), Vector2(-hw * 0.62, -h * 0.93),
				Vector2(-sw, -h * 0.93), Vector2(-sw * 0.35, -h),
				Vector2(sw * 0.35, -h), Vector2(sw, -h * 0.93),
				Vector2(hw * 0.62, -h * 0.93), Vector2(hw * 0.62, -h * 0.72),
				Vector2(hw, -h * 0.72), Vector2(hw, 0)])
		"hate":
			# Festungsmauer mit Zinnenkranz.
			var pts := PackedVector2Array([Vector2(-hw, 0), Vector2(-hw, -h)])
			var merlons := 4
			var step := w / float(merlons * 2)
			for k in merlons * 2:
				var x0 := -hw + k * step
				var top := -h - (h * 0.11 if k % 2 == 0 else 0.0)
				pts.append(Vector2(x0, top))
				pts.append(Vector2(x0 + step, top))
			pts.append(Vector2(hw, -h))
			pts.append(Vector2(hw, 0))
			return pts
		"void":
			# Zersplitterter Monolith, schief und oben abgebrochen.
			var lean := hw * 0.32 * (1.0 if i % 2 == 0 else -1.0)
			return PackedVector2Array([
				Vector2(-hw, 0), Vector2(-hw * 0.55 + lean, -h * 0.62),
				Vector2(-hw * 0.30 + lean, -h), Vector2(hw * 0.12 + lean, -h * 0.78),
				Vector2(hw * 0.48 + lean, -h * 0.90), Vector2(hw * 0.60, -h * 0.40),
				Vector2(hw, 0)])
		_:
			# Schlotwerk: Fabrikschlot mit verbreitertem Fuß und Kragen.
			var cw := hw * 0.40
			return PackedVector2Array([
				Vector2(-hw, 0), Vector2(-hw * 0.72, -h * 0.16),
				Vector2(-cw, -h * 0.30), Vector2(-cw, -h * 0.88),
				Vector2(-cw * 1.35, -h * 0.88), Vector2(-cw * 1.35, -h),
				Vector2(cw * 1.35, -h), Vector2(cw * 1.35, -h * 0.88),
				Vector2(cw, -h * 0.88), Vector2(cw, -h * 0.30),
				Vector2(hw * 0.72, -h * 0.16), Vector2(hw, 0)])

## Details der vordersten Kulissenebene: beleuchtete Fenster im Konzernturm,
## Rauch aus den Schloten, Glut auf den Zinnen, Splitterglimmen in der Leere.
func _skyline_detail(shape: Polygon2D, i: int, w: float, h: float, pal: Dictionary) -> void:
	match arena_theme:
		"gold":
			var cols := 3
			var rows := maxi(3, int(h / 34.0))
			for r in rows:
				for c in cols:
					if (i * 7 + r * 3 + c) % 3 == 0:
						continue  # dunkle Büros, sonst wirkt es wie ein Lichtgitter
					var win := Polygon2D.new()
					var wx: float = (c - 1) * w * 0.20
					var wy: float = -h * 0.14 - r * (h * 0.58 / rows)
					win.polygon = PackedVector2Array([
						Vector2(wx - 3, wy), Vector2(wx + 3, wy),
						Vector2(wx + 3, wy + 6), Vector2(wx - 3, wy + 6)])
					win.color = Color(1.0, 0.86, 0.45, 0.55)
					shape.add_child(win)
		"hate":
			var ember := Sprite2D.new()
			ember.texture = SpriteFactory.circle(9, Color(1.0, 0.38, 0.14, 0.30))
			ember.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			ember.material = _additive_mat()
			ember.position = Vector2(0, -h)
			shape.add_child(ember)
		"void":
			var shard := Sprite2D.new()
			shard.texture = SpriteFactory.circle(7, Color(0.72, 0.80, 0.95, 0.22))
			shard.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			shard.material = _additive_mat()
			shard.position = Vector2(0, -h * 0.85)
			shape.add_child(shard)
		_:
			# Qualm quillt aus dem Schlot — das Wahrzeichen des Schlotwerks.
			var smoke := CPUParticles2D.new()
			smoke.amount = 9
			smoke.lifetime = 4.5
			smoke.preprocess = 4.5
			smoke.position = Vector2(0, -h)
			smoke.direction = Vector2(0.25, -1)
			smoke.spread = 12.0
			smoke.gravity = Vector2(6, -10)
			smoke.initial_velocity_min = 8.0
			smoke.initial_velocity_max = 16.0
			smoke.scale_amount_min = 0.25
			smoke.scale_amount_max = 0.55
			smoke.color = Color(pal["fog"].r, pal["fog"].g, pal["fog"].b, 0.16)
			smoke.texture = SpriteFactory.particle("smoke_07")
			shape.add_child(smoke)

static func _additive_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

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
			stal.polygon = _skyline_shape(i, w, hh)
			stal.color = spec["col"]
			stal.position = Vector2(fmod(30.0 + i * (980.0 / n) + li * 57.0, 1000.0) - 20.0, spec["y"])
			layer.add_child(stal)
			# Nur die vorderste Ebene bekommt Details — dahinter würden sie
			# den Dunst-Eindruck der Tiefenstaffelung zerstören.
			if li == layer_specs.size() - 1:
				_skyline_detail(stal, i, w, hh, pal)
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
		"void": prop_kinds = ["bones", "crack", "pebble"]
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
		# Einheitlicher Maßstab für alle Kampffiguren: die Leinwand des Rigs
		# wächst mit der Figur, nicht die Vergrößerung. Dadurch ist ein Pixel
		# bei Held, Monster und Boss gleich groß.
		var hscale := RigFactory.BATTLE_SCALE
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
		# Die Rig-Figuren tragen ihre Waffe selbst — kein DTII-Overlay darüber.
		var wp: Sprite2D = null
		add_child(s)
		heroes.append({"data": data, "sprite": s, "home": home, "ult_used": false,
			"frame": 0, "weapon": wp, "anim": "idle"})

	# Gegner-Skalierung: Am Anfang sind alle Dungeons gleich schwer — die höheren
	# Grundwerte der späteren Dungeons werden über ihre `tier`-Stufe aufs
	# Einstiegsniveau normiert. Mit jedem erledigten Dungeon wachsen die noch
	# offenen Dungeons mit (GameState.enemy_multiplier), egal in welcher
	# Reihenfolge man vorgeht. Boss inklusive, damit auch er mitskaliert.
	for i in enemy_ids.size():
		var def: Dictionary = GameState.ENEMIES[enemy_ids[i]]
		var is_boss: bool = def.get("boss", false)
		var mul := GameState.enemy_multiplier(def.get("tier", 0))
		var e_hp: int = int(round(def["hp"] * mul))
		var e_atk: int = int(round(def["atk"] * mul))
		var e_def: int = int(round(def["def"] * mul))
		var e_gold: int = int(round(def["gold"] * mul))
		var e_xp: int = int(round(def.get("xp", 0) * mul))
		var s := Sprite2D.new()
		s.texture = SpriteFactory.enemy(def["sprite"])
		# Der finale Boss „Die Stille" (dunkles Spinnentier) thront breit und
		# bedrohlich über den anderen — sein Sprite ist zudem breiter angelegt.
		# Derselbe Maßstab wie bei den Helden: die Größe steckt in der Leinwand
		# des Rigs (Monster 52x52, Boss 112x128), nicht in der Vergrößerung —
		# nur so ist ein Pixel bei allen Figuren gleich groß.
		s.scale = Vector2(RigFactory.BATTLE_SCALE, RigFactory.BATTLE_SCALE)
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
		# Die Themen-Tönung aus ENEMIES entfällt: sie war dafür da, graue
		# DTII-Fremdsprites einzufärben. Die Rig-Monster bringen ihre Farben
		# selbst mit; geblieben ist nur das atmosphärische Abdunkeln.
		# Kaum noch Abdunklung: die Rig-Monster haben eigene, teils dunkle
		# Farben, und Grundlicht plus Vignette nehmen ohnehin schon viel weg.
		var dark := Color(1.0, 1.0, 1.0) if is_boss else Color(0.96, 0.94, 0.98)
		var tint := dark
		s.modulate = tint
		s.set_meta("tint", tint)
		add_child(s)
		enemies.append({"anim": "idle", "name": def["name"], "hp": e_hp, "max_hp": e_hp,
			"atk": e_atk, "def": e_def, "gold": e_gold, "xp": e_xp,
			"sprite": s, "home": home, "alive": true, "is_boss": is_boss,
			"id": def["sprite"], "frame": 0, "acts": 0, "enraged": false, "refl": refl,
			"tint": tint, "proj": def.get("proj", ""), "mist": mist,
			"attack_line": def.get("attack_line", ""),
			"special": def.get("special", {})})

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
	# Pulsierende Glutblasen: golden im Konzernturm, blutrot in der Hassfestung,
	# fahles Grau in der Leere.
	var blob_col := Color(1.0, 0.80, 0.30, 0.10) if arena_theme == "gold" \
		else (Color(0.70, 0.76, 0.88, 0.08) if arena_theme == "void" \
		else Color(1.0, 0.30, 0.12, 0.10))
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
	# Gestaucht statt spiegelbildlich in voller Höhe: seit die Figuren aus dem
	# Rig kommen (bis 128px hoch), reichte die volle Spiegelung bis in die
	# Figur dahinter. Eine flache Bodenspiegelung liest sich ohnehin besser.
	r.scale = Vector2(1.0, 0.45)
	r.position = Vector2(0, foot_y * 1.45 + 1.0)
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
	"boss4": Vector2(0, 2),  # Augencluster des Spinnentiers (Vorderkörper)
}

## Lebenszeichen des Bosses: glimmende Augen-Glut (mit Blinzeln), giftiger
## Atem aus dem Maul und ein tiefes Grollen mit Auren-Flackern.
func _attach_boss_life(s: Sprite2D, theme: String, sprite_id: String) -> void:
	var st: Dictionary = THEME_STYLE.get(theme, THEME_STYLE["toxic"])
	var face: Vector2 = BOSS_FACE.get(sprite_id, Vector2(2, -7))
	# Augen-Glut: additiver Schein, der pulsiert und ab und zu kurz erlischt
	# (Blinzeln). Das Spinnentier (boss4) glüht kräftig ROT statt themengrau.
	var eye_rgb: Color = st["ember"]
	var eye_wide := 1.4
	if sprite_id == "boss4":
		eye_rgb = Color(1.0, 0.12, 0.08)
		eye_wide = 2.1  # breiter Schein über dem ganzen Augencluster
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var eyes := Sprite2D.new()
	eyes.texture = SpriteFactory.circle(3, Color(1.0, 0.9, 0.8))
	eyes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	eyes.material = mat
	eyes.position = face
	eyes.scale = Vector2(eye_wide, 0.7)
	eyes.modulate = Color(eye_rgb.r, eye_rgb.g, eye_rgb.b, 0.6)
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
		"void":
			# Fahle Aschekörnchen treiben lautlos und richtungslos — nichts strebt
			# irgendwohin, nichts fällt mit Absicht. Nur Leere, die schwebt.
			p.position = Vector2(480, 260)
			p.amount = 30
			p.emission_rect_extents = Vector2(520, 260)
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.gravity = Vector2(0, -2)
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 7.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 1.0
			p.color = Color(0.74, 0.78, 0.86, 0.4)
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
			# Auch Gefallene takten weiter — sonst friert der Zusammenbruch
			# mitten in der Bewegung ein.
			var anim: String = e.get("anim", "idle")
			if not e["alive"] and anim != "down":
				return
			e["frame"] = (e["frame"] + 1) % RigFactory.mon_frames(anim, e["id"])
			var tex := SpriteFactory.enemy_frame(e["id"], e["frame"], anim)
			(e["sprite"] as Sprite2D).texture = tex
			if is_instance_valid(e["refl"]):
				(e["refl"] as Sprite2D).texture = tex)
	for h in heroes:
		_unit_ticker(randf_range(0.13, 0.19), func():
			if h["data"]["hp"] > 0:
				h["frame"] = (h["frame"] + 1) % RigFactory.anim_frames(h["anim"], h["data"]["id"])
				(h["sprite"] as Sprite2D).texture = \
					SpriteFactory.hero_battle_frame(h["data"]["id"], h["frame"], h["anim"]))
	# Drohgebärde: alle paar Sekunden richtet sich eine wartende Kreatur auf
	# und lehnt sich vor. Sonst steht die Gegnerseite zwischen den Zügen nur
	# atmend herum.
	var menace := Timer.new()
	menace.wait_time = 3.4
	menace.autostart = true
	menace.timeout.connect(func():
		var idle_ones := enemies.filter(func(e: Dictionary) -> bool:
			return e["alive"] and e.get("anim", "idle") == "idle")
		if idle_ones.is_empty():
			return
		_epose(idle_ones[randi() % idle_ones.size()], "taunt", 0.95))
	add_child(menace)
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
	if hero.get("anim", "idle") == "down":
		# Aus der Zusammenbruch-Pose zurück auf die Beine.
		hero["anim"] = "idle"
		hero["frame"] = 0
		s.texture = SpriteFactory.hero_battle_frame(hero["data"]["id"], 0, "idle")
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
