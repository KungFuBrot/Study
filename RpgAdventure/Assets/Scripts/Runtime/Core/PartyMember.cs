using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Runtime state of one hero in the party (current HP/MP). The base stats and
    /// abilities come from the shared <see cref="HeroDefinition"/> template asset.
    /// </summary>
    public class PartyMember
    {
        public readonly HeroDefinition definition;
        public int currentHp;
        public int currentMp;

        public PartyMember(HeroDefinition definition)
        {
            this.definition = definition;
            currentHp = definition.maxHp;
            currentMp = definition.maxMp;
        }

        public bool IsAlive => currentHp > 0;

        public void ApplyDamage(int amount)
        {
            currentHp = Mathf.Max(0, currentHp - Mathf.Max(0, amount));
        }

        public void Heal(int amount)
        {
            currentHp = Mathf.Min(definition.maxHp, currentHp + Mathf.Max(0, amount));
        }

        public void RestoreMp(int amount)
        {
            currentMp = Mathf.Min(definition.maxMp, currentMp + Mathf.Max(0, amount));
        }

        public bool TrySpendMp(int amount)
        {
            if (currentMp < amount) return false;
            currentMp -= amount;
            return true;
        }

        public void FullyRestore()
        {
            currentHp = definition.maxHp;
            currentMp = definition.maxMp;
        }
    }
}
