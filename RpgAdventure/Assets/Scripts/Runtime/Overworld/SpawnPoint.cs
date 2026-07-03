using UnityEngine;

namespace RpgAdventure
{
    /// <summary>A named cell the player can be placed at when entering a scene.</summary>
    public class SpawnPoint : MonoBehaviour
    {
        public string spawnId = "Default";
        public Vector2Int cell;
    }
}
