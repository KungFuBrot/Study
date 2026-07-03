using System.Collections.Generic;
using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Holds everything that must survive a scene change: the party, gold, inventory
    /// and the data needed to hand off into/out of a battle. Plain static class (no
    /// DontDestroyOnLoad singleton needed) - it lazily initializes itself the first
    /// time any scene touches it, loading hero/item templates from Resources.
    /// </summary>
    public static class GameState
    {
        public static List<PartyMember> Party { get; private set; }
        public static int Gold { get; private set; }
        public static Dictionary<ItemDefinition, int> Inventory { get; private set; }

        // Hand-off data used when entering/leaving the battle scene.
        public static List<EnemyDefinition> PendingEnemyGroup;
        public static string ReturnScene;
        public static Vector2Int? ReturnCell;

        // Which named spawn point the next overworld scene should place the player at.
        public static string NextSpawnId = "Default";

        private static bool _initialized;

        public static void EnsureInitialized()
        {
            if (_initialized) return;
            _initialized = true;

            Gold = 50;
            Inventory = new Dictionary<ItemDefinition, int>();
            Party = new List<PartyMember>();

            var heroes = Resources.LoadAll<HeroDefinition>("Data");
            foreach (var hero in heroes)
            {
                Party.Add(new PartyMember(hero));
            }

            var startPotion = Resources.Load<ItemDefinition>("Data/Item_KleinerTrank");
            if (startPotion != null) Inventory[startPotion] = 2;
        }

        public static bool PartyHasSurvivors()
        {
            foreach (var member in Party)
            {
                if (member.IsAlive) return true;
            }
            return false;
        }

        public static void AddGold(int amount)
        {
            Gold = Mathf.Max(0, Gold + amount);
        }

        public static bool TrySpendGold(int amount)
        {
            if (Gold < amount) return false;
            Gold -= amount;
            return true;
        }

        public static void AddItem(ItemDefinition item, int count = 1)
        {
            if (!Inventory.ContainsKey(item)) Inventory[item] = 0;
            Inventory[item] += count;
        }

        public static bool UseItemOn(ItemDefinition item, PartyMember target)
        {
            if (!Inventory.TryGetValue(item, out int count) || count <= 0) return false;

            switch (item.effectType)
            {
                case ItemEffectType.HealHp:
                    target.Heal(item.amount);
                    break;
                case ItemEffectType.HealMp:
                    target.RestoreMp(item.amount);
                    break;
            }

            Inventory[item] = count - 1;
            return true;
        }

        public static void ClearPendingEncounter()
        {
            PendingEnemyGroup = null;
        }
    }
}
