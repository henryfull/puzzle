shader_type canvas_item;

uniform vec4 color_from : source_color;
uniform vec4 color_to : source_color;
uniform vec2 direction = vec2(1.0, -1.0); // De abajo izquierda a arriba derecha

void fragment() {
    // Normalizamos la dirección para evitar errores si es muy grande
    vec2 dir = normalize(direction);
    float factor = dot(UV, dir); // proyección UV sobre la dirección
    factor = clamp(factor, 0.0, 1.0);
    COLOR = mix(color_from, color_to, factor);
}