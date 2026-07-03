using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace RpgAdventure
{
    /// <summary>
    /// Runs one round-based battle: builds initiative order by speed, lets the player
    /// choose an action for each hero when their turn comes, and has enemies act with
    /// a simple random-target AI. Loops rounds until one side is wiped out or the
    /// party flees.
    /// </summary>
    public class BattleManager : MonoBehaviour
    {
        [Header("Sprites")]
        [SerializeField] private SpriteRenderer[] heroSpriteSlots;
        [SerializeField] private SpriteRenderer[] enemySpriteSlots;

        [SerializeField] private BattleUIController ui;

        private List<BattleUnit> _heroUnits;
        private List<BattleUnit> _enemyUnits;
        private bool _battleOver;

        private void Start()
        {
            GameState.EnsureInitialized();
            BuildUnits();
            ui.RefreshStatus(_heroUnits, _enemyUnits);
            StartCoroutine(BattleLoop());
        }

        private void BuildUnits()
        {
            _heroUnits = new List<BattleUnit>();
            foreach (var member in GameState.Party)
            {
                _heroUnits.Add(BattleUnit.ForHero(member));
            }
            for (int i = 0; i < heroSpriteSlots.Length; i++)
            {
                if (i < _heroUnits.Count)
                {
                    heroSpriteSlots[i].gameObject.SetActive(true);
                    heroSpriteSlots[i].sprite = _heroUnits[i].Sprite;
                }
                else
                {
                    heroSpriteSlots[i].gameObject.SetActive(false);
                }
            }

            _enemyUnits = new List<BattleUnit>();
            var group = GameState.PendingEnemyGroup ?? new List<EnemyDefinition>();
            foreach (var def in group)
            {
                _enemyUnits.Add(BattleUnit.ForEnemy(def));
            }
            for (int i = 0; i < enemySpriteSlots.Length; i++)
            {
                if (i < _enemyUnits.Count)
                {
                    enemySpriteSlots[i].gameObject.SetActive(true);
                    enemySpriteSlots[i].sprite = _enemyUnits[i].Sprite;
                }
                else
                {
                    enemySpriteSlots[i].gameObject.SetActive(false);
                }
            }
        }

        private IEnumerator BattleLoop()
        {
            ui.Log("Ein Kampf beginnt!");
            yield return new WaitForSeconds(0.5f);

            while (true)
            {
                var order = BuildTurnOrder();
                foreach (var unit in order)
                {
                    if (!unit.IsAlive) continue;
                    if (CheckBattleEnd()) yield break;

                    if (unit.isHero)
                    {
                        yield return StartCoroutine(RunHeroTurn(unit));
                    }
                    else
                    {
                        yield return StartCoroutine(RunEnemyTurn(unit));
                    }

                    if (CheckBattleEnd()) yield break;
                }
            }
        }

        private List<BattleUnit> BuildTurnOrder()
        {
            var all = new List<BattleUnit>();
            all.AddRange(_heroUnits);
            all.AddRange(_enemyUnits);
            all.Sort((a, b) => b.Speed.CompareTo(a.Speed));
            return all;
        }

        private bool CheckBattleEnd()
        {
            if (_battleOver) return true;

            bool anyHeroAlive = _heroUnits.Exists(h => h.IsAlive);
            bool anyEnemyAlive = _enemyUnits.Exists(e => e.IsAlive);

            if (!anyEnemyAlive)
            {
                _battleOver = true;
                StartCoroutine(HandleVictory());
                return true;
            }
            if (!anyHeroAlive)
            {
                _battleOver = true;
                StartCoroutine(HandleDefeat());
                return true;
            }
            return false;
        }

        private IEnumerator RunEnemyTurn(BattleUnit enemy)
        {
            var alive = _heroUnits.FindAll(h => h.IsAlive);
            if (alive.Count == 0) yield break;
            var target = alive[Random.Range(0, alive.Count)];

            int damage = Mathf.Max(1, enemy.Attack - target.Defense + Random.Range(-2, 3));
            target.ApplyDamage(damage);
            ui.Log(enemy.Name + " greift " + target.Name + " an! " + damage + " Schaden.");
            ui.RefreshStatus(_heroUnits, _enemyUnits);
            yield return new WaitForSeconds(0.9f);
        }

        private IEnumerator RunHeroTurn(BattleUnit hero)
        {
            BattleAction chosen = null;
            ui.ShowActionMenu(hero, _heroUnits, _enemyUnits, action => chosen = action);
            yield return new WaitUntil(() => chosen != null);
            ui.HideActionMenu();

            yield return StartCoroutine(ResolveAction(hero, chosen));
        }

        private IEnumerator ResolveAction(BattleUnit actor, BattleAction action)
        {
            switch (action.type)
            {
                case BattleActionType.Attack:
                {
                    if (action.target != null && action.target.IsAlive)
                    {
                        int damage = Mathf.Max(1, actor.Attack - action.target.Defense + Random.Range(-2, 3));
                        action.target.ApplyDamage(damage);
                        ui.Log(actor.Name + " greift " + action.target.Name + " an! " + damage + " Schaden.");
                    }
                    break;
                }

                case BattleActionType.Ability:
                {
                    if (!actor.TrySpendMp(action.ability.mpCost))
                    {
                        ui.Log("Nicht genug MP für " + action.ability.abilityName + "!");
                        break;
                    }
                    ApplyAbility(actor, action.ability, action.target);
                    break;
                }

                case BattleActionType.Item:
                {
                    if (action.item != null && action.target != null && action.target.isHero &&
                        GameState.UseItemOn(action.item, action.target.heroMember))
                    {
                        action.target.SyncFromHeroMember();
                        ui.Log(actor.Name + " benutzt " + action.item.itemName + " bei " + action.target.Name + "!");
                    }
                    break;
                }

                case BattleActionType.Flee:
                {
                    if (Random.value < 0.5f)
                    {
                        ui.Log("Flucht erfolgreich!");
                        _battleOver = true;
                        StartCoroutine(HandleFlee());
                    }
                    else
                    {
                        ui.Log("Flucht fehlgeschlagen!");
                    }
                    break;
                }
            }

            ui.RefreshStatus(_heroUnits, _enemyUnits);
            yield return new WaitForSeconds(0.9f);
        }

        private void ApplyAbility(BattleUnit actor, AbilityDefinition ability, BattleUnit primaryTarget)
        {
            var targets = new List<BattleUnit>();
            switch (ability.targetType)
            {
                case AbilityTargetType.SingleEnemy:
                    if (primaryTarget != null && primaryTarget.IsAlive) targets.Add(primaryTarget);
                    break;
                case AbilityTargetType.AllEnemies:
                    targets.AddRange(_enemyUnits.FindAll(e => e.IsAlive));
                    break;
                case AbilityTargetType.SingleAlly:
                    targets.Add(primaryTarget != null ? primaryTarget : actor);
                    break;
                case AbilityTargetType.AllAllies:
                    targets.AddRange(_heroUnits.FindAll(h => h.IsAlive));
                    break;
                case AbilityTargetType.Self:
                    targets.Add(actor);
                    break;
            }

            ui.Log(actor.Name + " setzt " + ability.abilityName + " ein!");

            foreach (var t in targets)
            {
                if (ability.effectType == AbilityEffectType.Damage)
                {
                    int dmg = Mathf.Max(1, ability.power + actor.Magic - t.Defense / 2);
                    t.ApplyDamage(dmg);
                    ui.Log("-> " + t.Name + " erleidet " + dmg + " Schaden.");
                }
                else
                {
                    int heal = ability.power + actor.Magic / 2;
                    t.Heal(heal);
                    ui.Log("-> " + t.Name + " heilt " + heal + " HP.");
                }
            }
        }

        private IEnumerator HandleVictory()
        {
            int gold = 0;
            foreach (var e in _enemyUnits) gold += Random.Range(e.enemyDef.goldMin, e.enemyDef.goldMax + 1);
            GameState.AddGold(gold);
            GameState.ClearPendingEncounter();

            ui.Log("Sieg! Ihr erhaltet " + gold + " Gold.");
            yield return new WaitForSeconds(0.8f);
            ui.ShowVictory(gold, ReturnToOverworld);
        }

        private IEnumerator HandleDefeat()
        {
            ui.Log("Eure Gruppe wurde besiegt...");
            yield return new WaitForSeconds(0.8f);
            ui.ShowDefeat(ReviveAndReturnToTown);
        }

        private IEnumerator HandleFlee()
        {
            yield return new WaitForSeconds(0.6f);
            GameState.ClearPendingEncounter();
            ReturnToOverworld();
        }

        private void ReturnToOverworld()
        {
            string scene = GameState.ReturnScene ?? "WorldMapScene";
            SceneManager.LoadScene(scene);
        }

        private void ReviveAndReturnToTown()
        {
            foreach (var member in GameState.Party)
            {
                member.currentHp = Mathf.Max(1, member.definition.maxHp / 2);
                member.currentMp = member.definition.maxMp;
            }
            GameState.ClearPendingEncounter();
            GameState.ReturnScene = null;
            GameState.ReturnCell = null;
            GameState.NextSpawnId = "Default";
            SceneManager.LoadScene("TownScene");
        }
    }
}
