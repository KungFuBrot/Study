# Fable RPG (Godot)

Ein Mini-JRPG im Stil von *Final Fantasy VI / Octopath Traveler*, gebaut mit **Godot 4.3+**.
Alles ist prozedural: Pixel-Art, Karten, Musik und Soundeffekte werden zur Laufzeit
per GDScript erzeugt — das Projekt braucht **keine einzigen Binär-Assets**.

## Ausführen

### 1. Godot installieren (einmalig)

Benötigt wird **Godot 4.3 oder neuer** (Standard-Version, kein .NET nötig). Am einfachsten unter Windows per winget:

```powershell
winget install GodotEngine.GodotEngine
```

Danach ein **neues** Terminal öffnen, damit der Befehl `godot` verfügbar ist.
(Alternativ von [godotengine.org/download](https://godotengine.org/download) laden — Godot ist eine portable EXE ohne Installer.)

### 2. Spiel starten

**Direkt per Kommandozeile** (im Ordner oberhalb von `RpgGodot/`):

```powershell
godot --path RpgGodot
```

**Oder über den Editor:**

1. Godot starten → **Importieren** → die Datei `RpgGodot/project.godot` auswählen.
2. **F5** drücken (Hauptszene `scenes/Main.tscn` ist bereits eingestellt).

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
- **Bosskampf**: Tief in der Höhle thront der **Knochenkönig** — ansprechen (Z) startet
  den Kampf. Eigenes Boss-Theme, dramatischer Auftritt mit Banner und Kamerabeben,
  alle drei Runden beschwört er den **Knochensturm** (trifft die ganze Gruppe).
  Einmal besiegt, bleibt er besiegt.
- **Zwei Helden mit je zwei Fähigkeiten**:
  - **Serena** (Schwertkämpferin) — *Klingenwirbel* (trifft alle Gegner, 4 MP),
    *Fokusstoß* (drei schnelle Hiebe, ignoriert Verteidigung, 3 MP)
  - **Milo** (Zauberer) — *Feuerball* (starker Einzelziel-Zauber, 5 MP),
    *Heillicht* (heilt einen Verbündeten, 4 MP)
- **Rundenbasierte Kämpfe** mit Kommandos: Angriff, Fähigkeit (Untermenü), Item, Fliehen.
- **Animationen**: Einmarsch der Kämpfer, Idle-Wippen, Ausfallschritte, Schwerthieb-Effekt
  mit Funkenflug, Feuerball-Projektil mit Explosion, Heil-Lichtring, Aufladen der Gegner
  vor dem Angriff, Treffer-Shake + Kamera-Wackeln, Vollbild-Blitze, pulsierender
  Zielcursor, schwebende Schadenszahlen, Sterbe- und Sieg-Animationen mit Münzregen,
  Kampf-Blitz-Übergang.
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
