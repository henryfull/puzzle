# Content API

Backend mínimo de referencia para catálogo remoto, daily challenges, entitlements y URLs firmadas.

## Qué hace

- `GET /health`
- `GET /v1/entitlements`
- `GET /v1/catalog`
- `GET /v1/catalog/daily/{date}`
- `POST /v1/challenges/daily/complete`
- `POST /v1/rewards/daily/claim`
- `POST /v1/content/sign`
- `GET /content/file`

## Qué NO hace todavía

- No verifica compras reales de Apple o Google.
- No genera firmas de CloudFront.
- No persiste entitlements en base de datos.
- La validación del completado diario ya exige una sesión temporal firmada, pero sigue confiando en el cliente para el resultado; no hay anti-cheat real.

Está pensado como backend local y como contrato base para la versión de producción.

## Requisitos

- Node.js 22 o superior.
- Haber generado antes `dist/content` con el pipeline de publicación.

## Arranque local

```bash
cd backend/content-api
CONTENT_SIGNING_SECRET="dev-secret" npm run dev
```

## Variables de entorno

- `PORT`
- `CONTENT_BASE_URL`
- `CONTENT_ROOT`
- `ENTITLEMENTS_FILE`
- `PLAYER_STATE_FILE`
- `SIGNED_URL_TTL_SECONDS`
- `DAILY_COMPLETION_TOKEN_TTL_SECONDS`
- `CONTENT_SIGNING_SECRET`

## Defaults

- `PORT=8787`
- `CONTENT_ROOT=../../dist/content`
- `ENTITLEMENTS_FILE=./data/entitlements.json`
- `PLAYER_STATE_FILE=./data/player_state.json`
- `SIGNED_URL_TTL_SECONDS=300`
- `DAILY_COMPLETION_TOKEN_TTL_SECONDS=21600`

## Ejemplos

Obtener catálogo para usuario free:

```bash
curl "http://localhost:8787/v1/catalog?app_user_id=demo_free"
```

Obtener catálogo para premium:

```bash
curl "http://localhost:8787/v1/catalog?app_user_id=demo_premium"
```

Firmar assets:

```bash
curl -X POST "http://localhost:8787/v1/content/sign" \
  -H "Content-Type: application/json" \
  -d '{
    "app_user_id": "demo_premium",
    "asset_paths": [
      "packs/premium-archive-001/pack_manifest.v7.json"
    ]
  }'
```

Obtener daily con sesión de completion:

```bash
curl "http://localhost:8787/v1/catalog/daily/2026-03-08?app_user_id=demo_free"
```

Reportar completion del daily:

Primero hay que leer `completion_session.token` del daily. Luego se envía así:

```bash
curl -X POST "http://localhost:8787/v1/challenges/daily/complete" \
  -H "Content-Type: application/json" \
  -d '{
    "app_user_id": "demo_free",
    "date": "2026-03-08",
    "completion_token": "TOKEN_DEVUELTO_POR_GET_DAILY",
    "stats": {
      "elapsed_time": 143.2,
      "moves": 38,
      "score": 120
    }
  }'
```

Reclamar recompensa del daily:

```bash
curl -X POST "http://localhost:8787/v1/rewards/daily/claim" \
  -H "Content-Type: application/json" \
  -d '{
    "app_user_id": "demo_free",
    "date": "2026-03-08"
  }'
```

## Paso a producción

La evolución correcta es:

1. Reemplazar `data/entitlements.json` por un backend real con BD.
2. Guardar inventario, claims y progreso del daily en BD real, no en JSON local.
3. Verificar recibos/transacciones de Apple y Google en servidor.
4. Sustituir la sesión firmada por validación más autoritativa del reto o añadir anti-cheat/attestation.
5. Sustituir la firma HMAC local por `CloudFront signed URLs` o equivalente.
6. Dejar el asset gateway local solo para desarrollo.
