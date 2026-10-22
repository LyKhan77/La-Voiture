shader_type canvas_item;
render_mode unshaded;
uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 0.07);
uniform float dot_spacing : hint_range(2.0, 24.0) = 6.0;
uniform float dot_radius : hint_range(0.5, 4.0) = 1.0;
void fragment() {
    vec2 cell = mod(FRAGCOORD.xy, vec2(dot_spacing)) - vec2(dot_spacing * 0.5);
    float mask = 1.0 - step(dot_radius, length(cell));
    COLOR = vec4(dot_color.rgb, dot_color.a * mask);
}
