shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Color base para el tinte (Verde desaturado tipo piedra Coraline)
uniform vec4 tint_color : source_color = vec4(0.3, 0.7, 0.3, 1.0);
uniform float effect_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(screen_texture, SCREEN_UV);
    
    // Convertir a escala de grises midiendo la luminancia
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(gray);
    
    // Multiplicar el blanco y negro por el verde desaturado
    vec3 final_color = grayscale * tint_color.rgb * 1.5;
    
    COLOR.rgb = mix(tex_color.rgb, final_color, effect_amount);
    COLOR.a = tex_color.a;
}