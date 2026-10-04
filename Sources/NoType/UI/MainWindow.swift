import NoTypeDictionary
import AppKit
import SwiftUI

/// The app's main window.
///
/// A standard sidebar split view — which macOS 26 renders as a floating glass sidebar — with
/// the selected section in the detail column. The recorder lives in a glass bar pinned to the
/// bottom of the detail column, so content scrolls underneath it and the glass refracts it.
struct MainWindow: View {
    @Bindable var controller: DictationController

    @State private var section: Section? = .transcriptions
    @State private var runStore = RunStore.shared
    @State private var dictionary = DictionaryStore.shared

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case transcriptions
        case dictionary

        var id: String { rawValue }
        var title: String { self == .transcriptions ? "Transcriptions" : "Dictionary" }
        var systemImage: String { self == .transcriptions ? "text.bubble" : "character.book.closed" }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Section.allCases) { candidate in
                    Label(candidate.title, systemImage: candidate.systemImage)
                        .badge(count(for: candidate))
                        .tag(candidate)
                }
            }
            .navigationSplitViewColumnWidth(min: DS.Size.sidebarMin, ideal: DS.Size.sidebarMin)
        } detail: {
            Group {
                switch section ?? .transcriptions {
                case .transcriptions: TranscriptionList()
                case .dictionary: DictionaryPanel()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RecorderBar(controller: controller)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Space.wide)
                    .padding(.bottom, DS.Space.wide)
            }
        }
        .frame(minWidth: DS.Size.windowMinWidth, minHeight: DS.Size.windowMinHeight)
        .tint(DS.Color.accent)
    }

    private func count(for section: Section) -> Int {
        switch section {
        case .transcriptions: runStore.runs.count
        case .dictionary: dictionary.entries.count
        }
    }
}

// MARK: - Recorder bar

/// Record / stop, the live waveform, status and timer, floating on glass at the bottom of
/// the detail column.
///
/// One glass capsule holding everything, with the record button as a solid tinted circle
/// inset concentrically at its leading end (capsule height − 2 × inset = button size). One
/// shape rather than two means no glass-on-glass and no merge "neck" between neighbours.
/// Every slot has a fixed width, so the bar never resizes as the status text or timer changes.
private struct RecorderBar: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared

    @State private var elapsed: TimeInterval = 0
    @State private var startedAt: Date?

    private var isRecording: Bool { controller.state.isActive }

    var body: some View {
        HStack(spacing: DS.Space.base) {
            RecordButton(isRecording: isRecording) {
                if isRecording {
                    controller.stopButtonRecording()
                } else {
                    controller.startButtonRecording()
                }
            }

            Waveform(
                level: controller.level,
                isActive: controller.state == .listening,
                barCount: DS.Size.barWaveformBars,
                tint: isRecording ? DS.Color.record : DS.Color.accent
            )
            .frame(width: DS.Size.waveformWidth(bars: DS.Size.barWaveformBars),
                   height: DS.Size.waveformHeight)

            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Text(status)
                    .font(DS.Font.bodyEmphasis)
                    .foregroundStyle(isError ? DS.Color.record : DS.Color.ink)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(detail)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .lineLimit(1)
            }
            .frame(width: DS.Size.barStatusWidth, alignment: .leading)

            trailing
                .frame(width: DS.Size.barTrailingWidth, alignment: .trailing)
        }
        .padding(.leading, DS.Size.barInset)
        .padding(.trailing, DS.Space.wide)
        .frame(height: DS.Size.barHeight)
        .glassEffect(DS.Glass.passive, in: .capsule)
        .animation(DS.Motion.spring, value: isRecording)
        .onChange(of: isRecording) { _, active in
            startedAt = active ? Date() : nil
            if !active { elapsed = 0 }
        }
        .task(id: startedAt) {
            guard let startedAt else { return }
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    /// The timer while recording; the hotkey as a keycap while idle.
    @ViewBuilder
    private var trailing: some View {
        if isRecording {
            Text(timerText)
                .font(DS.Font.timer)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(DS.Color.record)
                .contentTransition(.numericText())
                .transition(.blurReplace)
        } else {
            Text(settings.pushToTalkKey.displayName)
                .font(DS.Font.captionEmphasis)
                .foregroundStyle(DS.Color.inkSecondary)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.tight)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                        .strokeBorder(DS.Color.inkTertiary, lineWidth: DS.Border.keycap)
                )
                .transition(.blurReplace)
                .help("Hold \(settings.pushToTalkKey.displayName) anywhere to dictate")
        }
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
    }

    private var status: String {
        switch controller.state {
        case .idle: "Ready to dictate"
        case .starting: "Listening…"
        case .listening: controller.transcript.isEmpty ? "Listening…" : controller.transcript
        case .finishing: controller.transcript.isEmpty ? "Transcribing…" : controller.transcript
        case .error(let message): message
        }
    }

    private var detail: String {
        switch controller.state {
        case .idle, .error: "Hold the key anywhere, or click the mic"
        case .starting, .listening: "Release the key or click stop when done"
        case .finishing: settings.compareMode
            ? "Comparing engines — nothing is typed"
            : "Cleaning up and inserting…"
        }
    }

    private var timerText: String {
        let total = Int(elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Transcriptions

/// Past transcriptions, grouped by day, searchable, each copyable.
private struct TranscriptionList: View {
    @State private var store = RunStore.shared
    @State private var query = ""
    @State private var isConfirmingClear = false

    private var runs: [DictationRun] {
        let all = store.runs.reversed().map { $0 }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.text.localizedStandardContains(trimmed) }
    }

    /// Newest day first; runs within a day are already newest first.
    private var days: [(day: Date, runs: [DictationRun])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        Group {
            if runs.isEmpty {
                EmptyPanel(
                    systemImage: store.runs.isEmpty ? "waveform" : "magnifyingglass",
                    title: store.runs.isEmpty ? "No transcriptions yet" : "No matches",
                    detail: store.runs.isEmpty
                        ? "Your dictations will appear here."
                        : "Try a different search."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Space.snug) {
                        ForEach(days, id: \.day) { group in
                            Eyebrow(text: dayTitle(group.day))
                                .padding(.top, DS.Space.base)
                                .padding(.leading, DS.Space.tight)
                            ForEach(group.runs) { run in
                                TranscriptionRow(run: run) {
                                    withAnimation(DS.Motion.spring) { RunLog.delete(run) }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: DS.Size.contentMaxWidth)
                    .padding(.horizontal, DS.Space.wide)
                    .padding(.bottom, DS.Space.wide)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
        }
        .navigationTitle("Transcriptions")
        .navigationSubtitle("\(store.runs.count) recording\(store.runs.count == 1 ? "" : "s")")
        .searchable(text: $query, placement: .toolbar, prompt: "Search transcriptions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Delete All Transcriptions…", systemImage: "trash", role: .destructive) {
                        isConfirmingClear = true
                    }
                    .disabled(store.runs.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        // Confirmed, unlike a single row: one row is trivially re-recorded, the whole
        // history is not, and there's no undo.
        .confirmationDialog(
            "Delete all \(store.runs.count) transcriptions?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { RunLog.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct TranscriptionRow: View {
    let run: DictationRun
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Text(run.text)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let corrections = run.corrections, !corrections.isEmpty {
                CorrectionBadges(corrections: corrections)
            }

            HStack(spacing: DS.Space.snug) {
                Text(run.date, style: .time)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                Chip(text: run.engine)
                Text(String(format: "%.2fs", run.processSeconds))
                    .font(DS.Font.metric)
                    .foregroundStyle(DS.Color.inkTertiary)
                Spacer()
                IconButton(systemImage: "trash", help: "Delete this transcription", action: onDelete)
                    .opacity(isHovering ? 1 : 0)
                CopyButton(text: run.text)
            }
        }
        .padding(DS.Space.roomy)
        .background(CardBackground(isHovering: isHovering))
        .onHover { hovering in
            withAnimation(DS.Motion.snappy) { isHovering = hovering }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(run.text, forType: .string)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

/// Shows that the dictionary fired, and on what. Without this the dictionary is invisible
/// and you can't tell a rule that works from one that never matches.
private struct CorrectionBadges: View {
    let corrections: [AppliedCorrection]

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Image(systemName: "wand.and.sparkles")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.correction)
            ForEach(corrections, id: \.self) { correction in
                HStack(spacing: DS.Space.tight) {
                    Text(correction.from)
                        .strikethrough()
                        .foregroundStyle(DS.Color.inkSecondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(DS.Color.inkTertiary)
                    Text(correction.to)
                        .foregroundStyle(DS.Color.ink)
                    if correction.count > 1 {
                        Text("×\(correction.count)")
                            .foregroundStyle(DS.Color.inkSecondary)
                    }
                }
                .font(DS.Font.caption)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.hair)
                .background(Capsule().fill(DS.Color.correction.opacity(0.12)))
            }
            Spacer(minLength: 0)
        }
    }
}
