import SwiftUI
import UIKit

/// Gestos del panel táctil, con UIKit porque SwiftUI no distingue cuántos dedos hay
/// en pantalla y aquí eso es justo lo que separa mover el foco de cambiar el volumen.
///
/// Un dedo mueve y selecciona; dos dedos suben y bajan el volumen, y un toque con dos
/// dedos silencia. Los cuatro reconocedores conviven sin pisarse: los de toque exigen
/// un número exacto de dedos y los de arrastre también.
struct PadGestures: UIViewRepresentable {
    /// Mientras sea false el panel no responde (por ejemplo, sin conexión con el TV).
    let isEnabled: Bool
    /// Un dedo arrastrando: traducción desde el inicio, punto actual y momento.
    let move: (CGSize, CGPoint, Date) -> Void
    let moveEnded: () -> Void
    /// Dos dedos arrastrando, con los mismos datos.
    let volume: (CGSize, CGPoint, Date) -> Void
    let volumeEnded: () -> Void
    let select: () -> Void
    let mute: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let coordinator = context.coordinator

        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.panned))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1

        let twoFingerPan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pannedWithTwo))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tapped))
        tap.numberOfTouchesRequired = 1

        let twoFingerTap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tappedWithTwo))
        twoFingerTap.numberOfTouchesRequired = 2

        for recognizer in [pan, twoFingerPan, tap, twoFingerTap] as [UIGestureRecognizer] {
            view.addGestureRecognizer(recognizer)
        }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        view.isUserInteractionEnabled = isEnabled
    }

    final class Coordinator {
        var parent: PadGestures

        init(_ parent: PadGestures) { self.parent = parent }

        @objc func panned(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .changed:
                parent.move(size(recognizer.translation(in: view)), recognizer.location(in: view), Date())
            case .ended, .cancelled, .failed:
                parent.moveEnded()
            default:
                break
            }
        }

        @objc func pannedWithTwo(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .changed:
                // Solo cuenta el recorrido vertical: subir y bajar, nada de laterales.
                let translation = recognizer.translation(in: view)
                parent.volume(CGSize(width: 0, height: translation.y), recognizer.location(in: view), Date())
            case .ended, .cancelled, .failed:
                parent.volumeEnded()
            default:
                break
            }
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.select()
        }

        @objc func tappedWithTwo(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.mute()
        }

        private func size(_ point: CGPoint) -> CGSize {
            CGSize(width: point.x, height: point.y)
        }
    }
}
