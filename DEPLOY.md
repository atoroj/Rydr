# Desplegar el backend

Tres contenedores (`docker-compose.yml`): `db` (Postgres), `backend`
(FastAPI/uvicorn) y `caddy` (proxy inverso, HTTPS automático vía Let's
Encrypt — o un certificado autofirmado si `DOMAIN` no es un dominio de
verdad, ver más abajo). El backend y Postgres no exponen ningún puerto
al exterior — solo Caddy, en 80/443.

`backend` usa una imagen de GHCR (`ghcr.io/atoroj/rydr-backend`) que
construye GitHub Actions en cada push a `main` (ver más abajo) — el VPS
nunca compila nada, solo hace `docker compose pull`. En local,
`docker compose up --build` sigue construyendo la imagen desde el
`Dockerfile` tal cual (mismo `docker-compose.yml`, ver el comentario
junto a `image:`/`build:` del servicio `backend`).

## Primera vez en el VPS (a mano, sin CI/CD todavía)

1. Instala Docker + el plugin de Compose (Debian/Ubuntu):
   ```
   curl -fsSL https://get.docker.com | sh
   apt install -y docker-compose-plugin
   ```
2. Firewall — solo SSH, HTTP y HTTPS:
   ```
   ufw allow 22
   ufw allow 80
   ufw allow 443
   ufw enable
   ```
3. Clona el repo **exactamente en `/opt/rydr`** (ese path está fijo en
   `.github/workflows/deploy.yml` — si usas otro, actualiza el workflow
   también):
   ```
   git clone --branch main https://github.com/atoroj/Rydr.git /opt/rydr
   cd /opt/rydr
   ```
4. Copia `.env.example` a `.env` y rellénalo:
   ```
   cp .env.example .env
   ```
   - `POSTGRES_PASSWORD`: algo real, no el placeholder.
   - `SECRET_KEY`: genera uno de verdad — `openssl rand -hex 32`.
   - `GOOGLE_CLIENT_ID`: el mismo que usa la app iOS
     (`ios-native-nav/project.yml` → `GIDClientID`).
   - `DOMAIN`: el dominio que apunta a este servidor (p. ej.
     `api.tudominio.com`) — **o la IP pública del VPS si todavía no
     tienes dominio** (ver la sección de más abajo: funciona, pero con
     certificado autofirmado en vez de uno real).
   - `RESEND_API_KEY`/`ALLOWED_ORIGINS`: opcionales, ver comentarios en
     `.env.example`.
5. Primer arranque:
   ```
   docker compose pull
   docker compose up -d
   ```
   Si `ghcr.io/atoroj/rydr-backend` todavía no existe (no ha corrido
   nunca el CI/CD), usa `docker compose up -d --build` esta primera vez
   para construirla ahí mismo — las siguientes veces ya las hace
   GitHub Actions.
   `docker compose logs -f caddy` para ver si el certificado se emitió
   bien.
6. Comprueba: `https://tu-dominio-o-ip/users/` debería responder (una
   lista vacía si es la primera vez). Con IP y certificado autofirmado,
   añade `-k` si pruebas con `curl`.

## Sin dominio todavía: usar la IP del VPS

`DOMAIN` acepta perfectamente una IP — Caddy detecta que no es un
dominio público de verdad y usa un certificado propio autofirmado (el
mismo mecanismo que con `DOMAIN=localhost` en local), en vez de pedirle
uno a Let's Encrypt (que nunca emite certificados para IPs). Funciona
para probar todo el despliegue de punta a punta; para un lanzamiento de
verdad conviene un dominio real (unos 10-15€/año en Namecheap, Porkbun,
Cloudflare...), porque iOS no confía en certificados autofirmados fuera
de desarrollo. Cambiar de IP a dominio real después es solo: comprar el
dominio, crear un registro A a la IP del VPS, cambiar `DOMAIN` en el
`.env`, y `docker compose up -d` de nuevo.

## CI/CD con GitHub Actions

`.github/workflows/deploy.yml`, en cada push a `main`:

1. **test** — `pytest` completo. Si falla, no se llega a construir ni
   desplegar nada.
2. **build-and-push** — construye la imagen del backend y la sube a
   GHCR (`ghcr.io/atoroj/rydr-backend:latest` y `:<sha del commit>`).
3. **deploy** — se conecta al VPS por SSH y hace `git pull` (para
   recoger cambios en `docker-compose.yml`/`Caddyfile`/`legal/` que no
   están en la imagen) + `docker compose pull backend` + `docker compose
   up -d` + limpia imágenes viejas sin usar.

En un *pull request* contra `main` solo corre **test** (gate antes de
fusionar) — build y deploy solo en push directo a `main`.

### Configurar los secrets (una vez)

En GitHub: **Settings → Secrets and variables → Actions → New repository
secret**.

- `VPS_HOST`: la IP (o dominio) del VPS.
- `VPS_USER`: el usuario SSH (p. ej. `root`, o uno con permiso para usar
  Docker).
- `VPS_SSH_KEY`: la clave **privada** de un par SSH dedicado a esto (no
  reutilices tu clave personal):
  ```
  ssh-keygen -t ed25519 -f ~/.ssh/rydr_deploy -N ""
  ```
  Pega el contenido de `~/.ssh/rydr_deploy` (la privada) como el
  secret, y añade `~/.ssh/rydr_deploy.pub` (la pública) a
  `~/.ssh/authorized_keys` del usuario `VPS_USER` **en el VPS**.
- `VPS_PORT`: opcional, solo si SSH no escucha en el 22 por defecto.

`GITHUB_TOKEN` (para subir la imagen a GHCR) ya lo pone GitHub solo, no
hace falta crearlo.

### Primera vez con GHCR privado

Las imágenes que sube `GITHUB_TOKEN` a GHCR nacen **privadas** aunque el
repo sea público. El VPS necesita autenticarse una vez para poder
descargarlas (`docker compose pull`):

```
echo TU_TOKEN_CON_read:packages | docker login ghcr.io -u atoroj --password-stdin
```

(`TU_TOKEN_CON_read:packages`: un Personal Access Token de GitHub —
Settings → Developer settings → Personal access tokens → scope
`read:packages` — nada que ver con el `GITHUB_TOKEN` automático de
Actions). Alternativa más simple: hacer pública la imagen desde
`github.com/atoroj/Rydr/pkgs/container/rydr-backend` → Package settings
→ Change visibility, y ya no hace falta `docker login` en el VPS.

## Términos de uso / Política de privacidad

Viven como HTML estático en `./legal` (`terms.html`, `privacy.html`),
servidos directamente por Caddy en `https://tu-dominio/legal/terms.html`
y `.../legal/privacy.html` — no por el backend, así que se editan y se
ven reflejados con solo `docker compose restart caddy` (no hace falta
reconstruir ni redesplegar nada de Python). Son un borrador funcional,
no redactado por un abogado — conviene una revisión legal real antes de
un lanzamiento público de verdad.

## Probar en local antes de tener servidor de verdad

Con `DOMAIN=localhost` en el `.env`, Caddy usa el mismo certificado
autofirmado que con una IP — el navegador avisará de certificado no
confiable, es normal, solo es para probar que los tres contenedores
arrancan y hablan entre sí:

```
docker compose up -d --build
curl -k https://localhost/users/
```

## Migrar datos de un `.rydr.db` local a este Postgres

No está automatizado — este despliegue parte de una base de datos
Postgres nueva y vacía. Si en algún momento hace falta llevar datos
reales que ya tengas en desarrollo, es un paso aparte (exportar de
SQLite, importar a Postgres) que no está cubierto aquí todavía.
