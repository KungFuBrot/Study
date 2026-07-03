using System.Collections.Generic;
using UnityEngine;

namespace RpgAdventure
{
    [System.Serializable]
    public class EncounterGroup
    {
        public EnemyDefinition[] enemies;
        [Min(1)] public int weight = 1;
    }

    /// <summary>
    /// The set of possible enemy groups a dungeon can throw at the party.
    /// A random group is rolled (weighted) each time a random encounter triggers.
    /// </summary>
    [CreateAssetMenu(fileName = "Encounters_", menuName = "RPG Spiel/Zufallskaempfe")]
    public class EncounterTable : ScriptableObject
    {
        public EncounterGroup[] groups;

        public List<EnemyDefinition> RollGroup()
        {
            if (groups == null || groups.Length == 0) return new List<EnemyDefinition>();

            int totalWeight = 0;
            foreach (var g in groups) totalWeight += Mathf.Max(1, g.weight);

            int roll = Random.Range(0, totalWeight);
            foreach (var g in groups)
            {
                roll -= Mathf.Max(1, g.weight);
                if (roll < 0) return new List<EnemyDefinition>(g.enemies);
            }

            return new List<EnemyDefinition>(groups[groups.Length - 1].enemies);
        }
    }
}
