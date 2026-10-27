shader_type canvas_item;
uniform sampler2D snapshot : source_color, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool negative_snap = true;
void fragment() {
	if (negative_snap) {
		vec3 sampled = texture(snapshot, UV).rgb;
		float ink = 1.0 - dot(sampled, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(ink), 1.0);
	} else {
		float dots = step(0.68, length(fract(UV * vec2(160.0, 90.0)) - 0.5));
		float edge = UV.x * 0.85 + UV.y * 0.15;
		COLOR = vec4(mix(vec3(0.018, 0.025, 0.04), vec3(0.09), dots), step(progress, edge));
	}
}
