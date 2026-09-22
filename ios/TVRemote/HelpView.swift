import SwiftUI

/// Ayuda: cómo se usa, qué hacer si algo falla y datos de la app y del TV.
struct HelpView: View {
    @AppStorage(TVConfig.Keys.ip) private var ip = ""
    @AppStorage(TVConfig.Keys.mac) private var mac = ""
    @AppStorage(TVConfig.Keys.name) private var tvName = ""
    @AppStorage(TVConfig.Keys.model) private var tvModel = ""
    @State private var showGuide = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                Button {
                    showGuide = true
                } label: {
                    Label("See the setup guide", systemImage: "sparkles")
                }
            }

            Section("How it works") {
                help("hand.point.up.left", "The big panel",
                     "Swipe to move the focus through the TV menu and tap anywhere to select. The longer the swipe, the further it moves.")
                help("speaker.wave.2", "Volume",
                     "Swipe up or down on the panel with two fingers. A two-finger tap mutes. The volume is also in Options, with buttons.")
                help("power", "Turning the TV on and off",
                     "The red button. Just after switching off the TV answers at once; after a while the app wakes it over the network and it takes a few seconds.")
                help("circle.grid.3x3", "Options",
                     "Channel numbers, mute, channel up and down, and the input source.")
                help("circle.fill", "The coloured dot",
                     "Green: connected. Orange: connecting, or the TV is asleep. Red: no connection. Tap it to retry.")
            }

            Section("If something goes wrong") {
                trouble("The TV does not show up",
                        "Turn it on before searching: fully switched off it does not answer. Check that the iPhone is on the same Wi-Fi, not the guest network. If your router splits the bands, use the same one as the TV.")
                trouble("It says “Disconnected”",
                        "Tap the status to retry. If the TV changed address, the app finds it again by its MAC and switches over. If it stays that way, search for the TV again in Settings.")
                trouble("It will not turn the TV on",
                        "The TV needs this turned on: Settings › General › Network › Expert Settings › Power On with Mobile. And it has to stay plugged in and on the same network.")
                trouble("The TV asks for permission every time",
                        "That means the authorisation could not be saved. Accept the prompt on the TV with its own remote; if it keeps happening, use “Forget authorisation” in Settings and connect again.")
            }

            Section("Your television") {
                if !tvName.isEmpty {
                    LabeledContent("Name", value: tvName)
                }
                LabeledContent("Address", value: ip.isEmpty ? Localization.string("not set") : ip)
                LabeledContent("MAC", value: mac.isEmpty ? Localization.string("not set") : mac)
                if !tvModel.isEmpty {
                    LabeledContent("Model", value: tvModel)
                }
            }

            Section {
                LabeledContent("Version", value: version)
            } header: {
                Text("About")
            } footer: {
                Text("Everything happens inside your network: the app talks to the TV directly and sends nothing to the internet. The TV's authorisation is kept in the iPhone's Keychain.")
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGuide) { GuideView() }
    }

    private func help(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func trouble(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        DisclosureGroup(title) {
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack { HelpView() }
        .preferredColorScheme(.dark)
}
