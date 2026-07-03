"use strict";

/*
 * ASCII-Layouts der drei Karten. Ein Zeichen = eine Kachel (32 px).
 * Zeile 0 ist die oberste Kartenzeile.
 *
 * Legende Stadt:   T Baum, G Gras, F Blumen, P Weg, W Wasser,
 *                  r Dach, w Hauswand, d Tür (alles Haus = blockiert)
 * Legende Welt:    M Berg, g Wiese, f Wald, V Wasser,
 *                  C Stadt (begehbar), D Dungeon-Eingang (begehbar)
 * Legende Dungeon: # Fels, . Boden, o Felsbrocken
 */
const Maps = {
  stadt: [
    "TTTTTTTTTTTTTTTTTTTT",
    "TGGGGGGGGGGGGGGGGGGT",
    "TGrrrGGGGrrrGGGGGGGT",
    "TGwdwGGGGwdwGGWWGGGT",
    "TGGPGGGGGGPGGGWWGGGT",
    "TGGPPPPPPPPGGGGGGGGT",
    "TGGGGGGGGGPGGGGGGGGT",
    "TGGrrrGGGGPGGGrrrGGT",
    "TGGwdwGGGGPGGGwdwGGT",
    "TGGGPGGGGGPGGGGPGGGT",
    "TGFGPPPPPPPPPPPPFGGT",
    "TGGGGGGGGGPGGGGGGGGT",
    "TGGGGGGGGGPGGGGFGGGT",
    "TTTTTTTTTTPTTTTTTTTT",
    "TTTTTTTTTTPTTTTTTTTT",
  ],
  weltkarte: [
    "MMMMMMMMMMMMMMMMMMMMMMMMMM",
    "MggggggggggggggggggMMMMMMM",
    "MggggggffggggggggggMMDMMMM",
    "MgggggfffggggggggggggggMMM",
    "MggggggffgggVVggggggggggMM",
    "MgggggggggVVVVVgggggffgggM",
    "MggggggggVVVVVVVgggffffggM",
    "MgggggggggVVVVVgggggffgggM",
    "MggggggggggVVVgggggggggggM",
    "MggffggggggggggggggggggggM",
    "MgffffgggggggggggffggggggM",
    "MggffggggggggggggffffggggM",
    "MgggggggggggggggggffgggggM",
    "MgggCggggggggggggggggggggM",
    "MggggggggggggggggggggggggM",
    "MMgggggggggggggggggggggMMM",
    "MMMgggggggggggggggggMMMMMM",
    "MMMMMMMMMMMMMMMMMMMMMMMMMM",
  ],
  dungeon: [
    "######################",
    "#........##..........#",
    "#.o......##...o...o..#",
    "#........##..........#",
    "###......##...####...#",
    "#.........#......o...#",
    "#...o................#",
    "#.......####.........#",
    "#.......#..#....o....#",
    "##..o...#..#.........#",
    "#.......#..#....###..#",
    "#..o....#..#.....#o..#",
    "#........#...........#",
    "#########....#########",
    "##########.###########",
  ],
};

const BLOCKIERT = "TWrwdMfV#o";

function istBlockiert(map, col, row) {
  if (row < 0 || row >= map.length || col < 0 || col >= map[0].length) return true;
  return BLOCKIERT.indexOf(map[row][col]) >= 0;
}

/*
 * Gebiete: Karten plus Spawnpunkte, Portale, NPCs und Zufallskämpfe.
 * Koordinaten sind Kachelspalten/-zeilen (col, row).
 */
const Areas = {
  stadt: {
    map: Maps.stadt,
    spawns: { Start: [10, 11], Sued: [10, 12] },
    portals: [
      { col: 10, row: 14, ziel: "weltkarte", spawn: "VonStadt" },
    ],
    npcs: [
      {
        col: 2, row: 4, sprite: "aeltester", name: "Ältester Theobald",
        art: "dialog", hint: "[E] Sprechen",
        lines: [
          "Willkommen in Eichenhain, Reisende!",
          "Nordöstlich von hier liegt die alte Kristallhöhle. Es heißt, dort hausen Ungeheuer.",
          "Folgt dem Weg nach Süden, dann erreicht ihr die Weltkarte. Aber seid gewappnet!",
        ],
      },
      {
        col: 11, row: 4, sprite: "priesterin", name: "Priesterin Lina",
        art: "dialog", hint: "[E] Sprechen", heilt: true,
        lines: [
          "Mögen die Ahnen euch schützen.",
          "Eure Wunden sind geheilt und euer Geist ist erfrischt. Kommt jederzeit wieder.",
        ],
      },
      {
        col: 14, row: 9, sprite: "haendlerin", name: "Gretas Kramladen",
        art: "shop", hint: "[E] Handeln",
        waren: ["heiltrank", "zaubertrank"],
      },
    ],
    encounters: null, // In der Stadt gibt es bewusst keine Zufallskämpfe.
  },
  weltkarte: {
    map: Maps.weltkarte,
    spawns: { VonStadt: [4, 14], VonDungeon: [21, 3] },
    portals: [
      { col: 4, row: 13, ziel: "stadt", spawn: "Sued" },      // Stadt-Symbol
      { col: 21, row: 2, ziel: "dungeon", spawn: "Start" },   // Höhleneingang
    ],
    npcs: [],
    encounters: null,
  },
  dungeon: {
    map: Maps.dungeon,
    spawns: { Start: [10, 12] },
    portals: [
      { col: 10, row: 14, ziel: "weltkarte", spawn: "VonDungeon" },
    ],
    npcs: [],
    encounters: { tabelle: "dungeon", chance: 0.16, pruefDistanz: 1, schonfrist: 4 },
  },
};
