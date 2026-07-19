# RpgAnotherWorld — Mini-JRPG im Another-World-Stil (Godot 4)

Parallel-Projekt zu `../RpgGodot` (identische Spiellogik): Die Grafik wird
schrittweise auf den Flächenstil von **Another World** (Eric Chahi) umgebaut —
flache Polygone, harte Schattenbänder, Silhouetten, keine Outlines. Das
Original-Projekt bleibt unangetastet. Web-Export nach `../web_build_aw/`.

## AW-Rig-System (Kern des Stil-Umbaus)

Figuren sind **Skelett-Rigs** (Bones mit Forward-Kinematik, Keyframe-Posen,
zu ImageTexture-Frames gebacken) — Teile können nicht "schweben", Gelenke
schließen überlappende Scheiben. Kette (nur Aufrufe nach OBEN):
`SpriteFactoryLib > AwRigEngine > AwRigsMonsters > AwRigs > SpriteFactoryChars
> SpriteFactory`. Farben ~2x heller anlegen als "richtig" wirkend (Ambiente/
Vignette/Grade dimmen kräftig).

**Nach jeder Rig-Änderung Pflicht:** Montage + Zusammenhangs-Validator
(`godot --headless --path . -s tools/check_aw_rigs.gd`) — muss
`bad=0` melden; PNGs in `../_assets_tmp/check/aw/` sichten.

Umbau-Stand (Milestone 0): Kampf im Schlotwerk komplett AW (3 Helden mit
Idle/Run/Attack-Zyklen, 3 Monster, Schlotbaron, `_build_backdrop_aw` in
BattleStage, AW-Skalen via `px_k`-Meta). Feld, übrige Arenen, Titel: noch alt.

## Konventionen

- **Spielertexte: Englisch.** Code-Kommentare: Deutsch. Beides beibehalten.
- Typisiertes GDScript (`:=`, `->`), Tabs, LF-Zeilenenden.
- Keine neuen Assets/Szenen anlegen — Grafik entsteht in `SpriteFactory`,
  Musik/SFX in `AudioManager`, UI per Code.
- ACHTUNG Grafikstil: Stil-Umbauten nur nach In-Game-Mock und Freigabe
  (mehrere Anläufe wurden abgelehnt, siehe `docs/ki-grafikstil-plan.md`).

## Dateikarte — gezielt lesen statt alles laden

| Datei | Inhalt |
|---|---|
| `scripts/Main.gd` | Root: Szenenwechsel Feld/Kampf/Intro/Ende, Input-Map, Fades |
| `scripts/GameState.gd` | **Daten:** Party, Fähigkeiten, Items, ENEMIES (inkl. Boss-Dialoge), XP/Level |
| `scripts/MapData.gd` | **Daten:** Karten (ASCII), Portale, NPC-Dialoge |
| `scripts/Field.gd` | Erkundung: Karte, Bewegung, NPC/Shop, Zufallskämpfe |
| `scripts/Intro.gd` / `Ending.gd` | Story-Texte Anfang/Abspann |
| `scripts/Title.gd` | Titelbild, Menü, Einstellungen |
| `scripts/AudioManager.gd` | Prozeduraler Chiptune-Synth + Junkala-Tracks |
| `scripts/Fx.gd` | Shader: Tilt-Shift, Wasser, Dissolve, Stoßwelle |
| `scripts/TouchControls.gd` | Bildschirm-Pad für Mobile |

### Battle-Vererbungskette (`scripts/battle/` + `scripts/Battle.gd`)

Der Kampf ist eine lineare Kette — **eine Klasse darf nur Methoden von sich
selbst oder ihren Vorfahren (weiter oben) aufrufen**, nie nach unten:

| # | Klasse | Inhalt |
|---|---|---|
| 1 | `BattleBase` | Zustand, Konstanten, `_say`, Kleinst-Helfer |
| 2 | `BattleFx` | Generische Effekte: Partikel, Beben, Hit-Stop, Kamera, `_sprint`, Banner |
| 3 | `BattleStage` | Arena-Aufbau, Ambiente, Idle-Animationen |
| 4 | `BattleUi` | Party-/Bossleiste, Menüs, Zielwahl, Input |
| 5 | `BattleBossCine` | Boss-Auftritt, Wut-Phase, Boss-Tod |
| 6 | `BattleDamage` | `_damage_hero` / `_damage_enemy` |
| 7 | `BattleHeroActions` | Helen- & Janosch-Skills |
| 8 | `BattleRaxActions` | Wally: MG, Laser, Raketen, Nuke, Orbital |
| 9 | `BattleSummons` | Ifrit, Leviathan, Bahamut |
| 10 | `BattleEnemyActions` | Gegnerzüge, Boss-AoE/-Ultimates |
| 11 | `Battle` | `_ready`, Rundenschleife, Fähigkeiten-Menü, Sieg/Niederlage, Showcases |

Neue geteilte Helfer gehören nach `BattleFx` (visuell) bzw. `BattleBase` (Zustand).

### SpriteFactory-Kette (`scripts/sprites/` + `scripts/SpriteFactory.gd`)

`SpriteFactoryLib` (Asset-Loader, Kacheln, Pixel-Helfer) → `SpriteFactoryChars`
(Helden/Roboter) → `SpriteFactory` (Beschwörungen, Gegner, Props). Alle Aufrufe
von außen laufen über `SpriteFactory.*` (statische Vererbung).

## Befehle

Godot-Binary: `C:\Users\Kungf\AppData\Local\Temp\godot_47\Godot_v4.7-stable_win64_console.exe`

```powershell
# Skript-/Klassencheck (nach Umbauten immer ausführen):
godot --headless --editor --quit --path .   # Klassen-Cache neu aufbauen
godot --headless --quit --path .            # Spielstart kompiliert alle Skripte

# Runtime-Smoke-Test: spielt alle Kampf-Fähigkeiten automatisch durch
# (headless schlagen nur die save_png-Screenshots fehl — das ist ok):
$env:SPELLSHOT = "$env:TEMP\shots"; godot --headless --path .

# Web-Export (Ziel ../web_build_aw, wird von GitHub Pages ausgeliefert):
godot --headless --path . --export-release "Web"
```

## Sitzungsende-Workflow

1. Headless-Check (siehe oben) — muss fehlerfrei sein.
2. Web-Build exportieren.
3. Committen (deutsche Commit-Messages, Muster: `Fix:`/`Feature:`/`Web-Build: … exportiert`) und pushen.

## Nicht lesen / nicht anfassen

- `../web_build_aw/*` (generierte Binaries — nur per Export erzeugen, nie editieren)
- `.godot/` (Cache), `assets/dtii`, `assets/kenney` (CC0-Packs, fertig)
