using UnityEngine;

namespace RpgFable.Exploration
{
    /// <summary>Benannter Startpunkt, an dem die Gruppe nach einem Szenenwechsel erscheint.</summary>
    public class SpawnPoint : MonoBehaviour
    {
        [SerializeField] private string id = "Start";

        public string Id { get { return id; } }
    }
}
