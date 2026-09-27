# Firmware v0.6.10

Install it from the jailbreak page (or from any earlier version of this firmware) as described in
[docs/02-install-firmware.md](../../docs/02-install-firmware.md), then upload the resource pack and, if you want the
device in another language, one language pack.

| File | Size | MD5 | SHA-256 |
|---|---|---|---|
| `smalltv-ultra-v0.6.10.bin` — the firmware | 619 664 B | `91db5f8ba427984ce5edc8a29b091e64` | `422a8f25…fb3d975e` |
| `smalltv-ultra-resources.res` — fonts and icons (38 files) | 154 804 B | `ddc571752f9817a94fcb619b5c9d23dd` | `d53eb1d0…6204b0f2` |
| `smalltv-ultra-lang-es.res` — Spanish (optional) | 22 627 B | `0937fe6d4bd0f607f0e8f5085895acd6` | `72d724d3…f9435a22` |
| `smalltv-ultra-lang-fr.res` — French (optional) | 23 513 B | `06e2b2a0b5912631dfdbe35b63c30208` | `155f6974…1220a0e9` |
| `smalltv-ultra-lang-it.res` — Italian (optional) | 22 893 B | `4870aaf95e56353d147ed03754867a75` | `9ded6197…9561394b` |

Full checksums in [`manifest.json`](manifest.json). The resource pack is the same file as in v0.6.0: if you already
uploaded it, you do not need to upload it again. **The language packs are new in this release**: if you use one,
upload it again after updating, or the new cards of the web page stay in English.

**What it includes:** clock, current weather and 3-day forecast (Open-Meteo), photo album, screens sent from your
PC (panels), web settings page, over-the-air updates and a rescue mode that keeps the device updatable. Details
and screenshots: [docs/03-features.md](../../docs/03-features.md).

**New in v0.6.10** (v0.6.8 and v0.6.9 were internal steps and were not published; their changes are included here):

- **Night mode, with "only the clock".** The night schedule now has its own card, *Night mode*. Besides dimming the
  screen between two hours, it can **show only the clock at night, in dim grey**: during the night hours the screen
  stays on the clock and shows just the time, nothing else. A hand gesture can still change the screen, and panel
  alerts are always shown (they can be an alarm); both go back to the clock when their turn ends. Off by default.
- **Brightness that can go really low.** The brightness slider (day and night) now follows the eye instead of a
  straight line: the low end moves in tiny steps, and 1 is the dimmest the backlight can go (about 4 times dimmer
  than before). Your saved values keep their number, so the screen will look a bit darker than before at the same
  setting: move the slider up if you want it back.
- **Device name.** Give each device a name in its web page (*Device name*, up to 15 characters). It is announced on
  the network, so the clients can find a device by its name instead of its address. See
  [docs/03-features.md](../../docs/03-features.md#finding-the-device-on-the-network).
- **Language card.** Installing a language pack no longer hides in *Advanced*: the new *Language* card shows the
  language in use and installs a pack in one step.
- **Faster return after a Wi-Fi outage.** When the router disappears, the device now retries every minute while
  nobody is connected to its own access point, so it comes back soon after the router does. While someone is
  connected to that access point (rescuing the device), it keeps retrying less often, so as not to interrupt them.
- The boot messages of the UDP log are now in English, and the page footer links to this repository
  (*Manual and updates on GitHub*).

**API:** no route changed or disappeared. Added the settings `name` (v0.6.8) and `night_clock` (v0.6.10), and the
`name=` field at the end of the discovery answer. `brightness` and `night_brightness` keep their 0-100 range, but
the number is now a slider position on the new curve. See [docs/api/API.md](../../docs/api/API.md).

**New in v0.6.7: languages.** The firmware speaks English out of the box. Upload **one** language pack
(`smalltv-ultra-lang-<code>.res`) and the screens and the everyday part of the web page switch to that language, with
no restart. Upload it from *Advanced → Update the firmware* (the same field that takes `.bin` and the resource pack)
or from *Advanced → Internal storage*. The *Advanced* section, the health card and rescue mode stay in English. The
last pack you upload replaces the previous one; to go back to English, remove the pack in *Advanced → Internal
storage* (the file `l-<code>.jpl`). When a pack is activated for the first time it sets its usual date format and
12/24-hour clock once; after that, whatever you change on the web page wins. Published languages: Spanish, French
and Italian. The French and Italian translations are **machine-assisted; corrections are welcome**.
`/api/app/health` gains a `language` block. Details: [docs/03-features.md](../../docs/03-features.md#languages).
(v0.6.6 was an internal step and was not published; its changes are included here.)

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
`hand_action` and `flip`, the `timeSource` field (v0.6.2) and the `language` block (v0.6.7) in `/api/app/health`. See
[docs/api/API.md](../../docs/api/API.md).

**Without the resource pack** the device still works, with a small built-in 5×7 font and no icons. Upload the
`.res` from the device's web page: the browser unpacks it and sends each file.

**Web credentials:** user `admin`, password `12345678` — the same on every unit. Keep the device on your local
network; do not expose it to the internet.

**Language:** English by default; Spanish, French and Italian with a language pack (see above).
