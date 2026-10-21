# Shipping

Dynamic Notch is distributed as a DMG on GitHub Releases, outside the Mac App Store (the Now
Playing helper uses a private macOS framework, which App Review does not allow).

There are two stages:

| | Now: unsigned | Later: signed and notarized |
|---|---|---|
| Cost | Free | Apple Developer Program, $99 a year |
| What users see on first open | "Not Opened" warning, then **Open Anyway** in Privacy & Security | One normal "downloaded from the internet" prompt |
| What changes in the README | Install steps 3–4 and the Terminal option | Remove those steps and the note above them |

Release assets are always named `DynamicNotch.dmg`, so the README's link
`releases/latest/download/DynamicNotch.dmg` always points to the newest version.

## Versions and the changelog

* The version lives in the `VERSION` file. It follows semantic versioning: bump the last number
  for fixes (1.1.0 → 1.1.1), the middle one for new features (1.1.1 → 1.2.0), the first one for
  big changes that break how people use the app.
* The build number is the commit count, so it always goes up on its own.
* Every release gets a section in [CHANGELOG.md](../CHANGELOG.md), written for users. The release
  script copies that section into the GitHub release notes, so write it the way you'd want people
  to read it.

## Making a release now (unsigned)

1. Change `VERSION`, add the matching `## [x.y.z] - date` section to `CHANGELOG.md`, and commit.
2. Run the manual checklist in [QA.md](QA.md) on a build of that commit.
3. Run:

   ```bash
   ./Scripts/release.sh
   ```

The script stops if the working tree isn't committed, the tag already exists, or the changelog
has no section for the version. Then it runs all checks, builds `build/DynamicNotch.dmg`, tags
`vX.Y.Z`, pushes, and publishes the GitHub release with the changelog section as its notes (plus
short install steps for new users).

### Why downloaded copies still get Now Playing

Everything inside a downloaded app carries macOS's quarantine flag. Opening the app with **Open
Anyway** approves the app, but the Now Playing helper is loaded by `/usr/bin/perl`, which would
trigger a second, separate warning for the library and fail. So on launch the app writes its own
copy of the helper to `~/Library/Application Support/Dynamic Notch/` (a copy the app writes has no
quarantine flag and keeps the library's signature) and loads that.

## Moving to signed and notarized releases

### What you need once

1. **Apple Developer Program** membership.
2. A **Developer ID Application** certificate in your login keychain: Xcode › Settings ›
   Accounts › Manage Certificates › + › Developer ID Application. An *Apple Development*
   certificate is not enough: Gatekeeper rejects it on other Macs and it can't be notarized.
3. A notarization profile stored in the keychain:

   ```bash
   xcrun notarytool store-credentials dynamic-notch --apple-id you@example.com --team-id TEAMID
   ```

   It asks for an app-specific password (appleid.apple.com › Sign-In and Security).
4. Optional: change the bundle id (`BUNDLE_ID`, default `com.rectircle.DynamicNotch`).

### Release steps

Same as above, with your identity and notarization profile set:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=dynamic-notch ./Scripts/release.sh
```

`make-dmg.sh` then signs the helper library and the app with hardened runtime, the camera and
calendar entitlements and a secure timestamp, notarizes the DMG, staples the ticket and runs a
Gatekeeper check. After the first signed release, simplify the README's install section and
the install note the release script adds.

## Not included yet

* **Automatic updates.** Users download new versions by hand. Sparkle is the usual route once
  releases are signed.
* **Crash reporting.** None, by design: the app makes no network requests.
