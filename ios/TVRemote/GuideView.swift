import SwiftUI

/// Guía de inicio. Sale la primera vez que se abre la app y siempre que no haya un TV
/// configurado; también se puede volver a ver desde Ajustes.
struct GuideView: View {
    /// Se llama si el usuario termina la guía con "Find my TV".
    var onSearch: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private var pages: [GuidePage] { GuidePage.all }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    GuidePageView(page: page, isVisible: self.page == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if page == pages.count - 1 {
                Button {
                    dismiss()
                    onSearch?()
                } label: {
                    Text("Find my TV")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)

                Button("I'll do it later") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .animation(.snappy, value: page)
    }
}

/// Una pantalla de la guía: un símbolo grande, un título y una lista de puntos.
struct GuidePage {
    let symbol: String
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let points: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)]

    static let all: [GuidePage] = [
        GuidePage(
            symbol: "appletvremote.gen4",
            title: "Your remote, on the iPhone",
            summary: "Control your smart TV over your home network. No internet and no original remote needed.",
            points: [
                ("wifi", "It all stays on your network", "The iPhone talks to the TV directly; nothing goes out to the internet."),
                ("bolt", "No Bluetooth pairing", "They just need to be on the same network."),
            ]
        ),
        GuidePage(
            symbol: "checklist",
            title: "Before you start",
            summary: "Four things so the TV shows up first time.",
            points: [
                ("power", "Turn the TV on", "Fully switched off it does not answer, and the app cannot find it."),
                ("wifi.router", "The same network", "The iPhone and the TV on the same Wi-Fi. If your router has a guest network, do not use it."),
                ("lock.shield", "Allow the local network", "iOS asks the first time. Without that permission the app cannot see the TV."),
                ("tv.badge.wifi", "Accept it on the TV", "The first connection asks for permission on the TV screen: accept it with its own remote."),
            ]
        ),
        GuidePage(
            symbol: "hand.draw",
            title: "How it works",
            summary: "El panel grande hace de touchpad, como el mando del Apple TV.",
            points: [
                ("hand.point.up.left", "Swipe and tap", "Swipe to move the focus through the TV menu and tap to select."),
                ("arrow.up.and.down", "Volume", "Two fingers on the panel, up or down. The next screen explains it."),
                ("power", "Red button", "Turns the TV on and off. Just switched off it answers at once; after a while it takes a few seconds."),
                ("circle.grid.3x3", "Options", "Channel numbers, mute, channels and the input source."),
            ]
        ),
        GuidePage(
            symbol: "hand.draw",
            title: "Volume with two fingers",
            summary: "The panel does two jobs at once, and the number of fingers decides which.",
            points: [
                ("hand.point.up.left", "One finger", "Moves the focus through the menu and selects, as always."),
                ("arrow.up.and.down", "Two fingers up or down", "Raise and lower the TV volume. A mark appears on the left with each step."),
                ("speaker.slash", "Two-finger tap", "Mutes and unmutes."),
                ("circle.grid.3x3", "Also in Options", "If you would rather press a button, the volume is there too."),
            ]
        ),
        GuidePage(
            symbol: "sparkles",
            title: "One setting worth changing",
            summary: "To turn the TV on after a while switched off, enable this once on the television.",
            points: [
                ("gearshape", "On the TV", "Settings › General › Network › Expert Settings › Power On with Mobile."),
                ("powerplug", "Why", "After a few minutes the TV sleeps completely and only wakes with that setting on."),
                ("magnifyingglass", "That's it", "Search for your TV and the app fills in the address by itself; nothing to copy."),
            ]
        ),
    ]
}

/// Contenido de una pantalla, con la animación de entrada.
private struct GuidePageView: View {
    let page: GuidePage
    let isVisible: Bool

    @State private var shown = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: isVisible)
                .frame(height: 72)
                .scaleEffect(shown ? 1 : 0.7)
                .opacity(shown ? 1 : 0)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text(page.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(shown ? 1 : 0)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(page.points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(point.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(point.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 12)
                    .animation(.snappy(duration: 0.35).delay(Double(index) * 0.07 + 0.1), value: shown)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: isVisible, initial: true) {
            withAnimation(.snappy(duration: 0.35)) { shown = isVisible }
        }
    }
}

#Preview {
    GuideView()
}
