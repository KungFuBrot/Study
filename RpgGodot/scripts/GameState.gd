extends Node
## Globaler Spielzustand: Party, Gold, Inventar, Item-/Gegner-Definitionen.
## Bewusst simpel gehalten, damit später Story/Level-System andocken können.

var main: Node = null
var gold := 120
var inventory := {}  # name -> anzahl
var party := []      # Array aus Dictionaries (siehe reset_party)

const ITEMS := {
	"Trank": {"price": 20, "desc": "Heilt 30 LP.", "hp": 30, "mp": 0},
	"Äther": {"price": 35, "desc": "Stellt 12 MP wieder her.", "hp": 0, "mp": 12},
}

const ENEMIES := {
	"slime": {"name": "Schleim", "hp": 26, "atk": 7, "def": 2, "gold": 8, "sprite": "slime"},
	"bat": {"name": "Höhlenfledermaus", "hp": 20, "atk": 9, "def": 1, "gold": 10, "sprite": "bat"},
	"skeleton": {"name": "Skelett", "hp": 40, "atk": 11, "def": 4, "gold": 18, "sprite": "skeleton"},
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
			"special": {
				"name": "Klingenwirbel", "cost": 4, "target": "all",
				"power": 10, "kind": "phys",
				"desc": "Wirbelangriff, trifft alle Gegner.",
			},
		},
		{
			"id": "milo", "name": "Milo", "class": "Zauberer",
			"hp": 42, "max_hp": 42, "mp": 24, "max_mp": 24,
			"atk": 6, "mag": 16, "def": 4,
			"special": {
				"name": "Feuerball", "cost": 5, "target": "one",
				"power": 26, "kind": "magic",
				"desc": "Mächtiger Feuerzauber gegen einen Gegner.",
			},
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
