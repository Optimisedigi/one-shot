# Shotter

A native macOS Swift/AppKit screenshot and annotation MVP inspired by lightweight tools like Shottr.

## Run in development

```bash
swift run Shotter
```

The app appears in the menu bar. Use **Capture Region** from the menu or press the default global hotkey **⌘⇧2**.

## Build a local .app bundle

```bash
scripts/build-app.sh
open .build/Shotter.app
```

macOS requires Screen Recording permission for capture. If capture is blank or denied, grant permission in System Settings → Privacy & Security → Screen & System Audio Recording, then restart the app.
