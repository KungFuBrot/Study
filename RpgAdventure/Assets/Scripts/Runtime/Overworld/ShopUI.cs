using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace RpgAdventure
{
    /// <summary>Buy-only shop panel: lists a shopkeeper's wares with price and a buy button each.</summary>
    public class ShopUI : MonoBehaviour
    {
        [SerializeField] private GameObject panel;
        [SerializeField] private Transform listParent;
        [SerializeField] private GameObject rowTemplate;
        [SerializeField] private Text goldText;
        [SerializeField] private Text messageText;
        [SerializeField] private Button closeButton;

        private readonly List<GameObject> _spawnedRows = new List<GameObject>();
        private Shop _currentShop;

        public bool IsOpen => panel != null && panel.activeSelf;

        private void Awake()
        {
            if (closeButton != null) closeButton.onClick.AddListener(Close);
            if (rowTemplate != null) rowTemplate.SetActive(false);
            if (panel != null) panel.SetActive(false);
        }

        public void Open(Shop shop)
        {
            _currentShop = shop;
            if (panel != null) panel.SetActive(true);
            if (messageText != null) messageText.text = "Willkommen im " + shop.shopName + "!";
            Rebuild();
        }

        private void Rebuild()
        {
            foreach (var go in _spawnedRows) Destroy(go);
            _spawnedRows.Clear();

            if (goldText != null) goldText.text = "Gold: " + GameState.Gold;
            if (_currentShop == null || rowTemplate == null || listParent == null) return;

            foreach (var item in _currentShop.itemsForSale)
            {
                var row = Instantiate(rowTemplate, listParent);
                row.SetActive(true);
                _spawnedRows.Add(row);

                var texts = row.GetComponentsInChildren<Text>();
                if (texts.Length > 0) texts[0].text = item.itemName;
                if (texts.Length > 1) texts[1].text = item.price + " G";

                var button = row.GetComponentInChildren<Button>();
                if (button != null)
                {
                    var captured = item;
                    button.onClick.AddListener(() => Buy(captured));
                }
            }
        }

        private void Buy(ItemDefinition item)
        {
            if (GameState.TrySpendGold(item.price))
            {
                GameState.AddItem(item);
                if (messageText != null) messageText.text = item.itemName + " gekauft!";
            }
            else if (messageText != null)
            {
                messageText.text = "Nicht genug Gold!";
            }

            Rebuild();
        }

        public void Close()
        {
            if (panel != null) panel.SetActive(false);
            _currentShop = null;
        }
    }
}
