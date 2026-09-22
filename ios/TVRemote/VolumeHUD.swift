import SwiftUI

/// Los dos signos de volumen, uno encima del otro junto al borde izquierdo y a la altura
/// de los botones físicos del iPhone.
///
/// Aparecen al abrir la app, para que se vea de dónde sale el volumen sin tener que leer
/// un aviso, y en cada pulsación resaltando el que se acaba de pulsar. No muestran el nivel
/// del TV: no lo informa de verdad, responde siempre 32 aunque el volumen cambie.
struct VolumeSigns: View {
    /// true resalta el de subir, false el de bajar, nil no resalta ninguno.
    let highlighted: Bool?

    var body: some View {
        VStack(spacing: 20) {
            sign("plus", label: "Raise volume", active: highlighted == true)
            sign("minus", label: "Lower volume", active: highlighted == false)
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

#Preview {
    HStack(spacing: 40) {
        VolumeSigns(highlighted: nil)
        VolumeSigns(highlighted: true)
        VolumeSigns(highlighted: false)
    }
    .padding(40)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
