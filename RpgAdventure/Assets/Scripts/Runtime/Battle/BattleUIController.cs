using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.UI;

namespace RpgAdventure
{
    /// <summary>
    /// Drives all battle UI: the scrolling log, the HP/MP status readout and the
    /// nested choice menus (action -> ability/item -> target) that feed a chosen
    /// <see cref="BattleAction"/> back to whoever asked for it.
    /// </summary>
    public class BattleUIController : MonoBehaviour
    {
        private struct ActionOption
        {
            public string label;
            public BattleActionType type;
        }

        [Header("Log & Status")]
        [SerializeField] private Text logText;
        [SerializeField] private Text statusText;

        [Header("Choice Menu")]
        [SerializeField] private GameObject choicePanel;
        [SerializeField] private Text choiceTitle;
        [SerializeField] private Transform choiceListParent;
        [SerializeField] private GameObject choiceButtonTemplate;

        [Header("Result Panels")]
        [SerializeField] private GameObject victoryPanel;
        [SerializeField] private Text victoryText;
        [SerializeField] private Button victoryButton;
        [SerializeField] private GameObject defeatPanel;
        [SerializeField] private Button defeatButton;

        private readonly List<string> _logLines = new List<string>();
        private readonly List<GameObject> _spawnedChoices = new List<GameObject>();

        private void Awake()
        {
            if (choiceButtonTemplate != null) choiceButtonTemplate.SetActive(false);
            if (choicePanel != null) choicePanel.SetActive(false);
            if (victoryPanel != null) victoryPanel.SetActive(false);
            if (defeatPanel != null) defeatPanel.SetActive(false);
        }

        public void Log(string line)
        {
            _logLines.Add(line);
            while (_logLines.Count > 5) _logLines.RemoveAt(0);
            if (logText != null) logText.text = string.Join("\n", _logLines);
        }

        public void RefreshStatus(List<BattleUnit> heroes, List<BattleUnit> enemies)
        {
            if (statusText == null) return;

            var sb = new StringBuilder();
            foreach (var h in heroes)
            {
                sb.Append(h.IsAlive ? h.Name : h.Name + " (besiegt)")
                  .Append("  HP ").Append(h.CurrentHp).Append('/').Append(h.MaxHp)
                  .Append("  MP ").Append(h.CurrentMp).Append('/').Append(h.MaxMp).Append('\n');
            }
            sb.Append('\n');
            foreach (var e in enemies)
            {
                sb.Append(e.IsAlive ? e.Name : e.Name + " (besiegt)")
                  .Append("  HP ").Append(e.CurrentHp).Append('/').Append(e.MaxHp).Append('\n');
            }
            statusText.text = sb.ToString();
        }

        public void ShowActionMenu(BattleUnit actor, List<BattleUnit> heroes, List<BattleUnit> enemies, System.Action<BattleAction> onChosen)
        {
            var options = new List<ActionOption>
            {
                new ActionOption { label = "Angriff", type = BattleActionType.Attack },
                new ActionOption { label = "Fähigkeit", type = BattleActionType.Ability },
                new ActionOption { label = "Item", type = BattleActionType.Item },
                new ActionOption { label = "Flucht", type = BattleActionType.Flee },
            };

            ShowChoices("Was tut " + actor.Name + "?", options, opt => opt.label, opt =>
            {
                switch (opt.type)
                {
                    case BattleActionType.Attack:
                        ShowTargetChoice("Ziel wählen", enemies, target =>
                            onChosen(new BattleAction { type = BattleActionType.Attack, target = target }));
                        break;

                    case BattleActionType.Ability:
                        ShowAbilityChoice(actor, heroes, enemies, onChosen);
                        break;

                    case BattleActionType.Item:
                        ShowItemChoice(actor, heroes, enemies, onChosen);
                        break;

                    case BattleActionType.Flee:
                        onChosen(new BattleAction { type = BattleActionType.Flee });
                        break;
                }
            });
        }

        private void ShowAbilityChoice(BattleUnit actor, List<BattleUnit> heroes, List<BattleUnit> enemies, System.Action<BattleAction> onChosen)
        {
            var abilities = actor.heroMember.definition.abilities;
            if (abilities == null || abilities.Length == 0)
            {
                Log(actor.Name + " kennt keine Fähigkeiten.");
                ShowActionMenu(actor, heroes, enemies, onChosen);
                return;
            }

            ShowChoices("Fähigkeit wählen", new List<AbilityDefinition>(abilities),
                a => a.abilityName + " (" + a.mpCost + " MP)",
                ability =>
                {
                    switch (ability.targetType)
                    {
                        case AbilityTargetType.SingleEnemy:
                            ShowTargetChoice("Ziel wählen", enemies, target =>
                                onChosen(new BattleAction { type = BattleActionType.Ability, ability = ability, target = target }));
                            break;
                        case AbilityTargetType.SingleAlly:
                            ShowTargetChoice("Ziel wählen", heroes, target =>
                                onChosen(new BattleAction { type = BattleActionType.Ability, ability = ability, target = target }));
                            break;
                        default:
                            onChosen(new BattleAction { type = BattleActionType.Ability, ability = ability, target = actor });
                            break;
                    }
                });
        }

        private void ShowItemChoice(BattleUnit actor, List<BattleUnit> heroes, List<BattleUnit> enemies, System.Action<BattleAction> onChosen)
        {
            var entries = new List<ItemDefinition>();
            foreach (var kv in GameState.Inventory)
            {
                if (kv.Value > 0) entries.Add(kv.Key);
            }

            if (entries.Count == 0)
            {
                Log("Keine Items im Beutel.");
                ShowActionMenu(actor, heroes, enemies, onChosen);
                return;
            }

            ShowChoices("Item wählen", entries, i => i.itemName + " x" + GameState.Inventory[i], item =>
            {
                ShowTargetChoice("Bei wem einsetzen?", heroes, target =>
                    onChosen(new BattleAction { type = BattleActionType.Item, item = item, target = target }));
            });
        }

        private void ShowTargetChoice(string title, List<BattleUnit> candidates, System.Action<BattleUnit> onChosen)
        {
            var alive = candidates.FindAll(c => c.IsAlive);
            ShowChoices(title, alive, u => u.Name + " (HP " + u.CurrentHp + "/" + u.MaxHp + ")", onChosen);
        }

        public void HideActionMenu()
        {
            if (choicePanel != null) choicePanel.SetActive(false);
        }

        private void ShowChoices<T>(string title, List<T> options, System.Func<T, string> label, System.Action<T> onChosen)
        {
            foreach (var go in _spawnedChoices) Destroy(go);
            _spawnedChoices.Clear();

            if (choiceTitle != null) choiceTitle.text = title;
            if (choicePanel != null) choicePanel.SetActive(true);

            foreach (var option in options)
            {
                var row = Instantiate(choiceButtonTemplate, choiceListParent);
                row.SetActive(true);
                _spawnedChoices.Add(row);

                var text = row.GetComponentInChildren<Text>();
                if (text != null) text.text = label(option);

                var button = row.GetComponent<Button>();
                if (button != null)
                {
                    var captured = option;
                    button.onClick.AddListener(() => onChosen(captured));
                }
            }
        }

        public void ShowVictory(int gold, System.Action onContinue)
        {
            if (victoryText != null) victoryText.text = "Sieg!\n+" + gold + " Gold";
            if (victoryPanel != null) victoryPanel.SetActive(true);
            if (victoryButton != null)
            {
                victoryButton.onClick.RemoveAllListeners();
                victoryButton.onClick.AddListener(() => onContinue());
            }
        }

        public void ShowDefeat(System.Action onContinue)
        {
            if (defeatPanel != null) defeatPanel.SetActive(true);
            if (defeatButton != null)
            {
                defeatButton.onClick.RemoveAllListeners();
                defeatButton.onClick.AddListener(() => onContinue());
            }
        }
    }
}
