using UnityEngine;

namespace RpgAdventure
{
    /// <summary>
    /// Walkability/encounter lookup for a scene's tile grid. Purely data - the visual
    /// tile GameObjects are placed separately by the scene builder; both are derived
    /// from the same ASCII layout so they always agree.
    /// </summary>
    public class MapGrid : MonoBehaviour
    {
        [SerializeField] private int width;
        [SerializeField] private int height;
        [SerializeField] private float cellSize = 1f;
        [SerializeField] private bool[] walkableFlat;
        [SerializeField] private bool[] encounterFlat;

        public int Width => width;
        public int Height => height;
        public float CellSize => cellSize;

        public void Configure(int w, int h, float cell, bool[] walkable, bool[] encounter)
        {
            width = w;
            height = h;
            cellSize = cell;
            walkableFlat = walkable;
            encounterFlat = encounter;
        }

        public bool IsInside(Vector2Int cell)
        {
            return cell.x >= 0 && cell.y >= 0 && cell.x < width && cell.y < height;
        }

        public bool IsWalkable(Vector2Int cell)
        {
            if (!IsInside(cell) || walkableFlat == null) return false;
            return walkableFlat[cell.y * width + cell.x];
        }

        public bool IsEncounterZone(Vector2Int cell)
        {
            if (!IsInside(cell) || encounterFlat == null) return false;
            return encounterFlat[cell.y * width + cell.x];
        }

        public Vector3 CellToWorld(Vector2Int cell)
        {
            return new Vector3(cell.x * cellSize, -cell.y * cellSize, 0f);
        }
    }
}
