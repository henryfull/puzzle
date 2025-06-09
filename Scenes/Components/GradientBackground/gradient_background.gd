extends Control


func _ready():
	$ColorRect.size = size
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;

		uniform vec4 color_from : source_color;
		uniform vec4 color_to : source_color;

		void fragment() {
			float factor = (UV.x + UV.y) * 0.5;
			COLOR = mix(color_from, color_to, factor);
		}
	"""

	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("color_from", Color.PURPLE)
	shader_material.set_shader_parameter("color_to", Color.BLUE)
	shader_material.set_shader_parameter("direction", Vector2(1, -1)) # Abajo izquierda → Arriba derecha
	$ColorRect.material = shader_material
