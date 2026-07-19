# Another-World-Grafikstil — kompletter Umbau mit echtem Animationssystem

> **Umsetzung im Parallel-Projekt `RpgAnotherWorld/`** (Nutzer-Entscheidung
> 2026-07-18): Kopie von RpgGodot, Original bleibt unangetastet; Web-Export
> nach `web_build_aw/`. **Stand: Milestone 0 umgesetzt** — AwRig-Engine
> (Bones/Keyframes/Validator), 3 Helden-Rigs (Idle/Run/Attack bzw. Cast/Aim),
> Schlotbaron + 3 Schlotwerk-Monster, AW-Kulisse der Toxic-Arena; In-Game-
> Screenshots liegen vor, warten auf Freigabe für M1 (übrige Arenen/Bosse).

## Kontext

RpgGodot soll konsequent (Kampf, Feld, Titel, Intro/Ending, UI) den Flächen-Look
von **Another World** (Eric Chahi) bekommen: flache Farbflächen, harte
Schattenbänder, Silhouetten, keine Outlines, wenige Farben.

Vorgeschichte: Der AW-Pilot vom 17./18.07. wurde verworfen — laut Nutzer **nicht
wegen des Stils**, sondern wegen der Ausführung: *Animationen fehlten oder waren
schlecht; der Boss hatte zu wenig Details, wirkte unvollständig, Teile schwebten
in der Luft.* Der Pilot hatte außerdem einen bewussten Stilbruch (nur Boss +
Arena + Titel AW, Rest Pixel-Art). Konsequenzen für diesen Plan:

1. **Animation zuerst**: Ein joint-basiertes Rig-/Keyframe-System ist das
   Fundament — keine handgebackenen Einzelframes mit Mikro-Verschiebungen mehr.
2. **Qualitäts-Validatoren**: Automatischer Check gegen „schwebende Teile"
   (Zusammenhangs-Analyse der Alpha-Maske jedes gebackenen Frames) + Zoom-Montagen
   jedes Rigs vor Einbau.
3. **Kein Stilbruch**: Alles wird umgestellt; Meilenstein-Gates mit
   In-Game-Screenshots vor jedem großen Ausbau (Projektregel nach 3 abgelehnten
   Stil-Anläufen).

### Ist Vibe Coding dafür realistisch? (Kernfrage des Nutzers)

**Ja — mit klaren Einschränkungen.** AW ist einer der wenigen Grafikstile, die
prozedural per Code wirklich erreichbar sind (flache Polygone, wenige Farben,
keine Texturen — die Demo `_assets_tmp/draw_aw.gd` hat das belegt). Die harte
Grenze ist die Animationsqualität: Another Worlds Bewegungen waren **rotoskopiert**
(von Filmaufnahmen abgezeichnet) — diese Flüssigkeit erreicht Keyframe-Code
nicht. Realistisches Ziel: sauberes Keyframe-Cartoon-Niveau mit 8–16 Frames pro
Zyklus bei ~12 fps (AW-typisch niedrige Framerate hilft uns hier sogar).
Aufwand ehrlich geschätzt: **8–12 Sessions** für den Vollumbau, iterativ mit
Screenshot-Reviews. Größtes Risiko: Die In-Game-Wirkung gefällt trotz allem
nicht — dagegen stehen die Gates (Abbruch nach M0 kostet nur ~2 Sessions).

## Kernarchitektur

### AW-Rig-System (neu, das Herzstück)

Neue Datei `RpgGodot/scripts/sprites/AwRig.gd` (+ Rig-Definitionen in 2–3
weiteren Dateien, analog zur bestehenden SpriteFactory-Kette):

- **Bones**: benannte Teile mit Pivot + Parent (torso → head/arm_l/arm_r/leg_l/leg_r …),
  Rotation/Translation pro Bone. Polygone hängen an Bones und werden mit
  transformiert → **Teile können konstruktionsbedingt nicht mehr „schweben"**,
  Gelenke werden durch überlappende Rundungen (Ellipsen an den Pivots) geschlossen.
- **Shading pro Teil**: 3–4 Flächenstufen + Rim-Licht + zweite Lichtfarbe
  (bewährtes Demo-Feedback „mehr Farben/Details").
- **Posen & Keyframes**: Eine Animation = Liste benannter Posen (Bone-Winkel) +
  Frame-Anzahl; Interpolation (mit Ease) zwischen Posen; Walk-Zyklen mit
  Kontakt-/Passier-Pose nach Animationslehrbuch.
- **Backen**: Rasterisierung über den erprobten Scanline-Rasterizer `_aw_poly`
  (aus `_assets_tmp/draw_aw.gd` übernehmen) in ImageTexture-Frame-Arrays.
  Dadurch bleibt die **gesamte bestehende Sprite2D-Pipeline unangetastet**
  (Tint, Dissolve, Reveal, Spiegelung, `enemy_frames`, Bob/Ticker — Lehre aus
  dem Piloten).
- **Farbregel**: Flächenfarben ~2x heller anlegen als „richtig" wirkend —
  CanvasModulate/Vignette/Grade dimmen kräftig (wichtigste Pilot-Lehre).

### Qualitäts-Validatoren (Antwort auf „unvollständig/schwebend")

Headless-Skript pro Rig (Muster: `_assets_tmp/check_aw_boss.gd`):
1. Rendert alle Frames aller Animationen als gezoomte Montage-PNGs → visuelle
   Prüfung per Read-Tool **vor** jedem Einbau.
2. **Zusammenhangs-Check**: Flood-Fill über die Alpha-Maske jedes Frames — mehr
   als 1 Zusammenhangskomponente (außer deklarierten Ausnahmen wie Qualmwolken)
   = Fehler. Kein Rig geht ohne grünen Check ins Spiel.
3. In-Game-Screenshots über die vorhandenen Debug-Hooks (SHOT/SPELLSHOT/
   BOSSSHOT) + Web-Build-Helligkeitsprüfung (Desktop rendert dunkler!).

## Meilensteine (jeder endet mit Screenshot-Review = Gate)

### M0 — Animations-Beweis + Voll-Mock (~2 Sessions) ⛔ GATE
Erst das Rig-System bauen, dann EINE Kampfszene komplett AW, in-game:
- Rig-System + Validatoren implementieren.
- **Held Helen als Rig**: Idle (Atmen/Gewichtsverlagerung), Run-Zyklus (8 Frames,
  Kontakt/Passier-Posen), Schwerthieb, Treffer-Reaktion — als Montage UND in-game.
- **Schlotbaron neu als Rig** (deutlich detaillierter als der Pilot: Ofenglut,
  Qualm, Sabber; alle Teile über Bones verbunden), 1–2 normale Monster als Rigs.
- Toxic-Arena aus dem Piloten wiederherstellen/verfeinern (`_build_arena_aw`-
  Wissen aus Memory), UI-Rahmen flach/minimal angepasst.
- Deliverable: In-Game-Screenshots (Kampf: Idle, Angriff, Boss) → **Freigabe
  oder Abbruch**.

### M1 — Kampf komplett (~3 Sessions)
- Alle 4 Arenen (toxic/gold/hate/void) als Polygon-Kulissen mit Leben
  (driftende Elemente, pulsierende Lichter — Muster aus dem Piloten).
- Alle 4 Bosse als große Rigs (Reveal-, Wut-, AoE-, Ultimate-Inszenierungen
  behalten ihre Logik; nur Sprites + ggf. Skalen wechseln, `k = 7.2/scale`-Anpassung
  der Aufsätze wie im Piloten).
- 11 normale Monster als Silhouetten-Rigs mit Idle + Angriffs-Windup.
- Helden Janosch + Wally als Rigs mit vollem Posen-Satz, den die bestehenden
  Aktionen brauchen: idle/run (für `_sprint`), cast, aim, Treffer, Ohnmacht.
  Routing über die bestehenden `hero_battle_frame`/`robot_battle_pose`-Schnittstellen.
- Geschosse/Waffen als flache Formen; Kenney-Bitmap-Partikel bleiben vorerst
  (additive Glüh-Partikel passen erstaunlich gut auf Flächen — Pilot-Erfahrung).

### M2 — Feld/Erkundung (~2 Sessions)
- Top-down bleibt. Kacheln → flache Farbflächen mit harten Kanten
  (Terrain-Bänder statt Einzelkachel-Optik), Bäume/Berge/Props als Silhouetten.
- Feldfiguren (Helden, NPCs) als kleine Rigs: 3 Richtungen × Walk-Zyklus über
  die bestehende `field_char(id, walking, frame)`-Schnittstelle.
- Licht-Rework: LIGHTING/CanvasModulate-Werte an die hellere AW-Basis anpassen.

### M3 — Titel, Intro, Ending, UI (~1–2 Sessions)
- Titelszene aus dem Piloten wiederherstellen (harte Bänder, Polygon-Mond,
  Silhouetten-Helden am Feuer) + Feuer als Polygon-Flackern.
- Intro/Ending als AW-typische Kino-Panels (Polygon-Illustrationen statt Text
  auf Schwarz) — AWs berühmte Intro-Sequenz als Vorbild.
- UI: flache Rahmen, Schrift bleibt (Web-Font-Falle: keine exotischen Glyphen).

### M4 — FX-Feinschliff (optional, ~1 Session)
- Explosionen/Zauber als expandierende Polygon-Splitter/Flächenblitze, wo die
  Bitmap-Partikel im Kontrast störend auffallen. Nur nach Sichtprüfung in M1–M3.

## Vorarbeit (vor M0)

- Uncommittete WIP-Änderungen sichern: `GameState.gd`/`BattleFx.gd`/`BattleStage.gd`
  enthalten eine halbfertige Monster-Spezialattacken-Funktion (aus früherer
  Session). Erst committen (falls lauffähig, Headless-Check) oder stashen —
  nicht mit dem Stil-Umbau vermischen.
- Diesen Plan als `docs/another-world-stil-plan.md` ins Repo übernehmen
  (Nachschlagewerk über Sessions hinweg, analog `docs/ki-grafikstil-plan.md`).

## Betroffene Dateien

| Bereich | Dateien |
|---|---|
| Neu | `scripts/sprites/AwRig.gd` + `AwRigsHeroes.gd`/`AwRigsMonsters.gd`/`AwRigsBosses.gd` (in die SpriteFactory-Vererbungskette eingehängt) |
| Sprites-Routing | `scripts/sprites/SpriteFactoryLib/Chars.gd`, `scripts/SpriteFactory.gd` (enemy_frames/hero_battle_frame/field_char/tile auf AW umleiten) |
| Kampf | `scripts/battle/BattleStage.gd` (Arenen), `BattleBossCine.gd` (Skalen/Offsets), `BattleUi.gd` (flache Rahmen) |
| Feld | `scripts/Field.gd` (Tiles, Licht, Props) |
| Rahmen | `scripts/Title.gd`, `Intro.gd`, `Ending.gd`, ggf. `Fx.gd` |
| Wiederverwendung | `_assets_tmp/draw_aw.gd` (Rasterizer + Demo-Szene), `_assets_tmp/check_aw_boss.gd` (Montage-Muster), Debug-Hooks SHOT/SPELLSHOT/BOSSSHOT/MENUSHOT |

Regeln der Battle-/Sprite-Vererbungsketten (nur Aufrufe nach oben) und
`RpgGodot/CLAUDE.md`-Konventionen gelten unverändert.

## Verifikation

1. Pro Rig: Montage-Render (headless `--script`) + Zusammenhangs-Validator grün.
2. Nach jedem Umbau: `godot --headless --editor --quit` (Klassen-Cache), dann
   `--headless --quit` (Kompiliercheck), dann SPELLSHOT-Smoke-Lauf.
3. Pro Meilenstein: In-Game-Screenshots (SHOT-Tour + BOSSSHOT) → Nutzer-Review;
   dunkle Szenen zusätzlich im Web-Build beurteilen (Desktop rendert dunkler).
4. Sessionende wie gewohnt: Web-Export, deutsche Commit-Message, push
   (Nutzer-Präferenz „Commit am Ende").
