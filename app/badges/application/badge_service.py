from dataclasses import dataclass
from datetime import date, timedelta
from typing import Callable, List

from app.badges.domain.badge import Badge
from app.meetups.domain.meetup_repository import MeetupRepository
from app.rides.domain.ride_repository import RideRepository


@dataclass
class _RiderStats:
    finished_ride_count: int
    week_streak: int
    meetups_joined_count: int


@dataclass
class _BadgeDefinition:
    id: str
    title: str
    description: str
    icon: str
    rule: Callable[[_RiderStats], bool]


class BadgeService:
    """Insignias por constancia, no por velocidad — a propósito: premiar a
    quien va más rápido en vía pública no es algo que esta app quiera
    fomentar, así que ninguna regla mira la velocidad de ningún ride.

    Se calculan al vuelo contra datos que ya existen (rides, quedadas),
    sin tabla ni job propios: a esta escala un repaso puntual de los
    rides/quedadas de un rider es barato de sobra, y así no hay estado de
    "insignias" que se pueda desincronizar de los datos reales.
    """

    _DEFINITIONS: List[_BadgeDefinition] = [
        _BadgeDefinition(
            "primera_ruta", "Primera ruta", "Graba tu primera ruta",
            "flag.checkered", lambda s: s.finished_ride_count >= 1),
        _BadgeDefinition(
            "diez_rutas", "10 rutas grabadas", "Graba 10 rutas",
            "road.lanes", lambda s: s.finished_ride_count >= 10),
        _BadgeDefinition(
            "cincuenta_rutas", "50 rutas grabadas", "Graba 50 rutas",
            "map", lambda s: s.finished_ride_count >= 50),
        _BadgeDefinition(
            "racha_2", "2 semanas seguidas", "Sal al menos una vez por semana, dos semanas seguidas",
            "flame", lambda s: s.week_streak >= 2),
        _BadgeDefinition(
            "racha_4", "Un mes seguido", "Sal al menos una vez por semana, cuatro semanas seguidas",
            "flame.fill", lambda s: s.week_streak >= 4),
        _BadgeDefinition(
            "racha_12", "3 meses seguidos", "Sal al menos una vez por semana, doce semanas seguidas",
            "trophy", lambda s: s.week_streak >= 12),
        _BadgeDefinition(
            "primera_quedada", "Primera quedada", "Apúntate a tu primera quedada",
            "person.3", lambda s: s.meetups_joined_count >= 1),
        _BadgeDefinition(
            "cinco_quedadas", "5 quedadas", "Apúntate a 5 quedadas",
            "person.3.fill", lambda s: s.meetups_joined_count >= 5),
    ]

    def __init__(self, ride_repo: RideRepository, meetup_repo: MeetupRepository):
        self.ride_repo = ride_repo
        self.meetup_repo = meetup_repo

    def get_badges(self, rider_id: int) -> List[Badge]:
        stats = self._stats_for(rider_id)
        return [
            Badge(id=d.id, title=d.title, description=d.description, icon=d.icon, achieved=d.rule(stats))
            for d in self._DEFINITIONS
        ]

    def _stats_for(self, rider_id: int) -> _RiderStats:
        finished_rides = [r for r in self.ride_repo.get_by_rider_id(rider_id) if r.finished_at is not None]
        ride_dates = [r.started_at.date() for r in finished_rides]
        return _RiderStats(
            finished_ride_count=len(finished_rides),
            week_streak=self._current_week_streak(ride_dates),
            meetups_joined_count=len(self.meetup_repo.list_joined_by(rider_id)),
        )

    @staticmethod
    def _current_week_streak(ride_dates: List[date]) -> int:
        """Semanas ISO consecutivas con al menos un ride, contando hacia
        atrás desde la semana actual. Con un margen de una semana: si esta
        semana todavía no has salido pero la pasada sí, la racha sigue
        "viva" hasta que acabe la semana en curso — no se rompe a las
        00:00 del lunes solo porque todavía no te ha dado tiempo."""
        if not ride_dates:
            return 0
        week_keys = {BadgeService._iso_week_key(d) for d in ride_dates}
        cursor = date.today()
        if BadgeService._iso_week_key(cursor) not in week_keys:
            cursor -= timedelta(days=7)
            if BadgeService._iso_week_key(cursor) not in week_keys:
                return 0
        streak = 0
        while BadgeService._iso_week_key(cursor) in week_keys:
            streak += 1
            cursor -= timedelta(days=7)
        return streak

    @staticmethod
    def _iso_week_key(d: date) -> tuple:
        iso_year, iso_week, _ = d.isocalendar()
        return (iso_year, iso_week)
