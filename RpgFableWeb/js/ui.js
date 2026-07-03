"use strict";

/* Fallback für ältere Browser ohne ctx.roundRect. */
if (!CanvasRenderingContext2D.prototype.roundRect) {
  CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, r) {
    const radius = Math.min(r, w / 2, h / 2);
    this.moveTo(x + radius, y);
    this.arcTo(x + w, y, x + w, y + h, radius);
    this.arcTo(x + w, y + h, x, y + h, radius);
    this.arcTo(x, y + h, x, y, radius);
    this.arcTo(x, y, x + w, y, radius);
    this.closePath();
  };
}

/*
 * Zeichenhelfer für Fenster und Text sowie die Feld-UI
 * (Interaktionshinweis, Dialogfenster, Shop).
 */
const UI = {
  FONT: '13px "Courier New", monospace',
  FONT_GROSS: 'bold 14px "Courier New", monospace',

  /* Klassisches JRPG-Fenster: heller Rand, dunkle Füllung. */
  panel(ctx, x, y, w, h) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, 7);
    ctx.fillStyle = "rgba(18,20,38,0.94)";
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = "rgb(89,84,71)";
    ctx.stroke();
    ctx.beginPath();
    ctx.roundRect(x - 2, y - 2, w + 4, h + 4, 9);
    ctx.lineWidth = 2;
    ctx.strokeStyle = "rgb(204,194,163)";
    ctx.stroke();
  },

  text(ctx, str, x, y, opts) {
    const o = opts || {};
    ctx.font = o.font || UI.FONT;
    ctx.textAlign = o.align || "left";
    ctx.textBaseline = "top";
    if (o.schatten) {
      ctx.fillStyle = "rgba(0,0,0,0.8)";
      ctx.fillText(str, x + 1, y + 1);
    }
    ctx.fillStyle = o.farbe || "rgb(242,240,224)";
    ctx.fillText(str, x, y);
  },

  /* Bricht einen Text an Wortgrenzen auf die maximale Breite um. */
  wrap(ctx, str, maxBreite) {
    ctx.font = UI.FONT;
    const woerter = str.split(" ");
    const zeilen = [];
    let zeile = "";
    for (const wort of woerter) {
      const test = zeile === "" ? wort : zeile + " " + wort;
      if (ctx.measureText(test).width > maxBreite && zeile !== "") {
        zeilen.push(zeile);
        zeile = wort;
      } else {
        zeile = test;
      }
    }
    if (zeile !== "") zeilen.push(zeile);
    return zeilen;
  },
};

/*
 * UI für die Erkundung: Dialogfenster und Shop.
 * [E]/[Enter]/[Leertaste] weiter bzw. kaufen, [Esc] schließen,
 * [W/S] bzw. Pfeiltasten wählen im Shop.
 */
const FieldUI = {
  mode: null, // null | "dialog" | "shop"
  hint: "",
  sprecher: "",
  lines: [],
  index: 0,
  shopName: "",
  waren: [],
  cursor: 0,
  meldung: "",
  geradeGeoeffnet: false,

  get busy() { return this.mode !== null; },

  close() {
    this.mode = null;
    this.hint = "";
  },

  openDialog(sprecher, lines) {
    this.mode = "dialog";
    this.sprecher = sprecher;
    this.lines = lines;
    this.index = 0;
    this.geradeGeoeffnet = true;
    this.hint = "";
  },

  openShop(shopName, warenIds) {
    this.mode = "shop";
    this.shopName = shopName;
    this.waren = warenIds;
    this.cursor = 0;
    this.meldung = "Was darf es sein?";
    this.geradeGeoeffnet = true;
    this.hint = "";
  },

  update() {
    if (this.geradeGeoeffnet) { this.geradeGeoeffnet = false; return; } // Öffnen-Taste nicht weiterreichen
    if (this.mode === "dialog") this.updateDialog();
    else if (this.mode === "shop") this.updateShop();
  },

  updateDialog() {
    if (!Input.pressed("confirm")) return;
    Sound.sfx("dialog");
    this.index++;
    if (this.index >= this.lines.length) this.mode = null;
  },

  updateShop() {
    if (Input.pressed("cancel")) { Sound.sfx("abbrechen"); this.mode = null; return; }

    if (Input.pressed("down")) {
      this.cursor = (this.cursor + 1) % this.waren.length;
      this.meldung = "Was darf es sein?";
      Sound.sfx("menu");
    } else if (Input.pressed("up")) {
      this.cursor = (this.cursor - 1 + this.waren.length) % this.waren.length;
      this.meldung = "Was darf es sein?";
      Sound.sfx("menu");
    } else if (Input.pressed("confirm")) {
      const item = Items[this.waren[this.cursor]];
      if (GameState.gold >= item.preis) {
        GameState.gold -= item.preis;
        GameState.addItem(this.waren[this.cursor], 1);
        this.meldung = item.name + " gekauft!";
        Sound.sfx("kaufen");
      } else {
        this.meldung = "Nicht genug Gold!";
        Sound.sfx("abbrechen");
      }
    }
  },

  draw(ctx) {
    if (this.hint && this.mode === null) {
      UI.text(ctx, this.hint, 320, 336, { align: "center", schatten: true, font: UI.FONT_GROSS });
    }
    if (this.mode === "dialog") this.drawDialog(ctx);
    else if (this.mode === "shop") this.drawShop(ctx);
  },

  drawDialog(ctx) {
    const x = 90, y = 252, w = 460, h = 96;
    UI.panel(ctx, x, y, w, h);
    UI.text(ctx, this.sprecher, x + 16, y + 10, { font: UI.FONT_GROSS, farbe: "rgb(230,214,150)" });
    const zeilen = UI.wrap(ctx, this.lines[this.index], w - 32);
    for (let i = 0; i < zeilen.length && i < 3; i++) {
      UI.text(ctx, zeilen[i], x + 16, y + 30 + i * 16);
    }
    const weiter = this.index < this.lines.length - 1 ? "[E] Weiter" : "[E] Schließen";
    UI.text(ctx, weiter, x + w - 16, y + h - 20, { align: "right", farbe: "rgb(160,158,178)" });
  },

  drawShop(ctx) {
    const x = 140, y = 60, w = 360, h = 240;
    UI.panel(ctx, x, y, w, h);
    UI.text(ctx, "== " + this.shopName + " ==", x + 16, y + 12, { font: UI.FONT_GROSS, farbe: "rgb(230,214,150)" });
    UI.text(ctx, "Gold: " + GameState.gold + " G", x + w - 16, y + 12, { align: "right", farbe: "rgb(240,214,110)" });

    for (let i = 0; i < this.waren.length; i++) {
      const item = Items[this.waren[i]];
      const marker = i === this.cursor ? "> " : "  ";
      UI.text(ctx, marker + item.name, x + 20, y + 44 + i * 20,
        { farbe: i === this.cursor ? "rgb(255,238,170)" : undefined });
      UI.text(ctx, item.preis + " G", x + w - 24, y + 44 + i * 20, { align: "right" });
    }

    const item = Items[this.waren[this.cursor]];
    const infoZeilen = UI.wrap(ctx, item.desc, w - 40);
    for (let i = 0; i < infoZeilen.length && i < 2; i++) {
      UI.text(ctx, infoZeilen[i], x + 20, y + h - 76 + i * 16, { farbe: "rgb(190,188,200)" });
    }
    UI.text(ctx, this.meldung, x + 20, y + h - 42, { farbe: "rgb(230,214,150)" });
    UI.text(ctx, "[E] Kaufen    [Esc] Verlassen", x + w - 16, y + h - 22, { align: "right", farbe: "rgb(160,158,178)" });
  },
};
