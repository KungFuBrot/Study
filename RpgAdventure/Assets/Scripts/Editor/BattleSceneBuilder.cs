using RpgAdventure;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Builds the shared battle scene: side-view hero/enemy sprite slots, the status
    /// and log panels, the nested choice menu and the victory/defeat overlays. Loaded
    /// on top whenever a random encounter (or any future scripted fight) triggers.
    /// Run via "RPG Spiel/6. Kampf-Szene erstellen".
    /// </summary>
    public static class BattleSceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/BattleScene.unity";
        private const string UiFolder = "Assets/Sprites/UI";

        [MenuItem("RPG Spiel/6. Kampf-Szene erstellen")]
        public static void BuildScene()
        {
            var panelSprite = SceneBuildUtils.LoadSprite(UiFolder, "UI_Panel");
            if (panelSprite == null)
            {
                EditorUtility.DisplayDialog("RPG Spiel", "Bitte zuerst 'RPG Spiel/1. Bilder erzeugen' ausführen.", "OK");
                return;
            }

            SceneBuildUtils.EnsureFolder("Assets/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cameraGO = new GameObject("Main Camera", typeof(Camera));
            var camera = cameraGO.GetComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 4.2f;
            camera.backgroundColor = new Color(0.10f, 0.08f, 0.16f);
            cameraGO.transform.position = new Vector3(0f, -0.5f, -10f);
            cameraGO.tag = "MainCamera";

            var heroSlots = new SpriteRenderer[2];
            Vector2[] heroPositions = { new Vector2(-3.3f, -1.0f), new Vector2(-3.3f, -2.4f) };
            for (int i = 0; i < heroSlots.Length; i++)
            {
                var go = new GameObject("HeroSlot_" + i);
                go.transform.position = heroPositions[i];
                var sr = go.AddComponent<SpriteRenderer>();
                sr.sortingOrder = SceneBuildUtils.EntitySortingOrder;
                heroSlots[i] = sr;
            }

            var enemySlots = new SpriteRenderer[3];
            Vector2[] enemyPositions = { new Vector2(2.6f, 0.4f), new Vector2(3.2f, -1.2f), new Vector2(2.2f, -2.6f) };
            for (int i = 0; i < enemySlots.Length; i++)
            {
                var go = new GameObject("EnemySlot_" + i);
                go.transform.position = enemyPositions[i];
                var sr = go.AddComponent<SpriteRenderer>();
                sr.sortingOrder = SceneBuildUtils.EntitySortingOrder;
                enemySlots[i] = sr;
            }

            new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));

            var canvasGO = new GameObject("Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasGO.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGO.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);
            scaler.matchWidthOrHeight = 0.5f;

            // Status panel (top)
            var statusPanelGO = SceneBuildUtils.CreateUIObject("StatusPanel", canvasGO.transform);
            var statusBg = statusPanelGO.AddComponent<Image>();
            statusBg.sprite = panelSprite;
            statusBg.type = Image.Type.Sliced;
            var statusRT = (RectTransform)statusPanelGO.transform;
            statusRT.anchorMin = new Vector2(0f, 1f);
            statusRT.anchorMax = new Vector2(1f, 1f);
            statusRT.pivot = new Vector2(0.5f, 1f);
            statusRT.sizeDelta = new Vector2(-40f, 160f);
            statusRT.anchoredPosition = new Vector2(0f, -16f);

            var statusTextGO = SceneBuildUtils.CreateUIObject("StatusText", statusPanelGO.transform);
            var statusText = SceneBuildUtils.MakeText(statusTextGO, "", 20, FontStyle.Normal, Color.white, TextAnchor.UpperLeft);
            var statusTextRT = (RectTransform)statusTextGO.transform;
            statusTextRT.anchorMin = Vector2.zero;
            statusTextRT.anchorMax = Vector2.one;
            statusTextRT.offsetMin = new Vector2(20f, 10f);
            statusTextRT.offsetMax = new Vector2(-20f, -10f);

            // Log panel (middle)
            var logPanelGO = SceneBuildUtils.CreateUIObject("LogPanel", canvasGO.transform);
            var logBg = logPanelGO.AddComponent<Image>();
            logBg.sprite = panelSprite;
            logBg.type = Image.Type.Sliced;
            logBg.color = new Color(1f, 1f, 1f, 0.92f);
            var logRT = (RectTransform)logPanelGO.transform;
            logRT.anchorMin = new Vector2(0f, 0f);
            logRT.anchorMax = new Vector2(1f, 0f);
            logRT.pivot = new Vector2(0.5f, 0f);
            logRT.sizeDelta = new Vector2(-40f, 130f);
            logRT.anchoredPosition = new Vector2(0f, 214f);

            var logTextGO = SceneBuildUtils.CreateUIObject("LogText", logPanelGO.transform);
            var logText = SceneBuildUtils.MakeText(logTextGO, "", 18, FontStyle.Normal, Color.white, TextAnchor.LowerLeft);
            var logTextRT = (RectTransform)logTextGO.transform;
            logTextRT.anchorMin = Vector2.zero;
            logTextRT.anchorMax = Vector2.one;
            logTextRT.offsetMin = new Vector2(16f, 10f);
            logTextRT.offsetMax = new Vector2(-16f, -10f);

            // Choice panel (bottom)
            var choicePanelGO = SceneBuildUtils.CreateUIObject("ChoicePanel", canvasGO.transform);
            var choiceBg = choicePanelGO.AddComponent<Image>();
            choiceBg.sprite = panelSprite;
            choiceBg.type = Image.Type.Sliced;
            var choiceRT = (RectTransform)choicePanelGO.transform;
            choiceRT.anchorMin = new Vector2(0f, 0f);
            choiceRT.anchorMax = new Vector2(1f, 0f);
            choiceRT.pivot = new Vector2(0.5f, 0f);
            choiceRT.sizeDelta = new Vector2(-40f, 190f);
            choiceRT.anchoredPosition = new Vector2(0f, 16f);

            var choiceTitleGO = SceneBuildUtils.CreateUIObject("ChoiceTitle", choicePanelGO.transform);
            var choiceTitle = SceneBuildUtils.MakeText(choiceTitleGO, "", 22, FontStyle.Bold, new Color(1f, 0.85f, 0.4f), TextAnchor.UpperLeft);
            var choiceTitleRT = (RectTransform)choiceTitleGO.transform;
            choiceTitleRT.anchorMin = new Vector2(0f, 1f);
            choiceTitleRT.anchorMax = new Vector2(1f, 1f);
            choiceTitleRT.pivot = new Vector2(0.5f, 1f);
            choiceTitleRT.sizeDelta = new Vector2(-32f, 34f);
            choiceTitleRT.anchoredPosition = new Vector2(0f, -14f);

            var choiceListGO = SceneBuildUtils.CreateUIObject("ChoiceList", choicePanelGO.transform);
            var choiceListLayout = choiceListGO.AddComponent<HorizontalLayoutGroup>();
            choiceListLayout.spacing = 12f;
            choiceListLayout.childControlWidth = true;
            choiceListLayout.childControlHeight = true;
            choiceListLayout.childForceExpandWidth = false;
            choiceListLayout.childForceExpandHeight = true;
            choiceListLayout.childAlignment = TextAnchor.MiddleLeft;
            var choiceListRT = (RectTransform)choiceListGO.transform;
            choiceListRT.anchorMin = new Vector2(0f, 0f);
            choiceListRT.anchorMax = new Vector2(1f, 1f);
            choiceListRT.offsetMin = new Vector2(20f, 16f);
            choiceListRT.offsetMax = new Vector2(-20f, -52f);

            var choiceButtonTemplate = SceneBuildUtils.CreateChoiceButtonTemplate(choiceListGO.transform, new Vector2(190f, 90f));

            // Victory panel
            var victoryPanelGO = SceneBuildUtils.CreateUIObject("VictoryPanel", canvasGO.transform);
            var victoryBg = victoryPanelGO.AddComponent<Image>();
            victoryBg.color = new Color(0f, 0f, 0f, 0.75f);
            SceneBuildUtils.Stretch((RectTransform)victoryPanelGO.transform);

            var victoryTextGO = SceneBuildUtils.CreateUIObject("VictoryText", victoryPanelGO.transform);
            var victoryText = SceneBuildUtils.MakeText(victoryTextGO, "Sieg!", 44, FontStyle.Bold, Color.white);
            var victoryTextRT = (RectTransform)victoryTextGO.transform;
            victoryTextRT.anchorMin = new Vector2(0.5f, 0.5f);
            victoryTextRT.anchorMax = new Vector2(0.5f, 0.5f);
            victoryTextRT.pivot = new Vector2(0.5f, 0.5f);
            victoryTextRT.sizeDelta = new Vector2(600f, 200f);
            victoryTextRT.anchoredPosition = new Vector2(0f, 60f);

            var victoryButtonGO = SceneBuildUtils.CreateUIObject("VictoryButton", victoryPanelGO.transform);
            var victoryButton = SceneBuildUtils.MakeButton(victoryButtonGO, "Weiter", 26, new Color(0.25f, 0.5f, 0.25f), Color.white);
            var victoryButtonRT = (RectTransform)victoryButtonGO.transform;
            victoryButtonRT.anchorMin = new Vector2(0.5f, 0.5f);
            victoryButtonRT.anchorMax = new Vector2(0.5f, 0.5f);
            victoryButtonRT.pivot = new Vector2(0.5f, 0.5f);
            victoryButtonRT.sizeDelta = new Vector2(240f, 70f);
            victoryButtonRT.anchoredPosition = new Vector2(0f, -60f);

            victoryPanelGO.SetActive(false);

            // Defeat panel
            var defeatPanelGO = SceneBuildUtils.CreateUIObject("DefeatPanel", canvasGO.transform);
            var defeatBg = defeatPanelGO.AddComponent<Image>();
            defeatBg.color = new Color(0f, 0f, 0f, 0.8f);
            SceneBuildUtils.Stretch((RectTransform)defeatPanelGO.transform);

            var defeatTextGO = SceneBuildUtils.CreateUIObject("DefeatText", defeatPanelGO.transform);
            SceneBuildUtils.MakeText(defeatTextGO, "Eure Gruppe wurde besiegt...", 36, FontStyle.Bold, new Color(0.9f, 0.3f, 0.3f));
            var defeatTextRT = (RectTransform)defeatTextGO.transform;
            defeatTextRT.anchorMin = new Vector2(0.5f, 0.5f);
            defeatTextRT.anchorMax = new Vector2(0.5f, 0.5f);
            defeatTextRT.pivot = new Vector2(0.5f, 0.5f);
            defeatTextRT.sizeDelta = new Vector2(700f, 160f);
            defeatTextRT.anchoredPosition = new Vector2(0f, 60f);

            var defeatButtonGO = SceneBuildUtils.CreateUIObject("DefeatButton", defeatPanelGO.transform);
            var defeatButton = SceneBuildUtils.MakeButton(defeatButtonGO, "Zurück ins Dorf", 24, new Color(0.5f, 0.25f, 0.25f), Color.white);
            var defeatButtonRT = (RectTransform)defeatButtonGO.transform;
            defeatButtonRT.anchorMin = new Vector2(0.5f, 0.5f);
            defeatButtonRT.anchorMax = new Vector2(0.5f, 0.5f);
            defeatButtonRT.pivot = new Vector2(0.5f, 0.5f);
            defeatButtonRT.sizeDelta = new Vector2(300f, 70f);
            defeatButtonRT.anchoredPosition = new Vector2(0f, -60f);

            defeatPanelGO.SetActive(false);

            var uiGO = new GameObject("BattleUI");
            var battleUI = uiGO.AddComponent<BattleUIController>();
            var uiSo = new SerializedObject(battleUI);
            uiSo.FindProperty("logText").objectReferenceValue = logText;
            uiSo.FindProperty("statusText").objectReferenceValue = statusText;
            uiSo.FindProperty("choicePanel").objectReferenceValue = choicePanelGO;
            uiSo.FindProperty("choiceTitle").objectReferenceValue = choiceTitle;
            uiSo.FindProperty("choiceListParent").objectReferenceValue = choiceListGO.transform;
            uiSo.FindProperty("choiceButtonTemplate").objectReferenceValue = choiceButtonTemplate;
            uiSo.FindProperty("victoryPanel").objectReferenceValue = victoryPanelGO;
            uiSo.FindProperty("victoryText").objectReferenceValue = victoryText;
            uiSo.FindProperty("victoryButton").objectReferenceValue = victoryButton;
            uiSo.FindProperty("defeatPanel").objectReferenceValue = defeatPanelGO;
            uiSo.FindProperty("defeatButton").objectReferenceValue = defeatButton;
            uiSo.ApplyModifiedPropertiesWithoutUndo();

            var managerGO = new GameObject("BattleManager");
            var manager = managerGO.AddComponent<BattleManager>();
            var managerSo = new SerializedObject(manager);

            var heroArray = managerSo.FindProperty("heroSpriteSlots");
            heroArray.arraySize = heroSlots.Length;
            for (int i = 0; i < heroSlots.Length; i++) heroArray.GetArrayElementAtIndex(i).objectReferenceValue = heroSlots[i];

            var enemyArray = managerSo.FindProperty("enemySpriteSlots");
            enemyArray.arraySize = enemySlots.Length;
            for (int i = 0; i < enemySlots.Length; i++) enemyArray.GetArrayElementAtIndex(i).objectReferenceValue = enemySlots[i];

            managerSo.FindProperty("ui").objectReferenceValue = battleUI;
            managerSo.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.SaveScene(scene, ScenePath);
            SceneBuildUtils.AddSceneToBuildSettings(ScenePath);

            EditorUtility.DisplayDialog("RPG Spiel", "Die Kampf-Szene wurde erstellt:\n" + ScenePath, "OK");
        }
    }
}
