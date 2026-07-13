class_name MapData
## ASCII-Karten. Legende:
##  g Gras, t Baum, p Weg, w Wasser, b Brücke, m Berg,
##  R Dach, W Hauswand, D Tür, f Fabrikboden, # Fabrikwand,
##  i Marmorboden, I Turmwand, y Festungsboden, Y Festungswand,
##  n Leere-Boden, N Leere-Wand,
##  T Stadt (Portal), C Schlotwerk (Portal), F Konzernturm (Portal),
##  H Hassfestung (Portal), V Die Leere (Portal), X Dungeon-Ausgang (Portal)

const WALKABLE := ["g", "p", "b", "f", "i", "y", "n", "T", "C", "F", "H", "V", "X"]

const TILE_FOR_CHAR := {
	"g": "grass", "t": "tree", "p": "path", "w": "water", "b": "bridge",
	"m": "mount", "R": "roof", "W": "wall", "D": "door", "f": "floor",
	"#": "dwall", "i": "ice", "I": "iwall", "y": "hfloor", "Y": "hwall",
	"n": "void", "N": "vwall",
	"T": "town_icon", "C": "factory_icon", "F": "tower_icon", "H": "keep_icon",
	"V": "void_icon", "X": "path",
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
					"Drei Plagen würgen unser Land.",
					"Im Osten verpestet das Schlotwerk den Fluss —",
					"der Schlotbaron kippt seinen Giftschlamm einfach hinein.",
					"Im Nordosten presst der Konzernturm die Dörfer aus,",
					"und im Südwesten schürt eine Festung Hass und Zwietracht.",
					"Geht sie an, in welcher Reihenfolge ihr wollt — jede",
					"macht euch stärker für die nächste.",
					"Doch hütet euch: Fallen alle drei, öffnet sich im Norden",
					"ein grauer Riss. Was dahinter wohnt, hasst nicht einmal —",
					"es fühlt gar nichts mehr. Das ist das Kälteste von allem."]},
			{"id": "npc_kid", "name": "Pia", "pos": Vector2i(12, 8),
				"lines": [
					"Der Fluss hat früher geglitzert! Jetzt ist er ganz braun.",
					"Papa sagt, das kommt vom Schlotwerk. Macht ihr das wieder heil?"]},
			{"id": "npc_shop", "name": "Händlerin Greta", "pos": Vector2i(15, 4), "shop": true,
				"lines": ["Willkommen! Faire Preise, gerechter Lohn — schaut euch um."]},
		],
	},
	"world": {
		"name": "Weltkarte",
		"music": "world",
		"encounters": false,
		"ground": "grass",
		"rows": [
			"mmmmmmmmmmmmmmmmmmmmmm",
			"mggggtgggggwwggmmmmmmm",
			"mggggggVgggwwggmmmFmmm",
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
			"mggtHggggggwwggggtgggm",
			"mggggggggggwwggggggggm",
			"mmmmmmmmmmmmmmmmmmmmmm",
		],
		"spawns": {"from_town": Vector2i(2, 4), "from_dungeon": Vector2i(18, 9),
			"from_dungeon2": Vector2i(18, 3), "from_dungeon3": Vector2i(4, 12),
			"from_dungeon4": Vector2i(7, 3)},
		"portals": [
			{"pos": Vector2i(2, 3), "to": "town", "spawn": "from_world"},
			{"pos": Vector2i(18, 10), "to": "dungeon", "spawn": "entrance"},
			{"pos": Vector2i(18, 2), "to": "dungeon2", "spawn": "entrance"},
			{"pos": Vector2i(4, 13), "to": "dungeon3", "spawn": "entrance"},
			{"pos": Vector2i(7, 2), "to": "dungeon4", "spawn": "entrance",
				"locked_until": "all_bosses", "locked_name": "Grauer Riss",
				"locked_msg": "Ein grauer Riss klafft in der Welt — dahinter nichts als Stille. Er lässt sich nicht öffnen, solange auch nur eine der drei Plagen weiterlebt. Erst wenn Schlotbaron, Monopolfürst und der Spalter gefallen sind, gibt die Leere ihren Eingang frei."},
		],
		"npcs": [],
	},
	"dungeon": {
		"name": "Schlotwerk",
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
	"dungeon2": {
		"name": "Konzernturm",
		"music": "dungeon2",
		"encounters": true,
		"ground": "ice",
		"rows": [
			"IIIIIIIIIIIIIIIIIIIIII",
			"IXiiiiiiIIiiiiiiiiiiiI",
			"IiiiiiiiIIiiiiIIIiiiiI",
			"IiiIIiiiiiiiiiiIIIiiiI",
			"IiiIIiiiiIIiiiiiiiiiiI",
			"IiiiiiiiiiIIiiiiiiiiiI",
			"IiiiiiiiiiiiiiiIIiiiiI",
			"IiiiIIIiiiiiiiiiIIiiiI",
			"IiiiIIIiiiiiiiiiiiiiiI",
			"IiiiiiiiiiiiiiiiiiiiiI",
			"IiiiiiiiiiiiiiiiiiiiiI",
			"IiiiiiiiiiiiiiiiiiiiiI",
			"IIIIIIIIIIIIIIIIIIIIII",
		],
		"spawns": {"entrance": Vector2i(2, 1)},
		"portals": [
			{"pos": Vector2i(1, 1), "to": "world", "spawn": "from_dungeon2"},
		],
		"npcs": [],
	},
	"dungeon3": {
		"name": "Hassfestung",
		"music": "dungeon3",
		"encounters": true,
		"ground": "hfloor",
		"rows": [
			"YYYYYYYYYYYYYYYYYYYYYY",
			"YXyyyyyyYYyyyyyyyyyyyY",
			"YyyYYyyyyyyyyyYYYyyyyY",
			"YyyYYyyyYYyyyyyyYYyyyY",
			"YyyyyyyyYYyyyyyyyyyyyY",
			"YyyyyyyyyyyyyYYyyyyyyY",
			"YyyYYYyyyyyyyYYyyYYyyY",
			"YyyyyyyyyYYyyyyyyYYyyY",
			"YyyyyyyyyYYyyyyyyyyyyY",
			"YyyYYyyyyyyyyyYYyyyyyY",
			"YyyyyyyyyyyyyyyyyyyyyY",
			"YyyyyyyyyyyyyyyyyyyyyY",
			"YYYYYYYYYYYYYYYYYYYYYY",
		],
		"spawns": {"entrance": Vector2i(2, 1)},
		"portals": [
			{"pos": Vector2i(1, 1), "to": "world", "spawn": "from_dungeon3"},
		],
		"npcs": [],
	},
	"dungeon4": {
		"name": "Die Leere",
		"music": "dungeon4",
		"encounters": true,
		"ground": "void",
		"rows": [
			"NNNNNNNNNNNNNNNNNNNNNN",
			"NXnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnNnnnnnnnnnNnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnnnnNnnnnnnnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnNnnnnnnnnnNnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NnnnnnnnnnnnnnnnnnnnnN",
			"NNNNNNNNNNNNNNNNNNNNNN",
		],
		"spawns": {"entrance": Vector2i(2, 1)},
		"portals": [
			{"pos": Vector2i(1, 1), "to": "world", "spawn": "from_dungeon4"},
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
