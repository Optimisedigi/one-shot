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

## Install as a searchable macOS app

```bash
chmod +x scripts/install-app.sh
scripts/install-app.sh
```

This installs Shotter to `/Applications/Shotter.app`, so it can be opened from Spotlight, Launchpad, or Finder like a normal app.

The build script creates and reuses a local code-signing identity named `Shotter Local Development` so macOS Screen Recording permission can persist across rebuilds. macOS still requires Screen Recording permission for first use; if capture is blank or denied, grant permission in System Settings → Privacy & Security → Screen & System Audio Recording, then restart the app.
