# La racha de semanas depende de `date.today()` — no se puede simular
# creando rides por HTTP (`started_at` lo pone el propio backend a
# `datetime.now()`, no es un campo que se pueda mandar). Aquí se prueba
# directamente la función pura, con fechas relativas a hoy, en vez de
# forzar el flujo HTTP para algo que no está pensado para eso.
from datetime import date, timedelta

from app.badges.application.badge_service import BadgeService


def weeks_ago(n: int) -> date:
    return date.today() - timedelta(weeks=n)


def test_streak_zero_with_no_rides():
    assert BadgeService._current_week_streak([]) == 0


def test_streak_one_with_a_ride_this_week():
    assert BadgeService._current_week_streak([date.today()]) == 1


def test_streak_counts_consecutive_weeks():
    dates = [weeks_ago(0), weeks_ago(1), weeks_ago(2)]
    assert BadgeService._current_week_streak(dates) == 3


def test_streak_stops_at_a_gap():
    # Esta semana, la pasada, y luego un hueco antes de una racha vieja —
    # solo debe contar las dos consecutivas más recientes.
    dates = [weeks_ago(0), weeks_ago(1), weeks_ago(5), weeks_ago(6)]
    assert BadgeService._current_week_streak(dates) == 2


def test_streak_has_one_week_grace_period():
    # Nada esta semana todavía, pero sí la pasada y la anterior — la racha
    # sigue viva (no se rompe a las 00:00 del lunes).
    dates = [weeks_ago(1), weeks_ago(2)]
    assert BadgeService._current_week_streak(dates) == 2


def test_streak_broken_if_two_weeks_without_a_ride():
    # Ni esta semana ni la pasada — la racha se ha roto de verdad.
    dates = [weeks_ago(2), weeks_ago(3)]
    assert BadgeService._current_week_streak(dates) == 0


def test_streak_ignores_multiple_rides_same_week():
    # Lunes de esta semana + el día siguiente — garantizado en la misma
    # semana ISO pase lo que pase (a diferencia de "ayer"/"anteayer" desde
    # `date.today()`, que cruzan de semana si hoy es lunes o martes).
    monday = date.today() - timedelta(days=date.today().weekday())
    dates = [monday, monday + timedelta(days=1)]
    assert BadgeService._current_week_streak(dates) == 1
