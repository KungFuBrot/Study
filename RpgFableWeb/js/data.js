"use strict";

/*
 * Spieldaten: Fähigkeiten, Helden, Gegner, Gegenstände, Begegnungstabellen.
 * Hier können später Levelkurven, Erfahrung, Drops usw. ergänzt werden,
 * ohne dass der übrige Code bricht.
 *
 * kind:   "phys" | "magie" | "heil"
 * target: "gegner" | "alleGegner" | "held" | "alleHelden"
 */
const Abilities = {
  wirbelklinge: {
    name: "Wirbelklinge", kind: "phys", target: "alleGegner", power: 6, mp: 5,
    desc: "Ein wirbelnder Rundumschlag, der alle Gegner trifft.",
  },
  schildbrecher: {
    name: "Schildbrecher", kind: "phys", target: "gegner", power: 14, mp: 3,
    desc: "Ein wuchtiger Hieb gegen einen einzelnen Gegner.",
  },
  feuerball: {
    name: "Feuerball", kind: "magie", target: "gegner", power: 16, mp: 4,
    desc: "Schleudert eine Feuerkugel auf einen Gegner.",
  },
  heilendesLicht: {
    name: "Heilendes Licht", kind: "heil", target: "held", power: 20, mp: 5,
    desc: "Stellt die Lebenspunkte eines Verbündeten wieder her.",
  },
  beben: {
    name: "Beben", kind: "phys", target: "alleGegner", power: 5, mp: 0,
    desc: "Der Boden erzittert und trifft die ganze Gruppe.",
  },
};

const Heroes = {
  aria: {
    name: "Aria", klasse: "Schwertkämpferin", sprite: "aria",
    maxHp: 42, maxMp: 12, atk: 11, mag: 4, def: 7, spd: 8,
    abilities: ["wirbelklinge", "schildbrecher"],
  },
  milo: {
    name: "Milo", klasse: "Zauberer", sprite: "milo",
    maxHp: 30, maxMp: 24, atk: 5, mag: 12, def: 4, spd: 6,
    abilities: ["feuerball", "heilendesLicht"],
  },
};

const Enemies = {
  schleim: {
    name: "Schleim", sprite: "schleim",
    maxHp: 18, atk: 6, mag: 2, def: 2, spd: 4, gold: 6,
    ability: null, abilityChance: 0,
  },
  fledermaus: {
    name: "Fledermaus", sprite: "fledermaus",
    maxHp: 14, atk: 7, mag: 3, def: 1, spd: 9, gold: 8,
    ability: null, abilityChance: 0,
  },
  golem: {
    name: "Golem", sprite: "golem",
    maxHp: 40, atk: 9, mag: 4, def: 6, spd: 3, gold: 20,
    ability: "beben", abilityChance: 0.3,
  },
};

const Items = {
  heiltrank: {
    name: "Heiltrank", preis: 20, effekt: "hp", menge: 30,
    desc: "Stellt 30 LP eines Helden wieder her.",
  },
  zaubertrank: {
    name: "Zaubertrank", preis: 35, effekt: "mp", menge: 15,
    desc: "Stellt 15 MP eines Helden wieder her.",
  },
};

/* Zufallskampf-Tabellen: Gegnertyp, Anzahl und Gewichtung. */
const EncounterTables = {
  dungeon: [
    { enemy: "schleim", min: 1, max: 2, gewicht: 5 },
    { enemy: "fledermaus", min: 1, max: 2, gewicht: 4 },
    { enemy: "schleim", min: 3, max: 3, gewicht: 2 },
    { enemy: "golem", min: 1, max: 1, gewicht: 2 },
  ],
};

/* Würfelt eine Gegnergruppe (Liste von Gegner-Kennungen) aus einer Tabelle. */
function rollEncounter(tabellenName) {
  const eintraege = EncounterTables[tabellenName];
  if (!eintraege || eintraege.length === 0) return [];

  let gesamt = 0;
  for (const e of eintraege) gesamt += Math.max(0, e.gewicht);

  let wurf = Math.random() * Math.max(1, gesamt);
  let gewaehlt = eintraege[0];
  for (const e of eintraege) {
    wurf -= Math.max(0, e.gewicht);
    if (wurf < 0) { gewaehlt = e; break; }
  }

  const anzahl = gewaehlt.min + Math.floor(Math.random() * (gewaehlt.max - gewaehlt.min + 1));
  const gruppe = [];
  for (let i = 0; i < Math.max(1, anzahl); i++) gruppe.push(gewaehlt.enemy);
  return gruppe;
}

/*
 * Globaler Spielzustand, der Kartenwechsel überlebt.
 * Ein Speichersystem kann diese Daten später serialisieren.
 */
const GameState = {
  gold: 150,
  party: [],      // { def, hp, mp }
  inventory: [],  // { id, count }

  init() {
    this.party = [Heroes.aria, Heroes.milo].map(def => ({ def, hp: def.maxHp, mp: def.maxMp }));
    this.inventory = [{ id: "heiltrank", count: 3 }, { id: "zaubertrank", count: 1 }];
    this.gold = 150;
  },

  addItem(id, count) {
    const stack = this.inventory.find(s => s.id === id);
    if (stack) stack.count += count;
    else this.inventory.push({ id, count });
  },

  removeItem(id, count) {
    const i = this.inventory.findIndex(s => s.id === id);
    if (i < 0 || this.inventory[i].count < count) return false;
    this.inventory[i].count -= count;
    if (this.inventory[i].count <= 0) this.inventory.splice(i, 1);
    return true;
  },

  healParty() {
    for (const h of this.party) { h.hp = h.def.maxHp; h.mp = h.def.maxMp; }
  },
};
