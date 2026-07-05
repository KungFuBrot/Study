extends Node
## Wurzelknoten: wechselt zwischen Feld (Stadt/Weltkarte/Dungeon) und Kampf,
## inkl. Überblendungen. Feldposition wird beim Kampfstart gemerkt.

var current_screen: Node = null
var fade_rect: ColorRect

# Merker, um nach einem Kampf an dieselbe Stelle zurückzukehren.
var field_return := {"map": "town", "spawn": "start", "pos": Vector2i(-1, -1)}
var last_battle_was_final_boss := false

func _ready() -> void:
	GameState.main = self
	_setup_input()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade_rect)
	goto_map("town", "start")
	if OS.get_environment("SHOT") != "":
		_shot_tour()

## Temporärer Debug-Rundgang: Screenshots von Feld und Bosskampf (env SHOT=Zielordner).
func _shot_tour() -> void:
	await get_tree().create_timer(2.0).timeout
	_snap("town")
	goto_map("dungeon", "entrance")
	await get_tree().create_timer(2.0).timeout
	_snap("dungeon")
	goto_map("dungeon2", "entrance")
	await get_tree().create_timer(2.0).timeout
	_snap("dungeon2")
	# Berührungs-Test: neben den Boss stellen und hineinlaufen — muss den Kampf starten.
	goto_map("dungeon", "", Vector2i(17, 10))
	await get_tree().create_timer(1.5).timeout
	_snap("boss_before_touch")
	(current_screen as Field)._try_step(Vector2i(1, 0))
	await get_tree().create_timer(7.0).timeout
	_snap("battle1")
	await get_tree().create_timer(3.0).timeout
	_snap("battle2")
	start_battle(["slime", "bat", "skeleton"], "dungeon", Vector2i(4, 10))
	await get_tree().create_timer(2.5).timeout
	_snap("battle_normal")
	start_battle(["frostwolf", "eisgeist"], "dungeon2", Vector2i(4, 10))
	await get_tree().create_timer(2.5).timeout
	_snap("battle_frost")
	get_tree().quit()

func _snap(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT") + "/" + shot_name + ".png")

func goto_map(map_id: String, spawn_id: String, exact_pos := Vector2i(-1, -1)) -> void:
	await _fade(1.0, 0.25)
	_clear_screen()
	var field := Field.new()
	field.map_id = map_id
	field.spawn_id = spawn_id
	field.exact_pos = exact_pos
	add_child(field)
	current_screen = field
	AudioManager.play_music(map_id)
	await _fade(0.0, 0.35)

func start_battle(enemy_ids: Array, from_map: String, pos: Vector2i) -> void:
	field_return = {"map": from_map, "spawn": "", "pos": pos}
	last_battle_was_final_boss = enemy_ids.has("boss2")
	AudioManager.play_sfx("encounter")
	# Kurzes Aufblitzen als Kampf-Übergang.
	for i in 2:
		fade_rect.color = Color.WHITE
		await _fade(0.8, 0.07)
		await _fade(0.0, 0.07)
	fade_rect.color = Color.BLACK
	await _fade(1.0, 0.25)
	_clear_screen()
	var battle := Battle.new()
	battle.enemy_ids = enemy_ids
	battle.arena_theme = "frost" if from_map == "dungeon2" else "cave"
	battle.finished.connect(_on_battle_finished)
	add_child(battle)
	current_screen = battle
	# Boss-Kämpfe bringen ihre eigene Musik mit.
	var song := "battle"
	for id in enemy_ids:
		song = GameState.ENEMIES[id].get("song", song)
	AudioManager.play_music(song)
	await _fade(0.0, 0.35)

func _on_battle_finished(victory: bool) -> void:
	if not victory:
		GameState.reset_party()
		goto_map("town", "start")
	elif last_battle_was_final_boss and GameState.boss2_defeated:
		_show_ending()
	else:
		goto_map(field_return["map"], "", field_return["pos"])

## Der Boss ist gefallen — das Spiel endet mit dem Abspann.
func _show_ending() -> void:
	await _fade(1.0, 0.6)
	_clear_screen()
	var ending := Ending.new()
	ending.restart.connect(_on_ending_restart)
	add_child(ending)
	current_screen = ending
	await _fade(0.0, 0.8)

func _on_ending_restart() -> void:
	GameState.reset_all()
	goto_map("town", "start")

func _clear_screen() -> void:
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null

func _fade(target_alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", target_alpha, dur)
	await tw.finished

func _setup_input() -> void:
	var bindings := {
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"confirm": [KEY_Z, KEY_ENTER, KEY_SPACE],
		"cancel": [KEY_X, KEY_ESCAPE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
