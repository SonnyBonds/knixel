shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture; 

void fragment() {
    vec4 screen_color = vec4(0.0);
    for(int i=0; i<40; ++i)
    {
	    screen_color += texture(screen_texture, SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x*(float(i)-20.0), 0));
    }
	COLOR = screen_color * 0.025;
} 
