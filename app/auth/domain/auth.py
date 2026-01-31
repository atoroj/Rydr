from dataclasses import dataclass

@dataclass
class Auth:
    email: str
    password_hash: str
    role: str