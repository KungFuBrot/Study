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
## Heldenraster. LPC zeichnet auf 64x64; die Blaetter liegen doppelt so gross
## im Projekt, weil das Rig seine Figuren ebenfalls doppelt aufloest (Held
## 32x56 x BAKE 2) und der Kampf danach nicht mehr skaliert.
const CELL := 128

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

## Zusaetzlich fuers Feld: die drei Dorfbewohner (nur Stehen und Gehen).
const FIELD_FILES := {
	"serena": "serena", "milo": "milo", "rax": "rax",
	"npc_elder": "npc_elder", "npc_kid": "npc_kid", "npc_shop": "npc_shop",
}

## Feld-Blickrichtungen auf LPC-Zeilen. Das Feld spiegelt die Seitenansicht
## selbst (Field setzt flip_h bei facing.x < 0), also liefern wir die
## Rechts-Zeile; "up" ist der Ruecken, "down" das Gesicht.
const FIELD_ROW := {"side": 3, "up": 0, "down": 2}

## Gegner: fertig gebackene Streifen in enemies/<id>.png, ein Bild neben dem
## anderen. Die Zellbreite ergibt sich aus Breite/Bilderzahl, die Hoehe ist die
## Bildhoehe — deshalb genuegt hier die Bilderzahl. Wer nur ein Bild hat, kommt
## aus dem Kampfblatt (unbewegte Seitenansicht); die Bewegung macht dort wie
## gehabt die Verformung in BattleFx.
const ENEMY_FRAMES := {
	"schlammschleim": 3, "qualmgeist": 3, "muellgnom": 3, "gierschlund": 3,
	"paragraphengeist": 1, "zinshund": 1, "hetzer": 4, "wutgeist": 3,
	"schlaeger": 1, "hassprediger": 1, "hohlgaenger": 1, "grauschemen": 3,
	"namenlose": 1,
	"boss": 8, "boss2": 4, "boss3": 5, "boss4": 4,
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

## Gegner im Kampf (nur Leerlauf; Angriff, Treffer und Zusammenbruch macht
## weiterhin die Verformung in BattleFx — dafuer liefern die Pakete keine
## Bilder). null, wenn der Gegner nicht umgestellt ist.
static func monster(id: String, frame: int) -> Texture2D:
	if not ENEMY_FRAMES.has(id):
		return null
	var file := "enemies/%s.png" % id
	var sheet := _sheet(file)
	if sheet == null:
		return null
	var n: int = maxi(int(ENEMY_FRAMES[id]), 1)
	var w: int = int(sheet.get_width() / n)
	var h: int = sheet.get_height()
	return _cut(file, (frame % n) * w, 0, w, h)

## Bilderzahl des Streifens (0, wenn der Gegner nicht umgestellt ist).
static func monster_frames(id: String) -> int:
	return int(ENEMY_FRAMES.get(id, 0))

## Figur auf der Karte. dir: "side" | "up" | "down".
static func field(id: String, walking: bool, frame: int, dir: String) -> Texture2D:
	var f: String = FIELD_FILES.get(id, "")
	if f == "":
		return null
	var sheet := "walk" if walking else "idle"
	var cols := 9 if walking else 2
	var row: int = int(FIELD_ROW.get(dir, 3))
	return _cut("heroes/%s_%s.png" % [f, sheet], (frame % cols) * CELL, row * CELL, CELL, CELL)
