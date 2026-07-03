using System.Collections.Generic;
using UnityEngine;

namespace RpgFable.Data
{
    /// <summary>Ein möglicher Zufallskampf: Gegnertyp, Anzahl und Gewichtung.</summary>
    [System.Serializable]
    public class EncounterEntry
    {
        public EnemyDefinition enemy;
        public int minCount = 1;
        public int maxCount = 1;
        [Tooltip("Relative Wahrscheinlichkeit gegenüber den anderen Einträgen.")]
        public int weight = 1;
    }

    /// <summary>
    /// Tabelle für Random Encounters. Pro Gebiet (z. B. Dungeon-Ebene)
    /// kann eine eigene Tabelle angelegt werden.
    /// </summary>
    [CreateAssetMenu(fileName = "Begegnungen", menuName = "RPG Fable/Begegnungstabelle")]
    public class EncounterTable : ScriptableObject
    {
        public EncounterEntry[] entries;

        /// <summary>Würfelt eine Gegnergruppe aus der Tabelle aus.</summary>
        public List<EnemyDefinition> Roll()
        {
            var result = new List<EnemyDefinition>();
            if (entries == null || entries.Length == 0) return result;

            int total = 0;
            foreach (var e in entries) total += Mathf.Max(0, e.weight);

            EncounterEntry chosen = entries[0];
            int pick = Random.Range(0, Mathf.Max(1, total));
            foreach (var e in entries)
            {
                pick -= Mathf.Max(0, e.weight);
                if (pick < 0) { chosen = e; break; }
            }

            if (chosen.enemy == null) return result;
            int count = Random.Range(chosen.minCount, chosen.maxCount + 1);
            for (int i = 0; i < Mathf.Max(1, count); i++) result.Add(chosen.enemy);
            return result;
        }
    }
}
