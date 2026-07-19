shader_type canvas_item;

uniform float vision_range = 0.0; 
uniform float softness = 0.01;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// Вычисляем соотношение сторон (ширина / высота)
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	
	// Центрируем UV
	vec2 uv = SCREEN_UV - vec2(0.5);
	
	// Корректируем X-координату, чтобы получить круг, а не овал
	uv.x *= aspect;
	
	float dist = length(uv);
	
	// Эффект пульсации (только если vision_range > 0, т.е. во время Пира)
	float pulse = 0.0;
	if (vision_range > 0.01) {
		pulse = sin(TIME * 1.5) * 0.005;
	}
	
	float final_vision = vision_range + pulse;
	float s = max(softness, 0.001);
	
	// Создаем маску круга
	float mask = smoothstep(final_vision, final_vision + s, dist);
	
	COLOR = vec4(fog_color.rgb, mask * fog_color.a);
}