# 2. Install the application firmware and the resource pack

Prerequisite: the device is running the bridge ([01-jailbreak.md](01-jailbreak.md)), or an earlier version of
this application.

A release folder in [`../firmware/`](../firmware/) (currently [`v0.6.7`](../firmware/v0.6.7/)) contains:

| File | What it is |
|---|---|
| the application `.bin` | the firmware: clock, weather, album, panels, with its own rescue core inside |
| the `.res` resource pack | fonts and icons, uploaded into the device's internal storage |
| `smalltv-ultra-lang-<code>.res` (optional) | a language pack: Spanish, French or Italian instead of English |
| `README.md` / `manifest.json` | exact file names, sizes and MD5 checksums |

Always compare the MD5 of what you downloaded with the one in the release README before uploading.

## Step 1 — Upload the application `.bin`

1. Open the device's page: `http://192.168.4.1/` from its own access point `SmallTV-Setup-<chip-id>`, or the
   address your router gave it on your home network.
2. In the firmware update card, choose the application `.bin` and enter its MD5 when the form asks for it. The
   device checks size, MD5, image structure and bootloader compatibility **before** it switches to the new image;
   a rejected upload leaves the current firmware in place, and you can simply try again.
3. The device restarts into the application. This takes a few seconds; the page reconnects on its own.

From this point on, **the web login is `admin` / `12345678`** and the device's access point password is `12345678`
(public, identical on every unit — see the warning in the [README](../README.md)).

The application carries its own rescue core, so every future version is installed the same way, from its own page
(*Advanced → Update the firmware*).

## Step 2 — Format the internal storage (new units only)

Fonts, icons, album images and panels live in a separate storage area of the flash, not inside the firmware.
On a unit that comes from the factory firmware, that area is usually unformatted.

Open *Advanced → Internal storage*. If it says the storage is not formatted, press *Format the storage* once.

## Step 3 — Upload the `.res` resource pack

In *Advanced → Update the firmware*, the file field accepts **either a firmware image (`.bin`) or a resource pack
(`.res`)**. The browser reads the first bytes of the file to tell which one it is, shows you a confirmation with
what it found, and only then sends it:

- a `.bin` goes to the firmware updater;
- a `.res` is unpacked **in your browser** and each font and icon is uploaded to the internal storage. The MD5
  field is hidden for a `.res`: the pack carries its own checksums.

A file that is neither is rejected without sending anything to the device.

Without the resource pack the device still works, but draws with a small built-in typeface and without icons.

To check: `GET /api/app/health` (see [api/API.md](api/API.md)) lists missing resources in `missing`; after a complete
upload it is an empty list.

## Step 4 (optional) — Upload a language pack

The device speaks English. To use Spanish, French or Italian, upload **one** `smalltv-ultra-lang-<code>.res` from
the release folder, in the same field as the resource pack (or from *Advanced → Internal storage*). The page tells
you which language was installed. See [03-features.md](03-features.md#languages).

## Updating later

**Updating the firmware is just uploading the new `.bin`.** Firmware updates do not touch the internal storage:
your resources, album images, panels and settings survive them.

You only need to upload a resource pack again when:

1. the unit is new, or you formatted the storage;
2. a new firmware version uses a font or icon that was not there before, or changes their format. Nothing breaks
   in the meantime: the screen falls back to the built-in typeface or leaves the icon slot empty, and `missing`
   lists what is missing.

**Formatting the storage** deletes every resource and every album image. Settings are kept (the application writes
them back by itself).

## Command line (application only)

The application's updater also accepts an upload from a script. The upload needs the web credentials, the session
token and the size and MD5 of the image; see [api/API.md](api/API.md) §2 for the exact headers. For the bridge,
use a browser or `curl -F` (see the bridge limitation in [01-jailbreak.md](01-jailbreak.md)).

## If something goes wrong

See [04-recovery.md](04-recovery.md) and [troubleshooting.md](troubleshooting.md).
