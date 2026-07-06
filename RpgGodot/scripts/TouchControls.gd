class_name TouchControls
extends CanvasLayer
## Bildschirm-Steuerung für Geräte ohne Tastatur (v. a. die Web-Version auf
## Handy/Tablet). Speist die vorhandenen Input-Actions (move_*, confirm, cancel)
## per InputEventAction ein, sodass Field/Battle/Ending unverändert reagieren —
## sowohl das Polling (`Input.is_action_pressed`) als auch die Event-Callbacks
## (`_unhandled_input`) werden bedient.

const BTN := 82        # Kantenlänge eines Knopfes
const GAP := 8         # Abstand zwischen Knöpfen
const MARGIN := 28     # Abstand zum Bildschirmrand
const VW := 960        # Viewport-Breite (project.godot)
const VH := 540        # Viewport-Höhe

var _root: Control
var _held := {}        # action -> bool, verhindert doppelte Press/Release

func _ready() -> void:
	# Über dem Spiel, aber unter der Fade-/Übergangs-Ebene (layer 100).
	layer = 90
	# Nur dort einblenden, wo es keine (verlässliche) Tastatur gibt.
	# FORCE_TOUCH=1 erzwingt die Anzeige auch am Desktop (zum Testen/Screenshots).
	var forced := OS.get_environment("FORCE_TOUCH") != ""
	if not (forced or DisplayServer.is_touchscreen_available() or OS.has_feature("web")):
		queue_free()
		return
	# Auch während Pausen/Übergängen bedienbar bleiben.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- D-Pad unten links (Kreuz-Anordnung) ---
	var lx := MARGIN                         # linke Spalte
	var mx := MARGIN + BTN + GAP             # mittlere Spalte
	var rx := MARGIN + 2 * (BTN + GAP)       # rechte Spalte
	var by := VH - MARGIN - BTN              # untere Reihe
	var my := by - (BTN + GAP)               # mittlere Reihe
	var ty := by - 2 * (BTN + GAP)           # obere Reihe
	_make(mx, ty, "▲", "move_up")
	_make(lx, my, "◀", "move_left")
	_make(rx, my, "▶", "move_right")
	_make(mx, by, "▼", "move_down")

	# --- Aktionsknöpfe unten rechts ---
	var ax := VW - MARGIN - BTN              # rechte Spalte der Aktionsknöpfe
	var bx := ax - BTN - GAP                 # Spalte links davon
	_make(ax, by, "A", "confirm", Color(0.30, 0.70, 0.45))   # Bestätigen
	_make(bx, my, "B", "cancel", Color(0.80, 0.35, 0.35))    # Abbrechen/Zurück

func _make(x: int, y: int, label: String, action: String, tint := Color(0.55, 0.60, 0.75)) -> void:
	var b := Button.new()
	b.text = label
	b.position = Vector2(x, y)
	b.custom_minimum_size = Vector2(BTN, BTN)
	b.size = Vector2(BTN, BTN)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint.r, tint.g, tint.b, 0.34)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(2)
	normal.border_color = Color(1, 1, 1, 0.4)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.r, tint.g, tint.b, 0.85)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.92))

	b.button_down.connect(_press.bind(action))
	b.button_up.connect(_release.bind(action))
	_root.add_child(b)

## Action als gedrückt melden — erreicht Polling UND _unhandled_input.
func _press(action: String) -> void:
	if _held.get(action, false):
		return
	_held[action] = true
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)

func _release(action: String) -> void:
	if not _held.get(action, false):
		return
	_held[action] = false
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
