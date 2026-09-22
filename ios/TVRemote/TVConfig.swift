import Foundation

/// Claves con las que se guardan los datos del TV elegido.
///
/// La app no trae ningún televisor preconfigurado: todo sale de la búsqueda en la red
/// o de lo que el usuario escriba en Ajustes.
enum TVConfig {
    /// Versión actual de la guía de inicio.
    static let guideVersion = 2

    enum Keys {
        static let ip = "tvIP"
        static let mac = "tvMAC"
        /// Nombre y modelo del TV elegido, solo para mostrarlos en la ayuda.
        static let name = "tvName"
        static let model = "tvModel"
        /// Versión de la guía que el usuario ya vio. Al subirla, la guía vuelve a salir
        /// una vez, que es como se entera de lo que cambió.
        static let guideVersion = "guiaVersion"
        /// Cuántas veces se mostró el recordatorio del gesto del volumen.
        static let volumeHintCount = "avisoVolumen"
        /// true en cuanto el usuario usa el gesto: el recordatorio ya no hace falta.
        static let volumeGestureUsed = "gestoVolumenUsado"
    }
}
