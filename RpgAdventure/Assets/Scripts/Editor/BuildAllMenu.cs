using UnityEditor;

namespace RpgAdventure.EditorTools
{
    /// <summary>Convenience menu item that runs all six setup steps back to back.</summary>
    public static class BuildAllMenu
    {
        [MenuItem("RPG Spiel/Alles erstellen (1-6)")]
        public static void BuildEverything()
        {
            RpgTextureGenerator.GenerateAll();
            RpgDataBuilder.GenerateAll();
            TownSceneBuilder.BuildScene();
            WorldMapSceneBuilder.BuildScene();
            DungeonSceneBuilder.BuildScene();
            BattleSceneBuilder.BuildScene();
        }
    }
}
