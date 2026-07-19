extends SceneTree
## Montage- und Validator-Check für die AW-Rigs: rendert jede Animation als
## Frame-Streifen (4x vergrößert) und prüft jede Frame-Alpha-Maske auf
## Zusammenhang (1 Teil = nichts schwebt). Aufruf:
##   godot --headless --path RpgAnotherWorld -s <dieses Skript>

const OUT := "C:/Education/ClaudeSession/_assets_tmp/check/aw/"
const SCALE := 4

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var specs: Array = [
		["serena", ["idle", "run", "attack"]],
		["milo", ["idle", "run", "cast"]],
		["rax", ["idle", "run", "aim"]],
		["schlammschleim", ["idle"]],
		["qualmgeist", ["idle"]],
		["muellgnom", ["idle"]],
		["boss", ["idle"]],
	]
	var bad := 0
	for spec: Array in specs:
		var id: String = spec[0]
		for anim: String in spec[1]:
			var rig: Dictionary = AwRigs._rig(id)
			var n: int = AwRigs.aw_anim_frames(id, anim)
			var size: Vector2i = rig["size"]
			var strip := Image.create((size.x * SCALE + 2) * n, size.y * SCALE + 2,
				false, Image.FORMAT_RGBA8)
			strip.fill(Color(0.13, 0.15, 0.18))
			for f in n:
				var img: Image = AwRigs.bake(rig, anim, f)
				var parts: int = AwRigs.count_parts(img)
				if parts != 1:
					print("WARN %s/%s f%d: %d Teile" % [id, anim, f, parts])
					bad += 1
				var big := img.duplicate()
				big.resize(size.x * SCALE, size.y * SCALE, Image.INTERPOLATE_NEAREST)
				strip.blend_rect(big, Rect2i(0, 0, big.get_width(), big.get_height()),
					Vector2i(f * (size.x * SCALE + 2) + 1, 1))
			strip.save_png(OUT + "%s_%s.png" % [id, anim])
	print("FERTIG bad=%d" % bad)
	quit()
