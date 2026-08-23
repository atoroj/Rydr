# Mismo Python que usa el proyecto en local (ver Pipfile: python_version = "3.14").
FROM python:3.14-slim

WORKDIR /app

# libpq no hace falta como paquete de compilación aparte: psycopg2-binary
# (Pipfile) ya trae el binario precompilado, sin pedir herramientas de
# compilación en la imagen.
RUN pip install --no-cache-dir pipenv

# Copiar solo el Pipfile/lock primero: así Docker reutiliza esta capa
# (no reinstala dependencias) mientras solo cambie el código de app/,
# que es lo que más cambia entre builds.
COPY Pipfile Pipfile.lock ./
# --system: instala directo en el Python de la imagen, sin crear un venv
# dentro del contenedor — el contenedor ya es el aislamiento, no hace
# falta uno más. --deploy: falla si Pipfile.lock no está al día con
# Pipfile, para no desplegar con dependencias desincronizadas sin darte
# cuenta.
RUN pipenv install --system --deploy

COPY app ./app

EXPOSE 8000

# Sin --reload (eso es solo para desarrollo, ver Pipfile: script "dev").
# --proxy-headers --forwarded-allow-ips='*': sin esto, el rate limiting
# por IP (ver app/shared/rate_limit.py) vería siempre la IP de Caddy (el
# único que le habla al backend, por la red interna de Docker Compose) en
# vez de la del cliente real, y todo el mundo compartiría el mismo
# límite. Seguro poner '*' aquí porque el backend no está expuesto al
# exterior — solo Caddy puede llegarle directamente (ver
# docker-compose.yml: "backend" no publica ningún puerto).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]
