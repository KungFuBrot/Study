using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Uniform battle-time view over either a party member or an enemy instance,
    /// so combat code doesn't need to branch on hero-vs-enemy everywhere.
    /// </summary>
    public class BattleUnit
    {
        public readonly bool isHero;
        public readonly PartyMember heroMember;
        public readonly EnemyDefinition enemyDef;

        public int CurrentHp { get; private set; }
        public int CurrentMp { get; private set; }

        private BattleUnit(PartyMember member)
        {
            isHero = true;
            heroMember = member;
            enemyDef = null;
            SyncFromHeroMember();
        }

        private BattleUnit(EnemyDefinition def)
        {
            isHero = false;
            heroMember = null;
            enemyDef = def;
            CurrentHp = def.maxHp;
            CurrentMp = 0;
        }

        public static BattleUnit ForHero(PartyMember member) => new BattleUnit(member);
        public static BattleUnit ForEnemy(EnemyDefinition def) => new BattleUnit(def);

        public string Name => isHero ? heroMember.definition.heroName : enemyDef.enemyName;
        public int MaxHp => isHero ? heroMember.definition.maxHp : enemyDef.maxHp;
        public int MaxMp => isHero ? heroMember.definition.maxMp : 0;
        public int Attack => isHero ? heroMember.definition.attack : enemyDef.attack;
        public int Defense => isHero ? heroMember.definition.defense : enemyDef.defense;
        public int Magic => isHero ? heroMember.definition.magic : 0;
        public int Speed => isHero ? heroMember.definition.speed : enemyDef.speed;
        public Sprite Sprite => isHero ? heroMember.definition.sprite : enemyDef.sprite;
        public bool IsAlive => CurrentHp > 0;

        public void SyncFromHeroMember()
        {
            if (!isHero) return;
            CurrentHp = heroMember.currentHp;
            CurrentMp = heroMember.currentMp;
        }

        public void ApplyDamage(int amount)
        {
            CurrentHp = Mathf.Max(0, CurrentHp - Mathf.Max(0, amount));
            if (isHero) heroMember.currentHp = CurrentHp;
        }

        public void Heal(int amount)
        {
            CurrentHp = Mathf.Min(MaxHp, CurrentHp + Mathf.Max(0, amount));
            if (isHero) heroMember.currentHp = CurrentHp;
        }

        public bool TrySpendMp(int amount)
        {
            if (CurrentMp < amount) return false;
            CurrentMp -= amount;
            if (isHero) heroMember.currentMp = CurrentMp;
            return true;
        }
    }
}
