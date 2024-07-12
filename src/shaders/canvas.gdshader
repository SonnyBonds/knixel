shader_type canvas_item;
render_mode blend_mix, unshaded;

vec4 linear_to_srgb(vec4 linear)
{
    vec3 lower_segment = linear.rgb * 12.92;
    vec3 upper_segment = 1.055 * pow(linear.rgb, vec3(1.0/2.4)) - 0.055;

    bvec3 segment_mix = lessThan(linear.rgb, vec3(0.0031308));

    return vec4(mix(upper_segment, lower_segment, segment_mix), linear.a);
}

vec4 srgb_to_linear(vec4 srgb)
{
    vec3 lower_segment = srgb.rgb / 12.92;
    vec3 upper_segment = pow((srgb.rgb + 0.055) / 1.055, vec3(2.4));

    bvec3 segment_mix = lessThan(srgb.rgb, vec3(0.04045));

    return vec4(mix(upper_segment, lower_segment, segment_mix), srgb.a);
}

void fragment() {
	COLOR = linear_to_srgb(texture(TEXTURE, UV));
}