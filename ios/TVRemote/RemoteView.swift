import SwiftUI

/// Pantalla principal: el control remoto.
struct RemoteView: View {
    @EnvironmentObject private var client: TVRemoteClient
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(TVConfig.Keys.ip) private var ip = ""
    @AppStorage(TVConfig.Keys.mac) private var mac = ""

    @State private var showSettings = false
    /// true cuando se abre Ajustes para buscar el TV, no para escribir la IP.
    @State private var searchOnOpenSettings = false
    @State private var showGuide = false
    @AppStorage(TVConfig.Keys.guideVersion) private var guideVersion = 0
    @AppStorage(TVConfig.Keys.volumeGestureUsed) private var volumeGestureUsed = false
    @State private var showKeypad = false
    /// Cambia con cada pulsación para disparar la vibración.
    @State private var tapCount = 0
    /// Lo que se muestra ahora sobre el panel, si hay algo.
    @State private var volumeCue: VolumeCue?
    /// Cambia con cada aviso para reiniciar la cuenta atrás que lo oculta.
    @State private var volumeCueID = 0

    private var isConnected: Bool { client.state == .connected }
    private var hasTV: Bool { !ip.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 20) {
            topBar
            if hasTV {
                remote
            } else {
                ContentUnavailableView {
                    Label("No TV set up", systemImage: "tv")
                } description: {
                    Text("Enter your TV's address to get started.")
                } actions: {
                    Button("Find my TV") { searchOnOpenSettings = true; showSettings = true }
                    Button("Type the address") { showSettings = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        // A la izquierda y arriba, donde el pulgar espera el volumen.
        .overlay(alignment: .topLeading) {
            if let volumeCue, volumeCue != .hint {
                VolumeSigns(cue: volumeCue)
                    .padding(.top, 104)
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .overlay(alignment: .center) {
            if volumeCue == .hint {
                VolumeGestureHint()
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.snappy(duration: 0.2), value: volumeCue)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .sheet(isPresented: $showSettings) {
            searchOnOpenSettings = false
            client.connect(host: ip)
            // Si acaba de configurar el TV, este es el primer momento en que hay panel.
            remindVolumeGesture()
        } content: {
            SettingsView(searchOnOpen: searchOnOpenSettings)
        }
        .sheet(isPresented: $showGuide) {
            guideVersion = TVConfig.guideVersion
            // Al cerrar la guía toca el recordatorio: antes quedaba tapado por ella.
            remindVolumeGesture()
        } content: {
            GuideView(onSearch: {
                searchOnOpenSettings = true
                showSettings = true
            })
        }
        .sheet(isPresented: $showKeypad) {
            KeypadView(press: press)
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.visible)
        }
        // Conecta al abrir, al volver a primer plano y al cerrar ajustes (por si cambió la IP).
        .onAppear {
            client.connect(host: ip)
            // La guía sale la primera vez, cuando trae novedades y mientras no haya TV.
            if guideVersion < TVConfig.guideVersion || !hasTV {
                showGuide = true
            } else {
                remindVolumeGesture()
            }
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                if client.state == .disconnected { client.connect(host: ip) }
                remindVolumeGesture()
            case .background:
                client.disconnect()
            default:
                break
            }
        }
    }

    // MARK: - Secciones

    /// Ajustes, estado de la conexión y encendido, agrupados en una sola píldora.
    private var topBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 10) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Settings")

                statusButton

                Button(action: powerTapped) {
                    Image(systemName: "power")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.red.opacity(0.16)))
                }
                .accessibilityLabel("Power")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    /// Estado de la conexión. Al tocarlo desconectado, reintenta.
    private var statusButton: some View {
        Button {
            if client.state == .disconnected { client.connect(host: ip) }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .fixedSize()
        }
        .accessibilityLabel("Connection: \(statusText)")
        .accessibilityHint("Double tap to reconnect")
    }

    private var remote: some View {
        VStack(spacing: 20) {
            TouchPad(
                direction: { client.sendKey($0) },
                select: { client.sendKey(.ok) },
                volume: volumeChanged,
                mute: muteTapped
            )
            .disabled(!isConnected)
                // Un 10% más ancho que el resto del mando: se come parte del margen lateral.
                .padding(.horizontal, -18)

            if let error = client.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // El volumen va por los botones físicos del iPhone, así que aquí no hay teclas de volumen.
            HStack(alignment: .bottom, spacing: 28) {
                RoundKey(systemImage: "circle.grid.3x3", label: "Options", size: 60) { showKeypad = true }
                RoundKey(systemImage: "chevron.backward", label: "Back", size: 80) { press(.back) }
                RoundKey(systemImage: "house", label: "Home", size: 60) { press(.home) }
            }
            .disabled(!isConnected)
        }
        .frame(maxHeight: .infinity)
        .opacity(isConnected ? 1 : 0.85)
        .task(id: volumeCueID) {
            guard let volumeCue else { return }
            try? await Task.sleep(for: .seconds(volumeCue == .hint ? 3.5 : 1.2))
            if !Task.isCancelled { self.volumeCue = nil }
        }
    }

    /// Ya traducido: se muestra con `Text(variable)`, que no traduce por su cuenta.
    private var statusText: String {
        switch client.state {
        case .connected:
            client.isStandby ? Localization.string("TV asleep") : Localization.string("Connected")
        case .connecting: Localization.string("Connecting…")
        case .disconnected: Localization.string("Disconnected")
        }
    }

    private var statusColor: Color {
        switch client.state {
        case .connected: client.isStandby ? .orange : .green
        case .connecting: .orange
        case .disconnected: .red
        }
    }

    // MARK: - Acciones

    /// Muestra algo sobre el panel. Cada aviso reinicia la cuenta atrás que lo oculta.
    private func show(_ cue: VolumeCue) {
        volumeCue = cue
        volumeCueID += 1
    }

    /// Volumen con dos dedos en el panel.
    private func volumeChanged(up: Bool) {
        volumeGestureUsed = true
        client.sendKey(up ? .volumeUp : .volumeDown)
        show(up ? .up : .down)
    }

    /// Silencio con dos dedos. El estado que se muestra se le pregunta al televisor,
    /// que es el único que lo sabe de verdad.
    private func muteTapped() {
        volumeGestureUsed = true
        client.sendKey(.mute)
        show(.mute(nil))
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let muted = await TVMute.isMuted(host: ip)
            if volumeCue != nil, muted != nil { show(.mute(muted)) }
        }
    }

    /// Recordatorio del gesto: cada vez que se abre la app, hasta que el usuario lo use.
    /// A partir de ahí no vuelve a salir: ya sabe hacerlo.
    private func remindVolumeGesture() {
        guard hasTV, !volumeGestureUsed, !showGuide else { return }
        show(.hint)
    }

    private func press(_ key: RemoteKey) {
        tapCount += 1
        client.sendKey(key)
    }

    /// El cliente decide entre KEY_POWER y Wake-on-LAN según el estado real del TV.
    private func powerTapped() {
        tapCount += 1
        client.togglePower(host: ip, mac: mac)
    }
}

// MARK: - Componentes

/// Estilo común: fondo gris oscuro que se aclara y encoge al pulsar.
private struct KeyStyle<S: Shape>: ButtonStyle {
    let shape: S
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(shape.fill(Color.white.opacity(configuration.isPressed ? 0.28 : 0.12)))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Botón circular con icono y etiqueta opcional debajo.
private struct RoundKey: View {
    let systemImage: String
    /// Texto bajo el botón. Si no hay, se usa `name` para VoiceOver.
    var label: LocalizedStringKey? = nil
    var name: LocalizedStringKey? = nil
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
            }
            .buttonStyle(KeyStyle(shape: Circle()))
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? name ?? LocalizedStringKey(systemImage))
    }
}

/// Teclado numérico y las teclas que no caben en la pantalla principal,
/// mostrados como hoja inferior.
private struct KeypadView: View {
    let press: (RemoteKey) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        VStack(spacing: 24) {
            // El volumen también está aquí, además de en los botones físicos del iPhone.
            HStack(spacing: 24) {
                RoundKey(systemImage: "minus", label: "Vol −", size: 56) { press(.volumeDown) }
                RoundKey(systemImage: "speaker.slash", label: "Mute", size: 56) { press(.mute) }
                RoundKey(systemImage: "plus", label: "Vol +", size: 56) { press(.volumeUp) }
            }

            HStack(spacing: 24) {
                RoundKey(systemImage: "chevron.down", label: "CH −", size: 56) { press(.channelDown) }
                RoundKey(systemImage: "rectangle.on.rectangle", label: "Source", size: 56) { press(.source) }
                RoundKey(systemImage: "chevron.up", label: "CH +", size: 56) { press(.channelUp) }
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...9, id: \.self) { digitKey($0) }
                Color.clear.frame(height: 1)
                digitKey(0)
                Color.clear.frame(height: 1)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func digitKey(_ n: Int) -> some View {
        Button {
            if let key = RemoteKey.digit(n) { press(key) }
        } label: {
            Text("\(n)")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(KeyStyle(shape: Capsule()))
    }
}

#Preview {
    RemoteView()
        .environmentObject(TVRemoteClient())
        .preferredColorScheme(.dark)
}
