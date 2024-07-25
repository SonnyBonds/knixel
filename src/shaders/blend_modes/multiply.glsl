#[vertex]
#version 420 

#include "res://src/shaders/blend_modes/blend_mode_vertex.glsl"

#[fragment]
#version 420

#include "res://src/shaders/blend_modes/blend_mode_fragment.glsl"

vec4 blend(vec4 src, vec4 dst)
{
    vec4 blended;
    blended.rgb = mix(dst.rgb, src.rgb * dst.rgb, src.a);
    blended.a = dst.a;
    return blended;
}
