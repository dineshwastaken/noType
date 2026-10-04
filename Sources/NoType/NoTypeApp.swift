import AppKit
import SwiftUI

@main
struct NoTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The main window. A `Window` rather than a `WindowGroup`: this app has one main
        // window, and ⌘N belongs to "Add dictionary entry", not a second copy of it.
        Window("NoType", id: "main") {
            MainWindow(controller: delegate.controller)
        }
        // A menu bar app: launching starts it quietly. The window opens from the menu bar
        // item, from double-clicking the app, and once on the very first launch.
        .defaultLaunchBehavior(.suppressed)
        .defaultSize(width: 920, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Reveal Dictionary File") {
                    NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
                }
            }
        }

        // Fully qualified: this app has its own `Settings` type, which otherwise shadows
        // SwiftUI's settings scene.
        SwiftUI.Settings {
            SettingsWindow(controller: delegate.controller)
        }

        // The app's home: status, the main window, settings and quick toggles.
        MenuBarExtra {
            MenuContent(controller: delegate.controller)
        } label: {
            MenuBarIcon(controller: delegate.controller, delegate: delegate)
        }

        Window("Engine comparison", id: "comparison") {
            ComparisonWindow(controller: delegate.controller)
        }
        .defaultSize(width: 640, height: 560)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    private var hud: HUDPanel?
    private var stateObservation: NSObjectProtocol?

    /// Opens the main window. Set by the menu bar icon, the one view that exists for the
    /// app's whole lifetime and so can hand out SwiftUI's `openWindow` to AppKit callers.
    var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app by default (LSUIElement); the Dock icon is a setting. The HUD is a
        // non-activating panel either way, so dictating into another app never steals its
        // focus — that property belongs to the panel, not to the activation policy.
        Settings.shared.applyActivationPolicy()
        Settings.shared.applyAppearance()

        hud = HUDPanel(controller: controller)

        // If the tap can't be installed yet, the controller keeps waiting for the grant
        // and arms itself when it lands; this only raises the system prompt.
        if !controller.activate() {
            Permissions.promptForAccessibility()
        }

        // Parakeet's models take ~20s to load from disk, and that cost lands on whichever
        // dictation touches them first — so the first hold after every launch would stall
        // with the HUD showing nothing. Warm them in the background instead, but only when
        // they're actually going to be used and are already downloaded.
        let willUseParakeet = Settings.shared.compareMode || Settings.shared.engine == .parakeet
        if willUseParakeet, ParakeetModels.isDownloaded {
            Task.detached(priority: .utility) {
                _ = try? await ParakeetModels.shared.manager()
            }
        }

        // Every `make install` relaunches the app and drops its windows. Restoring the
        // window when it was open last time keeps it from vanishing on each rebuild.
        if UserDefaults.standard.bool(forKey: "comparisonWindowOpen") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                Self.showComparisonWindow()
            }
        }

        observeState()
        Log.app.info("NoType ready — hold \(Settings.shared.pushToTalkKey.displayName) to dictate")
    }

    /// Double-clicking the app (or `open -a NoType`) while it's running shows the window —
    /// with no Dock icon, that's the only way back to it besides the menu bar.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { openMainWindow?() }
        return true
    }

    /// Closing the window leaves NoType running in the menu bar, which is where the hotkey
    /// lives.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// `notype://show` raises the comparison window — a scriptable way in. There is
    /// deliberately no URL that deletes anything: any web page can open a custom-scheme link.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "notype" && url.host == "show" {
            Self.showComparisonWindow()
        }
    }

    /// Raises the comparison window without needing SwiftUI's `openWindow` environment
    /// value — usable from the app delegate and from a URL handler.
    static func showComparisonWindow() {
        RunStore.shared.reload()
        if let existing = NSApp.windows.first(where: { $0.title == "Engine comparison" }) {
            existing.makeKeyAndOrderFront(nil)
        }
        NSApp.activate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        let isOpen = NSApp.windows.contains { $0.title == "Engine comparison" && $0.isVisible }
        UserDefaults.standard.set(isOpen, forKey: "comparisonWindowOpen")
        controller.deactivate()
    }

    /// Shows and hides the HUD in step with the controller's state.
    private func observeState() {
        withObservationTracking {
            _ = controller.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.controller.state.isActive {
                    self.hud?.present()
                } else {
                    self.hud?.dismiss()
                }
                self.observeState()
            }
        }
    }

}

/// The menu bar icon. Also the bridge that lets AppKit code open the main window: it lives
/// as long as the app does and has SwiftUI's `openWindow` in its environment.
private struct MenuBarIcon: View {
    @Bindable var controller: DictationController
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    private static let hasLaunchedKey = "hasLaunchedBefore"

    var body: some View {
        Image(systemName: controller.state.isActive ? "waveform.circle.fill" : "waveform")
            .onAppear {
                delegate.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                // Show the window once, on the very first launch, so a new user isn't left
                // looking for an app with no Dock icon.
                if !UserDefaults.standard.bool(forKey: Self.hasLaunchedKey) {
                    UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
                    delegate.openMainWindow?()
                }
            }
    }
}

private struct MenuContent: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared
    @Environment(\.openWindow) private var openWindow
    @State private var isPreloadingParakeet = false
    @State private var parakeetOnDisk = ParakeetModels.isDownloaded

    private var parakeetStatus: String {
        if isPreloadingParakeet { return "Loading Parakeet models…" }
        // Reflects what's actually on disk, not just what this menu instance has done.
        return parakeetOnDisk ? "Parakeet models installed ✓" : "Download Parakeet models…"
    }

    private func preloadParakeet() {
        guard !isPreloadingParakeet else { return }
        isPreloadingParakeet = true
        Task {
            do {
                _ = try await ParakeetModels.shared.manager()
                parakeetOnDisk = ParakeetModels.isDownloaded
            } catch {
                Log.speech.error("Parakeet preload failed: \(error.localizedDescription)")
            }
            isPreloadingParakeet = false
        }
    }

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("Hold \(settings.pushToTalkKey.displayName) to dictate")

        Divider()

        Button("Open NoType") {
            openWindow(id: "main")
            NSApp.activate()
        }
        .keyboardShortcut("o")

        Button("Settings…") {
            // A menu bar app isn't active when its menu is clicked, so bring it forward or
            // the Settings window opens behind whatever you were using.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

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

        Toggle("Compare mode (both engines)", isOn: $settings.compareMode)

        if !settings.compareMode {
            Picker("Engine", selection: $settings.engine) {
                ForEach(SpeechEngineChoice.allCases, id: \.self) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        }

        Toggle("Clean up text", isOn: $settings.cleanupEnabled)

        if settings.cleanupEnabled {
            Toggle("Smart cleanup (on-device AI)", isOn: $settings.smartCleanup)
                .disabled(!FoundationModelFormatter.isAvailable)
            if let reason = FoundationModelFormatter.unavailableReason {
                Text(reason).font(.caption)
            }
        }

        Toggle("Sound", isOn: $settings.soundEnabled)

        Divider()

        Button("Show comparison window") {
            RunStore.shared.reload()
            openWindow(id: "comparison")
            NSApp.activate()
        }
        .keyboardShortcut("d")

        // Downloading ~470 MB on the first hold would look like a hang, so offer to do it
        // deliberately instead.
        if settings.engine == .parakeet || settings.compareMode {
            Button(parakeetStatus) { preloadParakeet() }
                .disabled(isPreloadingParakeet || parakeetOnDisk)
        }

        if !Permissions.hasAccessibility {
            Button("Grant Accessibility…") { Permissions.openAccessibilitySettings() }
        }
        if !Permissions.hasMicrophone {
            Button("Grant Microphone…") { Permissions.openMicrophoneSettings() }
        }

        Button("Quit NoType") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
