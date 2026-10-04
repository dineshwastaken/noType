# NoType

Hold a key, talk, and let go. NoType turns what you said into cleaned-up text and types it
into whatever app you're using. Speech recognition runs on your computer; your voice is not
sent anywhere.

On macOS it lives in the menu bar, uses Apple's Liquid Glass design, and shows your words in
a small pill under the notch while you speak.

| | macOS | Windows |
|---|---|---|
| Status | Works, in daily use | Builds and passes its tests; not yet tried on a real PC |
| Needs | macOS 26 or later, Apple silicon, Xcode 26 or later to build | Windows 10/11, .NET 10 SDK to build |
| Push-to-talk key | fn | Right Ctrl |
| Speech engine | Apple's on-device engine; Parakeet optional | Parakeet (about 660 MB download) |

## Install with an AI coding agent

The repo includes a setup skill that walks an agent through the whole install on either OS,
including what to do when something goes wrong. Give your agent (Claude Code, Codex, Cursor
or similar) this prompt:

```text
Set up NoType on this computer from https://github.com/dineshwastaken/noType.
Clone it, then follow skills/install-notype/SKILL.md exactly.
```

The agent does the checks, builds and verification. A few steps need you: anything that
asks for your password, privacy permissions (Accessibility and Microphone on a Mac,
microphone access on Windows), and large downloads. The agent stops and tells you exactly
what to click when it reaches one.

## Install by hand

The full steps, with fixes for every problem we know about, are in
[skills/install-notype/SKILL.md](skills/install-notype/SKILL.md). The short version:

### macOS

1. Install Xcode from the App Store, then accept its licence:
   `sudo xcodebuild -license accept`
2. Build and install:
   ```bash
   git clone https://github.com/dineshwastaken/noType.git NoType
   cd NoType
   make install
   ```
3. Turn on NoType in System Settings ▸ Privacy & Security ▸ Accessibility (called "Device
   Control and Data Access" on macOS 27), and allow the microphone when asked.
4. In System Settings ▸ Keyboard, set "Press 🌐 key to" to **Do Nothing**.
5. Hold fn, say something, let go.

### Windows

1. Install the .NET 10 SDK.
2. Build, then download the speech model (commands in the skill, step 4):
   ```powershell
   git clone https://github.com/dineshwastaken/noType.git NoType
   cd NoType\windows
   dotnet publish src/NoType.App/NoType.App.csproj --configuration Release --runtime win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true --output artifacts/publish
   ```
3. Run `artifacts\publish\NoType.App.exe --selftest`, then start the app. Windows may warn
   that the app is unrecognised because it isn't code-signed.
4. Hold Right Ctrl, say something, let go.

## Using it

Hold the key while you talk and release it when you're done. If you press it by accident and
say nothing, NoType throws the recording away after 6 seconds.

On a Mac, NoType has no Dock icon. Its menu bar icon opens the main window, which holds
your transcription history, a dictionary for names and jargon it keeps getting wrong, and
Settings. NoType has to be running for the key to work; Settings ▸ Open at login starts it
with your Mac.

| Say | You get |
|---|---|
| "new line" | a line break |
| "new paragraph" | a blank line |
| "open paren", "close paren" | ( ) |

Punctuation comes from speaking naturally, and filler words like "um" are removed.

## More

- [RELEASE_NOTES.md](RELEASE_NOTES.md): everything in NoType 1.0.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): architecture and design decisions for the
  macOS app.
- [windows/README.md](windows/README.md) and
  [docs/PARAKEET-WINDOWS.md](docs/PARAKEET-WINDOWS.md): the Windows app in depth.
- [AGENTS.md](AGENTS.md): read this before changing the code.

## License

MIT. See [LICENSE](LICENSE).
