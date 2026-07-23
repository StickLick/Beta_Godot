shader_type canvas_item;

uniform float radius = 0.45;
uniform float softness = 0.06;
uniform float glow_intensity = 0.4;

void fragment() {
    // 1. Исходный цвет текстуры (GradientTexture2D с собственным альфа-каналом)
    vec4 tex = texture(TEXTURE, UV);
    
    // 2. Радиальное расстояние от центра UV (0.5, 0.5)
    float dist = distance(UV, vec2(0.5));
    
    // 3. Круговая маска: 1.0 внутри круга, 0.0 снаружи, smoothstep на границе
    float mask = 1.0 - smoothstep(radius - softness, radius, dist);
    
    // 4. Свечение на краю круга (тонкая полоска)
    float rim = smoothstep(radius - softness * 2.0, radius - softness, dist);
    rim *= 1.0 - smoothstep(radius - softness, radius, dist);
    rim *= glow_intensity;
    rim *= tex.a;  // свечение только там, где есть текстура
    
    // 5. Итоговый цвет
    COLOR.rgb = tex.rgb;                           // исходный цвет текстуры
    COLOR.a = tex.a * clamp(mask + rim, 0.0, 1.0); // альфа = текстура × (маска + свечение)
}