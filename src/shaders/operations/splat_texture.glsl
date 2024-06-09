#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    vec4 rect;
    vec4 color;
} inputs;

layout(location = 0) out vec2 uv;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    uv = coord[gl_VertexIndex];
    gl_Position = vec4(mix(inputs.rect.xy, inputs.rect.zw, uv)*2.0-1.0, 0.0, 1.0); 
}

#[fragment]
#version 420

layout(location = 0) in vec2 uv;

layout(set = 0, binding = 0) uniform sampler2D tex;

layout(location = 0) out vec4 output_color; 

layout( push_constant ) uniform constants
{
    vec4 rect;
    vec4 color;
} inputs;

void main(){ 
    output_color = inputs.color * texture(tex, uv);    
}