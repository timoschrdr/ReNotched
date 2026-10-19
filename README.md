# ReNotched

**A simple, free app that turns the notch of your MacBook into a Dynamic Island.**

ReNotched is deliberately small. It sticks closely to Apple's design guidelines (system fonts, SF Symbols,
native controls, spring animations) and therefore has no crazy features: just the things you glance at
every day, done nicely.

- Animated feedback for **volume**, **copying**, **charger plugged in** and **headphones connecting** (with battery level when the device reports it)
- **Now playing** from any app (Music, Spotify, browsers, …): cover, title, progress and controls. Click the island to expand it, click elsewhere to close it
- Cover transition and equalizer tinted with the album cover's colour
- Each indicator can be switched off in the settings; English and German UI, chosen automatically from the system language

## Build

```bash
./build.sh && open build/ReNotched.app
```

Requirements: macOS 14 or later, Xcode / Swift 5.9 or later. A MacBook with a notch is recommended; without one the island appears at the top centre of the screen.

## Privacy

ReNotched works entirely on your Mac. It collects, stores and sends **no data** and makes **no network connections**.
Clipboard text, now-playing information and Bluetooth device names are only read to display them on the island and are never saved.
macOS asks for Bluetooth access so the app can notice when headphones connect.

## Legal

- ReNotched is an independent project. It is **not affiliated with, authorised or endorsed by Apple Inc.**
  Apple, MacBook, macOS, Dynamic Island and SF Symbols are trademarks of Apple Inc.
- The app is provided **"as is", without warranty of any kind** (see `LICENSE`). Use it at your own risk.
- Now-playing information is read through the private MediaRemote interface via the third-party
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3-Clause, © Jonas van den Berg and contributors; see `Vendor/MediaRemoteAdapter.LICENSE`),
  because Apple has restricted that interface for regular apps since macOS 15.4.
  Private interfaces can change or stop working with any macOS update, and apps using them cannot be distributed through the Mac App Store.
- SF Symbols are used as permitted by Apple's SF Symbols license for apps running on Apple platforms.
- Album covers and track information are shown locally only and are not stored or shared.

## License

ReNotched is released under the MIT License (see `LICENSE`). Third-party components keep their own licenses (see above).
The app icon can be regenerated with `swift Tools/make-icon.swift`.
