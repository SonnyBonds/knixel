#[vertex]
#version 420 

#include "res://src/shaders/blend_modes/blend_mode_vertex.glsl"

#[fragment]
#version 420

#include "res://src/shaders/blend_modes/blend_mode_fragment.glsl"

vec4 blend(vec4 src, vec4 dst)
{
    vec4 blended;
    blended.rgb = mix(dst.rgb, 1.0 - (1.0-src.rgb) * (1.0-dst.rgb), src.a);
    blended.a = src.a + dst.a*(1.0-src.a);
    return blended;
}
