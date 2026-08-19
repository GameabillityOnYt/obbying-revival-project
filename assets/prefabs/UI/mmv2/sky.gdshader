shader_type sky;

uniform sampler2D texture_back  : source_color, filter_linear;
uniform sampler2D texture_front : source_color, filter_linear;
uniform sampler2D texture_left  : source_color, filter_linear;
uniform sampler2D texture_right : source_color, filter_linear;
uniform sampler2D texture_down  : source_color, filter_linear;
uniform sampler2D texture_up   : source_color, filter_linear;

void sky() {
    vec3 dir = EYEDIR;
    vec3 abs_dir = abs(dir);
    vec2 uv;
    vec4 col = vec4(0.0);

    if (abs_dir.x >= abs_dir.y && abs_dir.x >= abs_dir.z) {
        if (dir.x > 0.0) {
            uv = vec2(-dir.z, -dir.y) / abs_dir.x * 0.5 + 0.5;
            col = texture(texture_right, clamp(uv, 0.001, 0.999));
        } else {
            uv = vec2(dir.z, -dir.y) / abs_dir.x * 0.5 + 0.5;
            col = texture(texture_left, clamp(uv, 0.001, 0.999));
        }
    } else if (abs_dir.y >= abs_dir.x && abs_dir.y >= abs_dir.z) {
        if (dir.y > 0.0) {
            uv = vec2(dir.x, dir.z) / abs_dir.y * 0.5 + 0.5;
            col = texture(texture_up, clamp(uv, 0.001, 0.999));
        } else {
            uv = vec2(dir.x, -dir.z) / abs_dir.y * 0.5 + 0.5;
            col = texture(texture_down, clamp(uv, 0.001, 0.999));
        }
    } else {
        if (dir.z > 0.0) {
            uv = vec2(dir.x, -dir.y) / abs_dir.z * 0.5 + 0.5;
            col = texture(texture_back, clamp(uv, 0.001, 0.999));
        } else {
            uv = vec2(-dir.x, -dir.y) / abs_dir.z * 0.5 + 0.5;
            col = texture(texture_front, clamp(uv, 0.001, 0.999));
        }
    }

    COLOR = col.rgb;
}