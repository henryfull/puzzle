# Prueba Local De Catalogo Remoto

Este flujo deja `fruits` como pack base local y genera el resto del catalogo desde `dlc_backup_20250901_190152` para probar:

- packs free rotatorios,
- packs premium por suscripcion,
- descarga de imagenes y manifests,
- desafio diario.

No mueve ni toca los packs reales del proyecto. Todo se genera en `dist/content`.

## 1. Generar el catalogo remoto local

Desde la raiz del proyecto:

```bash
node tools/content-pipeline/build-local-dev-catalog.mjs
```

Por defecto genera:

- `fruits` como contenido base local.
- Packs free remotos: `numbers`, `farm-animals`.
- Packs premium remotos: `artistic-cities`, `wild-animals`, `usa-pack`, `wild-animals-cartoon`.
- Daily challenge free con fecha de hoy usando el primer pack free disponible.

Opciones utiles:

```bash
node tools/content-pipeline/build-local-dev-catalog.mjs \
  --dailyDate 2026-03-08 \
  --freePacks numbers,farm-animals \
  --premiumPacks artistic-cities,wild-animals,usa-pack,wild-animals-cartoon \
  --dailySourcePack numbers
```

## 2. Ajustes del juego para el sandbox remoto

Ahora el proyecto puede leer el catalogo directamente desde `dist/content`, sin levantar la API local.

La configuracion por defecto del repo ya queda preparada para este sandbox:

- `catalog/local_content_root = res://dist/content`
- `catalog/dev_entitlements_path = res://dist/content/catalog/dev_entitlements.json`
- `commerce/remote_catalog_sandbox_mode = true`
- `commerce/free_to_play_mode = false`
- `catalog/app_user_id = demo_free`

Para probar premium, cambia solo:

- `catalog/app_user_id = demo_premium`

Notas:

- En este modo el juego ignora el flujo legacy de DLCs locales para tienda/catalogo y usa `fruits` como base local + el catalogo remoto generado en `dist/content`.
- Los entitlements de prueba se generan en `dist/content/catalog/dev_entitlements.json`.
- Si quieres volver al flujo anterior, desactiva `commerce/remote_catalog_sandbox_mode`.

## 3. Que deberias ver

Con `demo_free`:

- `fruits` como pack base local.
- packs remotos free visibles y descargables: `numbers`, `farm-animals`.
- los packs premium no deben aparecer en la lista del catalogo.
- daily challenge disponible.

Con `demo_premium`:

- todo lo anterior,
- acceso a todos los packs remotos,
- claim del daily manteniendo el flujo remoto local.

## 4. Si quieres una prueba limpia

Antes de arrancar el juego, borra el progreso local del usuario si vienes de pruebas anteriores. Lo importante es limpiar:

- `user://progress.json`
- `user://dlc/`
- `user://catalog/`
- `user://settings.cfg`

## 5. Que hace el generador

`tools/content-pipeline/build-local-dev-catalog.mjs`:

- lee los packs desde `dlc_backup_20250901_190152/packs`,
- excluye `fruits`,
- construye un staging temporal en `content-staging/local-dev`,
- genera `dist/content` con el pipeline remoto normal,
- crea un daily usando un puzzle real del backup,
- genera `dist/content/catalog/dev_entitlements.json` con `demo_free` y `demo_premium`.
