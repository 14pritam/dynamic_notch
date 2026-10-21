<p align="center">
  <img src="Support/AppIcon-1024.png" width="128" alt="Dynamic Notch icon">
</p>

<h1 align="center">Dynamic Notch</h1>

<p align="center">
  Your MacBook's notch, brought to life — like the Dynamic Island on iPhone.<br>
  <b><a href="https://github.com/shandilyaswagat/dynamic_notch/releases/latest/download/DynamicNotch.dmg">⬇ Download Dynamic Notch</a></b> · free · macOS 14 or later
</p>

---

When something is happening on your Mac, the notch grows to show it. When nothing is, it
disappears back into the notch.

- 🎵 **Music** from any app — artwork, play/pause, skip and a progress bar
- ⏱ **Timer** — start one in two clicks, see it count down next to the camera
- 📞 **Calls** — FaceTime, Zoom, Meet, Teams and more, with how long you've been on
- 🔋 **Charging and low battery**
- 🎧 **AirPods and headphones** connecting
- 📤 **AirDrop** — drag files onto the notch to send them
- 📏 **Small, Medium or Large** — pick the size that suits your screen

No account, no internet connection, no tracking.

## Install

> Dynamic Notch is free and isn't registered with Apple yet, so macOS asks you to confirm the
> first time you open it. This takes about a minute and you only do it once.

**1. Download**
[DynamicNotch.dmg](https://github.com/shandilyaswagat/dynamic_notch/releases/latest/download/DynamicNotch.dmg)
and open it.

**2. Drag Dynamic Notch into the Applications folder** in the window that appears.

**3. Open it once.** Go to Applications and double-click **Dynamic Notch**. macOS will say
*"Dynamic Notch" Not Opened*. Click **Done**.

**4. Allow it.** Open **System Settings → Privacy & Security**, scroll down to the
**Security** section, and next to *"Dynamic Notch" was blocked* click **Open Anyway**.
Enter your password (or use Touch ID), then click **Open Anyway** again.

**5. You're done.** The notch briefly shows **Dynamic Notch · Ready**, and a small capsule
icon appears in your menu bar.

<details>
<summary>Prefer Terminal? One command instead of steps 3 and 4</summary>

After step 2, run:

```bash
xattr -dr com.apple.quarantine "/Applications/Dynamic Notch.app"
```

Then open Dynamic Notch normally.
</details>

## How to use it

| To… | Do this |
|---|---|
| Start a timer, or see what's playing | Click the notch |
| See more about something in the notch | Click it |
| Close it again | Click anywhere else, or move the pointer away |
| Switch between two things in the notch | Swipe left or right on it with two fingers |
| Send files with AirDrop | Drag them onto the notch |
| Pause a timer, skip a song, open Settings | Right-click the notch |
| Change the size, start at login, turn features off | Menu bar capsule icon → **Settings…** |

**Tip:** turn on **Open at login** in Settings › General so it's always there.

## Questions

**Nothing shows in the notch.** That's normal when nothing is happening — it hides until you
play music, start a timer or join a call. Hover over the notch and it swells slightly; click it to
open.

**My Mac doesn't have a notch.** It still works: a small virtual notch appears at the top centre
of the screen when there's something to show.

**Music isn't showing.** Start playing something, then wait a second. Dynamic Notch uses a
behind-the-scenes macOS feature to see what's playing; if a future macOS update removes it,
music stops appearing but everything else keeps working.

**Is it safe?** The full source code is in this repository. The app doesn't connect to the
internet, doesn't collect anything, and doesn't ask for any permissions. The warning in step 3
appears only because the app isn't registered with Apple (that costs a yearly fee); it's planned
for a later release.

**How do I update?** Download the new DMG and drag it into Applications again, replacing the
old one. Your settings are kept.

**How do I uninstall?** Click the menu bar capsule icon → **Quit Dynamic Notch**, then drag
**Dynamic Notch** from Applications to the Trash. To remove everything it stored too, delete
`~/Library/Application Support/Dynamic Notch` and
`~/Library/Preferences/com.rectircle.DynamicNotch.plist`.

## Requirements

- macOS 14 Sonoma or later
- Any Mac (Apple silicon or Intel). Designed for MacBooks with a notch.

## For developers

Build instructions, architecture and design notes are in [docs](docs/README.md).
