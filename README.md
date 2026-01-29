# 🏍️ Rydr Backend API

A modern Backend API built with **Python** and **FastAPI**, engineered with a scalable **Vertical Slicing** (Feature Modules) approach and **Hexagonal Architecture** (Ports & Adapters).

## 🏗️ Architecture & Design Decisions

This project moves away from the traditional Layered Architecture (MVC) to favor module independence and domain-centric design.

### 📂 Directory Structure Strategy
* **`app/shared/`**: Shared Kernel (Database configuration, Security, Utilities).
* **`app/users/`**: User Management Slice (CRUD, Profile).
* **`app/auth/`**: Authentication Slice (Login, Token Management).

### ⬢ Hexagonal Architecture Implementation
Each slice (`users`, `auth`) implements its own internal Hexagonal Architecture to decouple business logic from external details:

* **Domain:** Core entities and Ports (Repository Interfaces). *Pure Python code, no external dependencies.*
* **Application:** Use Cases, Services, and DTOs. *Orchestrates logic.*
* **Infrastructure:** Adapters (API Routers, SQL Repositories, ORM Models). *Framework and Database details.*

---

## 🚀 Tech Stack

* **Language:** Python 3.14
* **Web Framework:** `fastapi` + `uvicorn` (High performance ASGI)
* **Database:** `sqlalchemy` (SQLite for dev / PostgreSQL ready)
* **Validation:** Pydantic + `email-validator`
* **Security:**
    * `python-jose`: JWT generation and validation.
    * `bcrypt`: Secure password hashing.
    * `fastapi-sso`: OAuth2 integration (Planned).
* **Testing:** `pytest` + `httpx` for integration testing.

---

## 🛠️ Project Structure

The codebase is organized to ensure that business logic remains decoupled from the framework and database.

```text
Rydr/
├── app/
│   ├── shared/              # Shared Kernel (DB Session, Security Utils)
│   ├── users/               # [Vertical Slice] User Domain
│   │   ├── application/     # Service Layer (Use Cases) & DTOs
│   │   ├── domain/          # Entities & Repository Interfaces (Ports)
│   │   └── infrastructure/  # DB Models, Repositories & API Routes
│   ├── auth/                # [Vertical Slice] Auth Domain
│   │   ├── application/     # Auth Services
│   │   ├── domain/          # Auth Models
│   │   └── infrastructure/  # Routers & Adapters
│   └── main.py              # Application Entrypoint
├── tests/                   # Integration Tests
├── Pipfile                  # Dependency Management
└── README.md
```

## ⚡ How to Run

1. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   # OR if using pipenv
   pipenv install
   pipenv shell
   ```

2. **Run the Server:**
    ```bash
    uvicorn app.main:app --reload
    ```

## 🧪 Testing

   **To run the integration tests:**
    ```
    pytest
    ```
