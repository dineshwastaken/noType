# NoType 1.0

Hold a key, talk, and let go: NoType types what you said, cleaned up, into whatever app you
were using. Speech recognition runs on your computer, so your voice never leaves it. This is
the first release.

## Dictation anywhere

Hold fn on a Mac (Right Ctrl on Windows), speak, and release. Apple's on-device engine
streams text while you talk, so the words are usually ready the moment you let go. NoType
removes filler words like "um", fixes spacing and punctuation, and understands "new line",
"new paragraph", "open paren" and "close paren".

If you press the key by accident and say nothing, NoType discards the recording after 6
seconds and types nothing. Once you've started speaking, pauses never end the recording;
only letting go does.

## A pill under the notch

While you dictate, a dark glass pill drops out of the notch and shows your words as you say
them, then slides back up when you let go. It sits 8 pt below the notch, centred on it, and
stays readable over any window or wallpaper. On a display without a notch it appears under
the menu bar. With Reduce Motion on, it fades instead.

## Lives in the menu bar

NoType has no Dock icon. Its menu bar icon opens the main window and Settings, and closing
the window leaves it running so the key keeps working. Turn on Open at login and it starts
with your Mac. Show in Dock is there if you want the icon back.

## Liquid Glass design

The main window follows Apple's Liquid Glass design: a sidebar for Transcriptions and
Dictionary, search in the toolbar, and a recorder bar floating at the bottom with the mic
button, a live waveform, status and timer. Light and dark mode follow the system, and
Settings ▸ Appearance can fix either one.

## Your history and dictionary

Every dictation is saved in a searchable history, with copy and delete on each entry. The
dictionary teaches NoType words it gets wrong. Add a term ("Anthropic") to steer
recognition, or a correction ("cloud code" becomes "Claude Code") that is applied every
time. Corrections also catch run-together and hyphenated forms such as "CloudCode", warn you
when an entry could match ordinary words, and show in the history whenever they fire. The
dictionary is a plain text file you can also edit by hand.

## Smart cleanup

Turn on Smart cleanup and Apple's on-device language model tidies each dictation: it
formats spoken lists and applies corrections like "Tuesday, actually Wednesday". If the
model is unavailable or slow, NoType falls back to the standard cleanup.

## Two speech engines

Apple's engine is the default and needs no download. Parakeet, a second on-device engine
that runs on the Neural Engine, is a one-time 470 MB download from the menu bar. Compare
mode runs every installed engine on the same recording and shows the results side by side
with their timings; nothing is typed in that mode.

## Requirements

- macOS 26 or later on Apple silicon. NoType needs Accessibility permission to see the key
  and type text, and Microphone permission.
- On macOS, set System Settings ▸ Keyboard ▸ "Press 🌐 key to" to Do Nothing, or the emoji
  picker opens alongside NoType.
- Windows 10 or 11 with the .NET 10 SDK to build, and the 660 MB Parakeet model.

## Installing

Point your coding agent at the repository and ask it to follow
`skills/install-notype/SKILL.md`, or follow the steps in the README.

## Building from source

- The macOS app needs full Xcode 26 or later; Command Line Tools alone can't build it.
- `make install` signs with a Developer ID or Apple Development certificate when one is in
  your keychain. With a stable signature, macOS keeps NoType's permissions across rebuilds;
  ad-hoc builds lose them each time.

## Known limitations

- NoType has to be running for the hotkey to work.
- "comma", "period" and "next line" are not commands; punctuation comes from speaking
  naturally.
- Bullet points and "scratch that" depend on Smart cleanup and don't always work.
- The Windows app builds and passes its automated tests but hasn't been used on a real PC
  yet. Its typing into apps, microphone handling and hotkey are untested on real hardware.
- Neither app is notarized or code-signed for distribution.
