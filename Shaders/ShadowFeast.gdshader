shader_type canvas_item;

// Все параметры в реальных экранных пикселях
uniform float radius_px = 0.0; 
uniform float softness_px = 10.0;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center_px = vec2(0.0, 0.0); 

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 current_pixel = SCREEN_UV * resolution;
	
	// Расстояние от текущего пикселя до центра зоны
	float dist = distance(current_pixel, center_px);
	
	// Маска: 
	// Внутри (dist < radius_px) -> 0.0 (чисто)
	// Снаружи (dist > radius_px + softness) -> 1.0 (туман)
	float mask = smoothstep(radius_px, radius_px + max(softness_px, 0.1), dist);
	
	// Итоговый цвет
	COLOR = vec4(fog_color.rgb, mask * fog_color.a);
}