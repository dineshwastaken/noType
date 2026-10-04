# NoType 0.1.0

October 2026. The first release under the NoType name, with an interface rebuilt on Apple's
Liquid Glass and the fixes that came out of using it day to day. Requires macOS 26 or later.

## What's new

### NoType lives in the menu bar

NoType no longer sits in the Dock. Hold fn anywhere to dictate; the menu bar icon opens the
main window and Settings. Closing the window leaves NoType running, because the hotkey only
works while it runs. Turn on Settings ▸ Open at login and you won't have to think about it.
If you'd rather have the Dock icon, Settings ▸ Show in Dock brings it back.

### A pill under the notch

While you dictate, a dark glass pill drops down from the notch with your words as you say
them. It retracts into the notch when you let go. Its top edge sits 8 pt below the notch,
centred on it; on a display without a notch it sits under the menu bar instead. With Reduce
Motion on, it fades in and out.

The pill uses smoke-tinted glass so the text stays readable over any wallpaper or window,
light or dark.

### Liquid Glass throughout

The main window has a sidebar for Transcriptions and Dictionary, search in the toolbar, and
a recorder bar floating at the bottom: one glass capsule holding the mic button, a live
waveform, the status and a timer. Settings uses the standard macOS layout. Light and dark
mode follow the system, and Settings ▸ Appearance can pin either one. The app icon is new
too.

### fn is the push-to-talk key

Every Mac keyboard has fn in the same corner. Set System Settings ▸ Keyboard ▸ "Press 🌐 key
to" to Do Nothing, or the emoji picker will open alongside NoType. Right ⌥ and Right ⌘ are
still available in Settings.

### Accidental presses clean up after themselves

Letting go of the key closes the pill straight away. If you press it and say nothing, NoType
discards the recording after 6 seconds and types nothing. The same applies to a key release
the app missed or a mic button left running.

### Voice commands

Say "new line" or "new paragraph" for line breaks, and "open paren" and "close paren" for
brackets. Punctuation comes from speaking naturally. NoType strips um, uh, erm and hmm.
With Smart cleanup on, the on-device model also tries to format spoken lists and apply
corrections like "Tuesday, actually Wednesday", though it doesn't always get them.

## Fixes

- Engine comparison could hang for minutes. If Parakeet's models weren't installed, a
  comparison started their one-time 470 MB download after the recording had ended, with no
  progress shown. Comparison now skips an engine that isn't installed and says so. Use
  "Download Parakeet models…" in the menu bar to install it first.
- An interrupted model download counted as installed. NoType now checks for every model
  file and the vocabulary before trusting a download.
- A skipped or failed engine showed up as the "fastest" in comparison results. Only
  engines that returned text are ranked now.
- Changing the hotkey before granting Accessibility left it dead until a relaunch. The
  hotkey now arms itself within a second of the grant, whatever the order.
- The waveform barely moved for quiet microphones. It now responds to quieter input, and
  the silence check treats about −42 dBFS as speech.
- The recorder bar's timer could wrap onto two lines.

## Removed

The old HTML dashboard, which nothing opened any more, and its `notype://clear` link, which
any web page could have used to wipe your history without asking. `notype://show` still
opens the comparison window.

## For developers

- Building now needs full Xcode. In the macOS 27 SDK, `@State` and swift-testing's `@Test`
  are macros whose plugins only ship with Xcode.
- `make install` signs with a Developer ID or Apple Development certificate when one is in
  your keychain. With a stable signature, macOS keeps the Microphone and Accessibility
  grants across rebuilds. Ad-hoc builds still lose them every time.
- If the Accessibility switch shows on but the hotkey does nothing, the entry belongs to an
  older signature. Remove NoType from the list and add it again.

## Known limitations

- NoType has to be running for the hotkey to work.
- "next line", "comma" and "period" are not commands.
- Bullet points and "scratch that" only work through Smart cleanup, and not reliably.
- The Windows port has been renamed to NoType but still hasn't been tried on real hardware.
