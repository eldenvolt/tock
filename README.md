# Tock

<img src="Tock/AppIcon.png" alt="Tock app icon" width="128">

Super-minimal menubar timer with quick parsing, stopwatch mode, and configurable repeating tones.

## Features

- Menubar timer with countdown + stopwatch, plus quick natural-language input.
- Notification settings for tone (default: gentle-roll), repeat (default: 10x), volume (default: medium), and unit when omitted (default: minutes).
- Context menu and popover controls for start/pause/clear and settings.

## Usage

- Enter a duration like `10`, `5m`, `1.5h`, or `45 sec`, then press Enter.
- Click the play button to start a stopwatch without a countdown.
- Clear stops the timer and silences the alarm.

## Shortcuts

- Open popover: ⌃⌥⌘T
- Clear timer: ⌃⌥⌘X

## Build and run

1. Open `Tock.xcodeproj` in Xcode.
1. Select the `Tock` scheme.
1. Build and run.

## Archive and export

1. `Product > Archive`
1. Organizer > `Distribute App` > `Custom` > `Copy App`
1. Open the export folder and move the inner `Tock.app` to `/Applications`.

## Download

Download the latest macOS build:

`https://github.com/edelstone/tock/releases/latest/download/Tock.dmg`

First launch:

1. Drag `Tock.app` to `/Applications`.
1. Right-click `Tock.app` and choose `Open`.

## Releasing

This repo includes a GitHub Actions workflow that builds an unsigned DMG on tag pushes and uploads it to a GitHub Release.

1. Tag a release: `git tag v0.1.0`
1. Push the tag: `git push origin v0.1.0`

## Login item

- Add via `System Settings > General > Login Items`.
