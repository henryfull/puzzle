extends Node

# Esta función encuentra un espacio coherente en un tablero de juego
func find_coherent_space(board, width, height, piece_width, piece_height):
	var best_space = null
	var best_score = -1
	
	# Iterar por todas las posibles posiciones del tablero
	for y in range(height - piece_height + 1):
		for x in range(width - piece_width + 1):
			var space = Vector2(x, y)
			var score = evaluate_space(board, space, piece_width, piece_height)
			
			if score > best_score:
				best_score = score
				best_space = space
	
	return best_space

# Evalúa qué tan buena es una posición dada
func evaluate_space(board, space, width, height):
	var score = 0
	var x = space.x
	var y = space.y
	
	# Verificar si el espacio está completamente vacío
	var is_empty = true
	for j in range(y, y + height):
		for i in range(x, x + width):
			if board[j][i] != 0:  # Asumiendo que 0 representa un espacio vacío
				is_empty = false
				break
		if not is_empty:
			break
	
	if is_empty:
		score += 100  # Alto puntaje para espacios completamente vacíos
	
	# Verificar la coherencia con piezas adyacentes
	# Este es un ejemplo simplificado - puedes expandirlo según tus necesidades
	
	return score 