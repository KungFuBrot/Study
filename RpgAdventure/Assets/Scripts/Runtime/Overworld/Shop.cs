using UnityEngine;

namespace RpgAdventure
{
    /// <summary>A shopkeeper standing on a fixed cell who opens the shop UI on interact.</summary>
    public class Shop : MonoBehaviour
    {
        public string shopName = "Laden";
        public Vector2Int cell;
        public ItemDefinition[] itemsForSale;
    }
}
