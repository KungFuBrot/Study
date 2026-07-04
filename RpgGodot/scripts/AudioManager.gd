extends Node
## Prozeduraler Chiptune-Synth: Musik und SFX werden beim ersten Abruf als
## PCM gerendert (AudioStreamWAV) und gecacht — keine Audiodateien nötig.

const RATE := 22050

var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx_next := 0
var _music_cache := {}
var _sfx_cache := {}
var current_music := ""

# Songs: [Tempo BPM, loop, Melodie, Bass]; Noten als [MIDI, Schläge], -1 = Pause.
const SONGS := {
	"town": [120, true,
		[[72, 1], [76, 1], [79, 1], [76, 1], [77, 1], [81, 1], [79, 1], [76, 1],
		 [74, 1], [77, 1], [76, 1], [72, 1], [74, 1], [71, 1], [72, 2]],
		[[48, 2], [55, 2], [53, 2], [55, 2], [50, 2], [48, 2], [43, 2], [48, 2]]],
	"world": [105, true,
		[[69, 1], [72, 1], [76, 1], [74, 1], [72, 1], [74, 1], [76, 1], [79, 1],
		 [77, 1], [76, 1], [74, 1], [72, 1], [71, 1], [72, 1], [74, 2]],
		[[45, 2], [52, 2], [48, 2], [52, 2], [50, 2], [48, 2], [47, 2], [45, 2]]],
	"dungeon": [80, true,
		[[62, 2], [65, 1], [68, 1], [69, 2], [65, 2], [63, 2], [62, 1], [60, 1], [58, 4]],
		[[38, 4], [41, 4], [36, 4], [38, 4]]],
	"battle": [150, true,
		[[64, 0.5], [64, 0.5], [67, 0.5], [64, 0.5], [69, 0.5], [67, 0.5], [64, 1],
		 [62, 0.5], [64, 0.5], [67, 0.5], [71, 0.5], [69, 0.5], [67, 0.5], [64, 1],
		 [72, 0.5], [71, 0.5], [69, 0.5], [67, 0.5], [69, 0.5], [71, 0.5], [72, 1],
		 [71, 0.5], [69, 0.5], [67, 0.5], [64, 0.5], [62, 1], [64, 1]],
		[[40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5], [40, 0.5], [40, 0.5], [47, 0.5], [40, 0.5],
		 [43, 0.5], [43, 0.5], [50, 0.5], [43, 0.5], [45, 0.5], [45, 0.5], [40, 0.5], [40, 0.5]]],
	"boss": [132, true,
		[[62, 0.5], [62, 0.5], [65, 0.5], [62, 0.5], [68, 0.5], [67, 0.5], [65, 1],
		 [62, 0.5], [62, 0.5], [65, 0.5], [68, 0.5], [70, 0.5], [68, 0.5], [65, 1],
		 [74, 0.5], [73, 0.5], [74, 0.5], [70, 0.5], [68, 0.5], [65, 0.5], [62, 1],
		 [61, 0.5], [62, 0.5], [61, 0.5], [58, 0.5], [61, 1], [62, 1]],
		[[38, 0.5], [38, 0.5], [45, 0.5], [38, 0.5], [37, 0.5], [37, 0.5], [44, 0.5], [37, 0.5],
		 [41, 0.5], [41, 0.5], [48, 0.5], [41, 0.5], [43, 0.5], [43, 0.5], [38, 0.5], [38, 0.5]]],
	"victory": [140, false,
		[[72, 0.5], [72, 0.5], [72, 0.5], [76, 1], [74, 0.5], [76, 1], [79, 2]],
		[[48, 1.5], [52, 1], [55, 1.5], [60, 2]]],
	"defeat": [70, false,
		[[64, 1.5], [62, 1.5], [60, 1.5], [57, 3]],
		[[45, 3], [41, 3], [33, 3]]],
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

func _render_song(song: Array) -> AudioStreamWAV:
	var bpm: float = song[0]
	var spb := 60.0 / bpm  # Sekunden pro Schlag
	var total_beats := 0.0
	for n in song[2]:
		total_beats += n[1]
	var total := int(total_beats * spb * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	_render_track(mix, song[2], spb, 0.22, "square")
	_render_track(mix, song[3], spb, 0.20, "tri")
	return _to_wav(mix, song[1])

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
					var ph := fmod(t * f, 1.0)
					var v: float = (0.7 if ph < 0.5 else -0.7) if wave == "square" \
						else (4.0 * absf(ph - 0.5) - 1.0)
					var env := 1.0
					if i < attack: env = float(i) / attack
					elif i > body: env = maxf(1.0 - float(i - body) / (length - body), 0.0)
					mix[idx] += v * vol * env
			pos += length
			if pos >= total:
				return

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
