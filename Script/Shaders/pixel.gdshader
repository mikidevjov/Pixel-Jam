
shader_type canvas_item;

uniform sampler2D screen_texture :
    hint_screen_texture, filter_nearest;

uniform float grain_strength : hint_range(0.0, 0.04) = 0.008;
uniform float grain_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;

float hash(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) * 43758.5453
    );
}

void fragment() {
    vec2 uv = SCREEN_UV;

    vec4 base = texture(screen_texture, uv);

    vec2 pixel_coord = floor(
        FRAGCOORD.xy / max(pixel_size, 1.0)
    );

    float grain = hash(
        pixel_coord + floor(TIME * grain_speed)
    ) - 0.5;

    vec3 result = base.rgb + grain * grain_strength;

    COLOR = vec4(clamp(result, 0.0, 1.0), base.a);
}
