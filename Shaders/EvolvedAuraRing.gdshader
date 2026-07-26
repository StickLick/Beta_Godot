shader_type canvas_item;

uniform float radius = 0.45;
uniform float ring_thickness = 0.06;
uniform float glow_intensity = 0.4;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float dist = distance(UV, vec2(0.5));
    
    // Ring: visible only at radius, transparent inside
    float ring = 1.0 - smoothstep(radius - ring_thickness, radius, dist);
    ring *= smoothstep(radius - ring_thickness * 2.0, radius - ring_thickness, dist);
    
    // Glow on the ring
    float glow = smoothstep(radius - ring_thickness * 3.0, radius - ring_thickness, dist);
    glow *= 1.0 - smoothstep(radius - ring_thickness, radius + ring_thickness, dist);
    glow *= glow_intensity;
    
    COLOR.rgb = tex.rgb;
    COLOR.a = tex.a * clamp(ring + glow, 0.0, 1.0);
}