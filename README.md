# NoType

Push-to-talk dictation for macOS. Hold a key, talk, release — cleaned-up text lands in
whatever text field has focus. Built native and fully on-device, with a Liquid Glass
interface that follows the system's light and dark appearance.

Requires macOS 26 or later and Xcode 26 or later to build.

---

## Coexisting with another dictation app

This app is built to run alongside other dictation tools without colliding with them, which
is not automatic on macOS and is worth understanding before changing anything:

- **Bundle ID `com.notype.app`** — TCC keys Accessibility and Microphone
  grants to the bundle ID, so granting or revoking a permission here has no effect on any
  other app, and vice versa.
- **Executable `NoType`** — distinct enough that `pkill -x NoType` cannot
  match a differently-named binary. The `Makefile` only ever targets `$(EXEC)`.
- **Hotkey is configurable** (fn by default, or Right ⌥ / Right ⌘) precisely because another tool may
  already own the key you'd reach for first. The event tap inspects only its own keycode
  and passes everything else through untouched.

If you run more than one dictation app, give each a different push-to-talk key. Two apps on
the same key both record, and whichever injects text will fight the other.

---

## Quick start

```bash
make install     # builds, bundles, signs, copies to /Applications, launches
```

Then grant two permissions — neither is optional, and neither can be requested silently:

| Permission | Where | Needed for |
|---|---|---|
| **Accessibility** | System Settings ▸ Privacy & Security ▸ Accessibility (macOS 27: "Device Control and Data Access") | The `CGEventTap` that sees the hotkey, and the AX text insert |
| **Microphone** | Prompted on first dictation | Audio capture |

No restart is needed: NoType arms the hotkey within a second of the grant. Then hold **fn**
and talk.

If the switch shows on but the hotkey still does nothing, the entry belongs to an older
signature. Remove NoType with **−** and add `/Applications/NoType.app` again with **+**;
toggling the existing row doesn't help.

NoType is a menu bar app. It has no Dock icon, and closing its window leaves it running,
which it has to be for the hotkey to work. Open the window from the menu bar icon (or by
double-clicking the app). **Settings ▸ Open at login** starts it with your Mac, and
**Settings ▸ Show in Dock** brings the Dock icon back if you want it.

### Voice commands

| Say | Get |
|---|---|
| "new line" | a line break |
| "new paragraph" | a blank line |
| "open paren", "close paren" | ( ) |

Punctuation comes from speaking naturally; "comma" and "period" are not commands. Filler
words (um, uh, erm, hmm) are removed. With **Smart cleanup** on, the on-device model also
tries to format spoken lists and apply self-corrections ("Tuesday, actually Wednesday"),
on a best-effort basis.

> **Set System Settings ▸ Keyboard ▸ "Press 🌐 key to" → Do Nothing.** NoType deliberately
> passes fn through (swallowing it would break fn+arrow and fn+delete), so if macOS also has
> an action bound to it, the emoji picker or system dictation opens alongside NoType.

If you press the key by accident and say nothing, the recording is discarded and the pill
closes by itself after 6 seconds; letting go of the key closes it immediately.

### Why grants survive rebuilds here

TCC stores a *code-signing requirement* per entry, not just a path. An ad-hoc signature
changes on every build, so the rebuilt binary stops satisfying the stored requirement —
and the symptom is nasty: the Accessibility toggle still **shows as on** while the app is
reported untrusted, and flipping it changes nothing because the stale row is the problem.

The `Makefile` therefore signs with a stable Developer ID (auto-detected via
`security find-identity`, falling back to ad-hoc). Verified: rebuild + reinstall keeps both
grants with no re-prompt.

If a grant ever does get wedged, reset that one row and re-add — never toggle:

```bash
tccutil reset Accessibility com.notype.app
tccutil reset Microphone   com.notype.app
```

Always pass the bundle ID. A bare `tccutil reset Accessibility` wipes **every** app on the
machine. Then quit System Settings entirely (⌘Q) before reopening — that pane caches its
list and will otherwise show the row you just deleted.

> **Keep the build out of iCloud.** `~/Desktop` and `~/Documents` are file-provider synced
> on this machine; the sync engine can materialize/dematerialize files inside an `.app` and
> corrupt its signature. `make install` puts the running copy in `/Applications`.

Other targets: `make app` (bundle only), `make run` (run in place), `make clean`.

---

## Architecture

```
 hold key ─► HotkeyMonitor ──► DictationController ◄── Settings
                                │
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
              AudioCapture  HUDPanel   TranscriptionEngine
                     │                      │
                (AudioChunk) ──ordered──► AppleSpeechEngine
                                            │
                                       (transcript)
                                            ▼
                                      TextFormatter
                                            ▼
                                      TextInjector ─► focused app
```

### Decisions worth knowing

**The HUD must never take focus.** `HUDPanel` is a `.nonactivatingPanel` with
`canBecomeKey == false`. This is the load-bearing detail of the whole app: if the overlay
took key status, the user's text field would lose focus and there'd be nothing left to
inject into. Everything else is replaceable; this isn't.

**The hotkey needs a `CGEventTap`, not `NSEvent`.** `fn` and left/right modifier
discrimination don't surface through `NSEvent.addGlobalMonitorForEvents` or the Carbon
hotkey API. A session event tap is the only way to see them — which is why Accessibility
permission is a hard requirement rather than a nicety.

**Audio ordering is explicit.** `AudioCapture` yields into an `AsyncStream` drained by a
single task. Spawning a `Task` per buffer would be simpler and would silently corrupt the
transcript, because unstructured tasks have no ordering guarantee.

**Buffers are copied, never borrowed.** `AVAudioEngine` recycles the buffer it hands to a
tap the instant the callback returns. `AudioChunk`'s `@unchecked Sendable` is only sound
because `AudioCapture` always allocates fresh storage before handing off.

**Two swappable seams.** `TranscriptionEngine` and `TextFormatter` are protocols so the
two components most likely to change can change without touching anything else.

### Layout

```
Sources/NoType/
├── NoTypeApp.swift                 @main, AppDelegate, menu bar item and menu
├── Core/
│   ├── DictationController.swift   state machine, silence guard, wires everything
│   ├── HotkeyMonitor.swift         CGEventTap on .flagsChanged
│   ├── AudioCapture.swift          AVAudioEngine tap + format conversion + RMS
│   ├── TextInjector.swift          AX insert, pasteboard+⌘V fallback
│   └── EngineComparison.swift      same audio through every installed engine
├── Transcription/                  Apple SpeechAnalyzer, Parakeet (FluidAudio)
├── Formatting/                     RuleBasedFormatter, on-device FoundationModelFormatter
├── Dictionary/DictionaryStore.swift
├── UI/
│   ├── DesignSystem.swift          every colour, size, glass and motion token
│   ├── Components.swift            cards, chips, waveform, record button
│   ├── MainWindow.swift            sidebar, transcriptions, recorder bar
│   ├── DictionaryPanel.swift, SettingsWindow.swift, ComparisonWindow.swift
│   ├── HUDPanel.swift              non-activating panel, positioned under the notch
│   └── HUDView.swift               the pill: waveform + live transcript
└── Support/                        Settings, Permissions, RunLog, Log
```

---

## Speech engine

Default is Apple's **`SpeechAnalyzer` / `SpeechTranscriber`**, new in macOS 26: no
dependency, no bundled model, no cloud path, real streaming with `.volatileResults` so
text appears while you're still talking. The OS downloads and manages model assets, so the
first run for a locale may pause on `AssetInstallationRequest`.

The intended upgrade is **Parakeet v3** via FluidAudio (CoreML on the Neural Engine) —
measurably better English WER, ~110× realtime, ~66 MB resident. Implementing
`TranscriptionEngine` is the entire cost of switching; `DictationController` doesn't
change.

| | Apple SpeechTranscriber | Parakeet v3 (FluidAudio) | Whisper large-v3 (WhisperKit) |
|---|---|---|---|
| Dependency | none | SwiftPM | SwiftPM |
| Model download | OS-managed | ~600 MB | ~1.5 GB |
| English accuracy | good | best | good |
| Languages | many | 25 | 99 |
| Latency | low | ~80 ms | 200–500 ms |

---

## Not built yet

1. **LLM cleanup tier.** `RuleBasedFormatter` strips fillers, fixes spacing, capitalizes
   sentences and adds terminal punctuation — genuinely useful, entirely deterministic. The
   real win is a second `TextFormatter` backed by Apple's on-device Foundation Models
   (macOS 26) for tone, list formatting, and honoring spoken corrections, with Claude as an
   optional higher-quality tier.
2. **Command Mode.** Select text, hold a second hotkey, say "make this more formal."
   Needs AX read of `kAXSelectedTextAttribute` plus an LLM round-trip.
3. **Personal dictionary.** Names and jargon the ASR keeps missing. `SpeechAnalyzer`
   supports this through `AnalysisContext` / `SFCustomLanguageModelData`.
5. **Onboarding.** A first-run window that walks through both permissions instead of
   relying on the menu's "Grant…" items.
6. **Developer ID signing + notarization.** Ends the TCC-reset churn and makes the app
   distributable.

---

## Verified

Checked on a MacBook Air (notch, macOS 27) with synthetic fn events, screenshots, and
`/usr/bin/log show --predicate 'subsystem == "com.notype.app"'`:

- Builds under Swift 6 strict concurrency; the dictionary vector tests pass.
- Signed with an Apple Development certificate, the Accessibility grant survives rebuild
  and reinstall, and the hotkey arms within a second of a fresh grant without a relaunch.
- Runs as a menu bar app with no Dock icon.
- Real speech: fn held 9.2 s, text ready 0.1 s after release, cleaned up and pasted.
- A press with no speech is discarded after 6 s and nothing is typed.
- The pill's top edge sits 8 pt below the notch, centred on it.
- Comparison runs Apple and Parakeet on the same recording once Parakeet is installed.

Not verified by the automated run: the "new line" command spoken aloud (the code path is
in `RuleBasedFormatter`).

> `log` may be shadowed in your shell; use `/usr/bin/log` explicitly or it returns nothing.
