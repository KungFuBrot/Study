using UnityEngine;
using RpgFable.Core;
using RpgFable.UI;

namespace RpgFable.Exploration
{
    /// <summary>Ein NPC, der beim Ansprechen mehrere Dialogzeilen zeigt.</summary>
    public class NpcDialogue : Interactable
    {
        [SerializeField] private string npcName = "Bewohner";
        [SerializeField] [TextArea] private string[] lines;
        [SerializeField] private bool healsParty = false;

        public override void Interact()
        {
            var ui = FieldUI.Instance;
            if (ui == null) return;

            if (healsParty) GameState.HealParty();
            ui.ShowDialogue(npcName, lines);
        }
    }
}
