import SwiftUI

/// Lo que se muestra al tocar el volumen.
enum VolumeCue: Equatable {
    /// Recordatorio del gesto, las primeras veces que se usa la app.
    case hint
    case up
    case down
    /// Silencio. nil cuando no se pudo leer el estado real del televisor.
    case mute(Bool?)
}

/// Los dos signos de volumen, uno encima del otro junto al borde izquierdo y a la altura
/// de los botones físicos del iPhone, o el icono de silencio.
///
/// No muestran el nivel del TV: no lo informa de verdad, responde siempre el mismo número
/// aunque el volumen cambie. El silencio sí es real.
struct VolumeSigns: View {
    let cue: VolumeCue

    var body: some View {
        switch cue {
        case .up, .down:
            VStack(spacing: 20) {
                sign("plus", label: "Raise volume", active: cue == .up)
                sign("minus", label: "Lower volume", active: cue == .down)
            }
        case .mute(let muted):
            sign(muted == false ? "speaker.wave.2.fill" : "speaker.slash.fill",
                 label: muted == false ? "Sound on" : "Muted",
                 active: muted != false)
        case .hint:
            EmptyView()
        }
    }

    private func sign(_ systemImage: String, label: LocalizedStringKey, active: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(active ? Color.black : Color.white)
            .frame(width: 44, height: 44)
            .background {
                if active {
                    Circle().fill(.white)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(active ? 0 : 0.13), lineWidth: 1))
            .scaleEffect(active ? 1.06 : 1)
            .accessibilityLabel(label)
    }
}

/// Recordatorio de que el volumen va con dos dedos. Sale sobre el panel las primeras
/// veces y desaparece para siempre en cuanto el usuario hace el gesto.
struct VolumeGestureHint: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 20, weight: .medium))
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Two fingers for volume")
                    .font(.subheadline.weight(.semibold))
                Text("Swipe up or down with two fingers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.13), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 28) {
        VolumeGestureHint()
        HStack(spacing: 40) {
            VolumeSigns(cue: .up)
            VolumeSigns(cue: .down)
            VolumeSigns(cue: .mute(true))
            VolumeSigns(cue: .mute(false))
        }
    }
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
