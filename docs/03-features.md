# 3. Features

Everything below applies to the application firmware (v0.6.10). The bridge image only offers the access point, the
web page and the updater.

Screen texts and the web page are in English, unless you install a [language pack](#languages).

## Screens

The device rotates through the screens you enable (*Which screens are shown*), changing automatically every few
seconds (configurable), or stays on one screen if automatic change is off. You can also jump to a screen from the
web page or through the API.

| Screen | What it shows | |
|---|---|---|
| **Clock** | Time and date. 24-hour or 12-hour format, date format, optional blinking colon. Time comes from NTP (with a backup source, see [Weather](#weather)); the time zone is a POSIX time zone string | ![Clock](images/clock.png) ![Clock, 12-hour](images/clock-12h.png) |
| **Weather** | Current conditions with an icon, from Open-Meteo | ![Weather](images/weather.png) |
| **Forecast** | The next three days, with icons | ![Forecast](images/forecast.png) |
| **Status** | Version, access point name and address, Wi-Fi network and IP address | |
| **Album** | Your photos and animated GIFs (off until enabled) | ![Album](images/album.png) |
| **Panels** | Screens sent by programs on your computer (off by default) — see [05-pc-apps.md](05-pc-apps.md) | |

If a font or icon is missing from the internal storage, the screen falls back to a small built-in typeface or
leaves the icon slot empty; the clock keeps working.

## Web settings page

Open `http://<device-address>/` and log in with `admin` / `12345678`.

![Web page](images/web-home.png)

Everyday settings are at the top; the rest is folded under *Advanced*:

- **Device name**: the name the device announces on the network (see [below](#finding-the-device-on-the-network)).
- **Language**: which language pack is in use, and a button to install another one (see [Languages](#languages)).
- **Screen brightness**: a slider from 0 (off) to 100. It follows the eye, not a straight line: the low end moves in
  very small steps (1 is the dimmest the backlight can go), so the device can be really dim in a dark room.
- **Night mode**: dim the screen at night (start hour, end hour, night brightness, same scale as above) and,
  optionally, **show only the clock at night, in dim grey**: during the night hours the screen stays on the clock and
  shows just the time. A hand gesture can still change the screen, and panel alerts are always shown (they can be an
  alarm); both go back to the clock when their turn ends.
- **Which screens are shown**, and how many seconds each one stays.
- **Time and date**: time zone, 12/24-hour format, date format, colon blink.
- **The weather**: find your city by name (or type latitude and longitude), Celsius or Fahrenheit.
- **Upload photos to the album**.
- **Hand detection (experimental)**: on/off, what a gesture does, rotate the display 180°, and a live indicator.
  See [below](#hand-detection-experimental).
- **Device health**: free memory, loop timing, clock synchronisation, missing resources, and the switch for the
  UDP log.
- **Advanced**: update the firmware, boot mode (rescue mode), internal storage, detailed status, Wi-Fi.

Settings are stored in the device's internal storage and survive firmware updates.

## Weather

Weather data comes from [Open-Meteo](https://open-meteo.com/) over plain HTTP. Once the clock is set, the device
fetches the weather (and re-synchronises NTP) once an hour, at one minute past the hour. It makes no other
periodic outgoing connection.

**Backup clock source.** Some networks block NTP. In that case the clock is set from the `Date` header of the
weather server's response, which is UTC to the second (accuracy about ±2 s); the time zone still comes from your
settings. NTP always wins: as soon as it answers, it replaces the backup time, and a recent NTP time is never
overwritten. The health page field `timeSource` tells you which one is in use (`ntp`, `weather` or `none`).

## Hand detection (experimental)

**Off by default.** Turn it on under *Hand detection (experimental)* on the web page.

**The gesture:** hold your hand over the **base** of the device — that is where its Wi-Fi antenna is — and keep it
there for **2-3 seconds**. The action runs while your hand is still there (the device needs the drop to last at
least 1.5 s); after that it waits until the signal comes back, so one gesture is one action.

**What a gesture does** (you choose one):

| Action | Effect |
|---|---|
| Dim / brighten | switches between your day brightness and your night brightness |
| Change screen | goes to the next screen of the rotation |
| Show custom panels | jumps to the panels screen and keeps it there for 30 s (or two carousel turns, if longer), then the carousel resumes; a second gesture goes back earlier |
| Night mode (screen off) | turns the screen off; the next gesture turns it on again |

None of these is stored: a restart forgets them, and the normal day/night schedule takes over again.

**Rotate display 180°** lives in the same block (greyed out while detection is off), for when you stand the
device upside down so that the base is on top and easier to reach.

**Live indicator.** With detection on, the block shows the current signal drop, the threshold, the state and when
the last gesture was detected. Use it to check whether the gesture works where your device sits and with your way
of covering it.

![Hand detection settings with the live indicator](images/web-hand.png)

**How it works, and why it is experimental.** There is no sensor: the device watches the strength of the Wi-Fi
signal it receives from your router, and a hand over the antenna lowers it. A gesture is a drop of at least 5 dB
against the previous few seconds, held for at least 1.5 s. Honest limits:

- It needs your home Wi-Fi connection. It does nothing in access-point-only or rescue mode.
- It works better with a **good Wi-Fi signal**. With a weak signal (device far from the router) the same hand moves
  the signal less, and gestures are missed more often. In our tests about 8 gestures in 10 were detected on a desk
  near the router and about 7 in 10 far from it.
- How you cover the device matters: the same gesture gave drops of 10-18 dB or of 5-9 dB depending on the hand.
- **False alarms happen**: about one per hour in our one-hour measurement with a person working about half a
  metre away and nobody touching the device. Choose an action you do not mind being triggered now and then.
- The rotation applies to the application screens only: the start-up screen, rescue mode and the *Status* screen
  are not rotated.

## Photo album

The album page (`http://<device-address>/api/app/album`, also usable from a phone) converts a photo or an animated
GIF **in your browser** into the device's own image format (JPB1, RGB565 pixels) and uploads it. The device never
decodes JPG, PNG or GIF — there is not enough memory for that. Images are shown centred on the 240×240 panel;
animations can have up to 32 frames. Details: [api/ALBUM-API.md](api/ALBUM-API.md).

## Panels from other computers

Any program on your network can send the device a ready-made screen: text rows, label/value pairs, a gauge, or an
image. The device only draws it; it does not know what the data means and never fetches anything by itself.
Details: [05-pc-apps.md](05-pc-apps.md) and [api/PANEL-API.md](api/PANEL-API.md).

## Internal storage and resource packs

About 2 MB of the flash is a storage area for fonts, icons, album images and panels. You can list, upload and
delete files from *Advanced → Internal storage*; system files (fonts, icons, panels) are hidden unless you switch
*show system resources* on. A `.res` resource pack installs all fonts and icons in one go
([02-install-firmware.md](02-install-firmware.md)).

The firmware never depends on the storage to boot or to update: with the storage empty, corrupted or unformatted,
the clock still works with the built-in typeface, and rescue mode does not use the storage at all.

## Languages

The firmware speaks **English**, built in. Any other language is a small **language pack**,
`smalltv-ultra-lang-<code>.res`, published next to each firmware release. Available: Spanish (`es`), French (`fr`)
and Italian (`it`). The French and Italian translations are machine-assisted; corrections from native speakers are
welcome (open an issue with the text you would change).

- **Install:** from the **Language** card (v0.6.10), or upload one pack from *Advanced → Update the firmware* (the same field that takes `.bin` and the
  resource pack) or from *Advanced → Internal storage → File to upload*. The browser unpacks it, uploads the single
  file inside (`l-<code>.jpl`) and tells you which language was installed. No restart is needed.
- **What gets translated:** the screens, and the everyday part of the web page (name, language, brightness, night
  mode, screens, album, time, weather, hand detection). *Advanced*, the health card, the upload box and rescue mode stay in English on purpose,
  so the recovery path never depends on a file.
- **One language at a time:** the last pack you upload replaces the previous one.
- **Date and time format:** the first time a pack is activated, it sets its usual date format and 12/24-hour clock
  once. After that, whatever you change on the web page wins; uploading the same pack again does not reapply it.
- **Back to English:** in *Advanced → Internal storage*, press **Remove the language pack (back to English)** (it deletes the file `l-<code>.jpl`).
- **Safe by design:** with no pack, a damaged pack or two packs at once, the device speaks English; if a single text
  does not fit or is missing, only that text stays in English. The pack is checked before it is used.
- **Firmware:** packs need firmware 0.6.6 or later (0.6.7 is the first published); an older firmware stores the file
  and ignores it. **After updating the firmware, upload your language pack again from the same release**: each release
  ships the packs with the texts of its new cards, and an older pack leaves those cards in English. The weather API answers in English whatever the pack.
- **Status:** `GET /api/app/health` shows the active pack in its `language` block
  ([api/API.md](api/API.md#43-monitor-the-device)).

Want another language? Open an issue asking for it, or offering to translate: the list of texts is short (the
screens plus the everyday cards of the web page), and each screen text has a size limit, so the maintainer
builds the pack and sends you a picture of every screen to check.

## Finding the device on the network

The device's IP address comes from your router and can change. Ways to find it:

- **UDP discovery**: send any UDP datagram to port **7778** (broadcast); the device answers by broadcast on port
  **7779** with a line containing its name, MAC, IP address, firmware version and current mode. It answers in
  rescue mode too. The line looks like
  `M 21:43:07 [HERE] smalltv-a1b2c3 mac=aa:bb:cc:dd:ee:ff ip=10.0.0.42 v=0.6.8 mode=app name=Kitchen`; the mode is
  `app` or `rescue`. The `name=` at the end is the name you give the device in its web page (*Device name*, firmware
  0.6.8+): it appears only in app mode and only if you set one. Firmware 0.6.3 and older answer with
  `[AQUI] … modo=app` (mode `app` or `rescate`), and the clients accept every form. With several devices at home,
  the clients pick one by its name (`--name Kitchen`). Every client in
  [`clients/`](../clients/) does this for you when you do not give it an address (`discover.sh`, `discover.ps1`,
  `discover.mjs`).
- **Hostname**: it registers with your router's DHCP as `smalltv-<chip-id>`. There is no mDNS (`.local`).
- The **Status** screen shows the current IP address.
- Your router's client list, or the ARP table of your computer.

## UDP log

The device can broadcast a text log on UDP port **7777** (`nc -ul 7777` to listen). It is **off by default**; turn
it on under *Device health* ("Broadcast the log over UDP"). In rescue mode it always logs. Each line starts with a
level letter (`D`, `I` or `E`) and the time.

## Rescue mode

A minimal mode in which only the access point, the web page and the updater run; the application does not.
Entered from the web page (*Advanced → Boot mode → Enter rescue mode*) or, without the web page, by cutting the
power three times in a row. See [04-recovery.md](04-recovery.md).

![Rescue web page](images/rescue-web.png)

## Security model, briefly

- Fixed public credentials (`admin` / `12345678`), the same on every unit. Keep the device on a trusted local
  network and never expose it to the internet.
- Requests that change something also need a session token (`X-Rescue-Token`) that the device generates at every
  boot. It prevents another website open in your browser from triggering actions on the device; it is not
  protection against someone on your network.
- Every firmware image is validated (size, MD5, structure, identical bootloader) before the device switches to it.
