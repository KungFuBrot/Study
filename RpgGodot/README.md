# Fable RPG (Godot)

Ein Mini-JRPG im Stil von *Final Fantasy VI / Octopath Traveler*, gebaut mit **Godot 4.3+**.
Alles ist prozedural: Pixel-Art, Karten, Musik und Soundeffekte werden zur Laufzeit
per GDScript erzeugt — das Projekt braucht **keine einzigen Binär-Assets**.

## Starten

1. [Godot 4.3+](https://godotengine.org/download) installieren (Standard-Version, kein .NET nötig).
2. In Godot: **Importieren** → Ordner `RpgGodot/` bzw. die `project.godot` auswählen.
3. **F5** drücken (Hauptszene `scenes/Main.tscn` ist bereits eingestellt).

> Hinweis: Beim ersten Betreten eines Bereichs wird dessen Musik einmalig
> gerendert — ein kurzer Moment Rechenzeit ist normal.

## Steuerung

| Taste | Aktion |
|---|---|
| Pfeiltasten / WASD | Bewegen bzw. Menü-Auswahl |
| Z / Enter / Leertaste | Bestätigen, Ansprechen, Kaufen |
| X / Escape | Abbrechen, Shop verlassen |

## Inhalt

- **Stadt Lindenhain** — sicher, keine Kämpfe. Zwei ansprechbare NPCs
  (Ältester Theobald, Pia) und **Händlerin Greta** mit Shop (Trank, Äther).
- **Weltkarte** — verbindet Stadt (Westen) und Höhle (Osten), Fluss mit Brücke.
- **Finsterhöhle (Dungeon)** — mit **Zufallskämpfen** (Schleim, Höhlenfledermaus, Skelett).
- **Zwei Helden**:
  - **Serena** (Schwertkämpferin) — Spezial: *Klingenwirbel* (trifft alle Gegner, 4 MP)
  - **Milo** (Zauberer) — Spezial: *Feuerball* (starker Einzelziel-Zauber, 5 MP)
- **Rundenbasierte Kämpfe** mit Kommandos: Angriff, Spezialfähigkeit, Item, Fliehen.
- **Animationen**: Idle-Wippen, Ausfallschritte, Schwerthieb-Effekt, Feuerball-Projektil
  mit Explosion, Treffer-Shake + Kamera-Wackeln, schwebende Schadenszahlen,
  Sterbe- und Sieg-Animationen, Kampf-Blitz-Übergang.
- **Musik & SFX**: prozeduraler Chiptune-Synth — eigene Themes für Stadt, Weltkarte,
  Dungeon, Kampf, Sieg und Niederlage; Sounds für Schritte, Menü, Kauf, Hieb,
  Feuer, Explosion, Heilung u. v. m.

## Architektur (erweiterbar)

| Datei | Zweck |
|---|---|
| `scripts/Main.gd` | Szenenwechsel Feld ↔ Kampf, Überblendungen, Input-Setup |
| `scripts/GameState.gd` (Autoload) | Party, Gold, Inventar, Item-/Gegner-Daten |
| `scripts/AudioManager.gd` (Autoload) | Chiptune-Synth für Musik & SFX |
| `scripts/MapData.gd` | ASCII-Karten inkl. Portale, NPCs, Spawns |
| `scripts/Field.gd` | Erkundung: Bewegung, Dialoge, Shop, Zufallskämpfe |
| `scripts/Battle.gd` | Rundenkampf inkl. aller Effekte |
| `scripts/SpriteFactory.gd` | Prozedurale Pixel-Art (Tiles, Helden, Gegner) |

**Bewusst offen gelassen für später** (wie gewünscht): Story/Ziel, Level-/EP-System
(einfach in `GameState.party` + `_victory()` einhängen), weitere Karten (nur ein
Eintrag in `MapData.MAPS`), weitere Gegner/Items (Einträge in `GameState`).
