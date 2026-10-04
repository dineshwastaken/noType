import SwiftUI

/// The pill under the notch: a live waveform and transcript on Liquid Glass.
///
/// It enters the way the Dynamic Island expands — scaling and dropping down out of the notch
/// on a spring — and retracts back up into it. With Reduce Motion on it simply cross-fades.
struct HUDView: View {
    @Bindable var controller: DictationController
    let model: HUDModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        pill
            .scaleEffect(model.isPresented || reduceMotion ? 1 : DS.Size.hudEnterScale, anchor: .top)
            .offset(y: model.isPresented || reduceMotion ? 0 : DS.Size.hudEnterOffset)
            .opacity(model.isPresented ? 1 : 0)
            .blur(radius: model.isPresented || reduceMotion ? 0 : DS.Space.snug)
            // Pinned to the top of the panel so the pill grows downward from the notch.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, DS.Size.hudMargin)
    }

    private var pill: some View {
        HStack(spacing: DS.Space.base) {
            ZStack {
                Circle().fill(isError ? DS.Color.record.opacity(0.18) : DS.Color.record)
                Image(systemName: isError ? "exclamationmark" : "mic.fill")
                    .font(DS.Font.headline)
                    .foregroundStyle(isError ? DS.Color.record : .white)
                    .symbolEffect(.pulse, isActive: controller.state == .listening)
            }
            .frame(width: DS.Size.hudBadge, height: DS.Size.hudBadge)

            Text(label)
                .font(DS.Font.hud)
                .foregroundStyle(isError ? DS.Color.record : DS.Color.ink)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)
                .animation(DS.Motion.text, value: label)

            Waveform(
                level: controller.level,
                isActive: controller.state == .listening,
                barCount: DS.Size.hudWaveformBars,
                tint: DS.Color.ink
            )
            .frame(
                width: DS.Size.waveformWidth(bars: DS.Size.hudWaveformBars),
                height: DS.Size.hudWaveformHeight
            )
        }
        .padding(.leading, DS.Space.snug)
        .padding(.trailing, DS.Space.wide)
        .frame(width: DS.Size.hudWidth, height: DS.Size.hudHeight)
        .glassEffect(DS.Glass.hud, in: .capsule)
        // Always the dark scheme, matching the smoke-tinted glass and the notch above it.
        .environment(\.colorScheme, .dark)
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
    }

    private var label: String {
        switch controller.state {
        case .starting: "Listening…"
        case .listening: controller.transcript.isEmpty ? "Listening…" : controller.transcript
        // Parakeet transcribes in one pass on release, so there's nothing to show until
        // it lands — say what's happening instead of leaving an empty pill.
        case .finishing: controller.transcript.isEmpty ? "Transcribing…" : controller.transcript
        case .error(let message): message
        case .idle: ""
        }
    }
}
