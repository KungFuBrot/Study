extends Node
## Globaler Spielzustand: Party, Gold, Inventar, Item-/Gegner-Definitionen.
## Bewusst simpel gehalten, damit später Story/Level-System andocken können.

var main: Node = null
var gold := 120
var inventory := {}  # name -> anzahl
var party := []      # Array aus Dictionaries (siehe reset_party)
var boss_defeated := false   # Knochenkönig (Finsterhöhle)
var boss2_defeated := false  # Frostkoloss (Frostgrotte) — beendet das Spiel

const ITEMS := {
	"Trank": {"price": 20, "desc": "Heilt 30 LP.", "hp": 30, "mp": 0},
	"Äther": {"price": 35, "desc": "Stellt 12 MP wieder her.", "hp": 0, "mp": 12},
	"Elixier": {"price": 90, "desc": "Heilt 100 LP.", "hp": 100, "mp": 0},
}

# Bosse tragen "boss": true plus Inszenierungs-Daten (Thema, Musik, Texte).
const ENEMIES := {
	"slime": {"name": "Schleim", "hp": 26, "atk": 7, "def": 2, "gold": 8, "sprite": "slime"},
	"bat": {"name": "Höhlenfledermaus", "hp": 20, "atk": 9, "def": 1, "gold": 10, "sprite": "bat"},
	"skeleton": {"name": "Skelett", "hp": 40, "atk": 11, "def": 4, "gold": 18, "sprite": "skeleton"},
	"frostwolf": {"name": "Frostwolf", "hp": 55, "atk": 17, "def": 5, "gold": 25, "sprite": "frostwolf"},
	"eisgeist": {"name": "Eisgeist", "hp": 45, "atk": 19, "def": 3, "gold": 28, "sprite": "eisgeist"},
	"boss": {"name": "Knochenkönig", "hp": 450, "atk": 20, "def": 6, "gold": 500, "sprite": "boss",
		"boss": true, "theme": "bone", "song": "boss",
		"entrance_line": "Der Herrscher der Finsterhöhle erhebt sich!",
		"aoe_name": "Knochensturm", "ultimate_name": "Armee der Verdammten"},
	"boss2": {"name": "Frostkoloss", "hp": 520, "atk": 26, "def": 8, "gold": 800, "sprite": "boss2",
		"boss": true, "theme": "frost", "song": "boss2",
		"entrance_line": "Das ewige Eis erwacht — der Wächter der Frostgrotte!",
		"aoe_name": "Eissturm", "ultimate_name": "Ewiger Winter"},
}

# Zufalls-Begegnungen pro Dungeon (Gruppen von Gegner-IDs).
const ENCOUNTERS := {
	"dungeon": [
		["slime", "slime"],
		["bat", "bat", "slime"],
		["skeleton"],
		["skeleton", "bat"],
		["slime", "bat"],
	],
	"dungeon2": [
		["frostwolf"],
		["frostwolf", "eisgeist"],
		["eisgeist", "eisgeist"],
		["frostwolf", "frostwolf"],
		["eisgeist", "frostwolf", "eisgeist"],
	],
}

func _ready() -> void:
	reset_party()

## Kompletter Neustart (nach dem Abspann): alles zurück auf Anfang.
func reset_all() -> void:
	gold = 120
	boss_defeated = false
	boss2_defeated = false
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
			"ultimate": {"name": "Sternenklinge",
				"desc": "Lichtklingen zerreißen alle Feinde. (1x pro Kampf)"},
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
			"ultimate": {"name": "Meteorregen",
				"desc": "Brennende Meteore auf alle Feinde. (1x pro Kampf)"},
		},
	]
	# Nach dem Sieg über den Knochenkönig bleibt seine Segnung erhalten,
	# auch wenn die Gruppe später fällt — sonst wäre die Frostgrotte unschaffbar.
	if boss_defeated:
		apply_blessing()

## Segnung des Knochenkönigs: dauerhafter Machtschub für die Frostgrotte.
func apply_blessing() -> void:
	for member in party:
		member["max_hp"] += 35
		member["hp"] = member["max_hp"]
		member["max_mp"] += 12
		member["mp"] = member["max_mp"]
		member["atk"] += 6
		member["mag"] += 8
		member["def"] += 3

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

func random_encounter(map_id: String) -> Array:
	var groups: Array = ENCOUNTERS[map_id]
	return groups[randi() % groups.size()]
