using UnityEngine;
using UnityEngine.SceneManagement;
using RpgFable.Core;
using RpgFable.Data;
using RpgFable.UI;

namespace RpgFable.Exploration
{
    /// <summary>
    /// Löst beim Umherlaufen zufällige Kämpfe aus (nur in Szenen, in denen
    /// diese Komponente existiert — in der Stadt gibt es sie bewusst nicht).
    /// </summary>
    public class RandomEncounterZone : MonoBehaviour
    {
        [SerializeField] private Transform player;
        [SerializeField] private EncounterTable encounterTable;

        [Tooltip("Nach jeweils so vielen zurückgelegten Einheiten wird gewürfelt.")]
        [SerializeField] private float checkDistance = 1f;

        [Range(0f, 1f)]
        [Tooltip("Wahrscheinlichkeit pro Würfelvorgang.")]
        [SerializeField] private float encounterChance = 0.16f;

        [Tooltip("So viele Einheiten nach Szenenstart passiert garantiert nichts.")]
        [SerializeField] private float graceDistance = 4f;

        private Vector3 lastPosition;
        private float sinceCheck;
        private float sinceSceneStart;
        private bool triggered;

        private void Start()
        {
            if (player != null) lastPosition = player.position;
        }

        private void Update()
        {
            if (triggered || player == null || encounterTable == null) return;

            var ui = FieldUI.Instance;
            if (ui != null && ui.IsBusy)
            {
                lastPosition = player.position;
                return;
            }

            float moved = (player.position - lastPosition).magnitude;
            lastPosition = player.position;
            if (moved <= 0f) return;

            sinceSceneStart += moved;
            if (sinceSceneStart < graceDistance) return;

            sinceCheck += moved;
            if (sinceCheck < checkDistance) return;
            sinceCheck -= checkDistance;

            if (Random.value < encounterChance) StartBattle();
        }

        private void StartBattle()
        {
            var enemies = encounterTable.Roll();
            if (enemies.Count == 0) return;

            triggered = true;
            GameState.PendingEnemies = enemies;
            GameState.ReturnScene = SceneManager.GetActiveScene().name;
            GameState.ReturnPosition = player.position;
            GameState.HasReturnPosition = true;
            SceneManager.LoadScene("Kampf");
        }
    }
}
