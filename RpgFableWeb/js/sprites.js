"use strict";

/*
 * Erzeugt sämtliche Grafiken prozedural auf Offscreen-Canvases:
 * Kartenkacheln, Figuren, Gegner und den Kampfhintergrund.
 * Es werden keinerlei externe Bilddateien benötigt.
 */
const Sprites = (() => {
  const TILE = 32;

  // ------------------------------------------------------------------
  // Kleine Zeichenhelfer (Farben als [r,g,b] mit Werten 0–255)
  // ------------------------------------------------------------------

  function col(c, a) {
    const alpha = a === undefined ? 1 : a;
    return "rgba(" + (c[0] | 0) + "," + (c[1] | 0) + "," + (c[2] | 0) + "," + alpha + ")";
  }

  function shade(c, f) {
    return [Math.min(255, c[0] * f), Math.min(255, c[1] * f), Math.min(255, c[2] * f)];
  }

  function makeCanvas(w, h) {
    const c = document.createElement("canvas");
    c.width = w; c.height = h;
    return c;
  }

  function fillEll(ctx, cx, cy, rx, ry, fill) {
    ctx.beginPath();
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  function fillCirc(ctx, cx, cy, r, fill) { fillEll(ctx, cx, cy, r, r, fill); }

  function fillRRect(ctx, x, y, w, h, r, fill) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  function fillTri(ctx, ax, ay, bx, by, cx, cy, fill) {
    ctx.beginPath();
    ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.lineTo(cx, cy);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
  }

  function fillSeg(ctx, ax, ay, bx, by, breite, stroke) {
    ctx.beginPath();
    ctx.moveTo(ax, ay); ctx.lineTo(bx, by);
    ctx.lineWidth = breite;
    ctx.lineCap = "round";
    ctx.strokeStyle = stroke;
    ctx.stroke();
  }

  /* Deterministisches Pixelrauschen (z. B. Grasstruktur). */
  function hash01(x, y, seed) {
    let h = (x * 374761393 + y * 668265263 + seed * 974634541) >>> 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
    return ((h >>> 8) & 0xFFFF) / 65535;
  }

  function noise(ctx, ox, oy, w, h, seed, dichte, fill) {
    ctx.fillStyle = fill;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (hash01(x, y, seed) < dichte) ctx.fillRect(ox + x, oy + y, 1, 1);
      }
    }
  }

  // ------------------------------------------------------------------
  // Kacheln (32×32, gezeichnet an Offset ox/oy; y zeigt nach unten)
  // ------------------------------------------------------------------

  function grasTile(ctx, ox, oy, seed, basis) {
    ctx.fillStyle = col(basis);
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.20, col(shade(basis, 0.85)));
    noise(ctx, ox, oy, TILE, TILE, seed + 7, 0.10, col(shade(basis, 1.15)));
  }

  const GRAS_STADT = [84, 133, 69];
  const GRAS_WELT = [120, 158, 87];

  function blumenTile(ctx, ox, oy, seed) {
    grasTile(ctx, ox, oy, seed, GRAS_STADT);
    const bluetenfarben = ["rgb(242,140,166)", "rgb(242,230,128)", "rgb(235,235,242)"];
    for (let k = 0; k < 3; k++) {
      const fx = ox + 5 + hash01(k, 7, seed) * 22;
      const fy = oy + 5 + hash01(k, 11, seed) * 22;
      fillCirc(ctx, fx, fy, 1.7, bluetenfarben[Math.floor(hash01(k, 13, seed) * 2.99)]);
      fillCirc(ctx, fx, fy, 0.7, "rgb(242,191,64)");
    }
  }

  function wegTile(ctx, ox, oy, seed) {
    ctx.fillStyle = "rgb(184,161,112)";
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.25, "rgb(163,140,94)");
    noise(ctx, ox, oy, TILE, TILE, seed + 3, 0.12, "rgb(201,181,133)");
  }

  function wasserTile(ctx, ox, oy, seed, basis) {
    ctx.fillStyle = col(basis);
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.10, col(shade(basis, 0.9)));
    const welle = "rgba(153,194,235,0.65)";
    const y1 = oy + 7 + hash01(1, 2, seed) * 6;
    const y2 = oy + 19 + hash01(3, 4, seed) * 6;
    fillSeg(ctx, ox + 6, y1, ox + 14, y1, 1.6, welle);
    fillSeg(ctx, ox + 18, y2, ox + 26, y2, 1.6, welle);
  }

  function baumTile(ctx, ox, oy, seed) {
    grasTile(ctx, ox, oy, seed, GRAS_STADT);
    const dx = (hash01(5, 9, seed) - 0.5) * 3;
    fillRRect(ctx, ox + 14 + dx, oy + 20, 4.4, 9, 1, "rgb(107,74,43)");   // Stamm unten
    fillCirc(ctx, ox + 16 + dx, oy + 14, 9.5, "rgb(41,89,43)");           // Krone
    fillCirc(ctx, ox + 13 + dx, oy + 11, 4.8, "rgb(56,112,56)");
    fillCirc(ctx, ox + 20 + dx, oy + 16, 4.2, "rgb(48,102,51)");
  }

  function dachTile(ctx, ox, oy) {
    const basis = [161, 74, 59];
    ctx.fillStyle = col(basis);
    ctx.fillRect(ox, oy, TILE, TILE);
    ctx.fillStyle = col(shade(basis, 0.82));
    for (let ly = 5; ly < 32; ly += 8) ctx.fillRect(ox, oy + ly, TILE, 2);
    ctx.fillStyle = col(shade(basis, 1.12));
    ctx.fillRect(ox, oy, TILE, 2); // Firstkante oben
  }

  function wandTile(ctx, ox, oy) {
    const balken = "rgb(115,84,56)";
    ctx.fillStyle = "rgb(214,196,158)";
    ctx.fillRect(ox, oy, TILE, TILE);
    ctx.fillStyle = balken;
    ctx.fillRect(ox, oy, TILE, 3);
    ctx.fillRect(ox, oy + 29, TILE, 3);
    ctx.fillRect(ox, oy, 3, TILE);
    ctx.fillRect(ox + 29, oy, 3, TILE);
    ctx.fillRect(ox, oy + 15, TILE, 2);
  }

  function tuerTile(ctx, ox, oy) {
    wandTile(ctx, ox, oy);
    fillRRect(ctx, ox + 9.6, oy + 13, 12.8, 19, 5, "rgb(77,51,28)");   // Rahmen
    fillRRect(ctx, ox + 10.6, oy + 14.5, 10.8, 17.5, 4, "rgb(107,69,36)"); // Türblatt
    fillCirc(ctx, ox + 19.5, oy + 23, 1, "rgb(217,184,82)");           // Knauf
  }

  function waldTile(ctx, ox, oy, seed) {
    grasTile(ctx, ox, oy, seed, GRAS_WELT);
    fillRRect(ctx, ox + 14.4, oy + 23.5, 3.2, 5, 0.5, "rgb(97,66,38)");
    fillCirc(ctx, ox + 16, oy + 16, 11, "rgb(51,102,56)");
    fillCirc(ctx, ox + 10, oy + 12, 6, "rgb(61,117,64)");
    fillCirc(ctx, ox + 22, oy + 12, 6, "rgb(56,110,59)");
    fillCirc(ctx, ox + 16, oy + 10, 5, "rgb(66,125,69)");
  }

  function bergTile(ctx, ox, oy, seed) {
    grasTile(ctx, ox, oy, seed, GRAS_WELT);
    fillTri(ctx, ox + 2, oy + 29, ox + 30, oy + 29, ox + 16, oy + 2, "rgb(133,125,117)");
    fillTri(ctx, ox + 2, oy + 29, ox + 16, oy + 2, ox + 9, oy + 29, "rgb(112,105,99)");
    fillTri(ctx, ox + 12.5, oy + 12, ox + 19.5, oy + 12, ox + 16, oy + 2.5, "rgb(230,235,242)");
  }

  function stadtSymbolTile(ctx, ox, oy, seed) {
    grasTile(ctx, ox, oy, seed, GRAS_WELT);
    fillRRect(ctx, ox + 9, oy + 17.5, 14, 11, 1, "rgb(224,209,173)");        // Hauskörper
    fillTri(ctx, ox + 6, oy + 18.5, ox + 26, oy + 18.5, ox + 16, oy + 7, "rgb(166,71,56)"); // Dach
    fillRRect(ctx, ox + 14, oy + 23, 4, 6, 0.5, "rgb(102,69,38)");           // Tür
    fillRRect(ctx, ox + 9.5, oy + 21, 3, 3, 0.3, "rgb(89,140,191)");         // Fenster
    fillRRect(ctx, ox + 19.5, oy + 21, 3, 3, 0.3, "rgb(89,140,191)");        // Fenster
  }

  function dungeonSymbolTile(ctx, ox, oy, seed) {
    const fels = [115, 110, 105];
    ctx.fillStyle = col(fels);
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.20, col(shade(fels, 0.85)));
    fillCirc(ctx, ox + 16, oy + 20, 9.5, "rgb(82,77,74)");
    ctx.fillStyle = "rgb(82,77,74)";
    ctx.fillRect(ox + 6.5, oy + 21, 19, 11);
    fillCirc(ctx, ox + 16, oy + 21, 7.5, "rgb(13,13,18)");   // Höhlenmund
    ctx.fillStyle = "rgb(13,13,18)";
    ctx.fillRect(ox + 8.5, oy + 22, 15, 10);
  }

  function hoehlenWandTile(ctx, ox, oy, seed) {
    const basis = [38, 33, 33];
    ctx.fillStyle = col(basis);
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.22, "rgb(48,41,38)");
    for (let k = 0; k < 3; k++) {
      const rx = ox + 4 + hash01(k, 17, seed) * 24;
      const ry = oy + 4 + hash01(k, 23, seed) * 24;
      fillCirc(ctx, rx, ry, 3.2 + hash01(k, 29, seed) * 1.5, "rgb(54,46,43)");
    }
  }

  function hoehlenBodenTile(ctx, ox, oy, seed) {
    ctx.fillStyle = "rgb(84,74,69)";
    ctx.fillRect(ox, oy, TILE, TILE);
    noise(ctx, ox, oy, TILE, TILE, seed, 0.22, "rgb(71,61,59)");
    noise(ctx, ox, oy, TILE, TILE, seed + 5, 0.10, "rgb(97,87,79)");
  }

  function felsbrockenTile(ctx, ox, oy, seed) {
    hoehlenBodenTile(ctx, ox, oy, seed);
    fillEll(ctx, ox + 16, oy + 23, 9.5, 3, "rgba(0,0,0,0.35)");
    fillCirc(ctx, ox + 16, oy + 16, 8.8, "rgb(122,117,112)");
    fillCirc(ctx, ox + 13, oy + 13, 3.2, "rgb(148,143,135)");
    fillSeg(ctx, ox + 14, oy + 21, ox + 19.5, oy + 15.5, 1, "rgb(92,87,82)");
  }

  function paintTile(ctx, zeichen, ox, oy, seed) {
    switch (zeichen) {
      case "G": grasTile(ctx, ox, oy, seed, GRAS_STADT); break;
      case "F": blumenTile(ctx, ox, oy, seed); break;
      case "P": wegTile(ctx, ox, oy, seed); break;
      case "W": wasserTile(ctx, ox, oy, seed, [64, 115, 179]); break;
      case "T": baumTile(ctx, ox, oy, seed); break;
      case "r": dachTile(ctx, ox, oy); break;
      case "w": wandTile(ctx, ox, oy); break;
      case "d": tuerTile(ctx, ox, oy); break;
      case "g": grasTile(ctx, ox, oy, seed, GRAS_WELT); break;
      case "f": waldTile(ctx, ox, oy, seed); break;
      case "M": bergTile(ctx, ox, oy, seed); break;
      case "V": wasserTile(ctx, ox, oy, seed, [46, 92, 158]); break;
      case "C": stadtSymbolTile(ctx, ox, oy, seed); break;
      case "D": dungeonSymbolTile(ctx, ox, oy, seed); break;
      case "#": hoehlenWandTile(ctx, ox, oy, seed); break;
      case ".": hoehlenBodenTile(ctx, ox, oy, seed); break;
      case "o": felsbrockenTile(ctx, ox, oy, seed); break;
      default: grasTile(ctx, ox, oy, seed, GRAS_STADT); break;
    }
  }

  function composeMap(map) {
    const rows = map.length, cols = map[0].length;
    const canvas = makeCanvas(cols * TILE, rows * TILE);
    const ctx = canvas.getContext("2d");
    for (let row = 0; row < rows; row++) {
      for (let col2 = 0; col2 < cols; col2++) {
        const seed = (col2 * 73856093) ^ (row * 19349663);
        paintTile(ctx, map[row][col2], col2 * TILE, row * TILE, seed);
      }
    }
    return canvas;
  }

  // ------------------------------------------------------------------
  // Figuren (32×32): Schatten, Beine, Körper, Kopf plus Stil-Details
  // ------------------------------------------------------------------

  function makeCharacter(haar, kleidung, akzent, stil) {
    const canvas = makeCanvas(32, 32);
    const ctx = canvas.getContext("2d");
    const haut = [245, 204, 168];
    const dunkel = "rgb(38,31,31)";

    fillEll(ctx, 16, 28.5, 9, 2.6, "rgba(0,0,0,0.28)");                 // Bodenschatten

    const beine = col(shade(kleidung, 0.55));
    fillRRect(ctx, 10.9, 22.8, 4.2, 6.4, 1, beine);                     // Beine
    fillRRect(ctx, 16.9, 22.8, 4.2, 6.4, 1, beine);

    fillRRect(ctx, 10, 14.2, 12, 10.6, 2.5, col(kleidung));             // Körper
    fillRRect(ctx, 10.4, 21.1, 11.2, 2.2, 0.5, col(shade(kleidung, 0.5))); // Gürtel
    fillRRect(ctx, 7.2, 15.7, 3.6, 7.6, 1.2, col(shade(kleidung, 0.8))); // Arme
    fillRRect(ctx, 21.2, 15.7, 3.6, 7.6, 1.2, col(shade(kleidung, 0.8)));

    fillCirc(ctx, 16, 9.5, 7.2, col(haar));                             // Haar
    fillCirc(ctx, 16, 11, 5.6, col(haut));                              // Gesicht
    fillRRect(ctx, 10.4, 4.5, 11.2, 4.2, 1.5, col(haar));               // Pony
    ctx.fillStyle = dunkel;                                             // Augen
    ctx.fillRect(12.9, 10.7, 1.6, 2.2);
    ctx.fillRect(17.5, 10.7, 1.6, 2.2);

    switch (stil) {
      case "schwertkaempferin":
        fillCirc(ctx, 22.5, 5.5, 2.6, col(haar));                       // Zopf
        fillEll(ctx, 23.5, 10, 1.6, 3.4, col(haar));
        fillSeg(ctx, 27, 26, 27, 17, 2.2, "rgb(199,204,217)");          // Klinge
        fillRRect(ctx, 24.6, 15.7, 4.8, 1.4, 0.3, "rgb(115,89,51)");    // Parierstange
        fillSeg(ctx, 27, 16, 27, 13.5, 1.8, "rgb(89,64,38)");           // Griff
        fillRRect(ctx, 11.4, 14.4, 9.2, 2.4, 0.6, col(akzent));         // Schärpe
        break;

      case "zauberer":
        fillEll(ctx, 16, 7.5, 9.5, 2.4, col(shade(haar, 0.9)));         // Hutkrempe
        fillTri(ctx, 9.5, 7.5, 22.5, 7.5, 17.5, 0, col(haar));          // Spitzhut
        fillSeg(ctx, 6.5, 28, 6.5, 15, 2, "rgb(115,79,46)");            // Stab
        fillCirc(ctx, 6.5, 13, 2.2, "rgb(115,217,242)");                // Kugel
        fillCirc(ctx, 5.8, 12.3, 0.8, "rgb(217,250,255)");
        fillRRect(ctx, 10, 23.2, 12, 2.4, 0.5, col(akzent));            // Robensaum
        break;

      case "aeltester":
        fillEll(ctx, 16, 14.4, 3.4, 2.4, "rgb(224,224,224)");           // Bart
        fillSeg(ctx, 25, 28, 25, 16, 1.8, "rgb(128,97,56)");            // Gehstock
        break;

      case "priesterin":
        fillRRect(ctx, 10.8, 4.4, 10.4, 1.6, 0.4, col(akzent));         // Stirnband
        fillRRect(ctx, 11.8, 14.6, 8.4, 2, 0.5, "rgb(242,242,250)");    // Kragen
        break;

      case "haendlerin":
        fillRRect(ctx, 12.2, 16.9, 7.6, 7.2, 1.2, col(akzent));         // Schürze
        fillRRect(ctx, 13.4, 16, 5.2, 1.6, 0.4, col(shade(akzent, 0.8)));
        break;
    }
    return canvas;
  }

  // ------------------------------------------------------------------
  // Gegner (48×48)
  // ------------------------------------------------------------------

  function makeSchleim() {
    const canvas = makeCanvas(48, 48);
    const ctx = canvas.getContext("2d");
    const koerper = [77, 168, 82];

    fillEll(ctx, 24, 42, 15, 3.4, "rgba(0,0,0,0.30)");
    fillEll(ctx, 24, 34, 17, 8, col(shade(koerper, 0.88)));             // Sockel
    fillEll(ctx, 24, 28, 14.5, 12.5, col(koerper));                     // Körper
    fillEll(ctx, 17.5, 22, 4.6, 3.2, "rgba(158,230,140,0.9)");          // Glanzlicht
    fillCirc(ctx, 19, 29, 2.1, "rgb(26,56,26)");                        // Augen
    fillCirc(ctx, 29, 29, 2.1, "rgb(26,56,26)");
    fillCirc(ctx, 19.7, 28.3, 0.7, "#fff");
    fillCirc(ctx, 29.7, 28.3, 0.7, "#fff");
    fillSeg(ctx, 21.5, 34.5, 26.5, 34.5, 1.8, col(shade(koerper, 0.45))); // Mund
    return canvas;
  }

  function makeFledermaus() {
    const canvas = makeCanvas(48, 48);
    const ctx = canvas.getContext("2d");
    const koerper = [92, 66, 122];
    const fluegel = col(shade(koerper, 0.72));

    fillTri(ctx, 2, 18, 17, 21, 13, 34, fluegel);                       // Flügel
    fillTri(ctx, 46, 18, 31, 21, 35, 34, fluegel);
    fillTri(ctx, 18, 20, 22, 19, 18.5, 13, col(koerper));               // Beinchen
    fillTri(ctx, 26, 19, 30, 20, 29.5, 13, col(koerper));
    fillCirc(ctx, 24, 25, 8.5, col(koerper));                           // Körper
    fillCirc(ctx, 20.8, 24, 1.7, "rgb(242,64,64)");                     // Augen
    fillCirc(ctx, 27.2, 24, 1.7, "rgb(242,64,64)");
    fillTri(ctx, 21, 31, 23, 31, 22, 34, "#fff");                       // Zähne
    fillTri(ctx, 25, 31, 27, 31, 26, 34, "#fff");
    return canvas;
  }

  function makeGolem() {
    const canvas = makeCanvas(48, 48);
    const ctx = canvas.getContext("2d");
    const stein = [128, 122, 115];

    fillEll(ctx, 24, 43, 16, 3.2, "rgba(0,0,0,0.30)");
    fillRRect(ctx, 14.6, 37.6, 6.8, 6.8, 1, col(shade(stein, 0.7)));    // Füße
    fillRRect(ctx, 26.6, 37.6, 6.8, 6.8, 1, col(shade(stein, 0.7)));
    fillRRect(ctx, 4.9, 22, 7.2, 16, 2, col(shade(stein, 0.8)));        // Arme
    fillRRect(ctx, 35.9, 22, 7.2, 16, 2, col(shade(stein, 0.8)));
    fillRRect(ctx, 12.5, 20, 23, 20, 3, col(stein));                    // Rumpf
    fillRRect(ctx, 17, 10.5, 14, 10, 2, col(shade(stein, 1.08)));       // Kopf
    fillRRect(ctx, 19.4, 14.4, 3.2, 2.2, 0.4, "rgb(255,158,38)");       // Glutaugen
    fillRRect(ctx, 25.4, 14.4, 3.2, 2.2, 0.4, "rgb(255,158,38)");
    fillSeg(ctx, 18, 34, 22, 30, 1, col(shade(stein, 0.5)));            // Risse
    fillSeg(ctx, 28, 26, 31, 30, 1, col(shade(stein, 0.5)));
    fillCirc(ctx, 31, 36, 3, "rgba(77,128,71,0.75)");                   // Moos
    return canvas;
  }

  // ------------------------------------------------------------------
  // Kampfhintergrund (640×360): Höhle mit Kristall
  // ------------------------------------------------------------------

  function makeKampfHintergrund() {
    const w = 640, h = 360;
    const canvas = makeCanvas(w, h);
    const ctx = canvas.getContext("2d");

    const verlauf = ctx.createLinearGradient(0, 0, 0, h);
    verlauf.addColorStop(0, "rgb(13,15,28)");
    verlauf.addColorStop(1, "rgb(38,28,48)");
    ctx.fillStyle = verlauf;
    ctx.fillRect(0, 0, w, h);

    for (let k = 0; k < 6; k++) {                                       // Stalaktiten
      const x = 45 + k * 105 + (hash01(k, 3, 99) - 0.5) * 40;
      const laenge = 45 + hash01(k, 5, 99) * 40;
      fillTri(ctx, x - 20, 0, x + 20, 0, x, laenge, "rgb(23,20,33)");
    }

    for (let k = 0; k < 7; k++) {                                       // Ferne Felsen
      const x = 25 + k * 92 + hash01(k, 7, 42) * 50;
      const r = 24 + hash01(k, 11, 42) * 20;
      fillCirc(ctx, x, 225, r, "rgb(33,28,41)");
    }

    fillCirc(ctx, 120, 205, 34, "rgba(115,191,242,0.12)");              // Kristallschein
    fillTri(ctx, 107, 220, 133, 220, 120, 168, "rgba(140,217,250,0.85)");
    fillTri(ctx, 112, 220, 128, 220, 120, 246, "rgba(115,184,230,0.85)");

    fillRRect(ctx, -15, 255, w + 30, 120, 10, "rgb(71,59,54)");         // Boden
    const bodenCtx = ctx;
    bodenCtx.save();
    bodenCtx.beginPath();
    bodenCtx.rect(0, 258, w, h - 258);
    bodenCtx.clip();
    noise(bodenCtx, 0, 258, w, h - 258, 31, 0.10, "rgb(61,48,46)");
    noise(bodenCtx, 0, 258, w, h - 258, 37, 0.05, "rgb(84,69,64)");
    bodenCtx.restore();

    return canvas;
  }

  /* Rot eingefärbte Kopie eines Sprites (Treffer-Aufblitzen im Kampf). */
  function makeTinted(quelle) {
    const canvas = makeCanvas(quelle.width, quelle.height);
    const ctx = canvas.getContext("2d");
    ctx.drawImage(quelle, 0, 0);
    ctx.globalCompositeOperation = "source-atop";
    ctx.fillStyle = "rgba(255,80,80,0.85)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    return canvas;
  }

  // ------------------------------------------------------------------
  // Öffentliche Schnittstelle
  // ------------------------------------------------------------------

  const api = { TILE, maps: {}, chars: {}, enemies: {}, tinted: {}, kampfHintergrund: null };

  api.init = function () {
    api.maps.stadt = composeMap(Maps.stadt);
    api.maps.weltkarte = composeMap(Maps.weltkarte);
    api.maps.dungeon = composeMap(Maps.dungeon);

    api.chars.aria = makeCharacter([140, 64, 36], [66, 97, 158], [204, 64, 56], "schwertkaempferin");
    api.chars.milo = makeCharacter([97, 61, 140], [82, 56, 122], [217, 179, 77], "zauberer");
    api.chars.aeltester = makeCharacter([217, 217, 217], [115, 92, 66], [153, 128, 89], "aeltester");
    api.chars.priesterin = makeCharacter([230, 204, 115], [235, 235, 242], [140, 179, 230], "priesterin");
    api.chars.haendlerin = makeCharacter([89, 56, 31], [128, 82, 77], [217, 191, 102], "haendlerin");

    api.enemies.schleim = makeSchleim();
    api.enemies.fledermaus = makeFledermaus();
    api.enemies.golem = makeGolem();

    api.kampfHintergrund = makeKampfHintergrund();

    for (const key of Object.keys(api.chars)) api.tinted[key] = makeTinted(api.chars[key]);
    for (const key of Object.keys(api.enemies)) api.tinted[key] = makeTinted(api.enemies[key]);
  };

  return api;
})();
