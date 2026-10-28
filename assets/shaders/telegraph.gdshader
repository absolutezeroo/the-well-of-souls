shader_type canvas_item;
// A monster's warning, on a square around it, pointing along `aim` (radians):
//   shape 0: a circle (an area skill), 1: a cone (a melee swing), 2: a line (a shot, a dash),
//   3: lanes (a fan or a ring of shots: one line per shot, so the gaps between them read).
// Faint hazard stripes crawl over the zone, a solid rim outlines it, and a stronger fill grows
// from the monster as the attack comes (`progress` 0..1), flashing just before it lands.
// The node is never turned: its pixels are 2x2 art pixels on the world's grid (like the art).

uniform int shape = 0;
uniform float radius = 60.0;
uniform float aim = 0.0;
uniform float half_angle = 0.8;
uniform float line_width = 10.0;
// Lanes: how many, and the fan's width in radians (TAU or more: a full ring).
uniform int lanes = 1;
uniform float spread = 0.0;
// Lanes start this far out (the monster's body).
uniform float inner = 0.0;
// Lanes cut at the first wall (TelegraphView.clip_to_walls): the first `clip_count` lanes each
// end at their own reach (lane_reach[k], lane k counted from the fan's first or the ring's aim);
// 0: every lane `radius` long. A shot stops at a wall: its lane does too (docs/decisions/0008).
uniform int clip_count = 0;
uniform float lane_reach[32];
uniform float progress = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.2, 1.0);
uniform float pixel = 2.0;

varying vec2 world;
varying vec2 origin;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

void fragment() {
	vec2 cell = floor(world / pixel);
	vec2 d = (cell + 0.5) * pixel - origin;
	float c = cos(aim);
	float s = sin(aim);
	vec2 p = vec2(d.x * c + d.y * s, -d.x * s + d.y * c);
	float r = length(p);
	float rim;    // distance to the zone's edge, in world units (negative: outside)
	float depth;  // how far out from the monster, 0..1 (for the growing fill)
	if (shape == 0) {
		rim = radius - r;
		depth = r / radius;
	} else if (shape == 1) {
		float angle = abs(atan(p.y, p.x));
		rim = min(radius - r, (half_angle - angle) * max(r, 1.0));
		depth = r / radius;
	} else if (shape == 2) {
		rim = min(min(radius - p.x, p.x), line_width * 0.5 - abs(p.y));
		depth = p.x / radius;
	} else {
		// The nearest lane to this pixel, then the distance across it.
		float angle = atan(p.y, p.x);
		float lane_angle;
		float index;
		if (spread >= 6.2831) {
			float gap = 6.2831853 / float(lanes);
			float step_index = round(angle / gap);
			lane_angle = step_index * gap;
			index = mod(step_index + float(lanes), float(lanes));
		} else {
			float gap = spread / max(float(lanes - 1), 1.0);
			float first = -spread * 0.5;
			index = clamp(round((angle - first) / max(gap, 0.0001)), 0.0, float(lanes - 1));
			lane_angle = lanes > 1 ? first + index * gap : 0.0;
		}
		float reach = radius;
		int k = int(index + 0.5);
		if (k < clip_count && k < 32) {
			reach = lane_reach[k];
		}
		vec2 lane = vec2(cos(lane_angle), sin(lane_angle));
		float along = dot(p, lane);
		float off = abs(p.x * lane.y - p.y * lane.x);
		rim = min(min(reach - along, along - inner), line_width * 0.5 - off);
		depth = (along - inner) / max(radius - inner, 1.0);
	}
	if (rim < 0.0) {
		discard;
	}
	float stripes = step(0.5, fract((cell.x - cell.y) * pixel / 14.0 - TIME * 1.2));
	float alpha = 0.14 + 0.08 * stripes;
	alpha += step(depth, progress) * (0.18 + 0.12 * progress);
	float edge = step(rim, pixel * 1.5);
	alpha = mix(alpha, 0.85, edge * (0.45 + 0.55 * progress));
	// The last instant: a flash.
	alpha += step(0.85, progress) * 0.25 * step(0.0, sin(TIME * 40.0));
	COLOR = vec4(mix(color.rgb, vec3(1.0, 0.85, 0.8), edge * step(0.5, progress) * 0.4), alpha * color.a);
}
