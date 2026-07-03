using UnityEngine;

namespace RpgAdventure.EditorTools
{
    /// <summary>
    /// 2D signed-distance-field shape functions (classic analytic formulas), used to
    /// rasterize crisp, anti-aliased sprite shapes directly into textures at edit time.
    /// All shapes are centred on the origin and sized for a [-1, 1] canvas.
    /// </summary>
    public static class Sdf
    {
        public static float Circle(Vector2 p, float r) => p.magnitude - r;

        public static float Ellipse(Vector2 p, float rx, float ry)
        {
            float k = Mathf.Min(rx, ry);
            Vector2 q = new Vector2(p.x / rx, p.y / ry);
            return (q.magnitude - 1f) * k;
        }

        public static float RoundedBox(Vector2 p, Vector2 b, float r)
        {
            Vector2 q = new Vector2(Mathf.Abs(p.x) - b.x + r, Mathf.Abs(p.y) - b.y + r);
            float outside = new Vector2(Mathf.Max(q.x, 0f), Mathf.Max(q.y, 0f)).magnitude;
            float inside = Mathf.Min(Mathf.Max(q.x, q.y), 0f);
            return outside + inside - r;
        }

        private static float Ndot(Vector2 a, Vector2 b) => a.x * b.x - a.y * b.y;

        public static float Rhombus(Vector2 p, Vector2 b)
        {
            Vector2 q = new Vector2(Mathf.Abs(p.x), Mathf.Abs(p.y));
            float h = Mathf.Clamp((-2f * Ndot(q, b) + Ndot(b, b)) / Vector2.Dot(b, b), -1f, 1f);
            Vector2 inner = new Vector2(1f - h, 1f + h) * 0.5f;
            Vector2 diff = new Vector2(q.x - b.x * inner.x, q.y - b.y * inner.y);
            float d = diff.magnitude;
            return d * Mathf.Sign(q.x * b.y + q.y * b.x - b.x * b.y);
        }

        public static float Star5(Vector2 p, float r, float rf)
        {
            Vector2 k1 = new Vector2(0.809016994375f, -0.587785252292f);
            Vector2 k2 = new Vector2(-k1.x, k1.y);

            p.x = Mathf.Abs(p.x);
            p -= 2f * Mathf.Max(Vector2.Dot(k1, p), 0f) * k1;
            p -= 2f * Mathf.Max(Vector2.Dot(k2, p), 0f) * k2;
            p.x = Mathf.Abs(p.x);
            p.y -= r;

            Vector2 ba = rf * new Vector2(-k1.y, k1.x) - new Vector2(0f, 1f);
            float h = Mathf.Clamp(Vector2.Dot(p, ba) / Vector2.Dot(ba, ba), 0f, r);
            Vector2 diff = p - ba * h;
            return diff.magnitude * Mathf.Sign(p.y * ba.x - p.x * ba.y);
        }

        public static float Hexagon(Vector2 p, float r)
        {
            Vector2 k = new Vector2(-0.866025404f, 0.5f);
            const float kz = 0.577350269f;

            p = new Vector2(Mathf.Abs(p.x), Mathf.Abs(p.y));
            p -= 2f * Mathf.Min(Vector2.Dot(k, p), 0f) * k;
            Vector2 d = new Vector2(p.x - Mathf.Clamp(p.x, -kz * r, kz * r), p.y - r);
            return d.magnitude * Mathf.Sign(d.y);
        }

        public static float TriangleIso(Vector2 p, Vector2 q)
        {
            p.x = Mathf.Abs(p.x);
            Vector2 a = p - q * Mathf.Clamp(Vector2.Dot(p, q) / Vector2.Dot(q, q), 0f, 1f);
            Vector2 b = p - new Vector2(q.x * Mathf.Clamp(p.x / q.x, 0f, 1f), q.y);
            float s = -Mathf.Sign(q.y);
            float dx = Mathf.Min(Vector2.Dot(a, a), Vector2.Dot(b, b));
            float dy = Mathf.Min(s * (p.x * q.y - p.y * q.x), s * (p.y - q.y));
            return -Mathf.Sqrt(dx) * Mathf.Sign(dy);
        }

        public static float Cross(Vector2 p, Vector2 b, float r)
        {
            p = new Vector2(Mathf.Abs(p.x), Mathf.Abs(p.y));
            if (p.y > p.x) (p.x, p.y) = (p.y, p.x);
            Vector2 q = p - b;
            float k = Mathf.Max(q.y, q.x);
            Vector2 w = (k > 0f) ? q : new Vector2(b.y - p.x, -k);
            Vector2 wMax = new Vector2(Mathf.Max(w.x, 0f), Mathf.Max(w.y, 0f));
            return Mathf.Sign(k) * wMax.magnitude + r;
        }

        public static float Segment(Vector2 p, Vector2 a, Vector2 b, float r)
        {
            Vector2 pa = p - a, ba = b - a;
            float h = Mathf.Clamp(Vector2.Dot(pa, ba) / Vector2.Dot(ba, ba), 0f, 1f);
            return (pa - ba * h).magnitude - r;
        }

        public static float Moon(Vector2 p, float d, float ra, float rb)
        {
            p.y = Mathf.Abs(p.y);
            float a = (ra * ra - rb * rb + d * d) / (2f * d);
            float b = Mathf.Sqrt(Mathf.Max(ra * ra - a * a, 0f));

            if (d * (p.x * b - p.y * a) > d * d * Mathf.Max(b - p.y, 0f))
            {
                return (p - new Vector2(a, b)).magnitude;
            }

            return Mathf.Max(
                p.magnitude - ra,
                -((p - new Vector2(d, 0f)).magnitude - rb));
        }

        public static float Union(float a, float b) => Mathf.Min(a, b);
        public static float Subtract(float a, float b) => Mathf.Max(a, -b);
        public static float Intersect(float a, float b) => Mathf.Max(a, b);
    }
}
