// Underwater caustics — animated bright ribbons of light playing over the map.
// ADDITIVE: bright caustic bands add light (no darkening of the map below),
// so they read clearly even on a dark ocean. The characteristic thin ribbons
// come from the absolute-difference of two flowing noise fields.
//
// Craft notes (why it looks like water and not a grid):
//   * QUINTIC interpolation (smootherstep) — C2 continuous, so the value-noise
//     lattice doesn't leave axis-aligned creases.
//   * FBM (a few rotated octaves) — breaks the single-lattice regularity into
//     organic detail so ribbons don't kink along grid lines.
//   * DOMAIN WARP — the sample point is pushed by a slow low-freq flow, so the
//     ribbons swim like light through moving water instead of sliding rigidly.
//   * SOFT ribbon edges (smoothstep, not a hard pow) — adjacent ribbons blend
//     rather than ending in sharp edges that visibly clip as they move.
//
// Tunables (from sidecar `underwater_caustics` config block):
//   intensity (0.0-1.5) — brightness of the ribbons
//   speed     (0.0-3.0) — flow speed
//   tint      — color of the light (cool blue-white reads as water)

shader_type canvas_item;
render_mode blend_add;

uniform float intensity : hint_range(0.0, 1.5) = 0.45;
uniform float speed     : hint_range(0.0, 3.0) = 0.35;
uniform vec4  tint      : source_color = vec4(0.55, 0.80, 1.00, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic smootherstep (Perlin's improved fade) — removes the axis-aligned
	// creases that plain cubic value-noise leaves at cell boundaries.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal noise: a few octaves, each rotated so their lattices don't align —
// organic ribbons that don't snap to a grid.
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.6;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 3; i++) {
		v += amp * noise(p);
		p = rot * p * 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// Lower frequency = larger, calmer ribbons that read as water without
	// competing with the facility for attention.
	vec2 uv = UV * 4.0;
	float t = TIME * speed;
	// Domain warp: displace the sample point by a slow low-frequency flow so the
	// caustics swim organically instead of the two layers sliding rigidly past
	// each other (which is what made ribbons look like they clipped).
	vec2 warp = vec2(
		fbm(uv * 0.5 + vec2(t * 0.20, 1.7)),
		fbm(uv * 0.5 + vec2(-1.3, t * 0.20)));
	uv += (warp - 0.5) * 1.6;
	float n1 = fbm(uv + vec2(t, t * 0.7));
	float n2 = fbm(uv * 1.3 + vec2(-t * 0.5, t * 0.6));
	// Thin ribbons where the two fields meet. smoothstep gives SOFT edges so
	// adjacent ribbons blend instead of ending in the sharp, non-aligning edges
	// seen before.
	float ribbon = 1.0 - smoothstep(0.0, 0.28, abs(n1 - n2));
	float caustic = ribbon * ribbon;  // gentle sharpen, still soft-edged
	COLOR = vec4(tint.rgb * caustic * intensity, 1.0);
}
