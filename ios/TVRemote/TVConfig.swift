import Foundation

/// Claves con las que se guardan los datos del TV elegido.
///
/// La app no trae ningún televisor preconfigurado: todo sale de la búsqueda en la red
/// o de lo que el usuario escriba en Ajustes.
enum TVConfig {
    enum Keys {
        static let ip = "tvIP"
        static let mac = "tvMAC"
        /// Nombre y modelo del TV elegido, solo para mostrarlos en la ayuda.
        static let name = "tvName"
        static let model = "tvModel"
        /// true cuando el usuario ya vio la guía de inicio.
        static let guideSeen = "guiaVista"
    }
}
