import SwiftUI

/// Zona táctil única que sustituye a la cruceta: se desliza para navegar y se toca
/// para seleccionar, como el trackpad del mando del Apple TV.
///
/// No conoce al cliente del TV: avisa por `direction` y `select`, así que el resto
/// de la app sigue recibiendo las mismas teclas KEY_UP/DOWN/LEFT/RIGHT/ENTER.
struct TouchPad: View {
    let direction: (RemoteKey) -> Void
    let select: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var tracker = SwipeTracker()
    /// Cambian con cada tecla para disparar la vibración.
    @State private var directionCount = 0
    @State private var selectCount = 0

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                surface
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .gesture(drag(in: geometry.size))
            }
            // Se queda con todo el espacio que le deje el resto del mando, y en pantallas
            // pequeñas encoge hasta este mínimo en vez de empujar los botones fuera.
            .frame(minHeight: 140, maxHeight: .infinity)

            Text("Swipe to move · tap to select")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .opacity(isEnabled ? 1 : 0.35)
        .sensoryFeedback(.impact(weight: .light), trigger: directionCount)
        .sensoryFeedback(.selection, trigger: selectCount)
        .accessibilityElement()
        .accessibilityLabel("Touch area")
        .accessibilityHint("Swipe up or down to move, use the actions for the rest, and double tap to select")
        // VoiceOver se queda con el gesto de deslizar, así que las teclas van aparte:
        // arriba y abajo como ajuste, y las cinco como acciones, para que el rotor
        // baste por sí solo sin tener que cambiar de modo.
        .accessibilityAdjustableAction { adjustment in
            switch adjustment {
            case .increment: fire(.up)
            case .decrement: fire(.down)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Up") { fire(.up) }
        .accessibilityAction(named: "Down") { fire(.down) }
        .accessibilityAction(named: "Left") { fire(.left) }
        .accessibilityAction(named: "Right") { fire(.right) }
        .accessibilityAction(named: "Select") { fire(.ok) }
        .accessibilityAction { fire(.ok) }
    }

    // MARK: - Aspecto

    private var surface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        }
    }

    // MARK: - Gesto

    private func drag(in size: CGSize) -> some Gesture {
        // minimumDistance 0: el toque también entra por aquí, así no hay dos gestos compitiendo.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let key = tracker.moved(
                    translation: value.translation,
                    from: value.startLocation,
                    location: value.location,
                    in: size,
                    at: value.time
                )
                if let key { fire(key) }
            }
            .onEnded { _ in
                if let key = tracker.ended() { fire(key) }
            }
    }

    private func fire(_ key: RemoteKey) {
        if key == .ok {
            selectCount += 1
            select()
        } else {
            directionCount += 1
            direction(key)
        }
    }
}

#Preview {
    TouchPad(direction: { print($0.rawValue) }, select: { print("OK") })
        .padding(32)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
