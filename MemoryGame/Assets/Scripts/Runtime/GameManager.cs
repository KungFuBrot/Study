using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace MemoryGame
{
    /// <summary>
    /// Sets up the board, handles flip/match logic, and drives the moves/timer/win UI.
    /// </summary>
    public class GameManager : MonoBehaviour
    {
        [Header("Setup")]
        [SerializeField] private Transform boardParent;
        [SerializeField] private Card cardPrefab;
        [SerializeField] private Sprite[] iconSprites;
        [SerializeField] private int pairCount = 8;
        [SerializeField] private float revealDelay = 0.6f;

        [Header("UI")]
        [SerializeField] private Text movesText;
        [SerializeField] private Text timerText;
        [SerializeField] private GameObject winPanel;
        [SerializeField] private Text winText;

        private readonly List<Card> _cards = new List<Card>();
        private readonly List<Card> _flippedCards = new List<Card>();

        private int _moves;
        private int _matchedPairs;
        private float _elapsed;
        private bool _busy;
        private bool _running;

        private void Start()
        {
            StartNewGame();
        }

        private void Update()
        {
            if (!_running) return;
            _elapsed += Time.deltaTime;
            UpdateTimerText();
        }

        public void StartNewGame()
        {
            foreach (var c in _cards)
            {
                if (c != null) Destroy(c.gameObject);
            }
            _cards.Clear();
            _flippedCards.Clear();

            _moves = 0;
            _matchedPairs = 0;
            _elapsed = 0f;
            _busy = false;

            if (winPanel != null) winPanel.SetActive(false);
            UpdateMovesText();
            UpdateTimerText();

            int pairs = Mathf.Min(pairCount, iconSprites.Length);
            var ids = new List<int>(pairs * 2);
            for (int i = 0; i < pairs; i++)
            {
                ids.Add(i);
                ids.Add(i);
            }
            Shuffle(ids);

            foreach (var id in ids)
            {
                var card = Instantiate(cardPrefab, boardParent);
                card.Setup(id, iconSprites[id]);
                card.Clicked += OnCardClicked;
                _cards.Add(card);
            }

            _running = true;
        }

        private static void Shuffle(List<int> list)
        {
            for (int i = list.Count - 1; i > 0; i--)
            {
                int j = Random.Range(0, i + 1);
                (list[i], list[j]) = (list[j], list[i]);
            }
        }

        private void OnCardClicked(Card card)
        {
            if (_busy) return;

            card.FlipToFront();
            _flippedCards.Add(card);

            if (_flippedCards.Count == 2)
            {
                _moves++;
                UpdateMovesText();
                StartCoroutine(CheckMatch());
            }
        }

        private IEnumerator CheckMatch()
        {
            _busy = true;

            var a = _flippedCards[0];
            var b = _flippedCards[1];

            yield return new WaitForSeconds(revealDelay);

            if (a.IconId == b.IconId)
            {
                a.SetMatched();
                b.SetMatched();
                _matchedPairs++;

                if (_matchedPairs >= Mathf.Min(pairCount, iconSprites.Length))
                {
                    _running = false;
                    if (winText != null)
                        winText.text = $"Gewonnen!\nZüge: {_moves}\nZeit: {FormatTime(_elapsed)}";
                    if (winPanel != null)
                        winPanel.SetActive(true);
                }
            }
            else
            {
                a.FlipToBack();
                b.FlipToBack();
            }

            _flippedCards.Clear();
            _busy = false;
        }

        private void UpdateMovesText()
        {
            if (movesText != null) movesText.text = $"Züge: {_moves}";
        }

        private void UpdateTimerText()
        {
            if (timerText != null) timerText.text = $"Zeit: {FormatTime(_elapsed)}";
        }

        private static string FormatTime(float seconds)
        {
            int m = Mathf.FloorToInt(seconds / 60f);
            int s = Mathf.FloorToInt(seconds % 60f);
            return $"{m:00}:{s:00}";
        }
    }
}
