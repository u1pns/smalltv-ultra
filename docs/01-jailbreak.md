# 1. Jailbreak: from the factory firmware to the bridge

> This is a personal experiment, not a product. No warranty. You can brick your device. Recovery requires the
> built-in web updater; if the device does not boot, you need to open it and use a UART adapter.

## Why there is a bridge image

The factory firmware only accepts images that fit in the space it reserves for an update. The application
firmware does not fit there. The **bridge** (`smalltv-rescue-0.1.2.bin`, 337 984 bytes, in
[`../firmware/jailbreak/`](../firmware/jailbreak/)) is a small image that the factory firmware does accept. Once it
is running, it brings up its own Wi-Fi access point, a web page and an over-the-air updater without that size limit.
From the bridge you install the real application.

You use the bridge **once per device**. The application replaces it; the bridge does not stay on the device.

The bridge is frozen: it is never rebuilt, because it is the only entry image that has been tested on real
hardware. Check its MD5 against the one listed in [`../firmware/jailbreak/`](../firmware/jailbreak/) before you
upload it.

## What you need

- A GeekMagic SmallTV Ultra running its factory firmware. This project was developed on a unit with factory
  firmware `Ultra-V9.1.54`; other factory versions have not been tested.
- The device and your computer on the same Wi-Fi network.
- A web browser, or `curl`.

## Steps

1. **Find the device's address.** It gets its IP address from your router (DHCP). Look it up in your router's
   client list. Do not reuse an address from another day: it can change.
2. **Open the factory update page** at `http://<device-address>/update`.
3. **Upload the bridge** (`smalltv-rescue-0.1.2.bin`) in the *firmware* field of that form — not the filesystem
   field. It takes a few seconds and the device restarts.

   From the command line, the equivalent is:

   ```sh
   curl -F "firmware=@smalltv-rescue-0.1.2.bin" "http://<device-address>/update"
   ```
4. **Wait for the bridge's access point.** After the restart a new Wi-Fi network appears:
   `SmallTV-Setup-<chip-id>`. The screen shows a black status page with the version, the access point name and
   its address. If the screen stays black but the access point appears, the bridge is running: the display is not
   needed for the web page or the updater.
5. **Connect to the access point** with password `12345678` and open `http://192.168.4.1/`. Log in
   as user `admin` with password `kapifo`.
6. **Optionally join your home Wi-Fi** from that page. The device then serves the same page at the address your
   router gives it, and keeps its own access point as well.

## Coming from the factory firmware: two things to know

- **The factory firmware exposes your Wi-Fi password.** Other projects report that its `GET /config.json` returns
  the saved Wi-Fi network *and password* in plain text, without any login, to anyone on the same network or on its
  `GIFTV` access point. We have not checked this ourselves. Until you install the bridge, treat that password as
  readable by anyone who can reach the device, and consider changing it afterwards if the device lived on a
  network you share. This firmware never returns the Wi-Fi password through its web page or its API.
- **Three short power cuts mean something different here.** Other projects report that on the factory firmware,
  three quick power cycles (during its boot progress bar) are a factory Wi-Fi reset: it forgets your network and
  comes back as the open access point `GIFTV` at `192.168.4.1`. On this firmware the same gesture enters
  **rescue mode** and **keeps your saved Wi-Fi network**: the device rejoins it and also opens its own access
  point `SmallTV-Setup-<chip-id>`. To leave rescue mode, see [04-recovery.md](04-recovery.md).

Next: [install the application firmware](02-install-firmware.md).

## Known limitation of the bridge — the first thing to suspect

The bridge **rejects a multipart upload whose body ends exactly at the closing boundary without a final CRLF**.
Browsers and `curl -F` always send that final CRLF, so they work. A hand-written script, an unusual command-line
tool or a mobile upload app may not, and then the upload fails **the same way on every retry**.

This affects uploads *to* the bridge (step 2 of [02-install-firmware.md](02-install-firmware.md)) and its Wi-Fi
form. The bridge is never rebuilt, so the limitation stays; every application version fixes it.

**If an upload to the bridge keeps failing, use a browser or `curl -F` before suspecting the file or the device.**

## If the factory firmware refuses the bridge

- A "Not Enough Space" style error from the factory updater is a clean refusal: the device is still on its
  factory firmware and nothing was written.
- Make sure you used the *firmware* field, not the filesystem field.
- Try again from a desktop browser or with `curl -F`.
