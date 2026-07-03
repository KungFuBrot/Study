# RPG Adventure (Unity)

Ein kleines rundenbasiertes RPG im Stil von *Final Fantasy VI* / *Octopath Traveler*,
geschrieben in C# für Unity. Stadt, Weltkarte, Dungeon-Kämpfe, Shop und NPCs -
alle Grafiken (Kacheln, Held:innen, Gegner, UI) werden von Editor-Skripten
**prozedural erzeugt**, es müssen keine externen Bilder heruntergeladen werden.

## Spielinhalt

- **Stadt**: 2 sprechbare NPCs (Dorfältester, Wache) und ein Laden (Miras Laden)
  mit kaufbaren Tränken. Keine Zufallskämpfe.
- **Weltkarte**: verbindet Stadt und Dungeon, ebenfalls ohne Zufallskämpfe.
- **Dungeon**: Zufallskämpfe bei jedem Schritt auf dem Boden (ca. 12 % Chance).
- **Zwei steuerbare Held:innen**: Aria (Schwertkämpferin, Fähigkeit "Wirbelschlag")
  und Elan (Zauberer, Fähigkeiten "Feuerball" und "Heilung").
- **Rundenbasierte Kämpfe**: Zugreihenfolge nach Initiative/Geschwindigkeit,
  Menü mit Angriff / Fähigkeit / Item / Flucht, einfache Gegner-KI.
- Bewusst **kein** Ziel, keine Geschichte und kein Level-System - die Datenklassen
  (`HeroDefinition`, `EnemyDefinition`, ...) sind aber so gehalten, dass sich das
  später ergänzen lässt, ohne bestehenden Code umzubauen.

## Enthalten

```
Assets/Scripts/Runtime/Data/       Hero-, Fähigkeits-, Gegner-, Item- und Encounter-Definitionen (ScriptableObjects)
Assets/Scripts/Runtime/Core/       GameState (Party/Gold/Inventar, Szenenübergabe), PartyMember
Assets/Scripts/Runtime/Overworld/  Gridbewegung, NPCs, Shop, Dialog, Szenenübergänge, Zufallskämpfe, HUD
Assets/Scripts/Runtime/Battle/     Rundenkampf-Logik (BattleManager), Kampf-UI, BattleUnit/-Action
Assets/Scripts/Editor/             Prozedurale Grafik-, Daten- und Szenen-Erzeugung (nur im Editor)
```

## Einrichtung (einmalig, ca. 3 Minuten)

1. **Unity-Projekt erstellen**: Im Unity Hub ein neues Projekt mit dem Template
   *"2D (Core)"* anlegen (Unity 2021 LTS oder neuer).
2. Den Ordner **`Assets/Scripts`** aus diesem Verzeichnis in den `Assets`-Ordner
   deines neuen Unity-Projekts kopieren (Explorer/Copy-Paste genügt).
3. Unity öffnen/fokussieren, damit die Skripte kompiliert werden.
4. Im Menü **"RPG Spiel"** der Reihe nach ausführen (oder direkt
   **"RPG Spiel → Alles erstellen (1-6)"** für alle Schritte auf einmal):
   1. **Bilder erzeugen** - Kacheln, Held:innen, NPCs, Gegner, UI-Panel als PNG.
   2. **Daten erzeugen** - Helden, Fähigkeiten, Gegner, Items, Zufallskampf-Tabelle
      als Assets unter `Assets/Resources/Data`.
   3. **Stadt-Szene erstellen** - `Assets/Scenes/TownScene.unity`.
   4. **Weltkarte-Szene erstellen** - `Assets/Scenes/WorldMapScene.unity`.
   5. **Dungeon-Szene erstellen** - `Assets/Scenes/DungeonScene.unity`.
   6. **Kampf-Szene erstellen** - `Assets/Scenes/BattleScene.unity`.
5. **`Assets/Scenes/TownScene.unity` öffnen** (wichtig - nach "Alles erstellen"
   ist zuletzt die Kampf-Szene aktiv) und **Play** drücken.

Jeder Schritt lässt sich beliebig oft erneut ausführen und überschreibt dabei
nur seine eigenen Assets/Szenen - eigene Änderungen an anderen Stellen bleiben
unberührt.

## Steuerung

- **Pfeiltasten / WASD**: Bewegen (schrittweise auf dem Raster).
- **Leertaste / E / Enter**: Mit NPC/Händler:in interagieren, Dialog weiterblättern.
- **Escape**: Shop-Fenster schließen.
- Im Kampf: Aktionen per Maus über die Menüs unten auswählen.

## Wie die Szenen zusammenhängen

`TownScene` → (Tor im Süden) → `WorldMapScene` → (Tor im Osten) → `DungeonScene`.
Zufallskämpfe im Dungeon laden `BattleScene`; nach Sieg/Flucht geht es an exakt
die Stelle zurück, an der der Kampf begann. Bei einer Niederlage der ganzen
Gruppe wird sie mit halber HP zurück ins Dorf gebracht (kein Game-Over-Screen).

## Anpassen

- **Werte/Fähigkeiten der Held:innen**: `RpgDataBuilder.cs`, Schritt 2 erneut
  ausführen.
- **Kartenlayout** (Stadt/Weltkarte/Dungeon): `AsciiMap`-Aufbau am Anfang von
  `TownSceneBuilder.cs` / `WorldMapSceneBuilder.cs` / `DungeonSceneBuilder.cs`,
  jeweiligen Schritt erneut ausführen.
- **Encounter-Wahrscheinlichkeit**: `encounterChancePerStep` in
  `DungeonSceneBuilder.cs`.
- **Aussehen**: Farben/Formen in `RpgTextureGenerator.cs`, Schritt 1 (und danach
  ggf. 2-6) erneut ausführen.
- **Neue Fähigkeiten/Gegner/Items**: in `RpgDataBuilder.cs` per `CreateAsset<...>`
  ergänzen.

Alle Editor-Skripte sind jederzeit erneut ausführbar (überschreiben die vorher
erzeugten Assets/Prefabs/Szenen anhand des Namens/Pfads).
