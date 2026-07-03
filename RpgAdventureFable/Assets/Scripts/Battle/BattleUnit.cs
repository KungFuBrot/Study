using UnityEngine;
using RpgFable.Core;
using RpgFable.Data;

namespace RpgFable.Battle
{
    /// <summary>
    /// Laufzeitdaten eines Kampfteilnehmers (Held oder Gegner)
    /// inklusive Verweis auf seine Darstellung in der Szene.
    /// </summary>
    public class BattleUnit
    {
        public string Name;
        public bool IsHero;

        public HeroRuntime Hero;        // nur bei Helden gesetzt
        public EnemyDefinition Enemy;   // nur bei Gegnern gesetzt

        public int MaxHp;
        public int MaxMp;
        public int CurrentHp;
        public int CurrentMp;
        public int Attack;
        public int Magic;
        public int Defense;
        public int Speed;
        public int GoldReward;

        public SpriteRenderer View;

        public bool IsAlive { get { return CurrentHp > 0; } }

        public static BattleUnit FromHero(HeroRuntime hero)
        {
            var d = hero.Definition;
            return new BattleUnit
            {
                Name = d.displayName,
                IsHero = true,
                Hero = hero,
                MaxHp = d.maxHp,
                MaxMp = d.maxMp,
                CurrentHp = hero.CurrentHp,
                CurrentMp = hero.CurrentMp,
                Attack = d.attack,
                Magic = d.magic,
                Defense = d.defense,
                Speed = d.speed
            };
        }

        public static BattleUnit FromEnemy(EnemyDefinition enemy, string uniqueName)
        {
            return new BattleUnit
            {
                Name = uniqueName,
                IsHero = false,
                Enemy = enemy,
                MaxHp = enemy.maxHp,
                MaxMp = 0,
                CurrentHp = enemy.maxHp,
                CurrentMp = 0,
                Attack = enemy.attack,
                Magic = enemy.magic,
                Defense = enemy.defense,
                Speed = enemy.speed,
                GoldReward = enemy.goldReward
            };
        }
    }
}
