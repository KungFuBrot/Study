"use strict";

/*
 * Visuelle Effekte: Partikel, schwebende Schadenszahlen, Bildschirmwackeln,
 * Aufblitzen und Szenenübergänge (Blenden). Wird in jedem Frame aus der
 * Hauptschleife aktualisiert und über dem jeweiligen Modus gezeichnet.
 */
const Fx = {
  partikel: [],
  zahlen: [],
  shakeStaerke: 0,
  shakeZeit: 0,
  blitzAlpha: 0,
  blitzFarbe: "#fff",
  ueberblendung: null, // { t, raus, rein, mitteAufgerufen, callback }

  /* Während einer Überblendung ist die Feldsteuerung eingefroren. */
  get blockiert() { return this.ueberblendung !== null; },

  update(dt) {
    for (let i = this.partikel.length - 1; i >= 0; i--) {
      const p = this.partikel[i];
      p.leben -= dt;
      if (p.leben <= 0) { this.partikel.splice(i, 1); continue; }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.grav * dt;
    }

    for (let i = this.zahlen.length - 1; i >= 0; i--) {
      const z = this.zahlen[i];
      z.leben -= dt;
      if (z.leben <= 0) { this.zahlen.splice(i, 1); continue; }
      z.y -= 38 * dt;
    }

    if (this.shakeZeit > 0) this.shakeZeit -= dt;
    if (this.blitzAlpha > 0) this.blitzAlpha = Math.max(0, this.blitzAlpha - dt * 3);

    const u = this.ueberblendung;
    if (u) {
      u.t += dt;
      if (u.t >= u.raus && !u.mitteAufgerufen) {
        u.mitteAufgerufen = true;
        u.callback();
      }
      if (u.t >= u.raus + u.rein) this.ueberblendung = null;
    }
  },

  /* Verschiebung durch Bildschirmwackeln (im Kampf auf die Welt anwenden). */
  offset() {
    if (this.shakeZeit <= 0) return [0, 0];
    const s = this.shakeStaerke * Math.min(1, this.shakeZeit * 4);
    return [(Math.random() * 2 - 1) * s, (Math.random() * 2 - 1) * s];
  },

  // ------------------------------------------------------------------
  // Auslöser
  // ------------------------------------------------------------------

  schuetteln(staerke, dauer) {
    this.shakeStaerke = Math.max(this.shakeStaerke, staerke);
    this.shakeZeit = Math.max(this.shakeZeit, dauer);
    if (this.shakeZeit <= 0) this.shakeStaerke = staerke;
  },

  blitz(farbe, alpha) {
    this.blitzFarbe = farbe;
    this.blitzAlpha = Math.max(this.blitzAlpha, alpha);
  },

  zahl(x, y, text, farbe) {
    this.zahlen.push({ x, y, text, farbe, leben: 0.85, maxLeben: 0.85 });
  },

  funken(x, y, anzahl, farben, tempo, grav, groesse, dauer) {
    for (let i = 0; i < anzahl; i++) {
      const winkel = Math.random() * Math.PI * 2;
      const v = tempo * (0.35 + Math.random() * 0.65);
      this.partikel.push({
        x, y,
        vx: Math.cos(winkel) * v,
        vy: Math.sin(winkel) * v,
        grav: grav,
        leben: dauer * (0.6 + Math.random() * 0.4),
        maxLeben: dauer,
        farbe: farben[Math.floor(Math.random() * farben.length)],
        groesse: groesse * (0.6 + Math.random() * 0.6),
        art: "punkt",
      });
    }
  },

  /* Heller Hieb: kurze, schnelle Striche quer über das Ziel. */
  schnitt(x, y) {
    for (let i = 0; i < 3; i++) {
      this.partikel.push({
        x: x - 34 + i * 6, y: y - 30 + i * 12,
        vx: 620, vy: 480,
        grav: 0, leben: 0.13, maxLeben: 0.13,
        farbe: i === 1 ? "rgb(255,255,255)" : "rgb(190,220,255)",
        groesse: 2.5, art: "strich",
      });
    }
    this.funken(x, y, 8, ["rgb(255,255,255)", "rgb(255,230,140)"], 160, 300, 2.2, 0.35);
  },

  feuer(x, y) {
    this.funken(x, y, 22, ["rgb(255,120,30)", "rgb(255,190,60)", "rgb(255,240,160)", "rgb(200,60,20)"],
      170, -120, 3.2, 0.55);
    this.blitz("rgb(255,150,50)", 0.35);
  },

  heilung(x, y) {
    for (let i = 0; i < 12; i++) {
      this.partikel.push({
        x: x - 28 + Math.random() * 56, y: y + 20 - Math.random() * 20,
        vx: (Math.random() - 0.5) * 20, vy: -55 - Math.random() * 45,
        grav: 0, leben: 0.7 + Math.random() * 0.3, maxLeben: 1,
        farbe: Math.random() < 0.5 ? "rgb(120,255,150)" : "rgb(220,255,230)",
        groesse: 2.6, art: "stern",
      });
    }
  },

  /* Auflösungswölkchen, wenn ein Gegner besiegt wird. */
  aufloesen(x, y) {
    this.funken(x, y, 18, ["rgb(180,150,255)", "rgb(120,90,200)", "rgb(240,240,255)"],
      110, -60, 3.0, 0.7);
  },

  // ------------------------------------------------------------------
  // Überblendungen
  // ------------------------------------------------------------------

  /* Weiche Schwarzblende für Kartenwechsel; callback in der Mitte. */
  blende(callback) {
    if (this.ueberblendung) return;
    this.ueberblendung = { t: 0, raus: 0.25, rein: 0.3, mitteAufgerufen: false, callback };
  },

  /* Dramatischere Blende für den Kampfbeginn (mit Aufblitzen). */
  kampfBlende(callback) {
    if (this.ueberblendung) return;
    this.blitz("rgb(255,255,255)", 0.8);
    this.ueberblendung = { t: 0, raus: 0.5, rein: 0.35, mitteAufgerufen: false, callback };
  },

  // ------------------------------------------------------------------
  // Zeichnen
  // ------------------------------------------------------------------

  /* Partikel und Schadenszahlen (innerhalb der gewackelten Weltebene). */
  drawWelt(ctx) {
    for (const p of this.partikel) {
      const a = Math.max(0, p.leben / p.maxLeben);
      ctx.globalAlpha = a;
      ctx.fillStyle = p.farbe;
      if (p.art === "strich") {
        ctx.strokeStyle = p.farbe;
        ctx.lineWidth = p.groesse;
        ctx.beginPath();
        ctx.moveTo(p.x - p.vx * 0.045, p.y - p.vy * 0.045);
        ctx.lineTo(p.x, p.y);
        ctx.stroke();
      } else if (p.art === "stern") {
        ctx.fillRect(p.x - p.groesse, p.y - 0.8, p.groesse * 2, 1.6);
        ctx.fillRect(p.x - 0.8, p.y - p.groesse, 1.6, p.groesse * 2);
      } else {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.groesse * (0.5 + 0.5 * a), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;

    for (const z of this.zahlen) {
      const a = Math.min(1, z.leben / z.maxLeben * 2);
      ctx.globalAlpha = a;
      ctx.font = 'bold 17px "Courier New", monospace';
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.lineWidth = 3;
      ctx.strokeStyle = "rgba(0,0,0,0.85)";
      ctx.strokeText(z.text, z.x, z.y);
      ctx.fillStyle = z.farbe;
      ctx.fillText(z.text, z.x, z.y);
    }
    ctx.globalAlpha = 1;
  },

  /* Aufblitzen und Blenden — als Letztes über allem zeichnen. */
  drawUeber(ctx) {
    if (this.blitzAlpha > 0) {
      ctx.globalAlpha = this.blitzAlpha;
      ctx.fillStyle = this.blitzFarbe;
      ctx.fillRect(0, 0, 640, 360);
      ctx.globalAlpha = 1;
    }

    const u = this.ueberblendung;
    if (u) {
      const alpha = u.t < u.raus ? u.t / u.raus : Math.max(0, 1 - (u.t - u.raus) / u.rein);
      ctx.globalAlpha = alpha;
      ctx.fillStyle = "#000";
      ctx.fillRect(0, 0, 640, 360);
      ctx.globalAlpha = 1;
    }
  },
};
