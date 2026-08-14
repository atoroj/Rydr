from dataclasses import dataclass

@dataclass
class User:
    id: int | None
    email: str
    username: str
    password: str
    role: str
    avatar_url: str | None = None
    is_private: bool = False