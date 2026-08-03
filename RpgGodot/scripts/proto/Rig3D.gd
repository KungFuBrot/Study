class_name Rig3D
extends Node3D
## PROTOTYP: Figur als echtes 3D-Skelett, gedacht zum Herunterrendern auf
## Pixel-Art (Verfahren von Motion Twin/Dead Cells: in 3D modellieren und
## animieren, dann sehr klein und ohne Kantenglättung rendern).
##
## Warum 3D statt weiter zeichnen: Bewegung kommt aus Gelenkwinkeln statt aus
## gerechneter Verformung, und das Licht wandert über echte Oberflächen. Beides
## ist der Grund, warum solche Figuren „leben" — nicht der Detailgrad.
##
## Aufbau: KEIN Skinning. Jeder Körperteil ist ein starres Mesh an einem
## Gelenk-Node. Das reicht für diesen Look vollkommen (Dead Cells' Modelle sind
## bewusst grob) und spart die gesamte Gewichtungs-Arbeit.

# Maße in Metern. Die Figur ist 1.70 hoch bei 0.28 Kopfhöhe — knapp sechs
# Kopfhöhen, dasselbe Erwachsenenmaß wie im 2D-Rig.
const H_TOTAL := 1.70
const Y_HIP := 0.88
const Y_CHEST := 1.35
const Y_NECK := 1.42

var joints := {}   # Name -> Node3D (Drehpunkt)
var parts := {}    # Name -> MeshInstance3D

# --- Aufbau -----------------------------------------------------------------

static func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	# Kein spiegelnder Glanz: der soll aus dem Licht kommen, nicht aus dem
	# Material — sonst frisst er beim Herunterrechnen die Form auf.
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, name: String, size: Vector3, offset: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	parts[name] = mi
	return mi

func _joint(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	joints[name] = n
	return n

## Baut die Heldin: rote Wams, brauner Hose, blondem Zopf, Schwert.
func build_serena() -> void:
	var skin := _mat(Color(0.93, 0.74, 0.58))
	var cloth := _mat(Color(0.62, 0.13, 0.16))
	var trim := _mat(Color(0.85, 0.76, 0.54))
	var pants := _mat(Color(0.31, 0.21, 0.14))
	var boot := _mat(Color(0.19, 0.13, 0.09))
	var hair := _mat(Color(0.80, 0.60, 0.20))
	var steel := _mat(Color(0.72, 0.76, 0.82), 0.35)
	var grip := _mat(Color(0.26, 0.17, 0.10))

	var hips := _joint(self, "hips", Vector3(0, Y_HIP, 0))
	_box(hips, "pelvis", Vector3(0.20, 0.16, 0.30), Vector3(0, -0.02, 0), pants)

	# Rumpf: unten Taille, oben Schultern — zwei Kästen statt einem, damit die
	# Silhouette eine Kerbe bekommt.
	var spine := _joint(hips, "spine", Vector3(0, 0.06, 0))
	_box(spine, "waist", Vector3(0.19, 0.20, 0.27), Vector3(0, 0.10, 0), cloth)
	_box(spine, "chest", Vector3(0.23, 0.24, 0.34), Vector3(0, 0.32, 0), cloth)
	_box(spine, "belt", Vector3(0.21, 0.05, 0.29), Vector3(0, 0.00, 0), trim)

	var neck := _joint(spine, "neck", Vector3(0, Y_NECK - Y_HIP - 0.06, 0))
	_box(neck, "neck", Vector3(0.09, 0.06, 0.10), Vector3(0, 0.02, 0), skin)
	var head := _joint(neck, "head", Vector3(0, 0.06, 0))
	_box(head, "skull", Vector3(0.20, 0.24, 0.21), Vector3(0.01, 0.12, 0), skin)
	# Haarkappe und Zopf: der Zopf hängt an einem eigenen Gelenk und schwingt
	# in der Animation nach.
	_box(head, "hair", Vector3(0.22, 0.13, 0.23), Vector3(-0.01, 0.19, 0), hair)
	_box(head, "hair_back", Vector3(0.10, 0.22, 0.22), Vector3(-0.08, 0.10, 0), hair)
	var braid := _joint(head, "braid", Vector3(-0.09, 0.10, 0))
	_box(braid, "braid", Vector3(0.07, 0.26, 0.09), Vector3(0, -0.13, 0), hair)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var sh := _joint(spine, "shoulder_" + tag,
			Vector3(0, 0.40, 0.15 * side))
		_box(sh, "pauldron_" + tag, Vector3(0.13, 0.11, 0.12), Vector3(0, 0.01, 0), trim)
		_box(sh, "upperarm_" + tag, Vector3(0.09, 0.24, 0.09), Vector3(0, -0.13, 0), cloth)
		var elb := _joint(sh, "elbow_" + tag, Vector3(0, -0.25, 0))
		_box(elb, "forearm_" + tag, Vector3(0.08, 0.22, 0.08), Vector3(0, -0.11, 0), skin)
		var hand := _joint(elb, "hand_" + tag, Vector3(0, -0.23, 0))
		_box(hand, "hand_" + tag, Vector3(0.08, 0.08, 0.08), Vector3(0, -0.03, 0), skin)

		var hp := _joint(hips, "hip_" + tag, Vector3(0, -0.08, 0.09 * side))
		_box(hp, "thigh_" + tag, Vector3(0.12, 0.30, 0.12), Vector3(0, -0.16, 0), pants)
		var knee := _joint(hp, "knee_" + tag, Vector3(0, -0.32, 0))
		_box(knee, "shin_" + tag, Vector3(0.10, 0.28, 0.10), Vector3(0, -0.15, 0), pants)
		var ankle := _joint(knee, "ankle_" + tag, Vector3(0, -0.30, 0))
		_box(ankle, "foot_" + tag, Vector3(0.19, 0.08, 0.11), Vector3(0.04, -0.04, 0), boot)

	# Schwert in der rechten Hand (die zur Kamera zeigende Seite).
	var wpn := _joint(joints["hand_r"], "weapon", Vector3(0.02, -0.05, 0))
	_box(wpn, "grip", Vector3(0.04, 0.13, 0.04), Vector3(0, -0.06, 0), grip)
	_box(wpn, "guard", Vector3(0.05, 0.03, 0.22), Vector3(0, 0.01, 0), steel)
	# Klinge breit genug, dass sie beim Herunterrechnen nicht auf ein Pixel
	# zusammenfällt — bei 48 px Bildbreite sind 0.07 m schlicht unsichtbar.
	_box(wpn, "blade", Vector3(0.035, 0.66, 0.115), Vector3(0, 0.35, 0), steel)

# --- Posen ------------------------------------------------------------------

## Eine Pose ist eine Tabelle Gelenk -> Euler-Winkel in Grad. Fehlende Gelenke
## bleiben in Ruhestellung. Genau wie im 2D-Rig kostet eine neue Animation
## damit ein paar Zeilen Tabelle.
const ANIMS := {
	"idle": {"fps": 10, "loop": true, "keys": [
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
	"run": {"fps": 14, "loop": true, "keys": [
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
	# Schlag von oben: ausholen über die Schulter, durchziehen, nachfedern.
	"attack": {"fps": 16, "loop": false, "keys": [
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
	# Treffer: wird zurückgerissen, fängt sich.
	"hit": {"fps": 16, "loop": false, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.18, "spine": [-26, 0, 0], "head": [-20, 0, 0], "shoulder_r": [-40, 0, -20],
			"shoulder_l": [34, 0, 20], "elbow_r": [-60, 0, 0], "hip_l": [-20, 0, 0],
			"knee_l": [26, 0, 0], "braid": [-34, 0, 0], "hips": [-8, 0, 0]},
		{"t": 0.55, "spine": [-9, 0, 0], "head": [-7, 0, 0], "shoulder_r": [-6, 0, -10],
			"braid": [-12, 0, 0], "hips": [-3, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0]},
	]},
	# Zusammenbrechen: einknicken, nach vorn kippen.
	"down": {"fps": 12, "loop": false, "keys": [
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
}

static func frames_of(anim: String) -> int:
	# Sechzehn Bilder je Zyklus: mehr als das 2D-Rig, weil 3D-Zwischenbilder
	# nichts kosten — genau das ist der Gewinn dieses Verfahrens.
	return 16 if ANIMS[anim]["loop"] else 12

## Setzt alle Gelenke auf die Pose zum Zeitpunkt t (0..1).
func apply(anim: String, frame: int) -> void:
	var a: Dictionary = ANIMS[anim]
	var n := frames_of(anim)
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
