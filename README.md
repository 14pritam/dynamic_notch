<p align="center">
  <img src="Support/AppIcon-1024.png" width="128" alt="Dynamic Notch icon">
</p>

<h1 align="center">Dynamic Notch</h1>

<p align="center">Live activities for the MacBook notch.</p>

The notch itself grows to show what's happening, the way the Dynamic Island works on iPhone:
music, timers, calls, charging, AirPods and AirDrop. When nothing is going on it disappears back
into the notch.

## Features

* **Now Playing** from any app (Music, Spotify, browsers, Podcasts…): artwork, bars tinted to the
  artwork, scrubbing, play/pause/skip.
* **Timer** with quick presets, pause and cancel, and a "Done" alert with Repeat and Stop.
* **Calls and microphone use** with a running duration (FaceTime, Zoom, Meet, Teams…).
* **Alerts**: charging, low battery (20 % and 10 %), headphones connected.
* **AirDrop**: drag files to the notch and drop them.
* **Two activities at once**: the second detaches into a bubble; swipe with two fingers to swap.
* **Your size**: Small, Medium or Large, plus width and thickness fine-tuning, with live preview.
  Pitch black by default, so the extension looks like part of the notch. An optional floating
  pill style adds position controls.
* Native settings window, menu bar item, open at login, Reduce Motion support.

## Requirements

* macOS 14 Sonoma or later. Tested on macOS 27.
* Best on Macs with a notch. Other displays get a virtual notch at the top centre of the screen.

## Build and run

Needs Swift 6 (Xcode 16 or later). Built and tested with Xcode 26.4.

```bash
git clone https://github.com/shandilyaswagat/dynamic_notch.git
```

```bash
cd dynamic_notch && ./Scripts/build-app.sh
```

```bash
open "build/Dynamic Notch.app"
```

Run the unit tests and the warnings-as-errors release build:

```bash
./Scripts/check.sh
```

You can also open `Package.swift` in Xcode. A local build is signed ad hoc and runs on the Mac
that built it; see [Shipping](docs/SHIPPING.md) for a signed, notarized DMG.

## Using it

* Hover the notch to see it swell; click it for Home (quick timers and the last media).
* Click a live activity to expand it. Click elsewhere or move the pointer away to collapse.
* Right-click for activity actions, Settings and Quit.
* Settings live in the menu bar item (capsule icon). If you hide that icon, open the app again
  from Applications to get back to Settings.

## Privacy

No network requests, no analytics, no permission prompts. Call detection reads which app holds
the microphone from Core Audio; it never records anything.

## How Now Playing works

macOS has no public API for "what's playing in any app". Since macOS 15.4 the private
MediaRemote framework only answers Apple-signed processes, so a small helper library runs inside
the system's `/usr/bin/perl` and streams track info to the app over a pipe. Because of this the app
can't be on the Mac App Store, and if a future macOS closes the gap, Now Playing stops while
everything else keeps working.

## Docs

* [Research: what moves from iPhone to Mac](docs/RESEARCH.md)
* [Design spec](docs/DESIGN.md)
* [Architecture](docs/ARCHITECTURE.md)
* [QA report](docs/QA.md)
* [Shipping](docs/SHIPPING.md)
