"use strict";

/*
 * Rundenbasierter Kampf im Stil klassischer JRPGs.
 * Reihenfolge nach Tempo; Helden wählen Befehle über ein Tastaturmenü.
 * Der Ablauf ist als async-Funktionen geschrieben (entspricht Coroutinen):
 * Menüs warten auf Tasten, Meldungen auf Zeit.
 */

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function unitVonHeld(held) {
  const d = held.def;
  return {
    name: d.name, isHero: true, ref: held,
    hp: held.hp, mp: held.mp, maxHp: d.maxHp, maxMp: d.maxMp,
    atk: d.atk, mag: d.mag, def: d.def, spd: d.spd, gold: 0,
    sprite: d.sprite, x: 0, y: 0, ox: 0, alpha: 1, flash: false,
  };
}

function unitVonGegner(def, name) {
  return {
    name, isHero: false, ref: null,
    hp: def.maxHp, mp: 0, maxHp: def.maxHp, maxMp: 0,
    atk: def.atk, mag: def.mag, def: def.def, spd: def.spd, gold: def.gold,
    ability: def.ability, abilityChance: def.abilityChance,
    sprite: def.sprite, x: 0, y: 0, ox: 0, alpha: 1, flash: false,
  };
}

const Battle = {
  heroes: [],
  enemies: [],
  message: null,
  menu: null,        // { titel, optionen, index }
  cursorUnit: null,  // Gegner unter dem Zielpfeil
  aktiverHeld: null,
  over: false,
  returnKey: null,
  returnPos: null,

  async start(gegnerIds, returnKey, returnPos) {
    Game.mode = "battle";
    Sound.spieleMusik("kampf");
    this.over = false;
    this.message = null;
    this.menu = null;
    this.cursorUnit = null;
    this.aktiverHeld = null;
    this.returnKey = returnKey;
    this.returnPos = returnPos;

    this.heroes = GameState.party.map((held, i) => {
      const unit = unitVonHeld(held);
      unit.x = 480 + i * 24;
      unit.y = 150 + i * 85;
      return unit;
    });

    // Gleichnamige Gegner bekommen A/B/C-Zusätze.
    const anzahl = {};
    for (const id of gegnerIds) anzahl[id] = (anzahl[id] || 0) + 1;
    const vergeben = {};
    const n = gegnerIds.length;
    this.enemies = gegnerIds.map((id, i) => {
      const def = Enemies[id];
      let name = def.name;
      if (anzahl[id] > 1) {
        vergeben[id] = vergeben[id] || 0;
        name += " " + String.fromCharCode(65 + vergeben[id]++);
      }
      const unit = unitVonGegner(def, name);
      unit.x = 165 + (i % 2 === 1 ? -45 : 0);
      unit.y = 195 - (n - 1) * 38 + i * 76;
      return unit;
    });

    await this.ablauf();
  },

  // ------------------------------------------------------------------
  // Kampfschleife
  // ------------------------------------------------------------------

  async ablauf() {
    await this.msg("Gegner erscheinen!", 1100);

    while (!this.over) {
      const reihenfolge = [...this.heroes, ...this.enemies]
        .filter(u => u.hp > 0)
        .sort((a, b) => b.spd - a.spd);

      for (const unit of reihenfolge) {
        if (this.over) break;
        if (unit.hp <= 0) continue;

        if (unit.isHero) await this.heldenzug(unit);
        else await this.gegnerzug(unit);

        if (this.over) break;
        if (this.enemies.every(e => e.hp <= 0)) { await this.sieg(); break; }
        if (this.heroes.every(h => h.hp <= 0)) { await this.niederlage(); break; }
      }
    }
  },

  async heldenzug(held) {
    this.aktiverHeld = held;
    let fertig = false;

    while (!fertig && !this.over) {
      const befehl = await this.zeigeMenu(held.name, ["Angriff", "Fähigkeit", "Gegenstand", "Fliehen"], false);

      if (befehl === 0) {
        const zielIndex = await this.waehleGegner();
        if (zielIndex < 0) continue;
        this.menu = null;
        await this.basisangriff(held, this.enemies[zielIndex]);
        fertig = true;

      } else if (befehl === 1) {
        fertig = await this.heldFaehigkeit(held);

      } else if (befehl === 2) {
        fertig = await this.heldGegenstand(held);

      } else if (befehl === 3) {
        this.menu = null;
        if (Math.random() < 0.6) {
          Sound.sfx("flucht");
          await this.msg("Ihr entkommt dem Kampf!", 1200);
          this.beenden(false);
        } else {
          Sound.sfx("abbrechen");
          await this.msg("Flucht gescheitert!", 1100);
          fertig = true;
        }
      }
    }

    this.menu = null;
    this.cursorUnit = null;
    this.aktiverHeld = null;
  },

  async heldFaehigkeit(held) {
    const ids = held.ref.def.abilities;
    const optionen = ids.map(id => Abilities[id].name + " (" + Abilities[id].mp + " MP)");
    const wahl = await this.zeigeMenu("Fähigkeit", optionen, true);
    if (wahl < 0) return false;

    const faehigkeit = Abilities[ids[wahl]];
    if (held.mp < faehigkeit.mp) {
      await this.msg("Nicht genug MP!", 1000);
      return false;
    }

    let ziele = null;
    if (faehigkeit.target === "gegner") {
      const zielIndex = await this.waehleGegner();
      if (zielIndex < 0) return false;
      ziele = [this.enemies[zielIndex]];
    } else if (faehigkeit.target === "alleGegner") {
      ziele = this.enemies.filter(e => e.hp > 0);
    } else if (faehigkeit.target === "held") {
      const zielIndex = await this.waehleHeld();
      if (zielIndex < 0) return false;
      ziele = [this.heroes[zielIndex]];
    } else {
      ziele = this.heroes.filter(h => h.hp > 0);
    }

    this.menu = null;
    held.mp -= faehigkeit.mp;
    await this.faehigkeitAusfuehren(held, faehigkeit, ziele);
    return true;
  },

  async heldGegenstand(held) {
    if (GameState.inventory.length === 0) {
      await this.msg("Keine Gegenstände im Beutel!", 1000);
      return false;
    }

    const stapel = GameState.inventory.slice();
    const optionen = stapel.map(s => Items[s.id].name + " x" + s.count);
    const wahl = await this.zeigeMenu("Gegenstand", optionen, true);
    if (wahl < 0) return false;

    const zielIndex = await this.waehleHeld();
    if (zielIndex < 0) return false;

    const ziel = this.heroes[zielIndex];
    const item = Items[stapel[wahl].id];
    this.menu = null;

    GameState.removeItem(stapel[wahl].id, 1);
    Sound.sfx("item");
    Fx.heilung(ziel.x, ziel.y);
    if (item.effekt === "hp") {
      ziel.hp = Math.min(ziel.maxHp, ziel.hp + item.menge);
      Fx.zahl(ziel.x, ziel.y - 46, "+" + item.menge, "rgb(140,255,160)");
      await this.msg(held.name + " setzt " + item.name + " ein. " + ziel.name + " erhält " + item.menge + " LP!", 1300);
    } else {
      ziel.mp = Math.min(ziel.maxMp, ziel.mp + item.menge);
      Fx.zahl(ziel.x, ziel.y - 46, "+" + item.menge + " MP", "rgb(140,190,255)");
      await this.msg(held.name + " setzt " + item.name + " ein. " + ziel.name + " erhält " + item.menge + " MP!", 1300);
    }
    return true;
  },

  async gegnerzug(gegner) {
    const lebende = this.heroes.filter(h => h.hp > 0);
    if (lebende.length === 0) return;

    if (gegner.ability && Math.random() < gegner.abilityChance) {
      const faehigkeit = Abilities[gegner.ability];
      const ziele = (faehigkeit.target === "alleGegner" || faehigkeit.target === "alleHelden")
        ? lebende
        : [lebende[Math.floor(Math.random() * lebende.length)]];
      await this.faehigkeitAusfuehren(gegner, faehigkeit, ziele);
    } else {
      const ziel = lebende[Math.floor(Math.random() * lebende.length)];
      await this.basisangriff(gegner, ziel);
    }
  },

  // ------------------------------------------------------------------
  // Aktionen und Schaden
  // ------------------------------------------------------------------

  async basisangriff(angreifer, ziel) {
    Sound.sfx("schwert");
    await this.bump(angreifer);
    const schaden = this.physSchaden(angreifer.atk * 2 - ziel.def);
    await this.schadenAnwenden(angreifer.name + " greift " + ziel.name + " an!", ziel, schaden, "schlag");
  },

  async faehigkeitAusfuehren(anwender, faehigkeit, ziele) {
    if (faehigkeit.kind === "magie") Sound.sfx("magie");
    else if (faehigkeit.kind === "phys") Sound.sfx(anwender.isHero ? "schwert" : "beben");
    if (faehigkeit.kind !== "heil") Fx.blitz("rgb(255,255,255)", 0.25);
    await this.msg(anwender.name + " setzt " + faehigkeit.name + " ein!", 1000);
    await this.bump(anwender);
    if (!anwender.isHero && faehigkeit.kind === "phys") Fx.schuetteln(6, 0.45);

    for (const ziel of ziele) {
      if (ziel.hp <= 0) continue;

      if (faehigkeit.kind === "phys") {
        const schaden = this.physSchaden(faehigkeit.power + anwender.atk * 2 - ziel.def);
        await this.schadenAnwenden(null, ziel, schaden, "schlag");
      } else if (faehigkeit.kind === "magie") {
        const schaden = this.physSchaden(faehigkeit.power + anwender.mag * 2 - Math.floor(ziel.def / 2));
        await this.schadenAnwenden(null, ziel, schaden, "magie");
      } else {
        const heilung = Math.max(1, faehigkeit.power + anwender.mag);
        ziel.hp = Math.min(ziel.maxHp, ziel.hp + heilung);
        Sound.sfx("heilung");
        Fx.heilung(ziel.x, ziel.y);
        Fx.zahl(ziel.x, ziel.y - 46, "+" + heilung, "rgb(140,255,160)");
        await this.msg(ziel.name + " erhält " + heilung + " LP zurück!", 1100);
      }

      if (this.enemies.every(e => e.hp <= 0) || this.heroes.every(h => h.hp <= 0)) return;
    }
  },

  physSchaden(basis) {
    const streuung = 0.85 + Math.random() * 0.30;
    return Math.max(1, Math.round(basis * streuung));
  },

  async schadenAnwenden(einleitung, ziel, schaden, art) {
    if (einleitung) await this.msg(einleitung, 800);

    ziel.hp = Math.max(0, ziel.hp - schaden);
    if (art === "magie") {
      Sound.sfx("feuer");
      Fx.feuer(ziel.x, ziel.y);
      Fx.schuetteln(5, 0.3);
    } else {
      Sound.sfx("treffer");
      Fx.schnitt(ziel.x, ziel.y);
      Fx.schuetteln(3, 0.18);
    }
    Fx.zahl(ziel.x, ziel.y - 46, String(schaden), ziel.isHero ? "rgb(255,150,140)" : "rgb(255,255,255)");
    await this.flash(ziel);
    await this.msg(ziel.name + " erleidet " + schaden + " Schaden!", 1000);

    if (ziel.hp <= 0) {
      Sound.sfx("besiegt");
      Fx.aufloesen(ziel.x, ziel.y);
      await this.fade(ziel);
      await this.msg(ziel.name + " wurde besiegt!", 1000);
    }
  },

  // ------------------------------------------------------------------
  // Kampfende
  // ------------------------------------------------------------------

  async sieg() {
    this.over = true;
    Sound.spieleMusik("sieg");
    let gold = 0;
    for (const e of this.enemies) gold += e.gold;
    GameState.gold += gold;
    await this.msg("Sieg!", 1000);
    await this.msgTaste("Ihr erhaltet " + gold + " Gold!  [E] Weiter");
    this.beenden(false);
  },

  async niederlage() {
    this.over = true;
    Sound.spieleMusik("niederlage");
    await this.msg("Die Gruppe wurde besiegt...", 1400);
    await this.msgTaste("Ihr erwacht in der Stadt.  [E] Weiter");
    this.heldenZurueckschreiben();
    for (const held of GameState.party) held.hp = Math.max(1, held.hp);
    Game.mode = "field";
    Field.load("stadt", "Start");
  },

  beenden(zurStadt) {
    this.over = true;
    this.heldenZurueckschreiben();
    Game.mode = "field";
    if (zurStadt) Field.load("stadt", "Start");
    else Field.load(this.returnKey, { pos: this.returnPos });
  },

  heldenZurueckschreiben() {
    for (const unit of this.heroes) {
      if (!unit.ref) continue;
      unit.ref.hp = Math.max(0, Math.min(unit.maxHp, unit.hp));
      unit.ref.mp = Math.max(0, Math.min(unit.maxMp, unit.mp));
    }
  },

  // ------------------------------------------------------------------
  // Menüs und Zielauswahl
  // ------------------------------------------------------------------

  async zeigeMenu(titel, optionen, abbruchErlaubt) {
    this.menu = { titel, optionen, index: 0 };
    while (true) {
      const taste = await Input.nextKey();
      if (taste === "down") { this.menu.index = (this.menu.index + 1) % optionen.length; Sound.sfx("menu"); }
      else if (taste === "up") { this.menu.index = (this.menu.index - 1 + optionen.length) % optionen.length; Sound.sfx("menu"); }
      else if (taste === "confirm") { Sound.sfx("bestaetigen"); return this.menu.index; }
      else if (taste === "cancel" && abbruchErlaubt) { Sound.sfx("abbrechen"); return -1; }
    }
  },

  /* Zielauswahl unter lebenden Gegnern; Ergebnis: Index in enemies oder -1. */
  async waehleGegner() {
    const lebende = [];
    for (let i = 0; i < this.enemies.length; i++) if (this.enemies[i].hp > 0) lebende.push(i);
    if (lebende.length === 0) return -1;

    let cursor = 0;
    this.cursorUnit = this.enemies[lebende[cursor]];
    this.menu = { titel: "Ziel wählen", optionen: [this.cursorUnit.name], index: 0 };

    while (true) {
      const taste = await Input.nextKey();
      if (taste === "down" || taste === "right") { cursor = (cursor + 1) % lebende.length; Sound.sfx("menu"); }
      else if (taste === "up" || taste === "left") { cursor = (cursor - 1 + lebende.length) % lebende.length; Sound.sfx("menu"); }
      else if (taste === "confirm") { Sound.sfx("bestaetigen"); this.cursorUnit = null; return lebende[cursor]; }
      else if (taste === "cancel") { Sound.sfx("abbrechen"); this.cursorUnit = null; return -1; }
      this.cursorUnit = this.enemies[lebende[cursor]];
      this.menu = { titel: "Ziel wählen", optionen: [this.cursorUnit.name], index: 0 };
    }
  },

  /* Zielauswahl unter Helden; gefallene Helden können (noch) nicht Ziel sein. */
  async waehleHeld() {
    const optionen = this.heroes.map(h => h.name + "  (" + h.hp + "/" + h.maxHp + " LP)");
    const wahl = await this.zeigeMenu("Wen?", optionen, true);
    if (wahl >= 0 && this.heroes[wahl].hp <= 0) return -1;
    return wahl;
  },

  // ------------------------------------------------------------------
  // Meldungen und kleine Animationen
  // ------------------------------------------------------------------

  async msg(text, ms) {
    this.message = text;
    await sleep(ms);
  },

  async msgTaste(text) {
    this.message = text;
    while ((await Input.nextKey()) !== "confirm") { /* warten */ }
  },

  async bump(unit) {
    const richtung = unit.isHero ? -1 : 1;
    for (let f = 0; f < 1; f += 0.2) { unit.ox = richtung * 11 * f; await sleep(16); }
    for (let f = 1; f > 0; f -= 0.2) { unit.ox = richtung * 11 * f; await sleep(16); }
    unit.ox = 0;
  },

  async flash(unit) {
    for (let i = 0; i < 2; i++) {
      unit.flash = true; await sleep(60);
      unit.flash = false; await sleep(60);
    }
  },

  async fade(unit) {
    for (let a = 1; a > 0; a -= 0.12) { unit.alpha = Math.max(0, a); await sleep(30); }
    unit.alpha = 0;
  },

  // ------------------------------------------------------------------
  // Darstellung
  // ------------------------------------------------------------------

  draw(ctx) {
    const t = performance.now();
    ctx.fillStyle = "rgb(8,8,14)";
    ctx.fillRect(0, 0, 640, 360);
    ctx.imageSmoothingEnabled = false;

    // Weltebene: wird beim Bildschirmwackeln als Ganzes verschoben
    const versatz = Fx.offset();
    ctx.save();
    ctx.translate(versatz[0], versatz[1]);
    ctx.drawImage(Sprites.kampfHintergrund, 0, 0);

    for (let i = 0; i < this.enemies.length; i++) {
      const e = this.enemies[i];
      if (e.alpha <= 0) continue;
      const wippen = Math.sin(t / 260 + i * 1.7) * 3; // Gegner schweben leicht
      ctx.globalAlpha = e.alpha;
      const bild = e.flash ? Sprites.tinted[e.sprite] : Sprites.enemies[e.sprite];
      ctx.drawImage(bild, e.x + e.ox - 55, e.y - 55 + wippen, 110, 110);
      ctx.globalAlpha = 1;
    }

    for (let i = 0; i < this.heroes.length; i++) {
      const h = this.heroes[i];
      if (h.alpha <= 0) continue;
      if (h === this.aktiverHeld) {
        fillEllipse(ctx, h.x, h.y + 40, 34, 8, "rgba(255,230,140,0.28)"); // Leuchten unterm aktiven Helden
      }
      const wippen = Math.sin(t / 340 + i * 2.1) * 1.5; // ruhiges Atmen
      ctx.globalAlpha = h.alpha;
      const bild = h.flash ? Sprites.tinted[h.sprite] : Sprites.chars[h.sprite];
      ctx.drawImage(bild, h.x + h.ox - 42, h.y - 42 + wippen, 84, 84);
      ctx.globalAlpha = 1;
    }

    // Zielpfeil über dem gewählten Gegner (hüpft leicht)
    if (this.cursorUnit) {
      const u = this.cursorUnit;
      fillCursor(ctx, u.x, u.y - 68 + Math.sin(t / 160) * 3);
    }

    Fx.drawWelt(ctx); // Partikel und Schadenszahlen
    ctx.restore();

    // Statusfenster (unten rechts)
    UI.panel(ctx, 330, 288, 296, 62);
    for (let i = 0; i < this.heroes.length; i++) {
      const h = this.heroes[i];
      const marker = h === this.aktiverHeld ? "> " : "  ";
      const tot = h.hp > 0 ? "" : " (k.o.)";
      UI.text(ctx, marker + h.name + "  LP " + h.hp + "/" + h.maxHp + "  MP " + h.mp + "/" + h.maxMp + tot,
        344, 300 + i * 20, { farbe: h.hp > 0 ? undefined : "rgb(200,120,120)" });
    }

    // Befehlsfenster (unten links)
    if (this.menu) {
      const hoehe = 34 + this.menu.optionen.length * 18;
      UI.panel(ctx, 14, 346 - hoehe, 210, hoehe);
      UI.text(ctx, "- " + this.menu.titel + " -", 28, 356 - hoehe, { font: UI.FONT_GROSS, farbe: "rgb(230,214,150)" });
      for (let i = 0; i < this.menu.optionen.length; i++) {
        const marker = i === this.menu.index ? "> " : "  ";
        UI.text(ctx, marker + this.menu.optionen[i], 28, 376 - hoehe + i * 18,
          { farbe: i === this.menu.index ? "rgb(255,238,170)" : undefined });
      }
    }

    // Meldungsfenster (oben)
    if (this.message) {
      UI.panel(ctx, 90, 14, 460, 40);
      UI.text(ctx, this.message, 320, 27, { align: "center", font: UI.FONT_GROSS });
    }
  },
};

/* Gefüllte Ellipse (Leuchten unter dem aktiven Helden). */
function fillEllipse(ctx, cx, cy, rx, ry, farbe) {
  ctx.beginPath();
  ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
  ctx.fillStyle = farbe;
  ctx.fill();
}

/* Gelber Zielpfeil (zeigt nach unten). */
function fillCursor(ctx, x, y) {
  ctx.beginPath();
  ctx.moveTo(x - 9, y);
  ctx.lineTo(x + 9, y);
  ctx.lineTo(x, y + 14);
  ctx.closePath();
  ctx.fillStyle = "rgb(64,46,13)";
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(x - 6.5, y + 1.5);
  ctx.lineTo(x + 6.5, y + 1.5);
  ctx.lineTo(x, y + 11.5);
  ctx.closePath();
  ctx.fillStyle = "rgb(255,217,64)";
  ctx.fill();
}
