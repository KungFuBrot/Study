class_name Rig3D
extends Node3D
## Figuren als echte 3D-Gelenkskelette, gedacht zum Herunterrendern auf
## Pixel-Art (Verfahren von Motion Twin/Dead Cells: in 3D modellieren und
## animieren, dann sehr klein und ohne Kantenglättung rendern).
##
## Warum 3D statt zeichnen: Bewegung kommt aus Gelenkwinkeln statt aus
## gerechneter Verformung, und das Licht wandert über echte Oberflächen.
## Beides ist der Grund, warum solche Figuren lebendig wirken — nicht der
## Detailgrad.
##
## KEIN Skinning: jeder Körperteil ist ein starres Mesh an einem Gelenk-Node.
## Für diesen Look genügt das (Dead Cells' Modelle sind bewusst grob) und
## spart die gesamte Gewichtungsarbeit.
##
## Fast alle Figuren entstehen aus EINEM parametrierten Humanoiden; nur
## Schleim, Vierbeiner und Spinne haben eigene Bauformen.

var joints := {}   # Name -> Node3D (Drehpunkt)

# --- Bausteine ---------------------------------------------------------------

static func mat(c: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	# Kein spiegelnder Glanz: Form soll aus dem Licht kommen, nicht aus einem
	# Highlight — beim Herunterrechnen frisst das sonst die Silhouette auf.
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _box(parent: Node3D, size: Vector3, offset: Vector3,
		m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = offset
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, r: float, offset: Vector3, sy: float,
		m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * sy
	# Grob facettiert: bei 40 px Bildhöhe ist alles darüber verschenkt.
	sm.radial_segments = 8
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = m
	mi.position = offset
	parent.add_child(mi)
	return mi

func _joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	joints[name] = n
	return n

# --- Humanoide ---------------------------------------------------------------

## Baut eine humanoide Figur nach Spezifikation. Alle Maße skalieren mit `h`
## (Gesamthöhe in Metern), damit ein Gnom dieselbe Tabelle nutzen kann wie ein
## Koloss. `build` verbreitert Rumpf und Glieder.
func build_humanoid(s: Dictionary) -> void:
	var h: float = s.get("h", 1.70)
	var k: float = h / 1.70                       # Grundskalierung
	var bw: float = s.get("build", 1.0)           # Massigkeit
	var hs: float = s.get("head", 1.0)            # Kopfgröße
	var skin := mat(s.get("skin", Color(0.9, 0.74, 0.58)))
	var cloth := mat(s.get("cloth", Color(0.5, 0.2, 0.2)))
	var trim := mat(s.get("trim", Color(0.8, 0.72, 0.5)))
	var legs := mat(s.get("legs", Color(0.3, 0.22, 0.15)))
	var boots := mat(s.get("boots", Color(0.18, 0.13, 0.1)))
	var hair := mat(s.get("hair", Color(0.5, 0.35, 0.15)))
	var floats: bool = s.get("float", false)

	var y_hip := 0.88 * k
	var hips := _joint(self, "hips", Vector3(0, y_hip, 0))
	_box(hips, Vector3(0.20 * k * bw, 0.16 * k, 0.30 * k * bw),
		Vector3(0, -0.02 * k, 0), legs if not floats else cloth)

	var spine := _joint(hips, "spine", Vector3(0, 0.06 * k, 0))
	_box(spine, Vector3(0.19 * k * bw, 0.20 * k, 0.27 * k * bw),
		Vector3(0, 0.10 * k, 0), cloth)
	_box(spine, Vector3(0.23 * k * bw, 0.24 * k, 0.34 * k * bw),
		Vector3(0, 0.32 * k, 0), cloth)
	_box(spine, Vector3(0.21 * k * bw, 0.05 * k, 0.29 * k * bw),
		Vector3(0, 0.0, 0), trim)

	var neck := _joint(spine, "neck", Vector3(0, 0.48 * k, 0))
	_box(neck, Vector3(0.09 * k, 0.06 * k, 0.10 * k), Vector3(0, 0.02 * k, 0), skin)
	var head := _joint(neck, "head", Vector3(0, 0.06 * k, 0))
	_box(head, Vector3(0.20 * k * hs, 0.24 * k * hs, 0.21 * k * hs),
		Vector3(0.01 * k, 0.12 * k * hs, 0), skin)
	_build_head_extras(head, s, k, hs, hair, cloth, trim)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var sh := _joint(spine, "shoulder_" + tag,
			Vector3(0, 0.40 * k, 0.15 * k * bw * side))
		_box(sh, Vector3(0.13 * k * bw, 0.11 * k, 0.12 * k * bw),
			Vector3(0, 0.01 * k, 0), trim)
		_box(sh, Vector3(0.09 * k * bw, 0.24 * k, 0.09 * k * bw),
			Vector3(0, -0.13 * k, 0), cloth)
		var elb := _joint(sh, "elbow_" + tag, Vector3(0, -0.25 * k, 0))
		_box(elb, Vector3(0.08 * k * bw, 0.22 * k, 0.08 * k * bw),
			Vector3(0, -0.11 * k, 0), skin)
		var hand := _joint(elb, "hand_" + tag, Vector3(0, -0.23 * k, 0))
		_box(hand, Vector3(0.08 * k, 0.08 * k, 0.08 * k), Vector3(0, -0.03 * k, 0), skin)

		if floats:
			continue
		var hp := _joint(hips, "hip_" + tag, Vector3(0, -0.08 * k, 0.09 * k * bw * side))
		_box(hp, Vector3(0.12 * k * bw, 0.30 * k, 0.12 * k * bw),
			Vector3(0, -0.16 * k, 0), legs)
		var knee := _joint(hp, "knee_" + tag, Vector3(0, -0.32 * k, 0))
		_box(knee, Vector3(0.10 * k * bw, 0.28 * k, 0.10 * k * bw),
			Vector3(0, -0.15 * k, 0), legs)
		var ankle := _joint(knee, "ankle_" + tag, Vector3(0, -0.30 * k, 0))
		_box(ankle, Vector3(0.19 * k, 0.08 * k, 0.11 * k), Vector3(0.04 * k, -0.04 * k, 0), boots)

	if floats:
		# Schwebende Wesen laufen nach unten in Schwaden aus statt Beine zu
		# haben. Drei sich verjüngende Kästen reichen dafür.
		# Kräftig verjüngen: bei gleicher Breite wirkt das Wesen wie eine
		# Säule, nicht wie etwas, das sich nach unten auflöst.
		var veil := _joint(hips, "veil", Vector3(0, -0.05 * k, 0))
		for i in 4:
			var f := 1.0 - float(i) * 0.24
			_box(veil, Vector3(0.20 * k * f * f * bw, 0.20 * k, 0.24 * k * f * f * bw),
				Vector3(-0.02 * k * i, -0.09 * k - i * 0.17 * k, 0), cloth)

	_build_prop(s, k, trim)

## Kopfaufsatz: Haar, Kapuze, Hut, Helm — plus glühende Augen, wo gewünscht.
func _build_head_extras(head: Node3D, s: Dictionary, k: float, hs: float,
		hair: StandardMaterial3D, cloth: StandardMaterial3D,
		trim: StandardMaterial3D) -> void:
	match String(s.get("hair_style", "short")):
		"braid":
			_box(head, Vector3(0.22 * k * hs, 0.13 * k, 0.23 * k * hs),
				Vector3(-0.01 * k, 0.19 * k * hs, 0), hair)
			_box(head, Vector3(0.10 * k, 0.22 * k, 0.22 * k * hs),
				Vector3(-0.08 * k, 0.10 * k, 0), hair)
			var braid := _joint(head, "braid", Vector3(-0.09 * k, 0.10 * k, 0))
			_box(braid, Vector3(0.07 * k, 0.26 * k, 0.09 * k),
				Vector3(0, -0.13 * k, 0), hair)
		"short":
			_box(head, Vector3(0.22 * k * hs, 0.11 * k, 0.23 * k * hs),
				Vector3(-0.01 * k, 0.20 * k * hs, 0), hair)
		"hood":
			# Kapuze steht vom Kopf ab und wirft ihn in Schatten.
			_box(head, Vector3(0.27 * k * hs, 0.30 * k * hs, 0.28 * k * hs),
				Vector3(-0.04 * k, 0.13 * k * hs, 0), cloth)
			_box(head, Vector3(0.10 * k, 0.20 * k * hs, 0.22 * k * hs),
				Vector3(0.10 * k, 0.11 * k * hs, 0), mat(Color(0.05, 0.04, 0.06)))
		"hat":
			_box(head, Vector3(0.34 * k * hs, 0.04 * k, 0.36 * k * hs),
				Vector3(-0.01 * k, 0.22 * k * hs, 0), cloth)
			for i in 4:
				var f := 1.0 - float(i) * 0.22
				_box(head, Vector3(0.20 * k * hs * f, 0.11 * k, 0.21 * k * hs * f),
					Vector3(-0.01 * k - i * 0.015 * k, (0.28 + i * 0.10) * k * hs, 0), cloth)
		"helm":
			_box(head, Vector3(0.24 * k * hs, 0.16 * k, 0.25 * k * hs),
				Vector3(-0.01 * k, 0.20 * k * hs, 0), trim)
		"none":
			pass
	if s.has("beard"):
		_box(head, Vector3(0.13 * k, 0.16 * k, 0.17 * k),
			Vector3(0.06 * k, 0.02 * k, 0), mat(s["beard"]))
	# Augen: zwei kleine leuchtende Würfel. Bei den meisten Monstern ist das
	# das einzige Gesichtsmerkmal, das bei dieser Größe überhaupt ankommt.
	var eye_col: Color = s.get("eyes", Color(0.10, 0.08, 0.12))
	var glow: float = s.get("eye_glow", 0.0)
	var em := mat(eye_col, 0.6, glow)
	for z in [-0.055, 0.055]:
		_box(head, Vector3(0.03 * k, 0.035 * k, 0.045 * k),
			Vector3(0.10 * k * hs, 0.13 * k * hs, z * k), em)

## Gegenstand in der vorderen Hand (bzw. auf dem Rücken).
func _build_prop(s: Dictionary, k: float, trim: StandardMaterial3D) -> void:
	var kind := String(s.get("prop", "none"))
	if kind == "none" or not joints.has("hand_r"):
		return
	var steel := mat(Color(0.72, 0.76, 0.82), 0.35)
	var wood := mat(Color(0.38, 0.26, 0.15))
	var w := _joint(joints["hand_r"], "weapon", Vector3(0.02 * k, -0.05 * k, 0))
	match kind:
		"sword":
			_box(w, Vector3(0.04 * k, 0.13 * k, 0.04 * k), Vector3(0, -0.06 * k, 0), wood)
			_box(w, Vector3(0.05 * k, 0.03 * k, 0.22 * k), Vector3(0, 0.01 * k, 0), steel)
			_box(w, Vector3(0.035 * k, 0.66 * k, 0.115 * k), Vector3(0, 0.35 * k, 0), steel)
		"staff":
			_box(w, Vector3(0.05 * k, 1.05 * k, 0.05 * k), Vector3(0, 0.35 * k, 0), wood)
			_sphere(w, 0.09 * k, Vector3(0, 0.92 * k, 0), 1.0,
				mat(s.get("gem", Color(0.35, 0.9, 0.45)), 0.4, 1.8))
		"gun":
			_box(w, Vector3(0.30 * k, 0.10 * k, 0.11 * k), Vector3(0.16 * k, 0, 0),
				mat(Color(0.42, 0.44, 0.48), 0.4))
			_box(w, Vector3(0.08 * k, 0.14 * k, 0.09 * k), Vector3(-0.02 * k, -0.06 * k, 0),
				mat(Color(0.24, 0.25, 0.28)))
		"club":
			_box(w, Vector3(0.06 * k, 0.42 * k, 0.06 * k), Vector3(0, 0.18 * k, 0), wood)
			_box(w, Vector3(0.15 * k, 0.24 * k, 0.15 * k), Vector3(0, 0.46 * k, 0), wood)
		"banner":
			_box(w, Vector3(0.04 * k, 1.30 * k, 0.04 * k), Vector3(0, 0.50 * k, 0), wood)
			_box(w, Vector3(0.02 * k, 0.44 * k, 0.34 * k), Vector3(0, 0.92 * k, 0.18 * k),
				mat(s.get("flag", Color(0.62, 0.11, 0.11))))
		"megaphone":
			for i in 4:
				var f := 0.35 + float(i) * 0.22
				_box(w, Vector3(0.09 * k, 0.16 * k * f, 0.16 * k * f),
					Vector3(0.06 * k + i * 0.09 * k, 0.10 * k, 0),
					mat(Color(0.55, 0.54, 0.52), 0.5))
		"sack":
			# Auf dem Rücken statt in der Hand.
			if joints.has("spine"):
				_sphere(joints["spine"], 0.26 * k, Vector3(-0.22 * k, 0.24 * k, 0), 1.0,
					mat(s.get("sackcol", Color(0.5, 0.43, 0.28))))
		"scroll":
			_box(w, Vector3(0.10 * k, 0.30 * k, 0.36 * k), Vector3(0.08 * k, -0.02 * k, 0),
				mat(Color(0.80, 0.76, 0.62)))
			_box(w, Vector3(0.11 * k, 0.09 * k, 0.09 * k), Vector3(0.09 * k, -0.15 * k, 0),
				mat(Color(0.70, 0.13, 0.13), 0.5, 0.5))
		"stack":
			# Schlotbaron: zwei Schornsteine auf dem Rücken.
			if joints.has("spine"):
				for z in [-0.16, 0.10]:
					_box(joints["spine"], Vector3(0.16 * k, 0.95 * k, 0.16 * k),
						Vector3(-0.20 * k, 0.75 * k, z * k), mat(Color(0.26, 0.25, 0.22)))
		"cane":
			_box(w, Vector3(0.04 * k, 0.80 * k, 0.04 * k), Vector3(0, -0.34 * k, 0),
				mat(Color(0.85, 0.68, 0.22), 0.4))
		"horns":
			if joints.has("head"):
				for z in [-0.11, 0.11]:
					var hn := _box(joints["head"], Vector3(0.07 * k, 0.34 * k, 0.07 * k),
						Vector3(-0.02 * k, 0.30 * k, z * k), mat(Color(0.84, 0.80, 0.70)))
					hn.rotation_degrees = Vector3(0, 0, 24 * signf(z))

# --- Sonderformen ------------------------------------------------------------

## Schleim/Maul: eine wabbelige Masse mit Augen. Kein Skelett außer Hüfte und
## Rumpf, damit die Animationstabellen trotzdem greifen.
func build_blob(s: Dictionary) -> void:
	var k: float = s.get("h", 1.0) / 1.70
	var body := mat(s.get("cloth", Color(0.36, 0.5, 0.2)))
	var hips := _joint(self, "hips", Vector3(0, 0.42 * k, 0))
	var spine := _joint(hips, "spine", Vector3(0, 0, 0))
	_sphere(spine, 0.52 * k, Vector3(0, 0, 0), 0.78, body)
	_sphere(spine, 0.34 * k, Vector3(-0.10 * k, 0.26 * k, 0), 0.72,
		mat((s.get("cloth", Color(0.36, 0.5, 0.2)) as Color).lightened(0.14)))
	var head := _joint(spine, "head", Vector3(0.10 * k, 0.18 * k, 0))
	var em := mat(s.get("eyes", Color(0.95, 1.0, 0.75)), 0.5, s.get("eye_glow", 1.2))
	for z in [-0.16, 0.16]:
		_box(head, Vector3(0.08 * k, 0.09 * k, 0.10 * k),
			Vector3(0.30 * k, 0.06 * k, z * k), em)
	if s.get("maw", false):
		_box(spine, Vector3(0.30 * k, 0.26 * k, 0.62 * k), Vector3(0.30 * k, -0.10 * k, 0),
			mat(Color(0.28, 0.12, 0.09)))
		for i in 5:
			_box(spine, Vector3(0.06 * k, 0.10 * k, 0.06 * k),
				Vector3(0.42 * k, 0.02 * k, (-0.22 + i * 0.11) * k),
				mat(Color(0.93, 0.91, 0.82)))
	# Tropfen am unteren Rand
	for i in 5:
		var a := TAU * float(i) / 5.0
		_sphere(spine, 0.09 * k, Vector3(cos(a) * 0.34 * k, -0.34 * k, sin(a) * 0.30 * k),
			1.3, body)

## Vierbeiner.
func build_quadruped(s: Dictionary) -> void:
	var k: float = s.get("h", 1.10) / 1.70
	var fur := mat(s.get("cloth", Color(0.34, 0.26, 0.2)))
	var dark := mat((s.get("cloth", Color(0.34, 0.26, 0.2)) as Color).darkened(0.35))
	var hips := _joint(self, "hips", Vector3(0, 0.62 * k, 0))
	var spine := _joint(hips, "spine", Vector3(0, 0, 0))
	_box(spine, Vector3(0.86 * k, 0.34 * k, 0.34 * k), Vector3(0, 0, 0), fur)
	var head := _joint(spine, "head", Vector3(0.48 * k, 0.14 * k, 0))
	_box(head, Vector3(0.30 * k, 0.26 * k, 0.26 * k), Vector3(0.10 * k, 0, 0), fur)
	_box(head, Vector3(0.22 * k, 0.14 * k, 0.16 * k), Vector3(0.32 * k, -0.05 * k, 0), fur)
	for z in [-0.08, 0.08]:
		_box(head, Vector3(0.08 * k, 0.18 * k, 0.06 * k), Vector3(0.02 * k, 0.20 * k, z * k), dark)
	var em := mat(s.get("eyes", Color(1.0, 0.72, 0.3)), 0.5, s.get("eye_glow", 1.4))
	for z in [-0.10, 0.10]:
		_box(head, Vector3(0.05 * k, 0.05 * k, 0.05 * k), Vector3(0.20 * k, 0.05 * k, z * k), em)
	_box(spine, Vector3(0.16 * k, 0.30 * k, 0.30 * k), Vector3(-0.02 * k, 0.05 * k, 0),
		mat(s.get("trim", Color(0.9, 0.72, 0.25)), 0.4))
	var i := 0
	for x in [0.32, -0.30]:
		for z in [-0.13, 0.13]:
			var tag := "hip_%s" % ("l" if i % 2 == 0 else "r")
			var hp := _joint(spine, tag if not joints.has(tag) else tag + str(i),
				Vector3(x * k, -0.14 * k, z * k))
			_box(hp, Vector3(0.12 * k, 0.44 * k, 0.12 * k), Vector3(0, -0.24 * k, 0), dark)
			i += 1

## Spinnentier: Hinterleib, Vorderkörper, acht Beine, acht Augen.
func build_spider(s: Dictionary) -> void:
	var k: float = s.get("h", 1.9) / 1.70
	var pale := mat(s.get("cloth", Color(0.6, 0.6, 0.66)))
	var dark := mat((s.get("cloth", Color(0.6, 0.6, 0.66)) as Color).darkened(0.5))
	var hips := _joint(self, "hips", Vector3(0, 0.60 * k, 0))
	var spine := _joint(hips, "spine", Vector3(0, 0, 0))
	_sphere(spine, 0.52 * k, Vector3(-0.30 * k, 0.05 * k, 0), 0.86, pale)
	_sphere(spine, 0.32 * k, Vector3(0.30 * k, 0, 0), 0.80, pale)
	var head := _joint(spine, "head", Vector3(0.44 * k, 0.06 * k, 0))
	_sphere(head, 0.20 * k, Vector3(0.06 * k, 0, 0), 0.75, dark)
	var em := mat(s.get("eyes", Color(1.0, 0.2, 0.18)), 0.4, s.get("eye_glow", 2.2))
	for i in 4:
		for row in 2:
			_box(head, Vector3(0.04 * k, 0.04 * k, 0.04 * k),
				Vector3(0.17 * k - row * 0.05 * k, 0.06 * k - row * 0.07 * k,
					(-0.15 + i * 0.10) * k), em)
	for i in 4:
		for side in [-1, 1]:
			var base := _joint(spine, "leg_%d_%d" % [i, side],
				Vector3((0.22 - i * 0.20) * k, 0.05 * k, 0.22 * k * side))
			var up := _box(base, Vector3(0.09 * k, 0.62 * k, 0.09 * k),
				Vector3(0, 0.16 * k, 0.22 * k * side), dark)
			up.rotation_degrees = Vector3(-(38.0 + i * 5.0) * side, 0, 0)
			var lo := _box(base, Vector3(0.07 * k, 0.72 * k, 0.07 * k),
				Vector3(0, -0.22 * k, 0.52 * k * side), dark)
			lo.rotation_degrees = Vector3((22.0 + i * 4.0) * side, 0, 0)

# --- Animationen -------------------------------------------------------------

## Eine Pose ist eine Tabelle Gelenk -> Euler-Winkel in Grad. Fehlende Gelenke
## bleiben in Ruhestellung — deshalb funktionieren dieselben Tabellen auch für
## Figuren, die gar keine Arme haben.
const ANIMS := {
	"idle": {"fps": 10, "loop": true, "frames": 16, "keys": [
		{"t": 0.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "shoulder_l": [-8, 0, 6],
			"elbow_r": [-28, 0, 0], "elbow_l": [-22, 0, 0], "weapon": [-14, 0, 0],
			"head": [2, 0, 0], "braid": [4, 0, 0], "hips": [0, 0, 0]},
		{"t": 0.5, "spine": [2.5, 0, 0], "shoulder_r": [13, 0, -8], "shoulder_l": [-11, 0, 8],
			"elbow_r": [-33, 0, 0], "elbow_l": [-26, 0, 0], "weapon": [-18, 0, 0],
			"head": [4, 3, 0], "braid": [11, 0, 0], "hips": [-1.5, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "shoulder_l": [-8, 0, 6],
			"elbow_r": [-28, 0, 0], "elbow_l": [-22, 0, 0], "weapon": [-14, 0, 0],
			"head": [2, 0, 0], "braid": [4, 0, 0], "hips": [0, 0, 0]},
	]},
	"walk": {"fps": 11, "loop": true, "frames": 16, "keys": [
		{"t": 0.0, "spine": [5, 0, 0], "hip_r": [-24, 0, 0], "knee_r": [8, 0, 0],
			"hip_l": [20, 0, 0], "knee_l": [-32, 0, 0], "shoulder_r": [24, 0, -7],
			"shoulder_l": [-28, 0, 7], "elbow_r": [-36, 0, 0], "elbow_l": [-34, 0, 0],
			"braid": [-10, 0, 0], "weapon": [-22, 0, 0]},
		{"t": 0.25, "spine": [4, 0, 0], "hip_r": [-2, 0, 0], "knee_r": [-10, 0, 0],
			"hip_l": [2, 0, 0], "knee_l": [-16, 0, 0], "shoulder_r": [2, 0, -7],
			"shoulder_l": [-4, 0, 7], "elbow_r": [-30, 0, 0], "elbow_l": [-28, 0, 0],
			"braid": [-4, 0, 0], "weapon": [-18, 0, 0], "hips": [-1, 0, 0]},
		{"t": 0.5, "spine": [5, 0, 0], "hip_r": [20, 0, 0], "knee_r": [-32, 0, 0],
			"hip_l": [-24, 0, 0], "knee_l": [8, 0, 0], "shoulder_r": [-28, 0, -7],
			"shoulder_l": [24, 0, 7], "elbow_r": [-34, 0, 0], "elbow_l": [-36, 0, 0],
			"braid": [-10, 0, 0], "weapon": [-26, 0, 0]},
		{"t": 0.75, "spine": [4, 0, 0], "hip_r": [2, 0, 0], "knee_r": [-16, 0, 0],
			"hip_l": [-2, 0, 0], "knee_l": [-10, 0, 0], "shoulder_r": [-4, 0, -7],
			"shoulder_l": [2, 0, 7], "elbow_r": [-28, 0, 0], "elbow_l": [-30, 0, 0],
			"braid": [-4, 0, 0], "weapon": [-18, 0, 0], "hips": [-1, 0, 0]},
		{"t": 1.0, "spine": [5, 0, 0], "hip_r": [-24, 0, 0], "knee_r": [8, 0, 0],
			"hip_l": [20, 0, 0], "knee_l": [-32, 0, 0], "shoulder_r": [24, 0, -7],
			"shoulder_l": [-28, 0, 7], "elbow_r": [-36, 0, 0], "elbow_l": [-34, 0, 0],
			"braid": [-10, 0, 0], "weapon": [-22, 0, 0]},
	]},
	"run": {"fps": 14, "loop": true, "frames": 16, "keys": [
		{"t": 0.0, "spine": [14, 0, 0], "hip_r": [-42, 0, 0], "knee_r": [22, 0, 0],
			"hip_l": [34, 0, 0], "knee_l": [-58, 0, 0], "shoulder_r": [46, 0, -8],
			"shoulder_l": [-52, 0, 8], "elbow_r": [-64, 0, 0], "elbow_l": [-70, 0, 0],
			"braid": [-24, 0, 0], "head": [-8, 0, 0], "weapon": [-40, 0, 0]},
		{"t": 0.25, "spine": [12, 0, 0], "hip_r": [-6, 0, 0], "knee_r": [-16, 0, 0],
			"hip_l": [4, 0, 0], "knee_l": [-30, 0, 0], "shoulder_r": [6, 0, -8],
			"shoulder_l": [-8, 0, 8], "elbow_r": [-48, 0, 0], "elbow_l": [-52, 0, 0],
			"braid": [-10, 0, 0], "head": [-6, 0, 0], "weapon": [-30, 0, 0]},
		{"t": 0.5, "spine": [14, 0, 0], "hip_r": [34, 0, 0], "knee_r": [-58, 0, 0],
			"hip_l": [-42, 0, 0], "knee_l": [22, 0, 0], "shoulder_r": [-52, 0, -8],
			"shoulder_l": [46, 0, 8], "elbow_r": [-70, 0, 0], "elbow_l": [-64, 0, 0],
			"braid": [-24, 0, 0], "head": [-8, 0, 0], "weapon": [-52, 0, 0]},
		{"t": 0.75, "spine": [12, 0, 0], "hip_r": [4, 0, 0], "knee_r": [-30, 0, 0],
			"hip_l": [-6, 0, 0], "knee_l": [-16, 0, 0], "shoulder_r": [-8, 0, -8],
			"shoulder_l": [6, 0, 8], "elbow_r": [-52, 0, 0], "elbow_l": [-48, 0, 0],
			"braid": [-10, 0, 0], "head": [-6, 0, 0], "weapon": [-30, 0, 0]},
		{"t": 1.0, "spine": [14, 0, 0], "hip_r": [-42, 0, 0], "knee_r": [22, 0, 0],
			"hip_l": [34, 0, 0], "knee_l": [-58, 0, 0], "shoulder_r": [46, 0, -8],
			"shoulder_l": [-52, 0, 8], "elbow_r": [-64, 0, 0], "elbow_l": [-70, 0, 0],
			"braid": [-24, 0, 0], "head": [-8, 0, 0], "weapon": [-40, 0, 0]},
	]},
	"attack": {"fps": 16, "loop": false, "frames": 12, "keys": [
		{"t": 0.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0],
			"weapon": [-14, 0, 0], "hips": [0, 0, 0], "head": [0, 0, 0]},
		{"t": 0.30, "spine": [-16, -14, 0], "shoulder_r": [-118, 0, -20],
			"elbow_r": [-72, 0, 0], "weapon": [-30, 0, 0], "hips": [0, -10, 0],
			"head": [-6, -8, 0], "braid": [-18, 0, 0], "hip_l": [-14, 0, 0]},
		{"t": 0.40, "spine": [-20, -18, 0], "shoulder_r": [-132, 0, -22],
			"elbow_r": [-80, 0, 0], "weapon": [-34, 0, 0], "hips": [0, -13, 0],
			"head": [-8, -10, 0], "braid": [-24, 0, 0], "hip_l": [-16, 0, 0]},
		{"t": 0.55, "spine": [26, 16, 0], "shoulder_r": [66, 0, 4], "elbow_r": [-8, 0, 0],
			"weapon": [8, 0, 0], "hips": [0, 12, 0], "head": [12, 8, 0],
			"braid": [30, 0, 0], "hip_r": [-24, 0, 0], "knee_r": [18, 0, 0]},
		{"t": 0.75, "spine": [16, 10, 0], "shoulder_r": [44, 0, 0], "elbow_r": [-20, 0, 0],
			"weapon": [-2, 0, 0], "hips": [0, 7, 0], "head": [7, 5, 0],
			"braid": [14, 0, 0], "hip_r": [-12, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0],
			"weapon": [-14, 0, 0], "hips": [0, 0, 0], "head": [0, 0, 0]},
	]},
	"hit": {"fps": 16, "loop": false, "frames": 10, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.18, "spine": [-26, 0, 0], "head": [-20, 0, 0], "shoulder_r": [-40, 0, -20],
			"shoulder_l": [34, 0, 20], "elbow_r": [-60, 0, 0], "hip_l": [-20, 0, 0],
			"knee_l": [26, 0, 0], "braid": [-34, 0, 0], "hips": [-8, 0, 0]},
		{"t": 0.55, "spine": [-9, 0, 0], "head": [-7, 0, 0], "shoulder_r": [-6, 0, -10],
			"braid": [-12, 0, 0], "hips": [-3, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0]},
	]},
	"down": {"fps": 12, "loop": false, "frames": 12, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.25, "spine": [-14, 0, 0], "head": [-16, 0, 0], "hip_r": [-16, 0, 0],
			"knee_r": [30, 0, 0], "hips": [-6, 0, 0]},
		{"t": 0.65, "spine": [34, 0, 0], "head": [26, 0, 0], "hip_r": [64, 0, 0],
			"knee_r": [86, 0, 0], "hip_l": [56, 0, 0], "knee_l": [78, 0, 0],
			"shoulder_r": [58, 0, -30], "shoulder_l": [46, 0, 30], "hips": [26, 0, 0],
			"braid": [44, 0, 0]},
		{"t": 1.0, "spine": [52, 0, 0], "head": [34, 0, 0], "hip_r": [88, 0, 0],
			"knee_r": [104, 0, 0], "hip_l": [82, 0, 0], "knee_l": [98, 0, 0],
			"shoulder_r": [72, 0, -36], "shoulder_l": [60, 0, 36], "hips": [62, 0, 0],
			"braid": [58, 0, 0]},
	]},
	"cheer": {"fps": 10, "loop": true, "frames": 12, "keys": [
		{"t": 0.0, "shoulder_r": [-140, 0, -16], "elbow_r": [-24, 0, 0],
			"weapon": [-16, 0, 0], "hips": [0, 0, 0], "spine": [-6, 0, 0]},
		{"t": 0.25, "shoulder_r": [-152, 0, -18], "elbow_r": [-16, 0, 0],
			"weapon": [-8, 0, 0], "hips": [-3, 0, 0], "spine": [-9, 0, 0],
			"knee_r": [-16, 0, 0], "knee_l": [-16, 0, 0], "braid": [16, 0, 0]},
		{"t": 0.5, "shoulder_r": [-140, 0, -16], "elbow_r": [-24, 0, 0],
			"weapon": [-16, 0, 0], "hips": [0, 0, 0], "spine": [-6, 0, 0]},
		{"t": 0.75, "shoulder_r": [-148, 0, -17], "elbow_r": [-19, 0, 0],
			"weapon": [-11, 0, 0], "hips": [-2, 0, 0], "spine": [-8, 0, 0],
			"knee_r": [-11, 0, 0], "knee_l": [-11, 0, 0], "braid": [11, 0, 0]},
		{"t": 1.0, "shoulder_r": [-140, 0, -16], "elbow_r": [-24, 0, 0],
			"weapon": [-16, 0, 0], "hips": [0, 0, 0], "spine": [-6, 0, 0]},
	]},
}

static func frames_of(anim: String) -> int:
	return ANIMS[anim]["frames"]

static func fps_of(anim: String) -> float:
	return float(ANIMS[anim]["fps"])

## Setzt alle Gelenke auf die Pose zum Zeitpunkt des Frames.
func apply(anim: String, frame: int) -> void:
	var a: Dictionary = ANIMS[anim]
	var n: int = a["frames"]
	var t := float(frame % n) / float(n) if a["loop"] \
		else float(mini(frame, n - 1)) / float(n - 1)
	var keys: Array = a["keys"]
	var i := 0
	while i < keys.size() - 2 and float(keys[i + 1]["t"]) < t:
		i += 1
	var k0: Dictionary = keys[i]
	var k1: Dictionary = keys[mini(i + 1, keys.size() - 1)]
	var span: float = maxf(float(k1["t"]) - float(k0["t"]), 0.0001)
	var f := clampf((t - float(k0["t"])) / span, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	for name: String in joints:
		var e0 := _euler(k0.get(name, null))
		var e1 := _euler(k1.get(name, null))
		(joints[name] as Node3D).rotation_degrees = e0.lerp(e1, f)

static func _euler(v) -> Vector3:
	if v == null:
		return Vector3.ZERO
	return Vector3(v[0], v[1], v[2])
