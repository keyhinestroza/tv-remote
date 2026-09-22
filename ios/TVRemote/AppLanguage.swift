import Foundation
import SwiftUI

/// Idioma de la app. Por defecto el del iPhone; si no es ninguno de los que la app
/// habla, queda en inglés (es el idioma base del catálogo de textos).
enum AppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case spanish
    case english

    var id: String { rawValue }

    /// Código del idioma, o nil cuando manda el del iPhone.
    var code: String? {
        switch self {
        case .automatic: nil
        case .spanish: "es"
        case .english: "en"
        }
    }

    /// Nombre en su propio idioma, que es como se espera ver un selector de idioma.
    var name: LocalizedStringKey {
        switch self {
        case .automatic: "System language"
        case .spanish: "Español"
        case .english: "English"
        }
    }
}

/// Resuelve el idioma elegido: el paquete y la región con los que se buscan los textos.
///
/// Las vistas lo aplican con `\.locale` en el entorno; lo que nace fuera de una vista
/// (los errores del cliente, el estado de la búsqueda) tiene que pedir aquí su texto,
/// porque `String(localized:)` a secas usaría el idioma del sistema.
enum Localization {
    static let key = "appLanguage"

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .automatic
    }

    /// Región para el entorno de SwiftUI.
    static var locale: Locale {
        guard let code = selected.code else { return .autoupdatingCurrent }
        return Locale(identifier: code)
    }

    /// Paquete del idioma elegido, o el principal si manda el iPhone.
    static var bundle: Bundle {
        guard let code = selected.code,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    /// Texto traducido al idioma elegido, para usar fuera de las vistas.
    static func string(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle)
    }
}
