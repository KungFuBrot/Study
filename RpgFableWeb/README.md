# RPG Fable Web — Mini-JRPG für den Browser

Die Browser-Fassung von *RPG Fable* (siehe `RpgAdventureFable/` für die
Unity-Version): ein kleines 2D-Rollenspiel im Stil von Octopath Traveler /
Final Fantasy VI, geschrieben in reinem JavaScript mit HTML5-Canvas.
Kein Framework, kein Build-Schritt, keine externen Assets — sämtliche
Grafiken werden beim Start prozedural gezeichnet.

## Starten

Einfach `index.html` im Browser öffnen (Doppelklick genügt, ein Webserver
ist nicht nötig). Getestet mit aktuellen Versionen von Chrome, Firefox
und Edge.

## Spielinhalt

- **Stadt Eichenhain**: 2 ansprechbare NPCs (der Älteste gibt Hinweise,
  die Priesterin heilt die Gruppe) und ein Shop (Heiltrank, Zaubertrank).
  Keine Zufallskämpfe.
- **Weltkarte**: verbindet Stadt (Süden) und Kristallhöhle (Nordosten) —
  einfach auf das Stadt- bzw. Höhlensymbol laufen.
- **Dungeon (Kristallhöhle)**: Zufallskämpfe beim Umherlaufen
  (Schleim, Fledermaus, Golem).
- **Rundenbasierte Kämpfe**: Reihenfolge nach Tempo; Befehle Angriff,
  Fähigkeit, Gegenstand, Fliehen. Sieg bringt Gold.
- **Zwei Helden**:
  - **Aria** (Schwertkämpferin): *Wirbelklinge* (trifft alle Gegner),
    *Schildbrecher* (starker Einzelschlag)
  - **Milo** (Zauberer): *Feuerball* (Magieschaden),
    *Heilendes Licht* (heilt einen Verbündeten)
- **Effekte**: Bildschirmwackeln, schwebende Schadenszahlen, Hieb-, Feuer-
  und Heilpartikel, Auflösungseffekt besiegter Gegner, Idle-Animationen,
  Aufblitzen und Überblendungen bei Kartenwechsel und Kampfbeginn.
- **Musik und Sound**: komplett prozedural über die Web-Audio-API erzeugt
  (kleiner Chiptune-Sequenzer) — eigene Themen für Stadt, Weltkarte,
  Dungeon und Kampf, Sieg-Fanfare, Niederlagen-Motiv sowie Soundeffekte
  für Menüs, Angriffe, Magie, Heilung, Einkauf und mehr. Ton lässt sich
  mit **M** stummschalten. (Browser starten Audio erst nach der ersten
  Taste — einfach loslaufen.)

## Steuerung

| Taste | Wirkung |
|---|---|
| Pfeiltasten / WASD | Bewegen bzw. Auswahl im Menü |
| E / Enter / Leertaste | Sprechen, bestätigen, kaufen |
| Esc / Rücktaste | Abbrechen, Shop verlassen |
| M | Ton an/aus |

## Projektstruktur

```
index.html      Seite mit Canvas, lädt die Skripte in fester Reihenfolge
js/maps.js      ASCII-Karten (1 Zeichen = 1 Kachel) und Gebietsdaten
                (Spawnpunkte, Portale, NPCs, Zufallskampf-Einstellungen)
js/data.js      Fähigkeiten, Helden, Gegner, Gegenstände,
                Begegnungstabellen und der globale Spielzustand
js/sprites.js   Prozedurale Grafikerzeugung (Kacheln, Figuren, Gegner,
                Kampfhintergrund) auf Offscreen-Canvases
js/audio.js     Musik-Sequenzer und Soundeffekte (Web-Audio-API,
                alle Lieder als Notendaten, keine Audiodateien)
js/effects.js   Partikel, Schadenszahlen, Bildschirmwackeln,
                Aufblitzen und Szenenübergänge
js/ui.js        Fensterzeichnung, Textumbruch, Dialog- und Shop-UI
js/field.js     Erkundung: Bewegung, Kollision, Kamera, Portale,
                Interaktion, Zufallskämpfe
js/battle.js    Rundenbasierter Kampf (async-Ablauf wie Coroutinen)
js/main.js      Eingabe, Spielschleife, Start
```

## Erweiterungspunkte

Das Spiel ist bewusst ohne Ziel, Geschichte und Levelsystem gehalten,
aber darauf vorbereitet:

- **Levelsystem**: `GameState.party`-Einträge (in `data.js`) um
  Erfahrung/Level ergänzen; Gegner um XP-Belohnung erweitern und in
  `Battle.sieg()` gutschreiben.
- **Geschichte/Quests**: Neue NPC-Arten in `maps.js`/`field.js`
  (z. B. `art: "quest"`) und ein Quest-Zustand in `GameState`.
- **Mehr Inhalte**: Karten sind ASCII-Text in `maps.js` — neue Gebiete
  sind schnell gezeichnet. Neue Gegner, Fähigkeiten und Gegenstände sind
  reine Datensätze in `data.js` und brauchen keinen weiteren Code.
- **Speichersystem**: `GameState` ist zentral gehalten und lässt sich
  direkt per `localStorage`/JSON serialisieren.
