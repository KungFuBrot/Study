using RpgAdventure;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Builds the world map that connects the town and the dungeon. Safe to travel -
    /// no random encounters here, only inside the dungeon. Run via
    /// "RPG Spiel/4. Weltkarte-Szene erstellen".
    /// </summary>
    public static class WorldMapSceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/WorldMapScene.unity";
        private const string TileFolder = "Assets/Sprites/Tiles";
        private const string CharFolder = "Assets/Sprites/Characters";
        private const string UiFolder = "Assets/Sprites/UI";

        [MenuItem("RPG Spiel/4. Weltkarte-Szene erstellen")]
        public static void BuildScene()
        {
            var grass = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Grass");
            var path = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Path");
            var water = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Water");
            var mountain = SceneBuildUtils.LoadSprite(TileFolder, "Tile_Mountain");
            var playerSprite = SceneBuildUtils.LoadSprite(CharFolder, "Char_Aria");
            var panelSprite = SceneBuildUtils.LoadSprite(UiFolder, "UI_Panel");

            if (grass == null || playerSprite == null)
            {
                EditorUtility.DisplayDialog("RPG Spiel", "Bitte zuerst 'RPG Spiel/1. Bilder erzeugen' ausführen.", "OK");
                return;
            }

            SceneBuildUtils.EnsureFolder("Assets/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var map = new AsciiMap(15, 11, '.');
            map.Border('^');
            map.Rect(2, 1, 4, 3, '~');
            map.Rect(9, 7, 12, 9, '^');
            for (int x = 1; x <= 13; x++) map.Set(x, 5, '=');
            map.Set(2, 5, 'P');
            map.Set(7, 5, 'C');
            map.Set(12, 5, 'V');

            var grid = SceneBuildUtils.BuildGrid(map, c => Classify(c, grass, path, water, mountain), 1f);

            BuildCamera();

            var playerGO = new GameObject("Player");
            var playerSr = playerGO.AddComponent<SpriteRenderer>();
            playerSr.sprite = playerSprite;
            playerSr.sortingOrder = SceneBuildUtils.EntitySortingOrder;

            var townCell = map.Find('C');
            var townGateGO = new GameObject("Gate_ToTown");
            var townGate = townGateGO.AddComponent<TransitionZone>();
            townGate.cell = townCell;
            townGate.targetScene = "TownScene";
            townGate.targetSpawnId = "FromWorldMap";

            var dungeonCell = map.Find('V');
            var dungeonGateGO = new GameObject("Gate_ToDungeon");
            var dungeonGate = dungeonGateGO.AddComponent<TransitionZone>();
            dungeonGate.cell = dungeonCell;
            dungeonGate.targetScene = "DungeonScene";
            dungeonGate.targetSpawnId = "FromWorldMap";

            var spawnDefaultGO = new GameObject("Spawn_Default");
            var spawnDefault = spawnDefaultGO.AddComponent<SpawnPoint>();
            spawnDefault.spawnId = "Default";
            spawnDefault.cell = map.Find('P');

            var spawnFromTownGO = new GameObject("Spawn_FromTown");
            var spawnFromTown = spawnFromTownGO.AddComponent<SpawnPoint>();
            spawnFromTown.spawnId = "FromTown";
            spawnFromTown.cell = townCell;

            var spawnFromDungeonGO = new GameObject("Spawn_FromDungeon");
            var spawnFromDungeon = spawnFromDungeonGO.AddComponent<SpawnPoint>();
            spawnFromDungeon.spawnId = "FromDungeon";
            spawnFromDungeon.cell = dungeonCell;

            var ui = SceneBuildUtils.BuildOverworldUI(panelSprite);

            var controllerGO = new GameObject("OverworldController");
            var controller = controllerGO.AddComponent<OverworldController>();
            var so = new SerializedObject(controller);
            so.FindProperty("mapGrid").objectReferenceValue = grid;
            so.FindProperty("playerTransform").objectReferenceValue = playerGO.transform;
            so.FindProperty("playerSpriteRenderer").objectReferenceValue = playerSr;
            so.FindProperty("playerSprite").objectReferenceValue = playerSprite;

            var spawnArray = so.FindProperty("spawnPoints");
            spawnArray.arraySize = 3;
            spawnArray.GetArrayElementAtIndex(0).objectReferenceValue = spawnDefault;
            spawnArray.GetArrayElementAtIndex(1).objectReferenceValue = spawnFromTown;
            spawnArray.GetArrayElementAtIndex(2).objectReferenceValue = spawnFromDungeon;

            var transitionArray = so.FindProperty("transitions");
            transitionArray.arraySize = 2;
            transitionArray.GetArrayElementAtIndex(0).objectReferenceValue = townGate;
            transitionArray.GetArrayElementAtIndex(1).objectReferenceValue = dungeonGate;

            so.FindProperty("encountersEnabled").boolValue = false;
            so.FindProperty("dialogueUI").objectReferenceValue = ui.dialogueUI;
            so.FindProperty("shopUI").objectReferenceValue = ui.shopUI;
            so.FindProperty("hud").objectReferenceValue = ui.hud;
            so.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.SaveScene(scene, ScenePath);
            SceneBuildUtils.AddSceneToBuildSettings(ScenePath);

            EditorUtility.DisplayDialog("RPG Spiel", "Die Weltkarten-Szene wurde erstellt:\n" + ScenePath, "OK");
        }

        private static void BuildCamera()
        {
            var cameraGO = new GameObject("Main Camera", typeof(Camera), typeof(CameraFollow2D));
            var camera = cameraGO.GetComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 5f;
            camera.backgroundColor = new Color(0.1f, 0.15f, 0.22f);
            cameraGO.transform.position = new Vector3(0f, 0f, -10f);
            cameraGO.tag = "MainCamera";
        }

        private static TileInfo Classify(char c, Sprite grass, Sprite path, Sprite water, Sprite mountain)
        {
            switch (c)
            {
                case '^': return TileInfo.Blocked(mountain);
                case '~': return TileInfo.Blocked(water);
                case '=': return TileInfo.Walkable(path);
                default: return TileInfo.Walkable(grass);
            }
        }
    }
}
