import AVFoundation
import MediaPlayer
import SwiftUI

/// Hace que los botones físicos de volumen del iPhone suban y bajen el volumen del TV.
///
/// iOS no tiene ninguna API pública para esto: `AVCaptureEventInteraction` es la única que
/// entrega las pulsaciones y exige una sesión de cámara en marcha, así que aquí no sirve.
/// Lo que queda es la técnica de siempre, que no es un contrato con el sistema y puede
/// dejar de funcionar en cualquier versión de iOS:
/// - un `MPVolumeView` dentro de la jerarquía de vistas (fuera de ella no funciona) y con
///   alpha mayor que cero, que es lo que evita que salga el aviso de volumen de iOS;
/// - la sesión de audio activa, para que los botones muevan el volumen de medios;
/// - KVO sobre `outputVolume` para enterarse de cada pulsación, y dejar el volumen otra vez
///   en la mitad: en 0 o en 1 el sistema ya no avisaría y se perdería la pulsación.
///
/// Solo funciona con la app en primer plano y en un iPhone real, no en el simulador.
struct VolumeButtons: UIViewRepresentable {
    /// Mientras sea false, los botones vuelven a controlar el volumen del iPhone.
    let isActive: Bool
    /// Se llama en cada pulsación: true si fue el botón de subir.
    let onPress: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPress: onPress) }

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.showsVolumeSlider = true
        view.isUserInteractionEnabled = false
        // Invisible a la vista pero no para el sistema: con alpha 0 volvería a salir el aviso.
        view.alpha = 0.01
        context.coordinator.volumeView = view
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        context.coordinator.onPress = onPress
        if isActive {
            context.coordinator.start()
        } else {
            context.coordinator.stop()
        }
    }

    static func dismantleUIView(_ view: MPVolumeView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onPress: (Bool) -> Void
        weak var volumeView: MPVolumeView?

        /// Punto de reposo del volumen del sistema. Una pulsación mueve ~1/16, así que
        /// nunca cae justo aquí: recibir este valor significa que el cambio lo hicimos
        /// nosotros al recolocarlo.
        private let anchor: Float = 0.5
        /// iOS redondea el volumen que informa, así que no se busca el paso exacto;
        /// esto solo descarta los movimientos mínimos (cambios de ruta de audio).
        private let minimumStep: Float = 0.03
        private var observation: NSKeyValueObservation?
        /// Volumen que tenía el iPhone antes de empezar, para devolverlo al salir.
        private var previousVolume: Float?

        init(onPress: @escaping (Bool) -> Void) {
            self.onPress = onPress
        }

        func start() {
            guard observation == nil else { return }
            let session = AVAudioSession.sharedInstance()
            // .mixWithOthers para no cortar lo que el usuario esté escuchando. Si algún día
            // dejara de avisar, lo siguiente que probar es .ambient o reproducir silencio.
            try? session.setCategory(.playback, options: [.mixWithOthers])
            try? session.setActive(true)

            previousVolume = slider?.value ?? session.outputVolume
            setSystemVolume(anchor)

            observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
                guard let self, let volume = change.newValue else { return }
                Task { @MainActor in self.volumeChanged(to: volume) }
            }
        }

        func stop() {
            guard observation != nil else { return }
            observation = nil
            let previous = previousVolume
            previousVolume = nil
            // Primero se devuelve el volumen que tenía el iPhone y solo después se suelta la
            // sesión de audio: al revés, el sistema ya no acepta el cambio.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                if let previous { self?.slider?.value = previous }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                }
            }
        }

        @MainActor
        private func volumeChanged(to volume: Float) {
            guard abs(volume - anchor) > minimumStep else { return }  // nuestra propia recolocación
            onPress(volume > anchor)
            setSystemVolume(anchor)
        }

        private var slider: UISlider? {
            volumeView?.subviews.compactMap { $0 as? UISlider }.first
        }

        private func setSystemVolume(_ value: Float) {
            // Fuera del aviso de KVO: cambiarlo dentro no siempre se aplica.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.slider?.value = value
            }
        }
    }
}
