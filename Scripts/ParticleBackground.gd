@tool
extends Node2D

class_name ParticleBackground

# Configuración exportada para el inspector
@export_group("Configuración de Partículas")
@export var max_particles: int = 80
@export var particle_speed_min: float = 20.0
@export var particle_speed_max: float = 60.0
@export var particle_size_min: float = 2.0
@export var particle_size_max: float = 8.0
@export var particle_alpha_min: float = 0.3
@export var particle_alpha_max: float = 0.8

@export_group("Efectos")
@export var wave_speed: float = 1.5
@export var wave_amplitude: float = 30.0
@export var intensity: float = 1.0 : set = set_intensity

@export_group("Colores")
@export var use_custom_colors: bool = false
@export var custom_colors: Array[Color] = []

# Variables internas
var particles = []

# Colores por defecto tipo Tetris Effect
var default_particle_colors = [
	Color(0.3, 0.7, 1.0),    # Azul cian
	Color(0.9, 0.3, 0.9),    # Magenta
	Color(0.3, 0.9, 0.5),    # Verde
	Color(1.0, 0.7, 0.3),    # Naranja
	Color(0.7, 0.3, 1.0),    # Púrpura
	Color(0.3, 1.0, 1.0),    # Cian claro
	Color(1.0, 0.3, 0.5),    # Rosa
	Color(0.8, 0.8, 0.3),    # Amarillo
]

# Configuración de ondas
var wave_time: float = 0.0

# Referencia a la ventana
var screen_size: Vector2

func _ready():
	screen_size = get_viewport().size
	create_particles()

func _process(delta):
	if particles.is_empty():
		return
		
	wave_time += delta * wave_speed * intensity
	update_particles(delta)
	queue_redraw()

func create_particles():
	particles.clear()
	for i in range(max_particles):
		var particle = create_particle()
		particles.append(particle)

func create_particle():
	var particle = {}
	particle.position = Vector2(
		randf() * screen_size.x,
		randf() * screen_size.y
	)
	particle.velocity = Vector2(
		randf_range(-particle_speed_max, particle_speed_max) * intensity,
		randf_range(particle_speed_min, particle_speed_max) * intensity
	)
	particle.size = randf_range(particle_size_min, particle_size_max)
	particle.color = get_random_color()
	particle.alpha = randf_range(particle_alpha_min, particle_alpha_max)
	particle.rotation = randf() * TAU
	particle.rotation_speed = randf_range(-2.0, 2.0) * intensity
	particle.wave_offset = randf() * TAU
	particle.pulse_speed = randf_range(0.5, 2.0)
	particle.pulse_offset = randf() * TAU
	# Inicializar propiedades calculadas
	particle.current_size = particle.size
	particle.current_alpha = particle.alpha
	return particle

func get_random_color() -> Color:
	var colors_to_use = custom_colors if use_custom_colors and custom_colors.size() > 0 else default_particle_colors
	return colors_to_use[randi() % colors_to_use.size()]

func update_particles(delta):
	for particle in particles:
		# Movimiento base
		particle.position += particle.velocity * delta
		
		# Añadir movimiento ondulatorio
		particle.position.x += sin(wave_time + particle.wave_offset) * wave_amplitude * intensity * delta
		
		# Rotación
		particle.rotation += particle.rotation_speed * delta
		
		# Efecto de pulsación en el tamaño
		var pulse_factor = 1.0 + sin(wave_time * particle.pulse_speed + particle.pulse_offset) * 0.3
		particle.current_size = particle.size * pulse_factor
		
		# Efecto de pulsación en el alpha
		var alpha_pulse = sin(wave_time * particle.pulse_speed * 0.7 + particle.pulse_offset) * 0.2
		particle.current_alpha = clamp(particle.alpha + alpha_pulse, 0.1, 1.0)
		
		# Reposicionar partículas que salen de pantalla
		if particle.position.y > screen_size.y + 50:
			particle.position.y = -50
			particle.position.x = randf() * screen_size.x
		
		if particle.position.x < -50:
			particle.position.x = screen_size.x + 50
		elif particle.position.x > screen_size.x + 50:
			particle.position.x = -50

func _draw():
	for particle in particles:
		var color = particle.color
		color.a = particle.current_alpha
		
		# Dibujar partícula como un círculo con suave degradado
		draw_circle(particle.position, particle.current_size, color)
		
		# Añadir un brillo interno más suave
		var inner_color = color
		inner_color.a *= 0.8
		draw_circle(particle.position, particle.current_size * 0.6, inner_color)
		
		# Efecto de estela suave
		var trail_color = color
		trail_color.a *= 0.3
		var trail_pos = particle.position - particle.velocity * 0.5
		draw_circle(trail_pos, particle.current_size * 0.4, trail_color)

# Funciones públicas para configuración dinámica
func set_color_palette(new_colors: Array):
	custom_colors = new_colors
	use_custom_colors = true
	# Actualizar colores existentes gradualmente
	for particle in particles:
		if randf() < 0.3:  # Solo cambiar algunos para transición suave
			particle.color = get_random_color()

func set_intensity(new_intensity: float):
	intensity = clamp(new_intensity, 0.1, 2.0)
	# Actualizar velocidades existentes
	for particle in particles:
		particle.velocity = Vector2(
			randf_range(-particle_speed_max, particle_speed_max) * intensity,
			randf_range(particle_speed_min, particle_speed_max) * intensity
		)
		particle.rotation_speed = randf_range(-2.0, 2.0) * intensity

# Función para crear preset de colores específicos
func apply_menu_preset():
	var menu_colors = [
		Color(0.4, 0.8, 1.0, 0.6),    # Azul suave
		Color(0.8, 0.4, 0.9, 0.6),    # Magenta suave
		Color(0.4, 0.9, 0.6, 0.6),    # Verde suave
		Color(1.0, 0.8, 0.4, 0.6),    # Naranja suave
		Color(0.8, 0.4, 1.0, 0.6),    # Púrpura suave
		Color(0.4, 1.0, 0.9, 0.6),    # Cian suave
	]
	set_color_palette(menu_colors)
	set_intensity(0.7)

func apply_game_preset():
	var game_colors = [
		Color(0.2, 0.6, 1.0),    # Azul intenso
		Color(1.0, 0.2, 0.8),    # Magenta intenso
		Color(0.2, 1.0, 0.4),    # Verde intenso
		Color(1.0, 0.6, 0.2),    # Naranja intenso
		Color(0.6, 0.2, 1.0),    # Púrpura intenso
		Color(0.2, 1.0, 1.0),    # Cian intenso
	]
	set_color_palette(game_colors)
	set_intensity(1.2)

# Función para reinicializar las partículas (útil cuando cambia el tamaño de pantalla)
func reinitialize():
	screen_size = get_viewport().size
	create_particles() 
