shader_type canvas_item;
uniform vec4 stone_tint : source_color = vec4(0.78, 0.85, 0.88, 1.0);
// The remembered equipment keeps its silhouette, carved from the same stone as the hero.
void fragment() {
	vec4 picture = COLOR;
	float stone = dot(picture.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(stone_tint.rgb * stone, picture.a);
}
