using RpgAdventure;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Builds the small town: two talkable NPCs, one shopkeeper, no random encounters,
    /// and a single gate south to the world map. Run via "RPG Spiel/3. Stadt-Szene erstellen".
    /// </summary>
    public static class TownSceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/TownScene.unity";
        private const string TileFolder = "Assets/Sprites/Tiles";
        private const string CharFolder = "Assets/Sprites/Characters";
        private const string UiFolder = "Assets/Sprites/UI";

        [MenuItem("RPG Spiel/3. Stadt-Szene erstellen")]
        public static void BuildScene()
        {
            var grass = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Grass");
            var path = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Path");
            var hedge = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Hedge");
            var playerSprite = SceneBuildUtils.LoadSprite(CharFolder, "Char_Aria");
            var elderSprite = SceneBuildUtils.LoadSprite(CharFolder, "Npc_Elder");
            var guardSprite = SceneBuildUtils.LoadSprite(CharFolder, "Npc_Guard");
            var shopkeeperSprite = SceneBuildUtils.LoadSprite(CharFolder, "Npc_Shopkeeper");
            var panelSprite = SceneBuildUtils.LoadSprite(UiFolder, "UI_Panel");

            var potion = AssetDatabase.LoadAssetAtPath<ItemDefinition>(RpgDataBuilder.DataFolder + "/Item_KleinerTrank.asset");
            var manaVial = AssetDatabase.LoadAssetAtPath<ItemDefinition>(RpgDataBuilder.DataFolder + "/Item_Manaphiole.asset");

            if (grass == null || playerSprite == null || potion == null)
            {
                EditorUtility.DisplayDialog("RPG Spiel", "Bitte zuerst Schritt 1 (Bilder) und 2 (Daten) ausführen.", "OK");
                return;
            }

            SceneBuildUtils.EnsureFolder("Assets/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var map = new AsciiMap(13, 11, '.');
            map.Border('#');
            map.Rect(2, 2, 4, 3, '#');
            map.Rect(8, 2, 10, 3, '#');
            for (int y = 4; y <= 9; y++) map.Set(6, y, '=');
            map.Set(6, 6, 'S');
            map.Set(3, 5, '1');
            map.Set(9, 5, '2');
            map.Set(6, 8, 'P');
            map.Set(6, 10, 'X');

            var grid = SceneBuildUtils.BuildGrid(map, c => Classify(c, grass, path, hedge), 1f);

            BuildCamera();

            var playerGO = new GameObject("Player");
            var playerSr = playerGO.AddComponent<SpriteRenderer>();
            playerSr.sprite = playerSprite;
            playerSr.sortingOrder = SceneBuildUtils.EntitySortingOrder;

            var elderCell = map.Find('1');
            var elderGO = SceneBuildUtils.CreateSpriteEntity("Npc_Elder", elderSprite, elderCell, grid, SceneBuildUtils.EntitySortingOrder);
            var elder = elderGO.AddComponent<Npc>();
            elder.npcName = "Alrik";
            elder.cell = elderCell;
            elder.dialogueLines = new[]
            {
                "Willkommen in unserem kleinen Dorf, Reisende.",
                "Im Dungeon im Osten lauern gefährliche Kreaturen - seid vorsichtig.",
                "Der Laden hier verkauft nützliche Tränke, falls ihr aufbrecht."
            };

            var guardCell = map.Find('2');
            var guardGO = SceneBuildUtils.CreateSpriteEntity("Npc_Guard", guardSprite, guardCell, grid, SceneBuildUtils.EntitySortingOrder);
            var guard = guardGO.AddComponent<Npc>();
            guard.npcName = "Beris";
            guard.cell = guardCell;
            guard.dialogueLines = new[]
            {
                "Ich bewache dieses Dorf Tag und Nacht.",
                "Über die Weltkarte im Süden gelangt ihr zum Dungeon und wieder zurück.",
                "Hier im Dorf gibt es keine Zufallskämpfe - hier seid ihr sicher."
            };

            var shopCell = map.Find('S');
            var shopGO = SceneBuildUtils.CreateSpriteEntity("Shopkeeper", shopkeeperSprite, shopCell, grid, SceneBuildUtils.EntitySortingOrder);
            var shop = shopGO.AddComponent<Shop>();
            shop.shopName = "Miras Laden";
            shop.cell = shopCell;
            shop.itemsForSale = new[] { potion, manaVial };

            var gateCell = map.Find('X');
            var gateGO = new GameObject("Gate_ToWorldMap");
            var gateZone = gateGO.AddComponent<TransitionZone>();
            gateZone.cell = gateCell;
            gateZone.targetScene = "WorldMapScene";
            gateZone.targetSpawnId = "FromTown";

            var spawnDefaultGO = new GameObject("Spawn_Default");
            var spawnDefault = spawnDefaultGO.AddComponent<SpawnPoint>();
            spawnDefault.spawnId = "Default";
            spawnDefault.cell = map.Find('P');

            var spawnGateGO = new GameObject("Spawn_FromWorldMap");
            var spawnGate = spawnGateGO.AddComponent<SpawnPoint>();
            spawnGate.spawnId = "FromWorldMap";
            spawnGate.cell = gateCell;

            var ui = SceneBuildUtils.BuildOverworldUI(panelSprite);

            var controllerGO = new GameObject("OverworldController");
            var controller = controllerGO.AddComponent<OverworldController>();
            var so = new SerializedObject(controller);
            so.FindProperty("mapGrid").objectReferenceValue = grid;
            so.FindProperty("playerTransform").objectReferenceValue = playerGO.transform;
            so.FindProperty("playerSpriteRenderer").objectReferenceValue = playerSr;
            so.FindProperty("playerSprite").objectReferenceValue = playerSprite;

            var spawnArray = so.FindProperty("spawnPoints");
            spawnArray.arraySize = 2;
            spawnArray.GetArrayElementAtIndex(0).objectReferenceValue = spawnDefault;
            spawnArray.GetArrayElementAtIndex(1).objectReferenceValue = spawnGate;

            var transitionArray = so.FindProperty("transitions");
            transitionArray.arraySize = 1;
            transitionArray.GetArrayElementAtIndex(0).objectReferenceValue = gateZone;

            var npcArray = so.FindProperty("npcs");
            npcArray.arraySize = 2;
            npcArray.GetArrayElementAtIndex(0).objectReferenceValue = elder;
            npcArray.GetArrayElementAtIndex(1).objectReferenceValue = guard;

            var shopArray = so.FindProperty("shops");
            shopArray.arraySize = 1;
            shopArray.GetArrayElementAtIndex(0).objectReferenceValue = shop;

            so.FindProperty("encountersEnabled").boolValue = false;
            so.FindProperty("dialogueUI").objectReferenceValue = ui.dialogueUI;
            so.FindProperty("shopUI").objectReferenceValue = ui.shopUI;
            so.FindProperty("hud").objectReferenceValue = ui.hud;
            so.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.SaveScene(scene, ScenePath);
            SceneBuildUtils.AddSceneToBuildSettings(ScenePath);

            EditorUtility.DisplayDialog("RPG Spiel", "Die Stadt-Szene wurde erstellt:\n" + ScenePath, "OK");
        }

        private static void BuildCamera()
        {
            var cameraGO = new GameObject("Main Camera", typeof(Camera), typeof(CameraFollow2D));
            var camera = cameraGO.GetComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 5f;
            camera.backgroundColor = new Color(0.15f, 0.18f, 0.15f);
            cameraGO.transform.position = new Vector3(0f, 0f, -10f);
            cameraGO.tag = "MainCamera";
        }

        private static TileInfo Classify(char c, Sprite grass, Sprite path, Sprite hedge)
        {
            switch (c)
            {
                case '#': return TileInfo.Blocked(hedge);
                case '=': return TileInfo.Walkable(path);
                default: return TileInfo.Walkable(grass);
            }
        }
    }
}
