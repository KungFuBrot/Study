using UnityEngine;

namespace RpgAdventure
{
    public enum ItemEffectType
    {
        HealHp,
        HealMp
    }

    /// <summary>
    /// A consumable that can be bought from the shop and used from the battle menu.
    /// </summary>
    [CreateAssetMenu(fileName = "Item_", menuName = "RPG Spiel/Gegenstand")]
    public class ItemDefinition : ScriptableObject
    {
        public string itemName = "Gegenstand";
        [TextArea] public string description = "";
        public Sprite icon;
        public int price = 10;
        public ItemEffectType effectType = ItemEffectType.HealHp;
        public int amount = 20;
    }
}
