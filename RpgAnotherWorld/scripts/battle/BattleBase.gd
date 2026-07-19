class_name BattleBase
extends Node2D
## Rundenbasierter Kampf im Seitenformat (Helden rechts, Gegner links).
## Moderner Look: Partikel-Effekte, Hit-Stop, Geister-Trails, Kamerabeben,
## HP-Leisten, animierter Höhlenhintergrund mit Fackeln und Nebel sowie
## ein inszenierter Boss-Kampf (Kino-Balken, Wut-Phase, dramatischer Tod).

signal finished(victory: bool)
signal _choice_made

const BAR_W := 170
const WEAPON_REST := -0.35  # Ruhewinkel der Waffe (leicht zum Gegner geneigt)
# Griffposition (Faust) und Ruhewinkel pro Held — Schwert kampfbereit
# geneigt, Stab aufrecht neben dem Körper aufgesetzt.
const WEAPON_GRIP := {
	"serena": {"pos": Vector2(-5, 4), "rest": -0.35, "wscale": 0.85},
	"milo": {"pos": Vector2(-6, 2), "rest": 0.18, "wscale": 0.6},
}

# Kampf-Aufstellung (Zickzack in der Tiefe): Serena vordere Reihe oben,
# Milo hintere Reihe Mitte (weiter rechts + kleiner → Tiefe), Rax vordere
# Reihe unten. pos = Mittelpunkt. Milo weit genug rechts und Rax weit genug
# links, dass Milos Vortreten (_stance, -56 px) niemanden überlappt.
## AW-Rigs backen auf größeren Leinwänden (48x58 statt 16x28) — die Skalen
## sind entsprechend kleiner, die Bildschirmgröße bleibt gleich.
const BATTLE_FORMATION := {
	"serena": {"pos": Vector2(692, 178), "scale": 2.9},
	"milo": {"pos": Vector2(842, 236), "scale": 2.85},
	"rax": {"pos": Vector2(662, 306), "scale": 2.8},
}
# Referenz-Skalen des alten DTII-Stands: Aufsatz-Helfer (Schatten, Glow,
# Partikel) sind auf diese Maßstäbe abgestimmt — px_k = Referenz / aktuell
# vergrößert ihre lokalen Pixelmaße bei den feiner aufgelösten AW-Rigs.
const PXK_HERO_REF := {"serena": 4.9, "milo": 4.8, "rax": 4.6}

var enemy_ids: Array = []
var arena_theme := "toxic"  # "toxic" | "gold" | "hate" — von Main anhand der Karte gesetzt

# Inszenierungs-Farben je Boss-Thema (Banner, Blitze, Wut-Phase, Auren).
const THEME_STYLE := {
	"toxic": {"flash": Color(0.45, 1.0, 0.25, 0.40), "banner": Color(0.60, 1.0, 0.35),
		"banner_outline": Color(0.05, 0.18, 0.03), "bar": Color(0.45, 0.95, 0.25),
		"bar_border": Color(0.20, 0.45, 0.10), "rage": Color(0.6, 1.5, 0.45),
		"aura": Color(0.45, 1.0, 0.15, 0.30), "ember": Color(0.55, 1.0, 0.20, 0.8),
		"burst": Color(0.55, 1.0, 0.30)},
	"gold": {"flash": Color(1.0, 0.85, 0.25, 0.40), "banner": Color(1.0, 0.87, 0.35),
		"banner_outline": Color(0.25, 0.15, 0.02), "bar": Color(1.0, 0.80, 0.20),
		"bar_border": Color(0.50, 0.35, 0.08), "rage": Color(1.6, 1.2, 0.5),
		"aura": Color(1.0, 0.75, 0.15, 0.30), "ember": Color(1.0, 0.85, 0.25, 0.8),
		"burst": Color(1.0, 0.85, 0.35)},
	"hate": {"flash": Color(1.0, 0.15, 0.10, 0.40), "banner": Color(1.0, 0.45, 0.35),
		"banner_outline": Color(0.28, 0.03, 0.03), "bar": Color(0.95, 0.20, 0.15),
		"bar_border": Color(0.55, 0.10, 0.08), "rage": Color(1.7, 0.45, 0.35),
		"aura": Color(1.0, 0.15, 0.05, 0.30), "ember": Color(1.0, 0.25, 0.08, 0.8),
		"burst": Color(1.0, 0.40, 0.30)},
	# Die Leere: kalt, entsättigt, gefühllos — blasses Grau mit einem Hauch Blau.
	"void": {"flash": Color(0.80, 0.84, 0.90, 0.38), "banner": Color(0.82, 0.86, 0.92),
		"banner_outline": Color(0.12, 0.13, 0.16), "bar": Color(0.72, 0.78, 0.86),
		"bar_border": Color(0.32, 0.36, 0.42), "rage": Color(0.85, 0.90, 1.0),
		"aura": Color(0.70, 0.76, 0.85, 0.26), "ember": Color(0.78, 0.83, 0.92, 0.7),
		"burst": Color(0.80, 0.85, 0.92)},
}

## Stil des aktuellen Boss-Themas (Fallback: Arena-Thema).
func _style() -> Dictionary:
	return THEME_STYLE.get(boss_def.get("theme", arena_theme), THEME_STYLE["toxic"])
var boss_def := {}         # ENEMIES-Definition des Bosses in diesem Kampf (falls vorhanden)
var heroes := []   # {data, sprite, home, hp_label, hp_fill, mp_fill}
var enemies := []  # {name, hp, max_hp, atk, def, gold, sprite, home, alive, ...}

var ui_state := "none"  # none | menu | target | item | ally
var menu_index := 0
var choice := -1
var menu_labels: Array = []
var current_menu: Array = []
var menu_dim: Array = []  # Indizes gesperrter (grauer) Menüeinträge

var msg_label: Label
var menu_box: VBoxContainer
var menu_scroll_c: ScrollContainer   # scrollbarer Rahmen um das Auswahlmenü
var menu_rows: Array = []            # aktuelle Zeilen-Labels (für Auto-Scroll)
var party_box: VBoxContainer
var cursor: Polygon2D
var cam: Camera2D
var cam_idle: Tween
var live_lights := 0  # Deckel für kurzlebige Zauberlichter (Web-Performance)
var shock_live := false
var ui_layer: CanvasLayer
var boss_bar_fill: ColorRect
var boss_bar_holder: Control

func _say(text: String) -> void:
	msg_label.text = text

## Beendet die Deckung (verfällt zu Beginn des nächsten eigenen Zuges).
func _end_defend(h: Dictionary) -> void:
	h["defending"] = false
	_end_defend_node(h)

func _end_defend_node(h: Dictionary) -> void:
	if h.get("guard") != null and is_instance_valid(h["guard"]):
		var g: Node = h["guard"]
		var ft := g.create_tween()
		ft.tween_property(g, "modulate:a", 0.0, 0.2)
		ft.tween_callback(g.queue_free)
	h["guard"] = null

## Einmal-pro-Kampf-Fähigkeiten (z. B. Nuke): Nutzung je Held in h["used_once"]
## (Array der Fähigkeitsnamen) vermerken.
func _once_used(h: Dictionary, ab: Dictionary) -> bool:
	return ab["name"] in h.get("used_once", [])

func _mark_once_used(h: Dictionary, ab: Dictionary) -> void:
	if not h.has("used_once"):
		h["used_once"] = []
	if not (ab["name"] in h["used_once"]):
		h["used_once"].append(ab["name"])

func _any_enemy_alive() -> bool:
	for e in enemies:
		if e["alive"]:
			return true
	return false
