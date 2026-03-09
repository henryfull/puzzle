# Content Pipeline

Pipeline local para construir `dist/content` desde una carpeta de staging.

## Qué genera

- `dist/content/catalog/catalog_manifest.json`
- `dist/content/catalog/daily/<date>.json`
- `dist/content/packs/<pack-id>/...`
- `dist/content/daily/<date>/...`

## Uso

```bash
node Tools/content-pipeline/build-remote-content.mjs \
  --staging ./content-staging \
  --output ./dist/content \
  --cdnBaseUrl https://cdn.tudominio.com/puzzletikitiki
```

## Estructura de staging

```text
content-staging/
  catalog.control.json
  packs/
    free-001/
      pack.meta.json
      thumb.webp
      free-001-puzzle-01.webp
      free-001-puzzle-02.webp
  daily/
    2026-03-08/
      daily.meta.json
      hero.webp
      daily-2026-03-08.webp
```

## `catalog.control.json`

```json
{
  "catalogVersion": "2026.03.01",
  "generatedAt": "2026-03-08T10:00:00Z",
  "cdnBaseUrl": "https://cdn.example.com/puzzletikitiki",
  "freeRotation": {
    "slot_count": 12,
    "starts_at": "2026-03-01T00:00:00Z",
    "ends_at": "2026-04-01T00:00:00Z",
    "active_pack_ids": ["free-001"]
  },
  "seasonalEvents": [],
  "packs": ["free-001", "premium-archive-001"],
  "dailyChallenges": ["2026-03-08"]
}
```

## `pack.meta.json`

```json
{
  "id": "free-001",
  "revision": 3,
  "tier": "free_rotating",
  "title": {
    "es": "Pack Primavera",
    "en": "Spring Pack",
    "ca": "Pack Primavera"
  },
  "description": {
    "es": "Colección mensual rotatoria.",
    "en": "Monthly rotating collection.",
    "ca": "Col·lecció mensual rotatòria."
  },
  "thumbnailFile": "thumb.webp",
   "musicFile": "spring-theme.ogg",
  "puzzles": [
    {
      "id": "free-001-puzzle-01",
      "file": "free-001-puzzle-01.webp",
      "width": 1440,
      "height": 1440,
      "grid": {
        "columns": 4,
        "rows": 6
      },
      "title": {
        "es": "Tulipanes al amanecer",
        "en": "Tulips at dawn",
        "ca": "Tulipes a l'alba"
      },
      "story": {
        "es": "Cada mañana, el jardinero dejaba una carta entre los tulipanes...",
        "en": "Every morning, the gardener left a letter among the tulips...",
        "ca": "Cada matí, el jardiner deixava una carta entre les tulipes..."
      }
    }
  ]
}
```

Notas:

- `musicFile` es opcional. Si no existe, el juego sigue usando la música por defecto.
- Para audio remoto usa `.ogg`, `.oga` o `.mp3`. Recomendado: `.ogg`.
- `story` es el texto largo que se renderiza en el reverso del puzzle y en la pantalla de victoria.
- `description` queda como texto corto del pack. Si un puzzle no trae `story`, el juego usa `description`.
- Para contenido remoto no metas estos textos en `translation.csv`: deben viajar dentro del propio manifiesto del pack.
- El cliente resuelve idioma con este orden: idioma actual del juego, `es`, `en`.

## `daily.meta.json`

```json
{
  "challengeId": "daily-2026-03-08",
  "date": "2026-03-08",
  "tier": "free",
  "title": {
    "es": "Desafío diario",
    "en": "Daily challenge"
  },
  "expiresAt": "2026-03-09T00:00:00Z",
  "pack": {
    "id": "daily-2026-03-08",
    "revision": 1,
    "tier": "free",
    "title": {
      "es": "Pack diario",
      "en": "Daily Pack"
    },
    "description": {
      "es": "Contenido del desafío diario.",
      "en": "Daily challenge content."
    },
    "thumbnailFile": "hero.webp",
    "musicFile": "daily-theme.ogg",
    "puzzles": [
      {
        "id": "daily-2026-03-08-01",
        "file": "daily-2026-03-08.webp",
        "width": 1440,
        "height": 1440,
        "grid": {
          "columns": 4,
          "rows": 6
        },
        "story": {
          "es": "El reloj del invernadero marcó las seis cuando la última flor se abrió.",
          "en": "The greenhouse clock struck six when the last flower opened."
        }
      }
    ]
  }
}
```

## Despliegue recomendado

Después de generar `dist/content`, súbelo al bucket/CDN con tu herramienta de despliegue.

Ejemplo con AWS CLI:

```bash
aws s3 sync ./dist/content s3://TU_BUCKET/puzzletikitiki --delete
```

Luego invalidas solo manifiestos si hace falta:

```bash
aws cloudfront create-invalidation \
  --distribution-id TU_DISTRIBUTION_ID \
  --paths "/puzzletikitiki/catalog/catalog_manifest.json" "/puzzletikitiki/catalog/daily/*"
```
