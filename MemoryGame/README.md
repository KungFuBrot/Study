# Memory Spiel (Unity)

Ein einfaches Karten-Memory (4x4, 8 Paare) in C# für Unity. Alle Kartenbilder
(Rückseite, Rahmen und 8 bunte Icons) werden von einem Editor-Skript
**prozedural erzeugt** — es müssen keine externen Bilddateien heruntergeladen
werden.

## Enthalten

```
Assets/Scripts/Runtime/Card.cs           Kartenlogik (Flip-Animation, Klick)
Assets/Scripts/Runtime/GameManager.cs    Spielaufbau, Mischen, Paare prüfen, Timer, Sieg
Assets/Scripts/Editor/Sdf.cs             Mathematische Formen (Kreis, Herz, Stern, ...)
Assets/Scripts/Editor/IconTextureGenerator.cs   Erzeugt alle Kartenbilder als PNG
Assets/Scripts/Editor/MemorySceneBuilder.cs     Baut Prefab + Szene automatisch auf
```

## Einrichtung (einmalig, ca. 2 Minuten)

1. **Unity-Projekt erstellen**: Im Unity Hub ein neues Projekt mit dem Template
   *"2D (Core)"* anlegen (Unity 2021 LTS oder neuer).
2. Diesen Ordner **`Assets/Scripts`** in den `Assets`-Ordner deines neuen
   Unity-Projekts kopieren (z. B. per Explorer/Copy-Paste).
3. Unity öffnen/fokussieren — die Skripte werden automatisch kompiliert.
4. Im Menü: **Memory Spiel → 1. Bilder erzeugen**
   → erzeugt Kartenrückseite, Rahmen, Hintergrund und 8 Icons unter
   `Assets/Sprites/...`.
5. Im Menü: **Memory Spiel → 2. Szene erstellen**
   → baut das Karten-Prefab, Canvas, UI und `GameManager` automatisch und
   speichert die Szene unter `Assets/Scenes/MemoryGame.unity`.
6. **Play** drücken. Fertig!

## Spielregeln

- 4×4 Raster mit 8 Bildpaaren, zufällig gemischt.
- Zwei Karten anklicken: stimmen die Symbole überein, bleiben sie offen;
  sonst drehen sie sich nach kurzer Zeit wieder um.
- Züge- und Zeit-Anzeige oben, Sieg-Bildschirm mit "Nochmal spielen"-Button
  bei vollständig aufgedecktem Feld.

## Anpassen

- **Rastergröße / Anzahl Paare**: `pairCount` im `GameManager` (max. 8, da
  aktuell 8 Icons erzeugt werden). Für mehr Paare in
  `IconTextureGenerator.GetIconDefs()` weitere Formen ergänzen und danach
  Schritt 4 + 5 erneut ausführen.
- **Farben**: Hex-Farben in `IconTextureGenerator.cs` (`Hex("#....")`) ändern
  und Schritt 4 + 5 erneut ausführen.
- **Rastergröße/Abstände** (Kartengröße in Pixel): Konstanten `cell` und
  `spacing` in `MemorySceneBuilder.BuildScene()`.

Beide Editor-Skripte sind jederzeit erneut ausführbar (überschreiben die
vorher erzeugten Assets bzw. Prefab/Szene).
