shader_type canvas_item;
uniform vec4 source_colors[3] : source_color;
uniform vec4 target_colors[3] : source_color;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 painted = pixel.rgb;
	for (int i = 0; i < 3; i++) {
		if (distance(pixel.rgb, source_colors[i].rgb) < 0.015) {
			painted = target_colors[i].rgb;
			break;
		}
	}
	COLOR = vec4(painted, pixel.a) * vertex_tint;
}
