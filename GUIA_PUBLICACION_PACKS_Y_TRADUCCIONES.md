# Guia De Publicacion De Packs Y Traducciones

Esta es la forma recomendada para añadir contenido nuevo al juego sin tocar el binario base.

## Regla general

- `fruits` y el contenido base embebido siguen dentro de la app.
- Todo pack nuevo que quieras rotar, monetizar o traducir debe ir por `content-staging -> dist/content -> CDN/bucket`.
- Los textos de packs y puzzles no deben ir a `data/localization/translation.csv` si forman parte de contenido remoto.

## Estructura de un pack nuevo

```text
content-staging/
  packs/
    spring-2026/
      pack.meta.json
      thumb.webp
      spring-theme.ogg
      spring-2026-01.webp
      spring-2026-02.webp
```

## Campos clave de `pack.meta.json`

- `id`: identificador estable del pack. No lo reutilices para otro pack distinto.
- `revision`: súbela cuando cambies assets o metadatos del mismo pack.
- `tier`:
  - `free_rotating` para el catálogo gratuito rotatorio.
  - `premium` para catálogo premium permanente.
  - `free` o `seasonal` si quieres usar variantes controladas por catálogo/evento.
- `thumbnailFile`: portada del pack.
- `musicFile`: opcional. Si existe, el juego reproducirá esa pista para ese pack.
- `title`: nombre del pack por idioma.
- `description`: texto corto del pack por idioma.
- `puzzles[]`: lista de puzzles del pack.

## Campos clave de cada puzzle

- `id`: identificador estable del puzzle.
- `file`: imagen del puzzle.
- `width` y `height`: tamaño real del asset.
- `grid`: columnas y filas por defecto.
- `title`: nombre del puzzle por idioma.
- `description`: texto corto opcional.
- `story`: microrelato por idioma.

Regla práctica:

- Usa `story` para el texto largo que se ve en el reverso del puzzle y en la pantalla de victoria.
- Usa `description` para resumen corto o metadata editorial.
- Si un puzzle no tiene `story`, el cliente cae a `description`.

## Traducciones de contenido

Los packs remotos ya no dependen del CSV global del juego. La traducción correcta es esta:

```json
{
  "title": {
    "es": "Pack Primavera",
    "en": "Spring Pack",
    "ca": "Pack Primavera"
  },
  "story": {
    "es": "Cada mañana, el jardinero dejaba una carta entre los tulipanes...",
    "en": "Every morning, the gardener left a letter among the tulips...",
    "ca": "Cada mati, el jardiner deixava una carta entre les tulipes..."
  }
}
```

Fallback del cliente:

1. idioma actual del juego
2. `es`
3. `en`

Si mas adelante añades otro idioma, solo tienes que empezar a incluir esa clave en los JSON nuevos.

## Musica por pack

- Formatos soportados para contenido remoto: `.ogg`, `.oga`, `.mp3`
- Recomendado: `.ogg`
- Si `musicFile` no existe, el juego sigue usando la musica por defecto.
- La musica se descarga junto al pack y se cachea en local.

## Como hacer un pack gratuito o premium

### Pack gratuito rotatorio

1. Crea la carpeta del pack en `content-staging/packs/<pack-id>/`.
2. Pon `tier: "free_rotating"` en `pack.meta.json`.
3. Añade el `pack-id` a `content-staging/catalog.control.json -> packs`.
4. Añade el mismo `pack-id` a `freeRotation.active_pack_ids`.
5. Quita de `freeRotation.active_pack_ids` el pack gratuito que salga de la rotacion ese mes.

### Pack premium permanente

1. Crea la carpeta del pack.
2. Pon `tier: "premium"`.
3. Añade el `pack-id` a `catalog.control.json -> packs`.
4. No lo metas en `freeRotation.active_pack_ids`.

### Pack temporal o estacional

1. Crea el pack como `free` o `premium`.
2. Añadelo a `catalog.control.json -> packs`.
3. Declara la ventana en `seasonalEvents`.
4. El backend decidirá visibilidad por fecha.

## Daily challenges

Los diarios usan el mismo modelo de traduccion y microrelato, pero se publican en:

```text
content-staging/daily/YYYY-MM-DD/
  daily.meta.json
  hero.webp
  daily-theme.ogg
  challenge-image.webp
```

Dentro de `daily.meta.json`, el objeto `pack` acepta los mismos campos que un `pack.meta.json`, incluido `musicFile` y `story`.

## Build local

Genera el contenido publicable con:

```bash
node Tools/content-pipeline/build-remote-content.mjs \
  --staging ./content-staging \
  --output ./dist/content
```

Luego prueba en local con el sandbox remoto leyendo desde `res://dist/content`.

## Publicacion profesional

Flujo recomendado:

1. Preparas contenido en `content-staging`.
2. Ejecutas el build y validas `dist/content`.
3. Subes `dist/content` al bucket/CDN.
4. Invalidas solo manifiestos de catalogo y daily si hace falta.
5. Cambias `catalog_version` y `generatedAt`.

Infra recomendada:

- `S3 + CloudFront + OAC + signed URLs` para premium.
- `R2 + Workers` si priorizas coste.

## Convenciones recomendadas

- Usa IDs estables: `spring-2026`, `spring-2026-01`.
- No reutilices un `id` para un contenido distinto.
- Sube `revision` cuando cambies assets o textos de un pack existente.
- Mantén la portada y la musica dentro de la carpeta del pack.
- Guarda el microrelato en el propio puzzle, no en el pack.

## Ejemplo minimo

```json
{
  "id": "spring-2026",
  "revision": 1,
  "tier": "free_rotating",
  "title": {
    "es": "Pack Primavera 2026",
    "en": "Spring Pack 2026"
  },
  "description": {
    "es": "Flores, jardines y relatos cortos de primavera.",
    "en": "Flowers, gardens and short spring stories."
  },
  "thumbnailFile": "thumb.webp",
  "musicFile": "spring-theme.ogg",
  "puzzles": [
    {
      "id": "spring-2026-01",
      "file": "spring-2026-01.webp",
      "width": 1440,
      "height": 1440,
      "grid": {
        "columns": 4,
        "rows": 6
      },
      "title": {
        "es": "Tulipanes al amanecer",
        "en": "Tulips at dawn"
      },
      "story": {
        "es": "Cada manana, el jardinero dejaba una carta entre los tulipanes...",
        "en": "Every morning, the gardener left a letter among the tulips..."
      }
    }
  ]
}
```
