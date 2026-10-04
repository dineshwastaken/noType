import NoTypeDictionary
import AppKit
import SwiftUI

/// The dictionary: add, edit, delete, search.
///
/// Both entry kinds live in one list rather than separate tabs — they're two shapes of the
/// same idea and you want to see everything you've taught it at once. The kind is carried by
/// a chip on each row.
struct DictionaryPanel: View {
    @State private var store = DictionaryStore.shared
    @State private var query = ""
    @State private var editing: DictionaryEntry?
    @State private var isAdding = false

    private var entries: [DictionaryEntry] { store.filtered(by: query) }

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyPanel(
                    systemImage: store.entries.isEmpty ? "character.book.closed" : "magnifyingglass",
                    title: store.entries.isEmpty ? "Teach NoType your words" : "No matches",
                    detail: store.entries.isEmpty
                        ? "Add names, jargon and product names it keeps getting wrong."
                        : "Try a different search."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Space.snug) {
                        ForEach(entries) { entry in
                            DictionaryRow(
                                entry: entry,
                                onEdit: { editing = entry },
                                onToggle: {
                                    var updated = entry
                                    updated.isEnabled.toggle()
                                    store.update(updated)
                                },
                                onDelete: { withAnimation(DS.Motion.spring) { store.delete(entry) } }
                            )
                        }
                    }
                    .frame(maxWidth: DS.Size.contentMaxWidth)
                    .padding(.horizontal, DS.Space.wide)
                    .padding(.vertical, DS.Space.base)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
        }
        .navigationTitle("Dictionary")
        .navigationSubtitle("\(store.entries.count) entr\(store.entries.count == 1 ? "y" : "ies")")
        .searchable(text: $query, placement: .toolbar, prompt: "Search dictionary")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // The file path is reachable because the dictionary is meant to be editable
                // outside the UI — which is only true if you can find it.
                Button("Reveal dictionary.txt", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
                }
                .help(DictionaryStore.fileURL.path)

                Button("Add Entry", systemImage: "plus") { isAdding = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Add an entry (⌘N)")
            }
        }
        .sheet(isPresented: $isAdding) {
            DictionaryEditor(entry: nil) { store.add($0) }
        }
        .sheet(item: $editing) { entry in
            DictionaryEditor(entry: entry) { store.update($0) }
        }
    }
}

// MARK: - Row

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DS.Space.base) {
            Chip(
                text: entry.kind == .correction ? "Fix" : "Term",
                tint: entry.kind == .correction ? DS.Color.correction : DS.Color.accent
            )

            HStack(spacing: DS.Space.snug) {
                if entry.kind == .correction {
                    Text(entry.hear)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.inkSecondary)
                    Image(systemName: "arrow.right")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkTertiary)
                }
                Text(entry.write)
                    .font(DS.Font.bodyEmphasis)
                    .foregroundStyle(DS.Color.ink)
            }
            .opacity(entry.isEnabled ? 1 : 0.45)

            Spacer()

            HStack(spacing: DS.Space.tight) {
                IconButton(systemImage: "pencil", help: "Edit", action: onEdit)
                IconButton(systemImage: "trash", help: "Delete", action: onDelete)
            }
            .opacity(isHovering ? 1 : 0)

            Toggle("Enabled", isOn: Binding(get: { entry.isEnabled }, set: { _ in onToggle() }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(entry.isEnabled ? "Disable this entry" : "Enable this entry")
        }
        .padding(.horizontal, DS.Space.roomy)
        .padding(.vertical, DS.Space.base)
        .background(CardBackground(isHovering: isHovering))
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { hovering in
            withAnimation(DS.Motion.snappy) { isHovering = hovering }
        }
        .contextMenu {
            Button("Edit…", systemImage: "pencil", action: onEdit)
            Button(entry.isEnabled ? "Disable" : "Enable", systemImage: "power", action: onToggle)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Editor

/// Add or edit one entry, with the false-positive warning shown live as you type.
private struct DictionaryEditor: View {
    let entry: DictionaryEntry?
    let onSave: (DictionaryEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: DictionaryEntry.Kind
    @State private var hear: String
    @State private var write: String

    init(entry: DictionaryEntry?, onSave: @escaping (DictionaryEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _kind = State(initialValue: entry?.kind ?? .term)
        _hear = State(initialValue: entry?.hear ?? "")
        _write = State(initialValue: entry?.write ?? "")
    }

    private var draft: DictionaryEntry {
        DictionaryEntry(
            id: entry?.id ?? UUID(),
            kind: kind,
            write: write.trimmingCharacters(in: .whitespacesAndNewlines),
            hear: kind == .correction ? hear.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            isEnabled: entry?.isEnabled ?? true
        )
    }

    private var warnings: [DictionaryWarning] { DictionaryWarning.check(draft) }

    private var isValid: Bool {
        !draft.write.isEmpty && (kind == .term || !draft.hear.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    Picker("Type", selection: $kind.animation(DS.Motion.spring)) {
                        Text("Term").tag(DictionaryEntry.Kind.term)
                        Text("Correction").tag(DictionaryEntry.Kind.correction)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(kind == .term
                        ? "A word or phrase NoType should know — passed to the engine as a hint."
                        : "When NoType hears one thing, write another. Runs after every transcription.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkSecondary)
                }

                Section {
                    if kind == .correction {
                        TextField("When you hear", text: $hear, prompt: Text("cloud code"))
                    }
                    TextField(
                        kind == .correction ? "Write" : "Word or phrase",
                        text: $write,
                        prompt: Text(kind == .correction ? "Claude Code" : "Anthropic")
                    )
                }

                if !warnings.isEmpty {
                    Section {
                        ForEach(warnings) { warning in
                            Label {
                                Text(warning.message)
                                    .font(DS.Font.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(DS.Color.correction)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack(spacing: DS.Space.snug) {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(entry == nil ? "Add" : "Save") {
                    guard isValid else { return }
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(!isValid)
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], DS.Space.wide)
        }
        .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
        .frame(width: DS.Size.editorWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}
