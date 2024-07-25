#[vertex]
#version 420 

#include "res://src/shaders/blend_modes/blend_mode_vertex.glsl"

#[fragment]
#version 420

#include "res://src/shaders/blend_modes/blend_mode_fragment.glsl"

vec4 blend(vec4 src, vec4 dst)
{
    vec4 blended = src * vec4(src.aaa, 1.0) + dst * vec4(dst.aaa, 1.0) * (1.0-src.a);
	if(blended.a > 0.0)
    {
        blended.rgb = blended.rgb / blended.a;
    }

    return blended;
}