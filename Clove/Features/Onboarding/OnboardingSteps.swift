import AppKit
import SwiftUI

struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 60, height: 60)
                .padding(.leading, -4)
                .padding(.bottom, 18)
                .accessibilityHidden(true)
            StepHeader(
                title: "Welcome to Clove",
                message: "Your Mac, from the disk down to the skills your agents use, in one calm place."
            )
            VStack(alignment: .leading, spacing: 14) {
                FeatureLine("internaldrive", "Storage", "shows what's filling your disk, and clears it safely.")
                FeatureLine("waveform.path.ecg", "Running", "lists agents, dev servers, and containers.")
                FeatureLine("square.stack.3d.up", "Skills", "from every agent, one shortcut away.")
                FeatureLine("lock", "Everything", "stays on this Mac. Nothing is uploaded.")
            }
        }
    }
}

private struct FeatureLine: View {
    let symbol: String
    let lead: String
    let rest: String

    init(_ symbol: String, _ lead: String, _ rest: String) {
        self.symbol = symbol
        self.lead = lead
        self.rest = rest
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
                .background(Palette.accent.opacity(0.1), in: .rect(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text("\(Text(lead).fontWeight(.semibold).foregroundStyle(Palette.ink)) \(Text(rest).foregroundStyle(Palette.inkSecondary))")
                .font(.system(size: 13))
        }
    }
}

// MARK: - License

/// The key from the purchase email. Next waits for it; activating moves on by itself.
struct LicenseStep: View {
    @Environment(AppModel.self) private var model
    let onActivated: () -> Void

    @State private var key = ""
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        let license = model.license

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: license.isUnlocked ? "Clove is unlocked" : "Unlock Clove",
                message: license.isUnlocked
                    ? "This Mac is activated. You can move the key to another Mac from Settings, About."
                    : "Enter the key from your purchase email. One key unlocks Clove on one Mac."
            )

            if let active = license.license {
                SettingCard(symbol: "key", title: "License", detail: "Active on this Mac · \(active.maskedKey)") {
                    StatusPill(text: "Active")
                }
            } else {
                keyForm(license)
            }
        }
        .animation(.snappy(duration: 0.25), value: license.failure)
        .onChange(of: license.isUnlocked) { _, unlocked in
            if unlocked { onActivated() }
        }
    }

    @ViewBuilder
    private func keyForm(_ license: LicenseStore) -> some View {
        let canActivate = !key.trimmingCharacters(in: .whitespaces).isEmpty && !license.isWorking

        VStack(alignment: .leading, spacing: 10) {
            Text("License key")
                .font(.callout.weight(.medium))
                .foregroundStyle(Palette.inkSecondary)

            HStack(spacing: 8) {
                TextField("License key", text: $key, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .focused($isKeyFocused)
                    .disabled(license.isWorking)
                    .onSubmit(activate)
                    .onChange(of: key) { license.failure = nil }

                Button(action: activate) {
                    ZStack {
                        Text("Activate").opacity(license.isWorking ? 0 : 1)
                        if license.isWorking { ProgressView().controlSize(.small) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canActivate)
            }

            if let failure = license.failure {
                Label(failure.message, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Palette.destructive)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            Link(destination: LicenseConfiguration.checkoutURL) {
                Text("Buy Clove \(Image(systemName: "arrow.up.right"))")
            }
            .font(.callout.weight(.medium))
            Text("One payment, no subscription.")
            Link("Clove is open source. Build it yourself for free.", destination: URL(string: "https://github.com/keshav-exe/clove#build-from-source")!)
        }
        .font(.caption)
        .foregroundStyle(Palette.inkTertiary)
        .tint(Palette.accent)
        .padding(.top, 24)
        .onAppear { isKeyFocused = true }
    }

    private func activate() {
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await model.license.activate(key: key) }
    }
}

// MARK: - Permissions

/// Each permission says what it unlocks. None is needed to go on, and each
/// turns into a checkmark the moment macOS grants it.
struct PermissionsStep: View {
    @State private var access = MacAccess.current()
    @State private var askedFullDisk = false
    @AppStorage("askedForFolders") private var askedFolders = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: "Allow what Clove needs",
                message: "macOS asks before Clove can see your files or type into other apps. Allow what you'll use; you can change any of it later."
            )

            VStack(spacing: 10) {
                SettingCard(symbol: "folder", title: "Your folders", detail: "Desktop, Documents, and Downloads, so Storage can measure them.") {
                    if access.folders || access.fullDisk {
                        StatusPill(text: "Allowed").arrives()
                    } else {
                        Button(askedFolders ? "Ask Again" : "Allow…") {
                            askedFolders = true
                            MacAccess.askForFolders()
                            access = MacAccess.current()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                SettingCard(symbol: "hand.raised", title: "Accessibility", detail: "So Clove can type a skill into your editor.") {
                    if access.accessibility {
                        StatusPill(text: "Allowed").arrives()
                    } else {
                        Button("Allow…") {
                            AccessibilityAccess.requestPrompt()
                            AccessibilityAccess.openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                SettingCard(symbol: "lock.shield", title: "Full Disk Access", detail: "Optional. Lets Storage see the Trash and your Library.") {
                    if access.fullDisk {
                        StatusPill(text: "Allowed").arrives()
                    } else {
                        Button("Allow…") {
                            askedFullDisk = true
                            StorageStore.openFullDiskAccessSettings()
                        }
                    }
                }
            }

            if askedFullDisk && !access.fullDisk {
                VStack(alignment: .leading, spacing: 10) {
                    NumberedRow(1, "Turn on Clove under Full Disk Access.")
                    NumberedRow(2, "macOS asks to quit and reopen Clove. Let it, and setup picks up here.")
                }
                .font(.system(size: 13))
                .padding(.top, 20)
                .arrives()
            }
        }
        // Checked once a second while this page is open, and not at all otherwise.
        .task {
            while !Task.isCancelled {
                let now = MacAccess.current(probeFolders: askedFolders)
                if now != access { access = now }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// What macOS has granted Clove. Folder access is only probed after Clove has
/// asked, because probing is what makes macOS ask.
struct MacAccess: Equatable {
    var accessibility: Bool
    var fullDisk: Bool
    var folders: Bool

    @MainActor
    static func current(probeFolders: Bool = UserDefaults.standard.bool(forKey: "askedForFolders")) -> MacAccess {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let trash = home.appending(path: ".Trash").path(percentEncoded: false)
        return MacAccess(
            accessibility: AccessibilityAccess.isGranted,
            fullDisk: (try? FileManager.default.contentsOfDirectory(atPath: trash)) != nil,
            folders: probeFolders && userFolders.allSatisfy { (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) != nil }
        )
    }

    private static var userFolders: [URL] {
        [.desktopDirectory, .documentsDirectory, .downloadsDirectory]
    }

    /// Reading each folder once is what brings up macOS's prompt for it.
    static func askForFolders() {
        for folder in userFolders {
            _ = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        }
    }
}

// MARK: - Shortcut

struct ShortcutStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: "One shortcut away",
                message: "Open the menu bar panel from any app. It holds whichever blocks you pick: Skills, Storage, Running, and more."
            )

            VStack(spacing: 10) {
                SettingCard(symbol: "command", title: "Panel shortcut", detail: "Works in every app.") {
                    KeyRecorderView(chord: $settings.hotKey)
                        .disabled(!settings.hotKeyEnabled)
                }

                SettingCard(symbol: "menubar.rectangle", title: "Menu bar icon", detail: "Click for the panel, right-click for every section.") {
                    Toggle("Menu bar icon", isOn: $settings.showMenuBarIcon)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            if settings.hotKeyEnabled, settings.hotKey != nil, !settings.hotKeyIsRegistered {
                Label("Another app already uses that shortcut. Pick a different one.", systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - Ready

struct ReadyStep: View {
    @Environment(UpdateService.self) private var updates
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        @Bindable var launch = launchAtLogin

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: "Almost ready",
                message: "Choose how Clove runs. Start Clove and it looks through your agents' folders and measures your disk."
            )

            VStack(spacing: 10) {
                SettingCard(symbol: "power", title: "Open at login", detail: "Clove is there whenever your Mac starts.") {
                    Toggle("Open at login", isOn: $launch.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingCard(symbol: "arrow.down.circle", title: "Install updates automatically", detail: "Downloads in the background, installs when Clove quits.") {
                    Toggle("Install updates automatically", isOn: Binding(
                        get: { updates.isAutomatic },
                        set: { updates.isAutomatic = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
        }
    }
}
