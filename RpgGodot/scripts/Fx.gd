class_name Fx
## Gemeinsame HD-2D-Bildeffekte im Octopath-Stil: Tilt-Shift-Tiefenunschärfe
## als Screen-Space-Shader sowie weiche 2D-Punktlichter für Laternen,
## Fackeln und Kristalle. Alles prozedural, keine Assets.

# Blur-Stärke wächst quadratisch mit dem Abstand zum Fokusband — oben (fern)
# stärker als unten (nah), wie eine Miniatur-Diorama-Aufnahme.
const TILT_SHADER_CODE := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float top_blur = 3.0;
uniform float bottom_blur = 2.2;
uniform float focus_center = 0.5;
uniform float focus_width = 0.18;

void fragment() {
	float d = abs(SCREEN_UV.y - focus_center) - focus_width;
	float t = clamp(d / 0.35, 0.0, 1.0);
	t *= t;
	float radius = t * (SCREEN_UV.y < focus_center ? top_blur : bottom_blur);
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	const vec2 taps[12] = {
		vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457),
		vec2(-0.203, 0.621), vec2(0.962, -0.195), vec2(0.473, -0.480),
		vec2(0.519, 0.767), vec2(0.185, -0.893), vec2(0.507, 0.064),
		vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598)
	};
	vec4 col = texture(screen_tex, SCREEN_UV);
	for (int i = 0; i < 12; i++) {
		col += texture(screen_tex, SCREEN_UV + taps[i] * px);
	}
	COLOR = col / 13.0;
}
"

static var _tilt_shader: Shader
static var _light_tex: ImageTexture

## Vollbild-Rechteck mit Tiefenunschärfe; als erstes Kind der UI-CanvasLayer
## einhängen, damit HUD und Textboxen scharf bleiben.
static func tilt_shift(top := 3.0, bottom := 2.2, center := 0.5, width := 0.18) -> ColorRect:
	if _tilt_shader == null:
		_tilt_shader = Shader.new()
		_tilt_shader.code = TILT_SHADER_CODE
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _tilt_shader
	mat.set_shader_parameter("top_blur", top)
	mat.set_shader_parameter("bottom_blur", bottom)
	mat.set_shader_parameter("focus_center", center)
	mat.set_shader_parameter("focus_width", width)
	rect.material = mat
	return rect

# Wasser-Shimmer: helle Wellenlinien wandern in Weltkoordinaten über alle
# Wasserkacheln hinweg (nicht pro Kachel wiederholt), plus leichtes Wogen.
const WATER_SHADER_CODE := "
shader_type canvas_item;
varying vec2 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float w = sin(world_pos.x * 0.13 + TIME * 1.1)
			+ sin(world_pos.y * 0.19 - TIME * 0.8)
			+ sin((world_pos.x + world_pos.y) * 0.09 + TIME * 0.6);
	w /= 3.0;
	float crest = smoothstep(0.55, 1.0, w);
	float trough = smoothstep(0.55, 1.0, -w);
	col.rgb += crest * vec3(0.16, 0.20, 0.24) * col.a;
	col.rgb -= trough * vec3(0.05, 0.07, 0.09) * col.a;
	COLOR = col;
}
"

static var _water_shader: Shader
static var _water_mat: ShaderMaterial

## Gemeinsames Wasser-Material (einmalig erzeugt) für alle Wasserkacheln.
static func water_material() -> ShaderMaterial:
	if _water_mat == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER_CODE
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = _water_shader
	return _water_mat

## Weiche radiale Falloff-Textur für PointLight2D (smoothstep, 128 px).
static func light_texture() -> Texture2D:
	if _light_tex != null:
		return _light_tex
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = v * v * (3.0 - 2.0 * v)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	_light_tex = ImageTexture.create_from_image(img)
	return _light_tex

## radius = Weltpixel bis zum Lichtrand.
static func point_light(color: Color, radius: float, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 64.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l

## Unruhiges Fackelflackern. Erst aufrufen, wenn das Licht im Baum hängt.
static func flicker(l: PointLight2D, base_energy: float) -> void:
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", base_energy * (0.78 + randf() * 0.12), 0.09 + randf() * 0.08)
	tw.tween_property(l, "energy", base_energy * (1.08 + randf() * 0.14), 0.11 + randf() * 0.09)
	tw.tween_property(l, "energy", base_energy * 0.92, 0.08 + randf() * 0.06)

## Ruhiges An- und Abschwellen, z. B. für Kristalle.
static func pulse(l: PointLight2D, base_energy: float, period := 1.6) -> void:
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", base_energy * 1.25, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "energy", base_energy * 0.8, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
