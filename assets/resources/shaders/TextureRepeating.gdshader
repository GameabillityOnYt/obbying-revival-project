shader_type spatial;

uniform vec3 base_color: source_color = vec3(0.0,0.0,0.0);
uniform sampler2D albedo_texture : source_color, repeat_enable;
uniform vec2 tiling_scale = vec2(1.0, 1.0); // 1 stud per 1 unit
uniform float sharpness : hint_range(0.0, 50.0) = 10.0;
uniform float transparency: hint_range(0.0, 1.0, 0.01) = 0;
uniform bool use_overlay_mode = false;

varying vec3 scale;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
    scale = vec3(
        length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),
        length(MODEL_MATRIX[2].xyz)
    );
	
    // center shift fix for it to be like in roblox
    local_pos = (VERTEX + vec3(0.5)) * scale;
    local_normal = abs(NORMAL);
}

void fragment() {
    vec2 uv_x = local_pos.zy * tiling_scale;
    vec2 uv_y = local_pos.xz * tiling_scale;
    vec2 uv_z = local_pos.xy * tiling_scale;

    vec4 tex_x = texture(albedo_texture, uv_x);
    vec4 tex_y = texture(albedo_texture, uv_y);
    vec4 tex_z = texture(albedo_texture, uv_z);
    
    vec3 weights = local_normal;
    weights = pow(weights, vec3(sharpness));
    weights /= (weights.x + weights.y + weights.z);
    
    vec3 stud_rgb = tex_x.rgb * weights.x + tex_y.rgb * weights.y + tex_z.rgb * weights.z;
    float stud_alpha = tex_x.a * weights.x + tex_y.a * weights.y + tex_z.a * weights.z;
    
    if (use_overlay_mode) {
        vec3 blended_studs = base_color * (stud_rgb * 2.0);
        float final_mask = stud_alpha * (1.0 - transparency);
        ALBEDO = mix(base_color, blended_studs, final_mask);
    } else {
        ALBEDO = mix(stud_rgb, base_color, transparency);
    }
}