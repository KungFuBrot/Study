using UnityEngine;

namespace RpgFable.Exploration
{
    /// <summary>
    /// Folgt der Spielfigur und hält die Kamera innerhalb der Kartengrenzen.
    /// Die Karte beginnt bei (0,0) und ist mapWidth × mapHeight Einheiten groß.
    /// </summary>
    [RequireComponent(typeof(Camera))]
    public class CameraFollow : MonoBehaviour
    {
        [SerializeField] private Transform target;
        [SerializeField] private float mapWidth = 20f;
        [SerializeField] private float mapHeight = 15f;
        [SerializeField] private float smoothTime = 0.12f;

        private Camera cam;
        private Vector3 velocity;

        private void Awake()
        {
            cam = GetComponent<Camera>();
        }

        private void Start()
        {
            if (target != null) transform.position = ClampedTarget();
        }

        private void LateUpdate()
        {
            if (target == null) return;
            transform.position = Vector3.SmoothDamp(transform.position, ClampedTarget(), ref velocity, smoothTime);
        }

        private Vector3 ClampedTarget()
        {
            float halfH = cam.orthographicSize;
            float halfW = halfH * cam.aspect;

            Vector3 p = target.position;
            p.x = mapWidth <= halfW * 2f ? mapWidth * 0.5f : Mathf.Clamp(p.x, halfW, mapWidth - halfW);
            p.y = mapHeight <= halfH * 2f ? mapHeight * 0.5f : Mathf.Clamp(p.y, halfH, mapHeight - halfH);
            p.z = -10f;
            return p;
        }
    }
}
