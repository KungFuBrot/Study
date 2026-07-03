using UnityEngine;

namespace RpgFable.Data
{
    /// <summary>
    /// Grunddaten eines Helden. Enthält bewusst nur Basiswerte:
    /// Ein späteres Level-/Erfahrungssystem kann hier z. B. Wachstumskurven
    /// ergänzen (Werte pro Level), ohne dass bestehender Code bricht.
    /// </summary>
    [CreateAssetMenu(fileName = "Held", menuName = "RPG Fable/Held")]
    public class HeroDefinition : ScriptableObject
    {
        public string displayName = "Held";
        public string className = "Klasse";
        [TextArea] public string description = "";

        [Header("Grafik")]
        public Sprite fieldSprite;
        public Sprite battleSprite;

        [Header("Basiswerte")]
        public int maxHp = 30;
        public int maxMp = 10;
        public int attack = 8;
        public int magic = 8;
        public int defense = 5;
        public int speed = 6;

        [Header("Spezialfähigkeiten")]
        public AbilityDefinition[] abilities;
    }
}
