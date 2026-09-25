# Troubleshooting

## Installing

| Symptom | Most likely cause and what to do |
|---|---|
| The factory update page refuses the bridge | Use the *firmware* field (not the filesystem one), from a desktop browser or with `curl -F`. A space error from the factory updater is a clean refusal: nothing was written. See [01-jailbreak.md](01-jailbreak.md) |
| An upload **to the bridge** fails every time with the same client | Known bridge limitation: it rejects a multipart body without the final CRLF. Upload from a browser or with `curl -F`. See [01-jailbreak.md](01-jailbreak.md) |
| After the jailbreak the screen is black | If the `SmallTV-Setup-<chip-id>` access point appears, the bridge is running; the display is not needed to continue |
| The firmware upload is rejected | Check the MD5 you typed against the release README, and that you chose the application `.bin`. A rejected upload changes nothing; you can retry |
| The page says the file is neither a firmware image nor a resource pack | The file is not a `.bin` or `.res` from this project (or it is damaged). Download it again and check its MD5 |
| The login is refused | Application: `admin` / `12345678`. Bridge: see [01-jailbreak.md](01-jailbreak.md) |

## Everyday use

| Symptom | Most likely cause and what to do |
|---|---|
| I can't find the device | Its IP address comes from DHCP and can change. Look at the **Status** screen, use UDP discovery (port 7778 → 7779) or your router's client list for `smalltv-<chip-id>`. See [03-features.md](03-features.md) |
| The clock and weather use a plain small typeface, icons are missing | The resource pack is not installed, or the storage was formatted. Upload the `.res` again ([02-install-firmware.md](02-install-firmware.md)). `GET /api/app/health` lists what is missing in `missing` |
| The storage says it is not formatted | Normal on a unit that comes from the factory firmware. Format it once from *Advanced → Internal storage* |
| No weather | The device needs internet access to reach Open-Meteo, and a city or coordinates set in *The weather*. Right after a change, data arrives within a few seconds |
| Wrong time | Check the time zone string in *Time and date*. The clock needs NTP (internet access) after every restart |
| All `/api/app/...` requests return `404` | The device is in rescue mode. See [04-recovery.md](04-recovery.md) |
| Requests return `409` | A firmware update is in progress. Wait and retry |
| Requests return `403` | The session token changed because the device restarted. Read it again from `GET /api/status` |

## Rescue mode

| Symptom | Most likely cause and what to do |
|---|---|
| The device booted into rescue mode on its own | It restarted several times without reaching a stable state (for example after a few quick power cuts, or several updates in a row). Leave rescue mode from the web page, or upload a working firmware. If it stays healthy for 10 minutes, the next power-on tries the application again |
| Three power cuts did not enter rescue mode | Each start must last long enough to actually boot (a few seconds) and less than 60 seconds. Try again |
| Nothing works: no access point, no web page | The image does not boot. This cannot be fixed over Wi-Fi: it needs a UART adapter. See [04-recovery.md](04-recovery.md) |

## Panels

See the troubleshooting table at the end of [api/PANEL-API.md](api/PANEL-API.md).
