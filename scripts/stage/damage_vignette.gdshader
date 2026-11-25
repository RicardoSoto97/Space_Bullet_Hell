shader_type canvas_item;
// Borde rojo de la pantalla: aparece al recibir daño y late con el casco bajo.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.08, 1.0);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.7, 1.0);
	float edge = smoothstep(0.42, 0.95, length(d));
	COLOR = vec4(tint.rgb, edge * intensity);
}
