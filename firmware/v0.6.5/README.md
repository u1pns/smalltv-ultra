# Firmware v0.6.5

Install it from the jailbreak page (or from any earlier version of this firmware) as described in
[docs/02-install-firmware.md](../../docs/02-install-firmware.md), then upload the resource pack.

| File | Size | MD5 | SHA-256 |
|---|---|---|---|
| `smalltv-ultra-v0.6.5.bin` — the firmware | 584 448 B | `50768005bf2dd6bdb9ca00d2adb6fc87` | `db68765b…8cdb7` |
| `smalltv-ultra-resources.res` — fonts and icons (38 files) | 154 804 B | `ddc571752f9817a94fcb619b5c9d23dd` | `d53eb1d0…04b0f2` |

Full checksums in [`manifest.json`](manifest.json). The resource pack is the same file as in v0.6.0: if you already
uploaded it, you do not need to upload it again.

**What it includes:** clock, current weather and 3-day forecast (Open-Meteo), photo album, screens sent from your
PC (panels), web settings page, over-the-air updates and a rescue mode that keeps the device updatable. Details
and screenshots: [docs/03-features.md](../../docs/03-features.md).

**New in v0.6.5:** rescue mode now leaves on its own. If the device went into rescue because it had no Wi-Fi
when it started, it goes back to the application after 2 minutes connected. For any other cause, after 10 minutes
connected with no action on the rescue web page. The rescue screen and `/api/status` show the cause and a countdown.
With no Wi-Fi it stays in rescue mode, so you can set up the network. Screens, API and web are now fully in English
(the rescue core's last Spanish words are gone).

**New in v0.6.3:** when the hand action is «show your panels», the panels stay on screen for 30 seconds (or two
carousel turns, if that is longer) before the carousel resumes its normal pace. A second hand gesture returns earlier.

**New since v0.6.0:**

- **Hand detection (experimental, off by default).** Hold your hand over the base of the device for 2-3 seconds and
  it runs an action you choose: dim/brighten, next screen, show your panels, or screen off. It works by noticing
  that your hand blocks the Wi-Fi signal, so it depends on your Wi-Fi and on how you cover the device; the web page
  has a live indicator so you can check whether it works where you put it. Limits and details:
  [docs/03-features.md](../../docs/03-features.md#hand-detection-experimental).
- **Rotate display 180°**, inside the same settings block, for when you stand the device upside down.
- **Backup clock source.** If your network blocks NTP, the clock is set from the `Date` header of the weather
  server's response (about ±2 s). NTP always wins when it answers.

**API:** no route changed or disappeared since v0.6.0. Added: `GET /api/app/hand`, the test command
`POST /api/app/command?name=hand`, the settings `hand`,
`hand_action` and `flip`, and the `timeSource` field in `/api/app/health`. See
[docs/api/API.md](../../docs/api/API.md).

**Without the resource pack** the device still works, with a small built-in 5×7 font and no icons. Upload the
`.res` from the device's web page: the browser unpacks it and sends each file.

**Web credentials:** user `admin`, password `12345678` — the same on every unit. Keep the device on your local
network; do not expose it to the internet.

**Language:** screens and web page in English.
