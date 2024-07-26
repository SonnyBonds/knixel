layout( push_constant ) uniform constants
{
    vec2 src_offset;
    ivec2 dst_offset;
    vec4 rect;
    vec4 color;
    ivec4 wrap_rect;
} inputs;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    gl_Position = vec4(mix(inputs.rect.xy, inputs.rect.zw, coord[gl_VertexIndex])*2.0-1.0, 0.0, 1.0); 
}