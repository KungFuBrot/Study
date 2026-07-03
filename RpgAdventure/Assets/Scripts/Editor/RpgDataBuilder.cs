using RpgAdventure;
using UnityEditor;
using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// Creates the hero/ability/enemy/item/encounter ScriptableObject assets used by
    /// the whole game. Heroes/items live under Resources so runtime code (GameState)
    /// can load them without any scene wiring. Run via "RPG Spiel/2. Daten erzeugen".
    /// Safe to re-run - it updates existing assets in place instead of duplicating them.
    /// </summary>
    public static class RpgDataBuilder
    {
        public const string DataFolder = "Assets/Resources/Data";
        private const string CharFolder = "Assets/Sprites/Characters";

        [MenuItem("RPG Spiel/2. Daten erzeugen (Helden, Gegner, Items)")]
        public static void GenerateAll()
        {
            EnsureFolder("Assets/Resources");
            EnsureFolder(DataFolder);

            var ariaSprite = LoadSprite("Char_Aria");
            var elanSprite = LoadSprite("Char_Elan");
            var slimeSprite = LoadSprite("Enemy_Slime");
            var wolfSprite = LoadSprite("Enemy_Wolf");
            var batSprite = LoadSprite("Enemy_Bat");

            if (ariaSprite == null || elanSprite == null || slimeSprite == null)
            {
                EditorUtility.DisplayDialog("RPG Spiel", "Bitte zuerst 'RPG Spiel/1. Bilder erzeugen' ausführen.", "OK");
                return;
            }

            var wirbelschlag = CreateAsset<AbilityDefinition>("Ability_Wirbelschlag", a =>
            {
                a.abilityName = "Wirbelschlag";
                a.description = "Trifft alle Gegner mit einem Schwerthieb.";
                a.mpCost = 4;
                a.power = 6;
                a.effectType = AbilityEffectType.Damage;
                a.targetType = AbilityTargetType.AllEnemies;
            });

            var feuerball = CreateAsset<AbilityDefinition>("Ability_Feuerball", a =>
            {
                a.abilityName = "Feuerball";
                a.description = "Schleudert einen Feuerball auf einen Gegner.";
                a.mpCost = 6;
                a.power = 10;
                a.effectType = AbilityEffectType.Damage;
                a.targetType = AbilityTargetType.SingleEnemy;
            });

            var heilung = CreateAsset<AbilityDefinition>("Ability_Heilung", a =>
            {
                a.abilityName = "Heilung";
                a.description = "Heilt einen Verbündeten.";
                a.mpCost = 5;
                a.power = 12;
                a.effectType = AbilityEffectType.Heal;
                a.targetType = AbilityTargetType.SingleAlly;
            });

            CreateAsset<HeroDefinition>("Hero_Aria", h =>
            {
                h.heroName = "Aria";
                h.description = "Eine mutige Schwertkämpferin.";
                h.sprite = ariaSprite;
                h.maxHp = 42; h.maxMp = 10; h.attack = 12; h.defense = 8; h.magic = 2; h.speed = 6;
                h.abilities = new[] { wirbelschlag };
            });

            CreateAsset<HeroDefinition>("Hero_Elan", h =>
            {
                h.heroName = "Elan";
                h.description = "Ein junger Zauberer, der die Elemente beherrscht.";
                h.sprite = elanSprite;
                h.maxHp = 26; h.maxMp = 24; h.attack = 5; h.defense = 4; h.magic = 10; h.speed = 5;
                h.abilities = new[] { feuerball, heilung };
            });

            var schleim = CreateAsset<EnemyDefinition>("Enemy_Schleim", e =>
            {
                e.enemyName = "Schleim";
                e.sprite = slimeSprite;
                e.maxHp = 18; e.attack = 5; e.defense = 2; e.speed = 3; e.goldMin = 4; e.goldMax = 9;
            });

            var wolf = CreateAsset<EnemyDefinition>("Enemy_Hoehlenwolf", e =>
            {
                e.enemyName = "Höhlenwolf";
                e.sprite = wolfSprite;
                e.maxHp = 26; e.attack = 8; e.defense = 3; e.speed = 7; e.goldMin = 7; e.goldMax = 14;
            });

            var bat = CreateAsset<EnemyDefinition>("Enemy_Fledermaus", e =>
            {
                e.enemyName = "Fledermaus";
                e.sprite = batSprite;
                e.maxHp = 14; e.attack = 6; e.defense = 1; e.speed = 9; e.goldMin = 3; e.goldMax = 8;
            });

            CreateAsset<ItemDefinition>("Item_KleinerTrank", i =>
            {
                i.itemName = "Kleiner Trank";
                i.description = "Heilt 20 HP.";
                i.price = 10;
                i.effectType = ItemEffectType.HealHp;
                i.amount = 20;
            });

            CreateAsset<ItemDefinition>("Item_Manaphiole", i =>
            {
                i.itemName = "Manaphiole";
                i.description = "Füllt 15 MP auf.";
                i.price = 15;
                i.effectType = ItemEffectType.HealMp;
                i.amount = 15;
            });

            CreateAsset<EncounterTable>("Encounters_Dungeon", t =>
            {
                t.groups = new[]
                {
                    new EncounterGroup { enemies = new[] { schleim }, weight = 3 },
                    new EncounterGroup { enemies = new[] { schleim, schleim }, weight = 2 },
                    new EncounterGroup { enemies = new[] { wolf }, weight = 2 },
                    new EncounterGroup { enemies = new[] { bat, bat }, weight = 2 },
                    new EncounterGroup { enemies = new[] { wolf, bat }, weight = 1 },
                };
            });

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.DisplayDialog("RPG Spiel", "Helden, Gegner, Items und Zufallskämpfe wurden erzeugt.", "OK");
        }

        private static T CreateAsset<T>(string name, System.Action<T> configure) where T : ScriptableObject
        {
            string path = DataFolder + "/" + name + ".asset";
            var existing = AssetDatabase.LoadAssetAtPath<T>(path);
            T asset = existing != null ? existing : ScriptableObject.CreateInstance<T>();
            configure(asset);

            if (existing == null)
            {
                AssetDatabase.CreateAsset(asset, path);
            }
            else
            {
                EditorUtility.SetDirty(asset);
            }
            return asset;
        }

        private static Sprite LoadSprite(string name)
        {
            return AssetDatabase.LoadAssetAtPath<Sprite>(CharFolder + "/" + name + ".png");
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            var parts = path.Split('/');
            string current = parts[0];
            for (int i = 1; i < parts.Length; i++)
            {
                string next = current + "/" + parts[i];
                if (!AssetDatabase.IsValidFolder(next)) AssetDatabase.CreateFolder(current, parts[i]);
                current = next;
            }
        }
    }
}
