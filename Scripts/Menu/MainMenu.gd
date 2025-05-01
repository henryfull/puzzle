extends Control

# Referencia al gestor de conexiones
@onready var connection_manager = $"/root/ConnectStores"

# Variable global para rastrear si ya se conectó
var _has_connected_first_time = false

func _ready():
    # Intentar conectar con la tienda solo la primera vez que se abre el menú
    if not _has_connected_first_time:
        _has_connected_first_time = true
        
        # Garantizar que la conexión solo se inicie una vez
        if connection_manager and not connection_manager.connection_initialized:
            connection_manager.initialize_connection()
            
        print("MainMenu: Primera apertura, iniciando conexión con las tiendas")
    else:
        print("MainMenu: El menú ya se ha abierto antes, omitiendo conexión") 