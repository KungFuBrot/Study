using UnityEngine;
using RpgFable.Data;

namespace RpgFable.Core
{
    /// <summary>
    /// Initialisiert den globalen Spielzustand beim ersten Szenenstart.
    /// Liegt in jeder Szene, damit jede Szene auch direkt im Editor
    /// gestartet werden kann.
    /// </summary>
    public class GameBootstrap : MonoBehaviour
    {
        [SerializeField] private HeroDefinition[] heroes;
        [SerializeField] private ItemDefinition[] startItems;
        [SerializeField] private int[] startCounts;
        [SerializeField] private int startGold = 150;

        private void Awake()
        {
            if (!GameState.Initialized)
            {
                GameState.Initialize(heroes, startItems, startCounts, startGold);
            }
        }
    }
}
