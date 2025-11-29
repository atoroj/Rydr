from dataclasses import dataclass

@dataclass
class User:
    id: int | None
    email: str
    username: str
    password: str