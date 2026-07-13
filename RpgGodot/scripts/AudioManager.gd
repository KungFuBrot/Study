extends Node
## Prozeduraler Chiptune-Synth: Musik und SFX werden beim ersten Abruf als
## PCM gerendert (AudioStreamWAV) und gecacht — keine Audiodateien nötig.
## Jeder Song hat bis zu 4 Spuren: Lead (Chorus-Square), Harmonie-Pad (Dreieck),
## Bass (Dreieck) und Schlagzeug (Kick/Snare/HiHat), dazu ein leichtes Echo.

const RATE := 22050

var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx_next := 0
var _music_cache := {}
var _sfx_cache := {}
var current_music := ""

# Noten als [MIDI, Schläge], -1 = Pause. "drums": 1 Zeichen pro halbem Schlag
# (k = Kick, s = Snare, h = HiHat, . = Pause); das Pattern loopt.
const SONGS := {
	# „Am Lagerfeuer" — C-Dur, ruhig-heroisch (I-V-vi-IV), fürs Titelbild.
	"title": {"bpm": 90, "loop": true,
		"mel": [[67, 1], [72, 1], [74, 0.5], [76, 0.5], [74, 1],
			[71, 1], [72, 0.5], [74, 0.5], [72, 1], [67, 1],
			[69, 1], [72, 1], [76, 1], [77, 1],
			[76, 2], [74, 1], [72, 1],
			[76, 1], [79, 1], [77, 0.5], [76, 0.5], [74, 1],
			[74, 1], [71, 0.5], [72, 0.5], [74, 1], [67, 1],
			[69, 1], [72, 1], [74, 0.5], [72, 0.5], [69, 1],
			[72, 2], [74, 1], [71, 1]],
		"harm": [[64, 4], [62, 4], [60, 4], [57, 4],
			[64, 4], [62, 4], [57, 4], [53, 2], [55, 2]],
		"bass": [[36, 2], [43, 2], [31, 2], [38, 2], [33, 2], [40, 2], [29, 2], [36, 2],
			[36, 2], [43, 2], [31, 2], [38, 2], [33, 2], [40, 2], [29, 2], [31, 2]],
		"drums": "k...h.s."},
	# „Marktplatz am Morgen" — F-Dur, freundlich schunkelnd (I-vi-IV-V).
	"town": {"bpm": 104, "loop": true,
		"mel": [[69, 0.5], [70, 0.5], [72, 1], [69, 1], [65, 1],
			[67, 0.5], [69, 0.5], [70, 1], [67, 1], [62, 1],
			[65, 0.5], [67, 0.5], [69, 1], [70, 1], [74, 1],
			[72, 1.5], [71, 0.5], [72, 1], [-1, 1],
			[77, 1], [76, 0.5], [74, 0.5], [72, 1], [70, 1],
			[69, 1], [70, 0.5], [69, 0.5], [67, 1], [65, 1],
			[67, 1], [69, 0.5], [67, 0.5], [64, 1], [67, 1],
			[65, 2.5], [-1, 1.5]],
		"harm": [[53, 4], [50, 4], [46, 4], [48, 4], [53, 4], [50, 4], [55, 2], [48, 2], [53, 4]],
		"bass": [[41, 1], [48, 1], [41, 1], [45, 1], [38, 1], [45, 1], [38, 1], [36, 1],
			[34, 1], [41, 1], [34, 1], [36, 1], [36, 1], [43, 1], [40, 1], [36, 1],
			[41, 1], [48, 1], [41, 1], [45, 1], [38, 1], [45, 1], [38, 1], [41, 1],
			[43, 2], [36, 2], [41, 2], [41, 2]],
		"drums": "k.h.s.h."},
	# „Weite" — D-dorisch, getragen-abenteuerlich, viel Raum.
	"world": {"bpm": 92, "loop": true,
		"mel": [[62, 1], [64, 0.5], [65, 0.5], [67, 1.5], [69, 0.5],
			[67, 1], [65, 0.5], [64, 0.5], [60, 2],
			[62, 1], [65, 1], [69, 1], [71, 1],
			[70, 1], [69, 0.5], [67, 0.5], [64, 2],
			[74, 1.5], [72, 0.5], [69, 1], [67, 1],
			[69, 1], [70, 0.5], [72, 0.5], [69, 2],
			[67, 1], [65, 0.5], [64, 0.5], [62, 1], [60, 1],
			[62, 3], [-1, 1]],
		"harm": [[50, 4], [48, 4], [50, 4], [46, 2], [48, 2], [50, 4], [53, 4], [55, 4], [50, 4]],
		"bass": [[38, 2], [45, 2], [36, 2], [43, 2], [38, 2], [45, 2], [34, 2], [36, 2],
			[38, 2], [45, 2], [41, 2], [48, 2], [43, 2], [50, 2], [38, 2], [38, 2]],
		"drums": "k...h.s."},
	# „Schlotwerk" — E-phrygisch, karg und drohend, lange Pausen.
	"dungeon": {"bpm": 66, "loop": true,
		"mel": [[-1, 2], [64, 1.5], [65, 0.5], [64, 2], [62, 2],
			[59, 1.5], [60, 0.5], [59, 2], [-1, 2], [55, 2],
			[64, 1.5], [67, 0.5], [65, 2], [64, 1], [62, 1], [60, 1], [59, 1],
			[57, 4], [-1, 4]],
		"harm": [[40, 8], [41, 8], [40, 8], [38, 8]],
		"bass": [[28, 8], [29, 8], [28, 8], [26, 8]],
		"drums": "k.......s......."},
	# „Konzernturm" — a-Moll, glasig kühle Marmor-Melodie, ohne Schlagzeug.
	"dungeon2": {"bpm": 76, "loop": true,
		"mel": [[76, 1], [74, 0.5], [72, 0.5], [71, 1], [69, 1],
			[71, 1.5], [67, 0.5], [64, 2],
			[65, 1], [69, 1], [72, 1], [77, 1],
			[76, 2], [71, 2],
			[74, 1], [72, 0.5], [71, 0.5], [72, 1], [69, 1],
			[67, 1], [71, 1], [74, 1], [79, 1],
			[77, 2], [76, 1], [75, 1],
			[69, 3], [-1, 1]],
		"harm": [[57, 4], [52, 4], [53, 4], [52, 4], [57, 4], [55, 4], [53, 2], [52, 2], [57, 4]],
		"bass": [[33, 4], [40, 4], [41, 4], [40, 4], [33, 4], [43, 4], [41, 2], [40, 2], [33, 4]],
		"drums": ""},
	# „Klingentanz" — melodischer Techno in a-Moll (Am-F-C-G): Four-on-the-Floor,
	# pumpender Oktavbass, perlendes 16tel-Arpeggio, schwebender Lead darüber.
	"battle": {"bpm": 150, "loop": true,
		"mel": [[76, 2], [74, 0.5], [72, 0.5], [74, 1],
			[72, 1.5], [69, 0.5], [72, 1], [74, 1],
			[76, 1], [79, 1], [77, 0.5], [76, 0.5], [74, 1],
			[74, 1.5], [71, 0.5], [74, 1], [76, 1],
			[81, 2], [79, 0.5], [77, 0.5], [76, 1],
			[77, 1], [76, 0.5], [74, 0.5], [72, 1], [69, 1],
			[72, 1], [74, 0.5], [76, 0.5], [79, 1], [77, 0.5], [76, 0.5],
			[74, 2], [71, 1], [72, 0.5], [74, 0.5]],
		"harm": [[57, 4], [53, 4], [60, 4], [55, 4]],
		"arp": [[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[69, 0.25], [72, 0.25], [77, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [77, 0.25], [72, 0.25],
			[69, 0.25], [72, 0.25], [77, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [77, 0.25], [72, 0.25],
			[67, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [67, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[67, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [67, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25], [67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25],
			[67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25], [67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25]],
		"bass": [[33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5],
			[29, 0.5], [41, 0.5], [29, 0.5], [41, 0.5], [29, 0.5], [41, 0.5], [29, 0.5], [41, 0.5],
			[36, 0.5], [48, 0.5], [36, 0.5], [48, 0.5], [36, 0.5], [48, 0.5], [36, 0.5], [48, 0.5],
			[31, 0.5], [43, 0.5], [31, 0.5], [43, 0.5], [31, 0.5], [43, 0.5], [31, 0.5], [43, 0.5]],
		"drums": "khBhkhBh"},
	# „Schlotbaron" — d-phrygisch, stampfendes Riff mit chromatischen Reibungen.
	"boss": {"bpm": 148, "loop": true,
		"mel": [[62, 0.5], [62, 0.5], [63, 0.5], [62, 0.5], [65, 1], [62, 0.5], [61, 0.5],
			[62, 0.5], [62, 0.5], [63, 0.5], [65, 0.5], [68, 1], [67, 0.5], [65, 0.5],
			[70, 1], [68, 0.5], [67, 0.5], [65, 0.5], [63, 0.5], [62, 1],
			[63, 1], [62, 0.5], [60, 0.5], [58, 2],
			[74, 0.5], [-1, 0.5], [74, 0.5], [75, 0.5], [74, 0.5], [72, 0.5], [70, 1],
			[68, 0.5], [70, 0.5], [72, 0.5], [74, 0.5], [75, 1], [74, 0.5], [72, 0.5],
			[70, 0.5], [68, 0.5], [67, 0.5], [65, 0.5], [63, 0.5], [65, 0.5], [62, 1],
			[62, 1], [63, 1], [62, 2]],
		"harm": [[50, 4], [51, 4], [50, 4], [46, 4], [50, 4], [51, 4], [48, 4], [50, 4]],
		"arp": [[62, 0.25], [65, 0.25], [69, 0.25], [65, 0.25], [62, 0.25], [65, 0.25], [69, 0.25], [65, 0.25],
			[62, 0.25], [65, 0.25], [69, 0.25], [65, 0.25], [62, 0.25], [65, 0.25], [69, 0.25], [65, 0.25],
			[63, 0.25], [67, 0.25], [70, 0.25], [67, 0.25], [63, 0.25], [67, 0.25], [70, 0.25], [67, 0.25],
			[63, 0.25], [67, 0.25], [70, 0.25], [67, 0.25], [63, 0.25], [67, 0.25], [70, 0.25], [67, 0.25]],
		"bass": [[26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5],
			[27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5],
			[26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5],
			[34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5],
			[26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5],
			[27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5], [27, 0.5], [39, 0.5],
			[24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5],
			[26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5]],
		"drums": "kkBhkhBh"},
	# „Monopolfürst" — e-Moll episch mit hohem Gegenlauf und Leitton-Schluss.
	"boss2": {"bpm": 152, "loop": true,
		"mel": [[64, 0.5], [64, 0.5], [67, 0.5], [71, 0.5], [72, 1], [71, 0.5], [67, 0.5],
			[69, 0.5], [71, 0.5], [72, 0.5], [74, 0.5], [71, 1], [67, 1],
			[76, 1], [74, 0.5], [72, 0.5], [74, 0.5], [72, 0.5], [71, 0.5], [69, 0.5],
			[71, 1.5], [66, 0.5], [64, 2],
			[72, 0.5], [74, 0.5], [76, 0.5], [79, 0.5], [78, 1], [76, 0.5], [74, 0.5],
			[76, 0.5], [74, 0.5], [72, 0.5], [71, 0.5], [72, 1], [69, 1],
			[67, 0.5], [69, 0.5], [71, 0.5], [72, 0.5], [74, 0.5], [76, 0.5], [78, 0.5], [79, 0.5],
			[76, 2], [75, 1], [71, 1]],
		"harm": [[52, 4], [48, 4], [50, 4], [47, 4], [52, 4], [48, 4], [50, 2], [51, 2], [52, 4]],
		"bass": [[28, 0.5], [40, 0.5], [28, 0.5], [40, 0.5], [28, 0.5], [40, 0.5], [28, 0.5], [40, 0.5],
			[24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5], [24, 0.5], [36, 0.5],
			[26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5], [26, 0.5], [38, 0.5],
			[23, 0.5], [35, 0.5], [23, 0.5], [35, 0.5], [23, 0.5], [35, 0.5], [23, 0.5], [35, 0.5]],
		"drums": "khBhkhBh"},
	# „Hassfestung" — E-phrygisch, dumpfer Marsch über bösem Halbton-Drone.
	"dungeon3": {"bpm": 100, "loop": true,
		"mel": [[52, 1], [52, 0.5], [52, 0.5], [53, 1], [52, 1],
			[55, 1], [53, 0.5], [52, 0.5], [53, 2],
			[52, 1], [52, 0.5], [52, 0.5], [55, 1], [57, 1],
			[59, 1], [57, 0.5], [55, 0.5], [53, 1], [52, 1],
			[64, 1], [62, 0.5], [60, 0.5], [62, 1], [59, 1],
			[60, 1], [59, 0.5], [57, 0.5], [59, 1], [55, 1],
			[57, 1], [59, 0.5], [60, 0.5], [59, 1], [53, 1],
			[52, 2], [53, 1], [52, 1]],
		"harm": [[40, 8], [41, 8]],
		"bass": [[28, 0.5], [28, 0.5], [35, 0.5], [28, 0.5],
			[28, 0.5], [33, 0.5], [35, 0.5], [31, 0.5]],
		"drums": "k.k.s.k."},
	# „Der Spalter" — A-phrygisch, hetzendes Riff, das sich immer höher schraubt.
	"boss3": {"bpm": 158, "loop": true,
		"mel": [[57, 0.5], [57, 0.5], [58, 0.5], [57, 0.5], [60, 1], [58, 0.5], [57, 0.5],
			[57, 0.5], [58, 0.5], [60, 0.5], [62, 0.5], [65, 1], [64, 0.5], [62, 0.5],
			[64, 1], [62, 0.5], [60, 0.5], [62, 0.5], [60, 0.5], [58, 1],
			[58, 1], [57, 0.5], [55, 0.5], [57, 2],
			[69, 0.5], [-1, 0.5], [69, 0.5], [70, 0.5], [69, 0.5], [67, 0.5], [65, 1],
			[64, 0.5], [65, 0.5], [67, 0.5], [69, 0.5], [70, 1], [69, 0.5], [67, 0.5],
			[65, 0.5], [64, 0.5], [62, 0.5], [60, 0.5], [62, 0.5], [64, 0.5], [58, 1],
			[57, 1], [58, 1], [57, 2]],
		"harm": [[45, 4], [46, 4], [45, 4], [43, 2], [46, 2]],
		"arp": [[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25], [70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25],
			[70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25], [70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25],
			[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25], [69, 0.25], [72, 0.25], [76, 0.25], [72, 0.25],
			[67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25], [67, 0.25], [71, 0.25], [74, 0.25], [71, 0.25],
			[70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25], [70, 0.25], [74, 0.25], [77, 0.25], [74, 0.25]],
		"bass": [[33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5],
			[34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5],
			[33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [45, 0.5],
			[31, 0.5], [43, 0.5], [31, 0.5], [43, 0.5], [34, 0.5], [46, 0.5], [34, 0.5], [46, 0.5]],
		"drums": "kkBhkkBh"},
	# „Die Leere" — sehr langsam, karg, unaufgelöst. Weite Pausen, tiefer Drone:
	# musikalische Einsamkeit, in der nichts irgendwohin strebt.
	"dungeon4": {"bpm": 58, "loop": true,
		"mel": [[-1, 2], [69, 3], [-1, 1], [67, 2], [-1, 2],
			[64, 3], [-1, 1], [65, 2], [-1, 2],
			[62, 3], [-1, 1], [60, 2], [-1, 2],
			[57, 4], [-1, 4]],
		"harm": [[45, 8], [43, 8], [41, 8], [45, 10]],
		"bass": [[33, 4], [-1, 4], [31, 4], [-1, 4], [29, 4], [-1, 4], [33, 4], [-1, 2], [33, 2]],
		"drums": ""},
	# „Die Stille" — Ganzton-Skala (kein Leitton, keine Auflösung): eine kühle,
	# gleichgültige Boss-Musik, die weder wütet noch tröstet, nur unaufhaltsam pulst.
	"boss4": {"bpm": 112, "loop": true,
		"mel": [[72, 1], [74, 1], [76, 1.5], [78, 0.5], [76, 1], [74, 1],
			[70, 1], [72, 1], [74, 1.5], [76, 0.5], [74, 1], [72, 1],
			[68, 1], [70, 1], [72, 1.5], [74, 0.5], [72, 1], [70, 1],
			[76, 2], [74, 1], [72, 1], [70, 2], [68, 2]],
		"harm": [[60, 4], [62, 4], [64, 4], [66, 4], [60, 4], [64, 2], [62, 2]],
		"bass": [[36, 1], [36, 1], [38, 1], [38, 1], [36, 1], [36, 1], [34, 1], [34, 1]],
		"drums": "k...k...k...k..."},
	# Sieg-Fanfare — C-Dur, kurzer Aufschwung mit Oktavsprung.
	"victory": {"bpm": 132, "loop": false,
		"mel": [[67, 0.5], [72, 0.5], [76, 0.5], [79, 1.5], [76, 0.5], [79, 2],
			[-1, 0.5], [77, 0.5], [79, 0.5], [81, 0.5], [84, 2.5]],
		"harm": [[64, 2], [60, 2], [65, 2], [67, 1], [72, 3]],
		"bass": [[48, 1], [43, 1], [41, 1], [45, 1], [43, 1], [41, 1], [43, 2], [48, 2]],
		"drums": ""},
	# Abspann — C-Dur, ruhig absteigende Seufzer-Linie.
	"ending": {"bpm": 84, "loop": true,
		"mel": [[76, 1.5], [77, 0.5], [76, 1], [72, 1],
			[74, 1.5], [76, 0.5], [74, 1], [71, 1],
			[72, 1], [74, 0.5], [72, 0.5], [71, 1], [69, 1],
			[67, 2], [69, 1], [71, 1], [72, 4]],
		"harm": [[60, 4], [57, 4], [53, 4], [55, 4], [60, 4]],
		"bass": [[48, 2], [55, 2], [45, 2], [52, 2], [41, 2], [48, 2], [43, 2], [50, 2], [48, 4]],
		"drums": ""},
	# Niederlage — a-Moll, chromatisch sinkend.
	"defeat": {"bpm": 60, "loop": false,
		"mel": [[69, 2], [68, 2], [67, 2], [65, 2], [64, 3], [-1, 1]],
		"harm": [[57, 4], [53, 4], [52, 4]],
		"bass": [[33, 4], [29, 4], [28, 4]],
		"drums": ""},
}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	# Echte Musikstücke sind kräftiger gemastert als der Synth — etwas leiser
	# fahren, damit die SFX durchkommen.
	music_player.volume_db = -9.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		sfx_players.append(p)

## Echte Musikstücke (CC0, Juhani Junkala — siehe assets/music/LICENSE.txt).
## Wo eine Datei existiert, spielt sie; sonst greift der Chiptune-Synth
## (z. B. für die kurzen Sieg-/Niederlage-Jingles).
const MUSIC_DIR := "res://assets/music/"

func play_music(id: String) -> void:
	if id == current_music:
		return
	var path := MUSIC_DIR + id + ".ogg"
	if ResourceLoader.exists(path):
		current_music = id
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		music_player.stream = stream
		music_player.play()
		return
	if not SONGS.has(id):
		return
	current_music = id
	if not _music_cache.has(id):
		_music_cache[id] = _render_song(SONGS[id])
	music_player.stream = _music_cache[id]
	music_player.play()

## Echte Soundeffekte (CC0, Kenney — siehe assets/sfx/LICENSE.txt) haben
## Vorrang; wo keine Datei liegt, rendert weiterhin der Synth (z. B. die
## eigens gebauten Explosionen boom/bigboom/nuke).
const SFX_DIR := "res://assets/sfx/"

func play_sfx(id: String) -> void:
	if not _sfx_cache.has(id):
		var path := SFX_DIR + id + ".ogg"
		if ResourceLoader.exists(path):
			_sfx_cache[id] = load(path)
		else:
			var buf := _render_sfx(id)
			if buf == null:
				return
			_sfx_cache[id] = buf
	var p: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	p.stream = _sfx_cache[id]
	p.play()

## ---------- Synthese ----------

static func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

func _render_song(song: Dictionary) -> AudioStreamWAV:
	var bpm: float = song["bpm"]
	var spb := 60.0 / bpm  # Sekunden pro Schlag
	var total_beats := 0.0
	for n in song["mel"]:
		total_beats += n[1]
	var total := int(total_beats * spb * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	_render_track(mix, song["mel"], spb, 0.16, "lead")
	if song.has("harm"):
		_render_track(mix, song["harm"], spb, 0.10, "pad")
	# Optionale Arpeggio-Spur: perlende 16tel für treibende Kampf-Tracks.
	if song.has("arp"):
		_render_track(mix, song["arp"], spb, 0.085, "square")
	_render_track(mix, song["bass"], spb, 0.28, "bass")
	if song.get("drums", "") != "":
		_render_drums(mix, song["drums"], spb, 0.30)
	# Zwei Echo-Stufen (punktierte Achtel + Viertel) geben Raumtiefe.
	var d1 := int(0.375 * spb * RATE)
	var d2 := int(0.75 * spb * RATE)
	if d1 > 0:
		for i in range(d1, total):
			mix[i] += mix[i - d1] * 0.22
	if d2 > 0:
		for i in range(d2, total):
			mix[i] += mix[i - d2] * 0.10
	# Sanfter Tiefpass nimmt das digitale Kratzen, weiche Sättigung
	# klebt die Stimmen zusammen (Analog-„Glue").
	var lp := 0.0
	for i in total:
		lp += 0.55 * (mix[i] - lp)
		var x := lp * 1.25
		mix[i] = x / (1.0 + absf(x)) * 1.1
	return _to_wav(mix, song["loop"])

func _render_track(mix: PackedFloat32Array, notes: Array, spb: float, vol: float, wave: String) -> void:
	var pos := 0
	var total := mix.size()
	while pos < total:
		for n in notes:
			var length := int(n[1] * spb * RATE)
			if n[0] >= 0:
				var f := _freq(n[0])
				var attack := int((0.018 if wave == "pad" else 0.006) * RATE)
				var body := int(length * 0.82)
				# Phase pro Sample aufintegrieren — nur so bleibt das Vibrato
				# über lange Noten stabil (fmod(t*f*vib) driftet mit t weg).
				var ph := 0.0
				for i in length:
					var idx := pos + i
					if idx >= total:
						return
					var t := float(i) / RATE
					# Dezentes Vibrato, das erst nach dem Anschlag einschwingt.
					var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t) * minf(t * 3.0, 1.0)
					ph += f * vib / RATE
					var v: float
					match wave:
						"lead":
							# Zwei verstimmte Sägezähne + leises Oktav-Rechteck:
							# breiter Chorus-Lead statt dünnem Piepen.
							var p1 := fmod(ph, 1.0)
							var p2 := fmod(ph * 1.006 + 0.3, 1.0)
							var p3 := fmod(ph * 0.5, 1.0)
							v = (p1 - 0.5) * 0.9 + (p2 - 0.5) * 0.7 \
								+ (0.25 if p3 < 0.5 else -0.25)
						"pad":
							# Zwei verstimmte Dreiecke = weiches, schwebendes Pad.
							var q1 := fmod(ph, 1.0)
							var q2 := fmod(ph * 1.012 + 0.5, 1.0)
							v = (4.0 * absf(q1 - 0.5) - 1.0) * 0.6 \
								+ (4.0 * absf(q2 - 0.5) - 1.0) * 0.5
						"bass":
							# Runder Bass: Sinus + Dreieck-Oberton + Sub-Oktave
							# (halbe Frequenz) für spürbares Fundament.
							v = sin(TAU * ph) * 0.8 \
								+ (4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0) * 0.3 \
								+ sin(TAU * ph * 0.5) * 0.55
						"tri":
							v = 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
						_:
							v = 0.7 if fmod(ph, 1.0) < 0.5 else -0.7
					var env := 1.0
					if i < attack: env = float(i) / attack
					elif i > body:
						var rel := maxf(1.0 - float(i - body) / (length - body), 0.0)
						env = rel * rel
					mix[idx] += v * vol * env
			pos += length
			if pos >= total:
				return

## Schlagzeugspur: Pattern loopt, ein Zeichen pro halbem Schlag.
func _render_drums(mix: PackedFloat32Array, pattern: String, spb: float, vol: float) -> void:
	var total := mix.size()
	var step := int(0.5 * spb * RATE)
	var pos := 0
	var idx := 0
	while pos < total:
		var ch := pattern[idx % pattern.length()]
		match ch:
			"k": _drum_hit(mix, pos, 0.11, vol * 1.2, "kick")
			"s": _drum_hit(mix, pos, 0.09, vol * 0.8, "snare")
			"h": _drum_hit(mix, pos, 0.03, vol * 0.35, "hat")
			"B":
				# Kick + Snare gleichzeitig — der Backbeat im Four-on-the-Floor.
				_drum_hit(mix, pos, 0.11, vol * 1.1, "kick")
				_drum_hit(mix, pos, 0.09, vol * 0.75, "snare")
		pos += step
		idx += 1

func _drum_hit(mix: PackedFloat32Array, start: int, dur: float, vol: float, kind: String) -> void:
	var n := int(dur * RATE)
	var phase := 0.0
	var last := 0.0
	for i in n:
		var idx := start + i
		if idx >= mix.size():
			return
		var t := float(i) / n
		var v: float
		match kind:
			"kick":
				# Pitch-Sweep + kurzer Klick am Anfang für Attack.
				phase += lerpf(160.0, 42.0, t) / RATE
				v = sin(phase * TAU)
				if i < 30:
					v += randf_range(-0.5, 0.5)
			"snare":
				v = randf_range(-1.0, 1.0) * 0.6 \
					+ sin(float(i) * 190.0 / RATE * TAU) * 0.35 \
					+ sin(float(i) * 285.0 / RATE * TAU) * 0.15
			_:
				# HiHat: differenziertes Rauschen = Hochpass, klingt metallischer.
				var wn := randf_range(-1.0, 1.0)
				v = (wn - last) * 1.4
				last = wn
		mix[idx] += v * vol * (1.0 - t) * (1.0 - t)

func _render_sfx(id: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match id:
		"step": _tone(buf, 180, 90, 0.05, 0.10, "noise")
		"menu": _tone(buf, 880, 880, 0.05, 0.20, "square")
		"buy":
			_tone(buf, 660, 660, 0.07, 0.22, "square")
			_tone(buf, 990, 990, 0.10, 0.22, "square")
		"error": _tone(buf, 160, 140, 0.18, 0.25, "square")
		"slash": _tone(buf, 3000, 300, 0.14, 0.30, "noise")
		"hit": _tone(buf, 500, 60, 0.15, 0.35, "noise")
		"fire": _tone(buf, 200, 900, 0.30, 0.22, "tri")
		"boom": _render_boom(buf, 0.9, 0.50, 0.5)
		"bigboom": _render_boom(buf, 1.5, 0.60, 0.7)
		"stomp":
			_tone(buf, 90, 28, 0.28, 0.55, "noise")
			_tone(buf, 55, 22, 0.22, 0.45, "tri")
		"charge": _tone(buf, 160, 1900, 0.65, 0.28, "tri")
		"ult_charge":
			_tone(buf, 120, 900, 0.55, 0.28, "tri")
			_tone(buf, 400, 2600, 0.45, 0.24, "square")
		"meteor": _tone(buf, 1900, 110, 0.45, 0.32, "noise")
		"heal":
			for f in [523, 659, 784, 1047]:
				_tone(buf, f, f, 0.09, 0.18, "tri")
		"die": _tone(buf, 400, 50, 0.40, 0.25, "square")
		"encounter":
			for i in 3:
				_tone(buf, 700, 350, 0.09, 0.25, "square")
		"flee":
			for f in [880, 660, 520, 390]:
				_tone(buf, f, f, 0.06, 0.20, "square")
		"whirl": _tone(buf, 300, 1400, 0.35, 0.22, "square")
		"laser":
			_tone(buf, 2600, 700, 0.28, 0.24, "square")
			_tone(buf, 1400, 400, 0.20, 0.20, "tri")
		"rocket":
			_tone(buf, 300, 1700, 0.22, 0.20, "noise")
			_tone(buf, 200, 90, 0.14, 0.30, "tri")
		"roar":
			_tone(buf, 130, 35, 0.55, 0.40, "noise")
			_tone(buf, 90, 45, 0.35, 0.30, "square")
		"growl":
			# Leises, tiefes Grollen — der Boss atmet im Hintergrund
			_tone(buf, 70, 38, 0.60, 0.16, "tri")
			_tone(buf, 110, 50, 0.40, 0.10, "noise")
		"summon":
			# Tiefes Grollen + aufsteigender Beschwörungs-Akkord
			_tone(buf, 70, 480, 0.55, 0.28, "tri")
			for f in [262, 330, 392, 523]:
				_tone(buf, f, f * 1.02, 0.09, 0.20, "tri")
		"eruption":
			_tone(buf, 1600, 55, 0.50, 0.38, "noise")
			_tone(buf, 120, 40, 0.35, 0.35, "tri")
		"wave":
			_tone(buf, 900, 200, 0.90, 0.30, "noise")
		"splash":
			_tone(buf, 1400, 300, 0.20, 0.28, "noise")
		"alarm":
			# Zwei schrille Warntöne mit kurzer Pause
			for i in 2:
				_tone(buf, 1180, 1180, 0.12, 0.22, "square")
				_tone(buf, 100, 100, 0.08, 0.0, "tri")
		"whistle":
			# Fallende Fliegerbombe: langer, absinkender Pfeifton
			_tone(buf, 1650, 220, 0.95, 0.20, "tri")
		"nuke": _render_boom(buf, 3.0, 0.70, 0.9)
		"splat":
			# Nasser Schlammklatscher
			_tone(buf, 300, 80, 0.12, 0.30, "noise")
			_tone(buf, 140, 60, 0.10, 0.25, "tri")
		"coin":
			# Helles Münzklimpern (Quint-Sprung nach oben)
			_tone(buf, 1560, 1560, 0.05, 0.20, "square")
			_tone(buf, 2080, 2080, 0.09, 0.16, "square")
		"screech":
			# Kreischende Hetz-Attacke: fallendes Krächzen
			_tone(buf, 2400, 400, 0.22, 0.24, "noise")
			_tone(buf, 1800, 300, 0.18, 0.20, "square")
		"mgun":
			# Einzelner MG-Schuss: harter, trockener Knall + tiefer Anschlag.
			# Im Kampf schnell hintereinander abgefeuert ergibt das Rattern.
			_render_gun(buf, 0.10, 0.45)
		"sizzle":
			# Glühendes Metall, das sich in den Boden brennt: hohes Zischen
			# (gefiltertes Rauschen) über einem knisternden Mittenband.
			_tone(buf, 6200, 3400, 0.20, 0.16, "noise")
			_tone(buf, 2600, 1500, 0.16, 0.12, "noise")
			_tone(buf, 520, 380, 0.08, 0.05, "square")
		_:
			return null
	return _to_wav(buf, false)

## Realistische Explosion in Schichten: scharfer Knall-Transient (breitbandiges
## Rauschen, sehr kurz), Druckwellen-Grollen (tiefpassgefiltertes Rauschen,
## dessen Grenzfrequenz nach unten wandert — erst Wucht, dann Rumpeln) und
## Sub-Wumms (Sinus-Sweep 70→24 Hz). Exponentielle Hüllkurven statt linearer
## Rampen — das macht den natürlichen Klangeindruck aus.
func _render_boom(buf: PackedFloat32Array, dur: float, vol: float, punch: float) -> void:
	var n := int(dur * RATE)
	var start := buf.size()
	buf.resize(start + n)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	var rumble_am := 1.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		# Tiefpass-Grenze wandert von offen (Knall) zu sehr tief (Grollen)
		var cutoff := lerpf(0.5, 0.035, minf(k * 2.6, 1.0))
		lp += cutoff * (randf_range(-1.0, 1.0) - lp)
		lp2 += 0.4 * (lp - lp2)
		# Sub-Wumms
		phase += lerpf(70.0, 24.0, minf(k * 2.0, 1.0)) / RATE
		var sub := sin(phase * TAU)
		# Langsame Zufallsmodulation lässt das Ausrollen "brodeln"
		if i % 512 == 0:
			rumble_am = lerpf(rumble_am, randf_range(0.55, 1.0), 0.5)
		var env := exp(-k * 4.6)
		var crack := randf_range(-1.0, 1.0) * exp(-t * 70.0) * punch
		buf[start + i] = (lp2 * 2.4 * rumble_am + sub * 0.55) * env * vol + crack * vol
	# Weiche Sättigung gegen harte Spitzen des Transienten
	for i in n:
		var x := buf[start + i] * 1.3
		buf[start + i] = x / (1.0 + absf(x))

## Hängt einen Ton (Frequenz-Sweep f0→f1) an den Puffer an.
func _tone(buf: PackedFloat32Array, f0: float, f1: float, dur: float, vol: float, wave: String) -> void:
	var n := int(dur * RATE)
	var start := buf.size()
	buf.resize(start + n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f: float = lerpf(f0, f1, t)
		phase += f / RATE
		var v: float
		match wave:
			"noise": v = randf_range(-1.0, 1.0)
			"tri": v = 4.0 * abs(fmod(phase, 1.0) - 0.5) - 1.0
			_: v = 0.7 if fmod(phase, 1.0) < 0.5 else -0.7
		var env := minf(t * 12.0, 1.0) * (1.0 - t)
		buf[start + i] = v * vol * env

## Einzelner Gewehrschuss: heller Knall-Transient (breitbandiges Rauschen, sehr
## schnelle exp-Hüllkurve), ein tiefer Anschlag-„Wumms" (Sinus 150→55 Hz) und
## etwas tiefpassgefiltertes Rausch-Körpergeräusch — alles in dieselben Samples
## überlagert und weich geclippt. Kurz (~90 ms), damit sich Schüsse stapeln.
func _render_gun(buf: PackedFloat32Array, dur: float, vol: float) -> void:
	var n := int(dur * RATE)
	var start := buf.size()
	buf.resize(start + n)
	var lp := 0.0
	var prev_noise := 0.0
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		# Scharfer Crack: breitbandiges Rauschen PLUS hochpassgefilterter Anteil
		# (Differenz aufeinanderfolgender Samples) für den harten, trockenen Knall.
		var nz := randf_range(-1.0, 1.0)
		var hp := nz - prev_noise
		prev_noise = nz
		var crack := (nz * 0.45 + hp * 1.0) * exp(-k * 32.0)
		# Harter tiefer Anschlag mit schnellem Frequenz-Sweep (Sub-Punch).
		phase += lerpf(230.0, 60.0, minf(k * 3.0, 1.0)) / RATE
		var thump := sin(phase * TAU) * exp(-k * 20.0)
		# Kurzes, tiefpassgefiltertes Körpergeräusch.
		lp += 0.45 * (randf_range(-1.0, 1.0) - lp)
		var body := lp * exp(-k * 26.0) * 0.4
		# Aggressiv übersteuern (Pre-Gain vor dem Soft-Clip) = härterer, knalliger
		# Ton mit Biss statt weichem Plopp.
		var x := (crack * 0.9 + thump * 0.8 + body) * vol * 2.6
		buf[start + i] = x / (1.0 + absf(x))

func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
