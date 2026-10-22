shader_type canvas_item;
render_mode unshaded;

// The garage's last rendered frame, flattened to a monochrome negative. One frame of
// brutalist snap before the comic panels slam in; the TextureRect owns the texture.

void fragment() {
	vec3 frame = texture(TEXTURE, UV).rgb;
	float luma = dot(frame, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(1.0 - luma), 1.0);
}
