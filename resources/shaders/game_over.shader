uniform float weight;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    vec4 c = texcolor * color;
    float middle = (c.r + c.g + c.b) / 3.0;
    return vec4(middle, middle, middle, c.a) * weight + c * (1.0 - weight);
}