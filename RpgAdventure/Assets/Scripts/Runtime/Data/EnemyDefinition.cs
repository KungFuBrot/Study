using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Base stats of an enemy species encountered in the dungeon. A battle creates a
    /// fresh <see cref="BattleUnit"/> from this template, so the asset itself never
    /// changes at runtime and can safely be reused across many fights.
    /// </summary>
    [CreateAssetMenu(fileName = "Enemy_", menuName = "RPG Spiel/Gegner")]
    public class EnemyDefinition : ScriptableObject
    {
        public string enemyName = "Gegner";
        public Sprite sprite;

        [Header("Basiswerte")]
        public int maxHp = 20;
        public int attack = 6;
        public int defense = 2;
        public int speed = 4;

        [Header("Belohnung")]
        public int goldMin = 4;
        public int goldMax = 10;
    }
}
