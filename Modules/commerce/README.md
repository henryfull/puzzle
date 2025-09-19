# Módulo de Comercio

## Descripción

El módulo de comercio proporciona una solución completa para compras in-app (IAP) y gestión de derechos de compra. Incluye soporte para múltiples plataformas y un sistema de fallback para testing.

## Archivos

### Servicios Principales
- `IAPService.gd` - Servicio principal de compras in-app
- `EntitlementsService.gd` - Gestión de derechos de compra

### Proveedores
- `providers/GooglePlayBillingProvider.gd` - Proveedor para Google Play Billing
- `providers/DummyIAPProvider.gd` - Proveedor de prueba para testing

### Configuración
- `config/sku_mapping.json` - Mapeo de SKUs a contenido DLC

## Características

- ✅ Soporte para Google Play Billing (Android)
- ✅ Proveedor de prueba para desarrollo
- ✅ Gestión automática de derechos de compra
- ✅ Integración con DLCService para contenido
- ✅ Persistencia de compras realizadas
- ✅ Sistema de señales para comunicación
- ✅ Manejo de errores robusto

## Requisitos

### Dependencias
- **SettingsService** (para persistencia de compras)
- **DLCService** (para contenido descargable)

### Plugins Externos
- **GodotGooglePlayBilling** (para Android)
- **GodotSteam** (opcional, para Steam)

## Configuración

### 1. Configurar Autoloads
En `Project > Project Settings > Autoload`, añade en este orden:
- `SettingsService`
- `DLCService`
- `IAPService`
- `EntitlementsService`

### 2. Configurar Mapeo de SKUs
Edita `config/sku_mapping.json`:
```json
{
  "pack_animals": ["animals", "wild-animals"],
  "pack_cities": ["cities", "artistic-cities"],
  "full_game_unlock": ["all_packs"]
}
```

### 3. Configurar Google Play Billing (Android)
1. Añade el plugin GodotGooglePlayBilling
2. Configura tu cuenta de desarrollador de Google Play
3. Añade los productos en Google Play Console

## API

### IAPService

#### Señales
```gdscript
# Conexión/desconexión
IAPService.connected
IAPService.disconnected

# Productos
IAPService.sku_details(details: Array)

# Compras
IAPService.purchases_updated(purchases: Array)
IAPService.purchase_error(code: int, message: String)
IAPService.purchase_acknowledged(token: String)

# Consultas
IAPService.query_purchases_result(result: Dictionary)
IAPService.connect_error(code: int, message: String)
```

#### Métodos
```gdscript
# Consultar productos disponibles
IAPService.query_products(["pack_animals", "pack_cities"])

# Consultar compras existentes
IAPService.query_purchases()

# Realizar compra
IAPService.purchase("pack_animals")

# Confirmar compra
IAPService.acknowledge(purchase_token)
```

### EntitlementsService

#### Señales
```gdscript
# Cambios en derechos
EntitlementsService.entitlements_changed()
```

#### Propiedades
```gdscript
# Descarga automática de contenido
EntitlementsService.auto_download = true
```

## Ejemplos de Uso

### Configuración Básica
```gdscript
# En tu scene principal
extends Node

func _ready():
    # Los servicios se inicializan automáticamente
    # Conecta las señales necesarias
    _connect_iap_signals()

func _connect_iap_signals():
    var iap_service = get_node("/root/IAPService")
    var entitlements_service = get_node("/root/EntitlementsService")
    
    iap_service.connected.connect(_on_iap_connected)
    iap_service.purchase_error.connect(_on_purchase_error)
    entitlements_service.entitlements_changed.connect(_on_entitlements_changed)
```

### Mostrar Productos Disponibles
```gdscript
# Consultar y mostrar productos
func show_available_products():
    var iap_service = get_node("/root/IAPService")
    var skus = ["pack_animals", "pack_cities", "full_game_unlock"]
    iap_service.query_products(skus)

func _on_iap_connected():
    # Consultar productos cuando se conecte
    show_available_products()

func _on_sku_details_received(details: Array):
    # Mostrar productos en UI
    for product in details:
        print("Producto: %s - %s - %s" % [product.sku, product.title, product.price])
        # Actualizar UI con información del producto
```

### Realizar Compra
```gdscript
# Comprar un producto
func purchase_product(sku: String):
    var iap_service = get_node("/root/IAPService")
    iap_service.purchase(sku)

func _on_purchase_error(code: int, message: String):
    print("Error en compra: %d - %s" % [code, message])
    # Mostrar error al usuario

func _on_purchase_acknowledged(token: String):
    print("Compra confirmada: %s" % token)
    # La compra se procesará automáticamente por EntitlementsService
```

### Verificar Compras Existentes
```gdscript
# Al iniciar el juego, verificar compras
func check_existing_purchases():
    var iap_service = get_node("/root/IAPService")
    iap_service.query_purchases()

func _on_query_purchases_result(result: Dictionary):
    if result.status == OK:
        print("Compras encontradas: %d" % result.purchases.size())
        # Las compras se procesarán automáticamente por EntitlementsService
    else:
        print("Error al consultar compras: %s" % result.debug_message)
```

### Verificar Derechos de Compra
```gdscript
# Verificar si el usuario tiene un producto
func has_purchased_product(sku: String) -> bool:
    var settings_service = get_node("/root/SettingsService")
    var purchases = settings_service.get_value("purchases", "sku_flags", {})
    return purchases.get(sku, false)

# Verificar si tiene acceso a un pack específico
func has_access_to_pack(pack_id: String) -> bool:
    var dlc_service = get_node("/root/DLCService")
    var purchased_packs = dlc_service.get_purchased_packs()
    return pack_id in purchased_packs
```

### UI de Tienda
```gdscript
# Ejemplo de UI de tienda
extends Control

@onready var product_list = $ProductList
@onready var purchase_button = $PurchaseButton

var available_products = []

func _ready():
    var iap_service = get_node("/root/IAPService")
    iap_service.sku_details.connect(_on_products_loaded)
    iap_service.purchase_error.connect(_on_purchase_error)
    
    # Cargar productos
    iap_service.query_products(["pack_animals", "pack_cities"])

func _on_products_loaded(products: Array):
    available_products = products
    update_product_list()

func update_product_list():
    product_list.clear()
    for product in available_products:
        var item_text = "%s - %s" % [product.title, product.price]
        product_list.add_item(item_text)

func _on_purchase_button_pressed():
    var selected_index = product_list.get_selected_items()
    if selected_index.size() > 0:
        var product = available_products[selected_index[0]]
        purchase_product(product.sku)

func purchase_product(sku: String):
    var iap_service = get_node("/root/IAPService")
    iap_service.purchase(sku)
    purchase_button.disabled = true

func _on_purchase_error(code: int, message: String):
    purchase_button.disabled = false
    show_error_message("Error en compra: %s" % message)
```

## Configuración de Productos

### Google Play Console
1. Ve a Google Play Console
2. Selecciona tu aplicación
3. Ve a "Monetización > Productos > Compras en la aplicación"
4. Crea los productos con los SKUs definidos en tu código

### Mapeo de SKUs
El archivo `config/sku_mapping.json` mapea SKUs de compra a contenido DLC:

```json
{
  "pack_animals": ["animals", "wild-animals", "farm-animals"],
  "pack_cities": ["cities", "artistic-cities"],
  "pack_numbers": ["numbers"],
  "full_game_unlock": ["all_packs"]
}
```

## Flujo de Compra

1. **Inicialización**: Los servicios se conectan automáticamente
2. **Consulta de productos**: Se consultan los productos disponibles
3. **Compra**: El usuario selecciona y compra un producto
4. **Verificación**: La compra se verifica con la plataforma
5. **Aplicación de derechos**: EntitlementsService aplica los derechos
6. **Descarga de contenido**: Se descarga/instala el contenido DLC
7. **Persistencia**: Los derechos se guardan en SettingsService

## Testing y Desarrollo

### Usar Proveedor Dummy
El proveedor Dummy se activa automáticamente cuando Google Play Billing no está disponible:

```gdscript
# El proveedor Dummy simula compras para testing
# Las compras se procesan inmediatamente
# No requiere configuración adicional
```

### Testing de Compras
```gdscript
# Para testing, puedes simular compras directamente
func simulate_purchase(sku: String):
    var dummy_provider = get_node("/root/IAPService")._provider
    if dummy_provider.has_method("purchase"):
        dummy_provider.purchase(sku)
```

## Integración con DLCService

El módulo de comercio se integra automáticamente con DLCService:

```gdscript
# Cuando se completa una compra:
# 1. EntitlementsService marca el pack como comprado
# 2. DLCService descarga/instala el contenido
# 3. El contenido queda disponible en el juego
```

## Notas Técnicas

### Manejo de Errores
- Todos los errores se reportan a través de señales
- Los errores incluyen códigos y mensajes descriptivos
- El sistema es resiliente a fallos de red

### Persistencia
- Las compras se guardan en SettingsService
- Los derechos se persisten en `user://settings.cfg`
- La información se mantiene entre sesiones

### Seguridad
- Las compras se verifican con la plataforma
- Los tokens de compra se validan
- No se puede falsificar una compra

## Migración a Otros Proyectos

1. Copia la carpeta `commerce` completa
2. Configura los autoloads necesarios
3. Ajusta el mapeo de SKUs según tu contenido
4. Configura los productos en las plataformas correspondientes
5. Los servicios funcionarán automáticamente

## Solución de Problemas

### Las compras no se procesan
- Verifica que EntitlementsService está configurado
- Comprueba que DLCService está disponible
- Revisa los logs de error

### Los productos no se cargan
- Verifica que Google Play Billing está configurado
- Comprueba que los SKUs existen en Google Play Console
- Revisa la conexión a internet

### Los derechos no se aplican
- Verifica que SettingsService está funcionando
- Comprueba que el mapeo de SKUs es correcto
- Revisa que DLCService puede instalar el contenido
