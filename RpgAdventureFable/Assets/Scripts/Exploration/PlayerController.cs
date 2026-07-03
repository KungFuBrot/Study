using UnityEngine;
using UnityEngine.SceneManagement;
using RpgFable.Core;
using RpgFable.UI;

namespace RpgFable.Exploration
{
    /// <summary>
    /// Steuert die Heldengruppe auf Stadt-, Weltkarten- und Dungeon-Karten.
    /// Bewegung über Rigidbody2D (Pfeiltasten/WASD), Interaktion mit [E].
    /// </summary>
    [RequireComponent(typeof(Rigidbody2D))]
    public class PlayerController : MonoBehaviour
    {
        [SerializeField] private float moveSpeed = 4f;
        [SerializeField] private float interactRadius = 1.3f;

        private Rigidbody2D body;
        private Vector2 moveInput;
        private Interactable currentInteractable;

        private void Awake()
        {
            body = GetComponent<Rigidbody2D>();
        }

        private void Start()
        {
            PlaceAtSpawn();
        }

        /// <summary>Setzt die Figur an die richtige Startposition (Portal-Spawn oder Kampf-Rückkehr).</summary>
        private void PlaceAtSpawn()
        {
            string sceneName = SceneManager.GetActiveScene().name;

            if (GameState.HasReturnPosition && GameState.ReturnScene == sceneName)
            {
                transform.position = GameState.ReturnPosition;
                GameState.HasReturnPosition = false;
                GameState.NextSpawnId = null;
                return;
            }

            if (!string.IsNullOrEmpty(GameState.NextSpawnId))
            {
                var spawns = FindObjectsOfType<SpawnPoint>();
                foreach (var spawn in spawns)
                {
                    if (spawn.Id == GameState.NextSpawnId)
                    {
                        transform.position = spawn.transform.position;
                        break;
                    }
                }
                GameState.NextSpawnId = null;
            }
        }

        private void Update()
        {
            var ui = FieldUI.Instance;
            bool locked = ui != null && ui.IsBusy;

            if (locked)
            {
                moveInput = Vector2.zero;
            }
            else
            {
                moveInput = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
                if (moveInput.sqrMagnitude > 1f) moveInput.Normalize();
            }

            UpdateInteraction(locked, ui);
        }

        private void FixedUpdate()
        {
#if UNITY_6000_0_OR_NEWER
            body.linearVelocity = moveInput * moveSpeed;
#else
            body.velocity = moveInput * moveSpeed;
#endif
        }

        private void UpdateInteraction(bool locked, FieldUI ui)
        {
            currentInteractable = null;

            if (!locked)
            {
                var hits = Physics2D.OverlapCircleAll(transform.position, interactRadius);
                float best = float.MaxValue;
                foreach (var hit in hits)
                {
                    var interactable = hit.GetComponent<Interactable>();
                    if (interactable == null) continue;
                    float distance = (hit.transform.position - transform.position).sqrMagnitude;
                    if (distance < best)
                    {
                        best = distance;
                        currentInteractable = interactable;
                    }
                }
            }

            if (ui != null)
            {
                ui.SetHint(currentInteractable != null ? currentInteractable.HintText : null);
            }

            if (!locked && currentInteractable != null && Input.GetKeyDown(KeyCode.E))
            {
                currentInteractable.Interact();
            }
        }
    }
}
