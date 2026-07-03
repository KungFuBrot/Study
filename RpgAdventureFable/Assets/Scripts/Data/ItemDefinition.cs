using UnityEngine;

namespace RpgFable.Data
{
    /// <summary>Wirkung eines Gegenstands.</summary>
    public enum ItemEffect
    {
        HealHp,
        RestoreMp
    }

    /// <summary>
    /// Daten eines Gegenstands. Erweiterbar um weitere Effekte
    /// (Statusheilung, Ausrüstung, Questgegenstände usw.).
    /// </summary>
    [CreateAssetMenu(fileName = "Gegenstand", menuName = "RPG Fable/Gegenstand")]
    public class ItemDefinition : ScriptableObject
    {
        public string displayName = "Gegenstand";
        [TextArea] public string description = "";

        [Tooltip("Kaufpreis im Shop in Gold.")]
        public int price = 10;

        public ItemEffect effect = ItemEffect.HealHp;

        [Tooltip("Stärke des Effekts (z. B. geheilte LP).")]
        public int amount = 30;
    }
}
