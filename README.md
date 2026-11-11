# Darktop

A macOS menu bar utility that switches every display to red only, whatever app is in front. One click turns it on, another turns it off.

## Use

- **Click** the menu bar bulb to toggle red mode.
- **Right-click** (or control-click) for options:
  - **Invert (Black Background)**: white becomes black and black becomes bright red. Most apps use light backgrounds, so this cuts the total light from the screen a lot.
  - **Red Level**: 100%, 50%, 25% or 10% peak red.
  - **Quit Darktop**: puts the normal colors back.

The icon is an outline bulb when off, a filled bulb when on, and a warning triangle when on but something may be stopping the screen from being fully red. Right-click to see the warning.

Settings are remembered. Red mode always starts off, unless you launch with `--on`:

```bash
open -a Darktop --args --on
```

## Build and install

Needs macOS 11 or later and Swift 5.9 or later (Xcode 15+, or the Command Line Tools).

```bash
scripts/build-app.sh
```

```bash
cp -R build/Darktop.app /Applications/
```

```bash
open /Applications/Darktop.app
```

To start it at login, add it under System Settings › General › Login Items.

`swift test` runs the unit tests. Each push also builds a universal app on GitHub Actions and attaches `Darktop.zip` to the run. That build is ad-hoc signed and not notarized, so macOS will block it after download until you allow it under System Settings › Privacy & Security.

## How it works

Darktop loads a gamma table into each display with `CGSetDisplayTransferByTable`: green and blue are set to zero, and red is passed through, scaled by the red level, and optionally inverted. This happens after macOS has drawn the screen, so it applies to every app and the menu bar. Screenshots are taken before this step, so they still look normal.

macOS resets gamma tables after sleep, display changes and when other color tools apply theirs. While red mode is on, Darktop reads the tables back once a second and reloads them if they changed. If something keeps overwriting them, the icon shows a warning.

Quitting, `kill`, or Ctrl-C restores the ColorSync profile. Darktop also restores it at launch, so if the screen is ever stuck red, opening Darktop again fixes it.

## Darkroom safety

Treat this as a tool to reduce light, not as a rated safelight. Before trusting it with paper, run a safelight (coin) test at your working distance and exposure time.

- **LCD backlight leaks.** Most Mac screens are LCDs. Setting green and blue to zero closes those subpixels, but an LCD never fully closes, so a small amount of green and blue backlight still gets through. OLED panels don't have this problem. The Red Level setting only lowers what the panel lets through. Turn the display brightness down as well, since that dims the backlight itself.
- **Turn off other color features.** Turn off Night Shift, True Tone, and Accessibility › Display › Invert Colors and Color Filters, and quit f.lux or similar tools. On Apple Silicon, Invert Colors has been reported to apply after the gamma table, which turns red into cyan. Darktop warns when Invert Colors is on, but it can't detect the other features.
- **Some displays can't be switched.** AirPlay, Sidecar and DisplayLink displays usually refuse gamma tables. Darktop shows a warning when a display refuses.
- **Known macOS bug on recent Macs.** On MacBook Pros with M5 Pro or M5 Max and on the MacBook Neo, macOS has been reported to accept gamma tables and then not show them, starting with macOS Tahoe 26.3 and still open in later releases ([Apple forum thread](https://developer.apple.com/forums/thread/819331), FB22273730). Darktop can't detect this, because the table reads back correctly. If the screen doesn't turn red on one of these Macs, this is the likely cause.
- **Content only in green or blue goes dark.** The gamma table changes each channel separately and can't mix them, so pure blue or green shows as black. Text on normal backgrounds stays readable.
