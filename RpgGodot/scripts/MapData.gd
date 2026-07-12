class_name MapData
## ASCII-Karten. Legende:
##  g Gras, t Baum, p Weg, w Wasser, b Brücke, m Berg,
##  R Dach, W Hauswand, D Tür, f Fabrikboden, # Fabrikwand,
##  i Marmorboden, I Turmwand, y Festungsboden, Y Festungswand,
##  T Stadt (Portal), C Schlotwerk (Portal), F Konzernturm (Portal),
##  H Hassfestung (Portal), X Dungeon-Ausgang (Portal)

const WALKABLE := ["g", "p", "b", "f", "i", "y", "T", "C", "F", "H", "X"]

const TILE_FOR_CHAR := {
	"g": "grass", "t": "tree", "p": "path", "w": "water", "b": "bridge",
	"m": "mount", "R": "roof", "W": "wall", "D": "door", "f": "floor",
	"#": "dwall", "i": "ice", "I": "iwall", "y": "hfloor", "Y": "hwall",
	"T": "town_icon", "C": "factory_icon", "F": "tower_icon", "H": "keep_icon",
	"X": "path",
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
					"Beginnt beim Schlotwerk. Eines führt zum anderen:",
					"Der Baron schmiert den Fürsten, der Fürst füttert den Hass."]},
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
			"mggggggggggwwggmmmFmmm",
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
			"from_dungeon2": Vector2i(18, 3), "from_dungeon3": Vector2i(4, 12)},
		"portals": [
			{"pos": Vector2i(2, 3), "to": "town", "spawn": "from_world"},
			{"pos": Vector2i(18, 10), "to": "dungeon", "spawn": "entrance"},
			{"pos": Vector2i(18, 2), "to": "dungeon2", "spawn": "entrance",
				"locked_until": "boss_defeated", "locked_name": "Goldene Versiegelung",
				"locked_msg": "Die goldenen Tore des Konzernturms sind verriegelt. Am Portal prangt: „Kein Zutritt — erst wenn die Schmiergeld-Pipeline aus dem Schlotwerk versiegt.“ Bezwingt den Schlotbaron!"},
			{"pos": Vector2i(4, 13), "to": "dungeon3", "spawn": "entrance",
				"locked_until": "boss2_defeated", "locked_name": "Wall aus Misstrauen",
				"locked_msg": "Ein Wall aus Misstrauen umgibt die Hassfestung. Solange der Monopolfürst den Hass finanziert, ist hier kein Durchkommen — stürzt ihn zuerst!"},
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
