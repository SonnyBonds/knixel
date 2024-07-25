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

vec4 blend(vec4 src, vec4 dst);

void main()
{
    ivec2 src_coord = ivec2(gl_FragCoord.xy) - inputs.src_offset;

    vec4 src = texelFetch(src_tex, src_coord, 0) * inputs.color;
    vec4 dst = texelFetch(dst_tex, ivec2(gl_FragCoord) - inputs.dst_offset, 0);

	output_color = blend(src, dst);
}