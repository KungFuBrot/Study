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

var _root: Control     # enthält D-Pad + Aktionsknöpfe (per Button ein-/ausblendbar)
var _toggle: Button     # bleibt immer sichtbar, schaltet die Pads um
var _pads_visible := true
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
	# Richtungsknöpfe tragen ein gezeichnetes Dreieck (arrow != ZERO) statt eines
	# Schrift-Glyphs — Unicode-Pfeile fehlen in der Standardschrift des Web-Exports.
	_make(mx, ty, "", "move_up", Color(0.55, 0.60, 0.75), Vector2(0, -1))
	_make(lx, my, "", "move_left", Color(0.55, 0.60, 0.75), Vector2(-1, 0))
	_make(rx, my, "", "move_right", Color(0.55, 0.60, 0.75), Vector2(1, 0))
	_make(mx, by, "", "move_down", Color(0.55, 0.60, 0.75), Vector2(0, 1))

	# --- Aktionsknöpfe unten rechts ---
	var ax := VW - MARGIN - BTN              # rechte Spalte der Aktionsknöpfe
	var bx := ax - BTN - GAP                 # Spalte links davon
	_make(ax, by, "A", "confirm", Color(0.30, 0.70, 0.45))   # Bestätigen
	_make(bx, my, "B", "cancel", Color(0.80, 0.35, 0.35))    # Abbrechen/Zurück

	_build_toggle()

## Kleiner Schalter oben rechts (bleibt immer sichtbar), der D-Pad und
## Aktionsknöpfe ein-/ausblendet — z. B. um die Sicht freizugeben.
func _build_toggle() -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 42)
	b.size = Vector2(124, 42)
	b.position = Vector2(VW - MARGIN - 124, MARGIN)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.20, 0.28, 0.5)
	st.set_corner_radius_all(12)
	st.set_border_width_all(2)
	st.border_color = Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	b.text = "Pad aus"
	b.pressed.connect(_toggle_pads)
	add_child(b)
	_toggle = b

func _toggle_pads() -> void:
	_pads_visible = not _pads_visible
	_root.visible = _pads_visible
	_toggle.text = "Pad aus" if _pads_visible else "Pad ein"

func _make(x: int, y: int, label: String, action: String, tint := Color(0.55, 0.60, 0.75), arrow := Vector2.ZERO) -> void:
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

	if arrow != Vector2.ZERO:
		_add_arrow(b, arrow)

## Zeichnet ein Pfeil-Dreieck mittig in einen Knopf (statt eines Schrift-Glyphs,
## das im Web-Export mangels Font fehlt). `dir` zeigt in die Laufrichtung.
func _add_arrow(button: Button, dir: Vector2) -> void:
	var tri := Polygon2D.new()
	# Nach oben zeigendes Basis-Dreieck, um die Knopfmitte zentriert.
	tri.polygon = PackedVector2Array([
		Vector2(0, -17), Vector2(-15, 12), Vector2(15, 12),
	])
	tri.color = Color(1, 1, 1, 0.92)
	tri.position = Vector2(BTN, BTN) * 0.5
	tri.rotation = dir.angle() + PI / 2.0   # Basis zeigt hoch → in dir drehen
	button.add_child(tri)

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
