# 4. Recovery and rescue mode

The whole firmware is built around one property: **the device can always receive a new image over Wi-Fi**. The
rescue core (access point, web page, updater and a watchdog) starts before anything else; the application starts
only after it, and only if the rescue core decided to run it.

Every released version is tested for this on real hardware before publication: it is uploaded twice in a row
(checking that the device comes back each time), then the device is put into rescue mode, a firmware is uploaded
*from* rescue mode, and the device returns to normal operation.

## What rescue mode is

In rescue mode **only the access point, the web page and the updater run**. The application — screens, weather,
album, panels — does not, and every `/api/app/...` route answers `404`. The firmware upload form is always visible
in rescue mode, without having to unfold anything.

## How to enter it

- **From the web page**: *Advanced → Boot mode → Enter rescue mode*. The device restarts into rescue mode.
- **From the API**: `POST /api/rescue/enter` (see [api/API.md](api/API.md)).
- **Without the web page — three short power cuts.** Unplug and plug the power back in three times in a row,
  each time **before the device has been running for 60 seconds**. The device notices that it never managed to
  reach a stable state and boots into rescue mode on the third start. Leave it powered long enough each time to
  actually start (a few seconds); very short power cycles may not count.

The access point `SmallTV-Setup-<chip-id>` is available in rescue mode, at `http://192.168.4.1/`, with the same
credentials as the application (`admin` / `12345678`, access point password `12345678`).

Note: rebooting the device quickly several times on purpose (for example, several firmware uploads in a row within
a minute of each other) can trigger the same gesture. That is expected behaviour, not a fault.

## How to leave it

- **Upload a working firmware** from the rescue page. A new image accepted in rescue mode starts in normal mode.
- **Leave rescue mode** button (`POST /api/rescue/exit`): the next boot starts the application again.
- **By itself** (firmware 0.6.5 and later): the rescue screen shows why the device is there (`RESCUE: NO NETWORK`,
  `RESCUE: BOOT FAILS`, `RESCUE: REQUESTED`) and, while it is counting, `BACK TO APP IN <n> S`.
  - If it went to rescue mode because it **could not get on its Wi-Fi** (for example, it was moved away from the
    router), it restarts into the application on its own after **2 minutes in a row with an IP address**.
  - For **any other cause**, it restarts into the application after **10 minutes** in rescue mode, as long as it
    has an IP address and **nobody has done anything on its web page in the last 2 minutes** (saving Wi-Fi settings,
    scanning for networks, uploading firmware…). Just leaving the page open does not keep it in rescue mode.
  - It never leaves on its own **without a Wi-Fi connection** (rescue mode is then the way to set one up), and never
    during a firmware upload. `/api/status` reports the cause and the seconds left (`rescueCause`, `rescueExitIn`).
  - This does not mean the application is fixed — it does not even run in rescue mode. If it is still broken, the
    device falls back to rescue mode after a few failed starts, and the cycle repeats.
  - Older firmware (0.6.4 and before) does not restart by itself: after 10 healthy minutes it only makes the **next**
    power-on try the application again.

If the web page shows that the unit *always* boots into rescue mode because its flash cannot hold the boot
counter, the device keeps the rescue page available rather than risk running an application it cannot recover
from.

## What cannot be recovered without opening the device

The rescue core lives **inside the same firmware image**. It is not a separate recovery partition and there is no
automatic rollback. It cannot save you from:

- **an image that does not boot at all** (the rescue core inside it never starts);
- **a failure of the updater itself**;
- **a power cut while the new image is being copied into place** at restart. Keep the power stable during and right
  after an upload.

In those cases the only way back is to open the case and flash the device over its serial pads with a **3.3 V
USB-UART adapter**, holding `GPIO0` to ground at power-on to enter the ESP8266's flash mode. Reports from other
users describe the pads as `3V3 GND TXD0 RXD0 GPIO0 RST` on the board inside; this has not been verified by this
project. If you ever plan to open the device, **make a full backup of the flash first** (for example
`esptool.py read_flash 0x0 0x400000 backup.bin`), ideally before installing anything.

## Going back to the factory firmware

The factory firmware is **not distributed** by this project. If you want to return to it, you need your own copy
of it (for example a full flash backup taken over UART before the jailbreak). Without such a copy, there is no way
back to the factory firmware.

## What is done to keep updates working

- Every image is validated **before** the device switches to it: declared size, MD5, image structure, and a
  bootloader identical to the one installed. A rejected upload changes nothing, and you can retry.
- The bootloader of the device is never replaced or modified.
- Firmware updates never write into the internal storage, and the rescue mode never mounts it, so a corrupted
  resource cannot block an update.
- Upload time limits grow with the size of the image, so a slow connection (for example a phone far from the
  access point) is not rejected.
