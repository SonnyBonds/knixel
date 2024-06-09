#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    vec4 color;
} inputs;

void main()
{
    vec2 coord[4] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));
    gl_Position = vec4(coord[gl_VertexIndex]*2.0-1.0, 0.0, 1.0); 
}

#[fragment]
#version 420

layout(location = 0) out vec4 output_color; 

layout( push_constant ) uniform constants
{
    vec4 color;
} inputs;

void main()
{
    output_color = inputs.color;
}