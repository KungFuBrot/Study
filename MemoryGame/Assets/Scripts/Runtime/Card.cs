using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;

namespace MemoryGame
{
    /// <summary>
    /// A single flippable card. The GameObject's own Image shows the card back;
    /// a child "FrontFace" object shows the frame + icon and is toggled on flip.
    /// </summary>
    [RequireComponent(typeof(Button))]
    [RequireComponent(typeof(Image))]
    public class Card : MonoBehaviour
    {
        [SerializeField] private GameObject frontFace;
        [SerializeField] private Image iconImage;
        [SerializeField] private float flipDuration = 0.15f;

        public int IconId { get; private set; }
        public bool IsMatched { get; private set; }
        public bool IsFlipped { get; private set; }

        public event Action<Card> Clicked;

        private Button _button;
        private RectTransform _rect;
        private bool _interactable = true;
        private Coroutine _flipRoutine;

        private void Awake()
        {
            _button = GetComponent<Button>();
            _rect = (RectTransform)transform;
            _button.onClick.AddListener(HandleClick);
        }

        public void Setup(int iconId, Sprite iconSprite)
        {
            IconId = iconId;
            if (iconImage != null) iconImage.sprite = iconSprite;
            IsMatched = false;
            IsFlipped = false;
            if (frontFace != null) frontFace.SetActive(false);
            _rect.localScale = Vector3.one;
            SetInteractable(true);
        }

        private void HandleClick()
        {
            if (!_interactable || IsFlipped || IsMatched) return;
            Clicked?.Invoke(this);
        }

        public void SetInteractable(bool value)
        {
            _interactable = value;
        }

        public void FlipToFront()
        {
            if (_flipRoutine != null) StopCoroutine(_flipRoutine);
            _flipRoutine = StartCoroutine(FlipRoutine(true));
        }

        public void FlipToBack()
        {
            if (_flipRoutine != null) StopCoroutine(_flipRoutine);
            _flipRoutine = StartCoroutine(FlipRoutine(false));
        }

        public void SetMatched()
        {
            IsMatched = true;
            SetInteractable(false);
        }

        private IEnumerator FlipRoutine(bool toFront)
        {
            IsFlipped = toFront;

            float t = 0f;
            while (t < flipDuration)
            {
                t += Time.deltaTime;
                float x = Mathf.Lerp(1f, 0f, t / flipDuration);
                _rect.localScale = new Vector3(x, 1f, 1f);
                yield return null;
            }

            _rect.localScale = new Vector3(0f, 1f, 1f);
            if (frontFace != null) frontFace.SetActive(toFront);

            t = 0f;
            while (t < flipDuration)
            {
                t += Time.deltaTime;
                float x = Mathf.Lerp(0f, 1f, t / flipDuration);
                _rect.localScale = new Vector3(x, 1f, 1f);
                yield return null;
            }

            _rect.localScale = Vector3.one;
            _flipRoutine = null;
        }
    }
}
