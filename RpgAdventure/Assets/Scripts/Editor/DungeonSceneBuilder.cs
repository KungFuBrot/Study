using RpgAdventure;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Builds the dungeon: a single room scattered with rubble pillars where every
    /// floor step (except right at the entrance) has a chance to start a random
    /// battle. Run via "RPG Spiel/5. Dungeon-Szene erstellen".
    /// </summary>
    public static class DungeonSceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/DungeonScene.unity";
        private const string TileFolder = "Assets/Sprites/Tiles";
        private const string CharFolder = "Assets/Sprites/Characters";
        private const string UiFolder = "Assets/Sprites/UI";

        [MenuItem("RPG Spiel/5. Dungeon-Szene erstellen")]
        public static void BuildScene()
        {
            var floor = SceneBuildUtils.LoadSprite(TileFolder, "Tile_DungeonFloor");
            var wall = SceneBuildUtils.LoadSprite(TileFolder, "Tile_DungeonWall");
            var playerSprite = SceneBuildUtils.LoadSprite(CharFolder, "Char_Aria");
            var panelSprite = SceneBuildUtils.LoadSprite(UiFolder, "UI_Panel");
            var encounterTable = AssetDatabase.LoadAssetAtPath<EncounterTable>(RpgDataBuilder.DataFolder + "/Encounters_Dungeon.asset");

            if (floor == null || playerSprite == null || encounterTable == null)
            {
                EditorUtility.DisplayDialog("RPG Spiel", "Bitte zuerst Schritt 1 (Bilder) und 2 (Daten) ausführen.", "OK");
                return;
            }

            SceneBuildUtils.EnsureFolder("Assets/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var map = new AsciiMap(13, 11, '.');
            map.Border('#');
            map.Rect(3, 2, 4, 2, '#');
            map.Rect(8, 2, 9, 2, '#');
            map.Rect(2, 5, 3, 5, '#');
            map.Rect(9, 5, 10, 5, '#');
            map.Rect(5, 7, 7, 7, '#');
            map.Rect(3, 8, 3, 9, '#');
            map.Rect(9, 8, 9, 9, '#');
            map.Set(6, 0, 'X');

            var grid = SceneBuildUtils.BuildGrid(map, c => Classify(c, floor, wall), 1f);

            BuildCamera();

            var playerGO = new GameObject("Player");
            var playerSr = playerGO.AddComponent<SpriteRenderer>();
            playerSr.sprite = playerSprite;
            playerSr.sortingOrder = SceneBuildUtils.EntitySortingOrder;

            var gateCell = map.Find('X');
            var gateGO = new GameObject("Gate_ToWorldMap");
            var gateZone = gateGO.AddComponent<TransitionZone>();
            gateZone.cell = gateCell;
            gateZone.targetScene = "WorldMapScene";
            gateZone.targetSpawnId = "FromDungeon";

            var spawnDefaultGO = new GameObject("Spawn_Default");
            var spawnDefault = spawnDefaultGO.AddComponent<SpawnPoint>();
            spawnDefault.spawnId = "Default";
            spawnDefault.cell = gateCell;

            var spawnFromWorldMapGO = new GameObject("Spawn_FromWorldMap");
            var spawnFromWorldMap = spawnFromWorldMapGO.AddComponent<SpawnPoint>();
            spawnFromWorldMap.spawnId = "FromWorldMap";
            spawnFromWorldMap.cell = gateCell;

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
            spawnArray.GetArrayElementAtIndex(1).objectReferenceValue = spawnFromWorldMap;

            var transitionArray = so.FindProperty("transitions");
            transitionArray.arraySize = 1;
            transitionArray.GetArrayElementAtIndex(0).objectReferenceValue = gateZone;

            so.FindProperty("encountersEnabled").boolValue = true;
            so.FindProperty("encounterTable").objectReferenceValue = encounterTable;
            so.FindProperty("encounterChancePerStep").floatValue = 0.12f;
            so.FindProperty("dialogueUI").objectReferenceValue = ui.dialogueUI;
            so.FindProperty("shopUI").objectReferenceValue = ui.shopUI;
            so.FindProperty("hud").objectReferenceValue = ui.hud;
            so.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.SaveScene(scene, ScenePath);
            SceneBuildUtils.AddSceneToBuildSettings(ScenePath);

            EditorUtility.DisplayDialog("RPG Spiel", "Die Dungeon-Szene wurde erstellt:\n" + ScenePath, "OK");
        }

        private static void BuildCamera()
        {
            var cameraGO = new GameObject("Main Camera", typeof(Camera), typeof(CameraFollow2D));
            var camera = cameraGO.GetComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 5f;
            camera.backgroundColor = new Color(0.05f, 0.05f, 0.07f);
            cameraGO.transform.position = new Vector3(0f, 0f, -10f);
            cameraGO.tag = "MainCamera";
        }

        private static TileInfo Classify(char c, Sprite floor, Sprite wall)
        {
            switch (c)
            {
                case '#': return TileInfo.Blocked(wall);
                case 'X': return TileInfo.Walkable(floor, false);
                default: return TileInfo.Walkable(floor, true);
            }
        }
    }
}
