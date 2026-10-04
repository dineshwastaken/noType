import AppKit
import Observation
import SwiftUI

/// Whether the pill is showing. The panel flips this; the view animates on it.
///
/// Animation lives in SwiftUI rather than on the window's alpha so the pill can emerge from
/// the notch — scaling and sliding down from it — instead of merely fading in place.
@MainActor
@Observable
final class HUDModel {
    var isPresented = false
}

/// The pill that appears under the notch while you dictate.
///
/// The single most important property here is that this panel **never becomes key**.
/// If it did, the user's text field would lose focus and `TextInjector` would have
/// nothing to insert into. Hence `.nonactivatingPanel` plus `canBecomeKey == false`.
@MainActor
final class HUDPanel: NSPanel {
    private let model = HUDModel()
    private var hideTask: Task<Void, Never>?

    init(controller: DictationController) {
        super.init(
            // The pill plus a transparent, click-through margin for its shadow and the
            // spring's overshoot.
            contentRect: NSRect(
                x: 0, y: 0,
                width: DS.Size.hudWidth + DS.Size.hudMargin * 2,
                height: DS.Size.hudHeight + DS.Size.hudMargin * 2
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        let host = NSHostingView(rootView: HUDView(controller: controller, model: model))
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Centers the pill horizontally under the notch, `hudNotchGap` below it.
    ///
    /// On a screen without a notch (an external display, or a Mac without one) the menu bar
    /// stands in for it, so the pill sits just under the menu bar in the same place.
    func reposition() {
        guard let screen = Self.targetScreen else {
            Log.app.error("no screen available to position HUD")
            return
        }
        let frame = screen.frame
        let pillTop = frame.maxY - screen.topObstructionHeight - DS.Size.hudNotchGap
        let notchMidX = screen.notchFrame?.midX ?? frame.midX
        setFrameOrigin(NSPoint(
            x: (notchMidX - self.frame.width / 2).rounded(),
            y: (pillTop + DS.Size.hudMargin - self.frame.height).rounded()
        ))
    }

    func present() {
        hideTask?.cancel()
        hideTask = nil
        // Every active state change (starting → listening → finishing) calls this; once the
        // pill is up, leave it alone rather than re-running the entrance.
        guard !model.isPresented else { return }

        reposition()
        orderFrontRegardless()
        withAnimation(Self.reduceMotion ? DS.Motion.hudFade : DS.Motion.hudIn) {
            model.isPresented = true
        }
    }

    func dismiss() {
        guard model.isPresented else { return }
        withAnimation(Self.reduceMotion ? DS.Motion.hudFade : DS.Motion.hudOut) {
            model.isPresented = false
        }
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: DS.Motion.hudOutDuration)
            guard let self, !Task.isCancelled, !self.model.isPresented else { return }
            self.orderOut(nil)
        }
    }

    /// The display you're working on: the one holding the focused window, else the one
    /// under the pointer, else the built-in one.
    private static var targetScreen: NSScreen? {
        NSScreen.main ?? NSScreen.withMouse ?? NSScreen.screens.first
    }

    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

// MARK: - Notch geometry

extension NSScreen {
    static var withMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }

    /// The camera housing, from the two menu-bar areas either side of it. nil without a notch.
    var notchFrame: NSRect? {
        // Widths only: they're unambiguous regardless of which coordinate space the areas
        // are reported in.
        guard let left = auxiliaryTopLeftArea?.width, let right = auxiliaryTopRightArea?.width,
              safeAreaInsets.top > 0
        else { return nil }
        let height = safeAreaInsets.top
        return NSRect(
            x: frame.minX + left,
            y: frame.maxY - height,
            width: frame.width - left - right,
            height: height
        )
    }

    /// How far down from the top edge the pill has to start: the notch where there is one,
    /// otherwise the menu bar (even when it auto-hides, so the pill doesn't jump).
    var topObstructionHeight: CGFloat {
        if safeAreaInsets.top > 0 { return safeAreaInsets.top }
        let menuBar = frame.maxY - visibleFrame.maxY
        return menuBar > 0 ? menuBar : NSStatusBar.system.thickness
    }
}
