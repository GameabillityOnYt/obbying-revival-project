shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float angle_degrees : hint_range(-360.0, 360.0) = 0.0;

void fragment() {
    // 1. Convert degrees to radians
    float angle_rad = radians(angle_degrees);
    
    // 2. Center UV coordinates to (0,0) before rotation
    vec2 centered_uv = UV - vec2(0.5);
    
    // 3. Apply 2D Rotation Matrix
    float cos_a = cos(angle_rad);
    float sin_a = sin(angle_rad);
    vec2 rotated_uv = vec2(
        centered_uv.x * cos_a - centered_uv.y * sin_a,
        centered_uv.x * sin_a + centered_uv.y * cos_a
    );
    
    // 4. Shift UV back to [0, 1] range
    rotated_uv += vec2(0.5);
    
    // 5. Sample texture & apply rotated gradient
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 gradient = mix(color_top, color_bottom, clamp(rotated_uv.y, 0.0, 1.0));
    
    COLOR = tex_color * gradient;
}