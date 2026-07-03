using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using RpgFable.Core;
using RpgFable.Data;

namespace RpgFable.Battle
{
    /// <summary>
    /// Rundenbasierter Kampf im Stil klassischer JRPGs.
    /// Reihenfolge nach Tempo; Helden wählen Befehle über ein Tastaturmenü
    /// (Pfeiltasten/W/S wählen, [E]/[Enter] bestätigen, [Esc] zurück).
    /// </summary>
    public class BattleManager : MonoBehaviour
    {
        [SerializeField] private GameObject commandPanel;
        [SerializeField] private Text commandLabel;
        [SerializeField] private GameObject messagePanel;
        [SerializeField] private Text messageLabel;
        [SerializeField] private Text statusLabel;
        [SerializeField] private Transform enemyRoot;
        [SerializeField] private Transform heroRoot;
        [SerializeField] private Transform targetCursor;

        [Tooltip("Wird verwendet, wenn die Kampfszene direkt gestartet wird (zum Testen).")]
        [SerializeField] private EncounterTable fallbackEncounter;

        private readonly List<BattleUnit> heroes = new List<BattleUnit>();
        private readonly List<BattleUnit> enemies = new List<BattleUnit>();

        private bool battleOver;
        private bool actionDone;
        private int menuResult;

        private void Start()
        {
            if (GameState.PendingEnemies == null || GameState.PendingEnemies.Count == 0)
            {
                if (fallbackEncounter != null)
                {
                    GameState.PendingEnemies = fallbackEncounter.Roll();
                    GameState.ReturnScene = "Stadt";
                    GameState.HasReturnPosition = false;
                }
            }

            SpawnHeroes();
            SpawnEnemies();

            if (commandPanel != null) commandPanel.SetActive(false);
            if (targetCursor != null) targetCursor.gameObject.SetActive(false);

            RefreshStatus(-1);
            StartCoroutine(BattleLoop());
        }

        // ------------------------------------------------------------------
        // Aufbau
        // ------------------------------------------------------------------

        private void SpawnHeroes()
        {
            for (int i = 0; i < GameState.Party.Count; i++)
            {
                var unit = BattleUnit.FromHero(GameState.Party[i]);
                var go = new GameObject("Held_" + unit.Name);
                go.transform.position = heroRoot.position + new Vector3(0.35f * i, 1.0f - 2.0f * i, 0f);
                go.transform.localScale = Vector3.one * 1.6f;
                var sr = go.AddComponent<SpriteRenderer>();
                sr.sprite = unit.Hero.Definition.battleSprite != null
                    ? unit.Hero.Definition.battleSprite
                    : unit.Hero.Definition.fieldSprite;
                sr.flipX = false;
                sr.sortingOrder = 5;
                unit.View = sr;
                heroes.Add(unit);
            }
        }

        private void SpawnEnemies()
        {
            var pending = GameState.PendingEnemies ?? new List<EnemyDefinition>();
            var nameCounts = new Dictionary<string, int>();
            foreach (var def in pending)
            {
                if (def == null) continue;
                if (!nameCounts.ContainsKey(def.displayName)) nameCounts[def.displayName] = 0;
                nameCounts[def.displayName]++;
            }

            var nameUsed = new Dictionary<string, int>();
            int count = pending.Count;
            int index = 0;
            foreach (var def in pending)
            {
                if (def == null) continue;

                string unitName = def.displayName;
                if (nameCounts[def.displayName] > 1)
                {
                    if (!nameUsed.ContainsKey(def.displayName)) nameUsed[def.displayName] = 0;
                    unitName += " " + (char)('A' + nameUsed[def.displayName]);
                    nameUsed[def.displayName]++;
                }

                var unit = BattleUnit.FromEnemy(def, unitName);
                var go = new GameObject("Gegner_" + unitName);
                float y = (count - 1) * 0.8f - index * 1.6f;
                float x = (index % 2 == 0) ? 0f : -1.1f;
                go.transform.position = enemyRoot.position + new Vector3(x, y, 0f);
                var sr = go.AddComponent<SpriteRenderer>();
                sr.sprite = def.battleSprite;
                sr.sortingOrder = 5;
                unit.View = sr;
                enemies.Add(unit);
                index++;
            }
        }

        // ------------------------------------------------------------------
        // Kampfschleife
        // ------------------------------------------------------------------

        private IEnumerator BattleLoop()
        {
            yield return ShowMessage("Gegner erscheinen!", 1.1f);

            if (enemies.Count == 0)
            {
                yield return ShowMessage("Keine Gegner gefunden...", 1f);
                yield return Victory();
                yield break;
            }

            while (!battleOver)
            {
                var order = heroes.Concat(enemies)
                    .Where(u => u.IsAlive)
                    .OrderByDescending(u => u.Speed)
                    .ToList();

                foreach (var unit in order)
                {
                    if (battleOver) break;
                    if (!unit.IsAlive) continue;

                    if (unit.IsHero) yield return HeroTurn(unit);
                    else yield return EnemyTurn(unit);

                    if (battleOver) break;
                    if (enemies.All(e => !e.IsAlive)) { yield return Victory(); break; }
                    if (heroes.All(h => !h.IsAlive)) { yield return Defeat(); break; }
                }
            }
        }

        private IEnumerator HeroTurn(BattleUnit hero)
        {
            RefreshStatus(heroes.IndexOf(hero));
            actionDone = false;

            while (!actionDone && !battleOver)
            {
                yield return RunMenu(hero.Name, new List<string> { "Angriff", "Fähigkeit", "Gegenstand", "Fliehen" }, false);
                int command = menuResult;

                switch (command)
                {
                    case 0:
                        yield return SelectEnemyTarget();
                        if (menuResult < 0) break;
                        var target = enemies[menuResult];
                        HideCommand();
                        yield return DoBasicAttack(hero, target);
                        actionDone = true;
                        break;

                    case 1:
                        yield return HeroAbility(hero);
                        break;

                    case 2:
                        yield return HeroItem(hero);
                        break;

                    case 3:
                        HideCommand();
                        if (Random.value < 0.6f)
                        {
                            yield return ShowMessage("Ihr entkommt dem Kampf!", 1.2f);
                            EndBattleToField();
                        }
                        else
                        {
                            yield return ShowMessage("Flucht gescheitert!", 1.1f);
                            actionDone = true;
                        }
                        break;
                }
            }

            HideCommand();
            RefreshStatus(-1);
        }

        private IEnumerator HeroAbility(BattleUnit hero)
        {
            var abilities = hero.Hero.Definition.abilities;
            if (abilities == null || abilities.Length == 0)
            {
                yield return ShowMessage(hero.Name + " kennt keine Fähigkeiten!", 1f);
                yield break;
            }

            var labels = abilities.Select(a => a.displayName + " (" + a.mpCost + " MP)").ToList();
            yield return RunMenu("Fähigkeit", labels, true);
            if (menuResult < 0) yield break;

            var ability = abilities[menuResult];
            if (hero.CurrentMp < ability.mpCost)
            {
                yield return ShowMessage("Nicht genug MP!", 1f);
                yield break;
            }

            List<BattleUnit> targets = null;
            switch (ability.target)
            {
                case AbilityTarget.SingleEnemy:
                    yield return SelectEnemyTarget();
                    if (menuResult < 0) yield break;
                    targets = new List<BattleUnit> { enemies[menuResult] };
                    break;
                case AbilityTarget.AllEnemies:
                    targets = enemies.Where(e => e.IsAlive).ToList();
                    break;
                case AbilityTarget.SingleAlly:
                    yield return SelectAllyTarget();
                    if (menuResult < 0) yield break;
                    targets = new List<BattleUnit> { heroes[menuResult] };
                    break;
                case AbilityTarget.AllAllies:
                    targets = heroes.Where(h => h.IsAlive).ToList();
                    break;
            }

            HideCommand();
            hero.CurrentMp -= ability.mpCost;
            RefreshStatus(-1);
            yield return ExecuteAbility(hero, ability, targets);
            actionDone = true;
        }

        private IEnumerator HeroItem(BattleUnit hero)
        {
            if (GameState.Inventory.Count == 0)
            {
                yield return ShowMessage("Keine Gegenstände im Beutel!", 1f);
                yield break;
            }

            var stacks = GameState.Inventory.ToList();
            var labels = stacks.Select(s => s.Item.displayName + " x" + s.Count).ToList();
            yield return RunMenu("Gegenstand", labels, true);
            if (menuResult < 0) yield break;

            var stack = stacks[menuResult];
            yield return SelectAllyTarget();
            if (menuResult < 0) yield break;

            var target = heroes[menuResult];
            HideCommand();

            GameState.RemoveItem(stack.Item, 1);
            int amount = stack.Item.amount;
            if (stack.Item.effect == ItemEffect.HealHp)
            {
                target.CurrentHp = Mathf.Min(target.MaxHp, target.CurrentHp + amount);
                yield return ShowMessage(hero.Name + " setzt " + stack.Item.displayName + " ein. " + target.Name + " erhält " + amount + " LP!", 1.3f);
            }
            else
            {
                target.CurrentMp = Mathf.Min(target.MaxMp, target.CurrentMp + amount);
                yield return ShowMessage(hero.Name + " setzt " + stack.Item.displayName + " ein. " + target.Name + " erhält " + amount + " MP!", 1.3f);
            }

            RefreshStatus(-1);
            actionDone = true;
        }

        private IEnumerator EnemyTurn(BattleUnit enemy)
        {
            var living = heroes.Where(h => h.IsAlive).ToList();
            if (living.Count == 0) yield break;

            var def = enemy.Enemy;
            if (def != null && def.ability != null && Random.value < def.abilityChance)
            {
                List<BattleUnit> targets;
                if (def.ability.target == AbilityTarget.AllEnemies || def.ability.target == AbilityTarget.AllAllies)
                    targets = living;
                else
                    targets = new List<BattleUnit> { living[Random.Range(0, living.Count)] };
                yield return ExecuteAbility(enemy, def.ability, targets);
            }
            else
            {
                var target = living[Random.Range(0, living.Count)];
                yield return DoBasicAttack(enemy, target);
            }
        }

        // ------------------------------------------------------------------
        // Aktionen und Schaden
        // ------------------------------------------------------------------

        private IEnumerator DoBasicAttack(BattleUnit attacker, BattleUnit target)
        {
            yield return Bump(attacker);
            int damage = PhysicalDamage(attacker.Attack * 2 - target.Defense);
            yield return ApplyDamage(attacker.Name + " greift " + target.Name + " an!", target, damage);
        }

        private IEnumerator ExecuteAbility(BattleUnit user, AbilityDefinition ability, List<BattleUnit> targets)
        {
            yield return ShowMessage(user.Name + " setzt " + ability.displayName + " ein!", 1f);
            yield return Bump(user);

            foreach (var target in targets)
            {
                if (!target.IsAlive) continue;

                switch (ability.kind)
                {
                    case AbilityKind.PhysicalDamage:
                        int pDamage = PhysicalDamage(ability.power + user.Attack * 2 - target.Defense);
                        yield return ApplyDamage(null, target, pDamage);
                        break;
                    case AbilityKind.MagicDamage:
                        int mDamage = PhysicalDamage(ability.power + user.Magic * 2 - target.Defense / 2);
                        yield return ApplyDamage(null, target, mDamage);
                        break;
                    case AbilityKind.Heal:
                        int heal = Mathf.Max(1, ability.power + user.Magic);
                        target.CurrentHp = Mathf.Min(target.MaxHp, target.CurrentHp + heal);
                        RefreshStatus(-1);
                        yield return ShowMessage(target.Name + " erhält " + heal + " LP zurück!", 1.1f);
                        break;
                }

                if (enemies.All(e => !e.IsAlive) || heroes.All(h => !h.IsAlive)) yield break;
            }
        }

        private int PhysicalDamage(int baseDamage)
        {
            float variance = Random.Range(0.85f, 1.15f);
            return Mathf.Max(1, Mathf.RoundToInt(baseDamage * variance));
        }

        private IEnumerator ApplyDamage(string introMessage, BattleUnit target, int damage)
        {
            if (!string.IsNullOrEmpty(introMessage))
            {
                yield return ShowMessage(introMessage, 0.8f);
            }

            target.CurrentHp = Mathf.Max(0, target.CurrentHp - damage);
            RefreshStatus(-1);
            yield return Flash(target);
            yield return ShowMessage(target.Name + " erleidet " + damage + " Schaden!", 1f);

            if (!target.IsAlive)
            {
                if (target.View != null) yield return FadeOut(target.View);
                yield return ShowMessage(target.Name + " wurde besiegt!", 1f);
            }
        }

        // ------------------------------------------------------------------
        // Kampfende
        // ------------------------------------------------------------------

        private IEnumerator Victory()
        {
            battleOver = true;
            int gold = enemies.Sum(e => e.GoldReward);
            GameState.Gold += gold;
            yield return ShowMessage("Sieg!", 1f);
            yield return ShowMessageAndWaitKey("Ihr erhaltet " + gold + " Gold!  [E] Weiter");
            SyncHeroesBack();
            GameState.PendingEnemies = null;
            SceneManager.LoadScene(string.IsNullOrEmpty(GameState.ReturnScene) ? "Stadt" : GameState.ReturnScene);
        }

        private IEnumerator Defeat()
        {
            battleOver = true;
            yield return ShowMessage("Die Gruppe wurde besiegt...", 1.4f);
            yield return ShowMessageAndWaitKey("Ihr erwacht in der Stadt.  [E] Weiter");
            SyncHeroesBack();
            foreach (var hero in GameState.Party) hero.CurrentHp = Mathf.Max(1, hero.CurrentHp);
            GameState.PendingEnemies = null;
            GameState.HasReturnPosition = false;
            GameState.NextSpawnId = "Start";
            SceneManager.LoadScene("Stadt");
        }

        private void EndBattleToField()
        {
            battleOver = true;
            SyncHeroesBack();
            GameState.PendingEnemies = null;
            SceneManager.LoadScene(string.IsNullOrEmpty(GameState.ReturnScene) ? "Stadt" : GameState.ReturnScene);
        }

        private void SyncHeroesBack()
        {
            foreach (var unit in heroes)
            {
                if (unit.Hero == null) continue;
                unit.Hero.CurrentHp = Mathf.Clamp(unit.CurrentHp, 0, unit.MaxHp);
                unit.Hero.CurrentMp = Mathf.Clamp(unit.CurrentMp, 0, unit.MaxMp);
            }
        }

        // ------------------------------------------------------------------
        // Menüs und Zielauswahl
        // ------------------------------------------------------------------

        private IEnumerator RunMenu(string title, IList<string> options, bool allowCancel)
        {
            commandPanel.SetActive(true);
            int index = 0;
            menuResult = -2;
            RenderMenu(title, options, index);
            yield return null;

            while (true)
            {
                if (DownPressed())
                {
                    index = (index + 1) % options.Count;
                    RenderMenu(title, options, index);
                }
                else if (UpPressed())
                {
                    index = (index - 1 + options.Count) % options.Count;
                    RenderMenu(title, options, index);
                }
                else if (ConfirmPressed())
                {
                    menuResult = index;
                    yield break;
                }
                else if (allowCancel && CancelPressed())
                {
                    menuResult = -1;
                    yield break;
                }
                yield return null;
            }
        }

        private void RenderMenu(string title, IList<string> options, int index)
        {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("- " + title + " -");
            for (int i = 0; i < options.Count; i++)
            {
                sb.AppendLine((i == index ? "> " : "   ") + options[i]);
            }
            commandLabel.text = sb.ToString();
        }

        /// <summary>Zielauswahl unter lebenden Gegnern; Ergebnis in menuResult (Index in enemies, -1 = abgebrochen).</summary>
        private IEnumerator SelectEnemyTarget()
        {
            var alive = new List<int>();
            for (int i = 0; i < enemies.Count; i++) if (enemies[i].IsAlive) alive.Add(i);
            if (alive.Count == 0) { menuResult = -1; yield break; }

            int cursor = 0;
            targetCursor.gameObject.SetActive(true);
            MoveCursorTo(enemies[alive[cursor]]);
            RenderMenu("Ziel wählen", new List<string> { enemies[alive[cursor]].Name }, cursor);
            yield return null;

            while (true)
            {
                bool moved = false;
                if (DownPressed() || Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.D))
                {
                    cursor = (cursor + 1) % alive.Count;
                    moved = true;
                }
                else if (UpPressed() || Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.A))
                {
                    cursor = (cursor - 1 + alive.Count) % alive.Count;
                    moved = true;
                }

                if (moved)
                {
                    MoveCursorTo(enemies[alive[cursor]]);
                    RenderMenu("Ziel wählen", new List<string> { enemies[alive[cursor]].Name }, 0);
                }
                else if (ConfirmPressed())
                {
                    targetCursor.gameObject.SetActive(false);
                    menuResult = alive[cursor];
                    yield break;
                }
                else if (CancelPressed())
                {
                    targetCursor.gameObject.SetActive(false);
                    menuResult = -1;
                    yield break;
                }
                yield return null;
            }
        }

        /// <summary>Zielauswahl unter lebenden Helden; Ergebnis in menuResult (Index in heroes, -1 = abgebrochen).</summary>
        private IEnumerator SelectAllyTarget()
        {
            var labels = heroes.Select(h => h.Name + "  (" + h.CurrentHp + "/" + h.MaxHp + " LP)").ToList();
            yield return RunMenu("Wen?", labels, true);
            if (menuResult >= 0 && !heroes[menuResult].IsAlive)
            {
                // Gefallene Helden können (noch) nicht Ziel sein.
                menuResult = -1;
            }
        }

        private void MoveCursorTo(BattleUnit unit)
        {
            if (unit.View != null)
            {
                targetCursor.position = unit.View.transform.position + new Vector3(0f, 1.15f, 0f);
            }
        }

        private void HideCommand()
        {
            if (commandPanel != null) commandPanel.SetActive(false);
            if (targetCursor != null) targetCursor.gameObject.SetActive(false);
        }

        // ------------------------------------------------------------------
        // Anzeige und kleine Animationen
        // ------------------------------------------------------------------

        private void RefreshStatus(int activeHeroIndex)
        {
            if (statusLabel == null) return;
            var sb = new System.Text.StringBuilder();
            for (int i = 0; i < heroes.Count; i++)
            {
                var h = heroes[i];
                string marker = i == activeHeroIndex ? "> " : "   ";
                string dead = h.IsAlive ? "" : "  (kampfunfähig)";
                sb.AppendLine(marker + h.Name + "   LP " + h.CurrentHp + "/" + h.MaxHp + "   MP " + h.CurrentMp + "/" + h.MaxMp + dead);
            }
            statusLabel.text = sb.ToString();
        }

        private IEnumerator ShowMessage(string text, float seconds)
        {
            if (messagePanel != null) messagePanel.SetActive(true);
            messageLabel.text = text;
            yield return new WaitForSeconds(seconds);
        }

        private IEnumerator ShowMessageAndWaitKey(string text)
        {
            if (messagePanel != null) messagePanel.SetActive(true);
            messageLabel.text = text;
            yield return null;
            while (!ConfirmPressed()) yield return null;
        }

        private IEnumerator Bump(BattleUnit unit)
        {
            if (unit.View == null) yield break;
            var t = unit.View.transform;
            Vector3 start = t.position;
            Vector3 direction = unit.IsHero ? Vector3.left : Vector3.right;
            Vector3 end = start + direction * 0.35f;

            for (float f = 0f; f < 1f; f += Time.deltaTime / 0.08f)
            {
                t.position = Vector3.Lerp(start, end, f);
                yield return null;
            }
            for (float f = 0f; f < 1f; f += Time.deltaTime / 0.08f)
            {
                t.position = Vector3.Lerp(end, start, f);
                yield return null;
            }
            t.position = start;
        }

        private IEnumerator Flash(BattleUnit unit)
        {
            if (unit.View == null) yield break;
            var sr = unit.View;
            Color original = sr.color;
            for (int i = 0; i < 2; i++)
            {
                sr.color = new Color(1f, 0.35f, 0.35f, 1f);
                yield return new WaitForSeconds(0.06f);
                sr.color = original;
                yield return new WaitForSeconds(0.06f);
            }
        }

        private IEnumerator FadeOut(SpriteRenderer sr)
        {
            Color c = sr.color;
            for (float f = 1f; f > 0f; f -= Time.deltaTime / 0.35f)
            {
                sr.color = new Color(c.r, c.g, c.b, f);
                yield return null;
            }
            sr.gameObject.SetActive(false);
        }

        // ------------------------------------------------------------------
        // Eingabe
        // ------------------------------------------------------------------

        private static bool ConfirmPressed()
        {
            return Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)
                || Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.E);
        }

        private static bool CancelPressed()
        {
            return Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.Backspace);
        }

        private static bool UpPressed()
        {
            return Input.GetKeyDown(KeyCode.UpArrow) || Input.GetKeyDown(KeyCode.W);
        }

        private static bool DownPressed()
        {
            return Input.GetKeyDown(KeyCode.DownArrow) || Input.GetKeyDown(KeyCode.S);
        }
    }
}
