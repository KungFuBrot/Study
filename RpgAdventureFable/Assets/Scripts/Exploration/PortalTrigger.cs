using UnityEngine;
using UnityEngine.SceneManagement;
using RpgFable.Core;

namespace RpgFable.Exploration
{
    /// <summary>
    /// Szenenübergang: Betritt die Spielfigur den Trigger, wird die Zielszene
    /// geladen und die Gruppe dort am angegebenen Spawnpunkt platziert.
    /// </summary>
    [RequireComponent(typeof(BoxCollider2D))]
    public class PortalTrigger : MonoBehaviour
    {
        [SerializeField] private string targetScene = "Weltkarte";
        [SerializeField] private string targetSpawnId = "Start";

        private bool triggered;

        private void OnTriggerEnter2D(Collider2D other)
        {
            if (triggered) return;
            if (other.GetComponent<PlayerController>() == null) return;

            triggered = true;
            GameState.NextSpawnId = targetSpawnId;
            GameState.HasReturnPosition = false;
            SceneManager.LoadScene(targetScene);
        }
    }
}
