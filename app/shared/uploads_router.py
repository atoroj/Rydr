import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status

from app.shared.auth_dependency import get_current_user
from app.users.infrastructure.user_model import UserModel

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = Path("uploads")
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024  # 8 MB


@router.post("/image")
async def upload_image(
    file: UploadFile,
    _current_user: UserModel = Depends(get_current_user),
):
    """Sube una imagen (foto de perfil, de moto o portada de ruta) y
    devuelve la URL relativa (`/uploads/<archivo>`) que se guarda luego en
    el registro correspondiente (usuario, moto o ruta). Servida como
    estático — ver `StaticFiles` montado en `app/main.py`.
    """
    extension = Path(file.filename or "").suffix.lower()
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Formato no soportado. Usa: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La imagen supera el tamaño máximo permitido (8 MB)",
        )

    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}{extension}"
    (UPLOAD_DIR / filename).write_bytes(contents)

    return {"url": f"/uploads/{filename}"}
