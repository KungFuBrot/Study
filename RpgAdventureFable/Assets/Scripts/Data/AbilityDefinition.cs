using UnityEngine;

namespace RpgFable.Data
{
    /// <summary>Art der Wirkung einer Fähigkeit.</summary>
    public enum AbilityKind
    {
        PhysicalDamage,
        MagicDamage,
        Heal
    }

    /// <summary>Wen eine Fähigkeit treffen kann.</summary>
    public enum AbilityTarget
    {
        SingleEnemy,
        AllEnemies,
        SingleAlly,
        AllAllies
    }

    /// <summary>
    /// Daten einer Spezialfähigkeit. Bewusst als eigenes Asset ausgelegt,
    /// damit später weitere Fähigkeiten (z. B. per Level freigeschaltet)
    /// ergänzt werden können, ohne Code zu ändern.
    /// </summary>
    [CreateAssetMenu(fileName = "Faehigkeit", menuName = "RPG Fable/Fähigkeit")]
    public class AbilityDefinition : ScriptableObject
    {
        public string displayName = "Neue Fähigkeit";
        [TextArea] public string description = "";
        public AbilityKind kind = AbilityKind.PhysicalDamage;
        public AbilityTarget target = AbilityTarget.SingleEnemy;

        [Tooltip("Grundstärke; wird mit Angriff bzw. Magie des Anwenders verrechnet.")]
        public int power = 10;

        [Tooltip("MP-Kosten beim Einsatz.")]
        public int mpCost = 0;
    }
}
