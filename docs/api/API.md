# HTTP API

Reference for anyone who wants to write scripts or apps that talk to the device: show your computer's CPU load, a
stock price or a home-automation alert, upload photos, or automate its settings. Everything is plain HTTP on your
local network. There is no cloud, no account and no external service.

Related documents: [PANEL-API.md](PANEL-API.md) for panels, [ALBUM-API.md](ALBUM-API.md) for album images,
[../02-install-firmware.md](../02-install-firmware.md) for installing the firmware.

Endpoint names, parameters, JSON keys and values are written here exactly as the device expects them. Error
messages are short human-readable texts; rely on the status code (and on `key` when present), not on the message
text.

## 1. Before your first call

> **Images wear out the flash; text does not.** A 240×240 image is about 115 KB and a text panel about 0.5 KB —
> some 230 times less. Rewriting an image every minute is about 165 MB a day, roughly 80 rewrites of the whole
> storage per day: that kills a NOR flash within months. The same rate in text is about 3 MB a day, sustainable for
> years. **If the data changes often, send it as text or as a panel definition, not as an image.** Keep images
> for things that change a few times a day, and upload only when the content has really changed.

- **HTTP Basic authentication** on every route: user `admin`, password `12345678` (public, the same on every unit).
- **Routes that change something also need a token** in the `X-Rescue-Token` header. The token is created at every
  boot and read from `GET /api/status` (field `token`). If the device restarts, the token changes: fetch it again.
- **Two modes**: `app` (normal) and `rescue`. In rescue mode **every `/api/app/*` route returns `404`**: the device
  only runs its minimal core, serving the web page and the updater. Treat that `404` as "not now", not as a bug.
- **During a firmware update**, application routes return **`409`**. Same treatment: retry later.
- **The device has no schedule.** It never asks anyone for data and does not know how often something should be
  refreshed: it draws what it has, stops drawing it when it expires, and marks it "not updated" when it gets stale.
  If your script stops working, the expiry time that *you* set decides what stays on screen.
- **The device does not rate-limit you.** If you upload a file every second, it will write it every second. Upload
  only when the content changes.
- **Do not hardcode the IP address**: it comes from DHCP. See "Finding the device" in
  [../03-features.md](../03-features.md).

Minimal example:

```sh
DEV=http://<device-address>          # or pass it in SMALLTV_HOST
A=admin:12345678
TOKEN=$(curl -s -u "$A" "$DEV/api/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -u "$A" -H "X-Rescue-Token: $TOKEN" -X POST "$DEV/api/app/show?screen=clock"
```

## 2. Core routes (always available, in both modes)

| Route | Method | Token | What it does |
|---|---|---|---|
| `/api/status` | GET | no | version, mode, IP, network, free memory, maximum image size, cause of the last restart, **token**, `warning` (empty unless the boot degraded; called `aviso` in firmware 0.6.3 and older), and — from firmware 0.6.5 — `rescueCause` and `rescueExitIn` (see below) |
| `/api/scan` | GET | no | Wi-Fi networks in range |
| `/api/wifi` | POST | yes | stores a network name and password, and connects |
| `/api/rescue/enter` | POST | yes | restarts into rescue mode |
| `/api/rescue/exit` | POST | yes | in rescue mode: back to the application on the next boot; in application mode: resets the boot counter |
| `/update` | POST | yes | uploads a firmware image (`multipart`, field `firmware`, with the `X-Firmware-Size` and `X-Firmware-MD5` headers) |

**Rescue cause and automatic exit (firmware 0.6.5 and later).** `/api/status` carries two more fields:

- `rescueCause`: why the device is in rescue mode — `"no-network"` (it did not get an IP address on its Wi-Fi within
  60 s of starting), `"boot-failures"` (several starts in a row without reaching a stable state, which includes the
  three-power-cuts gesture), `"requested"` (`POST /api/rescue/enter`) or `"unknown"`. `null` in application mode.
- `rescueExitIn`: seconds left before the device leaves rescue mode **by itself** and restarts into the
  application, or `null` when it is not counting (application mode, no IP address, or already done). A
  `"no-network"` rescue leaves after 2 minutes in a row with an IP address. Any other cause leaves after 10 minutes
  in rescue mode with an IP address and **no action on the rescue web in the last 2 minutes** (any authenticated
  `POST`, and `GET /api/scan`). Reads such as `GET /api/status` or `/api/screen` do not count, so polling the status
  or leaving the page open does not keep the device in rescue mode. It never leaves without an
  IP address, and never during a firmware upload. Older firmware does not send these fields.

Firmware upload from a script (application firmware; macOS `stat`/`md5` shown, use `stat -c%s` / `md5sum` on
Linux):

```sh
BIN=firmware.bin
curl -s -u "$A" -H "X-Rescue-Token: $TOKEN" \
     -H "X-Firmware-Size: $(stat -f%z "$BIN")" -H "X-Firmware-MD5: $(md5 -q "$BIN")" \
     -F "firmware=@$BIN" "$DEV/update"
```

The image is validated (size, MD5, structure, bootloader) before the device switches to it. After a successful
upload the device restarts and the token changes. A rejected upload leaves the current firmware in place.
If the image was accepted but the boot counter could not be cleared, the answer carries a `warning` text (the
new image may start in rescue mode); firmware 0.6.3 and older call that field `aviso`.

## 3. Application routes (`app` mode only)

| Route | Method | Token | What it does |
|---|---|---|---|
| `/api/app/health` | GET | no | health: free memory, lowest free memory seen, longest loop iteration, clock synchronisation, state of each screen, missing resources |
| `/api/app/settings` | GET | no | all settings, as JSON |
| `/api/app/settings` | POST | yes | changes settings through parameters (see below) |
| `/api/app/show` | POST | yes | jumps to a screen now: `?screen=clock\|weather\|forecast\|status\|album\|panels` |
| `/api/app/weather` | GET / POST | no / yes | reads the latest weather data, or forces a new request |
| `/api/app/panel` | POST | yes | shows a volatile panel — see [PANEL-API.md](PANEL-API.md) |
| `/api/app/files` | GET | no | lists the internal storage |
| `/api/app/files` | POST | yes | uploads a file (`multipart`, field `file`) |
| `/api/app/files/get` | GET | no | downloads a file: `?name=` |
| `/api/app/files/delete` | POST | yes | deletes a file: `?name=` |
| `/api/app/files/format` | POST | yes | formats the storage (deletes fonts, icons, album images and panels) |
| `/api/app/album` | GET | no | the page that converts photos and GIFs **in your browser** and uploads them |
| `/api/app/hand` | GET | no | hand detection live reading (v0.6.1+) — see below. `409` with `"key":"hand"` while detection is off |
| `/api/app/command?name=hand` | POST | yes | runs the configured gesture action now, as if a hand had been detected (to test an action without the gesture). `409` with `"key":"hand"` while detection is off. Answer: `{"ok":true,"command":"hand","action":"dim"}` |

### Settings (`POST /api/app/settings`)

Parameters are sent in the query string or as a form body. Read `GET /api/app/settings` first to see the current
values and their format. Known parameters:

| Parameter | Meaning |
|---|---|
| `brightness` | brightness, 0-100 (0 = backlight off). It is a slider position, not a linear fraction: the light follows an exponential curve in 1/256 steps (1 -> 1/256, 10 -> 11/256, 50 -> 77/256, 100 -> full), so the low end is fine enough for a dark room. Same scale for `night_brightness` (since v0.6.9) |
| `screens` | comma-separated list of screens that rotate: `clock,weather,forecast,status,album,panels` |
| `rotate`, `rotate_s` | automatic screen change on/off, and seconds each screen stays before the next one |
| `city`, `lat`, `lon` | weather location: the name shown on screen, and the coordinates that decide the forecast |
| `temp` | temperature unit: `C` or `F` |
| `wind` | wind unit |
| `weather_min` | minutes between weather requests while the clock is not yet set |
| `tz` | POSIX time zone string |
| `h12` | 12-hour or 24-hour clock |
| `date_format` | date format |
| `blink` | blinking colon, `0` or `1` |
| `night`, `night_start`, `night_end`, `night_brightness` | night dimming: on/off, start hour, end hour, night brightness |
| `night_clock` | `1` = during the night hours the screen stays on the clock and shows only HH:MM in dim grey. A hand gesture can still change the screen and panel alerts are always shown; both go back to the clock when their turn ends (since v0.6.9) |
| `log_udp` | `0` or `1`: turns the UDP log off or on (off by default; persisted) |
| `hand` | `0` or `1`: hand detection off or on (**experimental**, off by default) |
| `hand_action` | what a gesture does: `dim` (switch between day and night brightness), `screen` (next screen), `panels` (show the panels screen; the next gesture goes back), `night` (screen off; the next gesture turns it on) |
| `flip` | `0` or `1`: rotate the display 180°. The start-up screen, rescue mode and the *Status* screen are not rotated |
| `name` | the device's name, shown by discovery (firmware 0.6.8+): up to 15 printable ASCII characters; spaces are allowed inside but not at the start or end; `=`, `"`, `'`, `\` and `` ` `` are not. Empty (the default) means no name. It is a label, not an identity: two devices may share it, so pick a device by its MAC when it matters |

### Hand detection (`GET /api/app/hand`, experimental)

With `hand=1` the answer looks like:

```json
{"enabled":true,"state":"ready","phase":"idle","action":"dim","flip":0,"rssi":-58,
 "dropDb":1,"thresholdDb":5,"sustainMs":1500,"gestures":3,"lastGestureS":42}
```

| Field | Meaning |
|---|---|
| `state` | `learning` (collecting the reference signal after it was turned on), `ready`, or `no-wifi` (not connected to your Wi-Fi: nothing to measure) |
| `phase` | `idle`, `holding` (a drop is being held: keep the hand there) or `cooldown` (a gesture just fired; waiting for the signal to come back) |
| `action`, `flip` | the current settings |
| `rssi` | received Wi-Fi signal strength now, in dBm |
| `dropDb` | how many dB the signal is below its recent reference right now |
| `thresholdDb`, `sustainMs` | the rule: a drop of at least `thresholdDb` held for `sustainMs` is a gesture |
| `gestures` | gestures detected since boot |
| `lastGestureS` | seconds since the last gesture, or `null` if none yet |

All numbers are integers. With `hand=0` the route answers `409 {"error":"Hand detection is disabled","key":"hand"}`,
not `404`, so a client knows the fix is to turn the setting on. Nothing about gestures is stored: a restart clears
the counter and any brightness or screen change a gesture made.

### When the device talks by itself

Once its clock is set, the device requests **NTP and the weather once an hour, at one minute past the hour**.
There is no other periodic outgoing connection: everything else happens because you send it something.

### Discovery (UDP, both modes)

Send any UDP datagram to port **7778** (broadcast); the device never reads it. It answers with one line, broadcast
to port **7779**, at most once per second:

```
M 21:43:07 [HERE] smalltv-a1b2c3 mac=aa:bb:cc:dd:ee:ff ip=10.0.0.42 v=0.6.8 mode=app name=Kitchen
```

`mode` is `app` or `rescue`. Firmware 0.6.8 and newer end the line with `name=<name>` (the `name` setting) **only in
`app` mode and only if a name is set**; it is always the last field and may contain spaces, so read it up to the end
of the line. Older firmware answers without it, and 0.6.3 and older answer `[AQUI] … modo=app|rescate`. The identity
is the MAC (and the host name `smalltv-<chip-id>` derived from it): the name is only for people. The clients in
[`clients/`](../../clients/) accept every form and can choose a device by its name (`--name`, `-Name`,
`SMALLTV_NAME`).

The optional log goes out as a **UDP broadcast on port 7777** (`nc -ul 7777`). Each line looks like
`N HH:MM:SS [TAG] text`, where `N` is `D`, `I` or `E`. Until the clock is synchronised, the time counts from boot
and wraps every 24 h, so `00:00:00` in a long log does not necessarily mean a restart.

## 4. Recipes

### 4.1 Send a screen from your computer

The general way to "make the device show something of mine" is a **panel**: your script composes the screen and
sends it; the device only draws it. Example with the macOS CPU load:

```sh
CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s/'"$(sysctl -n hw.ncpu)"'}')
printf 'PANEL1\nT\tMac\nK\t1\tCPU\t%s %%\nB\t3\t%s\tnow\n' "$CPU" "$CPU" |
  curl -s -u "$A" -H "X-Rescue-Token: $TOKEN" -H 'Content-Type: text/plain; charset=utf-8' \
       --data-binary @- "$DEV/api/app/panel?s=10"
```

Full format: [PANEL-API.md](PANEL-API.md).

### 4.2 Upload a photo

The device does not decode JPG or GIF: images are converted beforehand. The easy way is the album page from your
phone; for scripts, see [ALBUM-API.md](ALBUM-API.md).

### 4.3 Monitor the device

```sh
curl -s -u "$A" "$DEV/api/app/health" | python3 -m json.tool
```

- `heap` and `heapMin`: free memory now and the lowest value seen.
- `tickMax`: the longest loop iteration.
- `ntp`: `true` once the clock has a valid time, whatever its source (the name is historical).
- `timeSource` (v0.6.2): where the current time came from — `ntp`, `weather` or `none`. `weather` means the network
  blocks NTP and the clock was set from the `Date` header of the last Open-Meteo response (UTC, about ±2 s). NTP
  always wins: as soon as it answers, `timeSource` becomes `ntp`.
- `missing`: resources a screen asked for that are not in the storage.
- `stackFree`: bytes of the main loop's stack (4 KB in total) that have never been used since boot. It is a
  high-water mark, so it can only go down. If it gets close to zero, the device is close to a stack overflow.
- `language` (v0.6.7; firmware 0.6.6 already reported it): the language pack in use.
  `{"pack":"l-es.jpl","code":"es","state":"ok","schema":1,"packSchema":1,"fallback":0,"unknown":0}`
  - `pack`: the file in the storage (empty if there is none, or more than one); `code`: its language code.
  - `state`: `ok` (pack active), `none` (no pack, or storage not mounted), `several` (two or more packs; English),
    `corrupt` (header, sections or checksum broken; English) or `font` (the pack's font is unusable; English).
  - `schema`: the text catalogue version this firmware expects; `packSchema`: the one the pack was built for.
  - `fallback`: texts shown in English because the pack does not provide a usable translation (all of them when
    `state` is not `ok`); `unknown`: keys in
    the pack this firmware does not know. A pack from a different firmware version still works: matching texts are
    translated, the rest stay in English.

### 4.4 Change brightness or the rotating screens

```sh
curl -s -u "$A" -H "X-Rescue-Token: $TOKEN" -X POST "$DEV/api/app/settings?brightness=40"
curl -s -u "$A" -H "X-Rescue-Token: $TOKEN" -X POST "$DEV/api/app/settings?screens=clock,weather,forecast"
```

## 5. Errors you will meet

| Code | Meaning | What to do |
|---|---|---|
| 401 | wrong user or password | check the credentials |
| 403 | token missing or expired | read `/api/status` again (the device restarted) |
| 404 on `/api/app/*` | the device is in rescue mode, or your firmware predates that route | retry later |
| 409 | a firmware update is in progress | retry later |
| 409 with `"key":"hand"` | hand detection is off (`/api/app/hand`, `command?name=hand`) | set `hand=1` first |
| 400 | the content does not pass validation | the response says why |
| 507 | it does not fit in the storage | delete something or upload less |

## 6. Living with the device

1. **Upload only when the content changes, and use text for anything that changes often.** A digest on your side
   avoids thousands of useless writes.
2. **Do not depend on the IP address**: it comes from DHCP. Use discovery or the hostname. The device's own access
   point is available even without a network.
3. **Treat `404` and `409` as normal states**, not failures.
4. **There is deliberately no rate limit on the device**: such a guard could one day reject a legitimate upload.
   Moderation is the sender's job.
5. **Nothing you send is needed for recovery.** If you delete every resource, the device still boots, serves its
   web page and accepts a new image; it only draws with its basic typeface.
