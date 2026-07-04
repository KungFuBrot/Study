class_name MapData
## ASCII-Karten. Legende:
##  g Gras, t Baum, p Weg, w Wasser, b Brücke, m Berg,
##  R Dach, W Hauswand, D Tür, f Dungeonboden, # Dungeonwand,
##  T Stadt (Portal), C Höhle (Portal), X Dungeon-Ausgang (Portal)

const WALKABLE := ["g", "p", "b", "f", "T", "C", "X"]

const TILE_FOR_CHAR := {
	"g": "grass", "t": "tree", "p": "path", "w": "water", "b": "bridge",
	"m": "mount", "R": "roof", "W": "wall", "D": "door", "f": "floor",
	"#": "dwall", "T": "town_icon", "C": "cave", "X": "path",
}

const MAPS := {
	"town": {
		"name": "Lindenhain",
		"music": "town",
		"encounters": false,
		"ground": "grass",
		"rows": [
			"tttttttttttttttttttt",
			"tggggggggggggggggggt",
			"tgRRRRRgggggRRRRRggt",
			"tgWWDWWgggggWWDWWggt",
			"tggggggggggggggggggt",
			"tggggpppppppppppgggt",
			"tggggpggggggggpggggt",
			"tggggpggggggggpggggt",
			"tggggpggggggggpggggt",
			"tggggpppppppppppgggt",
			"tgggggggggpggggggggt",
			"tgggggggggpggggggggt",
			"tggggggggggggggggggt",
			"ttttttttttpttttttttt",
		],
		"spawns": {"start": Vector2i(10, 11), "from_world": Vector2i(10, 12)},
		"portals": [
			{"pos": Vector2i(10, 13), "to": "world", "spawn": "from_town"},
		],
		"npcs": [
			{"id": "npc_elder", "name": "Ältester Theobald", "pos": Vector2i(7, 4),
				"lines": [
					"Willkommen in Lindenhain, Reisende!",
					"Östlich des Flusses liegt eine dunkle Höhle.",
					"Dort lauern Monster. Geht nicht unvorbereitet hinein!"]},
			{"id": "npc_kid", "name": "Pia", "pos": Vector2i(12, 8),
				"lines": [
					"Hihi! Serena, dein Schwert glitzert so schön!",
					"Milo, zeigst du mir mal einen Feuerball? ... Nein? Menno."]},
			{"id": "npc_shop", "name": "Händlerin Greta", "pos": Vector2i(15, 4), "shop": true,
				"lines": ["Willkommen! Schaut euch ruhig um."]},
		],
	},
	"world": {
		"name": "Weltkarte",
		"music": "world",
		"encounters": false,
		"ground": "grass",
		"rows": [
			"mmmmmmmmmmmmmmmmmmmmmm",
			"mggggtgggggwwgggggtggm",
			"mggggggggggwwggggggggm",
			"mgTggggggggwwggggggggm",
			"mgpggggggggwwggggggggm",
			"mgpppppppppbbppppppggm",
			"mggggggggggwwgggggpggm",
			"mggtgggggggwwgggggpggm",
			"mggggggggggwwgggggpggm",
			"mggggggggggwwggmmmpmmm",
			"mggggggggggwwggmmmCmmm",
			"mgggtggggggwwggmmmmmmm",
			"mggggggggggwwggggggggm",
			"mggtgggggggwwggggtgggm",
			"mggggggggggwwggggggggm",
			"mmmmmmmmmmmmmmmmmmmmmm",
		],
		"spawns": {"from_town": Vector2i(2, 4), "from_dungeon": Vector2i(18, 9)},
		"portals": [
			{"pos": Vector2i(2, 3), "to": "town", "spawn": "from_world"},
			{"pos": Vector2i(18, 10), "to": "dungeon", "spawn": "entrance"},
		],
		"npcs": [],
	},
	"dungeon": {
		"name": "Finsterhöhle",
		"music": "dungeon",
		"encounters": true,
		"ground": "floor",
		"rows": [
			"######################",
			"#Xfffffffff##ffffffff#",
			"#fffffffffff#ffffffff#",
			"#fff##ffffff#fff##fff#",
			"#fff##ffffffffff##fff#",
			"#ffffffff##ffffffffff#",
			"#ffffffff##ffffffffff#",
			"#fff##fffffffff##ffff#",
			"#fff##fffffffff##ffff#",
			"#ffffffffffffffffffff#",
			"#ffffffffffffffffffff#",
			"#ffffffffffffffffffff#",
			"######################",
		],
		"spawns": {"entrance": Vector2i(2, 1)},
		"portals": [
			{"pos": Vector2i(1, 1), "to": "world", "spawn": "from_dungeon"},
		],
		"npcs": [],
	},
}

static func get_map(id: String) -> Dictionary:
	return MAPS[id]

static func is_walkable(map: Dictionary, pos: Vector2i) -> bool:
	var rows: Array = map["rows"]
	if pos.y < 0 or pos.y >= rows.size():
		return false
	var row: String = rows[pos.y]
	if pos.x < 0 or pos.x >= row.length():
		return false
	return row[pos.x] in WALKABLE
