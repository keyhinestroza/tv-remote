import CoreGraphics
import Foundation

/// Convierte el recorrido de un dedo en teclas del control remoto.
///
/// Mientras dura el gesto dispara una tecla de dirección cada vez que el dedo avanza
/// `step` puntos desde la tecla anterior; el eje que más se haya movido decide cuál.
/// Un gesto que termina sin ninguna tecla es un toque: OK.
struct SwipeTracker {
    /// Puntos de desplazamiento por tecla de dirección.
    var step: CGFloat = 28
    /// Tiempo mínimo entre teclas. El TV dibuja cada movimiento del foco con su propia
    /// animación y encola lo que le llega de más: sin este freno sigue desplazándose
    /// varias posiciones después de levantar el dedo.
    var minInterval: TimeInterval = 0.15

    /// Teclas de dirección disparadas en el gesto actual.
    private var keys = 0
    /// El dedo salió del área: el resto del gesto se ignora.
    private var isCancelled = false
    /// Traducción en la última tecla: hace de cero móvil del acumulador.
    private var lastKey: CGSize = .zero
    /// Dónde empezó el gesto que se está midiendo; sirve para reconocer uno nuevo.
    private var start: CGPoint?
    /// Cuándo se disparó la última tecla, para no ir más rápido que el TV.
    private var lastKeyTime: Date?

    /// Dedo en movimiento. Devuelve la tecla de dirección que toque disparar, si la hay.
    /// Salirse de `size` cancela el gesto: a partir de ahí no dispara nada más.
    mutating func moved(translation: CGSize, from start: CGPoint, location: CGPoint, in size: CGSize, at time: Date) -> RemoteKey? {
        // SwiftUI no avisa cuando un gesto se cancela (app al fondo, vista deshabilitada
        // porque se cayó la conexión, gesto del sistema): entonces no llega `ended` y las
        // cuentas quedarían sucias. Cada gesto nuevo empieza de cero aquí.
        if start != self.start {
            self.start = start
            keys = 0
            isCancelled = false
            lastKey = .zero
            lastKeyTime = nil
        }

        guard !isCancelled else { return nil }
        guard CGRect(origin: .zero, size: size).contains(location) else {
            isCancelled = true
            return nil
        }

        // Desplazamiento desde la última tecla: el eje que más se movió manda.
        let dx = translation.width - lastKey.width
        let dy = translation.height - lastKey.height
        let key: RemoteKey
        if abs(dx) >= abs(dy) {
            guard abs(dx) >= step else { return nil }
            key = dx > 0 ? .right : .left
        } else {
            guard abs(dy) >= step else { return nil }
            key = dy > 0 ? .down : .up
        }

        // Demasiado pronto: se descarta el tramo recorrido en vez de encolarlo, para que
        // al levantar el dedo no queden teclas pendientes de camino al TV.
        lastKey = translation
        if let lastKeyTime, time.timeIntervalSince(lastKeyTime) < minInterval { return nil }

        keys += 1
        lastKeyTime = time
        return key
    }

    /// Dedo levantado. Un gesto que no llegó a mover el foco es un toque: OK.
    /// Deja las cuentas listas para el gesto siguiente.
    mutating func ended() -> RemoteKey? {
        let isTap = !isCancelled && keys == 0
        keys = 0
        isCancelled = false
        lastKey = .zero
        lastKeyTime = nil
        start = nil
        return isTap ? .ok : nil
    }
}
