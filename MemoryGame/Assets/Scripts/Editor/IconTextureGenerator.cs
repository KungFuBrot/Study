using System.IO;
using UnityEditor;
using UnityEngine;

namespace MemoryGame.EditorTools
{
    /// <summary>
    /// Procedurally draws all card artwork (back, frame, icons) using signed-distance-field
    /// shapes, so the game needs no external art assets or downloads. Run via
    /// "Memory Spiel/1. Bilder erzeugen".
    /// </summary>
    public static class IconTextureGenerator
    {
        private const int Size = 256;
        private const string IconFolder = "Assets/Sprites/Icons";
        private const string CardFolder = "Assets/Sprites/Card";
        private const string UiFolder = "Assets/Sprites/UI";

        private struct IconDef
        {
            public string Name;
            public System.Func<Vector2, float> ShapeSdf;
            public Color Top;
            public Color Bottom;
        }

        [MenuItem("Memory Spiel/1. Bilder erzeugen")]
        public static void GenerateAll()
        {
            EnsureFolder(IconFolder);
            EnsureFolder(CardFolder);
            EnsureFolder(UiFolder);

            GenerateCardFrame();
            GenerateCardBack();
            GenerateBackground();

            foreach (var def in GetIconDefs())
            {
                GenerateIcon(def);
            }

            AssetDatabase.Refresh();
            ConfigureFolderAsSprites(IconFolder);
            ConfigureFolderAsSprites(CardFolder);
            ConfigureFolderAsSprites(UiFolder);

            Debug.Log("Memory Spiel: Alle Bilder wurden erzeugt (" + IconFolder + ", " + CardFolder + ", " + UiFolder + ").");
        }

        private static IconDef[] GetIconDefs()
        {
            return new[]
            {
                new IconDef
                {
                    Name = "Icon_Kreis",
                    ShapeSdf = p => Sdf.Circle(p, 0.62f),
                    Top = Hex("#4FC3F7"), Bottom = Hex("#0277BD")
                },
                new IconDef
                {
                    Name = "Icon_Herz",
                    ShapeSdf = p => Sdf.Heart(new Vector2(p.x * 1.05f, (p.y + 0.42f) * 1.05f + 0.15f)),
                    Top = Hex("#FF8A9B"), Bottom = Hex("#E53366")
                },
                new IconDef
                {
                    Name = "Icon_Diamant",
                    ShapeSdf = p => Sdf.Rhombus(p, new Vector2(0.62f, 0.62f)),
                    Top = Hex("#B39DDB"), Bottom = Hex("#5E35B1")
                },
                new IconDef
                {
                    Name = "Icon_Stern",
                    ShapeSdf = p => Sdf.Star5(p, 0.62f, 0.42f),
                    Top = Hex("#FFD54F"), Bottom = Hex("#FF8F00")
                },
                new IconDef
                {
                    Name = "Icon_Sechseck",
                    ShapeSdf = p => Sdf.Hexagon(p, 0.6f),
                    Top = Hex("#FFB74D"), Bottom = Hex("#E65100")
                },
                new IconDef
                {
                    Name = "Icon_Dreieck",
                    ShapeSdf = p => Sdf.TriangleIso(new Vector2(p.x, p.y + 0.45f), new Vector2(0.62f, 1.0f)),
                    Top = Hex("#81C784"), Bottom = Hex("#2E7D32")
                },
                new IconDef
                {
                    Name = "Icon_Kreuz",
                    ShapeSdf = p => Sdf.Cross(p, new Vector2(0.5f, 0.16f), 0.05f),
                    Top = Hex("#4DD0E1"), Bottom = Hex("#00838F")
                },
                new IconDef
                {
                    Name = "Icon_Mond",
                    ShapeSdf = p => Sdf.Moon(p, 0.16f, 0.5f, 0.4f),
                    Top = Hex("#FFF59D"), Bottom = Hex("#F9A825")
                },
            };
        }

        // ---------- individual generators ----------

        private static void GenerateIcon(IconDef def)
        {
            var tex = NewTexture();
            var pixels = new Color[Size * Size];
            float aa = 2.2f / Size;

            for (int y = 0; y < Size; y++)
            {
                for (int x = 0; x < Size; x++)
                {
                    Vector2 p = ToNormalized(x, y);

                    // soft drop shadow
                    float dShadow = def.ShapeSdf(p - new Vector2(0.05f, -0.06f));
                    float shadowAlpha = (1f - SmoothStep(-aa * 3f, aa * 3f, dShadow)) * 0.30f;
                    Color result = new Color(0f, 0f, 0f, 0f);
                    result = Over(new Color(0f, 0f, 0f, shadowAlpha), result);

                    // main shape with vertical gradient + rim shading
                    float d = def.ShapeSdf(p);
                    float fillAlpha = 1f - SmoothStep(-aa, aa, d);
                    if (fillAlpha > 0f)
                    {
                        float t = Mathf.Clamp01((p.y + 1f) * 0.5f);
                        Color fill = Color.Lerp(def.Bottom, def.Top, t);

                        // darken near the outline for a subtle rim / bevel
                        float rim = 1f - SmoothStep(-0.10f, -aa, d);
                        fill = Color.Lerp(fill, fill * 0.75f, rim * 0.5f);
                        fill.a = fillAlpha;

                        result = Over(fill, result);
                    }

                    pixels[y * Size + x] = result;
                }
            }

            tex.SetPixels(pixels);
            tex.Apply();
            SavePng(tex, IconFolder + "/" + def.Name + ".png");
        }

        private static void GenerateCardFrame()
        {
            var tex = NewTexture();
            var pixels = new Color[Size * Size];
            float aa = 2.2f / Size;
            Vector2 box = new Vector2(0.88f, 0.88f);
            float radius = 0.16f;

            Color top = Hex("#FFFDF7");
            Color bottom = Hex("#F1ECE0");
            Color border = Hex("#D8CFBE");

            for (int y = 0; y < Size; y++)
            {
                for (int x = 0; x < Size; x++)
                {
                    Vector2 p = ToNormalized(x, y);
                    float d = Sdf.RoundedBox(p, box, radius);

                    Color result = new Color(0, 0, 0, 0);
                    float fillAlpha = 1f - SmoothStep(-aa, aa, d);
                    if (fillAlpha > 0f)
                    {
                        float t = Mathf.Clamp01((p.y + 1f) * 0.5f);
                        Color fill = Color.Lerp(bottom, top, t);

                        float edge = 1f - SmoothStep(-0.045f, -aa, d);
                        fill = Color.Lerp(fill, border, edge * 0.6f);
                        fill.a = fillAlpha;
                        result = Over(fill, result);
                    }

                    pixels[y * Size + x] = result;
                }
            }

            tex.SetPixels(pixels);
            tex.Apply();
            SavePng(tex, CardFolder + "/CardFrame.png");
        }

        private static void GenerateCardBack()
        {
            var tex = NewTexture();
            var pixels = new Color[Size * Size];
            float aa = 2.2f / Size;
            Vector2 box = new Vector2(0.88f, 0.88f);
            float radius = 0.16f;

            Color top = Hex("#5B2FA6");
            Color bottom = Hex("#1E3C72");
            Color accent = Hex("#FFD54F");

            for (int y = 0; y < Size; y++)
            {
                for (int x = 0; x < Size; x++)
                {
                    Vector2 p = ToNormalized(x, y);
                    float d = Sdf.RoundedBox(p, box, radius);

                    Color result = new Color(0, 0, 0, 0);
                    float fillAlpha = 1f - SmoothStep(-aa, aa, d);
                    if (fillAlpha > 0f)
                    {
                        float t = Mathf.Clamp01((p.x + p.y + 2f) * 0.25f);
                        Color fill = Color.Lerp(bottom, top, t);

                        // faint diagonal stripes for texture
                        float stripe = Mathf.Abs(Mathf.Sin((p.x - p.y) * 18f));
                        fill = Color.Lerp(fill, fill * 1.08f, (stripe > 0.92f) ? 0.15f : 0f);

                        // decorative hexagon ring emblem
                        float hex = Sdf.Hexagon(p * 1.7f, 0.62f);
                        float ring = 1f - SmoothStep(0.02f, 0.05f, Mathf.Abs(hex + 0.05f));
                        fill = Color.Lerp(fill, accent, ring * 0.55f);

                        // small star at the centre
                        float star = Sdf.Star5(p * 3.1f, 0.62f, 0.42f);
                        float starAlpha = 1f - SmoothStep(-0.03f, 0.03f, star);
                        fill = Color.Lerp(fill, accent, starAlpha * 0.85f);

                        float edge = 1f - SmoothStep(-0.04f, -aa, d);
                        fill = Color.Lerp(fill, top * 0.6f, edge * 0.5f);

                        fill.a = fillAlpha;
                        result = Over(fill, result);
                    }

                    pixels[y * Size + x] = result;
                }
            }

            tex.SetPixels(pixels);
            tex.Apply();
            SavePng(tex, CardFolder + "/CardBack.png");
        }

        private static void GenerateBackground()
        {
            int w = 32, h = 256;
            var tex = new Texture2D(w, h, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Bilinear,
                wrapMode = TextureWrapMode.Clamp
            };
            var pixels = new Color[w * h];
            Color top = Hex("#2B1055");
            Color bottom = Hex("#0F2027");

            for (int y = 0; y < h; y++)
            {
                float t = (float)y / (h - 1);
                Color c = Color.Lerp(bottom, top, t);
                for (int x = 0; x < w; x++)
                {
                    pixels[y * w + x] = c;
                }
            }

            tex.SetPixels(pixels);
            tex.Apply();
            SavePng(tex, UiFolder + "/Background.png");
        }

        // ---------- helpers ----------

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

        // "src over dst" alpha compositing
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

        private static void ConfigureFolderAsSprites(string folder)
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
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.SaveAndReimport();
            }
        }
    }
}
