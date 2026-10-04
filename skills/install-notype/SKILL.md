---
name: install-notype
description: |
  Install NoType, a push-to-talk dictation app, from this repository on macOS or Windows.
  Use when a user gives you the NoType repo URL (or a clone of it) and asks you to set it up,
  install it, build it, or get dictation working on their machine. Covers prerequisites,
  build, install, permissions, the optional Parakeet model, verification, and recovery from
  every known roadblock, including which steps only the user can approve.
---

# Install NoType

NoType: hold a key, talk, release, and cleaned-up text is typed into whatever app has focus.
Speech recognition runs on the device. This skill takes a user from a repo URL to working
dictation.

Two implementations live in the repo. Pick one by the user's OS:

| OS | Path | Status |
|---|---|---|
| macOS 26 or later, Apple silicon | repo root (Swift) | Works; in daily use |
| Windows 10/11 x64 | `windows/` (C#/.NET) | Builds and passes CI; **never tested on real hardware** |

Tell a Windows user about that status before you start.

## Rules for the agent

Follow these throughout. They exist because this install touches microphone access,
keyboard monitoring and code signing.

1. **The user approves anything involving security, privacy, passwords or accounts.** You
   prepare the step, say exactly what to click or run, and wait. You never do these
   yourself, even if your tools could:
   - any `sudo` command, or anything that asks for the user's password
   - macOS System Settings privacy switches (Accessibility, Microphone, Input Monitoring,
     Login Items) and keyboard settings
   - accepting the Xcode licence, signing in to an Apple ID, creating certificates, adding
     certificates to the keychain
   - Windows UAC prompts, SmartScreen "Run anyway", microphone privacy settings, antivirus
     exclusions
   - installing Xcode from the App Store
2. **Ask before large downloads.** Xcode (many GB), the .NET SDK, and the Parakeet model
   (about 470 MB on macOS) each need a yes from the user first.
3. **Check before you assume.** Run the check command for each prerequisite, and only fix
   what is actually missing.
4. **Leave the rest of the machine alone.** Do not change global git config, shell
   profiles, other apps' permissions or system settings beyond what a step lists.
   `tccutil reset` must always name the bundle ID (`com.notype.app`): a bare
   `tccutil reset Accessibility` revokes the permission for every app on the Mac.
5. **When a step fails, read the error, look it up in the roadblocks table, and fix the
   cause.** Do not retry the same command in a loop. If the table doesn't cover it, stop and
   report the exact error.
6. **Finish with a verification**, not with "should work now". The last section lists the
   checks.

## macOS

### 1. Check prerequisites

Run these and compare against the right-hand column.

| Check | Command | Need |
|---|---|---|
| macOS version | `sw_vers -productVersion` | 26.0 or later |
| CPU | `uname -m` | `arm64` |
| Full Xcode | `xcode-select -p` | a path inside `Xcode.app`, not `/Library/Developer/CommandLineTools` |
| Xcode licence | `xcodebuild -version` | prints a version (no licence message) |
| Swift | `swift --version` | Swift 6.2 or later |
| git | `git --version` | any |

Fixes, in order:

- **macOS older than 26:** stop. NoType uses APIs that only exist on macOS 26 (on-device
  `SpeechAnalyzer`, Liquid Glass). There is no workaround.
- **No Xcode, or only Command Line Tools:** NoType will not build with Command Line Tools
  alone. In the macOS 27 SDK, SwiftUI's `@State` and swift-testing's `@Test` are macros
  whose plugins ship only inside Xcode.app; the build fails with `plugin for module
  'SwiftUIMacros' not found`. Ask the user to install Xcode 26 or later from the App Store.
  Then, if `xcode-select -p` still points at CommandLineTools, the user runs:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- **Licence not accepted** (`You have not agreed to the Xcode license agreements`; this also
  blocks `git`): the user runs `sudo xcodebuild -license accept`.

### 2. Get the code

```bash
git clone <repo-url> NoType
cd NoType
```

If the user already has a clone, work in it. Don't clone a second copy.

### 3. Build and install

```bash
make install
```

This builds a release bundle outside the repo (`~/Library/Caches/NoTypeBuild`), signs it,
copies it to `/Applications/NoType.app` and launches it. The first build fetches the
FluidAudio Swift package and takes a few minutes. Always use `make`, never a bare
`swift build`: the Makefile keeps build products out of the repo folder, which matters when
that folder is synced by iCloud.

Expected last lines:

```
built …/NoType.app  [signed: <identity or ->]
installed to /Applications/NoType.app
```

`[signed: -]` means ad-hoc signing. It works, but see "Keep permissions across rebuilds"
below.

NoType is a menu bar app. It has no Dock icon; look for the waveform icon in the menu bar.
On the very first launch the main window opens once.

### 4. Permissions (user action)

NoType needs two permissions. Neither can be granted by an agent.

1. **Accessibility.** It lets NoType see the push-to-talk key and type the text. macOS
   shows a prompt on first launch. Tell the user:
   > Open System Settings ▸ Privacy & Security ▸ Accessibility (on macOS 27 the pane is
   > called "Device Control and Data Access") and switch on NoType.

   NoType notices the grant within a second; no relaunch is needed.
2. **Microphone.** macOS asks the first time the user dictates. They click Allow.

### 5. Set up the fn key (user action)

fn is the default push-to-talk key. macOS also binds fn to its own action, so tell the user:

> Open System Settings ▸ Keyboard and set "Press 🌐 key to" to **Do Nothing**.

You may check it without changing it: `defaults read com.apple.HIToolbox AppleFnUsageType`
prints `0` when it is set to Do Nothing. If the user prefers another key, Right ⌥ and
Right ⌘ are in NoType ▸ Settings.

### 6. Optional: Parakeet model

Apple's speech engine is the default and needs no download. Parakeet is an optional second
engine (about 470 MB, one time), used for engine comparison or chosen in Settings. If the
user wants it, ask before downloading, then tell them to choose **Download Parakeet
models…** from NoType's menu bar menu. Models land in
`~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3`.

### 7. Optional: keep permissions across rebuilds

macOS ties each permission to the app's code signature. An ad-hoc build gets a new
signature every time, so after each rebuild the user has to grant Accessibility and
Microphone again. A free Apple Development certificate fixes this, and `make` picks it up
automatically. Only suggest this if the user expects to rebuild (developers); a one-time
install doesn't need it.

User steps: Xcode ▸ Settings ▸ Accounts ▸ add their Apple ID ▸ Manage Certificates… ▸
**+** ▸ Apple Development. Check with `security find-identity -v -p codesigning`; it should
list `Apple Development: …`. Then rebuild with `make install` and grant both permissions one
last time.

### 8. Verify (macOS)

Run each check and report the result.

```bash
pgrep -x NoType                                  # prints a process id
codesign -dv /Applications/NoType.app 2>&1 | grep -E 'Identifier|Signature'
/usr/bin/log show --last 2m --info --predicate 'subsystem == "com.notype.app"' --style compact
```

In the log, `listening for …` or `Accessibility granted — hotkey armed` means the hotkey
works. `tapCreate failed — accessibility trusted: false` means the Accessibility grant
hasn't landed yet (see the roadblocks).

Then ask the user to hold fn, say a sentence, and release it with a text field focused, for
example in Notes. The text should appear within about a second, and the transcription
shows up in NoType's window. Use `/usr/bin/log`: some shells shadow `log` with a builtin.

### macOS roadblocks

| Symptom | Cause | Fix |
|---|---|---|
| `plugin for module 'SwiftUIMacros' not found` or `TestingMacros` | Building with Command Line Tools | Install Xcode; user runs `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `You have not agreed to the Xcode license agreements` | Licence not accepted | User runs `sudo xcodebuild -license accept` |
| `input file was modified during the build` | Repo in an iCloud-synced folder | Use `make` (it builds outside the repo); if it still happens, wait a few seconds and run it again once |
| Package resolution fails | No network, or GitHub unreachable | Check connectivity; `make build` again |
| Log shows `tapCreate failed — accessibility trusted: false` and the switch is off or missing | Accessibility not granted | User grants it (step 4) |
| Same log line, but the switch shows **on** | The entry belongs to an older signature of NoType | User selects NoType in that list, removes it with **−**, adds `/Applications/NoType.app` with **+**, and switches it on. Toggling the existing row does not help. If the list is confused, the user can run `tccutil reset Accessibility com.notype.app` first (always with the bundle ID) |
| Permissions vanish after every rebuild | Ad-hoc signing | Step 7 |
| Certificate shows "pending" or `find-identity` lists it but says `0 valid identities found` | Keychain lacks Apple's WWDR G3 intermediate | Download `https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer`, check its SHA-256 is `DC:F2:18:78:C7:7F:41:98:E4:B4:61:4F:03:D6:96:D8:9C:66:C6:60:08:D4:24:4E:1B:99:16:1A:AC:91:60:1F` (`openssl x509 -inform der -in AppleWWDRCAG3.cer -noout -fingerprint -sha256`), then the user runs `security add-certificates -k ~/Library/Keychains/login.keychain-db AppleWWDRCAG3.cer` |
| Holding fn opens the emoji picker or system dictation | macOS's fn action is still set | Step 5 |
| The pill appears, then closes after about 6 s with nothing typed | No voice detected (by design: accidental presses are discarded) | Check the mic is the input device and not muted; speak closer. The log line `peak input level` shows what the mic heard (speech is usually above 0.15) |
| Text is transcribed but never typed | No focused text field, or Accessibility missing | Focus a text field first; check step 4. NoType falls back to paste, so the text is also on the clipboard |
| Engine comparison shows Parakeet "Not installed" | Model not downloaded | Step 6 |
| Can't find the app after closing the window | Menu bar app, no Dock icon | Use the menu bar icon, or double-click NoType in Applications. Settings ▸ Show in Dock brings back a Dock icon; Settings ▸ Open at login starts it with the Mac |

## Windows

Before starting, tell the user plainly: the Windows app builds and passes its automated
tests, but **nobody has yet held the key and dictated with it on a real PC**. Their install
is the first real-hardware run. Untested so far: typing into the foreground app, a real
microphone, the keyboard hook on a physical key press, and Parakeet's speed and memory use
(around 2 GB) on real speech.

All commands below are PowerShell, run from the repo's `windows` folder unless stated.

### 1. Check prerequisites

| Check | Command | Need |
|---|---|---|
| Windows version | `[Environment]::OSVersion.Version` | Windows 10 or 11 |
| CPU | `$env:PROCESSOR_ARCHITECTURE` | `AMD64` (x64). On `ARM64`, build for `win-arm64` instead of `win-x64` below, or transcription runs slowly under emulation |
| .NET SDK | `dotnet --list-sdks` | a 10.0 SDK, 10.0.100 or later (`global.json` rolls forward to the latest 10.0 feature band) |
| git | `git --version` | any |

If the .NET 10 SDK is missing, ask the user before installing it. The usual route is
`winget install Microsoft.DotNet.SDK.10`, which shows a UAC prompt that the user approves.

### 2. Get the code

```powershell
git clone <repo-url> NoType
cd NoType\windows
```

### 3. Build and test

```powershell
dotnet test NoType.CrossPlatform.slnf
dotnet publish src/NoType.App/NoType.App.csproj --configuration Release --runtime win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true --output artifacts/publish
```

On ARM64 use `--runtime win-arm64`. The result is `artifacts\publish\NoType.App.exe`
(about 116 MB) plus the platform library published beside it. Keep the whole
`artifacts\publish` folder together: the app loads its Windows layer from a file next to
the exe, and it starts but ignores the hotkey if that file is missing.

If the user wants it somewhere permanent, copy the whole folder to
`%LOCALAPPDATA%\Programs\NoType`. That needs no administrator rights, and it avoids
`Program Files`, which does.

### 4. Download the speech model (required)

Parakeet is the Windows app's only speech engine, so this step is not optional. It is about
660 MB; ask the user before starting.

```powershell
$dir = "$env:LOCALAPPDATA\NoType\models\parakeet-v2"
$base = "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/resolve/main"
New-Item -ItemType Directory -Force $dir | Out-Null
foreach ($f in "encoder.int8.onnx","decoder.int8.onnx","joiner.int8.onnx","tokens.txt") {
    Write-Host "Downloading $f ..."
    curl.exe -L --fail --progress-bar -o "$dir\$f" "$base/$f"
}
Get-ChildItem $dir | Select-Object Name, Length
```

Check the sizes: `decoder.int8.onnx` 7,257,753 bytes, `joiner.int8.onnx` 1,739,080 bytes,
`tokens.txt` 9,384 bytes, and `encoder.int8.onnx` about 652 MB. A smaller file means the
download was cut short; delete it and download it again. This model is English only;
`docs/PARAKEET-WINDOWS.md` covers the 25-language v3 model.

### 5. Self-test

```powershell
$run = Start-Process -FilePath artifacts\publish\NoType.App.exe -ArgumentList '--selftest' -Wait -PassThru -NoNewWindow
$run.ExitCode
```

It prints `self-test: PASS` and exits with 0, or prints `self-test: N FAILED` and exits with
1. It checks the dictionary, settings storage, the model search paths, and that the Windows
layer loads and its audio, text and hotkey parts can be created. It does not record audio
or press keys. Fix any failure before going further.

### 6. First run (user actions)

Start `NoType.App.exe`. Three things may need the user:

1. **SmartScreen.** The exe is not code-signed, so Windows may show "Windows protected your
   PC". The user clicks **More info ▸ Run anyway** if they trust the build they just made.
2. **Microphone privacy.** Settings ▸ Privacy & security ▸ Microphone: "Microphone access"
   and "Let desktop apps access your microphone" must both be on.
3. **Antivirus.** Some products flag a new unsigned exe that installs a keyboard hook. If it
   is quarantined, the user decides whether to allow it; you don't add exclusions.

### 7. Verify (Windows)

Ask the user to open Notepad, hold **Right Ctrl**, say one short sentence and release. The
first dictation after launch takes about 2 seconds while the model loads; later ones are
faster. Right Ctrl is the default on purpose: Right Alt is AltGr on many European and
Latin-American layouts, so binding it would break typing `@`, `€`, `\` and `|`.

Settings, the dictionary and history live in `%LOCALAPPDATA%\NoType\` (`settings.json`,
`dictionary.txt`, `transcripts.jsonl`).

### Windows roadblocks

| Symptom | Cause | Fix |
|---|---|---|
| `dotnet` not found, or `NETSDK1045` / SDK version errors | .NET 10 SDK missing | Step 1 |
| `NETSDK1073` when building `NoType.sln` on a non-Windows machine | That solution includes the Windows-only project | Build `NoType.CrossPlatform.slnf` instead (expected behaviour) |
| Self-test fails on the platform layer, or the app runs but the key does nothing | The platform library isn't beside the exe | Run the app from the `artifacts\publish` folder, or copy the whole folder |
| "Model not found" | Files in the wrong folder | Put them in `%LOCALAPPDATA%\NoType\models\parakeet-v2`; Settings ▸ Model shows the path it checked |
| Protobuf or parse error when loading the model | Truncated download | Compare sizes (step 4); re-download the short file |
| Dictation records nothing | Microphone privacy block | Step 6.2 |
| SmartScreen blocks the exe | Unsigned build | Step 6.1 (user decision) |
| Transcription is slow | x64 build on an ARM64 PC | Rebuild with `--runtime win-arm64` |
| Recordings over about 7 minutes fail | The model's 400-second encoder limit | Dictate in shorter pieces |
| Anything else | Untested on real hardware | Report the exact error and the self-test output; this may be a real bug |

## Finishing

Report to the user:

1. What was installed, and where.
2. The result of each verification check, quoted.
3. Anything still waiting on them (a permission, a setting), as a short list.
4. On Windows, a reminder that this was the first run on real hardware if their test
   dictation worked, and the exact error if it didn't.

To uninstall on macOS: quit NoType from its menu, delete `/Applications/NoType.app`, and
optionally `~/Library/Application Support/NoType` (history and dictionary) and
`~/Library/Caches/NoTypeBuild`. The user can remove its permissions in System Settings.
