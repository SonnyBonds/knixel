shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform vec4 color : source_color;
uniform sampler2D mask : repeat_disable, filter_nearest;
uniform vec2 offset;

void fragment() {
	vec2 mask_uv = (UV * vec2(textureSize(TEXTURE, 0).xy) - offset) / vec2(textureSize(mask, 0).xy);
	float mask_value = texture(mask, mask_uv).r;
	COLOR = mix(texture(TEXTURE, UV), color, mask_value);
} 
