extends Node
## Globaler Spielzustand: Party, Gold, Inventar, Item-/Gegner-Definitionen.
## Bewusst simpel gehalten, damit später Story/Level-System andocken können.

var main: Node = null
var gold := 120
var inventory := {}  # name -> anzahl
var party := []      # Array aus Dictionaries (siehe reset_party)
var boss_defeated := false   # Schlotbaron (Schlotwerk)
var boss2_defeated := false  # Monopolfürst (Konzernturm)
var boss3_defeated := false  # Der Spalter (Hassfestung) — alle drei öffnen Die Leere
var boss4_defeated := false  # Die Stille (Die Leere) — beendet das Spiel

const ITEMS := {
	"Trank": {"price": 20, "desc": "Heilt 30 LP.", "hp": 30, "mp": 0},
	"Äther": {"price": 35, "desc": "Stellt 12 MP wieder her.", "hp": 0, "mp": 12},
	"Elixier": {"price": 90, "desc": "Heilt 100 LP.", "hp": 100, "mp": 0},
}

# Bosse tragen "boss": true plus Inszenierungs-Daten (Thema, Musik, Texte).
# "proj" gibt Fernkämpfern ihre Spezialattacke (sludge/smog/coin/page/hate),
# "tint" färbt das Sprite im Kampf, "attack_line" ersetzt den Standard-Angriffstext.
const ENEMIES := {
	# --- Schlotwerk: die Umweltverschmutzer ---
	"schlammschleim": {"name": "Schlammschleim", "hp": 26, "atk": 7, "def": 2,
		"gold": 8, "xp": 7, "sprite": "schlammschleim", "proj": "sludge",
		"attack_line": "%s spuckt Giftschlamm auf %s!"},
	"qualmgeist": {"name": "Qualmgeist", "hp": 20, "atk": 9, "def": 1,
		"gold": 10, "xp": 8, "sprite": "qualmgeist", "proj": "smog",
		"attack_line": "%s hüllt %s in beißenden Qualm!"},
	"muellgnom": {"name": "Müllgnom", "hp": 40, "atk": 11, "def": 4,
		"gold": 18, "xp": 15, "sprite": "muellgnom",
		"attack_line": "%s wirft sich mit rostigem Schrott auf %s!"},
	"boss": {"name": "Schlotbaron", "hp": 450, "atk": 20, "def": 6, "gold": 500, "xp": 130,
		"sprite": "boss", "boss": true, "theme": "toxic", "song": "boss",
		"entrance_line": "Der Schlamm brodelt — etwas Riesiges wälzt sich empor!",
		"intro": [
			["Schlotbaron", "Wer wagt es, meine Produktion zu stören?!"],
			["Serena", "Euer Gift verseucht den Fluss von Lindenhain!"],
			["Schlotbaron", "Gift? Man nennt das FORTSCHRITT. Und jetzt: versinkt im Schlamm!"],
		],
		"aoe_name": "Giftflut", "ultimate_name": "Schwarzer Himmel"},
	# --- Konzernturm: die Kapitalisten ---
	"gierschlund": {"name": "Gierschlund", "hp": 55, "atk": 18, "def": 5,
		"gold": 30, "xp": 22, "sprite": "gierschlund", "proj": "coin",
		"tint": Color(1.2, 1.05, 0.6),
		"attack_line": "%s schleudert glühende Münzen auf %s!"},
	"paragraphengeist": {"name": "Paragraphengeist", "hp": 48, "atk": 20, "def": 3,
		"gold": 34, "xp": 24, "sprite": "paragraphengeist", "proj": "page",
		"attack_line": "%s wirft %s eine Abmahnung an den Kopf!"},
	"zinshund": {"name": "Zinshund", "hp": 58, "atk": 17, "def": 6,
		"gold": 36, "xp": 23, "sprite": "zinshund", "tint": Color(1.15, 1.0, 0.65),
		"attack_line": "%s treibt bei %s Schulden ein!"},
	"boss2": {"name": "Monopolfürst", "hp": 560, "atk": 26, "def": 8, "gold": 1200, "xp": 190,
		"sprite": "boss2", "boss": true, "theme": "gold", "song": "boss2",
		"entrance_line": "Goldstaub rieselt — die Chefetage fährt persönlich herab!",
		"intro": [
			["Monopolfürst", "Besucher! Habt ihr einen Termin? Der kostet extra."],
			["Rax", "Berechnung abgeschlossen: Eure Bilanz ist ein Verbrechen."],
			["Monopolfürst", "Alles hier gehört MIR. Auch eure Niederlage — Zeit ist Geld!"],
		],
		"aoe_name": "Münzhagel", "ultimate_name": "Feindliche Übernahme"},
	# --- Hassfestung: die Rassisten und Nationalisten ---
	"hetzer": {"name": "Hetzer", "hp": 72, "atk": 25, "def": 6,
		"gold": 30, "xp": 34, "sprite": "hetzer", "proj": "hate",
		"attack_line": "%s bewirft %s mit giftigen Parolen!"},
	"wutgeist": {"name": "Wutgeist", "hp": 60, "atk": 28, "def": 4,
		"gold": 28, "xp": 36, "sprite": "wutgeist", "tint": Color(1.35, 0.62, 0.62),
		"attack_line": "%s stürzt sich blind vor Wut auf %s!"},
	"schlaeger": {"name": "Schläger", "hp": 88, "atk": 26, "def": 9,
		"gold": 34, "xp": 40, "sprite": "schlaeger",
		"attack_line": "%s holt zum brutalen Schlag gegen %s aus!"},
	"hassprediger": {"name": "Hassprediger", "hp": 66, "atk": 30, "def": 5,
		"gold": 36, "xp": 42, "sprite": "hassprediger", "proj": "hate",
		"tint": Color(1.15, 0.8, 0.8),
		"attack_line": "%s schleudert %s einen Fluch aus Hass entgegen!"},
	"boss3": {"name": "Der Spalter", "hp": 680, "atk": 33, "def": 10, "gold": 900, "xp": 280,
		"sprite": "boss3", "boss": true, "theme": "hate", "song": "boss3",
		"entrance_line": "Die Glut verdichtet sich zu einem Schatten — er nimmt Gestalt an!",
		"intro": [
			["Der Spalter", "Ihr?! IHR gehört nicht hierher. NIEMAND gehört zu NIEMANDEM!"],
			["Milo", "Dein Hass endet heute. Lindenhain steht zusammen — alle."],
			["Der Spalter", "Zusammen?! Ich SPALTE euch wie morsches Holz!"],
		],
		"aoe_name": "Hasstirade", "ultimate_name": "Mauer des Hasses"},
	# --- Die Leere: keine Emotionen, Einsamkeit, Gleichgültigkeit ---
	"hohlgaenger": {"name": "Hohlgänger", "hp": 96, "atk": 30, "def": 8,
		"gold": 40, "xp": 48, "sprite": "hohlgaenger", "tint": Color(0.72, 0.74, 0.80),
		"attack_line": "%s greift %s an, ganz ohne Regung."},
	"grauschemen": {"name": "Grauschemen", "hp": 84, "atk": 33, "def": 6,
		"gold": 42, "xp": 50, "sprite": "grauschemen", "tint": Color(0.70, 0.76, 0.82),
		"attack_line": "%s streift %s mit eisiger Gleichgültigkeit."},
	"namenlose": {"name": "Der Namenlose", "hp": 110, "atk": 31, "def": 11,
		"gold": 44, "xp": 54, "sprite": "namenlose", "tint": Color(0.68, 0.70, 0.74),
		"attack_line": "%s schlägt nach %s, als wäre da niemand."},
	"boss4": {"name": "Die Stille", "hp": 860, "atk": 38, "def": 12, "gold": 0, "xp": 400,
		"sprite": "boss4", "boss": true, "theme": "void", "song": "boss4",
		"tint": Color(0.74, 0.77, 0.83),
		"attack_line": "%s lässt die Leere unter %s aufreißen.",
		"entrance_line": "Jedes Geräusch erlischt. Eine hohe graue Gestalt steht einfach da — und sieht durch euch hindurch.",
		"intro": [
			["Die Stille", "..."],
			["Serena", "So sag doch etwas! Wüte, hasse — IRGENDwas!"],
			["Die Stille", "Wozu. Nichts davon bedeutet etwas. Ihr auch nicht."],
		],
		"aoe_name": "Grauschleier", "ultimate_name": "Das große Vergessen"},
}

# Zufalls-Begegnungen pro Dungeon (Gruppen von Gegner-IDs).
const ENCOUNTERS := {
	"dungeon": [
		["schlammschleim", "schlammschleim"],
		["qualmgeist", "qualmgeist", "schlammschleim"],
		["muellgnom"],
		["muellgnom", "qualmgeist"],
		["schlammschleim", "qualmgeist"],
	],
	"dungeon2": [
		["gierschlund"],
		["gierschlund", "paragraphengeist"],
		["zinshund", "zinshund"],
		["paragraphengeist", "zinshund"],
		["gierschlund", "zinshund", "paragraphengeist"],
	],
	"dungeon3": [
		["hetzer"],
		["hetzer", "wutgeist"],
		["schlaeger", "wutgeist"],
		["hassprediger", "hetzer"],
		["schlaeger", "hassprediger", "wutgeist"],
	],
	"dungeon4": [
		["grauschemen", "grauschemen"],
		["hohlgaenger", "grauschemen"],
		["namenlose"],
		["namenlose", "hohlgaenger"],
		["hohlgaenger", "grauschemen", "namenlose"],
	],
}

## Nutzer-Einstellungen (überleben Neustarts via user://settings.cfg).
var touch_pad := true  # Bildschirm-Tasten (D-Pad) anzeigen — Standard: an

func _ready() -> void:
	_load_settings()
	reset_party()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		touch_pad = cfg.get_value("input", "touch_pad", true)

func set_touch_pad(value: bool) -> void:
	touch_pad = value
	var cfg := ConfigFile.new()
	cfg.set_value("input", "touch_pad", value)
	cfg.save("user://settings.cfg")
	if main != null:
		var t: Variant = main.get("touch")
		if t != null and is_instance_valid(t):
			t.apply_setting()

## Kompletter Neustart (nach dem Abspann): alles zurück auf Anfang.
func reset_all() -> void:
	gold = 120
	boss_defeated = false
	boss2_defeated = false
	boss3_defeated = false
	boss4_defeated = false
	reset_party()

## Portal-Sperre: einfache Boss-Flags werden direkt gelesen; der Sonderfall
## „all_bosses" verlangt, dass alle drei Plagen gefallen sind (öffnet Die Leere).
func is_unlocked(flag: String) -> bool:
	if flag == "all_bosses":
		return boss_defeated and boss2_defeated and boss3_defeated
	return get(flag)

func reset_party() -> void:
	inventory = {"Trank": 3, "Äther": 1}
	party = [
		{
			"id": "serena", "name": "Serena", "class": "Schwertkämpferin",
			"level": 1, "xp": 0,
			"hp": 60, "max_hp": 60, "mp": 10, "max_mp": 10,
			"atk": 14, "mag": 4, "def": 6,
			"abilities": [
				{"name": "Klingenwirbel", "cost": 4, "target": "all",
					"power": 10, "kind": "phys",
					"desc": "Trifft alle Gegner."},
				{"name": "Sturmschnitt", "cost": 2, "target": "one",
					"power": 13, "kind": "pierce",
					"desc": "Schneller Einzelhieb."},
				{"name": "Fokusstoß", "cost": 3, "target": "one",
					"power": 16, "kind": "pierce", "unlock_bosses": 1,
					"desc": "Durchbohrt die Verteidigung."},
				{"name": "Klingentanz", "cost": 8, "target": "one",
					"power": 6, "kind": "dance", "unlock_bosses": 2,
					"desc": "Fünf Blitzschnitte im Stern, dann der Fallstreich."},
				{"name": "Klingensturm", "cost": 12, "target": "all",
					"power": 20, "kind": "phys", "unlock_bosses": 3,
					"desc": "Ein reißender Klingenorkan über alle Feinde."},
			],
			"ultimate": {"name": "Sternenklinge",
				"desc": "Lichtklingen zerreißen alle Feinde. (1x pro Kampf)"},
		},
		{
			"id": "milo", "name": "Milo", "class": "Zauberer",
			"level": 1, "xp": 0,
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
			"summons": [
				{"id": "ifrit", "name": "Ifrit", "attack": "Höllenfeuer",
					"cost": 16, "unlock_level": 1, "power": 34,
					"unlock_bosses": 1,
					"desc": "Feuerdämon — Höllenfeuer auf alle Gegner."},
				{"id": "leviathan", "name": "Leviathan", "attack": "Sintflut",
					"cost": 24, "unlock_level": 1, "power": 38,
					"unlock_bosses": 2,
					"desc": "Wasserschlange — Sintflut auf alle Gegner."},
				{"id": "bahamut", "name": "Bahamut", "attack": "Megaflare",
					"cost": 32, "unlock_level": 1, "power": 52,
					"unlock_bosses": 3,
					"desc": "Drachenkönig — Megaflare zerschmettert alle Gegner."},
			],
		},
		{
			"id": "rax", "name": "Rax", "class": "Kampfroboter",
			"level": 1, "xp": 0,
			"hp": 72, "max_hp": 72, "mp": 16, "max_mp": 16,
			"atk": 12, "mag": 12, "def": 10,
			"abilities": [
				{"name": "Laserstoß", "cost": 4, "target": "one",
					"power": 22, "kind": "beam",
					"desc": "Gebündelter Energiestrahl."},
				{"name": "Reparatur", "cost": 4, "target": "ally",
					"power": 30, "kind": "heal",
					"desc": "Nanit-Reparatur heilt einen Verbündeten."},
				{"name": "Raketensalve", "cost": 7, "target": "all",
					"power": 15, "kind": "rocket", "unlock_bosses": 1,
					"desc": "Raketen auf alle Gegner."},
				{"name": "Atombombe", "cost": 14, "target": "all",
					"power": 46, "kind": "nuke", "unlock_bosses": 2,
					"desc": "Taktischer Sprengkopf — verwüstet das Schlachtfeld."},
				{"name": "Plasmalanze", "cost": 11, "target": "one",
					"power": 44, "kind": "beam", "unlock_bosses": 3,
					"desc": "Gebündelte Plasmalanze durchbohrt ein Ziel komplett."},
			],
			"ultimate": {"name": "Orbitallaser",
				"desc": "Ein Strahl aus dem Orbit vernichtet alle Feinde. (1x pro Kampf)"},
		},
	]
	# Besiegte Bosse hinterlassen dauerhafte Segnungen — sie überstehen auch
	# Niederlagen, sonst wären die späteren Dungeons unschaffbar.
	if boss_defeated:
		apply_blessing()
	if boss2_defeated:
		apply_blessing2()
	if boss3_defeated:
		apply_blessing3()

## Segnung des reinen Flusses (nach dem Schlotbaron): Machtschub für den Konzernturm.
func apply_blessing() -> void:
	for member in party:
		member["max_hp"] += 35
		member["hp"] = member["max_hp"]
		member["max_mp"] += 12
		member["mp"] = member["max_mp"]
		member["atk"] += 6
		member["mag"] += 8
		member["def"] += 3

## Segnung des freien Marktes... nein: des geteilten Wohlstands (nach dem
## Monopolfürsten) — Rückenwind für die Hassfestung.
func apply_blessing2() -> void:
	for member in party:
		member["max_hp"] += 30
		member["hp"] = member["max_hp"]
		member["max_mp"] += 10
		member["mp"] = member["max_mp"]
		member["atk"] += 5
		member["mag"] += 6
		member["def"] += 3

## Segnung der geeinten Herzen (nach dem Spalter) — letzter Rückenwind, bevor
## sich Die Leere öffnet, in der Gefühl selbst zur Waffe wird.
func apply_blessing3() -> void:
	for member in party:
		member["max_hp"] += 30
		member["hp"] = member["max_hp"]
		member["max_mp"] += 10
		member["mp"] = member["max_mp"]
		member["atk"] += 5
		member["mag"] += 6
		member["def"] += 4

## ---------- Stufenaufstieg (Level-System) ----------

# Benötigte EP, um von der angegebenen Stufe zur nächsten aufzusteigen.
func xp_to_next(level: int) -> int:
	return 30 + (level - 1) * 35

# Wachstum pro Stufe je Held: Serena kämpferisch, Milo magisch.
const LEVEL_GROWTH := {
	"serena": {"max_hp": 9, "max_mp": 2, "atk": 3, "mag": 1, "def": 2},
	"milo": {"max_hp": 6, "max_mp": 4, "atk": 1, "mag": 3, "def": 1},
	"rax": {"max_hp": 9, "max_mp": 3, "atk": 2, "mag": 2, "def": 3},
}

# Verteilt EP an alle lebenden Mitglieder. Rückgabe: Liste der Aufstiege
# [{name, level}] für die Kampf-Meldung. Ein Aufstieg heilt voll.
func award_xp(amount: int) -> Array:
	var ups := []
	for m in party:
		if m["hp"] <= 0:
			continue
		m["xp"] = m.get("xp", 0) + amount
		while m["xp"] >= xp_to_next(m.get("level", 1)):
			m["xp"] -= xp_to_next(m["level"])
			m["level"] += 1
			var g: Dictionary = LEVEL_GROWTH.get(m["id"], LEVEL_GROWTH["serena"])
			m["max_hp"] += g["max_hp"]
			m["max_mp"] += g["max_mp"]
			m["atk"] += g["atk"]
			m["mag"] += g["mag"]
			m["def"] += g["def"]
			m["hp"] = m["max_hp"]
			m["mp"] = m["max_mp"]
			var up := {"name": m["name"], "level": m["level"]}
			# Schaltet diese Stufe eine Beschwörung frei? (nur Milo hat "summons")
			for sm in m.get("summons", []):
				if sm["unlock_level"] == m["level"]:
					up["unlock"] = sm["name"]
			ups.append(up)
	return ups

## ---------- Fähigkeiten-Siegel ----------
## Mächtige Fähigkeiten sind anfangs versiegelt; die Siegel fallen mit JEDEM
## Boss-Sieg — unabhängig davon, welcher Dungeon zuerst fällt. Jeder Held hat
## drei versiegelte Fähigkeiten (`unlock_bosses` 1/2/3): der erste Bosssieg
## löst Stufe 1, der zweite Stufe 2, der dritte Stufe 3. Im letzten Dungeon
## (nach allen drei Bossen) steht damit alles zur Verfügung.

## Anzahl der bisher gefallenen Haupt-Bosse (0-3, boss4 zählt nicht mit).
func bosses_defeated_count() -> int:
	var c := 0
	if boss_defeated: c += 1
	if boss2_defeated: c += 1
	if boss3_defeated: c += 1
	return c

func skill_unlocked(member: Dictionary, ab: Dictionary) -> bool:
	if member.get("level", 1) < ab.get("unlock_level", 0):
		return false
	return bosses_defeated_count() >= ab.get("unlock_bosses", 0)

const _BOSS_ORDINAL := ["", "ersten", "zweiten", "dritten"]

## Kurzer Hinweis, warum eine Fähigkeit noch gesperrt ist.
func skill_lock_hint(member: Dictionary, ab: Dictionary) -> String:
	var need: int = ab.get("unlock_bosses", 0)
	if bosses_defeated_count() < need:
		return "versiegelt bis zum %s Bosssieg" % _BOSS_ORDINAL[clampi(need, 1, 3)]
	return "ab Stufe %d" % ab.get("unlock_level", 0)

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
