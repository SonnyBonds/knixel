shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture; 

void fragment() {
	vec4 src = COLOR;
	vec4 dst = texture(screen_texture, SCREEN_UV);
	float alpha = src.a + dst.a * (1.0-src.a);
    vec3 color = dst.rgb;
	if(alpha > 0.0)
    {
        color = (dst.rgb*dst.a*(1.0-src.a) + src.rgb*src.a) / alpha;
    }
	COLOR = vec4(color, alpha);
} 
