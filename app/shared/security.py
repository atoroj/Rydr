from datetime import datetime, timedelta
from typing import Optional
from jose import jwt
import bcrypt
import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM")
ACCES_TOKEN_EXPIRE_MINUTES = 30

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Compara contraseña plana con hash.
    """
    password_byte_enc = plain_password.encode('utf-8')
    hashed_password_byte_enc = hashed_password.encode('utf-8')
    
    return bcrypt.checkpw(password_byte_enc, hashed_password_byte_enc)

def get_password_hashed(password: str) -> str:
    """
    Genera un hash seguro.
    Devuelve un string (decoded) para guardar fácil en la BD.
    """
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed_password = bcrypt.hashpw(pwd_bytes, salt)
    
    # Devolvemos string, no bytes, para que SQLAlchemy lo guarde bien
    return hashed_password.decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Crea un JSON Web Token (JWT).
    :param data: Diccionario con los datos a guardar en el token (ej: {"sub": "email", "role": "admin"})
    :param expires_delta: Tiempo opcional de expiración.
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now() + expires_delta
    else:
        expire = datetime.now() + timedelta(minutes=ACCES_TOKEN_EXPIRE_MINUTES)
        
    to_encode.update({"exp": expire})
    
    encode_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encode_jwt