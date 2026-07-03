using UnityEngine;

namespace RpgAdventure
{
    public enum AbilityTargetType
    {
        SingleEnemy,
        AllEnemies,
        SingleAlly,
        AllAllies,
        Self
    }

    public enum AbilityEffectType
    {
        Damage,
        Heal
    }

    /// <summary>
    /// A special skill a hero can use in battle instead of a basic attack.
    /// Data-only asset so new abilities can be added later without touching code.
    /// </summary>
    [CreateAssetMenu(fileName = "Ability_", menuName = "RPG Spiel/Faehigkeit")]
    public class AbilityDefinition : ScriptableObject
    {
        public string abilityName = "Fähigkeit";
        [TextArea] public string description = "";
        public int mpCost = 5;
        public int power = 8;
        public AbilityEffectType effectType = AbilityEffectType.Damage;
        public AbilityTargetType targetType = AbilityTargetType.SingleEnemy;
    }
}
