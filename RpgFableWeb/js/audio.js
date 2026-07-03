"use strict";

/*
 * Musik und Soundeffekte, komplett prozedural über die Web-Audio-API —
 * es werden keine Audiodateien benötigt.
 *
 * Browser erlauben Ton erst nach einer Nutzereingabe, deshalb wird der
 * AudioContext beim ersten Tastendruck entsperrt (Sound.entsperren).
 * Bis dahin wird sich nur gemerkt, welche Musik laufen soll.
 */
const Sound = {
  ctx: null,
  master: null,
  musikGain: null,
  sfxGain: null,
  stumm: false,
  gewuenschteMusik: null,
  aktuelleMusik: null,
  _timer: null,
  _pos: 0,
  _naechsteZeit: 0,
  _rauschPuffer: null,

  entsperren() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();

      this.master = this.ctx.createGain();
      this.master.gain.value = this.stumm ? 0 : 0.6;
      this.master.connect(this.ctx.destination);

      this.musikGain = this.ctx.createGain();
      this.musikGain.gain.value = 0.5;
      this.musikGain.connect(this.master);

      this.sfxGain = this.ctx.createGain();
      this.sfxGain.gain.value = 0.55;
      this.sfxGain.connect(this.master);
    }
    if (this.ctx.state === "suspended") this.ctx.resume();
    if (this.gewuenschteMusik && this.gewuenschteMusik !== this.aktuelleMusik) {
      this.spieleMusik(this.gewuenschteMusik);
    }
  },

  toggleStumm() {
    this.stumm = !this.stumm;
    if (this.master) this.master.gain.value = this.stumm ? 0 : 0.6;
  },

  // ------------------------------------------------------------------
  // Musik: kleiner Sequenzer, plant Noten mit Vorlauf ein
  // ------------------------------------------------------------------

  spieleMusik(name) {
    this.gewuenschteMusik = name;
    if (!this.ctx || name === this.aktuelleMusik) return;
    this.stoppeMusik();

    const lied = Lieder[name];
    if (!lied) return;
    this.aktuelleMusik = name;
    this._pos = 0;
    this._naechsteZeit = this.ctx.currentTime + 0.06;
    this._timer = setInterval(() => this._plane(lied), 40);
  },

  stoppeMusik() {
    if (this._timer) { clearInterval(this._timer); this._timer = null; }
    this.aktuelleMusik = null;
  },

  _plane(lied) {
    const sechzehntel = 60 / lied.bpm / 4;
    while (this._naechsteZeit < this.ctx.currentTime + 0.18) {
      for (const spur of lied.spuren) {
        for (const n of spur.noten) {
          if (n[0] !== this._pos) continue;
          if (spur.typ === "schlagzeug") this._schlag(n[1], this._naechsteZeit);
          else this._note(this._naechsteZeit, midiFreq(n[1]), n[2] * sechzehntel * 0.92, spur.typ, spur.vol);
        }
      }
      this._pos++;
      if (this._pos >= lied.laenge) {
        if (lied.einmalig) {
          const timer = this._timer;
          this._timer = null;
          clearInterval(timer);
          this.aktuelleMusik = null;
          return;
        }
        this._pos = 0;
      }
      this._naechsteZeit += sechzehntel;
    }
  },

  _note(zeit, freq, dauer, typ, vol) {
    const osc = this.ctx.createOscillator();
    osc.type = typ;
    osc.frequency.value = freq;
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0, zeit);
    g.gain.linearRampToValueAtTime(vol, zeit + 0.012);
    g.gain.setValueAtTime(vol, Math.max(zeit + 0.012, zeit + dauer - 0.05));
    g.gain.linearRampToValueAtTime(0.0001, zeit + dauer);
    osc.connect(g); g.connect(this.musikGain);
    osc.start(zeit);
    osc.stop(zeit + dauer + 0.03);
  },

  _schlag(art, zeit) {
    if (art === "kick") {
      const osc = this.ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.setValueAtTime(150, zeit);
      osc.frequency.exponentialRampToValueAtTime(45, zeit + 0.09);
      const g = this.ctx.createGain();
      g.gain.setValueAtTime(0.5, zeit);
      g.gain.exponentialRampToValueAtTime(0.001, zeit + 0.11);
      osc.connect(g); g.connect(this.musikGain);
      osc.start(zeit); osc.stop(zeit + 0.12);
    } else { // "hat"
      this._rauschen(zeit, 0.03, "highpass", 6000, 6000, 0.08, this.musikGain);
    }
  },

  // ------------------------------------------------------------------
  // Klangbausteine für Effekte
  // ------------------------------------------------------------------

  _blip(zeit, f1, f2, dauer, typ, vol) {
    const osc = this.ctx.createOscillator();
    osc.type = typ;
    osc.frequency.setValueAtTime(f1, zeit);
    if (f2 !== f1) osc.frequency.exponentialRampToValueAtTime(Math.max(1, f2), zeit + dauer);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(vol, zeit);
    g.gain.exponentialRampToValueAtTime(0.001, zeit + dauer);
    osc.connect(g); g.connect(this.sfxGain);
    osc.start(zeit); osc.stop(zeit + dauer + 0.02);
  },

  _rauschen(zeit, dauer, filterTyp, f1, f2, vol, ziel) {
    if (!this._rauschPuffer) {
      const laenge = this.ctx.sampleRate * 0.5;
      this._rauschPuffer = this.ctx.createBuffer(1, laenge, this.ctx.sampleRate);
      const daten = this._rauschPuffer.getChannelData(0);
      for (let i = 0; i < laenge; i++) daten[i] = Math.random() * 2 - 1;
    }
    const quelle = this.ctx.createBufferSource();
    quelle.buffer = this._rauschPuffer;
    quelle.loop = true;
    const filter = this.ctx.createBiquadFilter();
    filter.type = filterTyp;
    filter.frequency.setValueAtTime(f1, zeit);
    if (f2 !== f1) filter.frequency.exponentialRampToValueAtTime(Math.max(1, f2), zeit + dauer);
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(vol, zeit);
    g.gain.exponentialRampToValueAtTime(0.001, zeit + dauer);
    quelle.connect(filter); filter.connect(g); g.connect(ziel || this.sfxGain);
    quelle.start(zeit); quelle.stop(zeit + dauer + 0.02);
  },

  /* Spielt einen benannten Soundeffekt ab. */
  sfx(name) {
    if (!this.ctx || this.stumm) return;
    const t = this.ctx.currentTime;
    switch (name) {
      case "menu":       this._blip(t, 880, 880, 0.04, "square", 0.10); break;
      case "bestaetigen": this._blip(t, 660, 660, 0.05, "square", 0.10);
                          this._blip(t + 0.06, 990, 990, 0.07, "square", 0.10); break;
      case "abbrechen":  this._blip(t, 440, 220, 0.10, "square", 0.10); break;
      case "dialog":     this._blip(t, 750, 750, 0.03, "square", 0.08); break;
      case "kaufen":     this._blip(t, 1319, 1319, 0.05, "sine", 0.22);
                          this._blip(t + 0.07, 1760, 1760, 0.12, "sine", 0.22); break;
      case "schwert":    this._rauschen(t, 0.12, "bandpass", 3500, 700, 0.30);
                          this._blip(t, 1200, 300, 0.08, "sawtooth", 0.08); break;
      case "treffer":    this._rauschen(t, 0.10, "lowpass", 900, 300, 0.35);
                          this._blip(t, 200, 80, 0.10, "sine", 0.30); break;
      case "magie":      this._blip(t, 300, 1400, 0.25, "sine", 0.18);
                          this._blip(t + 0.10, 1568, 2093, 0.15, "triangle", 0.12); break;
      case "feuer":      this._rauschen(t, 0.35, "lowpass", 900, 150, 0.40);
                          this._blip(t, 120, 55, 0.30, "sine", 0.30); break;
      case "heilung":    this._blip(t, 784, 784, 0.10, "sine", 0.18);
                          this._blip(t + 0.08, 988, 988, 0.10, "sine", 0.18);
                          this._blip(t + 0.16, 1319, 1319, 0.22, "sine", 0.18); break;
      case "item":       this._blip(t, 523, 784, 0.10, "triangle", 0.20); break;
      case "besiegt":    this._blip(t, 400, 55, 0.30, "square", 0.12);
                          this._rauschen(t + 0.05, 0.25, "lowpass", 600, 100, 0.20); break;
      case "flucht":     this._blip(t, 300, 900, 0.18, "square", 0.10); break;
      case "beben":      this._rauschen(t, 0.55, "lowpass", 200, 60, 0.50);
                          this._blip(t, 70, 40, 0.5, "sine", 0.30); break;
      case "begegnung":  this._blip(t, 220, 880, 0.16, "square", 0.12);
                          this._blip(t + 0.16, 220, 880, 0.16, "square", 0.12); break;
    }
  },
};

function midiFreq(m) { return 440 * Math.pow(2, (m - 69) / 12); }

/*
 * Die Lieder: Positionen in Sechzehnteln, Tonhöhen als MIDI-Nummern.
 * Noten: [position, midi, dauerInSechzehnteln]
 */
const Lieder = (() => {
  // Dungeon-Arpeggio programmatisch erzeugen (Am, F, G, E über je 8 Sechzehntel)
  const arp = [];
  const akkorde = [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]];
  for (let a = 0; a < 4; a++) {
    const [tief, mitte, hoch] = akkorde[a];
    const muster = [tief, mitte, hoch, mitte, tief, mitte, hoch, mitte];
    for (let i = 0; i < 8; i++) arp.push([a * 8 + i, muster[i], 1]);
  }

  // Kampf-Bass (treibende Achtel: A, A, F, G) und Schlagzeug
  const kampfBass = [];
  for (let i = 0; i < 16; i++) {
    const ton = i < 8 ? 45 : (i < 12 ? 41 : 43);
    kampfBass.push([i * 2, ton, 1]);
  }
  const schlagzeug = [];
  for (let i = 0; i < 32; i += 4) schlagzeug.push([i, "kick"]);
  for (let i = 2; i < 32; i += 4) schlagzeug.push([i, "hat"]);

  return {
    stadt: {
      bpm: 92, laenge: 32,
      spuren: [
        { typ: "triangle", vol: 0.50, noten: [[0, 48, 7], [8, 43, 7], [16, 45, 7], [24, 41, 7]] },
        { typ: "sine", vol: 0.22, noten: [[0, 60, 8], [8, 59, 8], [16, 60, 8], [24, 57, 8]] },
        { typ: "square", vol: 0.11, noten: [
          [0, 64, 2], [2, 67, 2], [4, 72, 3], [8, 71, 2], [10, 67, 2], [12, 64, 3],
          [16, 69, 2], [18, 72, 2], [20, 76, 3], [24, 74, 2], [26, 71, 2], [28, 67, 3],
        ] },
      ],
    },
    weltkarte: {
      bpm: 112, laenge: 32,
      spuren: [
        { typ: "triangle", vol: 0.50, noten: [[0, 43, 7], [8, 50, 7], [16, 40, 7], [24, 48, 7]] },
        { typ: "square", vol: 0.11, noten: [
          [0, 67, 3], [4, 71, 1], [5, 72, 1], [6, 74, 2], [8, 74, 3], [12, 78, 2], [14, 74, 2],
          [16, 76, 3], [20, 71, 2], [22, 67, 2], [24, 72, 4], [28, 74, 2], [30, 67, 2],
        ] },
      ],
    },
    dungeon: {
      bpm: 100, laenge: 32,
      spuren: [
        { typ: "triangle", vol: 0.55, noten: [[0, 45, 7], [8, 41, 7], [16, 43, 7], [24, 40, 7]] },
        { typ: "square", vol: 0.055, noten: arp },
        { typ: "sine", vol: 0.20, noten: [[0, 69, 4], [6, 72, 2], [8, 71, 6], [16, 69, 4], [22, 68, 2], [24, 64, 6]] },
      ],
    },
    kampf: {
      bpm: 144, laenge: 32,
      spuren: [
        { typ: "triangle", vol: 0.55, noten: kampfBass },
        { typ: "schlagzeug", noten: schlagzeug },
        { typ: "square", vol: 0.11, noten: [
          [0, 69, 2], [2, 72, 1], [3, 74, 1], [4, 76, 2], [6, 74, 1], [7, 72, 1],
          [8, 69, 2], [10, 72, 2], [12, 74, 4], [16, 77, 2], [18, 76, 2], [20, 74, 2],
          [22, 72, 2], [24, 71, 2], [26, 74, 2], [28, 76, 4],
        ] },
      ],
    },
    sieg: {
      bpm: 132, laenge: 26, einmalig: true,
      spuren: [
        { typ: "triangle", vol: 0.50, noten: [[0, 48, 2], [4, 48, 2], [6, 52, 4], [12, 50, 4], [16, 55, 8]] },
        { typ: "square", vol: 0.13, noten: [
          [0, 72, 1], [2, 72, 1], [4, 72, 1], [6, 76, 5], [12, 74, 1], [14, 76, 1], [16, 79, 8],
        ] },
      ],
    },
    niederlage: {
      bpm: 80, laenge: 22, einmalig: true,
      spuren: [
        { typ: "triangle", vol: 0.45, noten: [[0, 45, 4], [4, 44, 4], [8, 43, 4], [12, 38, 8]] },
        { typ: "sine", vol: 0.22, noten: [[0, 64, 4], [4, 62, 4], [8, 60, 4], [12, 57, 8]] },
      ],
    },
  };
})();
