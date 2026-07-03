"use strict";

/*
 * Eingabe: bildet physische Tasten auf logische Aktionen ab.
 * - down(aktion):    Taste ist gerade gedrückt (für Bewegung)
 * - pressed(aktion): Taste wurde in diesem Frame gedrückt (für Menüs im Feld)
 * - nextKey():       Promise auf den nächsten Tastendruck (für den Kampf)
 */
const Input = {
  _down: {},
  _pressed: {},
  _warteschlange: [],

  _logisch(key) {
    switch (key) {
      case "ArrowUp": case "w": case "W": return "up";
      case "ArrowDown": case "s": case "S": return "down";
      case "ArrowLeft": case "a": case "A": return "left";
      case "ArrowRight": case "d": case "D": return "right";
      case "e": case "E": case "Enter": case " ": return "confirm";
      case "Escape": case "Backspace": return "cancel";
      default: return null;
    }
  },

  init() {
    window.addEventListener("keydown", e => {
      Sound.entsperren(); // Browser erlauben Ton erst nach einer Eingabe
      if (e.key === "m" || e.key === "M") { Sound.toggleStumm(); return; }
      const aktion = this._logisch(e.key);
      if (!aktion) return;
      e.preventDefault();
      if (e.repeat) return;
      this._down[aktion] = true;
      this._pressed[aktion] = true;
      const wartender = this._warteschlange.shift();
      if (wartender) wartender(aktion);
    });
    window.addEventListener("keyup", e => {
      const aktion = this._logisch(e.key);
      if (aktion) this._down[aktion] = false;
    });
  },

  down(aktion) { return !!this._down[aktion]; },
  pressed(aktion) { return !!this._pressed[aktion]; },
  nextKey() { return new Promise(r => this._warteschlange.push(r)); },
  endFrame() { this._pressed = {}; },
};

/* Spielmodus und Hauptschleife. */
const Game = {
  mode: "field", // "field" | "battle"
  ctx: null,
};

(function boot() {
  const canvas = document.getElementById("spiel");
  Game.ctx = canvas.getContext("2d");
  Game.ctx.imageSmoothingEnabled = false;

  Input.init();
  Sprites.init();
  GameState.init();
  Field.load("stadt", "Start");

  let letzteZeit = performance.now();
  function frame(zeit) {
    const dt = Math.min(0.05, (zeit - letzteZeit) / 1000);
    letzteZeit = zeit;

    Fx.update(dt);

    if (Game.mode === "field") {
      Field.update(dt);
      // update kann in den Kampfmodus wechseln — dann nicht mehr das Feld zeichnen
      if (Game.mode === "field") Field.draw(Game.ctx);
    }
    if (Game.mode === "battle") {
      Battle.draw(Game.ctx);
    }

    Fx.drawUeber(Game.ctx); // Aufblitzen und Überblendungen über allem

    Input.endFrame();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
