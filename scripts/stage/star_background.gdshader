shader_type canvas_item;
// Fondo 2D de estrellas con varias capas que se desplazan a distinta velocidad (parallax, GDD 10.3).

// Desplazamiento de la cámara en píxeles de pantalla.
uniform vec2 offset = vec2(0.0);
uniform vec4 space_color : source_color = vec4(0.012, 0.016, 0.035, 1.0);
uniform vec4 nebula_color : source_color = vec4(0.10, 0.05, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float star_layer(vec2 px, float cell, float density, float size) {
	vec2 g = px / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h > density) {
		return 0.0;
	}
	vec2 pos = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
	float d = length(f - pos * 0.7) * cell;
	float twinkle = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(size, 0.0, d) * twinkle;
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	vec3 col = space_color.rgb;
	float n = noise((px + offset * 0.05) / 420.0) * noise((px + offset * 0.05) / 180.0 + 9.0);
	col += nebula_color.rgb * smoothstep(0.15, 0.6, n) * 0.6;
	col += vec3(0.55, 0.6, 0.8) * star_layer(px + offset * 0.1, 22.0, 0.10, 1.2);
	col += vec3(0.75, 0.8, 1.0) * star_layer(px + offset * 0.25, 46.0, 0.10, 1.6);
	col += vec3(1.0) * star_layer(px + offset * 0.5, 90.0, 0.12, 2.3);
	COLOR = vec4(col, 1.0);
}
