using System.IO;
using UnityEditor;
using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Procedurally paints every sprite the game needs (ground tiles, heroes, NPCs,
    /// enemies, a UI panel) using signed-distance-field shapes, so no external art
    /// has to be downloaded. Run via "RPG Spiel/1. Bilder erzeugen".
    /// </summary>
    public static class RpgTextureGenerator
    {
        private const int Size = 128;
        private const string TileFolder = "Assets/Sprites/Tiles";
        private const string CharFolder = "Assets/Sprites/Characters";
        private const string UiFolder = "Assets/Sprites/UI";

        [MenuItem("RPG Spiel/1. Bilder erzeugen")]
        public static void GenerateAll()
        {
            EnsureFolder(TileFolder);
            EnsureFolder(CharFolder);
            EnsureFolder(UiFolder);

            GenerateGrass();
            GeneratePath();
            GenerateWater();
            GenerateMountain();
            GenerateHedge();
            GenerateDungeonFloor();
            GenerateDungeonWall();

            GenerateHumanoid(CharFolder + "/Char_Aria.png", Hex("#B8C4D6"), Hex("#3A2A20"), Hex("#F2C9A0"), Hex("#221A16"), Hex("#8A5A2B"), 'S');
            GenerateHumanoid(CharFolder + "/Char_Elan.png", Hex("#5B3FA0"), Hex("#1E1B2E"), Hex("#F2C9A0"), Hex("#221A16"), Hex("#FFD54F"), 'T');
            GenerateHumanoid(CharFolder + "/Npc_Elder.png", Hex("#8A7B63"), Hex("#D9D9D9"), Hex("#EAC9A0"), Hex("#221A16"), Hex("#6B4A2B"), 'C');
            GenerateHumanoid(CharFolder + "/Npc_Guard.png", Hex("#5C6B73"), Hex("#4A3324"), Hex("#EAC9A0"), Hex("#221A16"), Hex("#6B7280"), 'P');
            GenerateHumanoid(CharFolder + "/Npc_Shopkeeper.png", Hex("#C97A4A"), Hex("#7A2E2E"), Hex("#F2C9A0"), Hex("#221A16"), Hex("#E8C36B"), 'A');
            GenerateHumanoid(CharFolder + "/Enemy_Wolf.png", Hex("#6B5A4A"), Hex("#5A4A3B"), Hex("#5A4A3B"), Hex("#C0392B"), Hex("#3E332A"), 'E');
            GenerateHumanoid(CharFolder + "/Enemy_Bat.png", Hex("#3B2E4A"), Hex("#2E2340"), Hex("#2E2340"), Hex("#E74C3C"), Hex("#241C33"), 'W');
            GenerateSlime(CharFolder + "/Enemy_Slime.png");

            GenerateUiPanel();

            AssetDatabase.Refresh();
            ConfigureFolderAsSprites(TileFolder, false);
            ConfigureFolderAsSprites(CharFolder, false);
            ConfigureFolderAsSprites(UiFolder, true);

            Debug.Log("RPG Spiel: Alle Bilder wurden erzeugt.");
        }

        // ---------- tiles ----------

        private static void GenerateGrass()
        {
            RenderSprite(TileFolder + "/Tile_Grass.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#5B9A4B"), Hex("#3E7A34"));
                float speckle = Mathf.Abs(Mathf.Sin(p.x * 26f) * Mathf.Cos(p.y * 22f));
                if (speckle > 0.93f) c = Color.Lerp(c, Hex("#2E5C27"), 0.4f);
                return c;
            });
        }

        private static void GeneratePath()
        {
            RenderSprite(TileFolder + "/Tile_Path.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#D8C08A"), Hex("#BE9F66"));
                float speckle = Mathf.Abs(Mathf.Sin(p.x * 19f + 1.7f) * Mathf.Sin(p.y * 17f));
                if (speckle > 0.9f) c = Color.Lerp(c, Hex("#9C7C48"), 0.35f);
                return c;
            });
        }

        private static void GenerateWater()
        {
            RenderSprite(TileFolder + "/Tile_Water.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#5AA9D6"), Hex("#2E6FA3"));
                float wave = Mathf.Abs(Mathf.Sin((p.x * 6f) + (p.y * 10f)));
                if (wave > 0.88f) c = Color.Lerp(c, Hex("#BFE4F7"), 0.35f);
                return c;
            });
        }

        private static void GenerateMountain()
        {
            RenderSprite(TileFolder + "/Tile_Mountain.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#8C8B8E"), Hex("#5C5B60"));
                float aa = 2.2f / Size;
                Paint(ref c, Sdf.RoundedBox(p - new Vector2(0f, -0.55f), new Vector2(0.55f, 0.30f), 0.10f), Hex("#4A4A4E"), aa);
                Paint(ref c, Sdf.Segment(p, new Vector2(-0.35f, -0.55f), new Vector2(0f, 0.45f), 0.02f), Hex("#3C3C40"), aa * 2f);
                Paint(ref c, Sdf.Segment(p, new Vector2(0f, 0.45f), new Vector2(0.4f, -0.55f), 0.02f), Hex("#3C3C40"), aa * 2f);
                Paint(ref c, Sdf.Ellipse(p - new Vector2(0f, 0.40f), 0.15f, 0.11f), Hex("#EDEFF2"), aa);
                return c;
            });
        }

        private static void GenerateHedge()
        {
            RenderSprite(TileFolder + "/Tile_Hedge.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#3A6B34"), Hex("#254A20"));
                float aa = 2.2f / Size;
                Paint(ref c, Sdf.Circle(p - new Vector2(-0.28f, 0.18f), 0.30f), Hex("#4C8A44"), aa);
                Paint(ref c, Sdf.Circle(p - new Vector2(0.30f, 0.10f), 0.32f), Hex("#4C8A44"), aa);
                Paint(ref c, Sdf.Circle(p - new Vector2(0.0f, -0.30f), 0.34f), Hex("#3E7838"), aa);
                return c;
            });
        }

        private static void GenerateDungeonFloor()
        {
            RenderSprite(TileFolder + "/Tile_DungeonFloor.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#4A4750"), Hex("#332F38"));
                float aa = 2.2f / Size;
                float crackA = Mathf.Abs(p.x - 0.02f * Mathf.Sin(p.y * 5f));
                if (crackA < 0.012f) c = Color.Lerp(c, Hex("#231F28"), 0.6f);
                float crackB = Mathf.Abs(p.y - 0.35f);
                if (crackB < 0.01f) c = Color.Lerp(c, Hex("#231F28"), 0.5f);
                return c;
            });
        }

        private static void GenerateDungeonWall()
        {
            RenderSprite(TileFolder + "/Tile_DungeonWall.png", p =>
            {
                Color c = VerticalGradient(p, Hex("#26232C"), Hex("#141218"));
                float brickX = Mathf.Repeat(p.x + (Mathf.Floor((p.y + 1f) * 2f) % 2f == 0f ? 0f : 0.25f), 0.5f);
                float brickY = Mathf.Repeat(p.y + 1f, 0.5f);
                if (brickX < 0.03f || brickY < 0.03f) c = Color.Lerp(c, Hex("#0C0A0F"), 0.7f);
                return c;
            });
        }

        // ---------- characters ----------

        private static void GenerateHumanoid(string path, Color body, Color hair, Color head, Color eyes, Color accent, char accessory)
        {
            RenderSprite(path, p =>
            {
                Color result = new Color(0f, 0f, 0f, 0f);
                float aa = 2.2f / Size;

                Paint(ref result, Sdf.Ellipse(p - new Vector2(0f, -0.86f), 0.30f, 0.08f), new Color(0f, 0f, 0f, 0.28f), aa);
                Paint(ref result, Sdf.RoundedBox(p - new Vector2(0f, -0.16f), new Vector2(0.28f, 0.36f), 0.16f), body, aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(0f, 0.46f), 0.21f), hair, aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(0f, 0.39f), 0.23f), head, aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(-0.08f, 0.39f), 0.032f), eyes, aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(0.08f, 0.39f), 0.032f), eyes, aa);

                switch (accessory)
                {
                    case 'S':
                        Paint(ref result, Sdf.Segment(p, new Vector2(0.28f, -0.06f), new Vector2(0.50f, 0.56f), 0.035f), Hex("#E4E8EE"), aa);
                        Paint(ref result, Sdf.Segment(p, new Vector2(0.22f, -0.16f), new Vector2(0.34f, -0.02f), 0.05f), accent, aa);
                        break;
                    case 'T':
                        Paint(ref result, Sdf.Segment(p, new Vector2(0.32f, -0.32f), new Vector2(0.32f, 0.52f), 0.035f), Hex("#6B4A2B"), aa);
                        Paint(ref result, Sdf.Star5(p - new Vector2(0.32f, 0.58f), 0.12f, 0.05f), accent, aa);
                        break;
                    case 'C':
                        Paint(ref result, Sdf.Segment(p, new Vector2(0.26f, -0.32f), new Vector2(0.32f, 0.08f), 0.03f), accent, aa);
                        Paint(ref result, Sdf.Circle(p - new Vector2(0.32f, 0.10f), 0.045f), accent, aa);
                        break;
                    case 'P':
                        Paint(ref result, Sdf.Segment(p, new Vector2(0.30f, -0.34f), new Vector2(0.30f, 0.58f), 0.03f), accent, aa);
                        Paint(ref result, Sdf.Circle(p - new Vector2(0.30f, 0.58f), 0.05f), Hex("#EDEFF2"), aa);
                        break;
                    case 'A':
                        Paint(ref result, Sdf.RoundedBox(p - new Vector2(0f, -0.20f), new Vector2(0.14f, 0.18f), 0.05f), accent, aa);
                        break;
                    case 'E':
                        Paint(ref result, Sdf.Circle(p - new Vector2(-0.16f, 0.62f), 0.07f), body * 0.8f, aa);
                        Paint(ref result, Sdf.Circle(p - new Vector2(0.16f, 0.62f), 0.07f), body * 0.8f, aa);
                        break;
                    case 'W':
                        Paint(ref result, Sdf.Ellipse(p - new Vector2(-0.34f, 0.05f), 0.20f, 0.34f), body * 0.9f, aa);
                        Paint(ref result, Sdf.Ellipse(p - new Vector2(0.34f, 0.05f), 0.20f, 0.34f), body * 0.9f, aa);
                        break;
                }

                return result;
            });
        }

        private static void GenerateSlime(string path)
        {
            RenderSprite(path, p =>
            {
                Color result = new Color(0f, 0f, 0f, 0f);
                float aa = 2.2f / Size;

                Paint(ref result, Sdf.Ellipse(p - new Vector2(0f, -0.82f), 0.32f, 0.08f), new Color(0f, 0f, 0f, 0.25f), aa);
                Paint(ref result, Sdf.Ellipse(p - new Vector2(0f, -0.30f), 0.40f, 0.34f), Hex("#4FA857"), aa);
                Paint(ref result, Sdf.Ellipse(p - new Vector2(-0.10f, -0.14f), 0.16f, 0.12f), Hex("#8FE39A"), aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(-0.12f, -0.32f), 0.035f), Hex("#153018"), aa);
                Paint(ref result, Sdf.Circle(p - new Vector2(0.10f, -0.32f), 0.035f), Hex("#153018"), aa);

                return result;
            });
        }

        // ---------- ui ----------

        private static void GenerateUiPanel()
        {
            RenderSprite(UiFolder + "/UI_Panel.png", p =>
            {
                Color result = new Color(0f, 0f, 0f, 0f);
                float aa = 2.2f / Size;
                float d = Sdf.RoundedBox(p, new Vector2(0.92f, 0.92f), 0.18f);
                Color fill = VerticalGradient(p, Hex("#2B2440"), Hex("#181227"));
                float edge = 1f - SmoothStep(-0.06f, -aa, d);
                fill = Color.Lerp(fill, Hex("#7A5CC9"), edge * 0.6f);
                Paint(ref result, d, fill, aa);
                return result;
            });
        }

        // ---------- shared helpers ----------

        private static void Paint(ref Color result, float sdfDistance, Color color, float aa)
        {
            float alpha = 1f - SmoothStep(-aa, aa, sdfDistance);
            if (alpha <= 0f) return;
            Color c = color;
            c.a = alpha;
            result = Over(c, result);
        }

        private static Color VerticalGradient(Vector2 p, Color top, Color bottom)
        {
            float t = Mathf.Clamp01((p.y + 1f) * 0.5f);
            Color c = Color.Lerp(bottom, top, t);
            c.a = 1f;
            return c;
        }

        private static void RenderSprite(string path, System.Func<Vector2, Color> pixelFn)
        {
            var tex = NewTexture();
            var pixels = new Color[Size * Size];
            for (int y = 0; y < Size; y++)
            {
                for (int x = 0; x < Size; x++)
                {
                    Vector2 p = ToNormalized(x, y);
                    pixels[y * Size + x] = pixelFn(p);
                }
            }
            tex.SetPixels(pixels);
            tex.Apply();
            SavePng(tex, path);
        }

        private static Texture2D NewTexture()
        {
            return new Texture2D(Size, Size, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp
            };
        }

        private static Vector2 ToNormalized(int x, int y)
        {
            float nx = (x + 0.5f) / Size * 2f - 1f;
            float ny = (y + 0.5f) / Size * 2f - 1f;
            return new Vector2(nx, ny);
        }

        private static float SmoothStep(float edge0, float edge1, float v)
        {
            float t = Mathf.Clamp01((v - edge0) / (edge1 - edge0));
            return t * t * (3f - 2f * t);
        }

        private static Color Over(Color src, Color dst)
        {
            float a = src.a + dst.a * (1f - src.a);
            if (a <= 0.0001f) return new Color(0f, 0f, 0f, 0f);
            float r = (src.r * src.a + dst.r * dst.a * (1f - src.a)) / a;
            float g = (src.g * src.a + dst.g * dst.a * (1f - src.a)) / a;
            float b = (src.b * src.a + dst.b * dst.a * (1f - src.a)) / a;
            return new Color(r, g, b, a);
        }

        private static Color Hex(string hex)
        {
            ColorUtility.TryParseHtmlString(hex, out var c);
            return c;
        }

        private static void SavePng(Texture2D tex, string assetPath)
        {
            File.WriteAllBytes(assetPath, tex.EncodeToPNG());
            Object.DestroyImmediate(tex);
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;

            var parts = path.Split('/');
            string current = parts[0];
            for (int i = 1; i < parts.Length; i++)
            {
                string next = current + "/" + parts[i];
                if (!AssetDatabase.IsValidFolder(next))
                {
                    AssetDatabase.CreateFolder(current, parts[i]);
                }
                current = next;
            }
        }

        private static void ConfigureFolderAsSprites(string folder, bool sliced)
        {
            var guids = AssetDatabase.FindAssets("t:Texture2D", new[] { folder });
            foreach (var guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) continue;

                importer.textureType = TextureImporterType.Sprite;
                importer.spriteImportMode = SpriteImportMode.Single;
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.filterMode = FilterMode.Bilinear;
                importer.spritePixelsPerUnit = Size;
                importer.textureCompression = TextureImporterCompression.Uncompressed;

                if (sliced)
                {
                    int border = Size / 5;
                    importer.spriteBorder = new Vector4(border, border, border, border);
                }

                importer.SaveAndReimport();
            }
        }
    }
}
