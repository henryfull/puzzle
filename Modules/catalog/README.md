# Catalog Module

Servicio base para catálogo remoto, manifiestos y descarga de assets cacheados en `user://`.

## Objetivo

- Descargar el `catalog_manifest.json`.
- Descargar el manifiesto del desafío diario.
- Cachear JSON y assets en `user://catalog`.
- Servir como base para la futura integración con la selección de packs y el contenido rotatorio.

## Archivo principal

- `RemoteCatalogService.gd`

## Ajustes de proyecto usados

```ini
[catalog]
base_url=""
api_base_url=""
cache_dir="user://catalog"
catalog_manifest_path="catalog/catalog_manifest.json"
daily_manifest_path_template="catalog/daily/%s.json"
catalog_endpoint="/v1/catalog"
daily_endpoint_template="/v1/catalog/daily/%s"
entitlements_endpoint="/v1/entitlements"
content_sign_endpoint="/v1/content/sign"
app_user_id=""
timeout_seconds=15.0
```

## Uso esperado

```gdscript
var catalog_service = load("res://Modules/catalog/RemoteCatalogService.gd").new()
add_child(catalog_service)

var catalog = await catalog_service.fetch_catalog_manifest()
var daily = await catalog_service.fetch_daily_challenge_manifest()
var entitlements = await catalog_service.fetch_entitlements()
```

## Integración actual

- Se carga como autoload en [project.godot](/Users/lleno/workspace/videogames/puzzle/project.godot).
- `EntitlementsService` usa `viewer.accessible_pack_ids` y `active_skus` para sincronizar acceso local.
- `ProgressManager` incorpora los packs visibles del catálogo remoto como metadatos DLC y refresca la lista cuando cambia el catálogo o los entitlements.
