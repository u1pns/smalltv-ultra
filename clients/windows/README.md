# SmallTV PowerShell clients (Windows)

Scripts that talk to a SmallTV Ultra running this firmware, over plain HTTP on your local network.
They run on **Windows PowerShell 5.1** (built into Windows 10 and 11) and on PowerShell 7. No modules and no
downloads: they only use `Invoke-WebRequest`.

This is a personal experiment, not a product. No warranty. You can brick your device. Recovery requires the
built-in web updater; if the device does not boot, you need to open it and use a UART adapter.

## Setup

Windows blocks downloaded scripts by default. Open PowerShell in this folder and allow them for this window only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Get-ChildItem *.ps1 | Unblock-File          # optional: removes the "downloaded from the internet" mark
```

Usually you do not need to tell the scripts where the device is: **without an address they find it on your
network** (UDP discovery, about two seconds). If exactly one device answers they use it and say so; if several
answer they list them and ask you to choose; if none answers they say why that can happen. The first time, Windows
may ask whether PowerShell can use the network: allow it for private networks.

```powershell
.\discover.ps1                              # lists the devices: address, name, MAC, firmware, mode
.\status.ps1                                # finds the device and shows its status
.\status.ps1 -Address 10.0.0.42             # or give the address (shown on the device's Status screen)
$env:SMALLTV_HOST = '10.0.0.42'             # or once, for all the scripts
$env:SMALLTV_HOST = .\discover.ps1 -IpOnly  # or: discover once, then reuse it
```

The address can change (it comes from your router by DHCP), so prefer discovery to a written-down address.
Discovery is a broadcast: guest networks and "client isolation" block it, and then you need the address. Optional
overrides: `$env:SMALLTV_DISCOVERY_WAIT` (seconds), `$env:SMALLTV_DISCOVERY_ADDR` (addresses, comma-separated).
The web user and password are `admin` / `12345678` on every unit. If you changed them, set
`$env:SMALLTV_USER` and `$env:SMALLTV_PASSWORD`.

## The scripts

| Script | What it does |
|---|---|
| `discover.ps1` | lists the devices on this network (`-IpOnly` prints only the first address) |
| `status.ps1` | firmware version, mode (normal or rescue), address, network, free memory, uptime |
| `update-firmware.ps1 -File X.bin` | installs a firmware image over Wi-Fi (asks for confirmation) |
| `upload-resources.ps1 -Path X.res` | uploads a resource pack (`.res`) or single resource files |
| `send-panel.ps1` | shows a text panel composed on the command line |
| `settings.ps1 [-Set KEY=VALUE,...]` | prints or changes settings (brightness, screens, time zone...) |
| `show-screen.ps1 -Screen NAME` | jumps to a screen now |
| `files.ps1 -Action list\|get\|delete` | manages the device storage |
| `rescue.ps1 -Action enter\|exit` | enters or leaves rescue mode without cutting the power |

`Get-Help .\send-panel.ps1 -Full` shows the help of any script. `smalltv-common.ps1` holds the shared code;
you do not run it.

## Examples

```powershell
.\status.ps1

# Firmware update. DO NOT cut the power until the device is back.
.\update-firmware.ps1 -File .\smalltv-ultra-v0.6.5.bin

# Fonts and icons in one go (skips what is already there; run it again if it stops halfway)
.\upload-resources.ps1 -Path .\smalltv-resources.res

# A message that pops up for 15 seconds
.\send-panel.ps1 -Title Home -Big 'Dinner ready' -Line 'Come down' -Seconds 15

# A gauge
.\send-panel.ps1 -Title Disk -KeyValue 'Used=71 %' -Bar '71:of 512 GB'

# A panel that stays: saved on the device, expires after 8 hours
.\send-panel.ps1 -Save note -TtlHours 8 -Title Note -Line 'Water the plants'

# Settings
.\settings.ps1 -Set 'brightness=40'
.\settings.ps1 -Set 'screens=clock,weather,panels', 'rotate_s=20'
.\show-screen.ps1 -Screen panels
```

## Things worth knowing

- **Normal mode and rescue mode.** In rescue mode only the web page and firmware updates work: scripts that
  need the app (panels, settings, storage) say so and stop. `update-firmware.ps1` and `rescue.ps1` work in both.
- **A firmware update is safe to retry.** The device checks the size and MD5 of the whole image before it
  replaces anything. If the upload is rejected or cut, the old firmware stays and you try again. The one thing
  you must not do is cut the power while it copies and restarts.
- **Panels.** A one-off panel (the default of `send-panel.ps1`) lives in memory and never writes the flash.
  A saved panel (`-Save`) is a file: save it only when its content changes. The "panels" screen is off from
  the factory; turn it on with `settings.ps1 -Set 'screens=...,panels'` or in the web page.
- **Rows in `send-panel.ps1`** are drawn in a fixed order: `-Big`, then `-Line`, then `-KeyValue`, then `-Bar`.
  For full control, write a panel file and send it with `-File` (format in the panel API documentation).
- **Images.** The device does not decode JPG, PNG or GIF. Convert photos with the album page of the device web
  (`http://DEVICE/api/app/album`) and let it upload them.
- **Names.** Setting keys and screen names are those of the device API (`brightness`, `screens`, `clock`,
  `weather`...). The help of each script lists them.
- **Error codes.** 401 wrong password, 403 token expired (the device restarted: run again), 404 rescue mode or
  older firmware, 409 a firmware update is running, 507 storage full.
