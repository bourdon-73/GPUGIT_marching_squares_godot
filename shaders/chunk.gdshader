shader_type canvas_item;

uniform sampler2D test_texture;

void fragment(){
    // Sample the texture using the original UV coordinates
    vec4 texture_color = texture(test_texture, UV);

    COLOR.rgb = texture_color.rgb * 2.0;
}