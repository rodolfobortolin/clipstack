# Clipstack

A native clipboard history for the Mac menu bar. Press ⇧⌘V and everything you've copied
is right there: search it, preview it, and paste it straight into the app you're using.
Built to replace CopyClip, with images, files, colors and snippets with variables on top.

*[Português](README.pt-BR.md)*

## Install

Download the latest `Clipstack.dmg` from [Releases](../../releases/latest), open it
and drag **Clipstack** to Applications (there's a `.zip` too, if you prefer). It's signed
with a Developer ID and notarized by Apple, and runs on Macs with Apple silicon or Intel
and macOS 14 Sonoma or later.

To paste for you, Clipstack needs **Accessibility** permission (it sends ⌘V to the app
you're in); it asks the first time. Without it, the item is copied and you press ⌘V
yourself.

## What it does

- Keeps text, rich text, links, colors (`#RRGGBB`), images and files copied in Finder.
- A Spotlight-style panel (Liquid Glass on macOS 26) with instant search, filters and a
  preview alongside.
- Pastes right into the app you're using; ⇧↩ pastes as plain text.
- Pin items to the top, edit and rename them, save them as snippets.
- Snippets with `{date}`, `{time}`, `{datetime}`, `{weekday}`, `{clipboard}`, `{uuid}` and
  `{date:FORMAT}`.
- A compact menu at the pointer, on a second shortcut.
- Skips passwords (`org.nspasteboard.ConcealedType` and friends) and the apps you choose.
- Pause recording for 15 minutes, an hour or until you resume.
- Shows which app each item came from.
- Appearance: glass, translucent or solid; light, dark or automatic; accent color and density.

## Shortcuts

| Shortcut | Action |
|---|---|
| ⇧⌘V | Open the history |
| ⌃⇧V | Menu at the pointer |
| ↩ · ⇧↩ · ⌥↩ | Paste · paste as plain text · copy only |
| ⌘1 … ⌘0 | Paste one of the first ten |
| ⇥ | Next filter |
| Space or ⌘Y | Show or hide the preview |
| ⌘P · ⌘E · ⌘S · ⌘⌫ | Pin · edit · save as snippet · delete |

Both global shortcuts can be changed in Settings → Shortcuts.

## Languages

English, Portuguese (Brazil), Spanish, French, German, Italian, Japanese and Simplified
Chinese. Clipstack follows the Mac's language, or you can pick one just for it in
Settings → General → Language. Strings live in `Resources/Localizable.xcstrings`;
`Scripts/update-strings.sh` adds new keys from the code.

## Build

Needs Xcode 16 or later (Swift 6.2).

```sh
Scripts/build-app.sh            # build/Clipstack.app
Scripts/build-app.sh --install  # and install it in /Applications
Scripts/notarize.sh             # notarize it, then a zip and a disk image to share
```

The build signs with the first **Developer ID Application** identity in your Keychain (set
`SIGN_IDENTITY` to choose another). Keep the signature stable: macOS ties the
Accessibility permission to it, and an ad hoc signature would ask again after every build.

The icon is `Resources/AppIcon.icon`, an Icon Composer icon that `actool` compiles into
`Assets.car` (drawn by macOS 26 in its own shape and glass) and an `.icns` for earlier
versions.

## iCloud sync

The code is ready (SwiftData with CloudKit), but Apple only enables iCloud for apps with an
App ID and a provisioning profile. With your own developer account:

1. Create an App ID with the **iCloud** (CloudKit) capability and a container, for example
   `iCloud.<your bundle id>`, at
   [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list).
2. Create a **Developer ID** provisioning profile for it and save it as
   `Resources/embedded.provisionprofile`.
3. Create `Resources/Clipstack.entitlements` with your team ID, the application identifier,
   the iCloud container and `CloudKit` as the iCloud service.
4. Run `Scripts/build-app.sh --install` and turn sync on in Settings → Privacy.

Both files stay out of the repository (see `.gitignore`).

## How it's built

| Part | Where |
|---|---|
| Watching the clipboard (polls `changeCount` every 0.5 s) | `Core/ClipboardMonitor.swift` |
| History and snippets (SwiftData) | `Core/ClipStore.swift`, `Models/` |
| Pasting (pasteboard + ⌘V via `CGEvent`) | `Core/Paster.swift` |
| Global shortcuts (Carbon `RegisterEventHotKey`) | `Core/HotKeyCenter.swift` |
| Panel (a non-activating `NSPanel` + SwiftUI) | `UI/Panel/` |
| Menu bar and menu at the pointer | `UI/Menus.swift` |
| Settings | `UI/Settings/` |

The history lives in `~/Library/Application Support/Clipstack/Clipstack.store`. Clipstack
doesn't use the network and isn't sandboxed.

## License

[MIT](LICENSE) © Rodolfo Bortolin
