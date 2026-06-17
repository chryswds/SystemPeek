# SystemPeek

A macOS notch widget that shows live system telemetry. A small strip sits under
the notch; **hover it and a panel expands** with current **CPU**, **memory**, and
**disk** usage, refreshing about once a second. Inspired by NotchNook / Boring Notch.

SystemPeek runs as a background (`accessory`) app — **no Dock icon**.

## Privacy & security

- Reads only **aggregate, read-only** system metrics (CPU load, memory stats, disk
  capacity) via Apple's Darwin APIs. No network access.
- Runs under the **App Sandbox** with no extra entitlements (least privilege) and
  **never as root**.
- It sits next to the camera but **does not access the camera or microphone**.
- Hover is detected by reading the cursor position (`NSEvent.mouseLocation`) on a
  timer — **no event taps, no Input Monitoring permission**, and it cannot see
  clicks or keystrokes.

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

or from the command line:

```sh
xcodebuild -scheme SystemPeek -destination 'platform=macOS' build
```

The committed `SystemPeek.xcodeproj` lets the repo build without XcodeGen; rerun
`xcodegen generate` only after editing `project.yml`.

## Test

```sh
xcodebuild test -scheme SystemPeek -destination 'platform=macOS'
```

- **Unit + integration tests** (`SystemPeekTests`) cover the metric math and a real
  sample sanity-check.
- **End-to-end test** (`SystemPeekUITests`) launches the real app, moves the cursor
  onto the notch panel, and asserts it expands then collapses — observed via the
  live window height. It **moves the system cursor**, so don't drive the
  mouse/trackpad while it runs.
