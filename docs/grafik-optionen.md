# Grafik stark verbessern — Optionen ohne Aufwand für den Nutzer

Stand 2026-08-02. Ausgangspunkt: Another-World-Umsetzung (RpgAnotherWorld) hat
nicht überzeugt. Gesucht: der wirkungsvollste Weg, den Claude allein umsetzen kann.

## 1. Befund — woran es tatsächlich hängt

Analysiert an `shots/world.png` (Überwelt) und `shots/battle_boss3.png` (Kampf):

| # | Problem | Ursache im Code |
|---|---|---|
| 1 | Karte wirkt wie Excel-Zellen: harte Kanten Gras↔Stein↔Wasser | `SpriteFactoryLib.tile_at()` liefert nur Voll-Kacheln + Zufallsvarianten — **keine Übergangs-/Eckkacheln (Autotiling)** |
| 2 | Alles flach, keine Höhe | Keine Schlagschatten, keine Klippenkanten, keine Baumkronen-Ebene über dem Spieler |
| 3 | Kampfkulisse = Farbverlauf mit Streifen | `BattleStage` baut Ambiente, aber keine Tiefenebenen und keine Bodenfläche |
| 4 | Maßstabs- und Stilbruch | 16-px-DTII-Helden neben 3× größerem Roboter, gemalten Bossen, Kenney-Terrain und prozeduralen Props — drei Bildquellen in einem Bild |
| 5 | Alles klotzig | 16-px-Quellen bei Kamera-Zoom 3 → jedes Detail ist ein 48-px-Block |

Wichtig: **Punkte 1–3 sind keine Kunst-, sondern Logikprobleme.** Sie kosten
mehr wahrgenommene Qualität als der Sprite-Stil selbst — und sind zu 100 % per
Code lösbar, ohne einen einzigen neuen Pixel.

## 2. Die Optionen

### A — Präsentation & Kartenlogik („Postproduktion") · empfohlen
Kein neues Bildmaterial, nur Aufbau und Rendering:
- **Autotiling** per 8-Nachbar-Bitmaske: Übergangs- und Eckkacheln für
  Gras/Weg/Wasser/Stein (Kenney-Sheet enthält sie bereits, sie werden nur nicht genutzt).
- **Höhe:** weiche Schlagschatten unter Figuren/Props/Bäumen, Klippenkanten mit
  Abschattung, Kronen-Layer, hinter dem die Party durchläuft.
- **Kampf:** Kulisse aus 4–5 Parallax-Tiefenebenen + echter Bodenfläche mit
  Kontaktschatten + Vordergrund-Silhouetten + Lichtschächten.
- **Bildlook:** Farbgrading pro Region (LUT), Vignette, Bloom-Feinschliff,
  weichere Kamera (Nachlauf, leichter Zoom-Atem).

Risiko: minimal — der Sprite-Stil bleibt exakt, wie er ist.
Wirkung: nach meiner Einschätzung ~70 % des möglichen Qualitätssprungs.

### B — Auflösungssprung auf einheitliche 32-px-Figuren aus einem Code-Rig
Ein einziger Zeichen-Generator für alle Figuren (Helden, NPCs, Monster, Bosse):
Rig aus Körperteilen, gemeinsame Palette, gemeinsame Lichtrichtung, gemeinsame
Kontur. Behebt Punkt 4 und 5 an der Wurzel und liefert flüssigere Animationen.

Risiko: mittel — hier scheiterte der AW-Pilot. Laut Rückblick lag das an der
**Ausführung** (Animation, Detailgrad), nicht am Stil. Deshalb: erst Mock, dann Freigabe.

### C — Ein einziges kohärentes CC0-Komplettpack statt DTII + Kenney + prozedural
Ich suche, lade und integriere ein vollständiges 32-px-JRPG-Pack (Terrain,
Figuren, Monster, UI aus einer Hand). Behebt den Stilbruch sofort.

Risiko: „Asset-Packs" wurden schon einmal abgelehnt — allerdings galt das dem
*Mix*, nicht einem geschlossenen Pack. Nachteil: das Spiel sieht dann aus wie
das Pack, nicht wie ein Eigenstil.

### D — KI-generierte Grafik
Ehrlich gesagt: **ich kann selbst keine Bilder generieren.** Der bestehende Plan
(`ki-grafikstil-plan.md`) setzt voraus, dass du Midjourney/Retro-Diffusion
bedienst. Eine lokale Stable-Diffusion-Installation wäre mehrere GB Download,
GPU-Abhängigkeit und Einrichtung — das erfüllt „ohne dass ich etwas tun muss"
nicht. Bleibt vorerst liegen.

## 3. Vorschlag

1. **A vollständig umsetzen** und als In-Game-Mock zeigen (Vorher/Nachher-Screenshots
   von Überwelt, Dungeon, Kampf). Kein Stilbruch, also risikofrei.
2. Erst danach **B als Mock** — zwei, drei Figuren im neuen Rig neben den alten,
   in der echten Szene. Freigabe oder Verwerfen ohne Folgekosten.
3. **C** nur, falls B nicht überzeugt.
