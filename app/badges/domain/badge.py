from dataclasses import dataclass


@dataclass
class Badge:
    id: str
    title: str
    description: str
    # Nombre de SF Symbol — el cliente iOS lo pinta directo, sin tener que
    # mantener su propio mapeo id → icono.
    icon: str
    achieved: bool
