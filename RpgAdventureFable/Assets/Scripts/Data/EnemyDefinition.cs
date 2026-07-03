using UnityEngine;

namespace RpgFable.Data
{
    /// <summary>
    /// Grunddaten eines Gegners. Erweiterbar um z. B. Erfahrungspunkte,
    /// Item-Drops oder mehrere Fähigkeiten, ohne bestehende Felder zu ändern.
    /// </summary>
    [CreateAssetMenu(fileName = "Gegner", menuName = "RPG Fable/Gegner")]
    public class EnemyDefinition : ScriptableObject
    {
        public string displayName = "Gegner";

        [Header("Grafik")]
        public Sprite battleSprite;

        [Header("Basiswerte")]
        public int maxHp = 20;
        public int attack = 7;
        public int magic = 4;
        public int defense = 3;
        public int speed = 5;

        [Header("Belohnung")]
        public int goldReward = 5;

        [Header("Optionale Spezialfähigkeit")]
        public AbilityDefinition ability;
        [Range(0f, 1f)] public float abilityChance = 0f;
    }
}
