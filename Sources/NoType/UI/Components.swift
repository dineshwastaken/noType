import AppKit
import SwiftUI

// The shared vocabulary of the app: cards, chips, the waveform, the record button.
// Every value here comes from `DS`. If a component needs a number that isn't a token, the
// token is missing — add it there rather than inlining it.

// MARK: - Surfaces

/// A content card: one calm step off the canvas, hairline edge, nearly flat.
/// Content, not chrome — so it is deliberately *not* glass.
struct CardBackground: View {
    var isHovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
            .fill(isHovering ? DS.Color.cardHover : DS.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Color.stroke, lineWidth: DS.Border.hairline)
            )
            .shadow(DS.Shadow.card)
    }
}

// MARK: - Labels

/// Small uppercase section label.
struct Eyebrow: View {
    let text: String
    var color: Color = DS.Color.inkSecondary

    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.eyebrow)
            .tracking(DS.Font.eyebrowTracking)
            .foregroundStyle(color)
    }
}

/// A small capsule tag — engine name, entry kind.
struct Chip: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(DS.Font.captionEmphasis)
            .foregroundStyle(tint ?? DS.Color.inkSecondary)
            .padding(.horizontal, DS.Space.snug)
            .padding(.vertical, DS.Space.hair)
            .background(
                Capsule().fill(tint.map { $0.opacity(0.14) } ?? DS.Color.chip)
            )
    }
}

// MARK: - Controls

/// A borderless icon button for row actions (copy, edit, delete).
struct IconButton: View {
    let systemImage: String
    let help: String
    var tint: Color = DS.Color.inkSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DS.Font.callout.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: DS.Size.iconButton, height: DS.Size.iconButton)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

/// Copies text to the pasteboard and flips to a checkmark briefly.
struct CopyButton: View {
    let text: String
    @State private var didCopy = false

    var body: some View {
        IconButton(
            systemImage: didCopy ? "checkmark" : "doc.on.doc",
            help: "Copy",
            tint: didCopy ? DS.Color.positive : DS.Color.inkSecondary
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(DS.Motion.snappy) { didCopy = true }
            Task {
                try? await Task.sleep(for: DS.Motion.copyConfirm)
                withAnimation(DS.Motion.snappy) { didCopy = false }
            }
        }
        .contentTransition(.symbolEffect(.replace))
    }
}

/// The round glass record button: brand-tinted glass at rest, red glass while recording,
/// with the glyph morphing between mic and stop. Sized explicitly so it lines up exactly with
/// the recorder capsule beside it.
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(DS.Font.title)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: DS.Size.recordButton, height: DS.Size.recordButton)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(isRecording ? DS.Glass.recordActive : DS.Glass.recordIdle, in: .circle)
        .help(isRecording ? "Stop recording" : "Start recording")
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

// MARK: - Instrumentation

/// Level-reactive bars. Each bar gets a fixed phase offset so the group ripples rather than
/// pumping in unison; at rest the bars settle to dots.
struct Waveform: View {
    /// Current input level, 0...1.
    let level: Float
    let isActive: Bool
    var barCount = DS.Size.barWaveformBars
    var tint: Color = DS.Color.accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / DS.Motion.waveFrameRate, paused: !isActive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: DS.Size.waveformBarGap) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(tint.opacity(isActive ? 1 : 0.35))
                            .frame(
                                width: DS.Size.waveformBarWidth,
                                height: height(for: index, at: time, max: proxy.size.height)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(DS.Motion.snappy, value: isActive)
    }

    private func height(for index: Int, at time: TimeInterval, max maxHeight: CGFloat) -> CGFloat {
        let floor = DS.Size.waveformBarWidth
        guard isActive else { return floor }

        // Irrational multiplier keeps the offsets from lining up into a visible period.
        let phase = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
        let wave = sin(time * DS.Motion.waveSpeed + phase * .pi * 2)
        // Center-weighted envelope so the shape reads as a voice, not a bar chart.
        let center = Double(barCount - 1) / 2
        let envelope = 1 - pow(abs(Double(index) - center) / (center + 1), 2) * DS.Motion.waveformEnvelope
        let amplitude = Swift.max(0.06, Double(level))
        let scaled = amplitude * envelope * (0.55 + 0.45 * wave)
        return floor + CGFloat(Swift.max(0, scaled)) * (maxHeight - floor)
    }
}

// MARK: - Empty state

struct EmptyPanel: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
