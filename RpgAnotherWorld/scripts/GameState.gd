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
	"Potion": {"price": 20, "desc": "Restores 30 HP.", "hp": 30, "mp": 0},
	"Ether": {"price": 35, "desc": "Restores 12 MP.", "hp": 0, "mp": 12},
	"Elixir": {"price": 90, "desc": "Restores 100 HP.", "hp": 100, "mp": 0},
}

# Bosse tragen "boss": true plus Inszenierungs-Daten (Thema, Musik, Texte).
# "proj" gibt Fernkämpfern ihre Spezialattacke (sludge/smog/coin/page/hate),
# "tint" färbt das Sprite im Kampf, "attack_line" ersetzt den Standard-Angriffstext.
# "special" ist die benannte Spezialattacke normaler Monster (alle 3 Züge):
#   kind = barrage (Geschoss-Salve auf alle) / frenzy (Mehrfach-Sturm auf einen)
#        / slam (Sprung-Bodenschlag auf alle) / drain (Lebensentzug + Selbstheilung).
const ENEMIES := {
	# --- Schlotwerk: die Umweltverschmutzer ---
	"schlammschleim": {"name": "Sludge Slime", "hp": 26, "atk": 7, "def": 2, "tier": 0,
		"gold": 8, "xp": 7, "sprite": "schlammschleim", "proj": "sludge",
		"attack_line": "%s spits toxic sludge at %s!",
		"special": {"name": "Sludge Flood", "kind": "barrage"}},
	"qualmgeist": {"name": "Smog Wraith", "hp": 20, "atk": 9, "def": 1, "tier": 0,
		"gold": 10, "xp": 8, "sprite": "qualmgeist", "proj": "smog",
		"attack_line": "%s wraps %s in acrid smog!",
		"special": {"name": "Choking Cloud", "kind": "barrage"}},
	"muellgnom": {"name": "Scrap Gnome", "hp": 40, "atk": 11, "def": 4, "tier": 0,
		"gold": 18, "xp": 15, "sprite": "muellgnom",
		"attack_line": "%s hurls rusty scrap at %s!",
		"special": {"name": "Scrap Avalanche", "kind": "slam"}},
	"boss": {"name": "Smokestack Baron", "hp": 450, "atk": 20, "def": 6, "gold": 500, "xp": 130, "tier": 0,
		"sprite": "boss", "boss": true, "theme": "toxic", "song": "boss",
		"entrance_line": "The sludge churns — something enormous heaves itself out of the settling tank!",
		"intro": [
			["Smokestack Baron", "Who dares interrupt my production?! Do you know what one minute of downtime COSTS?"],
			["Helen", "And do you know what your poison costs? The river. The fish. A child who isn't allowed to swim anymore."],
			["Smokestack Baron", "Touching. It's called PROGRESS — and progress demands sacrifices!"],
			["Helen", "Agreed. Then let's start with you."],
		],
		"aoe_name": "Toxic Flood", "ultimate_name": "Black Sky",
		"ultimate2_name": "Core Meltdown"},
	# --- Konzernturm: die Kapitalisten ---
	"gierschlund": {"name": "Greedmaw", "hp": 55, "atk": 18, "def": 5, "tier": 1,
		"gold": 30, "xp": 22, "sprite": "gierschlund", "proj": "coin",
		"tint": Color(1.2, 1.05, 0.6),
		"attack_line": "%s flings red-hot coins at %s!",
		"special": {"name": "Coin Fountain", "kind": "barrage"}},
	"paragraphengeist": {"name": "Clause Phantom", "hp": 48, "atk": 20, "def": 3, "tier": 1,
		"gold": 34, "xp": 24, "sprite": "paragraphengeist", "proj": "page",
		"attack_line": "%s slaps %s with a cease-and-desist!",
		"special": {"name": "Class Action", "kind": "barrage"}},
	"zinshund": {"name": "Interest Hound", "hp": 58, "atk": 17, "def": 6, "tier": 1,
		"gold": 36, "xp": 23, "sprite": "zinshund", "tint": Color(1.15, 1.0, 0.65),
		"attack_line": "%s collects debts from %s!",
		"special": {"name": "Compound Interest", "kind": "frenzy"}},
	"boss2": {"name": "Monopoly Prince", "hp": 560, "atk": 26, "def": 8, "gold": 1200, "xp": 190, "tier": 1,
		"sprite": "boss2", "boss": true, "theme": "gold", "song": "boss2",
		"entrance_line": "Gold dust trickles from the chandeliers — the executive floor descends in person!",
		"intro": [
			["Monopoly Prince", "Visitors! Do you have an appointment? That costs extra. So does breathing in here, by the way."],
			["Wally", "Calculation complete: you own 97 percent of this valley and 0 percent of its decency."],
			["Monopoly Prince", "Ownership IS decency, tin can! Even your defeat goes on my books as profit."],
			["Wally", "Objection. This entry is now being cancelled."],
		],
		"aoe_name": "Coin Hail", "ultimate_name": "Hostile Takeover",
		"ultimate2_name": "Market Crash"},
	# --- Hassfestung: die Rassisten und Nationalisten ---
	"hetzer": {"name": "Rabble-Rouser", "hp": 72, "atk": 25, "def": 6, "tier": 2,
		"gold": 30, "xp": 34, "sprite": "hetzer", "proj": "hate",
		"attack_line": "%s pelts %s with venomous slogans!",
		"special": {"name": "Slogan Storm", "kind": "barrage"}},
	"wutgeist": {"name": "Rage Wraith", "hp": 60, "atk": 28, "def": 4, "tier": 2,
		"gold": 28, "xp": 36, "sprite": "wutgeist", "tint": Color(1.35, 0.62, 0.62),
		"attack_line": "%s lunges at %s, blind with rage!",
		"special": {"name": "Blind Fury", "kind": "frenzy"}},
	"schlaeger": {"name": "Bruiser", "hp": 88, "atk": 26, "def": 9, "tier": 2,
		"gold": 34, "xp": 40, "sprite": "schlaeger",
		"attack_line": "%s winds up a brutal blow at %s!",
		"special": {"name": "Earthshaker", "kind": "slam"}},
	"hassprediger": {"name": "Hate Preacher", "hp": 66, "atk": 30, "def": 5, "tier": 2,
		"gold": 36, "xp": 42, "sprite": "hassprediger", "proj": "hate",
		"tint": Color(1.15, 0.8, 0.8),
		"attack_line": "%s hurls a curse of pure hate at %s!",
		"special": {"name": "Mass Anathema", "kind": "barrage"}},
	"boss3": {"name": "The Divider", "hp": 680, "atk": 33, "def": 10, "gold": 900, "xp": 280, "tier": 2,
		"sprite": "boss3", "boss": true, "theme": "hate", "song": "boss3",
		"entrance_line": "The embers thicken into a shadow — it is taking shape!",
		"intro": [
			["The Divider", "You?! YOU don't belong here! NOBODY belongs to ANYBODY!"],
			["Janosch", "Strange. From far away you looked like a wall. Up close, you're just a lonely man, shouting."],
			["The Divider", "I divided them ALL! Village against village! Brother against brother!"],
			["Janosch", "And yet today three strangers stand before you, side by side. It didn't work."],
		],
		"aoe_name": "Hate Tirade", "ultimate_name": "Wall of Hate",
		"ultimate2_name": "Fault Line"},
	# --- Die Leere: keine Emotionen, Einsamkeit, Gleichgültigkeit ---
	"hohlgaenger": {"name": "Hollow Walker", "hp": 96, "atk": 30, "def": 8, "tier": 3,
		"gold": 40, "xp": 48, "sprite": "hohlgaenger", "tint": Color(0.72, 0.74, 0.80),
		"attack_line": "%s attacks %s without a flicker of feeling.",
		"special": {"name": "Soul Siphon", "kind": "drain"}},
	"grauschemen": {"name": "Gray Shade", "hp": 84, "atk": 33, "def": 6, "tier": 3,
		"gold": 42, "xp": 50, "sprite": "grauschemen", "tint": Color(0.70, 0.76, 0.82),
		"attack_line": "%s brushes %s with icy indifference.",
		"special": {"name": "Cold Embrace", "kind": "drain"}},
	"namenlose": {"name": "The Nameless", "hp": 110, "atk": 31, "def": 11, "tier": 3,
		"gold": 44, "xp": 54, "sprite": "namenlose", "tint": Color(0.68, 0.70, 0.74),
		"attack_line": "%s strikes at %s as if no one were there.",
		"special": {"name": "Erasure", "kind": "drain"}},
	"boss4": {"name": "The Silence", "hp": 860, "atk": 38, "def": 12, "gold": 0, "xp": 400, "tier": 3,
		"sprite": "boss4", "boss": true, "theme": "void", "song": "boss4",
		"tint": Color(0.96, 0.94, 1.0),  # neutral: das dunkle Spinnentier bleibt dunkel, Augen leuchten
		"attack_line": "%s tears the void open beneath %s.",
		"entrance_line": "Every sound dies. A tall gray figure simply stands there — looking straight through you.",
		"intro": [
			["The Silence", "..."],
			["Helen", "Say something! Rage! Hate! ANYTHING!"],
			["The Silence", "Why. The Baron bellowed. The Prince counted. The Divider screamed. Now they are quiet. As everything soon will be."],
			["Helen", "We are here because this valley matters to us. And that is louder than you will ever be."],
		],
		"aoe_name": "Gray Veil", "ultimate_name": "The Great Forgetting",
		"ultimate2_name": "Oblivion"},
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
var debug_mode := false  # schaltet alle Fähigkeiten und Dungeons frei — Standard: aus

func _ready() -> void:
	_load_settings()
	reset_party()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		touch_pad = cfg.get_value("input", "touch_pad", true)
		debug_mode = cfg.get_value("debug", "enabled", false)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")  # bestehende Werte bewahren
	cfg.set_value("input", "touch_pad", touch_pad)
	cfg.set_value("debug", "enabled", debug_mode)
	cfg.save("user://settings.cfg")

func set_touch_pad(value: bool) -> void:
	touch_pad = value
	_save_settings()
	if main != null:
		var t: Variant = main.get("touch")
		if t != null and is_instance_valid(t):
			t.apply_setting()

func set_debug_mode(value: bool) -> void:
	debug_mode = value
	_save_settings()

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
	if debug_mode:
		return true
	if flag == "all_bosses":
		return boss_defeated and boss2_defeated and boss3_defeated
	return get(flag)

func reset_party() -> void:
	inventory = {"Potion": 3, "Ether": 1}
	party = [
		{
			"id": "serena", "name": "Helen", "class": "Swordfighter",
			"level": 1, "xp": 0,
			"hp": 60, "max_hp": 60, "mp": 10, "max_mp": 10,
			"atk": 14, "mag": 4, "def": 6,
			"abilities": [
				{"name": "Blade Whirl", "cost": 4, "target": "all",
					"power": 10, "kind": "phys",
					"desc": "Hits all enemies."},
				{"name": "Storm Cut", "cost": 2, "target": "one",
					"power": 13, "kind": "stormcut",
					"desc": "A swift single strike."},
				{"name": "Focus Pierce", "cost": 3, "target": "one",
					"power": 16, "kind": "pierce", "unlock_bosses": 1,
					"desc": "Pierces through defense."},
				{"name": "Blade Dance", "cost": 8, "target": "one",
					"power": 6, "kind": "dance", "unlock_bosses": 2,
					"desc": "Five lightning cuts in a star, then the falling strike."},
				{"name": "Blade Storm", "cost": 12, "target": "all",
					"power": 20, "kind": "bladestorm", "unlock_bosses": 3,
					"desc": "A tearing hurricane of blades over all foes."},
			],
			"ultimate": {"name": "Starblade",
				"desc": "Blades of light tear all foes apart. (1x per battle)"},
		},
		{
			"id": "milo", "name": "Janosch", "class": "Mage",
			"level": 1, "xp": 0,
			"hp": 42, "max_hp": 42, "mp": 24, "max_mp": 24,
			"atk": 6, "mag": 16, "def": 4,
			"abilities": [
				{"name": "Fireball", "cost": 5, "target": "one",
					"power": 26, "kind": "magic",
					"desc": "A powerful fire spell."},
				{"name": "Healing Light", "cost": 4, "target": "ally",
					"power": 28, "kind": "heal",
					"desc": "Heals one ally."},
				{"name": "Meteor Rain", "cost": 16, "target": "all",
					"power": 32, "kind": "meteor",
					"desc": "Burning meteors rain on all foes."},
			],
			"summons": [
				{"id": "ifrit", "name": "Ifrit", "attack": "Hellfire",
					"cost": 16, "unlock_level": 1, "power": 34,
					"unlock_bosses": 1, "once": true,
					"desc": "Fire demon — Hellfire on all enemies. (1x per battle)"},
				{"id": "leviathan", "name": "Leviathan", "attack": "Deluge",
					"cost": 24, "unlock_level": 1, "power": 38,
					"unlock_bosses": 2, "once": true,
					"desc": "Sea serpent — Deluge on all enemies. (1x per battle)"},
				{"id": "bahamut", "name": "Bahamut", "attack": "Megaflare",
					"cost": 32, "unlock_level": 1, "power": 52,
					"unlock_bosses": 3, "once": true,
					"desc": "Dragon king — Megaflare shatters all enemies. (1x per battle)"},
			],
		},
		{
			"id": "rax", "name": "Wally", "class": "Battle Robot",
			"level": 1, "xp": 0,
			"hp": 72, "max_hp": 72, "mp": 16, "max_mp": 16,
			"atk": 12, "mag": 12, "def": 10,
			"abilities": [
				{"name": "Laser Burst", "cost": 4, "target": "one",
					"power": 22, "kind": "beam",
					"desc": "A focused energy beam."},
				{"name": "Repair", "cost": 4, "target": "ally",
					"power": 30, "kind": "repair",
					"desc": "Nanite repair heals one ally."},
				{"name": "Rocket Salvo", "cost": 7, "target": "all",
					"power": 15, "kind": "rocket", "unlock_bosses": 1,
					"desc": "Rockets on all enemies."},
				{"name": "Nuke", "cost": 14, "target": "all",
					"power": 46, "kind": "nuke", "unlock_bosses": 2, "once": true,
					"desc": "Tactical warhead — devastates the battlefield. (1x per battle)"},
				{"name": "Plasma Lance", "cost": 11, "target": "one",
					"power": 44, "kind": "lance", "unlock_bosses": 3,
					"desc": "A focused plasma lance punches clean through one target."},
			],
			"ultimate": {"name": "Orbital Laser",
				"desc": "A beam from orbit annihilates all foes. (1x per battle)"},
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

## ---------- Gegner-Skalierung ----------
## Am Anfang sind ALLE Dungeon-Gegner gleich stark: die von Haus aus höheren
## Grundwerte der späteren Dungeons werden über ihre Stufe (`tier`) wieder auf
## das Einstiegsniveau normiert. Mit jedem besiegten Dungeon wächst der Wert
## der noch offenen Dungeons — egal, in welcher Reihenfolge man vorgeht.
const _TIER_BASE := [1.0, 1.9, 2.5, 3.4]  # native Stärke je Herkunfts-Dungeon
const _DUNGEON_GROWTH := 0.75  # Zuwachs je bereits erledigtem Dungeon

func enemy_multiplier(tier: int) -> float:
	var growth := 1.0 + _DUNGEON_GROWTH * float(bosses_defeated_count())
	return growth / _TIER_BASE[clampi(tier, 0, 3)]

func skill_unlocked(member: Dictionary, ab: Dictionary) -> bool:
	if debug_mode:
		return true
	if member.get("level", 1) < ab.get("unlock_level", 0):
		return false
	return bosses_defeated_count() >= ab.get("unlock_bosses", 0)

const _BOSS_ORDINAL := ["", "first", "second", "third"]

## Kurzer Hinweis, warum eine Fähigkeit noch gesperrt ist.
func skill_lock_hint(member: Dictionary, ab: Dictionary) -> String:
	var need: int = ab.get("unlock_bosses", 0)
	if bosses_defeated_count() < need:
		return "sealed until the %s boss victory" % _BOSS_ORDINAL[clampi(need, 1, 3)]
	return "from level %d" % ab.get("unlock_level", 0)

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
