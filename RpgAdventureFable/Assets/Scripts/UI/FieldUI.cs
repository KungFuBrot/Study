using UnityEngine;
using UnityEngine.UI;
using RpgFable.Core;
using RpgFable.Data;

namespace RpgFable.UI
{
    /// <summary>
    /// UI für die Erkundung: Interaktionshinweis, Dialogfenster und Shop.
    /// Steuerung: [E]/[Enter]/[Leertaste] weiter bzw. kaufen, [Esc] schließen,
    /// [W/S] bzw. Pfeiltasten wählen im Shop.
    /// </summary>
    public class FieldUI : MonoBehaviour
    {
        public static FieldUI Instance { get; private set; }

        [SerializeField] private Text hintLabel;
        [SerializeField] private GameObject dialoguePanel;
        [SerializeField] private Text dialogueNameLabel;
        [SerializeField] private Text dialogueBodyLabel;
        [SerializeField] private GameObject shopPanel;
        [SerializeField] private Text shopListLabel;
        [SerializeField] private Text shopGoldLabel;
        [SerializeField] private Text shopInfoLabel;

        private enum Mode { None, Dialogue, Shop }

        private Mode mode = Mode.None;
        private string[] dialogueLines;
        private int dialogueIndex;
        private ItemDefinition[] shopWares;
        private int shopIndex;
        private string shopTitle;
        private string shopMessage;
        private int openedFrame;

        public bool IsBusy { get { return mode != Mode.None; } }

        private void Awake()
        {
            Instance = this;
            if (dialoguePanel != null) dialoguePanel.SetActive(false);
            if (shopPanel != null) shopPanel.SetActive(false);
            SetHint(null);
        }

        private void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        public void SetHint(string text)
        {
            if (hintLabel != null) hintLabel.text = string.IsNullOrEmpty(text) ? "" : text;
        }

        public void ShowDialogue(string speaker, string[] lines)
        {
            if (lines == null || lines.Length == 0) return;

            mode = Mode.Dialogue;
            openedFrame = Time.frameCount;
            dialogueLines = lines;
            dialogueIndex = 0;
            dialoguePanel.SetActive(true);
            dialogueNameLabel.text = speaker;
            RefreshDialogue();
            SetHint(null);
        }

        public void OpenShop(string title, ItemDefinition[] wares)
        {
            if (wares == null || wares.Length == 0) return;

            mode = Mode.Shop;
            openedFrame = Time.frameCount;
            shopTitle = title;
            shopWares = wares;
            shopIndex = 0;
            shopMessage = "Was darf es sein?";
            shopPanel.SetActive(true);
            RefreshShop();
            SetHint(null);
        }

        private void RefreshDialogue()
        {
            string prompt = dialogueIndex < dialogueLines.Length - 1 ? "[E] Weiter" : "[E] Schließen";
            dialogueBodyLabel.text = dialogueLines[dialogueIndex] + "\n\n" + prompt;
        }

        private void RefreshShop()
        {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("== " + shopTitle + " ==");
            sb.AppendLine();
            for (int i = 0; i < shopWares.Length; i++)
            {
                string cursor = i == shopIndex ? "> " : "   ";
                sb.AppendLine(cursor + shopWares[i].displayName + "   " + shopWares[i].price + " G");
            }
            shopListLabel.text = sb.ToString();
            shopGoldLabel.text = "Gold: " + GameState.Gold + " G";

            var item = shopWares[shopIndex];
            shopInfoLabel.text = item.description + "\n" + shopMessage + "\n[E] Kaufen    [Esc] Verlassen";
        }

        private void Update()
        {
            if (mode == Mode.None) return;
            if (Time.frameCount == openedFrame) return; // Öffnen-Taste nicht sofort weiterreichen

            if (mode == Mode.Dialogue) UpdateDialogue();
            else if (mode == Mode.Shop) UpdateShop();
        }

        private bool AdvancePressed()
        {
            return Input.GetKeyDown(KeyCode.E) || Input.GetKeyDown(KeyCode.Space)
                || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter);
        }

        private void UpdateDialogue()
        {
            if (!AdvancePressed()) return;

            dialogueIndex++;
            if (dialogueIndex >= dialogueLines.Length)
            {
                mode = Mode.None;
                dialoguePanel.SetActive(false);
            }
            else
            {
                RefreshDialogue();
            }
        }

        private void UpdateShop()
        {
            if (Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.Backspace))
            {
                mode = Mode.None;
                shopPanel.SetActive(false);
                return;
            }

            if (Input.GetKeyDown(KeyCode.DownArrow) || Input.GetKeyDown(KeyCode.S))
            {
                shopIndex = (shopIndex + 1) % shopWares.Length;
                shopMessage = "Was darf es sein?";
                RefreshShop();
            }
            else if (Input.GetKeyDown(KeyCode.UpArrow) || Input.GetKeyDown(KeyCode.W))
            {
                shopIndex = (shopIndex - 1 + shopWares.Length) % shopWares.Length;
                shopMessage = "Was darf es sein?";
                RefreshShop();
            }
            else if (AdvancePressed())
            {
                var item = shopWares[shopIndex];
                if (GameState.Gold >= item.price)
                {
                    GameState.Gold -= item.price;
                    GameState.AddItem(item, 1);
                    shopMessage = item.displayName + " gekauft!";
                }
                else
                {
                    shopMessage = "Nicht genug Gold!";
                }
                RefreshShop();
            }
        }
    }
}
