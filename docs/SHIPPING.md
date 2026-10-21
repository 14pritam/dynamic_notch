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

## Making a release now (unsigned)

1. Run the checks:

   ```bash
   ./Scripts/check.sh
   ```

2. Build the DMG (universal, ad-hoc signed):

   ```bash
   VERSION=1.0.1 BUILD_NUMBER=2 ./Scripts/make-dmg.sh
   ```

3. Run the manual checklist in [QA.md](QA.md) on the built app.
4. Tag and publish (needs the GitHub CLI, `gh`):

   ```bash
   gh release create v1.0.1 build/DynamicNotch.dmg --title "Dynamic Notch 1.0.1" --notes-file release-notes.md
   ```

Bump `BUILD_NUMBER` every release and `VERSION` for every user-visible change, and keep them in
step with the tag.

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

```bash
VERSION=1.1.0 BUILD_NUMBER=3 SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=dynamic-notch ./Scripts/make-dmg.sh
```

The script signs the helper library and the app with hardened runtime and a secure timestamp,
packages `build/DynamicNotch.dmg`, notarizes it, staples the ticket and runs a Gatekeeper check.
Publish it with `gh release create` as above, then simplify the README's install section.

## Not included yet

* **Automatic updates.** Users download new versions by hand. Sparkle is the usual route once
  releases are signed.
* **Crash reporting.** None, by design: the app makes no network requests.
