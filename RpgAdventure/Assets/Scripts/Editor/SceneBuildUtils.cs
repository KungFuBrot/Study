using System.Collections.Generic;
using RpgAdventure;
using UnityEditor;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RpgAdventure.EditorTools
{
    public struct OverworldUIRefs
    {
        public DialogueUI dialogueUI;
        public ShopUI shopUI;
        public OverworldHudUI hud;
    }

    /// <summary>A simple width x height grid of characters used to lay out a scene's map by hand in code.</summary>
    public class AsciiMap
    {
        public readonly int width;
        public readonly int height;
        private readonly char[,] _cells;

        public AsciiMap(int width, int height, char fill = '.')
        {
            this.width = width;
            this.height = height;
            _cells = new char[width, height];
            for (int x = 0; x < width; x++)
                for (int y = 0; y < height; y++)
                    _cells[x, y] = fill;
        }

        public void Set(int x, int y, char c) => _cells[x, y] = c;
        public char Get(int x, int y) => _cells[x, y];

        public void Border(char c)
        {
            for (int x = 0; x < width; x++) { Set(x, 0, c); Set(x, height - 1, c); }
            for (int y = 0; y < height; y++) { Set(0, y, c); Set(width - 1, y, c); }
        }

        public void Rect(int x0, int y0, int x1, int y1, char c)
        {
            for (int x = x0; x <= x1; x++)
                for (int y = y0; y <= y1; y++)
                    Set(x, y, c);
        }

        public Vector2Int Find(char marker)
        {
            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                    if (_cells[x, y] == marker) return new Vector2Int(x, y);
            return new Vector2Int(-1, -1);
        }
    }

    public struct TileInfo
    {
        public Sprite sprite;
        public bool walkable;
        public bool encounter;

        public static TileInfo Walkable(Sprite s, bool encounter = false) => new TileInfo { sprite = s, walkable = true, encounter = encounter };
        public static TileInfo Blocked(Sprite s) => new TileInfo { sprite = s, walkable = false, encounter = false };
    }

    /// <summary>Shared helpers for the scene-builder editor scripts (grid/tile placement, basic UI construction).</summary>
    public static class SceneBuildUtils
    {
        public const int EntitySortingOrder = 5;

        public static MapGrid BuildGrid(AsciiMap map, System.Func<char, TileInfo> classify, float cellSize)
        {
            var walkable = new bool[map.width * map.height];
            var encounter = new bool[map.width * map.height];

            var tilesParent = new GameObject("Tiles").transform;

            for (int y = 0; y < map.height; y++)
            {
                for (int x = 0; x < map.width; x++)
                {
                    char ch = map.Get(x, y);
                    var info = classify(ch);
                    int idx = y * map.width + x;
                    walkable[idx] = info.walkable;
                    encounter[idx] = info.encounter;

                    if (info.sprite != null)
                    {
                        var tileGO = new GameObject("Tile_" + x + "_" + y);
                        tileGO.transform.SetParent(tilesParent, false);
                        tileGO.transform.position = new Vector3(x * cellSize, -y * cellSize, 0f);
                        var sr = tileGO.AddComponent<SpriteRenderer>();
                        sr.sprite = info.sprite;
                        sr.sortingOrder = info.walkable ? 0 : 1;
                    }
                }
            }

            var gridGO = new GameObject("MapGrid");
            var grid = gridGO.AddComponent<MapGrid>();
            grid.Configure(map.width, map.height, cellSize, walkable, encounter);
            return grid;
        }

        public static GameObject CreateSpriteEntity(string name, Sprite sprite, Vector2Int cell, MapGrid grid, int sortingOrder)
        {
            var go = new GameObject(name);
            go.transform.position = grid.CellToWorld(cell);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = sprite;
            sr.sortingOrder = sortingOrder;
            return go;
        }

        public static GameObject CreateUIObject(string name, Transform parent)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            return go;
        }

        public static void Stretch(RectTransform rt)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        public static Text MakeText(GameObject go, string content, int fontSize, FontStyle style, Color color, TextAnchor anchor = TextAnchor.MiddleCenter)
        {
            var text = go.AddComponent<Text>();
            text.text = content;
            text.font = GetDefaultFont();
            text.fontSize = fontSize;
            text.fontStyle = style;
            text.alignment = anchor;
            text.color = color;
            text.horizontalOverflow = HorizontalWrapMode.Wrap;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            return text;
        }

        public static Button MakeButton(GameObject go, string label, int fontSize, Color bgColor, Color textColor)
        {
            var img = go.AddComponent<Image>();
            img.color = bgColor;

            var button = go.AddComponent<Button>();
            button.targetGraphic = img;

            var labelGO = CreateUIObject("Label", go.transform);
            Stretch((RectTransform)labelGO.transform);
            MakeText(labelGO, label, fontSize, FontStyle.Bold, textColor);

            return button;
        }

        public static Font GetDefaultFont()
        {
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font == null) font = Resources.GetBuiltinResource<Font>("Arial.ttf");
            return font;
        }

        public static void EnsureFolder(string path)
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

        public static void AddSceneToBuildSettings(string path)
        {
            var scenes = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
            bool exists = false;
            foreach (var s in scenes)
            {
                if (s.path == path) { exists = true; break; }
            }
            if (!exists)
            {
                scenes.Add(new EditorBuildSettingsScene(path, true));
                EditorBuildSettings.scenes = scenes.ToArray();
            }
        }

        public static Sprite LoadSprite(string folder, string name)
        {
            return AssetDatabase.LoadAssetAtPath<Sprite>(folder + "/" + name + ".png");
        }

        /// <summary>Builds EventSystem + Canvas + HUD/dialogue/shop panels shared by every overworld scene.</summary>
        public static OverworldUIRefs BuildOverworldUI(Sprite panelSprite)
        {
            new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));

            var canvasGO = new GameObject("Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasGO.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGO.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);
            scaler.matchWidthOrHeight = 0.5f;

            // --- HUD ---
            var hudGO = CreateUIObject("HudText", canvasGO.transform);
            var hudText = MakeText(hudGO, "", 22, FontStyle.Bold, Color.white, TextAnchor.UpperLeft);
            var hudRT = (RectTransform)hudGO.transform;
            hudRT.anchorMin = new Vector2(0f, 1f);
            hudRT.anchorMax = new Vector2(1f, 1f);
            hudRT.pivot = new Vector2(0.5f, 1f);
            hudRT.sizeDelta = new Vector2(-40f, 40f);
            hudRT.anchoredPosition = new Vector2(0f, -14f);
            var hud = hudGO.AddComponent<OverworldHudUI>();
            var hudSo = new SerializedObject(hud);
            hudSo.FindProperty("infoText").objectReferenceValue = hudText;
            hudSo.ApplyModifiedPropertiesWithoutUndo();

            // --- Dialogue panel ---
            var dialogueGO = CreateUIObject("DialoguePanel", canvasGO.transform);
            var dialogueBg = dialogueGO.AddComponent<Image>();
            dialogueBg.sprite = panelSprite;
            dialogueBg.type = Image.Type.Sliced;
            var dialogueRT = (RectTransform)dialogueGO.transform;
            dialogueRT.anchorMin = new Vector2(0f, 0f);
            dialogueRT.anchorMax = new Vector2(1f, 0f);
            dialogueRT.pivot = new Vector2(0.5f, 0f);
            dialogueRT.sizeDelta = new Vector2(-60f, 170f);
            dialogueRT.anchoredPosition = new Vector2(0f, 24f);

            var nameGO = CreateUIObject("NameText", dialogueGO.transform);
            var nameText = MakeText(nameGO, "", 24, FontStyle.Bold, new Color(1f, 0.85f, 0.4f), TextAnchor.UpperLeft);
            var nameRT = (RectTransform)nameGO.transform;
            nameRT.anchorMin = new Vector2(0f, 1f);
            nameRT.anchorMax = new Vector2(1f, 1f);
            nameRT.pivot = new Vector2(0.5f, 1f);
            nameRT.sizeDelta = new Vector2(-40f, 34f);
            nameRT.anchoredPosition = new Vector2(0f, -16f);

            var bodyGO = CreateUIObject("BodyText", dialogueGO.transform);
            var bodyText = MakeText(bodyGO, "", 20, FontStyle.Normal, Color.white, TextAnchor.UpperLeft);
            var bodyRT = (RectTransform)bodyGO.transform;
            bodyRT.anchorMin = new Vector2(0f, 0f);
            bodyRT.anchorMax = new Vector2(1f, 1f);
            bodyRT.offsetMin = new Vector2(24f, 16f);
            bodyRT.offsetMax = new Vector2(-24f, -52f);

            var dialogueUI = dialogueGO.AddComponent<DialogueUI>();
            var dialogueSo = new SerializedObject(dialogueUI);
            dialogueSo.FindProperty("panel").objectReferenceValue = dialogueGO;
            dialogueSo.FindProperty("nameText").objectReferenceValue = nameText;
            dialogueSo.FindProperty("bodyText").objectReferenceValue = bodyText;
            dialogueSo.ApplyModifiedPropertiesWithoutUndo();

            // --- Shop panel ---
            var shopGO = CreateUIObject("ShopPanel", canvasGO.transform);
            var shopBg = shopGO.AddComponent<Image>();
            shopBg.sprite = panelSprite;
            shopBg.type = Image.Type.Sliced;
            var shopRT = (RectTransform)shopGO.transform;
            shopRT.anchorMin = new Vector2(0.5f, 0.5f);
            shopRT.anchorMax = new Vector2(0.5f, 0.5f);
            shopRT.pivot = new Vector2(0.5f, 0.5f);
            shopRT.sizeDelta = new Vector2(560f, 460f);
            shopRT.anchoredPosition = Vector2.zero;

            var shopMsgGO = CreateUIObject("MessageText", shopGO.transform);
            var shopMsgText = MakeText(shopMsgGO, "", 22, FontStyle.Bold, new Color(1f, 0.85f, 0.4f), TextAnchor.UpperLeft);
            var shopMsgRT = (RectTransform)shopMsgGO.transform;
            shopMsgRT.anchorMin = new Vector2(0f, 1f);
            shopMsgRT.anchorMax = new Vector2(1f, 1f);
            shopMsgRT.pivot = new Vector2(0.5f, 1f);
            shopMsgRT.sizeDelta = new Vector2(-40f, 40f);
            shopMsgRT.anchoredPosition = new Vector2(0f, -20f);

            var goldGO = CreateUIObject("GoldText", shopGO.transform);
            var goldText = MakeText(goldGO, "", 20, FontStyle.Normal, Color.white, TextAnchor.UpperRight);
            var goldRT = (RectTransform)goldGO.transform;
            goldRT.anchorMin = new Vector2(0f, 1f);
            goldRT.anchorMax = new Vector2(1f, 1f);
            goldRT.pivot = new Vector2(0.5f, 1f);
            goldRT.sizeDelta = new Vector2(-40f, 30f);
            goldRT.anchoredPosition = new Vector2(0f, -56f);

            var listGO = CreateUIObject("ItemList", shopGO.transform);
            var listLayout = listGO.AddComponent<VerticalLayoutGroup>();
            listLayout.spacing = 8f;
            listLayout.childControlHeight = false;
            listLayout.childControlWidth = true;
            listLayout.childForceExpandHeight = false;
            listLayout.childForceExpandWidth = true;
            var listRT = (RectTransform)listGO.transform;
            listRT.anchorMin = new Vector2(0f, 0f);
            listRT.anchorMax = new Vector2(1f, 1f);
            listRT.offsetMin = new Vector2(24f, 80f);
            listRT.offsetMax = new Vector2(-24f, -96f);

            var rowTemplate = CreateShopRowTemplate(listGO.transform);

            var closeGO = CreateUIObject("CloseButton", shopGO.transform);
            var closeButton = MakeButton(closeGO, "Schließen", 22, new Color(0.6f, 0.2f, 0.2f), Color.white);
            var closeRT = (RectTransform)closeGO.transform;
            closeRT.anchorMin = new Vector2(0.5f, 0f);
            closeRT.anchorMax = new Vector2(0.5f, 0f);
            closeRT.pivot = new Vector2(0.5f, 0f);
            closeRT.sizeDelta = new Vector2(200f, 50f);
            closeRT.anchoredPosition = new Vector2(0f, 20f);

            var shopUI = shopGO.AddComponent<ShopUI>();
            var shopSo = new SerializedObject(shopUI);
            shopSo.FindProperty("panel").objectReferenceValue = shopGO;
            shopSo.FindProperty("listParent").objectReferenceValue = listGO.transform;
            shopSo.FindProperty("rowTemplate").objectReferenceValue = rowTemplate;
            shopSo.FindProperty("goldText").objectReferenceValue = goldText;
            shopSo.FindProperty("messageText").objectReferenceValue = shopMsgText;
            shopSo.FindProperty("closeButton").objectReferenceValue = closeButton;
            shopSo.ApplyModifiedPropertiesWithoutUndo();

            return new OverworldUIRefs { dialogueUI = dialogueUI, shopUI = shopUI, hud = hud };
        }

        private static GameObject CreateShopRowTemplate(Transform parent)
        {
            var row = CreateUIObject("ItemRow", parent);
            var layout = row.AddComponent<HorizontalLayoutGroup>();
            layout.spacing = 10f;
            layout.childControlWidth = true;
            layout.childControlHeight = true;
            layout.childForceExpandWidth = false;
            layout.childForceExpandHeight = true;
            var rowLE = row.AddComponent<LayoutElement>();
            rowLE.preferredHeight = 44f;

            var nameGO = CreateUIObject("NameText", row.transform);
            var nameLE = nameGO.AddComponent<LayoutElement>();
            nameLE.flexibleWidth = 1f;
            MakeText(nameGO, "Item", 20, FontStyle.Normal, Color.white, TextAnchor.MiddleLeft);

            var priceGO = CreateUIObject("PriceText", row.transform);
            var priceLE = priceGO.AddComponent<LayoutElement>();
            priceLE.preferredWidth = 80f;
            MakeText(priceGO, "0 G", 20, FontStyle.Normal, new Color(1f, 0.85f, 0.4f), TextAnchor.MiddleRight);

            var buyGO = CreateUIObject("BuyButton", row.transform);
            var buyLE = buyGO.AddComponent<LayoutElement>();
            buyLE.preferredWidth = 110f;
            MakeButton(buyGO, "Kaufen", 18, new Color(0.25f, 0.5f, 0.25f), Color.white);

            return row;
        }

        /// <summary>A single-label button used for dynamic choice lists (battle menus etc.).</summary>
        public static GameObject CreateChoiceButtonTemplate(Transform parent, Vector2 size)
        {
            var go = CreateUIObject("ChoiceButton", parent);
            var le = go.AddComponent<LayoutElement>();
            le.preferredHeight = size.y;
            le.preferredWidth = size.x;
            MakeButton(go, "Option", 20, new Color(0.3f, 0.26f, 0.45f), Color.white);
            return go;
        }
    }
}
