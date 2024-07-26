#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    vec2 src_offset;
    ivec4 wrap_rect;
} inputs;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    gl_Position = vec4(coord[gl_VertexIndex]*2.0-1.0, 0.0, 1.0); 
}

#[fragment]
#version 420

layout(set = 0, binding = 0) uniform sampler2D src_tex;

layout(location = 0) out vec4 output_color; 

layout( push_constant ) uniform constants
{
    ivec2 src_offset;
    ivec4 wrap_rect;
} inputs;

vec4 blend(vec4 src, vec4 dst);

void main()
{
    ivec2 wrap_size = max(textureSize(src_tex, 0), inputs.wrap_rect.zw - inputs.wrap_rect.xy);
    ivec2 src_coord = ivec2(gl_FragCoord.xy) - inputs.src_offset;
    src_coord = ivec2(mod(src_coord - inputs.wrap_rect.xy, wrap_size)) + inputs.wrap_rect.xy;

    output_color = texelFetch(src_tex, src_coord, 0);
}