# Shipping

Dynamic Notch ships outside the Mac App Store as a notarized DMG. The Now Playing helper uses a
private macOS framework, which App Review does not allow.

## What you need once

1. **Apple Developer Program** membership.
2. A **Developer ID Application** certificate in your login keychain. Xcode › Settings ›
   Accounts › Manage Certificates › + › Developer ID Application. An *Apple Development*
   certificate is not enough: Gatekeeper rejects it on other Macs and it cannot be notarized.
3. A notarization profile stored in the keychain:

   ```bash
   xcrun notarytool store-credentials dynamic-notch --apple-id you@example.com --team-id TEAMID
   ```

   It asks for an app-specific password (appleid.apple.com › Sign-In and Security).
4. Optional: change the bundle id (`BUNDLE_ID`, default `com.rectircle.DynamicNotch`).

## Release steps

```bash
./Scripts/check.sh
```

```bash
VERSION=1.0.0 BUILD_NUMBER=1 SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=dynamic-notch ./Scripts/make-dmg.sh
```

The script builds a universal release app, signs the helper library and the app with hardened
runtime and a secure timestamp, packages `build/DynamicNotch-<version>.dmg`, notarizes it, staples
the ticket and runs a Gatekeeper check. Then run the manual checklist in `QA.md` §5 on the
notarized build before publishing.

Bump `BUILD_NUMBER` on every upload; bump `VERSION` for user-visible releases.

## Local builds

```bash
./Scripts/build-app.sh
```

Without `SIGN_IDENTITY` the app is signed ad hoc. It runs on the Mac that built it; on other
Macs Gatekeeper blocks it.

## Not included yet

* **Automatic updates.** Users must download new versions by hand. Adding Sparkle is the usual
  route; it is a third-party dependency, so it was left for a later decision.
* **Crash reporting.** None, by design: the app makes no network requests.
