shader_type canvas_item;

uniform float radius = 0.45;
uniform float ring_thickness = 0.002;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float dist = distance(UV, vec2(0.5));
    
    // Razor-thin crisp ring
    float ring = 1.0 - smoothstep(radius - ring_thickness, radius, dist);
    ring *= smoothstep(radius - ring_thickness * 3.0, radius - ring_thickness, dist);
    
    // Strong pulsing inner fill
    float pulse = pow(sin(TIME * 2.0), 2.0) * 0.3 + 0.1;
    float inner = smoothstep(radius - 0.35, radius - ring_thickness * 3.0, dist);
    inner *= 1.0 - smoothstep(radius - ring_thickness * 3.0, radius - ring_thickness, dist);
    inner *= pulse;
    
    COLOR.rgb = tex.rgb;
    COLOR.a = tex.a * clamp(ring + inner, 0.0, 1.0);
}