# NoType: development notes

How the macOS app is built and why it is shaped the way it is. To install NoType, see the
[README](../README.md). Before changing code, read [AGENTS.md](../AGENTS.md).

## Building

You need macOS 26 or later on Apple silicon and Xcode 26 or later. Command Line Tools alone
can't build NoType: in the macOS 27 SDK, SwiftUI's `@State` and swift-testing's `@Test` are
macros whose plugins ship only inside Xcode.app.

| Command | Does |
|---|---|
| `make install` | Builds, bundles, signs, copies to `/Applications/NoType.app` and launches it |
| `make app` | Builds and signs the bundle without installing it |
| `make run` | Builds and runs the bundle from the staging folder |
| `make icon` | Regenerates `Resources/AppIcon.icns` from `Tools/makeicon.swift` |
| `make clean` | Removes build products |
| `swift test --filter VectorTests` | Runs the dictionary contract tests |

Build products go to `~/Library/Caches/NoTypeBuild`, outside the repo. When the repo sits in
an iCloud-synced folder, the sync engine modifies files mid-compile ("input file was
modified during the build") and can corrupt a signed `.app`, so always build with `make`
and run the copy in `/Applications`.

## Signing and permissions

macOS stores Accessibility and Microphone grants against the app's code signature, not
just its path. The `Makefile` signs with the first identity it finds: a Developer ID, then
an Apple Development certificate (free; Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates),
then ad-hoc. A certificate gives every build the same signature, so grants survive
rebuilds. An ad-hoc signature changes with every build and the user has to grant both
permissions again.

When a grant belongs to an older signature, System Settings still shows the switch as on
while the app is untrusted. The hotkey log makes this visible: `tapCreate failed —
accessibility trusted: false`. Toggling the switch doesn't help. Remove NoType from the
list and add it again, or reset only NoType's entries:

```bash
tccutil reset Accessibility com.notype.app
tccutil reset Microphone   com.notype.app
```

Always pass the bundle ID; a bare `tccutil reset Accessibility` revokes the permission for
every app on the Mac. Quit System Settings (⌘Q) before reopening it, because the pane caches
its list.

NoType doesn't need a relaunch after a grant: if the event tap can't be installed, the
controller polls once a second and arms the hotkey as soon as the grant lands.

## Running alongside other dictation apps

- The bundle ID `com.notype.app` gives NoType its own permission entries, so granting or
  revoking them affects no other app.
- The executable is named `NoType`, and the `Makefile` only ever targets that name with
  `pkill -x`.
- The push-to-talk key is configurable (fn by default, Right ⌥ or Right ⌘), and the event
  tap reacts only to its own key and passes every other event through.

Give each dictation app its own key. Two apps on the same key both record and then fight
over the text field.

## Architecture

```
 hold key ─► HotkeyMonitor ──► DictationController ◄── Settings
                                │
                ┌───────────────┼────────────────┐
                ▼               ▼                ▼
          AudioCapture      HUDPanel      TranscriptionEngine
                │          (notch pill)   (Apple or Parakeet)
          (AudioChunk) ──ordered──────────────►  │
                                            (transcript)
                                                 ▼
                                   TextFormatter (rule-based or
                                   on-device language model)
                                                 ▼
                                   DictionaryCorrector (always)
                                                 ▼
                              TextInjector ─► focused app
                              RunLog ─► history (runs.jsonl)
```

### Decisions worth knowing

**The HUD must never take focus.** `HUDPanel` is a `.nonactivatingPanel` with
`canBecomeKey == false`. If the overlay took key status, the user's text field would lose
focus and there would be nothing to type into. This is the one property of the app that
can't be traded away.

**The hotkey needs a `CGEventTap`, not `NSEvent`.** `fn` and left/right modifier
discrimination don't surface through `NSEvent.addGlobalMonitorForEvents` or the Carbon
hotkey API. A session event tap is the only way to see them, which is why Accessibility is
required. fn is passed through rather than consumed, so fn+arrow and fn+delete keep working.

**Audio ordering is explicit.** `AudioCapture` yields into an `AsyncStream` drained by a
single task. A `Task` per buffer would have no ordering guarantee and would scramble the
transcript.

**Buffers are copied, never borrowed.** `AVAudioEngine` recycles the buffer it hands to a
tap as soon as the callback returns. `AudioChunk`'s `@unchecked Sendable` is sound only
because `AudioCapture` always copies into fresh storage first.

**Accidental presses discard themselves.** If no input reaches about −42 dBFS (0.15 on the
0…1 meter) and no text has been transcribed within 6 seconds of the mic opening,
`DictationController` cancels the recording. After the first sign of speech the check never
fires again. Each recording logs its peak level (`peak input level`) for tuning.

**The pill is positioned from the notch's real geometry.** `HUDPanel` reads the notch from
`NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` (widths) and `safeAreaInsets.top`,
and falls back to the menu bar height on screens without a notch. The entrance and exit are
SwiftUI springs scaled from the top edge; with Reduce Motion they become a fade.

**Menu bar first.** `LSUIElement` is set, so there's no Dock icon and none flashes at
launch. Settings ▸ Show in Dock switches the activation policy at runtime. The main window
uses `.defaultLaunchBehavior(.suppressed)` and opens from the menu bar, from a reopen event
(double-clicking the app), or once on the very first launch. Open at login uses
`SMAppService.mainApp`.

**Comparison never downloads.** Engine comparison runs only engines whose models are
installed; a missing Parakeet model is reported as "not installed" instead of starting a
470 MB download after the recording ends.

**Two swappable seams.** `TranscriptionEngine` and `TextFormatter` are protocols, so the
parts most likely to change can change without touching the controller.

### Layout

```
Sources/NoType/
├── NoTypeApp.swift                 @main, AppDelegate, menu bar item and menu
├── Core/
│   ├── DictationController.swift   state machine, silence guard, wires everything
│   ├── HotkeyMonitor.swift         CGEventTap on .flagsChanged
│   ├── AudioCapture.swift          AVAudioEngine tap + format conversion + RMS
│   ├── TextInjector.swift          AX insert, pasteboard+⌘V fallback
│   ├── EngineComparison.swift      same audio through every installed engine
│   └── WisprTrigger.swift          optional Wispr Flow trigger in compare mode
├── Transcription/                  Apple SpeechAnalyzer, Parakeet (FluidAudio), Wispr reader
├── Formatting/                     RuleBasedFormatter, FoundationModelFormatter
├── Dictionary/DictionaryStore.swift
├── UI/
│   ├── DesignSystem.swift          every colour, size, glass and motion token
│   ├── Components.swift            cards, chips, waveform, record button
│   ├── MainWindow.swift            sidebar, transcriptions, recorder bar
│   ├── DictionaryPanel.swift, SettingsWindow.swift, ComparisonWindow.swift
│   ├── HUDPanel.swift              non-activating panel under the notch
│   └── HUDView.swift               the pill: waveform + live transcript
└── Support/                        Settings, Permissions, RunLog, Log
Sources/NoTypeDictionary/           correction engine, shared contract with Windows
```

## Speech engines

**Apple `SpeechAnalyzer` / `SpeechTranscriber`** is the default. It has no dependency and no
bundled model, never touches the network, and streams with `.volatileResults`, so text
appears while the user is still talking. The OS manages its model assets, so the first run
for a locale can pause while they install. Dictionary words reach it as contextual strings
through `AnalysisContext`.

**Parakeet TDT 0.6B v3** runs through FluidAudio as CoreML on the Neural Engine. It
transcribes in one pass on release rather than streaming. The model is a one-time 470 MB
download to `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3`, loaded
once per process and shared. `ParakeetModels.isDownloaded` uses FluidAudio's own
completeness check, so an interrupted download doesn't count as installed.

| | Apple SpeechTranscriber | Parakeet v3 (FluidAudio) |
|---|---|---|
| Dependency | none | SwiftPM |
| Model download | OS-managed | 470 MB, one time |
| Live text while speaking | yes | no |
| Languages | many | 25 |

## Text cleanup

Cleanup runs when Settings ▸ Clean up transcripts is on (the default).

- `RuleBasedFormatter` removes "um", "uh", "erm", "uhm", "hmm" and "mhm", turns "new line",
  "new paragraph", "open paren" and "close paren" into their symbols, fixes spacing,
  capitalises sentences and ends the text with punctuation.
- `FoundationModelFormatter` (Smart cleanup) uses Apple's on-device language model to also
  format spoken lists and apply self-corrections. It falls back to the rule-based pass when
  the model is unavailable, takes longer than 4 seconds, or returns something that fails its
  sanity check.

`DictionaryCorrector` runs last and always, whatever the cleanup setting. Its behaviour is
specified by `shared/dictionary-test-vectors.json`, which the Windows app also runs.

## Roadmap

1. Command Mode: select text, hold a second key, say "make this more formal".
2. Built-in "next line", "bullet point" and "scratch that" commands that don't depend on
   Smart cleanup.
3. A first-run window that walks through both permissions.
4. Developer ID signing and notarization, so NoType can be distributed as a download.

## Debugging

```bash
/usr/bin/log show --last 10m --info --predicate 'subsystem == "com.notype.app"' --style compact
```

Use `/usr/bin/log`; some shells shadow `log` with a builtin. Categories are `hotkey`,
`audio`, `speech`, `inject` and `app`. History is in
`~/Library/Application Support/NoType/runs.jsonl` and the dictionary in `dictionary.txt`
beside it.
