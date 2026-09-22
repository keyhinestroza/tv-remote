import SwiftUI

/// Ajustes: el TV elegido, el idioma y la ayuda.
struct SettingsView: View {
    /// true para empezar a buscar televisores nada más abrir los ajustes.
    var searchOnOpen = false

    @EnvironmentObject private var client: TVRemoteClient
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TVConfig.Keys.ip) private var ip = ""
    @AppStorage(TVConfig.Keys.mac) private var mac = ""
    @AppStorage(TVConfig.Keys.name) private var tvName = ""
    @AppStorage(TVConfig.Keys.model) private var tvModel = ""

    @AppStorage(Localization.key) private var language = AppLanguage.automatic.rawValue
    @StateObject private var discovery = TVDiscovery()
    @State private var tokenForgotten = false

    private var macIsValid: Bool { WakeOnLAN.magicPacket(mac: mac) != nil }

    /// Búsqueda automática: evita tener que mirar la IP en los menús del TV.
    private var discoverySection: some View {
        Section {
            ForEach(discovery.found) { tv in
                Button {
                    ip = tv.ip
                    if let found = tv.mac { mac = found }
                    tvName = tv.name
                    tvModel = tv.model ?? ""
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tv.name)
                                .foregroundStyle(.primary)
                            Text([tv.model, tv.ip].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if tv.ip == ip {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            Button {
                Task { await discovery.search() }
            } label: {
                HStack {
                    Label(discovery.found.isEmpty ? "Find my TV" : "Search again",
                          systemImage: "antenna.radiowaves.left.and.right")
                    if discovery.isSearching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(discovery.isSearching)
        } header: {
            Text("Search the network")
        } footer: {
            if discovery.isSearching {
                Text(discovery.status)
            } else if discovery.found.isEmpty {
                Text("The TV must be on and on the same Wi-Fi as the iPhone. Choosing it fills in the address and the MAC.")
            } else {
                Text("Tap your TV to use it.")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                discoverySection

                Section {
                    LabeledContent("IP") {
                        TextField("192.168.1.6", text: $ip)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("MAC") {
                        TextField("aa:bb:cc:dd:ee:ff", text: $mac)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    .autocorrectionDisabled()
                } header: {
                    Text("Television")
                } footer: {
                    if !mac.isEmpty && !macIsValid {
                        Text("The MAC needs 12 hexadecimal digits.")
                            .foregroundStyle(.red)
                    } else {
                        Text("The MAC is only used to turn the TV on over the network.")
                    }
                }

                Section {
                    Picker(selection: $language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.name).tag(option.rawValue)
                        }
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                } footer: {
                    Text("With the system language the app follows the iPhone; any language other than Spanish or English shows in English.")
                }

                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help and setup guide", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    Button("Forget authorisation", role: .destructive) {
                        client.forgetToken(host: ip)
                        tokenForgotten = true
                    }
                    .disabled(tokenForgotten)
                } footer: {
                    // Con un operador ternario el compilador puede tomar el texto como
                    // literal sin traducir; separados, cada uno es una clave.
                    if tokenForgotten {
                        Text("Authorisation cleared. The TV will ask again on the next connection.")
                    } else {
                        Text("Clears the authorisation saved in the iPhone's Keychain for this TV.")
                    }
                }
            }
            .task { if searchOnOpen { await discovery.search() } }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environmentObject(TVRemoteClient())
}
