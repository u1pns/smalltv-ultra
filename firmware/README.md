# Firmware images

Everything you upload to the device lives in this folder. There are only **three files** you need, plus an optional
language pack, and which ones you need depends on what your device is running today.

## What is in this folder

```
firmware/
├── jailbreak/                                   the door: used ONCE per device
│   ├── smalltv-ultra-jailbreak-v0.1.2.bin       the jailbreak (rescue bridge) image
│   ├── manifest.json                            size and checksums
│   └── README.md
└── v0.6.7/                                      the latest release
    ├── smalltv-ultra-v0.6.7.bin                 the application firmware
    ├── smalltv-ultra-resources.res              fonts and icons for the screens
    ├── smalltv-ultra-lang-{es,fr,it}.res        optional language packs
    ├── manifest.json                            sizes and checksums
    └── README.md                                what this version brings
```

| File | What it is | When you upload it | Where you upload it |
|---|---|---|---|
| `smalltv-ultra-jailbreak-v0.1.2.bin` | A small image whose only job is to get past the factory firmware. It opens its own Wi-Fi access point and a web page to install the next image. It does not show the clock. | **Once**, on a device that still runs the original GeekMagic firmware | The **factory** update page, `http://<device-address>/update` |
| `smalltv-ultra-v0.6.7.bin` | The application: clock, weather, forecast, album, panels, web settings, and the rescue core that keeps the device updatable | Right after the jailbreak, and again for every future update | The **jailbreak** page, or the application's own page (*Advanced → Update the firmware*) |
| `smalltv-ultra-resources.res` | The resource pack: 38 fonts and icons, stored in the device's internal storage, not in the firmware | Once after the first install, and only again if a release says so | The application's page (*Advanced → Update the firmware*: the same file field accepts `.bin` and `.res`) |
| `smalltv-ultra-lang-<code>.res` (optional) | A language pack: Spanish (`es`), French (`fr`) or Italian (`it`) for the screens and the everyday part of the web page. Without one, the device speaks English | Only if you want another language; one at a time, the last one uploaded wins | The application's page (*Advanced → Update the firmware*, or *Advanced → Internal storage*) |

The `.bin` files are complete firmware images. The `.res` files are **not** firmware: each is a bundle of small
files that your browser unpacks and sends one by one.

## Which files do you need?

| Your device runs… | Upload, in this order | Guide |
|---|---|---|
| The **original GeekMagic firmware** (a new unit) | 1. jailbreak `.bin` → 2. application `.bin` → 3. `.res` | [Quick start](../README.md#quick-start), then [01](../docs/01-jailbreak.md) and [02](../docs/02-install-firmware.md) |
| The **jailbreak** (you did step 1 but not step 2) | 1. application `.bin` → 2. `.res` | [docs/02-install-firmware.md](../docs/02-install-firmware.md) |
| **Any version of this firmware** | the new application `.bin` only | [docs/02-install-firmware.md](../docs/02-install-firmware.md#updating-later) |

Firmware updates keep your Wi-Fi, settings, resources, album and panels. You only upload the `.res` again on a new
unit, after formatting the storage, or when a release README tells you to.

## Logins: each image has its own

| Image running on the device | Its Wi-Fi access point | Web page login |
|---|---|---|
| Original GeekMagic firmware | — | none |
| **Jailbreak** | `SmallTV-Setup-<chip-id>`, password `12345678` | user `admin`, password **`kapifo`** |
| **Application** (any version) | `SmallTV-Setup-<chip-id>`, password `12345678` | user `admin`, password **`12345678`** |

`<chip-id>` is the last six hex digits of the device's MAC address, in lowercase (a MAC ending in `…:12:ab:34`
gives `SmallTV-Setup-12ab34`). All passwords are lowercase; phones like to capitalise the first letter.

After you upload the jailbreak, **the device leaves your Wi-Fi** (the jailbreak does not know your network):
join its access point, open `http://192.168.4.1/` and log in with `kapifo`. Its page is **in Spanish**, because
that image is frozen and never rebuilt. The Quick start walks through it step by step.

## Check every download before uploading it

Each folder's `manifest.json` lists the exact size, MD5 and SHA-256 of its files. Compare them with what you
downloaded:

| System | Command |
|---|---|
| macOS | `md5 smalltv-ultra-v0.6.7.bin` |
| Linux | `md5sum smalltv-ultra-v0.6.7.bin` |
| Windows (PowerShell) | `Get-FileHash -Algorithm MD5 smalltv-ultra-v0.6.7.bin` |

When you upload a `.bin`, the device's page asks for its MD5: copy it from `manifest.json` (or the folder's
README). The device also checks the size, the image structure and that it will boot, **before** it replaces
anything; a rejected upload leaves the current firmware in place and you can simply try again.

A matching MD5 detects a damaged download or upload. It does not prove who built the file.

## Good to know

- **The jailbreak is frozen.** It is never rebuilt, so its checksums will never change. It stays at v0.1.2 even
  when the application moves on.
- **The jailbreak does not stay on the device.** Installing the application replaces it. Recovery from then on is
  the application's own rescue mode: [docs/04-recovery.md](../docs/04-recovery.md).
- **Each release folder is self-contained:** the `.bin`, the `.res` and their checksums, nothing else needed.
- **There is no way back to the GeekMagic firmware** unless you kept your own copy of it: the manufacturer's image
  is not distributed here.
- **Do not cut the power** while an image is uploading or while the device restarts.
