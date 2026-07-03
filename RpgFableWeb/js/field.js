"use strict";

/*
 * Erkundungsmodus: Bewegung auf den Karten, Kamera, NPCs, Portale
 * und Zufallskämpfe. Positionen sind in Kacheleinheiten (1 = 32 px).
 */
const Field = {
  key: null,       // aktuelles Gebiet ("stadt" | "weltkarte" | "dungeon")
  area: null,
  x: 0, y: 0,      // Spielfigur (Kachelmitte = x.5)
  speed: 4,        // Kacheln pro Sekunde
  naherNpc: null,
  seitPruefung: 0,
  seitStart: 0,    // zurückgelegte Distanz seit Kartenwechsel (Schonfrist)

  /* Lädt ein Gebiet; spawn ist ein Spawnpunkt-Name oder {pos:[x,y]}. */
  load(key, spawn) {
    this.key = key;
    this.area = Areas[key];
    if (typeof spawn === "string") {
      const s = this.area.spawns[spawn];
      this.x = s[0] + 0.5;
      this.y = s[1] + 0.5;
    } else {
      this.x = spawn.pos[0];
      this.y = spawn.pos[1];
    }
    this.naherNpc = null;
    this.seitPruefung = 0;
    this.seitStart = 0;
    FieldUI.close();
    Sound.spieleMusik(key);
  },

  update(dt) {
    if (Fx.blockiert) return; // während einer Überblendung ist alles eingefroren
    if (FieldUI.busy) { FieldUI.update(); return; }

    // --- Bewegung mit Kollision (achsengetrennt) ---
    let mx = (Input.down("right") ? 1 : 0) - (Input.down("left") ? 1 : 0);
    let my = (Input.down("down") ? 1 : 0) - (Input.down("up") ? 1 : 0);
    if (mx !== 0 && my !== 0) { mx *= Math.SQRT1_2; my *= Math.SQRT1_2; }

    const altX = this.x, altY = this.y;
    this.tryMove(mx * this.speed * dt, my * this.speed * dt);
    const bewegt = Math.hypot(this.x - altX, this.y - altY);

    // --- Portale (Kachel unter der Spielfigur) ---
    const col = Math.floor(this.x), row = Math.floor(this.y);
    for (const portal of this.area.portals) {
      if (portal.col === col && portal.row === row) {
        Fx.blende(() => this.load(portal.ziel, portal.spawn));
        return;
      }
    }

    // --- Interaktion mit NPCs ---
    this.naherNpc = null;
    let beste = 1.3 * 1.3;
    for (const npc of this.area.npcs) {
      const dx = npc.col + 0.5 - this.x, dy = npc.row + 0.5 - this.y;
      const dist = dx * dx + dy * dy;
      if (dist < beste) { beste = dist; this.naherNpc = npc; }
    }
    FieldUI.hint = this.naherNpc ? this.naherNpc.hint : "";

    if (this.naherNpc && Input.pressed("confirm")) {
      this.interact(this.naherNpc);
      return;
    }

    // --- Zufallskämpfe ---
    const enc = this.area.encounters;
    if (enc && bewegt > 0) {
      this.seitStart += bewegt;
      if (this.seitStart >= enc.schonfrist) {
        this.seitPruefung += bewegt;
        if (this.seitPruefung >= enc.pruefDistanz) {
          this.seitPruefung -= enc.pruefDistanz;
          if (Math.random() < enc.chance) {
            const gruppe = rollEncounter(enc.tabelle);
            if (gruppe.length > 0) {
              Sound.sfx("begegnung");
              const key = this.key, pos = [this.x, this.y];
              Fx.kampfBlende(() => Battle.start(gruppe, key, pos));
            }
          }
        }
      }
    }
  },

  interact(npc) {
    if (npc.art === "shop") {
      Sound.sfx("dialog");
      FieldUI.openShop(npc.name, npc.waren);
    } else {
      if (npc.heilt) { GameState.healParty(); Sound.sfx("heilung"); }
      else Sound.sfx("dialog");
      FieldUI.openDialog(npc.name, npc.lines);
    }
  },

  /* Achsengetrennte Bewegung gegen blockierte Kacheln. */
  tryMove(dx, dy) {
    const h = 0.30; // halbe Kantenlänge der Kollisionsbox
    if (dx !== 0 && !this.boxBlockiert(this.x + dx, this.y, h)) this.x += dx;
    if (dy !== 0 && !this.boxBlockiert(this.x, this.y + dy, h)) this.y += dy;
  },

  boxBlockiert(cx, cy, h) {
    const map = this.area.map;
    for (const ex of [cx - h, cx + h]) {
      for (const ey of [cy - h, cy + h]) {
        if (istBlockiert(map, Math.floor(ex), Math.floor(ey))) return true;
      }
    }
    // NPCs blockieren ebenfalls (man kann nicht durch sie hindurchlaufen).
    for (const npc of this.area.npcs) {
      if (Math.abs(npc.col + 0.5 - cx) < h + 0.35 && Math.abs(npc.row + 0.5 - cy) < h + 0.35) return true;
    }
    return false;
  },

  draw(ctx) {
    const T = Sprites.TILE;
    const map = this.area.map;
    const mapW = map[0].length * T, mapH = map.length * T;

    // Kamera auf die Spielfigur, an den Kartenrändern begrenzt
    let camX = this.x * T - 320, camY = this.y * T - 180;
    camX = mapW <= 640 ? (mapW - 640) / 2 : Math.max(0, Math.min(camX, mapW - 640));
    camY = mapH <= 360 ? (mapH - 360) / 2 : Math.max(0, Math.min(camY, mapH - 360));
    camX = Math.round(camX); camY = Math.round(camY);

    ctx.fillStyle = "rgb(8,8,14)";
    ctx.fillRect(0, 0, 640, 360);
    ctx.drawImage(Sprites.maps[this.key], -camX, -camY);

    for (const npc of this.area.npcs) {
      ctx.drawImage(Sprites.chars[npc.sprite],
        Math.round((npc.col + 0.5) * T - 16 - camX),
        Math.round((npc.row + 0.5) * T - 18 - camY));
    }

    ctx.drawImage(Sprites.chars.aria,
      Math.round(this.x * T - 16 - camX),
      Math.round(this.y * T - 18 - camY));

    FieldUI.draw(ctx);
  },
};
