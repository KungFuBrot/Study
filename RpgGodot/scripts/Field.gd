class_name Field
extends Node2D
## Erkundungsmodus: baut die Karte aus MapData, steuert Heldin + Begleiter,
## NPC-Dialoge, Shop und Zufallskämpfe (nur wo die Karte es erlaubt).

const TILE := 16
const STEP_TIME := 0.18

var map_id := "town"
var spawn_id := "start"
var exact_pos := Vector2i(-1, -1)

var map: Dictionary
var player_tile: Vector2i
var facing := Vector2i(0, 1)
var moving := false
var walk_frame := 0
var steps_since_battle := 0
var state := "move"  # move | dialogue | shop | locked (Übergang läuft)

var player: Sprite2D
var follower: Sprite2D
var follower_tile: Vector2i
var camera: Camera2D
var npc_nodes := {}  # Vector2i -> npc dict

# UI
var ui: CanvasLayer
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var dialog_lines: Array = []
var dialog_after_shop := false
var shop_panel: PanelContainer
var shop_labels: Array = []
var shop_gold: Label
var shop_index := 0
var hud: Label

func _ready() -> void:
	map = MapData.get_map(map_id)
	_build_tiles()
	_spawn_npcs()
	_spawn_party()
	_build_ui()

func _build_tiles() -> void:
	var rows: Array = map["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var s := Sprite2D.new()
			s.texture = SpriteFactory.tile(MapData.TILE_FOR_CHAR[ch])
			s.centered = false
			s.position = Vector2(x * TILE, y * TILE)
			add_child(s)

func _spawn_npcs() -> void:
	for npc in map["npcs"]:
		var s := Sprite2D.new()
		s.texture = SpriteFactory.character(npc["id"], "down", 0)
		s.centered = false
		s.position = Vector2(npc["pos"].x * TILE + 2, npc["pos"].y * TILE)
		s.z_index = 5
		add_child(s)
		npc_nodes[npc["pos"]] = npc
	# Boss thront hinten in der Finsterhöhle, bis er besiegt ist.
	if map_id == "dungeon" and not GameState.boss_defeated:
		var boss_tile := Vector2i(18, 10)
		var bs := Sprite2D.new()
		bs.texture = SpriteFactory.enemy("boss")
		bs.centered = false
		bs.position = Vector2(boss_tile.x * TILE - 2, boss_tile.y * TILE - 4)
		bs.z_index = 5
		add_child(bs)
		var bob := create_tween().set_loops()
		bob.tween_property(bs, "position:y", bs.position.y - 2.0, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(bs, "position:y", bs.position.y, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		npc_nodes[boss_tile] = {"boss": true, "name": "Knochenkönig", "pos": boss_tile}

func _spawn_party() -> void:
	if exact_pos.x >= 0:
		player_tile = exact_pos
	else:
		player_tile = map["spawns"][spawn_id]
	follower_tile = player_tile
	player = Sprite2D.new()
	player.centered = false
	player.z_index = 10
	add_child(player)
	follower = Sprite2D.new()
	follower.centered = false
	follower.z_index = 9
	add_child(follower)
	player.position = _tile_pos(player_tile)
	follower.position = _tile_pos(follower_tile)
	_update_sprites()

	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	var rows: Array = map["rows"]
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = (rows[0] as String).length() * TILE
	camera.limit_bottom = rows.size() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.position = Vector2(6, 8)
	camera.make_current()

func _tile_pos(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + 2, t.y * TILE)

func _dir_name(d: Vector2i) -> String:
	if d.y > 0: return "down"
	if d.y < 0: return "up"
	return "side"

func _update_sprites() -> void:
	player.texture = SpriteFactory.character("serena", _dir_name(facing), walk_frame)
	player.flip_h = facing.x < 0
	var fd := player_tile - follower_tile
	if fd == Vector2i.ZERO:
		fd = facing
	follower.texture = SpriteFactory.character("milo", _dir_name(fd), walk_frame)
	follower.flip_h = fd.x < 0

func _process(_delta: float) -> void:
	if state == "move" and not moving:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("move_up"): dir = Vector2i(0, -1)
		elif Input.is_action_pressed("move_down"): dir = Vector2i(0, 1)
		elif Input.is_action_pressed("move_left"): dir = Vector2i(-1, 0)
		elif Input.is_action_pressed("move_right"): dir = Vector2i(1, 0)
		if dir != Vector2i.ZERO:
			_try_step(dir)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		match state:
			"move": _try_interact()
			"dialogue": _advance_dialogue()
			"shop": _shop_buy()
	elif event.is_action_pressed("cancel") and state == "shop":
		_close_shop()
	elif state == "shop":
		if event.is_action_pressed("move_up"): _shop_move(-1)
		elif event.is_action_pressed("move_down"): _shop_move(1)

func _try_step(dir: Vector2i) -> void:
	facing = dir
	var target := player_tile + dir
	if npc_nodes.has(target) or not MapData.is_walkable(map, target):
		_update_sprites()
		return
	moving = true
	var old := player_tile
	player_tile = target
	walk_frame = 1 - walk_frame
	_update_sprites()
	AudioManager.play_sfx("step")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "position", _tile_pos(player_tile), STEP_TIME)
	tw.tween_property(follower, "position", _tile_pos(old), STEP_TIME)
	await tw.finished
	follower_tile = old
	moving = false
	_after_step()

func _after_step() -> void:
	for portal in map["portals"]:
		if portal["pos"] == player_tile:
			state = "locked"  # Eingaben sperren während des Wechsels
			GameState.main.goto_map(portal["to"], portal["spawn"])
			return
	if map["encounters"]:
		steps_since_battle += 1
		if steps_since_battle > 4 and randf() < 0.12:
			steps_since_battle = 0
			state = "locked"
			GameState.main.start_battle(GameState.random_dungeon_encounter(), map_id, player_tile)

func _try_interact() -> void:
	var target := player_tile + facing
	if not npc_nodes.has(target):
		return
	var npc: Dictionary = npc_nodes[target]
	if npc.get("boss", false):
		state = "locked"
		GameState.main.start_battle(["boss"], map_id, player_tile)
		return
	dialog_lines = (npc["lines"] as Array).duplicate()
	dialog_after_shop = npc.get("shop", false)
	dialog_name.text = npc["name"]
	state = "dialogue"
	AudioManager.play_sfx("menu")
	_advance_dialogue()

func _advance_dialogue() -> void:
	if dialog_lines.is_empty():
		dialog_panel.visible = false
		if dialog_after_shop:
			_open_shop()
		else:
			state = "move"
		return
	dialog_panel.visible = true
	dialog_text.text = dialog_lines.pop_front()

## ---------- UI ----------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 18)
	ui.add_child(hud)
	_refresh_hud()

	dialog_panel = _make_panel(Rect2(80, 400, 800, 120))
	var vb := VBoxContainer.new()
	dialog_panel.add_child(vb)
	dialog_name = Label.new()
	dialog_name.add_theme_font_size_override("font_size", 16)
	dialog_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(dialog_name)
	dialog_text = Label.new()
	dialog_text.add_theme_font_size_override("font_size", 20)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(dialog_text)

	shop_panel = _make_panel(Rect2(280, 140, 400, 220))
	var svb := VBoxContainer.new()
	shop_panel.add_child(svb)
	var title := Label.new()
	title.text = "— Gretas Laden —   (Z: Kaufen, X: Zurück)"
	title.add_theme_font_size_override("font_size", 16)
	svb.add_child(title)
	shop_gold = Label.new()
	shop_gold.add_theme_font_size_override("font_size", 16)
	shop_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	svb.add_child(shop_gold)
	for item_name in GameState.ITEMS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		svb.add_child(l)
		shop_labels.append([l, item_name])

func _make_panel(rect: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.custom_minimum_size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.16, 0.92)
	style.border_color = Color(0.75, 0.7, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", style)
	p.visible = false
	ui.add_child(p)
	return p

func _refresh_hud() -> void:
	hud.text = "%s   |   Gold: %d" % [map["name"], GameState.gold]

func _open_shop() -> void:
	state = "shop"
	shop_index = 0
	shop_panel.visible = true
	_refresh_shop()

func _refresh_shop() -> void:
	shop_gold.text = "Gold: %d" % GameState.gold
	for i in shop_labels.size():
		var l: Label = shop_labels[i][0]
		var item_name: String = shop_labels[i][1]
		var item: Dictionary = GameState.ITEMS[item_name]
		var cursor := "> " if i == shop_index else "  "
		var owned: int = GameState.inventory.get(item_name, 0)
		l.text = "%s%s  %d G  (Besitz: %d) — %s" % [cursor, item_name, item["price"], owned, item["desc"]]
		l.add_theme_color_override("font_color", Color.WHITE if i == shop_index else Color(0.7, 0.7, 0.75))

func _shop_move(delta: int) -> void:
	shop_index = clampi(shop_index + delta, 0, shop_labels.size() - 1)
	AudioManager.play_sfx("menu")
	_refresh_shop()

func _shop_buy() -> void:
	var item_name: String = shop_labels[shop_index][1]
	var price: int = GameState.ITEMS[item_name]["price"]
	if GameState.gold >= price:
		GameState.gold -= price
		GameState.add_item(item_name)
		AudioManager.play_sfx("buy")
	else:
		AudioManager.play_sfx("error")
	_refresh_shop()
	_refresh_hud()

func _close_shop() -> void:
	shop_panel.visible = false
	state = "move"
	AudioManager.play_sfx("menu")
