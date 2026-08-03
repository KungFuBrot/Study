class_name Figures3D
## Bauplan jeder Spielfigur für das 3D-Rig. Fast alles entsteht aus dem
## parametrierten Humanoiden (`form: "human"`); nur Schleim, Vierbeiner und
## Spinne haben eigene Bauformen.
##
## `class` bestimmt Leinwand und Kameraabstand und muss zu den Größen passen,
## die das Spiel bereits erwartet (Held 32x56, Monster 52x52, Boss 112x128) —
## dadurch bleibt die gesamte Kampf- und Feldaufstellung unverändert.

const HERO := "hero"
const MON := "mon"
const BOSS := "boss"

const F := {
	# --- Party ---------------------------------------------------------------
	"serena": {"class": HERO, "form": "human", "detail": "serena", "h": 1.74, "build": 0.86, "shoulder": 0.92, "arm": 1.02, "leg": 1.08, "torso": 0.94, "head": 0.94,
		"skin": Color(0.93, 0.74, 0.58), "cloth": Color(0.62, 0.13, 0.16),
		"trim": Color(0.85, 0.76, 0.54), "legs": Color(0.31, 0.21, 0.14),
		"boots": Color(0.19, 0.13, 0.09), "hair": Color(0.80, 0.60, 0.20),
		"hair_style": "braid", "prop": "sword"},
	"milo": {"class": HERO, "form": "human", "detail": "milo", "cloak": Color(0.15, 0.21, 0.48), "h": 1.58, "build": 0.80, "shoulder": 0.84, "arm": 1.10, "leg": 0.88, "torso": 1.06, "head": 1.06,
		"skin": Color(0.90, 0.73, 0.58), "cloth": Color(0.19, 0.27, 0.60),
		"trim": Color(0.70, 0.74, 0.92), "legs": Color(0.16, 0.22, 0.48),
		"boots": Color(0.18, 0.15, 0.24), "hair": Color(0.17, 0.24, 0.55),
		"hair_style": "hat", "beard": Color(0.62, 0.62, 0.70), "prop": "staff",
		"gem": Color(0.35, 0.90, 0.45)},
	# Deutlich dunkleres Metall: hell gehalten verschwamm der Roboter im Licht
	# zu einem blassen Fleck ohne erkennbare Form.
	"rax": {"class": HERO, "form": "human", "detail": "rax", "boxhead": true, "h": 1.92, "build": 1.50, "shoulder": 1.34, "arm": 1.12, "leg": 0.92, "torso": 1.04, "head": 0.78, "sink": 0.9,
		"skin": Color(0.34, 0.36, 0.40), "cloth": Color(0.44, 0.46, 0.50),
		"trim": Color(0.22, 0.23, 0.27), "legs": Color(0.20, 0.21, 0.25),
		"boots": Color(0.30, 0.32, 0.36), "hair": Color(0.22, 0.23, 0.27),
		"hair_style": "helm", "eyes": Color(0.40, 0.90, 1.0), "eye_glow": 3.2,
		"prop": "gun"},
	# --- Dorf ----------------------------------------------------------------
	"npc_elder": {"class": HERO, "form": "human", "cloak": Color(0.36, 0.31, 0.23), "h": 1.52, "build": 0.88, "shoulder": 0.86, "arm": 0.94, "leg": 0.82, "torso": 1.10, "head": 1.10, "sink": 0.7,
		"cloth": Color(0.44, 0.38, 0.28), "trim": Color(0.70, 0.64, 0.48),
		"legs": Color(0.34, 0.30, 0.24), "hair": Color(0.86, 0.86, 0.88),
		"hair_style": "short", "beard": Color(0.86, 0.86, 0.88), "prop": "staff",
		"gem": Color(0.72, 0.66, 0.48)},
	"npc_kid": {"class": HERO, "form": "human", "h": 1.14, "build": 0.82, "shoulder": 0.80, "arm": 0.88, "leg": 0.90, "torso": 0.92, "head": 1.32,
		"cloth": Color(0.26, 0.54, 0.34), "trim": Color(0.86, 0.86, 0.60),
		"legs": Color(0.30, 0.28, 0.24), "hair": Color(0.44, 0.28, 0.14),
		"hair_style": "short"},
	"npc_shop": {"class": HERO, "form": "human", "h": 1.62, "build": 1.22, "shoulder": 1.04, "arm": 0.96, "leg": 0.94, "torso": 1.06, "head": 1.0,
		"cloth": Color(0.62, 0.46, 0.20), "trim": Color(0.94, 0.90, 0.72),
		"legs": Color(0.36, 0.28, 0.20), "hair": Color(0.58, 0.22, 0.34),
		"hair_style": "braid"},
	# --- Schlotwerk ----------------------------------------------------------
	"schlammschleim": {"class": MON, "form": "blob", "h": 1.15,
		"cloth": Color(0.36, 0.50, 0.20), "eyes": Color(0.95, 1.0, 0.75)},
	"qualmgeist": {"class": MON, "form": "human", "cloak": Color(0.26, 0.32, 0.25), "h": 1.62, "build": 1.10, "shoulder": 0.92, "arm": 1.30, "leg": 1.0, "torso": 1.16, "head": 0.88,
		"float": true, "cloth": Color(0.34, 0.40, 0.32), "trim": Color(0.26, 0.32, 0.25),
		"skin": Color(0.30, 0.36, 0.29), "hair_style": "hood",
		"eyes": Color(0.72, 1.0, 0.45), "eye_glow": 2.6},
	"muellgnom": {"class": MON, "form": "human", "h": 0.96, "build": 1.30, "shoulder": 1.12, "arm": 1.24, "leg": 0.62, "torso": 1.14, "head": 1.42, "sink": 1.0,
		"skin": Color(0.62, 0.58, 0.42), "cloth": Color(0.52, 0.39, 0.28),
		"trim": Color(0.55, 0.32, 0.18), "legs": Color(0.38, 0.30, 0.22),
		"boots": Color(0.30, 0.22, 0.15), "hair_style": "helm",
		"eyes": Color(1.0, 0.86, 0.40), "eye_glow": 1.2, "prop": "sack",
		"sackcol": Color(0.56, 0.48, 0.32)},
	# --- Konzernturm ---------------------------------------------------------
	"gierschlund": {"class": MON, "form": "blob", "h": 1.20, "maw": true,
		"cloth": Color(0.52, 0.42, 0.20), "eyes": Color(1.0, 0.90, 0.50)},
	"paragraphengeist": {"class": MON, "form": "human", "cloak": Color(0.66, 0.62, 0.50), "h": 1.70, "build": 0.78, "shoulder": 0.82, "arm": 1.34, "leg": 1.0, "torso": 1.22, "head": 0.84, "float": true,
		"cloth": Color(0.78, 0.74, 0.62), "trim": Color(0.62, 0.58, 0.48),
		"skin": Color(0.74, 0.70, 0.60), "hair_style": "hood",
		"eyes": Color(0.95, 0.86, 0.55), "eye_glow": 2.0, "prop": "scroll"},
	"zinshund": {"class": MON, "form": "quad", "h": 1.10,
		"cloth": Color(0.34, 0.26, 0.20), "trim": Color(0.92, 0.74, 0.26),
		"eyes": Color(1.0, 0.72, 0.30)},
	# --- Hassfestung ---------------------------------------------------------
	"hetzer": {"class": MON, "form": "human", "h": 1.66, "build": 0.92, "shoulder": 0.96, "arm": 1.06, "leg": 1.04, "torso": 0.96, "head": 1.02,
		"skin": Color(0.76, 0.56, 0.44), "cloth": Color(0.44, 0.20, 0.18),
		"trim": Color(0.30, 0.16, 0.15), "legs": Color(0.24, 0.20, 0.22),
		"boots": Color(0.18, 0.15, 0.16), "hair": Color(0.20, 0.16, 0.16),
		"hair_style": "short", "prop": "megaphone"},
	"wutgeist": {"class": MON, "form": "human", "h": 1.02, "build": 1.34, "shoulder": 1.22, "arm": 1.30, "leg": 0.66, "torso": 0.92, "head": 1.24, "sink": 1.1,
		"skin": Color(0.62, 0.18, 0.14), "cloth": Color(0.52, 0.15, 0.12),
		"trim": Color(0.36, 0.10, 0.10), "legs": Color(0.36, 0.10, 0.10),
		"boots": Color(0.26, 0.08, 0.07), "hair_style": "none",
		"eyes": Color(1.0, 0.92, 0.40), "eye_glow": 2.8, "prop": "horns"},
	"schlaeger": {"class": MON, "form": "human", "h": 1.96, "build": 1.62, "shoulder": 1.46, "arm": 1.16, "leg": 0.86, "torso": 1.02, "head": 0.74, "sink": 1.2,
		"skin": Color(0.72, 0.54, 0.42), "cloth": Color(0.42, 0.44, 0.49),
		"trim": Color(0.28, 0.29, 0.33), "legs": Color(0.22, 0.23, 0.27),
		"boots": Color(0.16, 0.17, 0.20), "hair": Color(0.22, 0.18, 0.16),
		"hair_style": "short", "prop": "club"},
	"hassprediger": {"class": MON, "form": "human", "cloak": Color(0.30, 0.14, 0.16), "h": 1.78, "build": 0.94, "shoulder": 0.98, "arm": 1.12, "leg": 1.02, "torso": 1.08, "head": 0.92,
		"cloth": Color(0.40, 0.23, 0.25), "trim": Color(0.28, 0.15, 0.17),
		"legs": Color(0.26, 0.15, 0.17), "skin": Color(0.70, 0.52, 0.42),
		"hair_style": "hood", "eyes": Color(1.0, 0.42, 0.28), "eye_glow": 2.4,
		"prop": "banner", "flag": Color(0.62, 0.11, 0.11)},
	# --- Die Leere -----------------------------------------------------------
	"hohlgaenger": {"class": MON, "form": "human", "h": 1.94, "build": 0.66, "shoulder": 0.78, "arm": 1.46, "leg": 1.18, "torso": 1.0, "head": 0.86,
		"skin": Color(0.52, 0.54, 0.58), "cloth": Color(0.44, 0.46, 0.50),
		"trim": Color(0.33, 0.35, 0.40), "legs": Color(0.33, 0.35, 0.40),
		"boots": Color(0.24, 0.26, 0.30), "hair_style": "none",
		"eyes": Color(0.10, 0.11, 0.14)},
	"grauschemen": {"class": MON, "form": "human", "cloak": Color(0.44, 0.48, 0.54), "h": 1.66, "build": 0.84, "shoulder": 0.86, "arm": 1.22, "leg": 1.0, "torso": 1.14, "head": 0.90, "float": true,
		"cloth": Color(0.56, 0.60, 0.66), "trim": Color(0.40, 0.44, 0.50),
		"skin": Color(0.54, 0.58, 0.64), "hair_style": "hood",
		"eyes": Color(0.86, 0.92, 1.0), "eye_glow": 2.2},
	"namenlose": {"class": MON, "form": "human", "h": 1.72, "build": 0.90, "shoulder": 0.94, "arm": 1.0, "leg": 1.0, "torso": 1.04, "head": 0.96,
		"cloth": Color(0.48, 0.48, 0.53), "trim": Color(0.34, 0.34, 0.39),
		"legs": Color(0.34, 0.34, 0.39), "skin": Color(0.78, 0.78, 0.82),
		"boots": Color(0.26, 0.26, 0.31), "hair_style": "none",
		"eyes": Color(0.52, 0.52, 0.58)},
	# --- Bosse ---------------------------------------------------------------
	"boss": {"class": BOSS, "form": "human", "h": 3.10, "build": 2.10, "shoulder": 2.00, "arm": 1.55, "leg": 0.62, "torso": 1.18, "head": 0.62, "sink": 1.6,
		"skin": Color(0.48, 0.56, 0.34), "cloth": Color(0.46, 0.48, 0.40),
		"trim": Color(0.30, 0.32, 0.27), "legs": Color(0.30, 0.32, 0.27),
		"boots": Color(0.22, 0.24, 0.20), "hair_style": "helm",
		"eyes": Color(0.55, 0.95, 0.30), "eye_glow": 3.0, "prop": "stack"},
	"boss2": {"class": BOSS, "form": "human", "cloak": Color(0.22, 0.20, 0.28), "h": 2.55, "build": 2.35, "shoulder": 1.30, "arm": 0.82, "leg": 0.54, "torso": 1.30, "head": 0.70, "sink": 1.3,
		"skin": Color(0.86, 0.68, 0.54), "cloth": Color(0.30, 0.28, 0.36),
		"trim": Color(0.90, 0.74, 0.26), "legs": Color(0.20, 0.19, 0.25),
		"boots": Color(0.14, 0.13, 0.18), "hair": Color(0.16, 0.15, 0.20),
		"hair_style": "hat", "prop": "cane"},
	"boss3": {"class": BOSS, "form": "human", "cloak": Color(0.34, 0.11, 0.12), "h": 3.30, "build": 1.72, "shoulder": 1.86, "arm": 1.62, "leg": 0.78, "torso": 1.10, "head": 0.68, "sink": 1.4,
		"skin": Color(0.60, 0.22, 0.20), "cloth": Color(0.52, 0.18, 0.17),
		"trim": Color(0.30, 0.11, 0.12), "legs": Color(0.28, 0.10, 0.11),
		"boots": Color(0.20, 0.07, 0.08), "hair_style": "none",
		"eyes": Color(1.0, 0.42, 0.14), "eye_glow": 3.2, "prop": "horns"},
	"boss4": {"class": BOSS, "form": "spider", "h": 2.30,
		"cloth": Color(0.60, 0.60, 0.66), "eyes": Color(1.0, 0.20, 0.18),
		"eye_glow": 2.8},
}

## Leinwandgröße je Klasse. Doppelt so groß wie die alten 2D-Leinwände; das
## Spiel zeigt sie dafür auf Maßstab 1 statt 2 an — gleiche Bildschirmgröße,
## vierfache Pixelmenge. Auflösung ist der größte Hebel für Detail, und
## Dead Cells' Figuren sind mit rund 100 px auch deutlich größer als 56.
const CANVAS := {
	HERO: Vector2i(64, 112),
	MON: Vector2i(104, 104),
	BOSS: Vector2i(224, 256),
}

## Bildhöhe der orthografischen Kamera je Klasse (in Metern).
const CAM_SIZE := {HERO: 2.10, MON: 2.00, BOSS: 3.30}

## Welche Animationen je Klasse gebacken werden.
const ANIMS := {
	HERO: ["idle", "walk", "run", "attack", "attack2", "cast", "aim", "block",
		"hit", "down", "cheer"],
	MON: ["idle", "attack", "taunt", "hit", "down"],
	BOSS: ["idle", "attack", "roar", "hit", "down"],
}

## Feldansichten (nur Figuren, die auf der Karte auftauchen).
const FIELD_IDS := ["serena", "milo", "rax", "npc_elder", "npc_kid", "npc_shop"]
const FIELD_VIEWS := {"side": 90.0, "down": 200.0, "up": 20.0}

static func spec(id: String) -> Dictionary:
	return F.get(id, F["serena"])

static func klass(id: String) -> String:
	return String(spec(id)["class"])
