#[vertex]
#version 420 

layout( push_constant ) uniform constants
{
    float radius;
    ivec2 direction;
    ivec2 offset;
    ivec2 src_size;
    ivec4 wrap_rect;
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
    ivec2 src_size;
    ivec4 wrap_rect;
} inputs;

float gaussian(float x, float sigma)
{
    sigma = 2.0 * sigma * sigma;
    return exp(-(x * x) / sigma) / (sigma * 3.14159265358979323846);
}

void main()
{
    float sigma = max(0.00001, float(inputs.radius) / 2.0);
    // TODO: Maybe this could be made smarter, but add a tiny base value to avoid division by zero
    vec4 weightSum = vec4(vec3(0.00001), 0.0);
    vec4 result = vec4(0.0);
    
    int intRadius = int(ceil(inputs.radius));
    ivec2 wrap_size = inputs.wrap_rect.zw - inputs.wrap_rect.xy;
    for(int i = -intRadius; i <= intRadius; ++i)
    {
        ivec2 src_coord = ivec2(gl_FragCoord.xy) - inputs.direction*i;
        src_coord -= inputs.offset; 
        src_coord = ivec2(mod(src_coord - inputs.wrap_rect.xy, wrap_size)) + inputs.wrap_rect.xy;
        vec2 inside = step(ivec2(0, 0), src_coord) * (1.0 - step(inputs.src_size, src_coord));
        vec4 tex_sample = texelFetch(src_tex, src_coord, 0) * inside.x * inside.y;
        float gauss_weight = gaussian(float(i), sigma);
        vec4 weight = gauss_weight * vec4(tex_sample.aaa, 1.0);
        result += tex_sample * weight;
        weightSum += weight;
    }

    result /= weightSum; // Normalize the result
    output_color = result;
}