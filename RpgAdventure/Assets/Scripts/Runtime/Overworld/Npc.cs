using UnityEngine;

namespace RpgAdventure
{
    /// <summary>A talkable villager standing on a fixed cell.</summary>
    public class Npc : MonoBehaviour
    {
        public string npcName = "Dorfbewohner";
        [TextArea] public string[] dialogueLines;
        public Vector2Int cell;
    }
}
