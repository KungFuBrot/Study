# RPG Fable — Mini-JRPG im Stil von Octopath Traveler / Final Fantasy VI

Ein kleines, vollständig prozedural erzeugtes 2D-Rollenspiel für Unity (C#).
Alle Grafiken, Daten und Szenen werden per Editor-Skript generiert — es werden
keinerlei externe Assets benötigt.

## Spielinhalt

- **Stadt Eichenhain**: 2 ansprechbare NPCs (der Älteste gibt Hinweise, die
  Priesterin heilt die Gruppe) und ein Shop (Heiltrank, Zaubertrank).
  Keine Zufallskämpfe.
- **Weltkarte**: verbindet Stadt (Süden) und Kristallhöhle (Nordosten).
- **Dungeon (Kristallhöhle)**: Zufallskämpfe beim Umherlaufen
  (Schleim, Fledermaus, Golem).
- **Rundenbasierte Kämpfe**: Reihenfolge nach Tempo; Befehle Angriff,
  Fähigkeit, Gegenstand, Fliehen. Sieg bringt Gold.
- **Zwei Helden**:
  - **Aria** (Schwertkämpferin): *Wirbelklinge* (trifft alle Gegner),
    *Schildbrecher* (starker Einzelschlag)
  - **Milo** (Zauberer): *Feuerball* (Magieschaden),
    *Heilendes Licht* (heilt einen Verbündeten)

## Einrichtung

1. Neues Unity-Projekt anlegen (Vorlage **2D**, Unity 2021.3 LTS oder neuer;
   getestet gegen die klassische Input- und UI-Pipeline).
2. Den Ordner `Assets/Scripts` dieses Projekts in den `Assets`-Ordner des
   Unity-Projekts kopieren (oder dieses Verzeichnis direkt als Projekt öffnen).
3. Warten, bis Unity kompiliert hat, dann im Menü ausführen:
   **RPG Fable → Alles erzeugen (Grafiken, Daten, Szenen)**
4. Die Szene `Stadt` ist danach geöffnet — einfach **Play** drücken.

Der Menübefehl erzeugt:
- `Assets/RpgFable/Sprites` — alle Grafiken als PNG (prozedural gerastert)
- `Assets/RpgFable/Daten` — Helden, Gegner, Fähigkeiten, Gegenstände,
  Begegnungstabelle als ScriptableObjects
- `Assets/RpgFable/Szenen` — `Stadt`, `Weltkarte`, `Dungeon`, `Kampf`
  (automatisch in den Build Settings registriert)

## Steuerung

| Taste | Wirkung |
|---|---|
| Pfeiltasten / WASD | Bewegen bzw. Auswahl im Menü |
| E / Enter / Leertaste | Sprechen, bestätigen, kaufen |
| Esc / Rücktaste | Abbrechen, Shop verlassen |

## Projektstruktur

```
Assets/Scripts/
  Core/         GameBootstrap, GameState (Gruppe, Gold, Inventar)
  Data/         ScriptableObject-Definitionen (Held, Gegner, Fähigkeit, ...)
  Exploration/  Spielfigur, Kamera, NPCs, Shop, Portale, Zufallskämpfe
  Battle/       Rundenbasierter Kampf (BattleManager, BattleUnit)
  UI/           Feld-UI (Hinweis, Dialog, Shop)
  Editor/       MapLayouts (ASCII-Karten), SpriteFactory (Grafikerzeugung),
                GameBuilder (Daten- und Szenenerzeugung)
```

## Erweiterungspunkte

Das Spiel ist bewusst ohne Ziel, Geschichte und Levelsystem gehalten, aber
darauf vorbereitet:

- **Levelsystem**: `HeroRuntime` (in `GameState.cs`) um Erfahrung/Level
  ergänzen; `HeroDefinition` kann Wachstumskurven aufnehmen.
  `EnemyDefinition` um Erfahrungspunkte erweitern und in
  `BattleManager.Victory()` gutschreiben.
- **Geschichte/Quests**: Neue `Interactable`-Unterklassen (z. B. Questgeber)
  und ein Quest-Zustand in `GameState`.
- **Mehr Inhalte**: Karten in `MapLayouts.cs` sind ASCII-Text — neue Gebiete
  sind schnell gezeichnet. Neue Gegner/Fähigkeiten/Gegenstände sind reine
  Daten-Assets (Menü *RPG Fable* im Create-Menü) und brauchen keinen Code.
- **Speichersystem**: `GameState` ist zentral und bewusst einfach
  serialisierbar gehalten.
