import AppKit
import SwiftUI

/// The design system for NoType.
///
/// Direction: Apple's Liquid Glass (macOS 26+). Content sits on calm, system backgrounds;
/// the controls that act on it — the recorder bar, the toolbar, the HUD — float above it on
/// glass that refracts what scrolls beneath. Every value a view needs lives here; components
/// never declare their own colors, sizes, radii or durations.
///
/// Light and dark are not two themes. Every color below is either a system semantic color or
/// a dynamic pair, and glass adapts to whatever is behind it, so a view is written once and
/// both appearances are correct by construction.
///
/// The rules that keep it native:
/// - Glass is for the control layer only. Lists and transcripts sit on regular backgrounds;
///   glass on content competes with the content.
/// - One brand tint. Red means recording and nothing else.
/// - Shapes are concentric and continuous: inner radius = outer radius − padding.
/// - Motion is springy and brief; glass morphs, it doesn't fade.
enum DS {

    // MARK: - Color

    enum Color {
        /// The NoType tint: a deep indigo-blue. Used for selection, links and the idle mic.
        static let accent = dynamic(light: 0x4F46E5, dark: 0x8B85FF)
        /// A lighter companion, used only in the waveform and the icon gradient.
        static let accentSoft = dynamic(light: 0x7C8CFF, dark: 0xA8B4FF)

        /// Recording. The only red in the app.
        static let record = SwiftUI.Color.red
        /// Corrections the dictionary applied — informative, not alarming.
        static let correction = SwiftUI.Color.orange
        /// Success feedback (copied, enabled).
        static let positive = SwiftUI.Color.green

        // Text — system semantics, which track appearance and Increase Contrast.
        static let ink = SwiftUI.Color.primary
        static let inkSecondary = SwiftUI.Color.secondary
        static let inkTertiary = SwiftUI.Color(nsColor: .tertiaryLabelColor)

        // Surfaces
        /// The window canvas behind content.
        static let canvas = SwiftUI.Color(nsColor: .windowBackgroundColor)
        /// A content card (transcript row, dictionary row) — one step off the canvas.
        static let card = dynamic(light: 0xFFFFFF, dark: 0x1E1E22, lightAlpha: 0.78, darkAlpha: 0.72)
        /// Card under the pointer.
        static let cardHover = dynamic(light: 0xFFFFFF, dark: 0x2A2A30, lightAlpha: 1, darkAlpha: 0.9)
        /// Hairline around cards. Barely there in light, a touch brighter in dark.
        static let stroke = dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.09)
        /// Inline chips (engine tag, correction badge background).
        static let chip = SwiftUI.Color(nsColor: .quaternaryLabelColor).opacity(0.5)


        // MARK: Dynamic resolution

        private static func dynamic(
            light: UInt32, dark: UInt32,
            lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
        ) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
            })
        }
    }

    // MARK: - Glass

    /// Liquid Glass variants. Views ask for a role, not a recipe.
    enum Glass {
        /// Non-interactive surfaces (recorder capsule, HUD). Interactive glass is reserved for
        /// things you can actually press; controls *inside* a glass surface are fills, never a
        /// second glass layer.
        static let passive = SwiftUI.Glass.regular
        /// The pill under the notch. Smoke-tinted like the Dynamic Island, so it reads as part
        /// of the notch it drops out of and stays legible over any wallpaper or window — plain
        /// glass takes its brightness from whatever is behind it, which a floating overlay
        /// can't predict.
        static let hud = SwiftUI.Glass.regular.tint(SwiftUI.Color.black.opacity(0.62))
    }

    // MARK: - Type

    /// SF Pro throughout — the system face is what makes glass read as native.
    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 26, weight: .bold)
        static let title = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let headline = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13.5)
        static let bodyEmphasis = SwiftUI.Font.system(size: 13.5, weight: .medium)
        static let callout = SwiftUI.Font.system(size: 12)
        static let caption = SwiftUI.Font.system(size: 11)
        static let captionEmphasis = SwiftUI.Font.system(size: 11, weight: .semibold)
        /// Section eyebrows ("TODAY", "TERMS").
        static let eyebrow = SwiftUI.Font.system(size: 10.5, weight: .semibold)
        static let eyebrowTracking: CGFloat = 0.6

        /// Timers and latencies. Rounded + monospaced digits so they don't jitter.
        static let timer = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
        static let metric = SwiftUI.Font.system(size: 11, weight: .medium, design: .rounded).monospacedDigit()

        /// The HUD's live transcript.
        static let hud = SwiftUI.Font.system(size: 13.5, weight: .medium)
    }

    // MARK: - Spacing

    /// A 4pt grid.
    enum Space {
        static let hair: CGFloat = 2
        static let tight: CGFloat = 4
        static let snug: CGFloat = 8
        static let base: CGFloat = 12
        static let roomy: CGFloat = 16
        static let wide: CGFloat = 20
        static let section: CGFloat = 28
    }

    // MARK: - Radius

    /// Continuous corners, chosen to nest: a control inset by `Space.tight` inside a card uses `control`.
    enum Radius {
        static let chip: CGFloat = 6
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let bar: CGFloat = 26
    }

    // MARK: - Border

    enum Border {
        static let hairline: CGFloat = 0.5
        /// The outline of a keycap hint.
        static let keycap: CGFloat = 1
    }

    // MARK: - Size

    enum Size {
        /// The recorder capsule, and the record button inset inside it. Concentric:
        /// `barHeight - 2 * barInset == recordButton`.
        static let barHeight: CGFloat = 56
        static let barInset: CGFloat = 6
        static let recordButton: CGFloat = 44
        static let iconButton: CGFloat = 26
        static let waveformHeight: CGFloat = 28
        static let waveformBarWidth: CGFloat = 3
        static let waveformBarGap: CGFloat = 3
        static let barWaveformBars = 16
        static let hudWaveformBars = 12
        static func waveformWidth(bars: Int) -> CGFloat {
            CGFloat(bars) * waveformBarWidth + CGFloat(bars - 1) * waveformBarGap
        }
        /// Fixed slots in the recorder capsule, so it never resizes as text changes.
        static let barStatusWidth: CGFloat = 220
        /// Wide enough for "00:00" in `Font.timer`; the text is also fixed-size so it can
        /// never wrap.
        static let barTrailingWidth: CGFloat = 64

        // HUD — the pill under the notch.
        static let hudWidth: CGFloat = 340
        static let hudHeight: CGFloat = 52
        /// The red mic badge at the pill's leading edge, inset concentrically.
        static let hudBadge: CGFloat = 36
        static let hudWaveformHeight: CGFloat = 20
        /// Room around the pill inside its panel, for the glass shadow and the spring's
        /// overshoot. Transparent and click-through.
        static let hudMargin: CGFloat = 24
        /// Gap between the bottom of the notch (or menu bar) and the top of the pill.
        static let hudNotchGap: CGFloat = 8
        /// Where the pill starts from when it appears: tucked up into the notch, smaller.
        static let hudEnterScale: CGFloat = 0.55
        static let hudEnterOffset: CGFloat = -28
        static let sidebarMin: CGFloat = 190
        static let contentMaxWidth: CGFloat = 760
        static let windowMinWidth: CGFloat = 760
        static let windowMinHeight: CGFloat = 520
        static let settingsWidth: CGFloat = 500
        static let editorWidth: CGFloat = 440
    }

    // MARK: - Elevation

    enum Shadow {
        /// Cards are almost flat; the hairline does most of the work.
        static let card = Spec(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)

        struct Spec {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }

    // MARK: - Motion

    enum Motion {
        /// Glass morphs, selection moves, rows appear.
        static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
        /// Button press response.
        static let pressScale: CGFloat = 0.92
        static let pressDim: Double = -0.06
        /// Quick state changes: hover, copy confirmation.
        static let snappy = Animation.snappy(duration: 0.2)
        /// Live text updates in the HUD.
        static let text = Animation.easeOut(duration: 0.12)
        /// The HUD emerging from the notch, and retracting into it. Critically damped enough
        /// to settle without wobble, with a hint of overshoot so it feels physical.
        static let hudIn = Animation.spring(response: 0.42, dampingFraction: 0.78)
        static let hudOut = Animation.spring(response: 0.32, dampingFraction: 1)
        /// How long to keep the panel on screen after `hudOut` starts, before ordering it out.
        static let hudOutDuration: Duration = .milliseconds(380)
        /// Reduce Motion: a plain cross-fade instead.
        static let hudFade = Animation.easeInOut(duration: 0.18)
        /// How long "Copied" stays before reverting.
        static let copyConfirm: Duration = .seconds(1.4)
        /// Waveform ripple speed (radians per second) and frame cap.
        static let waveSpeed: Double = 7
        static let waveformEnvelope: Double = 0.7
        /// Exponent applied to the 0…1 level before drawing; < 1 lifts quiet input.
        static let waveformGamma: Double = 0.5
        static let waveFrameRate: Double = 60
    }
}

// MARK: - Shadow helper

extension View {
    func shadow(_ spec: DS.Shadow.Spec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}

// MARK: - Hex helpers

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
