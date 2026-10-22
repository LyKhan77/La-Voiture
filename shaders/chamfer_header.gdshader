shader_type canvas_item;
render_mode unshaded;
uniform vec2 rect_size = vec2(320.0, 28.0);
uniform float cut_px = 14.0;
uniform float skew_degrees = -6.0;
uniform vec4 fill_color : source_color = vec4(0.8, 1.0, 0.0, 1.0);
varying vec2 local_pos;
void vertex() {
    local_pos = VERTEX;
    VERTEX.x += tan(radians(skew_degrees)) * (VERTEX.y - rect_size.y * 0.5);
}
void fragment() {
    float right_distance = rect_size.x - local_pos.x;
    if (right_distance + local_pos.y < cut_px) { discard; }
    vec2 cell = mod(FRAGCOORD.xy, vec2(5.0)) - vec2(2.5);
    float dot = 1.0 - step(1.25, length(cell));
    COLOR = vec4(mix(fill_color.rgb, vec3(0.0196), dot * 0.16), fill_color.a);
}
