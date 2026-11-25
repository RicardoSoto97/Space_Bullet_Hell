shader_type spatial;
// Superficie de los cuerpos del mapa estelar: manchas de ruido (rocosos, satélites, asteroides)
// o bandas onduladas (gaseosos). Colores planos, sin texturas (GDD 10.2).
render_mode diffuse_lambert, specular_disabled;

uniform vec3 color_a : source_color = vec3(0.6);
uniform vec3 color_b : source_color = vec3(0.3);
uniform float gas = 0.0;
uniform float seed = 0.0;

varying vec3 obj_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + seed * 0.173);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj_pos = normalize(VERTEX);
}

void fragment() {
	vec3 p = obj_pos;
	float t;
	if (gas > 0.5) {
		t = 0.5 + 0.5 * sin(p.y * 13.0 + fbm(p * 3.0 + seed) * 4.0);
		t = smoothstep(0.15, 0.85, t);
	} else {
		t = smoothstep(0.38, 0.68, fbm(p * 3.2 + seed));
	}
	ALBEDO = mix(color_a, color_b, t);
	ROUGHNESS = 0.9;
}
