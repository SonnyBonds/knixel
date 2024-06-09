#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    vec2 src_offset;
    ivec2 dst_offset;
    vec4 rect;
    vec4 color;
} inputs;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    gl_Position = vec4(mix(inputs.rect.xy, inputs.rect.zw, coord[gl_VertexIndex])*2.0-1.0, 0.0, 1.0); 
}

#[fragment]
#version 420

layout(set = 0, binding = 0) uniform sampler2D src_tex;
layout(set = 0, binding = 1) uniform sampler2D dst_tex;

layout(location = 0) out vec4 output_color; 

layout( push_constant ) uniform constants
{
    ivec2 src_offset;
    ivec2 dst_offset;
    vec4 rect;
    vec4 color;
} inputs;

void main()
{ 
    vec4 src = texelFetch(src_tex, ivec2(gl_FragCoord) - inputs.src_offset, 0) * inputs.color;
    vec4 dst = texelFetch(dst_tex, ivec2(gl_FragCoord) - inputs.dst_offset, 0);

    output_color.rgb = mix(dst.rgb, abs(src.rgb - dst.rgb), src.a);
    output_color.a = src.a + dst.a*(1.0-src.a);
}