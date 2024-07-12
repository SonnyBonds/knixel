#[vertex]
#version 420 

layout(location = 0) out vec2 uv;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    uv = coord[gl_VertexIndex];
    gl_Position = vec4(uv*2.0-1.0, 0.0, 1.0); 
}

#[fragment]
#version 420

layout(location = 0) in vec2 uv;

layout(set = 0, binding = 0) uniform sampler2D src_tex;

layout(location = 0) out vec4 output_color; 

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

void main()
{
    vec4 tex_sample = texelFetch(src_tex, ivec2(gl_FragCoord.xy), 0);
    output_color = srgb_to_linear(tex_sample);
}