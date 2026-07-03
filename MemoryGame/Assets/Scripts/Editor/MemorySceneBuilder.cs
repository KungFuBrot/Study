using System.Collections.Generic;
using MemoryGame;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace MemoryGame.EditorTools
{
    /// <summary>
    /// Builds the Card prefab and the playable scene (Canvas, board, UI, GameManager wiring)
    /// entirely from code, so no manual Editor setup is required.
    /// Run via "Memory Spiel/2. Szene erstellen" (after generating the artwork first).
    /// </summary>
    public static class MemorySceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/MemoryGame.unity";
        private const string PrefabPath = "Assets/Prefabs/Card.prefab";

        private static readonly string[] IconNames =
        {
            "Icon_Kreis", "Icon_Herz", "Icon_Diamant", "Icon_Stern",
            "Icon_Sechseck", "Icon_Dreieck", "Icon_Kreuz", "Icon_Mond"
        };

        [MenuItem("Memory Spiel/2. Szene erstellen")]
        public static void BuildScene()
        {
            var icons = LoadIcons();
            var cardFrame = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Sprites/Card/CardFrame.png");
            var cardBack = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Sprites/Card/CardBack.png");
            var background = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Sprites/UI/Background.png");

            if (icons.Length < 8 || cardFrame == null || cardBack == null || background == null)
            {
                EditorUtility.DisplayDialog(
                    "Memory Spiel",
                    "Bitte zuerst 'Memory Spiel/1. Bilder erzeugen' ausführen.",
                    "OK");
                return;
            }

            EnsureFolder("Assets/Scenes");
            EnsureFolder("Assets/Prefabs");

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cardPrefab = BuildCardPrefab(cardFrame, cardBack);

            new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));

            var canvasGO = new GameObject("Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasGO.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGO.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1080f, 1920f);
            scaler.matchWidthOrHeight = 0.5f;

            var bgGO = CreateUIObject("Background", canvasGO.transform);
            var bgImg = bgGO.AddComponent<Image>();
            bgImg.sprite = background;
            bgImg.type = Image.Type.Simple;
            Stretch((RectTransform)bgGO.transform);

            var titleGO = CreateUIObject("Title", canvasGO.transform);
            var titleText = MakeText(titleGO, "Memory Spiel", 76, FontStyle.Bold);
            var titleRT = (RectTransform)titleGO.transform;
            titleRT.anchorMin = new Vector2(0f, 1f);
            titleRT.anchorMax = new Vector2(1f, 1f);
            titleRT.pivot = new Vector2(0.5f, 1f);
            titleRT.sizeDelta = new Vector2(0f, 140f);
            titleRT.anchoredPosition = new Vector2(0f, -40f);

            var movesGO = CreateUIObject("MovesText", canvasGO.transform);
            var movesText = MakeText(movesGO, "Züge: 0", 44, FontStyle.Normal);
            movesText.alignment = TextAnchor.MiddleLeft;
            var movesRT = (RectTransform)movesGO.transform;
            movesRT.anchorMin = new Vector2(0f, 1f);
            movesRT.anchorMax = new Vector2(0.5f, 1f);
            movesRT.pivot = new Vector2(0f, 1f);
            movesRT.sizeDelta = new Vector2(-40f, 70f);
            movesRT.anchoredPosition = new Vector2(40f, -190f);

            var timerGO = CreateUIObject("TimerText", canvasGO.transform);
            var timerText = MakeText(timerGO, "Zeit: 00:00", 44, FontStyle.Normal);
            timerText.alignment = TextAnchor.MiddleRight;
            var timerRT = (RectTransform)timerGO.transform;
            timerRT.anchorMin = new Vector2(0.5f, 1f);
            timerRT.anchorMax = new Vector2(1f, 1f);
            timerRT.pivot = new Vector2(1f, 1f);
            timerRT.sizeDelta = new Vector2(-40f, 70f);
            timerRT.anchoredPosition = new Vector2(-40f, -190f);

            var restartGO = CreateUIObject("RestartButton", canvasGO.transform);
            var restartButton = MakeButton(restartGO, "Neu starten", 32);
            var restartRT = (RectTransform)restartGO.transform;
            restartRT.anchorMin = new Vector2(0.5f, 1f);
            restartRT.anchorMax = new Vector2(0.5f, 1f);
            restartRT.pivot = new Vector2(0.5f, 1f);
            restartRT.sizeDelta = new Vector2(280f, 80f);
            restartRT.anchoredPosition = new Vector2(0f, -280f);

            const int columns = 4;
            const int rows = 4;
            const float cell = 210f;
            const float spacing = 22f;

            var boardGO = CreateUIObject("Board", canvasGO.transform);
            var grid = boardGO.AddComponent<GridLayoutGroup>();
            grid.cellSize = new Vector2(cell, cell);
            grid.spacing = new Vector2(spacing, spacing);
            grid.constraint = GridLayoutGroup.Constraint.FixedColumnCount;
            grid.constraintCount = columns;
            grid.childAlignment = TextAnchor.MiddleCenter;
            var boardRT = (RectTransform)boardGO.transform;
            boardRT.anchorMin = new Vector2(0.5f, 0.5f);
            boardRT.anchorMax = new Vector2(0.5f, 0.5f);
            boardRT.pivot = new Vector2(0.5f, 0.5f);
            boardRT.sizeDelta = new Vector2(
                columns * cell + (columns - 1) * spacing,
                rows * cell + (rows - 1) * spacing);
            boardRT.anchoredPosition = new Vector2(0f, -80f);

            var winPanelGO = CreateUIObject("WinPanel", canvasGO.transform);
            var winBg = winPanelGO.AddComponent<Image>();
            winBg.color = new Color(0f, 0f, 0f, 0.75f);
            Stretch((RectTransform)winPanelGO.transform);

            var winTextGO = CreateUIObject("WinText", winPanelGO.transform);
            var winText = MakeText(winTextGO, "Gewonnen!", 60, FontStyle.Bold);
            var winTextRT = (RectTransform)winTextGO.transform;
            winTextRT.anchorMin = new Vector2(0.5f, 0.5f);
            winTextRT.anchorMax = new Vector2(0.5f, 0.5f);
            winTextRT.pivot = new Vector2(0.5f, 0.5f);
            winTextRT.sizeDelta = new Vector2(800f, 300f);
            winTextRT.anchoredPosition = new Vector2(0f, 60f);

            var winRestartGO = CreateUIObject("WinRestartButton", winPanelGO.transform);
            var winRestartButton = MakeButton(winRestartGO, "Nochmal spielen", 34);
            var winRestartRT = (RectTransform)winRestartGO.transform;
            winRestartRT.anchorMin = new Vector2(0.5f, 0.5f);
            winRestartRT.anchorMax = new Vector2(0.5f, 0.5f);
            winRestartRT.pivot = new Vector2(0.5f, 0.5f);
            winRestartRT.sizeDelta = new Vector2(340f, 90f);
            winRestartRT.anchoredPosition = new Vector2(0f, -100f);

            winPanelGO.SetActive(false);

            var gmGO = new GameObject("GameManager", typeof(GameManager));
            var gm = gmGO.GetComponent<GameManager>();

            var so = new SerializedObject(gm);
            so.FindProperty("boardParent").objectReferenceValue = boardGO.transform;
            so.FindProperty("cardPrefab").objectReferenceValue = cardPrefab.GetComponent<Card>();

            var iconsProp = so.FindProperty("iconSprites");
            iconsProp.arraySize = icons.Length;
            for (int i = 0; i < icons.Length; i++)
            {
                iconsProp.GetArrayElementAtIndex(i).objectReferenceValue = icons[i];
            }

            so.FindProperty("movesText").objectReferenceValue = movesText;
            so.FindProperty("timerText").objectReferenceValue = timerText;
            so.FindProperty("winPanel").objectReferenceValue = winPanelGO;
            so.FindProperty("winText").objectReferenceValue = winText;
            so.ApplyModifiedPropertiesWithoutUndo();

            UnityEventTools.AddPersistentListener(restartButton.onClick, gm.StartNewGame);
            UnityEventTools.AddPersistentListener(winRestartButton.onClick, gm.StartNewGame);

            EditorSceneManager.SaveScene(scene, ScenePath);
            AddSceneToBuildSettings(ScenePath);

            EditorUtility.DisplayDialog(
                "Memory Spiel",
                "Die Szene wurde erstellt:\n" + ScenePath + "\n\nEinfach Play drücken zum Testen.",
                "OK");
        }

        private static GameObject BuildCardPrefab(Sprite cardFrameSprite, Sprite cardBackSprite)
        {
            // Card has [RequireComponent] for Button and Image, so Unity adds those automatically.
            var root = new GameObject("Card", typeof(RectTransform), typeof(Card));
            var rootRT = (RectTransform)root.transform;
            rootRT.sizeDelta = new Vector2(200f, 200f);

            var backImg = root.GetComponent<Image>();
            backImg.sprite = cardBackSprite;
            backImg.type = Image.Type.Simple;

            var button = root.GetComponent<Button>();
            button.targetGraphic = backImg;

            var front = CreateUIObject("FrontFace", root.transform);
            Stretch((RectTransform)front.transform);
            var frontImg = front.AddComponent<Image>();
            frontImg.sprite = cardFrameSprite;
            frontImg.type = Image.Type.Simple;

            var iconGO = CreateUIObject("Icon", front.transform);
            var iconRT = (RectTransform)iconGO.transform;
            iconRT.anchorMin = new Vector2(0.16f, 0.16f);
            iconRT.anchorMax = new Vector2(0.84f, 0.84f);
            iconRT.offsetMin = Vector2.zero;
            iconRT.offsetMax = Vector2.zero;
            var iconImg = iconGO.AddComponent<Image>();
            iconImg.preserveAspect = true;

            front.SetActive(false);

            var cardComp = root.GetComponent<Card>();
            var so = new SerializedObject(cardComp);
            so.FindProperty("frontFace").objectReferenceValue = front;
            so.FindProperty("iconImage").objectReferenceValue = iconImg;
            so.ApplyModifiedPropertiesWithoutUndo();

            var prefab = PrefabUtility.SaveAsPrefabAsset(root, PrefabPath, out bool success);
            Object.DestroyImmediate(root);

            if (!success)
            {
                Debug.LogError("Memory Spiel: Card-Prefab konnte nicht gespeichert werden.");
            }

            return prefab;
        }

        private static Sprite[] LoadIcons()
        {
            var list = new List<Sprite>();
            foreach (var name in IconNames)
            {
                var sprite = AssetDatabase.LoadAssetAtPath<Sprite>($"Assets/Sprites/Icons/{name}.png");
                if (sprite != null) list.Add(sprite);
            }
            return list.ToArray();
        }

        private static GameObject CreateUIObject(string name, Transform parent)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            return go;
        }

        private static void Stretch(RectTransform rt)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
        }

        private static Text MakeText(GameObject go, string content, int fontSize, FontStyle style)
        {
            var text = go.AddComponent<Text>();
            text.text = content;
            text.font = GetDefaultFont();
            text.fontSize = fontSize;
            text.fontStyle = style;
            text.alignment = TextAnchor.MiddleCenter;
            text.color = Color.white;
            text.horizontalOverflow = HorizontalWrapMode.Overflow;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            return text;
        }

        private static Button MakeButton(GameObject go, string label, int fontSize)
        {
            var img = go.AddComponent<Image>();
            img.color = new Color(1f, 0.83f, 0.31f);

            var button = go.AddComponent<Button>();
            button.targetGraphic = img;

            var labelGO = CreateUIObject("Label", go.transform);
            Stretch((RectTransform)labelGO.transform);
            var text = MakeText(labelGO, label, fontSize, FontStyle.Bold);
            text.color = new Color(0.2f, 0.12f, 0.02f);

            return button;
        }

        private static Font GetDefaultFont()
        {
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font == null) font = Resources.GetBuiltinResource<Font>("Arial.ttf");
            return font;
        }

        private static void AddSceneToBuildSettings(string path)
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
    }
}
