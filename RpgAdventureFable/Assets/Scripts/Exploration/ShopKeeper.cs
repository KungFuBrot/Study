using UnityEngine;
using RpgFable.Data;
using RpgFable.UI;

namespace RpgFable.Exploration
{
    /// <summary>Eine Händlerin/ein Händler: öffnet beim Ansprechen den Shop.</summary>
    public class ShopKeeper : Interactable
    {
        [SerializeField] private string shopName = "Laden";
        [SerializeField] private ItemDefinition[] wares;

        public override void Interact()
        {
            var ui = FieldUI.Instance;
            if (ui == null) return;
            ui.OpenShop(shopName, wares);
        }
    }
}
