# Changelog

Every release of Dynamic Notch, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/): new features bump the middle number, fixes bump the
last one.

## [Unreleased]

### Added
- **Clipboard.** A new tab with the last 20 things you copied. Click one to copy it again.
  Passwords from password managers are skipped, and the history is never saved to disk.
- **Notes.** A new tab with a quick scratchpad. It saves as you type and stays open while you
  write. Press Escape or click outside to close it.
- **Focus sessions.** Tap Focus in Home for a 25 minute session. When it ends, the notch offers a
  5 minute break, then the next session. You can change both lengths in Settings.
- Start Focus from the menu bar too.
- **A new Timer panel.** Pick Timer, Pomodoro or Stopwatch, slide the ruler to any length and
  press Start. Open it from the timer icon or the ••• button in Home.
- **Stopwatch.** Counts up next to the camera, with pause and reset.
- **Calendar panel.** Click your next event in Home to see this month and what's coming up.
- **Mute your mic during calls.** A mute button in the call view that works for every app.
- **Keep Awake.** The cup button in Home stops your Mac from sleeping. Right-click it for 1 or
  2 hours.
- **Finished downloads.** Turn it on in Settings › Home and the notch tells you when a file lands
  in Downloads. Click to show it in Finder or drag it straight out.
- **Gestures.** Swipe sideways on the music to skip songs, pull down on the notch to open it and
  push up to close it.
- A back button on every open activity takes you to Home.

### Changed
- The first-launch hello now greets you by your first name, with a waving hand, instead of
  "Dynamic Notch · Ready".
- The tabs now sit on both sides of the camera (Notes and Mirror next to Settings), so none of
  them can end up hidden behind it.
- The battery is gone from the top of Home, since it's already in your menu bar.
- The quick timers in Home are now 5, 10 and 15 minutes, plus Focus and ••• for anything else.
- A running timer looks like the iPhone's: pause and cancel on the left, the time on the right.
  Every kind of timer uses the same orange.

### Fixed
- After a while (sooner if you connect headphones or join calls often) the app could get stuck
  using a full CPU core and stop responding, including the menu bar icon. It now cleans up after
  itself every time your audio devices change.

## [1.1.0] - 2026-10-21

### Added
- **File Tray.** Drag files onto the notch and drop them on Tray to keep them handy. Drag them
  back out whenever you need them, double-click to open, right-click for more.
- **Mirror.** A quick camera preview in the notch so you can check how you look before a call.
  The camera only turns on while you're looking at it.
- **Calendar.** Your next event shows up in Home, and the notch gives you a heads up 5 minutes
  before it starts.
- **Shortcuts.** Pin up to 4 of your shortcuts to Home and run them with one click.
- **Volume and brightness.** The notch shows the level when you change them.
- **Battery level** in Home.
- **Hover to open.** With "Expand on hover" on, resting on the notch opens Home.
- Home now has tabs (Home, Tray, Mirror) and a new layout: wider and shorter, with your music on
  the left and everything else next to it.
- A new Home tab in Settings to turn each of these on or off.

### Changed
- Dropping files on the notch now gives you two choices: Tray or AirDrop.
- The app asks for camera access only when you open Mirror, and calendar access only when you
  click Connect.

## [1.0.0] - 2026-10-21

### Added
- First release. The notch grows to show music, timers, calls, charging, low battery,
  headphones and AirDrop.
- Small, Medium and Large sizes, plus width and thickness fine-tuning.
- Pitch black look so the extension blends into the notch.
- Optional floating pill style.
- Menu bar icon, Settings window, open at login.

[1.1.0]: https://github.com/shandilyaswagat/dynamic_notch/releases/tag/v1.1.0
[1.0.0]: https://github.com/shandilyaswagat/dynamic_notch/releases/tag/v1.0.0
