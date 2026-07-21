shader_type canvas_item;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float color_split : hint_range(0.0, 0.1) = 0.0;

void vertex() {
	if (glitch_strength > 0.0) {
		float slice = floor(VERTEX.y * 0.2);
		float jitter = sin(TIME * 100.0 + slice) * 15.0;
		VERTEX.x += jitter * glitch_strength;
		VERTEX.y += cos(TIME * 50.0 + VERTEX.x) * 2.0 * glitch_strength;
	}
}

void fragment() {
	vec2 uv = UV;
	vec4 tex = texture(TEXTURE, uv);
	float split = color_split + (glitch_strength * 0.03);
	float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	
	vec4 final_color = vec4(r, tex.g, b, tex.a);
	
	if (glitch_strength > 0.1) {
		vec3 c1 = vec3(0.0, 1.0, 1.0); // Cyan
		vec3 c2 = vec3(1.0, 0.0, 1.0); // Magenta
		vec3 flicker = mix(c1, c2, step(0.5, sin(TIME * 120.0)));
		final_color.rgb = mix(final_color.rgb, flicker, glitch_strength * 0.5);
		final_color.rgb *= 1.3;
	}
	COLOR = final_color;
}