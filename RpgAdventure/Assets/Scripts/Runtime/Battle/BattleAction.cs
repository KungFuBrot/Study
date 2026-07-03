namespace RpgAdventure
{
    public enum BattleActionType
    {
        Attack,
        Ability,
        Item,
        Flee
    }

    /// <summary>A single resolved choice made during a hero's turn.</summary>
    public class BattleAction
    {
        public BattleActionType type;
        public AbilityDefinition ability;
        public ItemDefinition item;
        public BattleUnit target;
    }
}
