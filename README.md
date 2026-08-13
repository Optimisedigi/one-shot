# One Shot

A fast, native macOS screenshot and annotation app. Capture a region with a hotkey, mark it up, save or copy — no browser, no account, no upload.

Built in Swift/AppKit, inspired by lightweight tools like Shottr.

---

## Install (macOS)

You need **macOS 13+** and Xcode Command Line Tools. If you don't have them, run this first and accept the prompt:

```bash
xcode-select --install
```

Then install One Shot with one command:

```bash
git clone https://github.com/Optimisedigi/one-shot.git
cd one-shot
scripts/install-app.sh
```

That's it. The script builds the app, signs it, installs it to `/Applications/Shotter.app`, and opens it. It runs in the menu bar (no Dock icon).

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
| Copy to clipboard | **⌘C** |
| Undo | **⌘Z** |
| Delete last annotation | **Delete** |
| Zoom in / out / reset | **+** / **-** / **0** |
| Close editor | **Esc** |

**Annotation tools:** Rectangle, Arrow, Text, Pixelate (to hide sensitive info), and Step badges (numbered circles for walkthroughs).

- Click a shape to select it, then drag to move or use the corner handles to resize.
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
