import SwiftUI

@main
struct TVRemoteApp: App {
    /// Un único cliente compartido por toda la app.
    @StateObject private var client = TVRemoteClient()
    /// Cambiarlo vuelve a dibujar la app entera en el otro idioma.
    @AppStorage(Localization.key) private var language = AppLanguage.automatic.rawValue

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
                .environment(\.locale, Localization.locale)
        }
    }
}
