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
	"town": {"bpm": 120, "loop": true,
		"mel": [[72, 1], [76, 1], [79, 1], [76, 1], [77, 1], [81, 1], [79, 1], [76, 1],
			[74, 1], [77, 1], [76, 1], [72, 1], [74, 1], [71, 1], [72, 2]],
		"harm": [[64, 2], [67, 2], [65, 2], [69, 2], [62, 2], [64, 2], [62, 2], [64, 2]],
		"bass": [[48, 2], [55, 2], [53, 2], [55, 2], [50, 2], [48, 2], [43, 2], [48, 2]],
		"drums": "k.h.s.h."},
	"world": {"bpm": 105, "loop": true,
		"mel": [[69, 1], [72, 1], [76, 1], [74, 1], [72, 1], [74, 1], [76, 1], [79, 1],
			[77, 1], [76, 1], [74, 1], [72, 1], [71, 1], [72, 1], [74, 2]],
		"harm": [[60, 4], [64, 4], [65, 4], [62, 4]],
		"bass": [[45, 2], [52, 2], [48, 2], [52, 2], [50, 2], [48, 2], [47, 2], [45, 2]],
		"drums": "k.h.s.hh"},
	"dungeon": {"bpm": 80, "loop": true,
		"mel": [[62, 2], [65, 1], [68, 1], [69, 2], [65, 2], [63, 2], [62, 1], [60, 1], [58, 4]],
		"harm": [[50, 8], [46, 4], [48, 4]],
		"bass": [[38, 4], [41, 4], [36, 4], [38, 4]],
		"drums": "k...s..."},
	"dungeon2": {"bpm": 76, "loop": true,
		"mel": [[74, 1], [79, 1], [78, 1], [74, 1], [76, 2], [71, 2],
			[74, 1], [79, 1], [81, 1], [78, 1], [79, 3], [-1, 1]],
		"harm": [[62, 4], [59, 4], [62, 4], [61, 4]],
		"bass": [[43, 4], [40, 4], [38, 4], [43, 4]],
		"drums": "k.....s."},
	"battle": {"bpm": 150, "loop": true,
		"mel": [[64, 0.5], [64, 0.5], [67, 0.5], [64, 0.5], [69, 0.5], [67, 0.5], [64, 1],
			[62, 0.5], [64, 0.5], [67, 0.5], [71, 0.5], [69, 0.5], [67, 0.5], [64, 1],
			[72, 0.5], [71, 0.5], [69, 0.5], [67, 0.5], [69, 0.5], [71, 0.5], [72, 1],
			[71, 0.5], [69, 0.5], [67, 0.5], [64, 0.5], [62, 1], [64, 1]],
		"harm": [[55, 2], [55, 2], [57, 2], [55, 2], [60, 2], [59, 2], [55, 2], [56, 2]],
		"bass": [[40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5],
			[43, 0.5], [43, 0.5], [50, 0.5], [43, 0.5], [45, 0.5], [45, 0.5], [40, 0.5], [40, 0.5]],
		"drums": "k.hsk.hh"},
	"boss": {"bpm": 140, "loop": true,
		"mel": [[62, 0.5], [62, 0.5], [65, 0.5], [67, 0.5], [68, 1], [67, 0.5], [65, 0.5],
			[62, 0.5], [62, 0.5], [65, 0.5], [67, 0.5], [70, 1], [68, 0.5], [67, 0.5],
			[74, 0.5], [73, 0.5], [74, 0.5], [73, 0.5], [70, 0.5], [68, 0.5], [67, 0.5], [65, 0.5],
			[68, 0.5], [67, 0.5], [65, 0.5], [63, 0.5], [62, 1], [61, 1]],
		"harm": [[50, 4], [50, 4], [46, 2], [48, 2], [50, 2], [49, 2]],
		"bass": [[38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5], [38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5],
			[38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5], [38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5],
			[34, 0.5], [34, 0.5], [41, 0.5], [34, 0.5], [36, 0.5], [36, 0.5], [43, 0.5], [36, 0.5],
			[38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5], [37, 0.5], [37, 0.5], [44, 0.5], [37, 0.5]],
		"drums": "kk.sk.hs"},
	"boss2": {"bpm": 155, "loop": true,
		"mel": [[64, 0.5], [64, 0.5], [67, 0.5], [70, 0.5], [71, 1], [70, 0.5], [67, 0.5],
			[64, 0.5], [64, 0.5], [67, 0.5], [70, 0.5], [72, 1], [71, 0.5], [70, 0.5],
			[76, 0.5], [75, 0.5], [76, 0.5], [72, 0.5], [71, 0.5], [70, 0.5], [67, 0.5], [64, 0.5],
			[70, 0.5], [69, 0.5], [67, 0.5], [65, 0.5], [64, 1], [63, 1]],
		"harm": [[52, 4], [52, 4], [48, 2], [50, 2], [52, 2], [51, 2]],
		"bass": [[40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5],
			[40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5],
			[36, 0.5], [36, 0.5], [43, 0.5], [36, 0.5], [38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5],
			[40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5], [39, 0.5], [39, 0.5], [46, 0.5], [39, 0.5]],
		"drums": "kkhsk.hs"},
	"victory": {"bpm": 140, "loop": false,
		"mel": [[72, 0.5], [72, 0.5], [72, 0.5], [76, 1.5], [74, 0.5], [76, 1],
			[79, 1.5], [77, 0.5], [79, 0.5], [81, 0.5], [84, 3]],
		"harm": [[64, 3], [67, 2], [71, 2], [76, 3]],
		"bass": [[48, 1], [48, 0.5], [52, 1], [55, 1], [53, 1], [55, 1], [60, 2.5]],
		"drums": ""},
	"ending": {"bpm": 90, "loop": true,
		"mel": [[76, 1.5], [74, 0.5], [72, 1], [74, 1], [76, 1], [79, 1], [77, 2],
			[74, 1.5], [72, 0.5], [71, 1], [74, 1], [72, 4]],
		"harm": [[64, 4], [60, 4], [57, 4], [59, 4]],
		"bass": [[48, 1], [55, 1], [52, 1], [55, 1], [45, 1], [52, 1], [48, 1], [52, 1],
			[41, 1], [48, 1], [45, 1], [48, 1], [43, 1], [50, 1], [47, 1], [50, 1]],
		"drums": ""},
	"defeat": {"bpm": 70, "loop": false,
		"mel": [[64, 1.5], [62, 1.5], [60, 1.5], [57, 3]],
		"harm": [[52, 3], [48, 3], [45, 1.5]],
		"bass": [[45, 3], [41, 3], [33, 3]],
		"drums": ""},
}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -8.0
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		sfx_players.append(p)

func play_music(id: String) -> void:
	if not SONGS.has(id) or id == current_music:
		return
	current_music = id
	if not _music_cache.has(id):
		_music_cache[id] = _render_song(SONGS[id])
	music_player.stream = _music_cache[id]
	music_player.play()

func play_sfx(id: String) -> void:
	if not _sfx_cache.has(id):
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
		_render_track(mix, song["harm"], spb, 0.10, "tri")
	_render_track(mix, song["bass"], spb, 0.20, "tri")
	if song.get("drums", "") != "":
		_render_drums(mix, song["drums"], spb, 0.30)
	# Leichtes Echo (punktierte Achtel) macht den Klang räumlich.
	var delay := int(0.375 * spb * RATE)
	if delay > 0:
		for i in range(delay, total):
			mix[i] += mix[i - delay] * 0.25
	return _to_wav(mix, song["loop"])

func _render_track(mix: PackedFloat32Array, notes: Array, spb: float, vol: float, wave: String) -> void:
	var pos := 0
	var total := mix.size()
	while pos < total:
		for n in notes:
			var length := int(n[1] * spb * RATE)
			if n[0] >= 0:
				var f := _freq(n[0])
				var attack := int(0.005 * RATE)
				var body := int(length * 0.85)
				for i in length:
					var idx := pos + i
					if idx >= total:
						return
					var t := float(i) / RATE
					var v: float
					match wave:
						"lead":
							# Zwei leicht verstimmte Rechtecke = fetter Chorus-Klang.
							var p1 := fmod(t * f, 1.0)
							var p2 := fmod(t * f * 1.008, 1.0)
							v = (0.6 if p1 < 0.5 else -0.6) + (0.4 if p2 < 0.5 else -0.4)
						"tri":
							v = 4.0 * absf(fmod(t * f, 1.0) - 0.5) - 1.0
						_:
							v = 0.7 if fmod(t * f, 1.0) < 0.5 else -0.7
					var env := 1.0
					if i < attack: env = float(i) / attack
					elif i > body: env = maxf(1.0 - float(i - body) / (length - body), 0.0)
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
		pos += step
		idx += 1

func _drum_hit(mix: PackedFloat32Array, start: int, dur: float, vol: float, kind: String) -> void:
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= mix.size():
			return
		var t := float(i) / n
		var v: float
		match kind:
			"kick":
				phase += lerpf(150.0, 45.0, t) / RATE
				v = sin(phase * TAU)
			"snare":
				v = randf_range(-1.0, 1.0) * 0.7 + sin(float(i) * 180.0 / RATE * TAU) * 0.3
			_:
				v = randf_range(-1.0, 1.0)
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
		"boom": _tone(buf, 1200, 40, 0.45, 0.40, "noise")
		"bigboom":
			_tone(buf, 900, 25, 0.85, 0.50, "noise")
		"stomp":
			_tone(buf, 90, 28, 0.28, 0.55, "noise")
			_tone(buf, 55, 22, 0.22, 0.45, "tri")
		"charge": _tone(buf, 160, 1900, 0.65, 0.28, "tri")
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
		"roar":
			_tone(buf, 130, 35, 0.55, 0.40, "noise")
			_tone(buf, 90, 45, 0.35, 0.30, "square")
		_:
			return null
	return _to_wav(buf, false)

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
