using System.Text;
using UnityEngine;
using UnityEngine.UI;

namespace RpgAdventure
{
    /// <summary>Small always-visible strip showing gold and each hero's HP.</summary>
    public class OverworldHudUI : MonoBehaviour
    {
        [SerializeField] private Text infoText;

        private void Update()
        {
            Refresh();
        }

        public void Refresh()
        {
            if (infoText == null || GameState.Party == null) return;

            var sb = new StringBuilder();
            sb.Append("Gold: ").Append(GameState.Gold);
            foreach (var member in GameState.Party)
            {
                sb.Append("    ").Append(member.definition.heroName)
                  .Append(" HP ").Append(member.currentHp).Append('/').Append(member.definition.maxHp);
            }
            infoText.text = sb.ToString();
        }
    }
}
