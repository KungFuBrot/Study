extends Node
## Globaler Spielzustand: Party, Gold, Inventar, Item-/Gegner-Definitionen.
## Bewusst simpel gehalten, damit später Story/Level-System andocken können.

var main: Node = null
var gold := 120
var inventory := {}  # name -> anzahl
var party := []      # Array aus Dictionaries (siehe reset_party)
var boss_defeated := false  # bleibt auch nach einer Niederlage bestehen

const ITEMS := {
	"Trank": {"price": 20, "desc": "Heilt 30 LP.", "hp": 30, "mp": 0},
	"Äther": {"price": 35, "desc": "Stellt 12 MP wieder her.", "hp": 0, "mp": 12},
}

const ENEMIES := {
	"slime": {"name": "Schleim", "hp": 26, "atk": 7, "def": 2, "gold": 8, "sprite": "slime"},
	"bat": {"name": "Höhlenfledermaus", "hp": 20, "atk": 9, "def": 1, "gold": 10, "sprite": "bat"},
	"skeleton": {"name": "Skelett", "hp": 40, "atk": 11, "def": 4, "gold": 18, "sprite": "skeleton"},
	"boss": {"name": "Knochenkönig", "hp": 170, "atk": 17, "def": 5, "gold": 200, "sprite": "boss"},
}

# Zufalls-Begegnungen im Dungeon (Gruppen von Gegner-IDs).
const DUNGEON_ENCOUNTERS := [
	["slime", "slime"],
	["bat", "bat", "slime"],
	["skeleton"],
	["skeleton", "bat"],
	["slime", "bat"],
]

func _ready() -> void:
	reset_party()

func reset_party() -> void:
	inventory = {"Trank": 3, "Äther": 1}
	party = [
		{
			"id": "serena", "name": "Serena", "class": "Schwertkämpferin",
			"hp": 60, "max_hp": 60, "mp": 10, "max_mp": 10,
			"atk": 14, "mag": 4, "def": 6,
			"abilities": [
				{"name": "Klingenwirbel", "cost": 4, "target": "all",
					"power": 10, "kind": "phys",
					"desc": "Trifft alle Gegner."},
				{"name": "Fokusstoß", "cost": 3, "target": "one",
					"power": 16, "kind": "pierce",
					"desc": "Durchbohrt die Verteidigung."},
			],
		},
		{
			"id": "milo", "name": "Milo", "class": "Zauberer",
			"hp": 42, "max_hp": 42, "mp": 24, "max_mp": 24,
			"atk": 6, "mag": 16, "def": 4,
			"abilities": [
				{"name": "Feuerball", "cost": 5, "target": "one",
					"power": 26, "kind": "magic",
					"desc": "Starker Feuerzauber."},
				{"name": "Heillicht", "cost": 4, "target": "ally",
					"power": 28, "kind": "heal",
					"desc": "Heilt einen Verbündeten."},
			],
		},
	]

func add_item(item_name: String, count := 1) -> void:
	inventory[item_name] = inventory.get(item_name, 0) + count

func use_item(item_name: String) -> bool:
	if inventory.get(item_name, 0) <= 0:
		return false
	inventory[item_name] -= 1
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	return true

func party_alive() -> bool:
	for member in party:
		if member["hp"] > 0:
			return true
	return false

func random_dungeon_encounter() -> Array:
	return DUNGEON_ENCOUNTERS[randi() % DUNGEON_ENCOUNTERS.size()]
