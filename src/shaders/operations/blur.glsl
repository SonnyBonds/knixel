#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    float radius;
    ivec2 direction;
    ivec2 offset;
} inputs;

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

layout( push_constant ) uniform constants
{
    float radius;
    ivec2 direction;
    ivec2 offset;
} inputs;

float gaussian(float x, float sigma)
{
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (2.0 * 3.14159265358979323846 * sigma * sigma);
}

void main()
{
    float sigma = max(0.00001, float(inputs.radius) / 2.0); // standard deviation
    vec4 weightSum = vec4(0.0);
    vec4 result = vec4(0.0);
    
    int intRadius = int(ceil(inputs.radius));
    for(int i = -intRadius; i <= intRadius; ++i)
    {
        vec4 tex_sample = texelFetch(src_tex, ivec2(gl_FragCoord.xy) - inputs.offset + inputs.direction*i, 0);
        float gauss_weight = gaussian(float(i), sigma);
        vec4 weight = gauss_weight * vec4(tex_sample.aaa, 1.0);
        result += tex_sample * weight;
        weightSum += weight;
    }

    result /= weightSum; // normalize the result
    output_color = result;
}