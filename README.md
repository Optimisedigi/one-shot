# One Shot

A fast, native macOS screenshot and annotation app. Capture a region with a hotkey, mark it up, save or copy. Nothing is uploaded and no account is required.

The installed app is named **Shotter**. It lives in the menu bar, not the Dock. It needs macOS 13 or later.

---

## Download

A signed, notarized installer is **not published yet**. The download and Homebrew commands below are the intended release shape. Do not treat them as working links until a GitHub release exists.

Planned direct download: `Shotter-0.1.0-macOS.dmg` on the GitHub releases page for [Optimisedigi/one-shot](https://github.com/Optimisedigi/one-shot).

When that file is published:

1. Open the DMG.
2. Drag **Shotter** onto the **Applications** folder.
3. Eject the disk image and open Shotter from Applications.

Planned Homebrew install, from this repository as a tap:

```bash
brew tap Optimisedigi/one-shot https://github.com/Optimisedigi/one-shot
brew install --cask Optimisedigi/one-shot/shotter
```

Those commands will fail until the cask and the notarized DMG are in the repository.

### Grant Screen Recording, one time

macOS will not let any app read your screen until you allow it. Shotter only captures when you press the hotkey.

1. Press **⌘⇧2** (the default capture hotkey).
2. macOS shows a permission prompt. Click **Open System Settings**.
3. Turn **Shotter** on under **Privacy & Security → Screen & System Audio Recording**.
4. Quit and reopen the app. macOS applies the new permission on restart.

Press **⌘⇧2** again to capture.

---

## Install from source

This path is for people who want to build it themselves. End users should wait for the DMG above.

You need **macOS 13+** and Xcode Command Line Tools:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/Optimisedigi/one-shot.git
cd one-shot
scripts/install-app.sh
```

The script builds the app, signs it with a local certificate, installs it to `/Applications/Shotter.app`, and opens it.

### Grant Screen Recording — required, one time

macOS will not let any app read your screen until you allow it.

1. Press **⌘⇧2** (the default capture hotkey).
2. macOS shows a permission prompt → click **Open System Settings**.
3. Turn **Shotter** on under **Privacy & Security → Screen & System Audio Recording**.
4. **Quit and reopen the app** — macOS only applies the new permission on restart.

Press **⌘⇧2** again and you're capturing.

---

## What the certificate is for

The installer creates a local code-signing certificate called **Shotter Local Development** in your login keychain, then signs the app with it. This is automatic — you don't need to do anything.

**Why it matters:** macOS ties Screen Recording permission to an app's signature. Without a stable signature, the permission is thrown away on every rebuild and you'd have to re-grant it forever. With it, you grant once and it sticks across updates.

The certificate is local to your Mac, self-signed, and used only to sign this app. It is never uploaded and grants no access to anything else.

> **Note:** running `swift run Shotter` directly produces an *unsigned* binary that macOS will never grant Screen Recording to. Always use the installed app for real use.

---

## Using it

| Action | How |
| --- | --- |
| Capture a region | **⌘⇧2**, then drag |
| Save to Desktop | **⌘S** (closes the editor) |
| Copy to clipboard | **⌘C** (copies the selected shape if one is selected) |
| Paste a copied shape | **⌘V** |
| Undo | **⌘Z** |
| Delete last annotation | **Delete** |
| Zoom in / out / reset | **+** / **-** / **0** |
| Close editor | **Esc** |

**Annotation tools:** Rectangle, Arrow, Text, Pixelate (to hide sensitive info), and Step badges (numbered circles for walkthroughs).

- Click a shape to select it, then drag to move. Corner handles resize; on boxes, edge handles stretch just width or height.
- **⌘C** / **⌘V** duplicates the selected box, text, number, or arrow. Paste as many times as you want (including the same number). With nothing selected, **⌘C** still copies the screenshot.
- Selecting a shape lets you change its color and thickness from the toolbar.
- Double-click a Step badge to edit its number.
- Picking a different tool and clicking inside an existing shape draws a new one instead of moving the old one.

Change the capture hotkey and launch-at-login in **Preferences**, from the menu bar icon.

---

## Updating

```bash
git pull
scripts/install-app.sh
```

Your Screen Recording permission carries over, thanks to the certificate.

---

## Development

```bash
swift build          # compile
swift run Shotter    # run unsigned (capture will be blocked by macOS)
scripts/build-app.sh # build + sign a bundle at .build/Shotter.app without installing
```

There is no automated test suite. `swift build` is the compile check.

### Repeatable notarized release

`scripts/release-dmg.sh` builds a universal app (Apple silicon and Intel), signs it with **Developer ID Application: Peter Tu (NSD8UNQK9J)**, notarizes the app and the DMG, staples both tickets, and writes a SHA-256 file next to the DMG. It refuses to finish unless Apple returns Accepted and stapling validates.

Store the notary login in the Keychain once. The password is prompted locally and is not written into the repo:

```bash
xcrun notarytool store-credentials shotter-notary \
  --apple-id "YOUR_APPLE_ID" \
  --team-id NSD8UNQK9J
```

Use an app-specific password from [appleid.apple.com](https://appleid.apple.com), not your normal Apple ID password. Then:

```bash
scripts/release-dmg.sh
```

The result is `dist/Shotter-<version>-macOS.dmg`. Do not commit `dist/`.

This script has not produced a published DMG yet, because the `shotter-notary` Keychain profile is not on this Mac.

---

## Troubleshooting

**Capture is blank, or nothing happens on the hotkey.**
Screen Recording isn't granted. Follow the steps above, and make sure you fully quit and reopen the app afterwards.

**Permission looks granted but still doesn't work.**
An old unsigned copy may be holding a stale entry. Reset it and reinstall:

```bash
tccutil reset ScreenCapture local.shotter.app
scripts/install-app.sh
```

**The hotkey does nothing.**
Another app may own that shortcut. Pick a different one in Preferences.

**`scripts/install-app.sh: permission denied`**

```bash
chmod +x scripts/*.sh
```
