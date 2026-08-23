import ActivityKit
import SwiftUI
import WidgetKit

/// Vista de la Live Activity — pantalla de bloqueo/banner y Dynamic
/// Island. El target entero (`RydrRideWidgets`) tiene el deployment
/// target en iOS 16.1 (ver project.yml), así que aquí dentro no hace
/// falta `@available`: si el extension ni siquiera se instala en un
/// dispositivo más viejo.
struct RydrRideLiveActivity: Widget {
    // Mismo ámbar de marca que `AppTheme.primary` — la extensión no
    // puede importar el target de la app, así que se repite el valor
    // exacto en vez de compartir el archivo de colores entero.
    private static let brandColor = Color(red: 1, green: 0.690, blue: 0.125)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RydrRideActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.motorbikeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Self.timeString(context.state.elapsedSeconds))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Self.brandColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(String(format: "%.1f km", context.state.km), systemImage: "location.fill")
                        Spacer()
                        Label(String(format: "%.0f km/h", context.state.speedKmh), systemImage: "speedometer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(Self.brandColor)
            } compactTrailing: {
                Text(Self.timeString(context.state.elapsedSeconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Self.brandColor)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(Self.brandColor)
            }
            .widgetURL(URL(string: "rydrnav://register"))
            .keylineTint(Self.brandColor)
        }
    }

    fileprivate static func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct LockScreenView: View {
    let attributes: RydrRideActivityAttributes
    let state: RydrRideActivityAttributes.ContentState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grabando · \(attributes.motorbikeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(RydrRideLiveActivity.timeString(state.elapsedSeconds))
                    .font(.title.monospacedDigit().bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", state.km))
                    .foregroundStyle(.white)
                Text(String(format: "%.0f km/h", state.speedKmh))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding()
    }
}
