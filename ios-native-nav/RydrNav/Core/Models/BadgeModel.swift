import Foundation

/// Espejo de app/badges/application/badge_dto.py.
struct BadgeModel: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    /// Nombre de SF Symbol — lo decide el backend, así el cliente no
    /// mantiene su propio mapeo id → icono.
    let icon: String
    let achieved: Bool
}
