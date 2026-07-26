shader_type canvas_item;

uniform float radius = 0.45;
uniform float ring_thickness = 0.02;
uniform float glow_intensity = 0.3;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float dist = distance(UV, vec2(0.5));
    
    // Thin outer ring
    float ring = 1.0 - smoothstep(radius - ring_thickness, radius, dist);
    ring *= smoothstep(radius - ring_thickness * 3.0, radius - ring_thickness, dist);
    
    // Glow outside ring
    float glow = smoothstep(radius, radius + ring_thickness * 4.0, dist);
    glow *= 1.0 - smoothstep(radius + ring_thickness * 4.0, radius + ring_thickness * 8.0, dist);
    glow *= glow_intensity * 0.3;
    
    // Subtle inner fill - barely visible, just to show aura is active
    float inner = smoothstep(radius - 0.35, radius - ring_thickness, dist);
    inner *= 1.0 - smoothstep(radius - ring_thickness, radius, dist);
    inner *= 0.04;
    
    COLOR.rgb = tex.rgb;
    COLOR.a = tex.a * clamp(ring + glow + inner, 0.0, 1.0);
}