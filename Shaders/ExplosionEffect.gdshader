shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_thickness : hint_range(0.01, 0.5) = 0.08;
uniform vec4 core_color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform vec4 ring_color : source_color = vec4(1.0, 0.3, 0.05, 0.8);
uniform vec4 outer_color : source_color = vec4(1.0, 0.15, 0.0, 0.0);

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // Shockwave ring position (expands outward)
    float ring_pos = progress * 0.7;
    float ring_fade = smoothstep(ring_pos + ring_thickness, ring_pos, dist);
    float ring_inner = smoothstep(ring_pos - ring_thickness * 0.3, ring_pos, dist);
    float ring = ring_fade * (1.0 - ring_inner);
    
    // Core glow (shrinks)
    float core = smoothstep((1.0 - progress) * 0.5, 0.0, dist);
    
    // Outer flash
    float flash = smoothstep(progress * 0.9 + 0.1, progress * 0.5, dist);
    flash *= (1.0 - smoothstep(progress * 0.5, progress * 0.9, dist));
    
    // Distortion ripple
    float ripple = abs(sin(dist * 20.0 - progress * 15.0)) * 0.15;
    ripple *= smoothstep(0.5, 0.0, dist);
    
    vec4 final_color;
    final_color = mix(outer_color, ring_color, ring);
    final_color = mix(final_color, core_color, core * 0.4);
    final_color.a = max(final_color.a, flash * 0.6);
    final_color.a = max(final_color.a, ripple * 0.3);
    
    // Fade out at the very end
    final_color.a *= 1.0 - smoothstep(0.7, 1.0, progress);
    
    COLOR = final_color;
}