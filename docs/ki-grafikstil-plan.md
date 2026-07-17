# Plan: KI-generierter Grafikstil im Look von „Pixel Boss Fights"

Ziel: RpgGodot soll den Look des PromptBase-Prompts
[„Pixel Boss Fights"](https://promptbase.com/prompt/pixel-boss-fights) bekommen —
epische Pixel-Art-Boss-Szenen: riesiger, detailreicher Boss, kleine Helden,
dramatisches Licht. Der Prompt selbst ist nur ein (kostenloser) Midjourney-
Text-Prompt und liefert **keine Sprites** — wir nutzen ihn als Stil-Fundament
und bauen die spielbaren Assets mit spezialisierten KI-Werkzeugen darum herum.

## 1. Werkzeugkasten

| Zweck | Werkzeug | Anmerkung |
|---|---|---|
| Stil-Referenzen, Szenen, Hintergründe | **Midjourney** (mit dem PromptBase-Prompt) | Abo nötig (~10 $/Monat); kommerzielle Nutzung erst mit Bezahl-Plan |
| Spielfertige Pixel-Sprites (Transparenz, echtes Pixelraster, Tiling) | **Retro Diffusion** (retrodiffusion.ai, auch als Aseprite-Plugin) | Gratis-Kontingent zum Ausprobieren |
| Charakter-Animationen (Idle/Walk/Attack, 4–8 Richtungen) | **PixelLab** (pixellab.ai) | „Animate from image/skeleton" — löst das größte KI-Problem: Frame-Konsistenz |
| Volle Kontrolle / kostenlos lokal | Stable Diffusion + Pixel-Art-LoRA + ControlNet | Aufwendiger; Posen per ControlNet steuerbar |
| Nachbearbeitung | Aseprite (Palette, Frames), rembg (Freistellen), ImageMagick (Batch) | Automatisiere ich per Skript |

## 2. Stil-Fundament legen (1 Abend)

1. Mit dem PromptBase-Prompt in Midjourney **20–30 Referenzbilder** generieren —
   pro Dungeon-Thema Varianten (Schlotwerk/Fabrik, Konzernturm, Hassfestung, Leere).
2. Die besten 6–8 als **Stil-Anker** kuratieren.
3. **Palette extrahieren** (32–48 Farben) — ab dann verbindlich für alle Assets
   (Palette-Snap per Skript hält alles konsistent).
4. Stil-Guide festhalten: Zielauflösungen (Boss 96–128 px, Held 48–64 px,
   Tile 16 px), Outline-Regel, Lichtrichtung.

**Konsistenz-Techniken:** Midjourney `--sref <Anker-URL>` (Style Reference) für
alle Folgebilder; `--cref` für denselben Charakter in mehreren Posen; bei
Stable Diffusion ein kleines **LoRA auf den Ankerbildern** trainieren.

## 3. Assets in Reihenfolge von Wirkung/Aufwand

### Stufe A — Quick Wins (1–2 Sessions, größter Stil-Effekt)
- **4 Battle-Hintergründe** (je Dungeon-Thema, 960×540): Midjourney-Szene ohne
  Figuren → pixelieren + Palette-Snap → statische Kulisse in `Battle.gd`
  (ersetzt die prozedurale Arena; Lichter/Nebel/Partikel bleiben als Ebenen darüber).
- **5 Boss-Standbilder** (4 Bosse + Endboss „Die Stille" als Spinnentier):
  freistellen → auf Zielgröße runterrechnen → 2–4 Idle-Frames („Atmen" =
  minimale Verschiebung in Aseprite oder Retro-Diffusion-Animation).
  Genau DAS ist die Stärke der Vorlage: kleiner Held, riesiger gemalter Boss.
- **Titelbild** für den Titelscreen.

### Stufe B — Porträts & Story-Bilder
- Helden-/NPC-Porträts (Dialogboxen, Party-Panel), 3 Intro-Kapitelbilder, Ending.

### Stufe C — Helden-Kampfsprites (anspruchsvollster Teil)
- Pro Held: Referenzbild im Ankerstil → PixelLab generiert Idle/Run/Attack/Hit.
- Fallback, falls die Frame-Qualität nicht reicht: Helden klein lassen und nur
  Bosse/Hintergründe im neuen Stil — entspricht exakt der Vorlage.

### Stufe D — Feld/Tiles (optional, höchstes Risiko)
- KI-Kacheln tilen schlecht. Wenn, dann Retro-Diffusion-**Tiling-Modus** je
  Terrain; sonst Erkundung bewusst im bisherigen Stil belassen
  (Stilwechsel Erkundung→Kampf wie in Octopath Traveler).

## 4. Technische Integration (übernimmt Claude)

- Ablage `RpgGodot/assets/ai/{backgrounds,bosses,portraits,heroes}/` + CREDITS.
- `SpriteFactory`: Loader analog zum bisherigen Atlas-System, Frame-Configs
  (Anzahl, Größe, Fußlinie) — die Battle-/Field-Architektur bleibt unverändert.
- **Pipeline-Skript**: Freistellen → Downscale → Palette-Snap → Zuschnitt in
  einem Kommando, damit jedes neue KI-Bild reproduzierbar spielfertig wird.
- Verifikation: Montage-Rendertest (headless) + Web-Export wie gehabt.

## 5. Arbeitsteilung

- **Du:** Account(s) anlegen, Bilder generieren (fertige Prompt-Bausteine unten),
  Favoriten auswählen, PNGs in einen Ordner legen.
- **Claude:** alle Skripte, Zuschnitt/Palette, Godot-Integration, Tests, Export.

## 6. Rechtliches (Kurzfassung)

- Midjourney: kommerzielle Nutzung nur mit Bezahl-Abo; Output nicht exklusiv.
- Retro Diffusion / PixelLab: Output gehört laut Terms dem Ersteller (prüfen).
- Reiner KI-Output ist i. d. R. nicht urheberrechtlich schützbar — für dieses
  Lernprojekt unkritisch; Herkunft trotzdem in einer CREDITS-Datei dokumentieren.
- Keine fremden Marken/Figuren in Prompts.

## 7. Prompt-Bausteine (Startpunkt)

- **Szene/Hintergrund:** `pixel art boss fight scene, giant [BOSS], dark
  [THEME] arena, dramatic rim lighting, 16-bit JRPG style, limited color
  palette, highly detailed sprite work, no characters --ar 16:9 --sref <ANKER>`
- **Boss freigestellt:** `pixel art game sprite of [BOSS], full body, centered,
  plain solid background, no scenery, 16-bit style, facing left --sref <ANKER>`
- **Boss-Beispiele:** Schlotbaron = `hulking industrial sludge baron, smokestack
  armor, toxic green glow`; Die Stille = `giant pale spider creature, eight
  glowing red eyes, black widow silhouette, void grey mist`.

## 8. Nächster Schritt

Stufe A starten: Du generierst mit dem PromptBase-Prompt die ersten
Referenzen + 1 Battle-Hintergrund + 1 Boss (z. B. Schlotbaron) und legst die
PNGs ab — daraus baue ich Pipeline und Integration, danach skalieren wir auf
alle Bosse/Hintergründe.
