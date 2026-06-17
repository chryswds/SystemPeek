# SystemPeek

A macOS notch widget that surfaces live system telemetry. It stays **completely
hidden** until you **hover the notch** — then the notch **morphs open** into an
island showing your system at a glance, and retracts when you move away.
Inspired by NotchNook / Boring Notch.

SystemPeek runs as a background (`accessory`) app: no Dock icon, just a small
wave glyph in the menu bar for settings and quit.

<p align="center">
  <img src="docs/demo.gif" alt="SystemPeek revealing system metrics on notch hover" width="760">
</p>

## Features

- **Hover-to-reveal** — nothing on screen until your cursor reaches the notch;
  the panel then springs out of the notch as a Dynamic-Island-style morph.
- **Live metrics**, refreshed ~once a second:
  - **CPU**, **Memory**, **Disk** usage (percent + bar)
  - **Network** throughput (↓ download / ↑ upload)
  - **Load average** (1 / 5 / 15 min) and **Swap** used
  - **Top process by CPU** and **by memory** (highlighted)
- **Configurable** — a settings window lets you toggle which metrics appear; the
  island resizes to fit your selection.
- **Menu-bar control** — a wave icon with **Settings…** and **Quit**.
- **Launch at login** — optional, via a toggle in settings.

## How it works

- The panel is a borderless, non-activating `NSPanel` anchored to the top of the
  screen so its shape merges with the real notch.
- Hover is detected by **polling the cursor position** (`NSEvent.mouseLocation`)
  on a timer — no event taps, no global monitors.
- The reveal is a pure-SwiftUI morph: a `NotchShape` grows from the notch's exact
  footprint to the island while the metrics fade in (the window itself never
  animates, so there's no sliding/glitching).
- Metrics come from Darwin / IOKit:
  `host_statistics` (CPU/memory), volume capacity (disk), `getifaddrs`
  (network), `getloadavg`, `sysctl vm.swapusage`, and `proc_listpids` +
  `proc_pid_rusage` (top processes).

## Privacy & security

- Reads only **read-only** system metrics. **No network access. Never runs as
  root.**
- Sits next to the camera but **does not access the camera or microphone**.
- Hover uses only the **cursor position** — it cannot see clicks or keystrokes,
  and needs no Accessibility/Input-Monitoring permission.
- **The App Sandbox is off.** Showing the top process by CPU/memory requires
  enumerating other processes, which the sandbox blocks (`proc_listpids` →
  `EPERM`). This trades some isolation for that feature; the app remains
  read-only and unprivileged.

## Requirements

- macOS 14+ (built/tested on macOS 26, Apple Silicon)
- Xcode 16+ (developed on Xcode 26)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to (re)generate the project:
  `brew install xcodegen`

## Build & run

```sh
xcodegen generate          # regenerate SystemPeek.xcodeproj from project.yml
open SystemPeek.xcodeproj  # then press ⌘R
```

…or from the command line:

```sh
xcodebuild -scheme SystemPeek -configuration Release -destination 'platform=macOS' build
```

The committed `SystemPeek.xcodeproj` lets the repo build without XcodeGen; rerun
`xcodegen generate` only after editing `project.yml`.

### Using it

Launch the app — nothing appears (it's a background app). **Hover your notch** to
reveal the island. Open **Settings…** or **Quit** from the wave icon in the menu
bar.

## Tests

```sh
xcodebuild test -scheme SystemPeek -destination 'platform=macOS'
```

- **Unit + integration** (`SystemPeekTests`) — the metric math (CPU/memory/disk/
  network/swap/top-process leaders) plus real-sample sanity checks.
- **End-to-end** (`SystemPeekUITests`) — launches the real app, moves the cursor
  onto the notch, and asserts the panel reveals then hides (observed via the live
  window list). It **moves the system cursor**, so don't drive the mouse/trackpad
  while it runs.

## Project layout

```
SystemPeek/
  Metrics/        # CPU, Memory, Disk, Network, Load, Swap, ProcessUsage + sampler
  UI/             # ExpandedView (island), NotchShape, SettingsView
  NotchPanel.swift  # the borderless panel, hover polling, and morph
  AppDelegate.swift # menu-bar item, settings window, lifecycle
SystemPeekTests/    # unit + integration
SystemPeekUITests/  # end-to-end
project.yml         # XcodeGen project definition
```
