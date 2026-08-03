# RpgGodot — Mini-JRPG (Godot 4)

Rundenbasiertes Mini-JRPG im Stil von FF VI / Octopath. Läuft als Web-Export auf
GitHub Pages. Alles ist prozedural per Code erzeugt — es gibt nur eine Szene
(`Main.tscn`), keine Editor-Ressourcen.

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

`SpriteFactoryLib` (Asset-Loader, Kacheln, Gelände-Übergänge, Pixel-Helfer) →
`SpriteFactoryChars` (Figuren-Einstiege) → `SpriteFactory` (Beschwörungen,
Gegner, Props). Alle Aufrufe von außen laufen über `SpriteFactory.*`
(statische Vererbung).

**`scripts/sprites/RigFactory.gd` steht daneben, nicht in der Kette.** Dort
werden ALLE Kampffiguren gezeichnet — Helden, 13 Monster, 4 Bosse, Dorf-NPCs:
Körperteil-Karte → Schattierung je Glied über dessen eigene Ausdehnung →
farbige Kontur. Eine Lichtrichtung (oben links), eine Tonwertleiter, ein
Maßstab (`BATTLE_SCALE = 2.0`); die Größe steckt in der Leinwand
(Held 32x56, Monster 52x52, Boss 112x128), nicht in der Vergrößerung — nur so
ist ein Pixel bei allen Figuren gleich groß. `SpriteFactoryChars.field_char` /
`hero_battle_frame` und `SpriteFactory.enemy_frame` reichen nur noch dorthin
durch. DTII liefert seither ausschließlich Kacheln und Requisiten.

Offen im Rig: Lauf-/Angriffs-/Trefferposen im Kampf (es gibt nur Atmen) und
Blickrichtungen im Feld (nur Seitenansicht).

### Gelände-Übergänge (`SpriteFactoryLib.edge_overlay`)

Karten werden nicht mehr aus Vollkacheln gestapelt: `TERRAIN_RANK` legt fest,
welches Gelände in die Kachel des niedrigeren hineingreift (Fels > Weg > Gras >
Wasser). Die Kante bleibt pixelscharf, mäandert aber über tieffrequentes
Rauschen; am Saum liegt Kontaktschatten bzw. Ufersaum. Bäume, Häuser, Wände und
Portalsymbole sind Objekte AUF dem Gelände (`Field.OBJECT_CHARS`), damit der
Untergrund durchläuft.

## Befehle

Godot-Binary: `C:\Users\Kungf\AppData\Local\Temp\godot_47\Godot_v4.7-stable_win64_console.exe`

```powershell
# Skript-/Klassencheck (nach Umbauten immer ausführen):
godot --headless --editor --quit --path .   # Klassen-Cache neu aufbauen
godot --headless --quit --path .            # Spielstart kompiliert alle Skripte

# Runtime-Smoke-Test: spielt alle Kampf-Fähigkeiten automatisch durch
# (headless schlagen nur die save_png-Screenshots fehl — das ist ok):
$env:SPELLSHOT = "$env:TEMP\shots"; godot --headless --path .

# Web-Export (Ziel ../web_build, wird von GitHub Pages ausgeliefert):
godot --headless --path . --export-release "Web"
```

## Sitzungsende-Workflow

1. Headless-Check (siehe oben) — muss fehlerfrei sein.
2. Web-Build exportieren.
3. Committen (deutsche Commit-Messages, Muster: `Fix:`/`Feature:`/`Web-Build: … exportiert`) und pushen.

## Nicht lesen / nicht anfassen

- `../web_build/*` (generierte Binaries — nur per Export erzeugen, nie editieren)
- `.godot/` (Cache), `assets/dtii`, `assets/kenney` (CC0-Packs, fertig)
