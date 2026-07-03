using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace RpgFable.EditorTools
{
    /// <summary>
    /// Erzeugt sämtliche Grafiken prozedural (Signed-Distance-Field-Rasterung)
    /// und speichert sie als PNG unter Assets/RpgFable/Sprites.
    /// Es werden keinerlei externe Bilddateien benötigt.
    /// </summary>
    public static class SpriteFactory
    {
        public const string Folder = "Assets/RpgFable/Sprites";
        private const int TileSize = 32;

        // ------------------------------------------------------------------
        // Einstiegspunkt
        // ------------------------------------------------------------------

        public static void GenerateAll()
        {
            MapLayouts.ValidateAll();
            Directory.CreateDirectory(Folder);

            // Karten (jede Karte wird als ein großes PNG zusammengesetzt)
            SavePng("map_stadt", ComposeMap(MapLayouts.Stadt));
            SavePng("map_weltkarte", ComposeMap(MapLayouts.Weltkarte));
            SavePng("map_dungeon", ComposeMap(MapLayouts.Dungeon));

            // Helden und NPCs
            SavePng("hero_aria", MakeCharacter(
                new Color(0.55f, 0.25f, 0.14f), new Color(0.26f, 0.38f, 0.62f), new Color(0.80f, 0.25f, 0.22f), CharStyle.Schwertkaempferin));
            SavePng("hero_milo", MakeCharacter(
                new Color(0.38f, 0.24f, 0.55f), new Color(0.32f, 0.22f, 0.48f), new Color(0.85f, 0.70f, 0.30f), CharStyle.Zauberer));
            SavePng("npc_aeltester", MakeCharacter(
                new Color(0.85f, 0.85f, 0.85f), new Color(0.45f, 0.36f, 0.26f), new Color(0.60f, 0.50f, 0.35f), CharStyle.Aeltester));
            SavePng("npc_priesterin", MakeCharacter(
                new Color(0.90f, 0.80f, 0.45f), new Color(0.92f, 0.92f, 0.95f), new Color(0.55f, 0.70f, 0.90f), CharStyle.Priesterin));
            SavePng("npc_haendlerin", MakeCharacter(
                new Color(0.35f, 0.22f, 0.12f), new Color(0.50f, 0.32f, 0.30f), new Color(0.85f, 0.75f, 0.40f), CharStyle.Haendlerin));

            // Gegner
            SavePng("enemy_schleim", MakeSlime());
            SavePng("enemy_fledermaus", MakeBat());
            SavePng("enemy_golem", MakeGolem());

            // UI und Kampf
            SavePng("ui_panel", MakeUiPanel());
            SavePng("cursor_pfeil", MakeCursor());
            SavePng("battle_hintergrund", MakeBattleBackground());

            AssetDatabase.Refresh();
            ConfigureImporters();
            Debug.Log("RPG Fable: Alle Grafiken wurden unter '" + Folder + "' erzeugt.");
        }

        // ------------------------------------------------------------------
        // Import-Einstellungen
        // ------------------------------------------------------------------

        private static void ConfigureImporters()
        {
            Configure("map_stadt", 32f, SpriteAlignment.BottomLeft, Vector4.zero);
            Configure("map_weltkarte", 32f, SpriteAlignment.BottomLeft, Vector4.zero);
            Configure("map_dungeon", 32f, SpriteAlignment.BottomLeft, Vector4.zero);

            Configure("hero_aria", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("hero_milo", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("npc_aeltester", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("npc_priesterin", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("npc_haendlerin", 32f, SpriteAlignment.Center, Vector4.zero);

            Configure("enemy_schleim", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("enemy_fledermaus", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("enemy_golem", 32f, SpriteAlignment.Center, Vector4.zero);

            Configure("ui_panel", 100f, SpriteAlignment.Center, new Vector4(12f, 12f, 12f, 12f));
            Configure("cursor_pfeil", 32f, SpriteAlignment.Center, Vector4.zero);
            Configure("battle_hintergrund", 30f, SpriteAlignment.Center, Vector4.zero);
        }

        private static void Configure(string name, float pixelsPerUnit, SpriteAlignment alignment, Vector4 border)
        {
            string path = Folder + "/" + name + ".png";
            var importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer == null)
            {
                Debug.LogWarning("RPG Fable: Importer für " + path + " nicht gefunden.");
                return;
            }

            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = pixelsPerUnit;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.mipmapEnabled = false;
            importer.alphaIsTransparency = true;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.spriteBorder = border;

            var settings = new TextureImporterSettings();
            importer.ReadTextureSettings(settings);
            settings.spriteAlignment = (int)alignment;
            settings.spriteMeshType = SpriteMeshType.FullRect;
            importer.SetTextureSettings(settings);

            importer.SaveAndReimport();
        }

        // ------------------------------------------------------------------
        // PNG-Ausgabe
        // ------------------------------------------------------------------

        private static void SavePng(string name, Raster raster)
        {
            var texture = new Texture2D(raster.W, raster.H, TextureFormat.RGBA32, false);
            texture.SetPixels(raster.Px);
            texture.Apply();
            byte[] bytes = ImageConversion.EncodeToPNG(texture);
            UnityEngine.Object.DestroyImmediate(texture);
            File.WriteAllBytes(Folder + "/" + name + ".png", bytes);
        }

        // ------------------------------------------------------------------
        // Raster mit SDF-Zeichnen
        // ------------------------------------------------------------------

        private class Raster
        {
            public readonly int W;
            public readonly int H;
            public readonly Color[] Px;

            public Raster(int w, int h, Color background)
            {
                W = w;
                H = h;
                Px = new Color[w * h];
                for (int i = 0; i < Px.Length; i++) Px[i] = background;
            }

            public void Blend(int x, int y, Color c, float a)
            {
                if (x < 0 || y < 0 || x >= W || y >= H || a <= 0f) return;
                int i = y * W + x;
                Color d = Px[i];
                float outA = a + d.a * (1f - a);
                if (outA <= 0.0001f)
                {
                    Px[i] = Color.clear;
                    return;
                }
                Px[i] = new Color(
                    (c.r * a + d.r * d.a * (1f - a)) / outA,
                    (c.g * a + d.g * d.a * (1f - a)) / outA,
                    (c.b * a + d.b * d.a * (1f - a)) / outA,
                    outA);
            }

            /// <summary>Füllt alle Pixel mit sdf &lt; 0 (weiche Kante über 1 px).</summary>
            public void Fill(Func<Vector2, float> sdf, Color c)
            {
                for (int y = 0; y < H; y++)
                {
                    for (int x = 0; x < W; x++)
                    {
                        float d = sdf(new Vector2(x + 0.5f, y + 0.5f));
                        float a = Mathf.Clamp01(0.5f - d) * c.a;
                        if (a > 0f) Blend(x, y, c, a);
                    }
                }
            }

            /// <summary>Deterministisches Pixelrauschen (z. B. Grasstruktur).</summary>
            public void Noise(int seed, float density, Color c)
            {
                Noise(seed, density, c, 0, H);
            }

            public void Noise(int seed, float density, Color c, int yMin, int yMax)
            {
                for (int y = Mathf.Max(0, yMin); y < Mathf.Min(H, yMax); y++)
                {
                    for (int x = 0; x < W; x++)
                    {
                        if (Hash01(x, y, seed) < density) Blend(x, y, c, c.a);
                    }
                }
            }

            public void Blit(Raster src, int offsetX, int offsetY)
            {
                for (int y = 0; y < src.H; y++)
                {
                    for (int x = 0; x < src.W; x++)
                    {
                        Color p = src.Px[y * src.W + x];
                        if (p.a > 0f) Blend(offsetX + x, offsetY + y, p, p.a);
                    }
                }
            }
        }

        private static float Hash01(int x, int y, int seed)
        {
            unchecked
            {
                uint h = (uint)(x * 374761393 + y * 668265263 + seed * 974634541);
                h = (h ^ (h >> 13)) * 1274126177u;
                return ((h >> 8) & 0xFFFF) / 65535f;
            }
        }

        private static Color Shade(Color c, float factor)
        {
            return new Color(Mathf.Clamp01(c.r * factor), Mathf.Clamp01(c.g * factor), Mathf.Clamp01(c.b * factor), c.a);
        }

        // ------------------------------------------------------------------
        // SDF-Grundformen
        // ------------------------------------------------------------------

        private static Func<Vector2, float> Circle(float cx, float cy, float radius)
        {
            return p => Vector2.Distance(p, new Vector2(cx, cy)) - radius;
        }

        private static Func<Vector2, float> Ellipse(float cx, float cy, float rx, float ry)
        {
            return p =>
            {
                float dx = (p.x - cx) / rx;
                float dy = (p.y - cy) / ry;
                return (Mathf.Sqrt(dx * dx + dy * dy) - 1f) * Mathf.Min(rx, ry);
            };
        }

        private static Func<Vector2, float> Box(float cx, float cy, float halfW, float halfH, float round)
        {
            return p =>
            {
                float qx = Mathf.Abs(p.x - cx) - halfW + round;
                float qy = Mathf.Abs(p.y - cy) - halfH + round;
                float ox = Mathf.Max(qx, 0f);
                float oy = Mathf.Max(qy, 0f);
                return Mathf.Sqrt(ox * ox + oy * oy) + Mathf.Min(Mathf.Max(qx, qy), 0f) - round;
            };
        }

        private static Func<Vector2, float> Seg(float ax, float ay, float bx, float by, float radius)
        {
            return p =>
            {
                var a = new Vector2(ax, ay);
                var b = new Vector2(bx, by);
                Vector2 pa = p - a;
                Vector2 ba = b - a;
                float h = Mathf.Clamp01(Vector2.Dot(pa, ba) / Mathf.Max(0.0001f, Vector2.Dot(ba, ba)));
                return (pa - ba * h).magnitude - radius;
            };
        }

        private static Func<Vector2, float> Tri(float ax, float ay, float bx, float by, float cx, float cy)
        {
            return p =>
            {
                var p0 = new Vector2(ax, ay);
                var p1 = new Vector2(bx, by);
                var p2 = new Vector2(cx, cy);
                Vector2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
                Vector2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
                Vector2 pq0 = v0 - e0 * Mathf.Clamp01(Vector2.Dot(v0, e0) / Mathf.Max(0.0001f, e0.sqrMagnitude));
                Vector2 pq1 = v1 - e1 * Mathf.Clamp01(Vector2.Dot(v1, e1) / Mathf.Max(0.0001f, e1.sqrMagnitude));
                Vector2 pq2 = v2 - e2 * Mathf.Clamp01(Vector2.Dot(v2, e2) / Mathf.Max(0.0001f, e2.sqrMagnitude));
                float s = Mathf.Sign(e0.x * e2.y - e0.y * e2.x);
                float dx = Mathf.Min(Mathf.Min(pq0.sqrMagnitude, pq1.sqrMagnitude), pq2.sqrMagnitude);
                float dy = Mathf.Min(Mathf.Min(
                    s * (v0.x * e0.y - v0.y * e0.x),
                    s * (v1.x * e1.y - v1.y * e1.x)),
                    s * (v2.x * e2.y - v2.y * e2.x));
                return -Mathf.Sqrt(dx) * Mathf.Sign(dy);
            };
        }

        // ------------------------------------------------------------------
        // Kacheln
        // ------------------------------------------------------------------

        private static Raster ComposeMap(string[] layout)
        {
            int rows = layout.Length;
            int cols = layout[0].Length;
            var map = new Raster(cols * TileSize, rows * TileSize, Color.clear);

            for (int row = 0; row < rows; row++)
            {
                for (int col = 0; col < cols; col++)
                {
                    int seed = col * 73856093 ^ row * 19349663;
                    Raster tile = MakeTile(layout[row][col], seed);
                    map.Blit(tile, col * TileSize, (rows - 1 - row) * TileSize);
                }
            }
            return map;
        }

        private static Raster MakeTile(char c, int seed)
        {
            switch (c)
            {
                case 'G': return GrassTile(seed, new Color(0.33f, 0.52f, 0.27f));
                case 'F': return FlowerTile(seed);
                case 'P': return PathTile(seed);
                case 'W': return WaterTile(seed, new Color(0.25f, 0.45f, 0.70f));
                case 'T': return TreeTile(seed);
                case 'r': return RoofTile();
                case 'w': return WallTile();
                case 'd': return DoorTile();
                case 'g': return GrassTile(seed, new Color(0.47f, 0.62f, 0.34f));
                case 'f': return ForestTile(seed);
                case 'M': return MountainTile(seed);
                case 'V': return WaterTile(seed, new Color(0.18f, 0.36f, 0.62f));
                case 'C': return TownIconTile(seed);
                case 'D': return DungeonIconTile(seed);
                case '#': return CaveWallTile(seed);
                case '.': return CaveFloorTile(seed);
                case 'o': return BoulderTile(seed);
                default: return GrassTile(seed, new Color(0.33f, 0.52f, 0.27f));
            }
        }

        private static Raster GrassTile(int seed, Color baseColor)
        {
            var r = new Raster(TileSize, TileSize, baseColor);
            r.Noise(seed, 0.20f, Shade(baseColor, 0.85f));
            r.Noise(seed + 7, 0.10f, Shade(baseColor, 1.15f));
            return r;
        }

        private static Raster FlowerTile(int seed)
        {
            var r = GrassTile(seed, new Color(0.33f, 0.52f, 0.27f));
            Color[] petals =
            {
                new Color(0.95f, 0.55f, 0.65f),
                new Color(0.95f, 0.90f, 0.50f),
                new Color(0.92f, 0.92f, 0.95f)
            };
            for (int k = 0; k < 3; k++)
            {
                float fx = 5f + Hash01(k, 7, seed) * 22f;
                float fy = 5f + Hash01(k, 11, seed) * 22f;
                Color petal = petals[(int)(Hash01(k, 13, seed) * 2.99f)];
                r.Fill(Circle(fx, fy, 1.7f), petal);
                r.Fill(Circle(fx, fy, 0.7f), new Color(0.95f, 0.75f, 0.25f));
            }
            return r;
        }

        private static Raster PathTile(int seed)
        {
            var r = new Raster(TileSize, TileSize, new Color(0.72f, 0.63f, 0.44f));
            r.Noise(seed, 0.25f, new Color(0.64f, 0.55f, 0.37f));
            r.Noise(seed + 3, 0.12f, new Color(0.79f, 0.71f, 0.52f));
            return r;
        }

        private static Raster WaterTile(int seed, Color baseColor)
        {
            var r = new Raster(TileSize, TileSize, baseColor);
            r.Noise(seed, 0.10f, Shade(baseColor, 0.9f));
            Color wave = new Color(0.60f, 0.76f, 0.92f, 0.65f);
            float y1 = 7f + Hash01(1, 2, seed) * 6f;
            float y2 = 19f + Hash01(3, 4, seed) * 6f;
            r.Fill(Seg(6f, y1, 14f, y1, 0.8f), wave);
            r.Fill(Seg(18f, y2, 26f, y2, 0.8f), wave);
            return r;
        }

        private static Raster TreeTile(int seed)
        {
            var r = GrassTile(seed, new Color(0.33f, 0.52f, 0.27f));
            float ox = (Hash01(5, 9, seed) - 0.5f) * 3f;
            r.Fill(Box(16f + ox, 8f, 2.2f, 4.5f, 1f), new Color(0.42f, 0.29f, 0.17f));
            r.Fill(Circle(16f + ox, 18f, 9.5f), new Color(0.16f, 0.35f, 0.17f));
            r.Fill(Circle(13f + ox, 21f, 4.8f), new Color(0.22f, 0.44f, 0.22f));
            r.Fill(Circle(20f + ox, 16f, 4.2f), new Color(0.19f, 0.40f, 0.20f));
            return r;
        }

        private static Raster RoofTile()
        {
            Color baseColor = new Color(0.63f, 0.29f, 0.23f);
            var r = new Raster(TileSize, TileSize, baseColor);
            for (int ly = 5; ly < 32; ly += 8)
            {
                r.Fill(Box(16f, ly, 16f, 1.0f, 0f), Shade(baseColor, 0.82f));
            }
            r.Fill(Box(16f, 31f, 16f, 1.0f, 0f), Shade(baseColor, 1.12f));
            return r;
        }

        private static Raster WallTile()
        {
            Color baseColor = new Color(0.84f, 0.77f, 0.62f);
            Color beam = new Color(0.45f, 0.33f, 0.22f);
            var r = new Raster(TileSize, TileSize, baseColor);
            r.Fill(Box(16f, 1.5f, 16f, 1.6f, 0f), beam);
            r.Fill(Box(16f, 30.5f, 16f, 1.6f, 0f), beam);
            r.Fill(Box(1.5f, 16f, 1.6f, 16f, 0f), beam);
            r.Fill(Box(30.5f, 16f, 1.6f, 16f, 0f), beam);
            r.Fill(Box(16f, 16f, 16f, 1.1f, 0f), Shade(beam, 1.1f));
            return r;
        }

        private static Raster DoorTile()
        {
            var r = WallTile();
            Color frame = new Color(0.30f, 0.20f, 0.11f);
            Color door = new Color(0.42f, 0.27f, 0.14f);
            r.Fill(Box(16f, 9.5f, 6.4f, 9.6f, 3f), frame);
            r.Fill(Box(16f, 5f, 6.4f, 5f, 0f), frame);
            r.Fill(Box(16f, 9f, 5.4f, 8.6f, 2.5f), door);
            r.Fill(Box(16f, 4.5f, 5.4f, 4.5f, 0f), door);
            r.Fill(Circle(19.5f, 9f, 1.0f), new Color(0.85f, 0.72f, 0.32f));
            return r;
        }

        private static Raster ForestTile(int seed)
        {
            var r = GrassTile(seed, new Color(0.47f, 0.62f, 0.34f));
            r.Fill(Box(16f, 6f, 1.6f, 2.5f, 0.5f), new Color(0.38f, 0.26f, 0.15f));
            r.Fill(Circle(16f, 16f, 11f), new Color(0.20f, 0.40f, 0.22f));
            r.Fill(Circle(10f, 20f, 6f), new Color(0.24f, 0.46f, 0.25f));
            r.Fill(Circle(22f, 20f, 6f), new Color(0.22f, 0.43f, 0.23f));
            r.Fill(Circle(16f, 22f, 5f), new Color(0.26f, 0.49f, 0.27f));
            return r;
        }

        private static Raster MountainTile(int seed)
        {
            var r = GrassTile(seed, new Color(0.47f, 0.62f, 0.34f));
            r.Fill(Tri(2f, 3f, 30f, 3f, 16f, 30f), new Color(0.52f, 0.49f, 0.46f));
            r.Fill(Tri(2f, 3f, 16f, 30f, 9f, 3f), new Color(0.44f, 0.41f, 0.39f));
            r.Fill(Tri(12.5f, 20f, 19.5f, 20f, 16f, 29.5f), new Color(0.90f, 0.92f, 0.95f));
            return r;
        }

        private static Raster TownIconTile(int seed)
        {
            var r = GrassTile(seed, new Color(0.47f, 0.62f, 0.34f));
            r.Fill(Box(16f, 9f, 7f, 5.5f, 1f), new Color(0.88f, 0.82f, 0.68f));
            r.Fill(Tri(6f, 13.5f, 26f, 13.5f, 16f, 25f), new Color(0.65f, 0.28f, 0.22f));
            r.Fill(Box(16f, 6f, 2f, 3f, 0.5f), new Color(0.40f, 0.27f, 0.15f));
            r.Fill(Box(11f, 9.5f, 1.5f, 1.5f, 0.3f), new Color(0.35f, 0.55f, 0.75f));
            r.Fill(Box(21f, 9.5f, 1.5f, 1.5f, 0.3f), new Color(0.35f, 0.55f, 0.75f));
            return r;
        }

        private static Raster DungeonIconTile(int seed)
        {
            Color rock = new Color(0.45f, 0.43f, 0.41f);
            var r = new Raster(TileSize, TileSize, rock);
            r.Noise(seed, 0.20f, Shade(rock, 0.85f));
            r.Fill(Circle(16f, 12f, 9.5f), new Color(0.32f, 0.30f, 0.29f));
            r.Fill(Box(16f, 6.5f, 9.5f, 4.8f, 0f), new Color(0.32f, 0.30f, 0.29f));
            r.Fill(Circle(16f, 11f, 7.5f), new Color(0.05f, 0.05f, 0.07f));
            r.Fill(Box(16f, 6f, 7.5f, 4.3f, 0f), new Color(0.05f, 0.05f, 0.07f));
            return r;
        }

        private static Raster CaveWallTile(int seed)
        {
            Color baseColor = new Color(0.15f, 0.13f, 0.13f);
            var r = new Raster(TileSize, TileSize, baseColor);
            r.Noise(seed, 0.22f, new Color(0.19f, 0.16f, 0.15f));
            for (int k = 0; k < 3; k++)
            {
                float rx = 4f + Hash01(k, 17, seed) * 24f;
                float ry = 4f + Hash01(k, 23, seed) * 24f;
                r.Fill(Circle(rx, ry, 3.2f + Hash01(k, 29, seed) * 1.5f), new Color(0.21f, 0.18f, 0.17f));
            }
            return r;
        }

        private static Raster CaveFloorTile(int seed)
        {
            Color baseColor = new Color(0.33f, 0.29f, 0.27f);
            var r = new Raster(TileSize, TileSize, baseColor);
            r.Noise(seed, 0.22f, new Color(0.28f, 0.24f, 0.23f));
            r.Noise(seed + 5, 0.10f, new Color(0.38f, 0.34f, 0.31f));
            return r;
        }

        private static Raster BoulderTile(int seed)
        {
            var r = CaveFloorTile(seed);
            r.Fill(Ellipse(16f, 9f, 9.5f, 3f), new Color(0f, 0f, 0f, 0.35f));
            r.Fill(Circle(16f, 16f, 8.8f), new Color(0.48f, 0.46f, 0.44f));
            r.Fill(Circle(13f, 19f, 3.2f), new Color(0.58f, 0.56f, 0.53f));
            r.Fill(Seg(14f, 11f, 19.5f, 16.5f, 0.5f), new Color(0.36f, 0.34f, 0.32f));
            return r;
        }

        // ------------------------------------------------------------------
        // Figuren
        // ------------------------------------------------------------------

        private enum CharStyle { Schwertkaempferin, Zauberer, Aeltester, Priesterin, Haendlerin }

        private static Raster MakeCharacter(Color hair, Color outfit, Color accent, CharStyle style)
        {
            var r = new Raster(32, 32, Color.clear);
            Color skin = new Color(0.96f, 0.80f, 0.66f);
            Color dark = new Color(0.15f, 0.12f, 0.12f);

            // Bodenschatten
            r.Fill(Ellipse(16f, 3.5f, 9f, 2.6f), new Color(0f, 0f, 0f, 0.28f));

            // Beine
            Color legs = Shade(outfit, 0.55f);
            r.Fill(Box(13f, 6f, 2.1f, 3.2f, 1f), legs);
            r.Fill(Box(19f, 6f, 2.1f, 3.2f, 1f), legs);

            // Körper und Arme
            r.Fill(Box(16f, 12.5f, 6f, 5.3f, 2.5f), outfit);
            r.Fill(Box(16f, 9.8f, 5.6f, 1.1f, 0.5f), Shade(outfit, 0.5f));
            r.Fill(Box(9f, 12.5f, 1.8f, 3.8f, 1.2f), Shade(outfit, 0.8f));
            r.Fill(Box(23f, 12.5f, 1.8f, 3.8f, 1.2f), Shade(outfit, 0.8f));

            // Kopf
            r.Fill(Circle(16f, 22.5f, 7.2f), hair);
            r.Fill(Circle(16f, 21f, 5.6f), skin);
            r.Fill(Box(16f, 25.4f, 5.6f, 2.1f, 1.5f), hair);
            r.Fill(Box(13.7f, 20.2f, 0.8f, 1.1f, 0.3f), dark);
            r.Fill(Box(18.3f, 20.2f, 0.8f, 1.1f, 0.3f), dark);

            switch (style)
            {
                case CharStyle.Schwertkaempferin:
                    // Zopf
                    r.Fill(Circle(22.5f, 26.5f, 2.6f), hair);
                    r.Fill(Ellipse(23.5f, 22f, 1.6f, 3.4f), hair);
                    // Schwert an der Seite
                    r.Fill(Seg(27f, 6f, 27f, 15f, 1.1f), new Color(0.78f, 0.80f, 0.85f));
                    r.Fill(Box(27f, 15.6f, 2.4f, 0.7f, 0.3f), new Color(0.45f, 0.35f, 0.20f));
                    r.Fill(Seg(27f, 16f, 27f, 18.5f, 0.9f), new Color(0.35f, 0.25f, 0.15f));
                    // Schärpe
                    r.Fill(Box(16f, 16.4f, 4.6f, 1.2f, 0.6f), accent);
                    break;

                case CharStyle.Zauberer:
                    // Spitzhut mit Krempe
                    r.Fill(Ellipse(16f, 24.5f, 9.5f, 2.4f), Shade(hair, 0.9f));
                    r.Fill(Tri(9.5f, 24.5f, 22.5f, 24.5f, 17.5f, 32f), hair);
                    // Stab mit leuchtender Kugel
                    r.Fill(Seg(6.5f, 4f, 6.5f, 17f, 1.0f), new Color(0.45f, 0.31f, 0.18f));
                    r.Fill(Circle(6.5f, 19f, 2.2f), new Color(0.45f, 0.85f, 0.95f));
                    r.Fill(Circle(5.8f, 19.7f, 0.8f), new Color(0.85f, 0.98f, 1f));
                    // Robensaum
                    r.Fill(Box(16f, 7.6f, 6f, 1.2f, 0.5f), accent);
                    break;

                case CharStyle.Aeltester:
                    r.Fill(Ellipse(16f, 17.6f, 3.4f, 2.4f), new Color(0.88f, 0.88f, 0.88f));
                    r.Fill(Seg(25f, 4f, 25f, 16f, 0.9f), new Color(0.50f, 0.38f, 0.22f));
                    break;

                case CharStyle.Priesterin:
                    r.Fill(Box(16f, 26.8f, 5.2f, 0.8f, 0.4f), accent);
                    r.Fill(Box(16f, 16.4f, 4.2f, 1.0f, 0.5f), new Color(0.95f, 0.95f, 0.98f));
                    break;

                case CharStyle.Haendlerin:
                    r.Fill(Box(16f, 11.5f, 3.8f, 3.6f, 1.2f), accent);
                    r.Fill(Box(16f, 15.2f, 2.6f, 0.8f, 0.4f), Shade(accent, 0.8f));
                    break;
            }
            return r;
        }

        // ------------------------------------------------------------------
        // Gegner
        // ------------------------------------------------------------------

        private static Raster MakeSlime()
        {
            var r = new Raster(48, 48, Color.clear);
            Color body = new Color(0.30f, 0.66f, 0.32f);
            Color dark = new Color(0.10f, 0.22f, 0.10f);

            r.Fill(Ellipse(24f, 6f, 15f, 3.4f), new Color(0f, 0f, 0f, 0.30f));
            r.Fill(Ellipse(24f, 14f, 17f, 8f), Shade(body, 0.88f));
            r.Fill(Ellipse(24f, 20f, 14.5f, 12.5f), body);
            r.Fill(Ellipse(17.5f, 26f, 4.6f, 3.2f), new Color(0.62f, 0.90f, 0.55f, 0.9f));
            r.Fill(Circle(19f, 19f, 2.1f), dark);
            r.Fill(Circle(29f, 19f, 2.1f), dark);
            r.Fill(Circle(19.7f, 19.7f, 0.7f), Color.white);
            r.Fill(Circle(29.7f, 19.7f, 0.7f), Color.white);
            r.Fill(Seg(21.5f, 13.5f, 26.5f, 13.5f, 0.9f), Shade(body, 0.45f));
            return r;
        }

        private static Raster MakeBat()
        {
            var r = new Raster(48, 48, Color.clear);
            Color body = new Color(0.36f, 0.26f, 0.48f);
            Color wing = Shade(body, 0.72f);

            r.Fill(Tri(2f, 30f, 17f, 27f, 13f, 14f), wing);
            r.Fill(Tri(46f, 30f, 31f, 27f, 35f, 14f), wing);
            r.Fill(Tri(18f, 28f, 22f, 29f, 18.5f, 35f), body);
            r.Fill(Tri(26f, 29f, 30f, 28f, 29.5f, 35f), body);
            r.Fill(Circle(24f, 23f, 8.5f), body);
            r.Fill(Circle(20.8f, 24f, 1.7f), new Color(0.95f, 0.25f, 0.25f));
            r.Fill(Circle(27.2f, 24f, 1.7f), new Color(0.95f, 0.25f, 0.25f));
            r.Fill(Tri(21f, 17f, 23f, 17f, 22f, 14f), Color.white);
            r.Fill(Tri(25f, 17f, 27f, 17f, 26f, 14f), Color.white);
            return r;
        }

        private static Raster MakeGolem()
        {
            var r = new Raster(48, 48, Color.clear);
            Color stone = new Color(0.50f, 0.48f, 0.45f);

            r.Fill(Ellipse(24f, 5f, 16f, 3.2f), new Color(0f, 0f, 0f, 0.30f));
            r.Fill(Box(18f, 7f, 3.4f, 3.4f, 1f), Shade(stone, 0.7f));
            r.Fill(Box(30f, 7f, 3.4f, 3.4f, 1f), Shade(stone, 0.7f));
            r.Fill(Box(8.5f, 18f, 3.6f, 8f, 2f), Shade(stone, 0.8f));
            r.Fill(Box(39.5f, 18f, 3.6f, 8f, 2f), Shade(stone, 0.8f));
            r.Fill(Box(24f, 18f, 11.5f, 10f, 3f), stone);
            r.Fill(Box(24f, 32.5f, 7f, 5f, 2f), Shade(stone, 1.08f));
            r.Fill(Box(21f, 32.5f, 1.6f, 1.1f, 0.4f), new Color(1f, 0.62f, 0.15f));
            r.Fill(Box(27f, 32.5f, 1.6f, 1.1f, 0.4f), new Color(1f, 0.62f, 0.15f));
            r.Fill(Seg(18f, 14f, 22f, 18f, 0.5f), Shade(stone, 0.5f));
            r.Fill(Seg(28f, 22f, 31f, 18f, 0.5f), Shade(stone, 0.5f));
            r.Fill(Circle(31f, 12f, 3f), new Color(0.30f, 0.50f, 0.28f, 0.75f));
            return r;
        }

        // ------------------------------------------------------------------
        // UI und Kampfhintergrund
        // ------------------------------------------------------------------

        private static Raster MakeUiPanel()
        {
            var r = new Raster(48, 48, Color.clear);
            r.Fill(Box(24f, 24f, 23f, 23f, 7f), new Color(0.80f, 0.76f, 0.64f));
            r.Fill(Box(24f, 24f, 21f, 21f, 5.5f), new Color(0.35f, 0.33f, 0.28f));
            r.Fill(Box(24f, 24f, 20f, 20f, 5f), new Color(0.07f, 0.08f, 0.15f, 0.94f));
            return r;
        }

        private static Raster MakeCursor()
        {
            var r = new Raster(16, 16, Color.clear);
            r.Fill(Tri(2.5f, 13.5f, 13.5f, 13.5f, 8f, 3f), new Color(0.25f, 0.18f, 0.05f));
            r.Fill(Tri(4f, 12.5f, 12f, 12.5f, 8f, 4.8f), new Color(1f, 0.85f, 0.25f));
            return r;
        }

        private static Raster MakeBattleBackground()
        {
            int w = 480, h = 270;
            var r = new Raster(w, h, Color.clear);

            // Höhlen-Farbverlauf (unten wärmer, oben dunkler)
            Color top = new Color(0.05f, 0.06f, 0.11f);
            Color bottom = new Color(0.15f, 0.11f, 0.19f);
            for (int y = 0; y < h; y++)
            {
                Color c = Color.Lerp(bottom, top, y / (float)(h - 1));
                for (int x = 0; x < w; x++) r.Blend(x, y, c, 1f);
            }

            // Stalaktiten
            for (int k = 0; k < 6; k++)
            {
                float x = 35f + k * 78f + (Hash01(k, 3, 99) - 0.5f) * 30f;
                float length = 35f + Hash01(k, 5, 99) * 30f;
                r.Fill(Tri(x - 15f, h, x + 15f, h, x, h - length), new Color(0.09f, 0.08f, 0.13f));
            }

            // Ferne Felsen
            for (int k = 0; k < 7; k++)
            {
                float x = 20f + k * 70f + Hash01(k, 7, 42) * 40f;
                float radius = 18f + Hash01(k, 11, 42) * 16f;
                r.Fill(Circle(x, 100f, radius), new Color(0.13f, 0.11f, 0.16f));
            }

            // Leuchtender Kristall links
            r.Fill(Circle(90f, 150f, 26f), new Color(0.45f, 0.75f, 0.95f, 0.12f));
            r.Fill(Tri(80f, 138f, 100f, 138f, 90f, 178f), new Color(0.55f, 0.85f, 0.98f, 0.85f));
            r.Fill(Tri(84f, 138f, 96f, 138f, 90f, 118f), new Color(0.45f, 0.72f, 0.90f, 0.85f));

            // Boden
            r.Fill(Box(240f, 45f, 250f, 52f, 8f), new Color(0.28f, 0.23f, 0.21f));
            r.Noise(31, 0.18f, new Color(0.24f, 0.19f, 0.18f), 0, 95);
            r.Noise(37, 0.08f, new Color(0.33f, 0.27f, 0.25f), 0, 95);

            return r;
        }
    }
}
