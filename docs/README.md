# Developer docs

Everything here is for people who want to build, change or ship Dynamic Notch. If you only want
to use the app, see the [main README](../README.md).

| Doc | What's in it |
|---|---|
| [Research](RESEARCH.md) | What the iPhone Dynamic Island does and what moved to the Mac |
| [Design](DESIGN.md) | Sizes, colours, type and motion |
| [Architecture](ARCHITECTURE.md) | How the code is organised, data flow, debug commands |
| [QA report](QA.md) | Tests, on-screen checks, performance, known limitations |
| [Shipping](SHIPPING.md) | Making a release, now and once the app is signed |

## Build and run

Needs Swift 6 (Xcode 16 or later). Built and tested with Xcode 26.4 on macOS 27.

```bash
git clone https://github.com/shandilyaswagat/dynamic_notch.git
```

```bash
cd dynamic_notch && ./Scripts/build-app.sh
```

```bash
open "build/Dynamic Notch.app"
```

`CONFIG=debug ./Scripts/build-app.sh` builds a debug app that also accepts the debug commands
listed in [Architecture](ARCHITECTURE.md). You can also open `Package.swift` in Xcode.

## Checks

Unit tests plus a release build where any warning is an error:

```bash
./Scripts/check.sh
```
