using UnityEngine;

namespace RpgFable.EditorTools
{
    /// <summary>
    /// ASCII-Layouts der drei Karten. Ein Zeichen = eine Kachel (32 px).
    /// Zeile 0 ist die oberste Kartenzeile.
    ///
    /// Legende Stadt:   T Baum, G Gras, F Blumen, P Weg, W Wasser,
    ///                  r Dach, w Hauswand, d Tür (alles Haus = blockiert)
    /// Legende Welt:    M Berg, g Wiese, f Wald, V Wasser,
    ///                  C Stadt (begehbar), D Dungeon-Eingang (begehbar)
    /// Legende Dungeon: # Fels, . Boden, o Felsbrocken
    /// </summary>
    public static class MapLayouts
    {
        public static readonly string[] Stadt =
        {
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
        };

        public static readonly string[] Weltkarte =
        {
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
        };

        public static readonly string[] Dungeon =
        {
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
        };

        private const string BlockedChars = "TWrwdMfV#o";

        public static bool IsBlocked(char c)
        {
            return BlockedChars.IndexOf(c) >= 0;
        }

        public static int Cols(string[] map) { return map[0].Length; }
        public static int Rows(string[] map) { return map.Length; }

        /// <summary>Weltposition der Kachelmitte (Karte beginnt bei (0,0), y nach oben).</summary>
        public static Vector2 CellCenter(string[] map, int col, int row)
        {
            return new Vector2(col + 0.5f, (map.Length - 1 - row) + 0.5f);
        }

        public static void ValidateAll()
        {
            Validate(Stadt, "Stadt");
            Validate(Weltkarte, "Weltkarte");
            Validate(Dungeon, "Dungeon");
        }

        private static void Validate(string[] map, string name)
        {
            if (map == null || map.Length == 0)
                throw new System.InvalidOperationException("Karte '" + name + "' ist leer.");

            int cols = map[0].Length;
            for (int row = 0; row < map.Length; row++)
            {
                if (map[row].Length != cols)
                {
                    throw new System.InvalidOperationException(
                        "Karte '" + name + "', Zeile " + row + ": Länge " + map[row].Length +
                        " statt " + cols + ". Alle Zeilen müssen gleich lang sein.");
                }
            }
        }
    }
}
