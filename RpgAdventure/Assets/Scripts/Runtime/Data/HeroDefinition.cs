using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Base stats and abilities of a playable hero. Runtime state (current HP/MP)
    /// lives separately in <see cref="PartyMember"/> so this asset stays a template.
    /// No experience/level fields yet on purpose - stats are flat for now but can be
    /// extended later (e.g. by adding a level curve) without breaking existing saves.
    /// </summary>
    [CreateAssetMenu(fileName = "Hero_", menuName = "RPG Spiel/Held")]
    public class HeroDefinition : ScriptableObject
    {
        public string heroName = "Held";
        [TextArea] public string description = "";
        public Sprite sprite;

        [Header("Basiswerte")]
        public int maxHp = 30;
        public int maxMp = 10;
        public int attack = 8;
        public int defense = 5;
        public int magic = 5;
        public int speed = 5;

        public AbilityDefinition[] abilities;
    }
}
