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
## Helden-Blaetter, aus den Generator-Ebenen zusammengesetzt und umgefaerbt
## (Werkzeug siehe docs/lpc-umstellung-plan.md): Koerper, Beine, Oberteil, KOPF
## (eigene Ebene!) und Haare. Dateien liegen als heroes/<id>_<anim>.png.
##
## "cols" = Spalten des Blattes, "row" = Zeile im LPC-Raster
## (0 hoch, 1 links, 2 runter, 3 rechts). WICHTIG: Die Kampfszene spiegelt jede
## Heldenfigur (`s.flip_h = true` in BattleStage, Erbe der DTII-Zeit). Wir
## nehmen deshalb die RECHTS-Zeile — gespiegelt blickt sie nach links, also zu
## den Gegnern. Mit Zeile 1 schauten alle vom Feind weg.
## "hurt" hat nur EINE Zeile, deshalb row 0. "hold" haelt ein festes Bild,
## -1 laesst die Folge laufen.
const ROW := 3
const HERO_ANIM := {
	"idle":    {"sheet": "idle", "cols": 2, "row": ROW, "hold": -1},
	"walk":    {"sheet": "walk", "cols": 9, "row": ROW, "hold": -1},
	"run":     {"sheet": "run", "cols": 8, "row": ROW, "hold": -1},
	"attack":  {"sheet": "slash", "cols": 6, "row": ROW, "hold": -1},
	"attack2": {"sheet": "thrust", "cols": 8, "row": ROW, "hold": -1},
	"cast":    {"sheet": "spellcast", "cols": 7, "row": ROW, "hold": -1},
	"aim":     {"sheet": "spellcast", "cols": 7, "row": ROW, "hold": 4},
	"block":   {"sheet": "combat_idle", "cols": 2, "row": ROW, "hold": -1},
	"cheer":   {"sheet": "spellcast", "cols": 7, "row": ROW, "hold": 2},
	"hit":     {"sheet": "hurt", "cols": 6, "row": 0, "hold": -1},
	"down":    {"sheet": "hurt", "cols": 6, "row": 0, "hold": 5},
}

## Welche unserer Helden ein LPC-Blatt haben. Wally hat im LPC keine Entsprechung
## (es gibt dort keinen Roboter) — er ist aus Plattenpanzer, Schulterstuecken und
## geschlossenem Helm gebaut, alles auf kaltes Metall umgefaerbt, auch die Haut.
const HERO_FILES := {"serena": "serena", "milo": "milo", "rax": "rax"}

## Monster: eigene Zellgroessen, weil jedes Blatt anders geschnitten ist.
const MON_SHEETS := {
	"slime":    {"file": "monsters/slime.png", "cols": 3, "w": 32, "h": 32},
	"ghost":    {"file": "monsters/ghost.png", "cols": 3, "w": 40, "h": 46},
	"pumpking": {"file": "monsters/pumpking.png", "cols": 3, "w": 46, "h": 46},
}

static var _cache := {}
static var _sheets := {}
static var _env := -1

## Ist die Vorschau eingeschaltet? Entweder per Umgebungsvariable (Screenshot-
## Laeufe am Rechner) oder ueber den Menuepunkt — Letzteres ist der einzige Weg
## im Web-Export, wo es keine Umgebungsvariablen gibt. Der Menue-Schalter wird
## bei JEDEM Aufruf gelesen, damit er sofort wirkt; nur die Umgebungsvariable
## wird gemerkt.
static func active() -> bool:
	if _env < 0:
		_env = 1 if OS.get_environment("LPCMOCK") != "" else 0
	return _env == 1 or GameState.lpc_preview

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

## Held*in im Kampf. Gibt null zurueck, wenn Figur oder Pose (noch) nicht
## abgebildet sind — dann faellt der Aufrufer auf das bisherige Rig zurueck.
static func hero(id: String, frame: int, anim: String) -> Texture2D:
	var f: String = HERO_FILES.get(id, "")
	if f == "":
		return null
	var d: Dictionary = HERO_ANIM.get(anim, {})
	if d.is_empty():
		return null
	var cols: int = d["cols"]
	var hold: int = d["hold"]
	var col: int = frame % cols if hold < 0 else mini(hold, cols - 1)
	return _cut("heroes/%s_%s.png" % [f, d["sheet"]], col * CELL, int(d["row"]) * CELL, CELL, CELL)

## Monster im Kampf (nur Leerlauf; Angriff/Treffer/Sturz macht weiterhin die
## Verformung in BattleFx, LPC liefert dafuer keine Bilder).
static func monster(name: String, frame: int) -> Texture2D:
	var d: Dictionary = MON_SHEETS.get(name, {})
	if d.is_empty():
		return null
	var w: int = d["w"]
	var h: int = d["h"]
	return _cut(d["file"], (frame % int(d["cols"])) * w, ROW_LEFT * h, w, h)
