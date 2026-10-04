import ServiceManagement
import SwiftUI

/// Settings — opens on ⌘, via the standard `Settings` scene, so the system wires up the menu
/// item and the shortcut. A grouped form: on macOS 26 that is already the glass look, and
/// anything custom here would only make it look less native.
struct SettingsWindow: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
                Picker("Push-to-talk key", selection: Binding(
                    get: { settings.pushToTalkKey },
                    set: { key in
                        settings.pushToTalkKey = key
                        controller.reloadHotkey()
                    }
                )) {
                    ForEach(PushToTalkKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Dictation")
            } footer: {
                note("Hold this key anywhere to dictate. The mic button in the main window works "
                    + "regardless of what's focused.")
            }

            Section {
                Picker("Speech model", selection: $settings.engine) {
                    Text("Apple").tag(SpeechEngineChoice.apple)
                    Text("Parakeet").tag(SpeechEngineChoice.parakeet)
                }
                .pickerStyle(.segmented)
            } footer: {
                note(settings.engine == .apple
                    ? "Apple's on-device transcriber. Streams text while you speak; no download."
                    : "Parakeet on the Neural Engine. Resolves on release; ~470 MB model.")
            }

            Section {
                Toggle("Clean up transcripts", isOn: $settings.cleanupEnabled)
                Toggle("Smart cleanup (on-device AI)", isOn: $settings.smartCleanup)
                    .disabled(!settings.cleanupEnabled || !FoundationModelFormatter.isAvailable)
            } header: {
                Text("Cleanup")
            } footer: {
                note(FoundationModelFormatter.unavailableReason
                    ?? "Strips fillers, fixes spacing and punctuation. The dictionary's corrections run either way.")
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { opensAtLogin },
                    set: { setOpensAtLogin($0) }
                ))
                Toggle("Show in Dock", isOn: $settings.showInDock)
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Play sounds", isOn: $settings.soundEnabled)
            } header: {
                Text("General")
            } footer: {
                note(loginItemError
                    ?? "NoType runs from the menu bar. It has to be running for the hotkey to work — "
                    + "Open at login takes care of that.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: DS.Size.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .tint(DS.Color.accent)
    }

    /// Registers NoType as a login item with macOS, so it also appears (and can be turned
    /// off) in System Settings ▸ General ▸ Login Items.
    private func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't change the login item: \(error.localizedDescription)"
        }
        let status = SMAppService.mainApp.status
        opensAtLogin = status == .enabled
        if status == .requiresApproval {
            loginItemError = "Approve NoType in System Settings ▸ General ▸ Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
