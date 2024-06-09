shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture; 

void fragment() {
	COLOR = texture(screen_texture, SCREEN_UV) * vec4(1.0, 0.0, 1.0, 1.0);
} 
