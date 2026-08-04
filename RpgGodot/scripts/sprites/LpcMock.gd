class_name LpcMock
extends RefCounted
## Mock-Schalter fuer die LPC-Assets (siehe docs/lpc-umstellung-plan.md).
##
## Nur zum Vorzeigen: mit gesetzter Umgebungsvariable LPCMOCK=1 zeichnet Helen
## als LPC-Figur und der Schlammschleim als LPC-Monster, alles andere bleibt wie
## es ist. Ohne die Variable ruehrt diese Datei das Spiel nicht an — der
## Grafikstil wird erst nach Freigabe umgestellt (Regel in CLAUDE.md).
##
## LPC-Blattaufbau: Zeilen sind Blickrichtungen (0 hoch, 1 links, 2 runter,
## 3 rechts), Spalten die Einzelbilder. Wir nehmen Zeile 1 (links), weil die
## Gegner links stehen — dieselbe Blickrichtung wie beim bisherigen Rig.

const DIR := "res://assets/lpc/"
const CELL := 64          # Heldenraster
const ROW_LEFT := 1

## Blatt, Spaltenzahl und ob die Bildfolge laeuft oder auf dem letzten Bild haelt.
## ACHTUNG: Die LPC-Basisblaetter female_* zeigen den NACKTEN Grundkoerper —
## Kleidung, Haare und Waffen sind bei LPC eigene Ebenen, die uebereinander
## gelegt werden. Fuer den Mock nehmen wir deshalb "princess.png", eine fertig
## angezogene Figur. Sie bringt allerdings nur den Laufzyklus mit, darum leihen
## sich Angriff, Zauber und Treffer hier einzelne Laufbilder. Es geht in diesem
## Stadium um den STIL, nicht um die richtige Bewegung; die vollstaendigen
## angezogenen Saetze liefert erst der Universal-LPC-Generator.
const HERO_SHEETS := {
	"idle":    {"file": "people/princess.png", "cols": 9, "hold": 0},
	"walk":    {"file": "people/princess.png", "cols": 9, "hold": -1},
	"run":     {"file": "people/princess.png", "cols": 9, "hold": -1},
	"attack":  {"file": "people/princess.png", "cols": 9, "hold": 5},
	"attack2": {"file": "people/princess.png", "cols": 9, "hold": 7},
	"cast":    {"file": "people/princess.png", "cols": 9, "hold": 3},
	"aim":     {"file": "people/princess.png", "cols": 9, "hold": 3},
	"block":   {"file": "people/princess.png", "cols": 9, "hold": 0},
	"cheer":   {"file": "people/princess.png", "cols": 9, "hold": 2},
	"hit":     {"file": "people/princess.png", "cols": 9, "hold": 6},
	"down":    {"file": "people/princess.png", "cols": 9, "hold": 4},
}

## Monster: eigene Zellgroessen, weil jedes Blatt anders geschnitten ist.
const MON_SHEETS := {
	"slime":    {"file": "monsters/slime.png", "cols": 3, "w": 32, "h": 32},
	"ghost":    {"file": "monsters/ghost.png", "cols": 3, "w": 40, "h": 46},
	"pumpking": {"file": "monsters/pumpking.png", "cols": 3, "w": 46, "h": 46},
}

static var _cache := {}
static var _sheets := {}
static var _on := -1

## Ist der Mock eingeschaltet? Einmal ermitteln, danach gemerkt.
static func active() -> bool:
	if _on < 0:
		_on = 1 if OS.get_environment("LPCMOCK") != "" else 0
	return _on == 1

static func _sheet(file: String) -> Texture2D:
	if _sheets.has(file):
		return _sheets[file]
	var p := DIR + file
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_sheets[file] = t
	return t

static func _cut(file: String, x: int, y: int, w: int, h: int) -> Texture2D:
	var key := "%s_%d_%d_%d_%d" % [file, x, y, w, h]
	if _cache.has(key):
		return _cache[key]
	var sheet := _sheet(file)
	if sheet == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(x, y, w, h)
	_cache[key] = at
	return at

## Heldin im Kampf. Gibt null zurueck, wenn die Pose nicht abgebildet ist —
## dann faellt der Aufrufer auf das bisherige Rig zurueck.
static func hero(frame: int, anim: String) -> Texture2D:
	var d: Dictionary = HERO_SHEETS.get(anim, {})
	if d.is_empty():
		return null
	var cols: int = d["cols"]
	var hold: int = d["hold"]
	var col: int = frame % cols if hold < 0 else hold
	return _cut(d["file"], col * CELL, ROW_LEFT * CELL, CELL, CELL)

## Monster im Kampf (nur Leerlauf; Angriff/Treffer/Sturz macht weiterhin die
## Verformung in BattleFx, LPC liefert dafuer keine Bilder).
static func monster(name: String, frame: int) -> Texture2D:
	var d: Dictionary = MON_SHEETS.get(name, {})
	if d.is_empty():
		return null
	var w: int = d["w"]
	var h: int = d["h"]
	return _cut(d["file"], (frame % int(d["cols"])) * w, ROW_LEFT * h, w, h)
