"""Excepciones de dominio compartidas entre módulos.

`ValueError` se sigue usando tal cual para errores de validación/estado
genuinos (p. ej. "la quedada ya está completa") — eso no cambia. Lo que
faltaba era distinguir "el recurso no existe" (404) de esos casos: antes
los dos usaban `ValueError`, y el router no podía saber cuál de los dos
era sin mirar el texto del mensaje — lo que en la práctica hacía que
varios endpoints devolvieran 400 cuando el recurso simplemente no
existía (debería ser 404). Ver los routers de `meetups`/`riders` para
los casos reales que esto corrige.
"""


class NotFoundError(Exception):
    """El recurso pedido (quedada, usuario, moto...) no existe — 404."""
