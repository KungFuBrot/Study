# LPC-Umstellung — Lizenz und Plan

Zielprojekt ist **RpgGodot** (das ausgelieferte Spiel), nicht RpgAnotherWorld.
Beschlossen am 2026-08-04: Helden und NPCs kommen künftig aus dem Liberated
Pixel Cup, weil das die einzige geprüfte Quelle mit echten Animationssätzen ist,
deren Weitergabe ausdrücklich erlaubt ist.

## Lizenzlage — verbindlich

LPC-Grafiken sind doppelt lizenziert: **CC-BY-SA 3.0 und GPLv3**. Beide erlauben
die Weitergabe der Dateien, worauf es hier ankommt: Unsere Grafiken stecken in
`web_build/index.pck` und liegen im öffentlichen Repo, das ist rechtlich
Verbreitung. Daran sind Aekashics und Pipoya im Juli gescheitert.

Daraus folgen vier Pflichten, die vor dem ersten Commit von Assets erfüllt sein
müssen:

1. **Namentliche Nennung jedes Beitragenden** je genutztem Sprite, im Format
   `"[Titel]" von [Autor], lizenziert [Lizenz]: [URL]`. LPC-Figuren sind aus
   Einzelteilen verschiedener Autoren zusammengesetzt — der Generator gibt zu
   jeder Auswahl die Autorenliste aus, diese Liste ist zu übernehmen. Pauschales
   „LPC-Assets" genügt nicht.
2. **Credits an zwei Stellen**: eine `assets/lpc/LICENSE.txt` im Repo und
   sichtbar im Spiel. Für Letzteres bietet sich der Abspann (`Ending.gd`) an,
   besser noch ein eigener Punkt im Titelmenü, damit die Nennung auch ohne
   Durchspielen erreichbar ist.
3. **Änderungen kennzeichnen.** Jede Bearbeitung (Umfärben, Zuschneiden,
   Skalieren, neu zusammengesetzte Streifen) wird in der LICENSE.txt vermerkt.
4. **Share-alike auf die Grafik.** Bearbeitete LPC-Grafiken bleiben unter
   CC-BY-SA 3.0. Der Spielcode ist davon **nicht** betroffen — Code und Medien
   gelten als getrennte Werke. Kein DRM auf die Assets.

Damit bleibt der bisherige Bestand unberührt: DTII und Kenney (CC0) liefern
weiter Kacheln, Requisiten und Partikel, Junkala und artisticdude die Musik und
die Klänge. Die Lizenzdateien liegen bereits neben den jeweiligen Ordnern.

## Offene Entscheidungen vor der Umsetzung

- **Wally.** Im LPC gibt es keinen Roboter. Er bliebe vorerst als einzige Figur
  aus der eigenen 3D-zu-Pixel-Pipeline — genau der Stilbruch, den wir gerade
  beseitigt haben. Alternativen: aus LPC-Teilen eine Rüstungsfigur bauen, oder
  ihn im 3D-Rig lassen und farblich angleichen.
- **Gegner.** LPC hat einige Kreaturen, aber keine 13 passenden Monster und
  schon gar keine vier Bosse. Zweite Quelle wäre Dungeon Crawl Stone Soup (CC0,
  keine Attributionspflicht, riesiger Fundus, dafür 32x32 und unbewegt). Ob sich
  LPC (64x64, weich) und DCSS (32x32, hart konturiert) vertragen, muss der Mock
  zeigen.
- **Leinwandgrößen.** Das Rig arbeitet mit Held 32x56, Monster 52x52,
  Boss 112x128. LPC-Figuren sind 64x64 pro Einzelbild. Entweder die Formation
  bleibt und die Sprites werden eingepasst, oder `BATTLE_FORMATION` wird neu
  vermessen.

## Vorgehen — Mock zuerst

Regel aus der CLAUDE.md: Stil-Umbauten nur nach In-Game-Mock und Freigabe. Drei
Anläufe wurden bereits abgelehnt, zwei davon per Force-Push zurückgenommen.

1. Helen aus dem Universal-LPC-Generator bauen, Autorenliste mitschreiben.
2. Sie allein in die echte Kampfszene setzen, neben einem unveränderten Monster.
3. Screenshot per `SPELLSHOT` (Godot **mit** Fenster, headless kann kein
   `save_png`), Ausschnitt vierfach vergrößert — im Vollbild ist bei 960x540 in
   der dunklen Arena nichts zu erkennen.
4. Freigabe abwarten. Erst danach die übrigen Figuren.

## Bezugsquellen

- Generator: <https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator>
- Basis-Assets: <https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles>
- Lizenz-Hinweise: <https://opengameart.org/content/properly-licensing-your-liberated-pixel-cup-game-entry>
- DCSS-Kacheln (CC0): <https://github.com/crawl/tiles>

## Prüfmittel

Bisher werden Änderungen ausschließlich per Augenschein an Screenshots geprüft
(`SHOT`, `SPELLSHOT`, `BOSSSHOT`). Es gibt keinen Soll-Ist-Vergleich gegen
abgelegte Referenzbilder — deshalb blieb die eingefrorene Bodenspiegelung der
Helden monatelang unbemerkt, obwohl sie auf jedem Screenshot zu sehen war. Vor
einem Umbau dieser Größe sollten Referenzbilder der wichtigsten Posen abgelegt
und nach der Umstellung gegengehalten werden.
