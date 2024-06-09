shader_type canvas_item;

void vertex() {
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec4 v1 = texture(TEXTURE, UV);
	vec4 v2 = texture(TEXTURE, UV+dx);
	vec4 v3 = texture(TEXTURE, UV+dy);
	vec4 v4 = texture(TEXTURE, UV+dx+dy);
 	float s1 = step(0.5, v1.r);
	float s2 = step(0.5, v2.r);
	float s3 = step(0.5, v3.r);
	float s4 = step(0.5, v4.r);
	float above = s1 + s2 + s3 + s4;
	float below = (1.0-s1) + (1.0-s2) + (1.0-s3) + (1.0-s4);
	float f = step(0.5, fract((FRAGCOORD.x+FRAGCOORD.y)*0.1));
	COLOR = vec4(f, f, f, step(0.5, above*below));
}
