using System.Collections.Generic;
using UnityEngine;
using RpgFable.Data;

namespace RpgFable.Core
{
    /// <summary>
    /// Laufzeitzustand eines Helden (aktuelle LP/MP).
    /// Hier kann später Level, Erfahrung und Ausrüstung ergänzt werden.
    /// </summary>
    public class HeroRuntime
    {
        public HeroDefinition Definition;
        public int CurrentHp;
        public int CurrentMp;

        public HeroRuntime(HeroDefinition definition)
        {
            Definition = definition;
            CurrentHp = definition.maxHp;
            CurrentMp = definition.maxMp;
        }

        public bool IsAlive { get { return CurrentHp > 0; } }
    }

    /// <summary>Ein Stapel gleicher Gegenstände im Inventar.</summary>
    public class ItemStack
    {
        public ItemDefinition Item;
        public int Count;
    }

    /// <summary>
    /// Globaler Spielzustand, der Szenenwechsel überlebt.
    /// Bewusst als statische Klasse gehalten; ein Speichersystem kann diese
    /// Daten später serialisieren.
    /// </summary>
    public static class GameState
    {
        public static bool Initialized { get; private set; }

        public static readonly List<HeroRuntime> Party = new List<HeroRuntime>();
        public static int Gold;
        public static readonly List<ItemStack> Inventory = new List<ItemStack>();

        // Übergabedaten für die Kampfszene:
        public static List<EnemyDefinition> PendingEnemies;
        public static string ReturnScene;
        public static Vector3 ReturnPosition;
        public static bool HasReturnPosition;

        // Spawnpunkt-Kennung für den nächsten Szenenwechsel:
        public static string NextSpawnId;

        public static void Initialize(IList<HeroDefinition> heroes, IList<ItemDefinition> startItems, IList<int> startCounts, int startGold)
        {
            Party.Clear();
            Inventory.Clear();

            if (heroes != null)
            {
                foreach (var hero in heroes)
                {
                    if (hero != null) Party.Add(new HeroRuntime(hero));
                }
            }

            Gold = startGold;

            if (startItems != null)
            {
                for (int i = 0; i < startItems.Count; i++)
                {
                    if (startItems[i] == null) continue;
                    int count = (startCounts != null && i < startCounts.Count) ? startCounts[i] : 1;
                    AddItem(startItems[i], count);
                }
            }

            PendingEnemies = null;
            ReturnScene = null;
            HasReturnPosition = false;
            NextSpawnId = null;
            Initialized = true;
        }

        public static void AddItem(ItemDefinition item, int count)
        {
            if (item == null || count <= 0) return;
            foreach (var stack in Inventory)
            {
                if (stack.Item == item)
                {
                    stack.Count += count;
                    return;
                }
            }
            Inventory.Add(new ItemStack { Item = item, Count = count });
        }

        public static bool RemoveItem(ItemDefinition item, int count = 1)
        {
            for (int i = 0; i < Inventory.Count; i++)
            {
                if (Inventory[i].Item == item)
                {
                    if (Inventory[i].Count < count) return false;
                    Inventory[i].Count -= count;
                    if (Inventory[i].Count <= 0) Inventory.RemoveAt(i);
                    return true;
                }
            }
            return false;
        }

        /// <summary>Heilt die gesamte Gruppe vollständig (LP und MP).</summary>
        public static void HealParty()
        {
            foreach (var hero in Party)
            {
                hero.CurrentHp = hero.Definition.maxHp;
                hero.CurrentMp = hero.Definition.maxMp;
            }
        }
    }
}
