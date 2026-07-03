using UnityEngine;
using UnityEngine.UI;

namespace RpgAdventure
{
    /// <summary>Simple advance-on-key dialogue box used by NPCs.</summary>
    public class DialogueUI : MonoBehaviour
    {
        [SerializeField] private GameObject panel;
        [SerializeField] private Text nameText;
        [SerializeField] private Text bodyText;

        private string[] _lines;
        private int _index;

        public bool IsOpen => panel != null && panel.activeSelf;

        private void Awake()
        {
            if (panel != null) panel.SetActive(false);
        }

        public void Show(string speakerName, string[] lines)
        {
            if (lines == null || lines.Length == 0 || panel == null) return;

            _lines = lines;
            _index = 0;
            if (nameText != null) nameText.text = speakerName;
            panel.SetActive(true);
            RenderLine();
        }

        public void Advance()
        {
            _index++;
            if (_index >= _lines.Length)
            {
                Close();
                return;
            }
            RenderLine();
        }

        private void RenderLine()
        {
            if (bodyText != null) bodyText.text = _lines[_index] + "\n\n[Leertaste] weiter";
        }

        public void Close()
        {
            if (panel != null) panel.SetActive(false);
        }
    }
}
