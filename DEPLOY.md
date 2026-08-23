# Desplegar el backend

Tres contenedores (`docker-compose.yml`): `db` (Postgres), `backend`
(FastAPI/uvicorn) y `caddy` (proxy inverso, HTTPS automático vía Let's
Encrypt). El backend y Postgres no exponen ningún puerto al exterior —
solo Caddy, en 80/443.

## Primera vez

1. En el servidor (con Docker y Docker Compose instalados) clona el repo.
2. **El dominio (`DOMAIN` en el paso 3) tiene que apuntar YA** — registro
   A/AAAA a la IP de este servidor — antes de arrancar. Si no, Caddy no
   consigue el certificado y falla.
3. Copia `.env.example` a `.env` y rellénalo:
   ```
   cp .env.example .env
   ```
   - `POSTGRES_PASSWORD`: algo real, no el placeholder.
   - `SECRET_KEY`: genera uno de verdad — `openssl rand -hex 32`.
   - `GOOGLE_CLIENT_ID`: el mismo que usa la app iOS
     (`ios-native-nav/project.yml` → `GIDClientID`).
   - `DOMAIN`: el dominio que apunta a este servidor (p. ej.
     `api.tudominio.com`).
4. Arranca:
   ```
   docker compose up -d --build
   ```
   La primera vez tarda un poco más (build de la imagen del backend +
   Caddy pidiendo el certificado). `docker compose logs -f caddy` para
   ver si el certificado se emitió bien.
5. Comprueba: `https://tu-dominio/users/` debería responder (una lista
   vacía si es la primera vez).

## Actualizar tras un cambio de código

```
git pull
docker compose up -d --build
```

Postgres y las fotos subidas (`uploads_data`) viven en volúmenes de
Docker aparte — no se tocan ni se pierden al reconstruir `backend`.

## Términos de uso / Política de privacidad

Viven como HTML estático en `./legal` (`terms.html`, `privacy.html`),
servidos directamente por Caddy en `https://tu-dominio/legal/terms.html`
y `.../legal/privacy.html` — no por el backend, así que se editan y se
ven reflejados con solo `docker compose restart caddy` (no hace falta
reconstruir ni redesplegar nada de Python). Son un borrador funcional,
no redactado por un abogado — conviene una revisión legal real antes de
un lanzamiento público de verdad.

## Probar en local antes de tener servidor/dominio de verdad

Con `DOMAIN=localhost` en el `.env`, Caddy usa un certificado propio
autofirmado en vez de pedirle uno real a Let's Encrypt (Let's Encrypt no
emite certificados para `localhost`) — el navegador avisará de
certificado no confiable, es normal, solo es para probar que los tres
contenedores arrancan y hablan entre sí:

```
docker compose up -d --build
curl -k https://localhost/users/
```

## Migrar datos de un `.rydr.db` local a este Postgres

No está automatizado — este despliegue parte de una base de datos
Postgres nueva y vacía. Si en algún momento hace falta llevar datos
reales que ya tengas en desarrollo, es un paso aparte (exportar de
SQLite, importar a Postgres) que no está cubierto aquí todavía.
