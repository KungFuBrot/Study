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

## Sich verjüngender Zylinder — die Grundform für Gliedmaßen. Acht Segmente
## sind grob genug, dass die Facetten sichtbar bleiben, und rund genug, dass
## die Silhouette nicht mehr kastig wirkt. Genau das war die Grenze der
## reinen Quader-Bauweise.
func _cyl(parent: Node3D, r_top: float, r_bot: float, height: float,
		offset: Vector3, m: StandardMaterial3D, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = height
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = offset
	parent.add_child(mi)
	return mi

## Keil — für Schulterstücke, Kapuzenspitzen, Hutkegel.
func _prism(parent: Node3D, size: Vector3, offset: Vector3, lean: float,
		m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	pm.left_to_right = lean
	mi.mesh = pm
	mi.material_override = m
	mi.position = offset
	parent.add_child(mi)
	return mi

## Freie Röhre entlang eines Streckenzugs mit eigenem Radius je Stützpunkt.
## Damit bekommt ein Glied ein echtes PROFIL — Muskelbauch in der Mitte,
## schmales Gelenk am Ende — statt eines linearen Kegels. Genau daran hing der
## Baukasten-Eindruck: Grundkörper haben keine Verläufe.
func _tube(parent: Node3D, pts: Array, radii: Array, m: StandardMaterial3D,
		sides := 8) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in pts.size():
		var p: Vector3 = pts[i]
		# Richtung aus Vorgänger/Nachfolger — an den Enden nur einseitig.
		var dir: Vector3
		if i == 0:
			dir = (pts[1] - p).normalized()
		elif i == pts.size() - 1:
			dir = (p - pts[i - 1]).normalized()
		else:
			dir = ((pts[i + 1] - pts[i - 1]) as Vector3).normalized()
		# Beliebige Senkrechte zur Richtung aufspannen.
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var a := dir.cross(up).normalized()
		var b := dir.cross(a).normalized()
		var ring := []
		for s in sides:
			var ang := TAU * float(s) / float(sides)
			ring.append(p + (a * cos(ang) + b * sin(ang)) * float(radii[i]))
		rings.append(ring)
	for i in rings.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var v0: Vector3 = rings[i][s]
			var v1: Vector3 = rings[i][s2]
			var v2: Vector3 = rings[i + 1][s2]
			var v3: Vector3 = rings[i + 1][s]
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)
	# Deckel, damit die Röhre nicht hohl wirkt, wenn man ins Ende schaut.
	for e in [0, rings.size() - 1]:
		var c: Vector3 = pts[e]
		for s in sides:
			var s2 := (s + 1) % sides
			if e == 0:
				st.add_vertex(c); st.add_vertex(rings[e][s2]); st.add_vertex(rings[e][s])
			else:
				st.add_vertex(c); st.add_vertex(rings[e][s]); st.add_vertex(rings[e][s2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	parent.add_child(mi)
	return mi

## Senkrechtes Glied mit Profil: der Radius folgt `prof` über die Länge.
func _limb_tube(parent: Node3D, length: float, r: float, prof: Array,
		m: StandardMaterial3D) -> MeshInstance3D:
	var pts := []
	var radii := []
	for i in prof.size():
		var t := float(i) / float(prof.size() - 1)
		pts.append(Vector3(0, -length * t, 0))
		radii.append(r * float(prof[i]))
	return _tube(parent, pts, radii, m)

## Umhang: eine gewölbte Fläche, die von den Schultern nach unten fällt und
## sich nach hinten wegbiegt. Grundkörper können das nicht.
func _cloak(parent: Node3D, w: float, h: float, sag: float,
		m: StandardMaterial3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 7
	var rows := 6
	var grid := []
	for r in rows + 1:
		var tv := float(r) / float(rows)
		var row := []
		for c in cols + 1:
			var tu := float(c) / float(cols) * 2.0 - 1.0
			# Nach unten breiter, nach hinten gewölbt, Ränder fallen ab.
			var wide: float = w * (0.62 + 0.55 * tv)
			row.append(Vector3(-sag * tv * tv - absf(tu) * w * 0.22,
				-h * tv, tu * wide))
		grid.append(row)
	for r in rows:
		for c in cols:
			var v0: Vector3 = grid[r][c]
			var v1: Vector3 = grid[r][c + 1]
			var v2: Vector3 = grid[r + 1][c + 1]
			var v3: Vector3 = grid[r + 1][c]
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
			st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
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
	# Erst diese vier Regler erzeugen wirklich verschiedene Silhouetten. Nur
	# an der Gesamthöhe zu drehen reicht nicht: 1.62 gegen 1.70 sieht niemand.
	var sw: float = s.get("shoulder", 1.0)        # Schulterbreite, unabhängig von der Masse
	var al: float = s.get("arm", 1.0)             # Armlänge
	var ll: float = s.get("leg", 1.0)             # Beinlänge
	var tl: float = s.get("torso", 1.0)           # Rumpflänge
	var sink: float = s.get("sink", 0.0)          # Kopf sinkt zwischen die Schultern
	var skin := mat(s.get("skin", Color(0.9, 0.74, 0.58)))
	var cloth := mat(s.get("cloth", Color(0.5, 0.2, 0.2)))
	var trim := mat(s.get("trim", Color(0.8, 0.72, 0.5)))
	var legs := mat(s.get("legs", Color(0.3, 0.22, 0.15)))
	var boots := mat(s.get("boots", Color(0.18, 0.13, 0.1)))
	var hair := mat(s.get("hair", Color(0.5, 0.35, 0.15)))
	var floats: bool = s.get("float", false)

	var y_hip := 0.88 * k * ll
	var hips := _joint(self, "hips", Vector3(0, y_hip, 0))
	_box(hips, Vector3(0.20 * k * bw, 0.16 * k, 0.30 * k * bw),
		Vector3(0, -0.02 * k, 0), legs if not floats else cloth)

	var spine := _joint(hips, "spine", Vector3(0, 0.06 * k, 0))
	# Taille rund und verjüngt, Brust kantig — so bekommt der Rumpf eine
	# Kerbe statt eines durchgehenden Quaders.
	_cyl(spine, 0.105 * k * bw, 0.088 * k * bw, 0.22 * k * tl,
		Vector3(0, 0.10 * k * tl, 0), cloth)
	_box(spine, Vector3(0.23 * k * bw * sw, 0.24 * k * tl, 0.34 * k * bw * sw),
		Vector3(0, 0.32 * k * tl, 0), cloth)
	_box(spine, Vector3(0.21 * k * bw, 0.05 * k, 0.29 * k * bw),
		Vector3(0, 0.0, 0), trim)
	# Feindetail, das erst bei der doppelten Auflösung ankommt: Gürtelschnalle,
	# Brustriemen, Kragen. Jedes davon ist nur ein Kasten, aber es sind genau
	# diese Kanten, an denen das Licht bricht.
	_box(spine, Vector3(0.06 * k, 0.06 * k, 0.07 * k),
		Vector3(0.10 * k * bw, 0.0, 0), mat(Color(0.86, 0.72, 0.32), 0.4))
	_box(spine, Vector3(0.05 * k, 0.30 * k, 0.05 * k),
		Vector3(0.11 * k * bw, 0.22 * k, 0.09 * k * bw), trim)
	_box(spine, Vector3(0.20 * k * bw, 0.05 * k, 0.31 * k * bw),
		Vector3(-0.01 * k, 0.44 * k, 0), trim)

	var neck := _joint(spine, "neck", Vector3(0, (0.48 * tl - sink * 0.10) * k, 0))
	_cyl(neck, 0.045 * k, 0.05 * k, 0.08 * k, Vector3(0, 0.02 * k, 0), skin, 6)
	var head := _joint(neck, "head", Vector3(0, 0.06 * k, 0))
	# Rundes Schädeldach auf kantigem Kiefer: der Kopf war als reiner Würfel
	# das Auffälligste an der Kastenoptik.
	if s.get("boxhead", false):
		_box(head, Vector3(0.20 * k * hs, 0.24 * k * hs, 0.21 * k * hs),
			Vector3(0.01 * k, 0.12 * k * hs, 0), skin)
	else:
		_sphere(head, 0.115 * k * hs, Vector3(0.01 * k, 0.155 * k * hs, 0), 1.05, skin)
		_box(head, Vector3(0.17 * k * hs, 0.11 * k * hs, 0.17 * k * hs),
			Vector3(0.02 * k, 0.07 * k * hs, 0), skin)
	_build_head_extras(head, s, k, hs, hair, cloth, trim)
	# Umhang: fällt von den Schultern, wölbt sich nach hinten weg. Hängt am
	# Rumpf-Gelenk, schwingt also beim Lehnen mit.
	if s.has("cloak"):
		var cl := _joint(spine, "cloak", Vector3(-0.06 * k, 0.42 * k, 0))
		_cloak(cl, 0.20 * k * bw, 0.78 * k, 0.16 * k, mat(s["cloak"]))

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		var sh := _joint(spine, "shoulder_" + tag,
			Vector3(0, 0.40 * k * tl, 0.15 * k * bw * sw * side))
		# Schulterstück als Keil statt als Klotz — gibt der Schulter eine
		# abfallende Kante statt einer rechtwinkligen Ecke.
		_prism(sh, Vector3(0.14 * k * bw, 0.12 * k, 0.13 * k * bw),
			Vector3(0, 0.02 * k, 0), 0.5, trim)
		# Gliedmaßen mit Profil statt linearem Kegel: der Oberarm hat einen
		# Muskelbauch, der Ellenbogen zieht sich zusammen.
		_limb_tube(sh, 0.25 * k * al, 0.055 * k * bw, [0.86, 1.0, 0.94, 0.76], cloth)
		var elb := _joint(sh, "elbow_" + tag, Vector3(0, -0.25 * k * al, 0))
		_limb_tube(elb, 0.23 * k * al, 0.044 * k * bw, [0.84, 0.98, 0.86, 0.66], skin)
		var hand := _joint(elb, "hand_" + tag, Vector3(0, -0.23 * k * al, 0))
		_sphere(hand, 0.048 * k, Vector3(0, -0.03 * k, 0), 1.1, skin)

		if floats:
			continue
		var hp := _joint(hips, "hip_" + tag, Vector3(0, -0.08 * k, 0.09 * k * bw * side))
		# Oberschenkel kräftig oben, schmal am Knie; Wade mit Bauch.
		_limb_tube(hp, 0.32 * k * ll, 0.072 * k * bw, [0.92, 1.0, 0.88, 0.70], legs)
		var knee := _joint(hp, "knee_" + tag, Vector3(0, -0.32 * k * ll, 0))
		_limb_tube(knee, 0.30 * k * ll, 0.056 * k * bw, [0.80, 1.0, 0.82, 0.58], legs)
		# Knieschutz — bricht das lange Bein in zwei lesbare Abschnitte.
		_box(knee, Vector3(0.12 * k * bw, 0.07 * k, 0.13 * k * bw),
			Vector3(0.02 * k, 0.0, 0), boots)
		var ankle := _joint(knee, "ankle_" + tag, Vector3(0, -0.30 * k * ll, 0))
		_box(ankle, Vector3(0.19 * k, 0.08 * k, 0.11 * k), Vector3(0.04 * k, -0.04 * k, 0), boots)
		# Stiefelschaft mit Umschlag
		_box(ankle, Vector3(0.12 * k * bw, 0.16 * k, 0.13 * k * bw),
			Vector3(0, 0.08 * k, 0), boots)
		_box(ankle, Vector3(0.14 * k * bw, 0.05 * k, 0.15 * k * bw),
			Vector3(0, 0.17 * k, 0), trim)

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
	# Figuren, die man in jeder Szene sieht, bekommen eigene Geometrie oben
	# drauf — die gemeinsame Bauform trägt nur bis zu einem gewissen Punkt.
	match String(s.get("detail", "")):
		"serena": _detail_serena(s, k, bw)
		"milo": _detail_milo(s, k, bw)
		"rax": _detail_rax(s, k, bw)

# --- Figurenspezifische Geometrie -------------------------------------------

## Helen: Beintaschen über den Schenkeln, gewölbter Brustpanzer, Armschienen,
## geflochtener Zopf mit Band, Schwert mit Hohlkehle und Knauf.
func _detail_serena(s: Dictionary, k: float, bw: float) -> void:
	var cloth := mat(s["cloth"])
	var trim := mat(s["trim"])
	var leather := mat(Color(0.34, 0.22, 0.14))
	var steel := mat(Color(0.74, 0.78, 0.84), 0.32)
	var hair := mat(s["hair"])
	var spine: Node3D = joints["spine"]
	# Gewölbter Brustpanzer: eine Röhre quer über die Brust, nach vorn gebogen.
	_tube(spine, [Vector3(0.02 * k, 0.26 * k, -0.16 * k),
			Vector3(0.09 * k, 0.31 * k, 0), Vector3(0.02 * k, 0.26 * k, 0.16 * k)],
		[0.045 * k, 0.075 * k, 0.045 * k], trim, 8)
	# Beintaschen: vier schmale Lappen, die über den Schenkeln hängen.
	for i in 4:
		var z := (-0.15 + i * 0.10) * k * bw
		_tube(joints["hips"], [Vector3(0.06 * k, -0.06 * k, z),
				Vector3(0.07 * k, -0.20 * k, z * 1.1),
				Vector3(0.05 * k, -0.31 * k, z * 1.15)],
			[0.040 * k, 0.036 * k, 0.022 * k], cloth, 6)
	# Armschienen
	for tag in ["l", "r"]:
		_tube(joints["elbow_" + tag], [Vector3(0, -0.06 * k, 0), Vector3(0, -0.19 * k, 0)],
			[0.050 * k * bw, 0.043 * k * bw], leather, 8)
	# Zopf: drei Abschnitte, unten mit Band.
	if joints.has("braid"):
		var b: Node3D = joints["braid"]
		_tube(b, [Vector3(0, -0.02 * k, 0), Vector3(-0.02 * k, -0.12 * k, 0),
				Vector3(-0.01 * k, -0.22 * k, 0), Vector3(0.01 * k, -0.30 * k, 0)],
			[0.042 * k, 0.048 * k, 0.036 * k, 0.016 * k], hair, 7)
		_tube(b, [Vector3(-0.005 * k, -0.25 * k, 0), Vector3(0.005 * k, -0.28 * k, 0)],
			[0.030 * k, 0.030 * k], trim, 6)
	# Schwert: Hohlkehle in der Klinge, Knauf am Griffende.
	if joints.has("weapon"):
		var w: Node3D = joints["weapon"]
		_box(w, Vector3(0.012 * k, 0.58 * k, 0.030 * k), Vector3(0.019 * k, 0.35 * k, 0),
			mat(Color(0.52, 0.56, 0.64), 0.45))
		_sphere(w, 0.035 * k, Vector3(0, -0.13 * k, 0), 0.9, steel)

## Janosch: Faltenwurf auf der Robe, weite Ärmelglocken, geknickte Hutspitze,
## Gürteltaschen.
func _detail_milo(s: Dictionary, k: float, bw: float) -> void:
	var robe := mat((s["cloth"] as Color).darkened(0.22))
	var trim := mat(s["trim"])
	var leather := mat(Color(0.32, 0.24, 0.16))
	var spine: Node3D = joints["spine"]
	# Falten: vier Grate, die von der Brust nach unten auseinanderlaufen.
	for i in 4:
		var z := (-0.12 + i * 0.08) * k * bw
		_tube(spine, [Vector3(0.09 * k, 0.30 * k, z * 0.7),
				Vector3(0.10 * k, 0.10 * k, z),
				Vector3(0.08 * k, -0.10 * k, z * 1.25)],
			[0.016 * k, 0.024 * k, 0.020 * k], robe, 5)
	# Ärmelglocken: weiten sich zum Handgelenk hin.
	for tag in ["l", "r"]:
		_tube(joints["elbow_" + tag], [Vector3(0, -0.02 * k, 0), Vector3(0, -0.13 * k, 0),
				Vector3(0, -0.21 * k, 0)],
			[0.048 * k * bw, 0.062 * k * bw, 0.082 * k * bw], mat(s["cloth"]), 8)
		_tube(joints["elbow_" + tag], [Vector3(0, -0.19 * k, 0), Vector3(0, -0.22 * k, 0)],
			[0.084 * k * bw, 0.084 * k * bw], trim, 8)
	# Hutspitze knickt nach hinten weg statt gerade zu stehen.
	if joints.has("head"):
		_tube(joints["head"], [Vector3(-0.01 * k, 0.30 * k, 0),
				Vector3(-0.08 * k, 0.44 * k, 0), Vector3(-0.22 * k, 0.50 * k, 0),
				Vector3(-0.34 * k, 0.44 * k, 0)],
			[0.072 * k, 0.050 * k, 0.028 * k, 0.010 * k], mat(s["cloth"]), 7)
	# Gürteltaschen
	for z in [-0.10, 0.12]:
		_sphere(spine, 0.042 * k, Vector3(0.07 * k, -0.02 * k, z * k), 1.2, leather)

## Wally: Nieten, Kolbenarme, Auspuffrohre auf dem Rücken, Schulterpanzer.
func _detail_rax(s: Dictionary, k: float, bw: float) -> void:
	var shell := mat(s["cloth"], 0.55)
	var dark := mat(s["trim"], 0.6)
	var pipe := mat(Color(0.26, 0.27, 0.31), 0.5)
	var hot := mat(Color(1.0, 0.55, 0.16), 0.4, 1.6)
	var spine: Node3D = joints["spine"]
	# Nietenreihen an der Brustplatte.
	for i in 5:
		for z in [-0.14, 0.14]:
			_sphere(spine, 0.014 * k, Vector3(0.11 * k * bw,
				(0.22 + i * 0.055) * k, z * k * bw), 1.0, dark)
	# Auspuffrohre auf dem Rücken, leicht nach außen geneigt.
	for z in [-0.10, 0.10]:
		_tube(spine, [Vector3(-0.13 * k, 0.18 * k, z * k),
				Vector3(-0.16 * k, 0.40 * k, z * k * 1.3),
				Vector3(-0.18 * k, 0.54 * k, z * k * 1.5)],
			[0.032 * k, 0.028 * k, 0.036 * k], pipe, 7)
	# Kolben in den Armen: schmales Innenrohr über dem Ellenbogen.
	for tag in ["l", "r"]:
		_tube(joints["shoulder_" + tag], [Vector3(0, -0.19 * k, 0), Vector3(0, -0.26 * k, 0)],
			[0.026 * k, 0.026 * k], pipe, 6)
		_tube(joints["elbow_" + tag], [Vector3(0, -0.02 * k, 0), Vector3(0, -0.07 * k, 0)],
			[0.048 * k * bw, 0.044 * k * bw], dark, 8)
	# Schulterpanzer als gewölbte Kappe.
	for tag in ["l", "r"]:
		var side := -1.0 if tag == "l" else 1.0
		_tube(joints["shoulder_" + tag], [Vector3(0.05 * k, 0.03 * k, 0),
				Vector3(0, 0.05 * k, 0.02 * k * side), Vector3(-0.05 * k, 0.03 * k, 0)],
			[0.052 * k * bw, 0.070 * k * bw, 0.052 * k * bw], shell, 8)
	# Glühender Spalt am Rumpf
	_box(spine, Vector3(0.02 * k, 0.10 * k, 0.14 * k),
		Vector3(0.115 * k * bw, 0.14 * k, 0), hot)

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
			# Kapuze als nach hinten geneigte Spitze statt als Kasten — der
			# Klotz auf dem runden Kopf war das letzte, was nach Baukasten aussah.
			_tube(head, [
					Vector3(0.02 * k, 0.02 * k * hs, 0),
					Vector3(-0.02 * k, 0.16 * k * hs, 0),
					Vector3(-0.09 * k, 0.28 * k * hs, 0),
					Vector3(-0.17 * k, 0.34 * k * hs, 0)],
				[0.150 * k * hs, 0.135 * k * hs, 0.075 * k * hs, 0.012 * k * hs],
				cloth, 8)
			# Schattenhöhle: der Kopf verschwindet darin bis auf die Augen.
			_sphere(head, 0.085 * k * hs, Vector3(0.07 * k, 0.13 * k * hs, 0), 1.0,
				mat(Color(0.05, 0.04, 0.06)))
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
	# Gesicht. Bei doppelter Auflösung reichen die Pixel für Brauenwulst und
	# Nase — vorher waren zwei Augenwürfel alles, was ankam.
	var eye_col: Color = s.get("eyes", Color(0.10, 0.08, 0.12))
	var glow: float = s.get("eye_glow", 0.0)
	var em := mat(eye_col, 0.6, glow)
	var skin_c: Color = s.get("skin", Color(0.9, 0.74, 0.58))
	for z in [-0.055, 0.055]:
		_box(head, Vector3(0.03 * k, 0.035 * k, 0.045 * k),
			Vector3(0.10 * k * hs, 0.13 * k * hs, z * k), em)
	if not s.has("faceless"):
		# Brauenwulst wirft einen Schatten auf die Augen — das gibt dem
		# Gesicht Tiefe statt aufgemalter Punkte.
		_box(head, Vector3(0.035 * k, 0.03 * k, 0.17 * k * hs),
			Vector3(0.095 * k * hs, 0.175 * k * hs, 0), mat(skin_c.darkened(0.18)))
		_box(head, Vector3(0.04 * k, 0.05 * k, 0.04 * k),
			Vector3(0.11 * k * hs, 0.09 * k * hs, 0), mat(skin_c.lightened(0.08)))
		_box(head, Vector3(0.02 * k, 0.02 * k, 0.07 * k),
			Vector3(0.10 * k * hs, 0.035 * k * hs, 0), mat(skin_c.darkened(0.30)))

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
	# Beine einzeln benannt, damit die Vierbeiner-Tabelle sie ansprechen kann.
	var names := [['leg_fl', 0.32, -0.13], ['leg_fr', 0.32, 0.13],
		['leg_bl', -0.30, -0.13], ['leg_br', -0.30, 0.13]]
	for e: Array in names:
		var hp := _joint(spine, String(e[0]), Vector3(float(e[1]) * k, -0.14 * k, float(e[2]) * k))
		_cyl(hp, 0.055 * k, 0.040 * k, 0.46 * k, Vector3(0, -0.24 * k, 0), dark)

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
	"idle": {"fps": 10, "loop": true, "frames": 24, "keys": [
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
	"walk": {"fps": 11, "loop": true, "frames": 24, "keys": [
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
	"run": {"fps": 14, "loop": true, "frames": 24, "keys": [
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
	"attack": {"fps": 16, "loop": false, "frames": 18, "keys": [
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
	"hit": {"fps": 16, "loop": false, "frames": 14, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.18, "spine": [-26, 0, 0], "head": [-20, 0, 0], "shoulder_r": [-40, 0, -20],
			"shoulder_l": [34, 0, 20], "elbow_r": [-60, 0, 0], "hip_l": [-20, 0, 0],
			"knee_l": [26, 0, 0], "braid": [-34, 0, 0], "hips": [-8, 0, 0]},
		{"t": 0.55, "spine": [-9, 0, 0], "head": [-7, 0, 0], "shoulder_r": [-6, 0, -10],
			"braid": [-12, 0, 0], "hips": [-3, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0]},
	]},
	"down": {"fps": 12, "loop": false, "frames": 18, "keys": [
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
	# Rückhand: der zweite Schlag der Kombo, aus der Gegenrichtung.
	"attack2": {"fps": 16, "loop": false, "frames": 18, "keys": [
		{"t": 0.0, "spine": [16, 10, 0], "shoulder_r": [44, 0, 0], "elbow_r": [-20, 0, 0],
			"weapon": [-2, 0, 0], "hips": [0, 7, 0]},
		{"t": 0.28, "spine": [22, 20, 0], "shoulder_r": [78, 0, 14], "elbow_r": [-14, 0, 0],
			"weapon": [26, 0, 0], "hips": [0, 16, 0], "head": [10, 12, 0],
			"braid": [26, 0, 0]},
		{"t": 0.48, "spine": [-14, -20, 0], "shoulder_r": [-46, 0, -26],
			"elbow_r": [-34, 0, 0], "weapon": [-40, 0, 0], "hips": [0, -16, 0],
			"head": [-8, -12, 0], "braid": [-30, 0, 0], "hip_l": [-20, 0, 0],
			"knee_l": [16, 0, 0]},
		{"t": 0.72, "spine": [-6, -10, 0], "shoulder_r": [-18, 0, -14],
			"elbow_r": [-30, 0, 0], "weapon": [-26, 0, 0], "hips": [0, -7, 0],
			"braid": [-12, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0],
			"weapon": [-14, 0, 0], "hips": [0, 0, 0]},
	]},
	# Zaubern: sammeln, aufrichten, Stab nach vorn entladen.
	"cast": {"fps": 12, "loop": false, "frames": 20, "keys": [
		{"t": 0.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0]},
		{"t": 0.26, "spine": [12, 0, 0], "shoulder_r": [-24, 0, -14],
			"elbow_r": [-58, 0, 0], "shoulder_l": [-20, 0, 14], "elbow_l": [-54, 0, 0],
			"head": [8, 0, 0], "hip_r": [-12, 0, 0], "knee_r": [20, 0, 0],
			"weapon": [-30, 0, 0]},
		{"t": 0.46, "spine": [16, 0, 0], "shoulder_r": [-34, 0, -16],
			"elbow_r": [-66, 0, 0], "shoulder_l": [-28, 0, 16], "elbow_l": [-60, 0, 0],
			"head": [12, 0, 0], "hip_r": [-16, 0, 0], "knee_r": [26, 0, 0],
			"weapon": [-38, 0, 0], "braid": [-16, 0, 0]},
		{"t": 0.62, "spine": [-18, 0, 0], "shoulder_r": [-128, 0, -8],
			"elbow_r": [-8, 0, 0], "shoulder_l": [-40, 0, 20], "head": [-16, 0, 0],
			"weapon": [12, 0, 0], "braid": [34, 0, 0], "hips": [-6, 0, 0]},
		{"t": 0.82, "spine": [-8, 0, 0], "shoulder_r": [-96, 0, -8],
			"elbow_r": [-16, 0, 0], "head": [-8, 0, 0], "weapon": [4, 0, 0],
			"braid": [16, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0], "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0],
			"weapon": [-14, 0, 0]},
	]},
	# Zielen und schießen: Arm hoch, kurzer Rückstoß, halten.
	"aim": {"fps": 14, "loop": false, "frames": 14, "keys": [
		{"t": 0.0, "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0]},
		{"t": 0.30, "shoulder_r": [-84, 0, -4], "elbow_r": [-6, 0, 0],
			"spine": [-4, -8, 0], "head": [0, -6, 0], "weapon": [0, 0, 0]},
		{"t": 0.46, "shoulder_r": [-84, 0, -4], "elbow_r": [-6, 0, 0],
			"spine": [-4, -8, 0], "head": [0, -6, 0]},
		{"t": 0.56, "shoulder_r": [-70, 0, -4], "elbow_r": [-18, 0, 0],
			"spine": [-12, -8, 0], "hips": [-5, 0, 0], "head": [-6, -6, 0]},
		{"t": 0.75, "shoulder_r": [-82, 0, -4], "elbow_r": [-8, 0, 0],
			"spine": [-5, -8, 0]},
		{"t": 1.0, "shoulder_r": [10, 0, -6], "elbow_r": [-28, 0, 0]},
	]},
	# Decken: klein machen, Waffe quer vor den Körper.
	"block": {"fps": 12, "loop": true, "frames": 14, "keys": [
		{"t": 0.0, "spine": [16, -6, 0], "shoulder_r": [-52, 0, -34],
			"elbow_r": [-84, 0, 0], "shoulder_l": [-30, 0, 30], "elbow_l": [-70, 0, 0],
			"weapon": [64, 0, 0], "head": [10, 0, 0], "hip_r": [-22, 0, 0],
			"knee_r": [34, 0, 0], "hip_l": [-14, 0, 0], "knee_l": [26, 0, 0],
			"hips": [8, 0, 0]},
		{"t": 0.5, "spine": [18, -6, 0], "shoulder_r": [-56, 0, -36],
			"elbow_r": [-88, 0, 0], "shoulder_l": [-33, 0, 32], "elbow_l": [-73, 0, 0],
			"weapon": [68, 0, 0], "head": [12, 0, 0], "hip_r": [-24, 0, 0],
			"knee_r": [37, 0, 0], "hip_l": [-16, 0, 0], "knee_l": [29, 0, 0],
			"hips": [10, 0, 0]},
		{"t": 1.0, "spine": [16, -6, 0], "shoulder_r": [-52, 0, -34],
			"elbow_r": [-84, 0, 0], "shoulder_l": [-30, 0, 30], "elbow_l": [-70, 0, 0],
			"weapon": [64, 0, 0], "head": [10, 0, 0], "hip_r": [-22, 0, 0],
			"knee_r": [34, 0, 0], "hip_l": [-14, 0, 0], "knee_l": [26, 0, 0],
			"hips": [8, 0, 0]},
	]},
	# Drohen: aufrichten, vorlehnen, wieder sinken.
	"taunt": {"fps": 10, "loop": false, "frames": 18, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.30, "spine": [-16, 0, 0], "head": [-14, 0, 0],
			"shoulder_r": [-30, 0, -24], "shoulder_l": [-26, 0, 24],
			"elbow_r": [-46, 0, 0], "elbow_l": [-42, 0, 0], "hips": [-8, 0, 0]},
		{"t": 0.55, "spine": [14, 0, 0], "head": [16, 0, 0],
			"shoulder_r": [16, 0, -14], "shoulder_l": [12, 0, 14],
			"elbow_r": [-24, 0, 0], "elbow_l": [-22, 0, 0], "hips": [8, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0]},
	]},
	# Brüllen: weit zurückbäumen, Kopf hoch, dann vorschnellen.
	"roar": {"fps": 11, "loop": false, "frames": 20, "keys": [
		{"t": 0.0, "spine": [0, 0, 0]},
		{"t": 0.28, "spine": [-24, 0, 0], "head": [-30, 0, 0],
			"shoulder_r": [-58, 0, -40], "shoulder_l": [-54, 0, 40],
			"elbow_r": [-52, 0, 0], "elbow_l": [-48, 0, 0], "hips": [-12, 0, 0],
			"hip_r": [-14, 0, 0], "hip_l": [-14, 0, 0]},
		{"t": 0.52, "spine": [-28, 0, 0], "head": [-36, 0, 0],
			"shoulder_r": [-66, 0, -46], "shoulder_l": [-62, 0, 46],
			"elbow_r": [-56, 0, 0], "elbow_l": [-52, 0, 0], "hips": [-14, 0, 0]},
		{"t": 0.72, "spine": [22, 0, 0], "head": [20, 0, 0],
			"shoulder_r": [40, 0, -10], "shoulder_l": [36, 0, 10],
			"elbow_r": [-18, 0, 0], "elbow_l": [-16, 0, 0], "hips": [14, 0, 0],
			"hip_r": [-20, 0, 0], "knee_r": [26, 0, 0]},
		{"t": 1.0, "spine": [0, 0, 0]},
	]},
	"cheer": {"fps": 10, "loop": true, "frames": 18, "keys": [
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

## Eigene Tabellen je Bauform. Ein Schleim hat keine Schultern und eine Spinne
## keine Beine im menschlichen Sinn — die gemeinsame Tabelle greift bei ihnen
## nur zur Hälfte. Was hier steht, überschreibt sie.
const FORM_ANIMS := {
	"blob": {
		# Wabern ist reines Stauchen: der Körper zieht sich zusammen und
		# quillt wieder auseinander.
		"idle": {"fps": 9, "loop": true, "frames": 20, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0], "head": [0, 0, 0]},
			{"t": 0.35, "spine": [0, 0, 0, 1.10, 0.86, 1.08], "head": [-6, 0, 0]},
			{"t": 0.70, "spine": [0, 0, 0, 0.93, 1.14, 0.95], "head": [5, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0], "head": [0, 0, 0]},
		]},
		# Zusammenziehen, dann nach vorn schnellen und breit aufklatschen.
		"attack": {"fps": 14, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0]},
			{"t": 0.26, "spine": [0, 0, 0, 0.80, 1.30, 0.82], "hips": [0, 0, 0],
				"head": [-16, 0, 0]},
			{"t": 0.44, "spine": [0, 0, 0, 1.34, 0.70, 1.28], "hips": [16, 0, 0],
				"head": [22, 0, 0]},
			{"t": 0.66, "spine": [0, 0, 0, 0.94, 1.10, 0.96], "hips": [6, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0], "hips": [0, 0, 0]},
		]},
		"hit": {"fps": 16, "loop": false, "frames": 14, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0]},
			{"t": 0.18, "spine": [0, 0, 0, 1.28, 0.72, 1.24], "hips": [-14, 0, 0]},
			{"t": 0.52, "spine": [0, 0, 0, 0.90, 1.16, 0.92], "hips": [-5, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0], "hips": [0, 0, 0]},
		]},
		# Zerfließen statt Umfallen.
		"down": {"fps": 11, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0]},
			{"t": 0.22, "spine": [0, 0, 0, 0.88, 1.18, 0.90], "head": [-10, 0, 0]},
			{"t": 0.60, "spine": [0, 0, 0, 1.40, 0.46, 1.34], "head": [18, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.62, 0.22, 1.54], "head": [26, 0, 0]},
		]},
		"taunt": {"fps": 10, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0]},
			{"t": 0.34, "spine": [0, 0, 0, 0.84, 1.26, 0.86], "head": [-14, 0, 0]},
			{"t": 0.62, "spine": [0, 0, 0, 1.14, 0.90, 1.12], "head": [12, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0], "head": [0, 0, 0]},
		]},
	},
	"quad": {
		# Vierbeiner: Beine im Kreuzgang, Kopf senkt und hebt sich.
		"idle": {"fps": 9, "loop": true, "frames": 20, "keys": [
			{"t": 0.0, "spine": [0, 0, 0], "head": [0, 0, 0]},
			{"t": 0.5, "spine": [2, 0, 0], "head": [-5, 4, 0],
				"leg_fl": [6, 0, 0], "leg_br": [-6, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0], "head": [0, 0, 0]},
		]},
		# Zuschnappen: ducken, vorschnellen, Kopf reißt hoch.
		"attack": {"fps": 15, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0], "head": [0, 0, 0]},
			{"t": 0.26, "spine": [10, 0, 0], "head": [16, 0, 0],
				"leg_fl": [-26, 0, 0], "leg_fr": [-26, 0, 0]},
			{"t": 0.46, "spine": [-16, 0, 0], "head": [-30, 0, 0], "hips": [-10, 0, 0],
				"leg_fl": [34, 0, 0], "leg_fr": [34, 0, 0],
				"leg_bl": [-22, 0, 0], "leg_br": [-22, 0, 0]},
			{"t": 0.70, "spine": [6, 0, 0], "head": [10, 0, 0], "hips": [4, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0], "head": [0, 0, 0], "hips": [0, 0, 0]},
		]},
		"hit": {"fps": 16, "loop": false, "frames": 14, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.18, "spine": [-18, 0, 0], "head": [-24, 0, 0], "hips": [-12, 0, 0],
				"leg_fl": [24, 0, 0], "leg_fr": [24, 0, 0]},
			{"t": 0.55, "spine": [-6, 0, 0], "head": [-8, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0]},
		]},
		"down": {"fps": 11, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.30, "spine": [-12, 0, 0], "head": [-18, 0, 0]},
			{"t": 0.70, "spine": [0, 0, 46], "head": [10, 0, 30], "hips": [0, 0, 40],
				"leg_fl": [40, 0, 0], "leg_fr": [40, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 74], "head": [14, 0, 50], "hips": [0, 0, 68],
				"leg_fl": [56, 0, 0], "leg_fr": [56, 0, 0]},
		]},
		"taunt": {"fps": 10, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.35, "spine": [-14, 0, 0], "head": [-22, 0, 0], "hips": [-8, 0, 0]},
			{"t": 0.65, "spine": [8, 0, 0], "head": [14, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0], "head": [0, 0, 0]},
		]},
	},
	"spider": {
		# Beine tasten abwechselnd — vier Paare, gegenläufig.
		"idle": {"fps": 9, "loop": true, "frames": 24, "keys": [
			{"t": 0.0, "leg_0_-1": [0, 0, 0], "leg_1_1": [0, 0, 0],
				"leg_2_-1": [0, 0, 0], "leg_3_1": [0, 0, 0], "spine": [0, 0, 0]},
			{"t": 0.5, "leg_0_-1": [12, 0, 0], "leg_1_1": [-10, 0, 0],
				"leg_2_-1": [10, 0, 0], "leg_3_1": [-12, 0, 0], "spine": [3, 0, 0],
				"head": [-5, 0, 0]},
			{"t": 1.0, "leg_0_-1": [0, 0, 0], "leg_1_1": [0, 0, 0],
				"leg_2_-1": [0, 0, 0], "leg_3_1": [0, 0, 0], "spine": [0, 0, 0]},
		]},
		# Aufbäumen auf den Hinterbeinen, dann zustoßen.
		"attack": {"fps": 14, "loop": false, "frames": 20, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.30, "spine": [-24, 0, 0], "head": [-20, 0, 0], "hips": [-16, 0, 0],
				"leg_0_-1": [-34, 0, 0], "leg_0_1": [-34, 0, 0],
				"leg_1_-1": [-22, 0, 0], "leg_1_1": [-22, 0, 0]},
			{"t": 0.52, "spine": [22, 0, 0], "head": [26, 0, 0], "hips": [14, 0, 0],
				"leg_0_-1": [40, 0, 0], "leg_0_1": [40, 0, 0],
				"leg_1_-1": [26, 0, 0], "leg_1_1": [26, 0, 0]},
			{"t": 0.76, "spine": [6, 0, 0], "head": [8, 0, 0], "hips": [4, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0], "head": [0, 0, 0], "hips": [0, 0, 0]},
		]},
		"hit": {"fps": 16, "loop": false, "frames": 14, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.18, "spine": [-20, 0, 0], "hips": [-14, 0, 0],
				"leg_0_-1": [26, 0, 0], "leg_0_1": [26, 0, 0],
				"leg_3_-1": [-20, 0, 0], "leg_3_1": [-20, 0, 0]},
			{"t": 0.55, "spine": [-6, 0, 0], "hips": [-4, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0]},
		]},
		# Beine ziehen sich ein, der Leib sackt ab.
		"down": {"fps": 11, "loop": false, "frames": 18, "keys": [
			{"t": 0.0, "spine": [0, 0, 0, 1.0, 1.0, 1.0]},
			{"t": 0.30, "spine": [-14, 0, 0, 1.0, 1.0, 1.0],
				"leg_0_-1": [-30, 0, 0], "leg_0_1": [-30, 0, 0]},
			{"t": 0.70, "spine": [0, 0, 0, 1.10, 0.62, 1.08], "hips": [10, 0, 0],
				"leg_0_-1": [64, 0, 0], "leg_0_1": [64, 0, 0],
				"leg_1_-1": [58, 0, 0], "leg_1_1": [58, 0, 0],
				"leg_2_-1": [52, 0, 0], "leg_2_1": [52, 0, 0],
				"leg_3_-1": [46, 0, 0], "leg_3_1": [46, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0, 1.16, 0.40, 1.14], "hips": [16, 0, 0],
				"leg_0_-1": [86, 0, 0], "leg_0_1": [86, 0, 0],
				"leg_1_-1": [80, 0, 0], "leg_1_1": [80, 0, 0],
				"leg_2_-1": [74, 0, 0], "leg_2_1": [74, 0, 0],
				"leg_3_-1": [68, 0, 0], "leg_3_1": [68, 0, 0]},
		]},
		"roar": {"fps": 10, "loop": false, "frames": 20, "keys": [
			{"t": 0.0, "spine": [0, 0, 0]},
			{"t": 0.34, "spine": [-30, 0, 0], "head": [-34, 0, 0], "hips": [-20, 0, 0],
				"leg_0_-1": [-44, 0, 0], "leg_0_1": [-44, 0, 0],
				"leg_1_-1": [-30, 0, 0], "leg_1_1": [-30, 0, 0]},
			{"t": 0.62, "spine": [-26, 0, 0], "head": [-30, 0, 0], "hips": [-18, 0, 0]},
			{"t": 0.82, "spine": [16, 0, 0], "head": [18, 0, 0], "hips": [10, 0, 0]},
			{"t": 1.0, "spine": [0, 0, 0], "head": [0, 0, 0], "hips": [0, 0, 0]},
		]},
	},
}

## Aktive Bauform — bestimmt, welche Tabelle bei `apply` gilt.
var form := "human"

static func table(form_name: String, anim: String) -> Dictionary:
	var t: Dictionary = FORM_ANIMS.get(form_name, {})
	if t.has(anim):
		return t[anim]
	return ANIMS.get(anim, ANIMS["idle"])

static func frames_of(anim: String, form_name := "human") -> int:
	return table(form_name, anim)["frames"]

static func fps_of(anim: String) -> float:
	return float(ANIMS[anim]["fps"])

## Setzt alle Gelenke auf die Pose zum Zeitpunkt des Frames.
func apply(anim: String, frame: int) -> void:
	var a: Dictionary = table(form, anim)
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
		var v0 = k0.get(name, null)
		var v1 = k1.get(name, null)
		var n3 := joints[name] as Node3D
		n3.rotation_degrees = _euler(v0).lerp(_euler(v1), f)
		# Einträge mit sechs Zahlen tragen hinten eine Skalierung. Kreaturen
		# ohne Skelett — Schleim, Schwaden — bewegen sich fast nur darüber.
		n3.scale = _scale(v0).lerp(_scale(v1), f)

static func _euler(v) -> Vector3:
	if v == null:
		return Vector3.ZERO
	return Vector3(v[0], v[1], v[2])

static func _scale(v) -> Vector3:
	if v == null or (v as Array).size() < 6:
		return Vector3.ONE
	return Vector3(v[3], v[4], v[5])
