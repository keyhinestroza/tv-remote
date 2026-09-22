import SwiftUI

/// Zona táctil única que sustituye a la cruceta: se desliza para navegar y se toca
/// para seleccionar, como el trackpad del mando del Apple TV. Con dos dedos, el mismo
/// panel sube y baja el volumen del televisor.
///
/// No conoce al cliente del TV: avisa por `direction`, `select`, `volume` y `mute`,
/// así que el resto de la app sigue recibiendo las mismas teclas.
struct TouchPad: View {
    let direction: (RemoteKey) -> Void
    let select: () -> Void
    /// true para subir el volumen, false para bajarlo.
    let volume: (Bool) -> Void
    let mute: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var tracker = SwipeTracker()
    /// Un acumulador aparte para el volumen: su recorrido no debe mezclarse con el del foco.
    @State private var volumeTracker = SwipeTracker(step: 24)
    /// Cambian con cada tecla para disparar la vibración.
    @State private var directionCount = 0
    @State private var selectCount = 0

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                surface
                    .overlay(gestures(in: geometry.size))
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
        // VoiceOver se queda con los gestos, así que las teclas van aparte: arriba y abajo
        // como ajuste, y todas como acciones, para que el rotor baste por sí solo.
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
        .accessibilityAction(named: "Raise volume") { volume(true) }
        .accessibilityAction(named: "Lower volume") { volume(false) }
        .accessibilityAction(named: "Mute") { mute() }
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

    // MARK: - Gestos

    private func gestures(in size: CGSize) -> some View {
        PadGestures(
            isEnabled: isEnabled,
            move: { translation, location, time in
                let key = tracker.moved(translation: translation, from: .zero, location: location, in: size, at: time)
                if let key { fire(key) }
            },
            moveEnded: {
                // Un arrastre corto que no llegó a mover el foco cuenta como toque.
                if let key = tracker.ended() { fire(key) }
            },
            volume: { translation, location, time in
                let key = volumeTracker.moved(translation: translation, from: .zero, location: location, in: size, at: time)
                guard let key else { return }
                directionCount += 1
                volume(key == .up)
            },
            volumeEnded: {
                // Aquí no hay "toque": un arrastre con dos dedos sin pasos no hace nada.
                _ = volumeTracker.ended()
            },
            select: {
                selectCount += 1
                select()
            },
            mute: {
                selectCount += 1
                mute()
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
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
    TouchPad(direction: { print($0.rawValue) }, select: { print("OK") },
             volume: { print($0 ? "vol +" : "vol -") }, mute: { print("mute") })
        .padding(32)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
