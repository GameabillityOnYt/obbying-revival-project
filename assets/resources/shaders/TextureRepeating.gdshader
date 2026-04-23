shader_type spatial;

uniform vec3 base_color: source_color = vec3(0.0,0.0,0.0);
uniform sampler2D albedo_texture : source_color, repeat_enable;
uniform vec2 tiling_scale = vec2(0.25, 0.25);
uniform float sharpness : hint_range(0.0, 50.0) = 10.0;
uniform float transparency: hint_range(0.0, 1.0, 0.01) = 0;

varying vec3 scaled_local_pos;
varying vec3 local_normal;

void vertex() {
    // 1. Get the object scale
    vec3 scale = vec3(
        length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),
        length(MODEL_MATRIX[2].xyz)
    );
    
    // 2. Pass the scaled local position
    scaled_local_pos = VERTEX * scale;
    local_normal = abs(NORMAL);
}

void fragment() {
    // 3. Offset the UVs by 0.5 to center the texture.
    // We apply this BEFORE the tiling_scale so it stays anchored to the middle.
    vec2 uv_x = (scaled_local_pos.zy + 0.5) * tiling_scale;
    vec2 uv_y = (scaled_local_pos.xz + 0.5) * tiling_scale;
    vec2 uv_z = (scaled_local_pos.xy + 0.5) * tiling_scale;
    
    // Sample the textures
    vec3 tex_x = texture(albedo_texture, uv_x).rgb;
    vec3 tex_y = texture(albedo_texture, uv_y).rgb;
    vec3 tex_z = texture(albedo_texture, uv_z).rgb;
    
    // Blend based on normals
    vec3 weights = local_normal;
    weights = pow(weights, vec3(sharpness));
    weights /= (weights.x + weights.y + weights.z);
    
    vec3 final_texture_color = tex_x * weights.x + tex_y * weights.y + tex_z * weights.z;
	ALBEDO = mix(final_texture_color,base_color,transparency);
}