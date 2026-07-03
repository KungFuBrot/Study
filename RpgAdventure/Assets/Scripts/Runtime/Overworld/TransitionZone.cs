using UnityEngine;

namespace RpgAdventure
{
    /// <summary>Stepping onto <see cref="cell"/> loads <see cref="targetScene"/> at the given spawn point.</summary>
    public class TransitionZone : MonoBehaviour
    {
        public Vector2Int cell;
        public string targetScene;
        public string targetSpawnId = "Default";
    }
}
