using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace RpgAdventure
{
    /// <summary>
    /// Drives grid movement, NPC/shop interaction, scene transitions and (optionally)
    /// random encounters for one overworld scene (town / world map / dungeon). The
    /// scene builder wires up all references at edit time.
    /// </summary>
    public class OverworldController : MonoBehaviour
    {
        [Header("Grid & Player")]
        [SerializeField] private MapGrid mapGrid;
        [SerializeField] private Transform playerTransform;
        [SerializeField] private SpriteRenderer playerSpriteRenderer;
        [SerializeField] private Sprite playerSprite;
        [SerializeField] private float moveDuration = 0.14f;

        [Header("Entities")]
        [SerializeField] private SpawnPoint[] spawnPoints;
        [SerializeField] private TransitionZone[] transitions;
        [SerializeField] private Npc[] npcs;
        [SerializeField] private Shop[] shops;

        [Header("Random Encounters (Dungeon only)")]
        [SerializeField] private bool encountersEnabled;
        [SerializeField] private EncounterTable encounterTable;
        [SerializeField] private float encounterChancePerStep = 0.09f;

        [Header("UI")]
        [SerializeField] private DialogueUI dialogueUI;
        [SerializeField] private ShopUI shopUI;
        [SerializeField] private OverworldHudUI hud;

        private Vector2Int _cell;
        private Vector2Int _facing = new Vector2Int(0, 1);
        private bool _moving;

        private void Start()
        {
            GameState.EnsureInitialized();

            _cell = FindSpawnCell();
            if (playerTransform != null && mapGrid != null)
            {
                playerTransform.position = mapGrid.CellToWorld(_cell);
            }
            if (playerSpriteRenderer != null && playerSprite != null)
            {
                playerSpriteRenderer.sprite = playerSprite;
            }

            var camera = Camera.main;
            if (camera != null)
            {
                var follow = camera.GetComponent<CameraFollow2D>();
                if (follow != null) follow.SetTarget(playerTransform);
                if (playerTransform != null)
                {
                    camera.transform.position = new Vector3(playerTransform.position.x, playerTransform.position.y, camera.transform.position.z);
                }
            }

            if (hud != null) hud.Refresh();
        }

        private Vector2Int FindSpawnCell()
        {
            string sceneName = SceneManager.GetActiveScene().name;
            if (GameState.ReturnScene == sceneName && GameState.ReturnCell.HasValue)
            {
                var cell = GameState.ReturnCell.Value;
                GameState.ReturnScene = null;
                GameState.ReturnCell = null;
                return cell;
            }

            if (spawnPoints != null)
            {
                foreach (var sp in spawnPoints)
                {
                    if (sp != null && sp.spawnId == GameState.NextSpawnId) return sp.cell;
                }
                if (spawnPoints.Length > 0 && spawnPoints[0] != null) return spawnPoints[0].cell;
            }

            return Vector2Int.zero;
        }

        private void Update()
        {
            if (_moving) return;

            if (dialogueUI != null && dialogueUI.IsOpen)
            {
                if (Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.E))
                {
                    dialogueUI.Advance();
                }
                return;
            }

            if (shopUI != null && shopUI.IsOpen)
            {
                if (Input.GetKeyDown(KeyCode.Escape)) shopUI.Close();
                return;
            }

            Vector2Int dir = ReadDirection();
            if (dir != Vector2Int.zero)
            {
                _facing = dir;
                UpdateFacingSprite();

                Vector2Int target = _cell + dir;
                if (!IsOccupiedByEntity(target) && mapGrid != null && mapGrid.IsWalkable(target))
                {
                    StartCoroutine(MoveRoutine(target));
                }
            }
            else if (Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.E) || Input.GetKeyDown(KeyCode.Return))
            {
                TryInteract();
            }
        }

        private static Vector2Int ReadDirection()
        {
            if (Input.GetKey(KeyCode.UpArrow) || Input.GetKey(KeyCode.W)) return new Vector2Int(0, -1);
            if (Input.GetKey(KeyCode.DownArrow) || Input.GetKey(KeyCode.S)) return new Vector2Int(0, 1);
            if (Input.GetKey(KeyCode.LeftArrow) || Input.GetKey(KeyCode.A)) return new Vector2Int(-1, 0);
            if (Input.GetKey(KeyCode.RightArrow) || Input.GetKey(KeyCode.D)) return new Vector2Int(1, 0);
            return Vector2Int.zero;
        }

        private void UpdateFacingSprite()
        {
            if (playerSpriteRenderer == null || _facing.x == 0) return;
            playerSpriteRenderer.flipX = _facing.x < 0;
        }

        private bool IsOccupiedByEntity(Vector2Int cell)
        {
            if (npcs != null)
            {
                foreach (var npc in npcs)
                {
                    if (npc != null && npc.cell == cell) return true;
                }
            }
            if (shops != null)
            {
                foreach (var shop in shops)
                {
                    if (shop != null && shop.cell == cell) return true;
                }
            }
            return false;
        }

        private IEnumerator MoveRoutine(Vector2Int target)
        {
            _moving = true;

            Vector3 start = playerTransform.position;
            Vector3 end = mapGrid.CellToWorld(target);
            float t = 0f;
            while (t < moveDuration)
            {
                t += Time.deltaTime;
                playerTransform.position = Vector3.Lerp(start, end, t / moveDuration);
                yield return null;
            }
            playerTransform.position = end;
            _cell = target;
            _moving = false;

            if (!TryTransition())
            {
                TryRandomEncounter();
            }
        }

        private bool TryTransition()
        {
            if (transitions == null) return false;
            foreach (var zone in transitions)
            {
                if (zone != null && zone.cell == _cell)
                {
                    GameState.NextSpawnId = zone.targetSpawnId;
                    SceneManager.LoadScene(zone.targetScene);
                    return true;
                }
            }
            return false;
        }

        private void TryRandomEncounter()
        {
            if (!encountersEnabled || encounterTable == null || mapGrid == null) return;
            if (!mapGrid.IsEncounterZone(_cell)) return;
            if (Random.value >= encounterChancePerStep) return;

            var group = encounterTable.RollGroup();
            if (group.Count == 0) return;

            GameState.PendingEnemyGroup = group;
            GameState.ReturnScene = SceneManager.GetActiveScene().name;
            GameState.ReturnCell = _cell;
            SceneManager.LoadScene("BattleScene");
        }

        private void TryInteract()
        {
            Vector2Int target = _cell + _facing;

            if (npcs != null)
            {
                foreach (var npc in npcs)
                {
                    if (npc != null && npc.cell == target)
                    {
                        dialogueUI?.Show(npc.npcName, npc.dialogueLines);
                        return;
                    }
                }
            }

            if (shops != null)
            {
                foreach (var shop in shops)
                {
                    if (shop != null && shop.cell == target)
                    {
                        shopUI?.Open(shop);
                        return;
                    }
                }
            }
        }
    }
}
