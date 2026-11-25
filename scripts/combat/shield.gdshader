shader_type spatial;
// Burbuja del generador de escudo: brillo cian en el borde, más fuerte al recibir un golpe.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
// Golpe reciente (0 a 1) y cuánto escudo queda (0 a 1).
instance uniform float glow = 0.0;
instance uniform float strength = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = color.rgb;
	ALPHA = clamp((rim * 0.5 + 0.03 + glow * (0.18 + rim * 0.7)) * strength, 0.0, 1.0);
}
