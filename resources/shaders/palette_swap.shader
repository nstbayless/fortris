#define PALETTE_COUNT 32

uniform ivec4[PALETTE_COUNT] source;
uniform vec4[PALETTE_COUNT] dst;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    ivec4 compcolor = ivec4(texcolor * 255);
    for (int i = 0; i < PALETTE_COUNT; ++i) {
        if (source[i] == compcolor) {
            texcolor = dst[i];
        }
    }
    return texcolor * color / 255.0;
}