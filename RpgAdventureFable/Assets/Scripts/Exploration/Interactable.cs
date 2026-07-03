using UnityEngine;

namespace RpgFable.Exploration
{
    /// <summary>Basisklasse für alles, womit die Spielfigur per [E] interagieren kann.</summary>
    public abstract class Interactable : MonoBehaviour
    {
        [SerializeField] private string hintText = "[E] Sprechen";

        public string HintText { get { return hintText; } }

        public abstract void Interact();
    }
}
