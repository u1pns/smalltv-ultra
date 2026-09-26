# SmallTV shell clients (macOS and Linux)

Small scripts that talk to a SmallTV Ultra running this firmware, over plain HTTP on your local network.
They need only `sh`, `curl` and, to find the device by themselves, `perl` — all three come with macOS and most
Linux systems.

This is a personal experiment, not a product. No warranty. You can brick your device. Recovery requires the
built-in web updater; if the device does not boot, you need to open it and use a UART adapter.

## Setup

Usually nothing: **without an address, the scripts find the device on your network** (UDP discovery, about two
seconds). If exactly one device answers they use it and say so on the error output; if several answer they list
them and ask you to choose; if none answers they say why that can happen.

```sh
sh discover.sh                         # lists the devices: address, name, MAC, firmware, mode
sh status.sh                           # finds the device and shows its status
sh status.sh --host 10.0.0.42          # or give the address (shown on the device's Status screen)
export SMALLTV_HOST=10.0.0.42          # or once, for all the scripts
export SMALLTV_HOST=$(sh discover.sh --ip)   # or: discover once, then reuse it
```

The address can change (it comes from your router by DHCP), so prefer discovery to a written-down address.
Discovery is a broadcast: guest networks and "client isolation" block it, and then you need the address. Optional
overrides: `SMALLTV_DISCOVERY_WAIT` (seconds), `SMALLTV_DISCOVERY_ADDR` (addresses to ask, comma-separated).

The web user and password are `admin` / `12345678` on every unit. If you changed them, set
`SMALLTV_USER` and `SMALLTV_PASSWORD`.

## The scripts

| Script | What it does |
|---|---|
| `discover.sh` | lists the devices on this network (`--ip` prints only the first address) |
| `status.sh` | firmware version, mode (normal or rescue), address, network, free memory, uptime |
| `update-firmware.sh FILE.bin` | installs a firmware image over Wi-Fi (asks for confirmation) |
| `upload-resources.sh FILE...` | uploads a resource pack (`.res`) or single resource files |
| `send-panel.sh ITEMS...` | shows a text panel composed on the command line |
| `settings.sh [KEY=VALUE...]` | prints or changes settings (brightness, screens, time zone...) |
| `show-screen.sh SCREEN` | jumps to a screen now |
| `files.sh list\|get\|delete` | manages the device storage |
| `rescue.sh enter\|exit` | enters or leaves rescue mode without cutting the power |

Every script prints its full help with `-h`. `smalltv-common.sh` holds the shared code; you do not run it.

## Examples

```sh
sh status.sh

# Firmware update. DO NOT cut the power until the device is back.
sh update-firmware.sh smalltv-ultra-v0.6.7.bin

# Fonts and icons in one go (skips what is already there; run it again if it stops halfway)
sh upload-resources.sh smalltv-resources.res

# A message that pops up for 15 seconds
sh send-panel.sh --title Home --big "Dinner ready" "Come down" --seconds 15

# A gauge
sh send-panel.sh --title Disk --kv "Used=71 %" --bar "71:of 512 GB"

# A panel that stays: saved on the device, expires after 8 hours
sh send-panel.sh --save note --ttl 8 --title Note "Water the plants"

# Settings
sh settings.sh brightness=40
sh settings.sh screens=clock,weather,panels rotate_s=20
sh show-screen.sh panels
```

## Things worth knowing

- **Normal mode and rescue mode.** In rescue mode only the web page and firmware updates work: scripts that
  need the app (panels, settings, storage) say so and stop. `update-firmware.sh` and `rescue.sh` work in both.
- **A firmware update is safe to retry.** The device checks the size and MD5 of the whole image before it
  replaces anything. If the upload is rejected or cut, the old firmware stays and you try again. The one thing
  you must not do is cut the power while it copies and restarts.
- **Panels.** A one-off panel (the default of `send-panel.sh`) lives in memory and never writes the flash.
  A saved panel (`--save`) is a file: save it only when its content changes. The "panels" screen is off from
  the factory; turn it on with `settings.sh screens=...,panels` or in the web page.
- **Images.** The device does not decode JPG, PNG or GIF. Convert photos with the album page of the device web
  (`http://DEVICE/api/app/album`) and let it upload them.
- **Names.** Setting keys and screen names are those of the device API (`brightness`, `screens`, `clock`,
  `weather`...). The help of each script lists them.
- **Error codes.** 401 wrong password, 403 token expired (the device restarted: run again), 404 rescue mode or
  older firmware, 409 a firmware update is running, 507 storage full.

See the API documentation for everything else.
