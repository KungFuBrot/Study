using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;
using RpgFable.Battle;
using RpgFable.Core;
using RpgFable.Data;
using RpgFable.Exploration;
using RpgFable.UI;

namespace RpgFable.EditorTools
{
    /// <summary>
    /// Baut das komplette Spiel per Menübefehl auf:
    /// 1. Grafiken (SpriteFactory), 2. Daten-Assets, 3. die vier Szenen,
    /// 4. Build-Einstellungen. Danach ist das Spiel sofort spielbar.
    /// </summary>
    public static class GameBuilder
    {
        private const string DataFolder = "Assets/RpgFable/Daten";
        private const string SceneFolder = "Assets/RpgFable/Szenen";

        /// <summary>Gebündelte Verweise auf alle erzeugten Daten-Assets.</summary>
        private class GameData
        {
            public HeroDefinition Aria;
            public HeroDefinition Milo;
            public ItemDefinition Heiltrank;
            public ItemDefinition Zaubertrank;
            public EncounterTable DungeonTabelle;
        }

        // ------------------------------------------------------------------
        // Menü
        // ------------------------------------------------------------------

        [MenuItem("RPG Fable/Alles erzeugen (Grafiken, Daten, Szenen)")]
        public static void BuildAll()
        {
            SpriteFactory.GenerateAll();
            GameData data = BuildData();

            BuildStadt(data);
            BuildWeltkarte(data);
            BuildDungeon(data);
            BuildKampf(data);

            RegisterScenesInBuildSettings();
            EditorSceneManager.OpenScene(SceneFolder + "/Stadt.unity");
            Debug.Log("RPG Fable: Spiel vollständig erzeugt. Szene 'Stadt' ist geöffnet — einfach Play drücken!");
        }

        [MenuItem("RPG Fable/Nur Grafiken neu erzeugen")]
        public static void RebuildSprites()
        {
            SpriteFactory.GenerateAll();
        }

        // ------------------------------------------------------------------
        // Daten-Assets
        // ------------------------------------------------------------------

        private static GameData BuildData()
        {
            Directory.CreateDirectory(DataFolder);
            AssetDatabase.Refresh();

            // --- Fähigkeiten der Helden ---
            var wirbelklinge = CreateOrLoad<AbilityDefinition>("Faehigkeit_Wirbelklinge");
            wirbelklinge.displayName = "Wirbelklinge";
            wirbelklinge.description = "Ein wirbelnder Rundumschlag, der alle Gegner trifft.";
            wirbelklinge.kind = AbilityKind.PhysicalDamage;
            wirbelklinge.target = AbilityTarget.AllEnemies;
            wirbelklinge.power = 6;
            wirbelklinge.mpCost = 5;

            var schildbrecher = CreateOrLoad<AbilityDefinition>("Faehigkeit_Schildbrecher");
            schildbrecher.displayName = "Schildbrecher";
            schildbrecher.description = "Ein wuchtiger Hieb gegen einen einzelnen Gegner.";
            schildbrecher.kind = AbilityKind.PhysicalDamage;
            schildbrecher.target = AbilityTarget.SingleEnemy;
            schildbrecher.power = 14;
            schildbrecher.mpCost = 3;

            var feuerball = CreateOrLoad<AbilityDefinition>("Faehigkeit_Feuerball");
            feuerball.displayName = "Feuerball";
            feuerball.description = "Schleudert eine Feuerkugel auf einen Gegner.";
            feuerball.kind = AbilityKind.MagicDamage;
            feuerball.target = AbilityTarget.SingleEnemy;
            feuerball.power = 16;
            feuerball.mpCost = 4;

            var heilendesLicht = CreateOrLoad<AbilityDefinition>("Faehigkeit_HeilendesLicht");
            heilendesLicht.displayName = "Heilendes Licht";
            heilendesLicht.description = "Stellt die Lebenspunkte eines Verbündeten wieder her.";
            heilendesLicht.kind = AbilityKind.Heal;
            heilendesLicht.target = AbilityTarget.SingleAlly;
            heilendesLicht.power = 20;
            heilendesLicht.mpCost = 5;

            // --- Fähigkeit des Golems ---
            var beben = CreateOrLoad<AbilityDefinition>("Faehigkeit_Beben");
            beben.displayName = "Beben";
            beben.description = "Der Boden erzittert und trifft die ganze Gruppe.";
            beben.kind = AbilityKind.PhysicalDamage;
            beben.target = AbilityTarget.AllEnemies;
            beben.power = 5;
            beben.mpCost = 0;

            // --- Helden ---
            var aria = CreateOrLoad<HeroDefinition>("Held_Aria");
            aria.displayName = "Aria";
            aria.className = "Schwertkämpferin";
            aria.description = "Eine entschlossene Kämpferin mit schneller Klinge.";
            aria.fieldSprite = LoadSprite("hero_aria");
            aria.battleSprite = LoadSprite("hero_aria");
            aria.maxHp = 42;
            aria.maxMp = 12;
            aria.attack = 11;
            aria.magic = 4;
            aria.defense = 7;
            aria.speed = 8;
            aria.abilities = new[] { wirbelklinge, schildbrecher };

            var milo = CreateOrLoad<HeroDefinition>("Held_Milo");
            milo.displayName = "Milo";
            milo.className = "Zauberer";
            milo.description = "Ein junger Zauberer mit Gespür für die Elemente.";
            milo.fieldSprite = LoadSprite("hero_milo");
            milo.battleSprite = LoadSprite("hero_milo");
            milo.maxHp = 30;
            milo.maxMp = 24;
            milo.attack = 5;
            milo.magic = 12;
            milo.defense = 4;
            milo.speed = 6;
            milo.abilities = new[] { feuerball, heilendesLicht };

            // --- Gegner ---
            var schleim = CreateOrLoad<EnemyDefinition>("Gegner_Schleim");
            schleim.displayName = "Schleim";
            schleim.battleSprite = LoadSprite("enemy_schleim");
            schleim.maxHp = 18;
            schleim.attack = 6;
            schleim.magic = 2;
            schleim.defense = 2;
            schleim.speed = 4;
            schleim.goldReward = 6;
            schleim.ability = null;
            schleim.abilityChance = 0f;

            var fledermaus = CreateOrLoad<EnemyDefinition>("Gegner_Fledermaus");
            fledermaus.displayName = "Fledermaus";
            fledermaus.battleSprite = LoadSprite("enemy_fledermaus");
            fledermaus.maxHp = 14;
            fledermaus.attack = 7;
            fledermaus.magic = 3;
            fledermaus.defense = 1;
            fledermaus.speed = 9;
            fledermaus.goldReward = 8;
            fledermaus.ability = null;
            fledermaus.abilityChance = 0f;

            var golem = CreateOrLoad<EnemyDefinition>("Gegner_Golem");
            golem.displayName = "Golem";
            golem.battleSprite = LoadSprite("enemy_golem");
            golem.maxHp = 40;
            golem.attack = 9;
            golem.magic = 4;
            golem.defense = 6;
            golem.speed = 3;
            golem.goldReward = 20;
            golem.ability = beben;
            golem.abilityChance = 0.3f;

            // --- Gegenstände ---
            var heiltrank = CreateOrLoad<ItemDefinition>("Gegenstand_Heiltrank");
            heiltrank.displayName = "Heiltrank";
            heiltrank.description = "Stellt 30 LP eines Helden wieder her.";
            heiltrank.price = 20;
            heiltrank.effect = ItemEffect.HealHp;
            heiltrank.amount = 30;

            var zaubertrank = CreateOrLoad<ItemDefinition>("Gegenstand_Zaubertrank");
            zaubertrank.displayName = "Zaubertrank";
            zaubertrank.description = "Stellt 15 MP eines Helden wieder her.";
            zaubertrank.price = 35;
            zaubertrank.effect = ItemEffect.RestoreMp;
            zaubertrank.amount = 15;

            // --- Begegnungstabelle für den Dungeon ---
            var tabelle = CreateOrLoad<EncounterTable>("Begegnungen_Dungeon");
            tabelle.entries = new[]
            {
                new EncounterEntry { enemy = schleim, minCount = 1, maxCount = 2, weight = 5 },
                new EncounterEntry { enemy = fledermaus, minCount = 1, maxCount = 2, weight = 4 },
                new EncounterEntry { enemy = schleim, minCount = 3, maxCount = 3, weight = 2 },
                new EncounterEntry { enemy = golem, minCount = 1, maxCount = 1, weight = 2 },
            };

            AssetDatabase.SaveAssets();

            return new GameData
            {
                Aria = aria,
                Milo = milo,
                Heiltrank = heiltrank,
                Zaubertrank = zaubertrank,
                DungeonTabelle = tabelle,
            };
        }

        private static T CreateOrLoad<T>(string fileName) where T : ScriptableObject
        {
            string path = DataFolder + "/" + fileName + ".asset";
            var asset = AssetDatabase.LoadAssetAtPath<T>(path);
            if (asset == null)
            {
                asset = ScriptableObject.CreateInstance<T>();
                AssetDatabase.CreateAsset(asset, path);
            }
            EditorUtility.SetDirty(asset);
            return asset;
        }

        private static Sprite LoadSprite(string name)
        {
            string path = SpriteFactory.Folder + "/" + name + ".png";
            var sprite = AssetDatabase.LoadAssetAtPath<Sprite>(path);
            if (sprite == null) Debug.LogError("RPG Fable: Sprite '" + path + "' nicht gefunden. Erst Grafiken erzeugen!");
            return sprite;
        }

        // ------------------------------------------------------------------
        // Szene: Stadt
        // ------------------------------------------------------------------

        private static void BuildStadt(GameData data)
        {
            var map = MapLayouts.Stadt;
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            AddMap("map_stadt");
            AddWallColliders(map);
            AddBootstrap(data);

            var player = AddPlayer(data, MapLayouts.CellCenter(map, 10, 11));
            AddCamera(player, map);
            BuildFieldUi();

            AddSpawn(map, 10, 11, "Start");
            AddSpawn(map, 10, 12, "Sued");
            AddPortal(map, 10, 14, "Weltkarte", "VonStadt");

            AddNpc(map, 2, 4, "npc_aeltester", "Ältester Theobald", new[]
            {
                "Willkommen in Eichenhain, Reisende!",
                "Nordöstlich von hier liegt die alte Kristallhöhle. Es heißt, dort hausen Ungeheuer.",
                "Folgt dem Weg nach Süden, dann erreicht ihr die Weltkarte. Aber seid gewappnet!"
            }, false);

            AddNpc(map, 11, 4, "npc_priesterin", "Priesterin Lina", new[]
            {
                "Mögen die Ahnen euch schützen.",
                "Eure Wunden sind geheilt und euer Geist ist erfrischt. Kommt jederzeit wieder."
            }, true);

            AddShop(map, 14, 9, "npc_haendlerin", "Gretas Kramladen",
                new[] { data.Heiltrank, data.Zaubertrank });

            SaveScene("Stadt");
        }

        // ------------------------------------------------------------------
        // Szene: Weltkarte
        // ------------------------------------------------------------------

        private static void BuildWeltkarte(GameData data)
        {
            var map = MapLayouts.Weltkarte;
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            AddMap("map_weltkarte");
            AddWallColliders(map);
            AddBootstrap(data);

            var player = AddPlayer(data, MapLayouts.CellCenter(map, 4, 14));
            AddCamera(player, map);
            BuildFieldUi();

            AddSpawn(map, 4, 14, "VonStadt");
            AddSpawn(map, 21, 3, "VonDungeon");
            AddPortal(map, 4, 13, "Stadt", "Sued");       // Stadt-Symbol
            AddPortal(map, 21, 2, "Dungeon", "Start");    // Höhleneingang

            SaveScene("Weltkarte");
        }

        // ------------------------------------------------------------------
        // Szene: Dungeon
        // ------------------------------------------------------------------

        private static void BuildDungeon(GameData data)
        {
            var map = MapLayouts.Dungeon;
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            AddMap("map_dungeon");
            AddWallColliders(map);
            AddBootstrap(data);

            var player = AddPlayer(data, MapLayouts.CellCenter(map, 10, 12));
            AddCamera(player, map);
            BuildFieldUi();

            AddSpawn(map, 10, 12, "Start");
            AddPortal(map, 10, 14, "Weltkarte", "VonDungeon");

            var zone = new GameObject("Zufallskaempfe").AddComponent<RandomEncounterZone>();
            SetObj(zone, "player", player.transform);
            SetObj(zone, "encounterTable", data.DungeonTabelle);

            SaveScene("Dungeon");
        }

        // ------------------------------------------------------------------
        // Szene: Kampf
        // ------------------------------------------------------------------

        private static void BuildKampf(GameData data)
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            AddBootstrap(data);

            // Kamera (fest, ohne Verfolgung)
            var camGo = new GameObject("Hauptkamera");
            camGo.tag = "MainCamera";
            camGo.transform.position = new Vector3(0f, 0f, -10f);
            var cam = camGo.AddComponent<Camera>();
            cam.orthographic = true;
            cam.orthographicSize = 4.5f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.03f, 0.03f, 0.06f);
            camGo.AddComponent<AudioListener>();

            // Hintergrund (480x270 px bei 30 ppu = 16x9 Einheiten)
            var bg = new GameObject("Hintergrund").AddComponent<SpriteRenderer>();
            bg.sprite = LoadSprite("battle_hintergrund");
            bg.sortingOrder = 0;

            // Aufstellungspunkte
            var enemyRoot = new GameObject("GegnerPosition").transform;
            enemyRoot.position = new Vector3(-4.0f, 0.8f, 0f);
            var heroRoot = new GameObject("HeldenPosition").transform;
            heroRoot.position = new Vector3(4.3f, 0.5f, 0f);

            // Zielpfeil (zeigt nach unten auf den gewählten Gegner)
            var cursor = new GameObject("Zielpfeil").transform;
            cursor.rotation = Quaternion.Euler(0f, 0f, 180f);
            var cursorSr = cursor.gameObject.AddComponent<SpriteRenderer>();
            cursorSr.sprite = LoadSprite("cursor_pfeil");
            cursorSr.sortingOrder = 20;

            // UI
            var canvas = MakeCanvas("KampfUI");

            var statusPanel = MakePanel(canvas.transform, "Statusfenster",
                new Vector2(0.50f, 0.02f), new Vector2(0.98f, 0.26f));
            var statusLabel = MakeText(statusPanel.transform, "Statustext",
                Vector2.zero, Vector2.one, new Vector2(24f, 12f), new Vector2(-24f, -12f),
                22, TextAnchor.MiddleLeft);

            var commandPanel = MakePanel(canvas.transform, "Befehlsfenster",
                new Vector2(0.02f, 0.02f), new Vector2(0.34f, 0.34f));
            var commandLabel = MakeText(commandPanel.transform, "Befehlstext",
                Vector2.zero, Vector2.one, new Vector2(24f, 12f), new Vector2(-24f, -12f),
                22, TextAnchor.MiddleLeft);

            var messagePanel = MakePanel(canvas.transform, "Meldungsfenster",
                new Vector2(0.14f, 0.82f), new Vector2(0.86f, 0.97f));
            var messageLabel = MakeText(messagePanel.transform, "Meldungstext",
                Vector2.zero, Vector2.one, new Vector2(24f, 8f), new Vector2(-24f, -8f),
                24, TextAnchor.MiddleCenter);

            // Kampfleitung verdrahten
            var manager = new GameObject("Kampfleitung").AddComponent<BattleManager>();
            SetObj(manager, "commandPanel", commandPanel.gameObject);
            SetObj(manager, "commandLabel", commandLabel);
            SetObj(manager, "messagePanel", messagePanel.gameObject);
            SetObj(manager, "messageLabel", messageLabel);
            SetObj(manager, "statusLabel", statusLabel);
            SetObj(manager, "enemyRoot", enemyRoot);
            SetObj(manager, "heroRoot", heroRoot);
            SetObj(manager, "targetCursor", cursor);
            SetObj(manager, "fallbackEncounter", data.DungeonTabelle);

            SaveScene("Kampf");
        }

        // ------------------------------------------------------------------
        // Bausteine für Feldszenen
        // ------------------------------------------------------------------

        private static void AddMap(string spriteName)
        {
            var go = new GameObject("Karte");
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = LoadSprite(spriteName);
            sr.sortingOrder = 0;
        }

        /// <summary>Fasst blockierte Kacheln zeilenweise zu möglichst wenigen BoxCollidern zusammen.</summary>
        private static void AddWallColliders(string[] map)
        {
            var go = new GameObject("Kollision");
            int rows = MapLayouts.Rows(map);
            int cols = MapLayouts.Cols(map);

            for (int row = 0; row < rows; row++)
            {
                int start = -1;
                for (int col = 0; col <= cols; col++)
                {
                    bool blocked = col < cols && MapLayouts.IsBlocked(map[row][col]);
                    if (blocked && start < 0) start = col;
                    if (!blocked && start >= 0)
                    {
                        int length = col - start;
                        var box = go.AddComponent<BoxCollider2D>();
                        box.offset = new Vector2(start + length * 0.5f, (rows - 1 - row) + 0.5f);
                        box.size = new Vector2(length, 1f);
                        start = -1;
                    }
                }
            }
        }

        private static void AddBootstrap(GameData data)
        {
            var bootstrap = new GameObject("Spielleitung").AddComponent<GameBootstrap>();
            SetObjArray(bootstrap, "heroes", new Object[] { data.Aria, data.Milo });
            SetObjArray(bootstrap, "startItems", new Object[] { data.Heiltrank, data.Zaubertrank });
            SetIntArray(bootstrap, "startCounts", new[] { 3, 1 });
        }

        private static GameObject AddPlayer(GameData data, Vector2 position)
        {
            var go = new GameObject("Spieler");
            go.transform.position = position;

            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = data.Aria.fieldSprite;
            sr.sortingOrder = 10;

            var body = go.AddComponent<Rigidbody2D>();
            body.gravityScale = 0f;
            body.constraints = RigidbodyConstraints2D.FreezeRotation;
            body.interpolation = RigidbodyInterpolation2D.Interpolate;
            body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;

            var collider = go.AddComponent<CircleCollider2D>();
            collider.radius = 0.32f;

            go.AddComponent<PlayerController>();
            return go;
        }

        private static void AddCamera(GameObject player, string[] map)
        {
            var go = new GameObject("Hauptkamera");
            go.tag = "MainCamera";
            go.transform.position = new Vector3(player.transform.position.x, player.transform.position.y, -10f);

            var cam = go.AddComponent<Camera>();
            cam.orthographic = true;
            cam.orthographicSize = 4.5f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.03f, 0.03f, 0.06f);
            go.AddComponent<AudioListener>();

            var follow = go.AddComponent<CameraFollow>();
            SetObj(follow, "target", player.transform);
            SetFloat(follow, "mapWidth", MapLayouts.Cols(map));
            SetFloat(follow, "mapHeight", MapLayouts.Rows(map));
        }

        private static void AddSpawn(string[] map, int col, int row, string id)
        {
            AssertWalkable(map, col, row, "Spawnpunkt " + id);
            var spawn = new GameObject("Spawn_" + id).AddComponent<SpawnPoint>();
            spawn.transform.position = MapLayouts.CellCenter(map, col, row);
            SetString(spawn, "id", id);
        }

        private static void AddPortal(string[] map, int col, int row, string targetScene, string targetSpawnId)
        {
            AssertWalkable(map, col, row, "Portal nach " + targetScene);
            var go = new GameObject("Portal_" + targetScene);
            go.transform.position = MapLayouts.CellCenter(map, col, row);

            var box = go.AddComponent<BoxCollider2D>();
            box.isTrigger = true;
            box.size = new Vector2(0.9f, 0.9f);

            var portal = go.AddComponent<PortalTrigger>();
            SetString(portal, "targetScene", targetScene);
            SetString(portal, "targetSpawnId", targetSpawnId);
        }

        private static void AddNpc(string[] map, int col, int row, string spriteName, string npcName, string[] lines, bool healsParty)
        {
            var npc = AddNpcBase(map, col, row, spriteName, npcName).AddComponent<NpcDialogue>();
            SetString(npc, "hintText", "[E] Sprechen");
            SetString(npc, "npcName", npcName);
            SetStringArray(npc, "lines", lines);
            SetBool(npc, "healsParty", healsParty);
        }

        private static void AddShop(string[] map, int col, int row, string spriteName, string shopName, ItemDefinition[] wares)
        {
            var keeper = AddNpcBase(map, col, row, spriteName, shopName).AddComponent<ShopKeeper>();
            SetString(keeper, "hintText", "[E] Handeln");
            SetString(keeper, "shopName", shopName);
            var objects = new Object[wares.Length];
            for (int i = 0; i < wares.Length; i++) objects[i] = wares[i];
            SetObjArray(keeper, "wares", objects);
        }

        private static GameObject AddNpcBase(string[] map, int col, int row, string spriteName, string name)
        {
            AssertWalkable(map, col, row, "NPC " + name);
            var go = new GameObject("NPC_" + name);
            go.transform.position = MapLayouts.CellCenter(map, col, row);

            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = LoadSprite(spriteName);
            sr.sortingOrder = 5;

            var collider = go.AddComponent<CircleCollider2D>();
            collider.radius = 0.42f;
            return go;
        }

        private static void AssertWalkable(string[] map, int col, int row, string what)
        {
            if (MapLayouts.IsBlocked(map[row][col]))
            {
                Debug.LogError("RPG Fable: " + what + " liegt auf blockierter Kachel (" + col + "," + row + ") '" + map[row][col] + "'.");
            }
        }

        // ------------------------------------------------------------------
        // Feld-UI (Hinweis, Dialog, Shop)
        // ------------------------------------------------------------------

        private static void BuildFieldUi()
        {
            var canvas = MakeCanvas("FeldUI");
            var ui = canvas.gameObject.AddComponent<FieldUI>();

            var hint = MakeText(canvas.transform, "Hinweis",
                new Vector2(0f, 0.02f), new Vector2(1f, 0.09f), Vector2.zero, Vector2.zero,
                24, TextAnchor.MiddleCenter);
            hint.gameObject.AddComponent<Shadow>().effectDistance = new Vector2(1.5f, -1.5f);

            var dialoguePanel = MakePanel(canvas.transform, "Dialogfenster",
                new Vector2(0.14f, 0.02f), new Vector2(0.86f, 0.30f));
            var dialogueName = MakeText(dialoguePanel.transform, "Sprechername",
                new Vector2(0f, 0.68f), Vector2.one, new Vector2(24f, 0f), new Vector2(-24f, -8f),
                24, TextAnchor.MiddleLeft);
            dialogueName.fontStyle = FontStyle.Bold;
            var dialogueBody = MakeText(dialoguePanel.transform, "Dialogtext",
                Vector2.zero, new Vector2(1f, 0.72f), new Vector2(24f, 12f), new Vector2(-24f, 0f),
                22, TextAnchor.UpperLeft);

            var shopPanel = MakePanel(canvas.transform, "Shopfenster",
                new Vector2(0.22f, 0.16f), new Vector2(0.78f, 0.86f));
            var shopList = MakeText(shopPanel.transform, "Warenliste",
                new Vector2(0f, 0.30f), new Vector2(0.62f, 1f), new Vector2(28f, 0f), new Vector2(0f, -16f),
                22, TextAnchor.UpperLeft);
            var shopGold = MakeText(shopPanel.transform, "Goldanzeige",
                new Vector2(0.60f, 0.82f), Vector2.one, Vector2.zero, new Vector2(-28f, -16f),
                22, TextAnchor.UpperRight);
            var shopInfo = MakeText(shopPanel.transform, "Warenbeschreibung",
                Vector2.zero, new Vector2(1f, 0.32f), new Vector2(28f, 16f), new Vector2(-28f, 0f),
                20, TextAnchor.UpperLeft);

            SetObj(ui, "hintLabel", hint);
            SetObj(ui, "dialoguePanel", dialoguePanel.gameObject);
            SetObj(ui, "dialogueNameLabel", dialogueName);
            SetObj(ui, "dialogueBodyLabel", dialogueBody);
            SetObj(ui, "shopPanel", shopPanel.gameObject);
            SetObj(ui, "shopListLabel", shopList);
            SetObj(ui, "shopGoldLabel", shopGold);
            SetObj(ui, "shopInfoLabel", shopInfo);
        }

        // ------------------------------------------------------------------
        // UI-Grundbausteine
        // ------------------------------------------------------------------

        private static Canvas MakeCanvas(string name)
        {
            var go = new GameObject(name, typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = go.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;

            var scaler = go.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);
            scaler.matchWidthOrHeight = 0.5f;
            return canvas;
        }

        private static Image MakePanel(Transform parent, string name, Vector2 anchorMin, Vector2 anchorMax)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;

            var image = go.AddComponent<Image>();
            image.sprite = LoadSprite("ui_panel");
            image.type = Image.Type.Sliced;
            image.pixelsPerUnitMultiplier = 0.5f;
            return image;
        }

        private static Text MakeText(Transform parent, string name, Vector2 anchorMin, Vector2 anchorMax,
            Vector2 offsetMin, Vector2 offsetMax, int fontSize, TextAnchor alignment)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = offsetMin;
            rt.offsetMax = offsetMax;

            var text = go.AddComponent<Text>();
            text.font = UiFont();
            text.fontSize = fontSize;
            text.alignment = alignment;
            text.color = new Color(0.95f, 0.94f, 0.88f);
            text.horizontalOverflow = HorizontalWrapMode.Wrap;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            text.supportRichText = false;
            return text;
        }

        private static Font UiFont()
        {
            Font font = null;
            try { font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); }
            catch { }
            if (font == null)
            {
                try { font = Resources.GetBuiltinResource<Font>("Arial.ttf"); }
                catch { }
            }
            return font;
        }

        // ------------------------------------------------------------------
        // Serialisierte (private) Felder über SerializedObject setzen
        // ------------------------------------------------------------------

        private static SerializedProperty FindProp(Component component, string field, out SerializedObject so)
        {
            so = new SerializedObject(component);
            var prop = so.FindProperty(field);
            if (prop == null)
            {
                Debug.LogError("RPG Fable: Feld '" + field + "' an " + component.GetType().Name + " nicht gefunden.");
            }
            return prop;
        }

        private static void SetObj(Component component, string field, Object value)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.objectReferenceValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetString(Component component, string field, string value)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.stringValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetFloat(Component component, string field, float value)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.floatValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetBool(Component component, string field, bool value)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.boolValue = value;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetObjArray(Component component, string field, IList<Object> values)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.arraySize = values.Count;
            for (int i = 0; i < values.Count; i++)
            {
                prop.GetArrayElementAtIndex(i).objectReferenceValue = values[i];
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetStringArray(Component component, string field, IList<string> values)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.arraySize = values.Count;
            for (int i = 0; i < values.Count; i++)
            {
                prop.GetArrayElementAtIndex(i).stringValue = values[i];
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetIntArray(Component component, string field, IList<int> values)
        {
            SerializedObject so;
            var prop = FindProp(component, field, out so);
            if (prop == null) return;
            prop.arraySize = values.Count;
            for (int i = 0; i < values.Count; i++)
            {
                prop.GetArrayElementAtIndex(i).intValue = values[i];
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        // ------------------------------------------------------------------
        // Speichern und Build-Einstellungen
        // ------------------------------------------------------------------

        private static void SaveScene(string name)
        {
            Directory.CreateDirectory(SceneFolder);
            EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(), SceneFolder + "/" + name + ".unity");
        }

        private static void RegisterScenesInBuildSettings()
        {
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(SceneFolder + "/Stadt.unity", true),
                new EditorBuildSettingsScene(SceneFolder + "/Weltkarte.unity", true),
                new EditorBuildSettingsScene(SceneFolder + "/Dungeon.unity", true),
                new EditorBuildSettingsScene(SceneFolder + "/Kampf.unity", true),
            };
        }
    }
}
