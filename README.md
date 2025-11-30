# 🏍️ Rydr Backend API

Backend moderno construido con **Python** y **FastAPI**, diseñado con una arquitectura escalable de **Vertical Slicing** (Módulos funcionales) y **Arquitectura Hexagonal**.

## 🏗️ Arquitectura y Diseño

El proyecto se aleja de la estructura tradicional de capas (MVC) para favorecer la independencia de módulos.

### Estructura de Carpetas
* **`app/shared/`**: Kernel compartido (Configuración DB, Seguridad, Utilitarios).
* **`app/users/`**: Slice de gestión de usuarios (CRUD).
* **`app/auth/`**: Slice de autenticación (Login, Tokens, OAuth).

Cada slice (`users`, `auth`) implementa internamente **Arquitectura Hexagonal**:
* **Domain:** Entidades y Puertos (Interfaces).
* **Application:** Servicios y Lógica de Negocio.
* **Infrastructure:** Adaptadores (API Router, SQL Repository, Modelos DB).

---

## 🚀 Tecnologías y Librerías

Según `Pipfile`:

* **Lenguaje:** Python 3.14
* **Framework Web:** `fastapi` + `uvicorn`
* **Base de Datos:** `sqlalchemy` (SQLite por defecto para desarrollo)
* **Validación:** Pydantic (integrado en FastAPI) + `email-validator`
* **Seguridad:**
    * `python-jose`: Generación y validación de JWT.
    * `bcrypt`: Hasheo seguro de contraseñas.
    * `fastapi-sso`: Autenticación OAuth2 (Google). (No implementado aún)
* **Testing:** `pytest` + `httpx`.

---

## 📂 Estructura del Proyecto

```text
Rydr/
├── app/
│   ├── shared/              # Security, Database config
│   ├── users/               # Domain, Application, Infrastructure
│   ├── auth/                # Domain, Application, Infrastructure
│   └── main.py              # Entrypoint
├── tests/                   # Tests de integración (conftest.py)
├── Pipfile                  # Gestión de dependencias y scripts
└── README.md
