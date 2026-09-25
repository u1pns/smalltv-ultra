# Firmware images

Which file do you need?

| You have… | Upload this | Guide |
|---|---|---|
| A SmallTV Ultra with the **original Geekmagic firmware** | [`jailbreak/`](jailbreak/) first, then the latest version | [docs/01-jailbreak.md](../docs/01-jailbreak.md) |
| A device already running the **jailbreak** or **any version of this firmware** | the latest version folder | [docs/02-install-firmware.md](../docs/02-install-firmware.md) |

Latest version: **[v0.6.5](v0.6.5/)**.

Each version folder contains the firmware `.bin`, the resource pack `.res` (fonts and icons), a `README.md` with
what the version brings, and a `manifest.json` with sizes and checksums. The update page asks for the firmware's MD5: copy it
from `manifest.json`. It detects a damaged download or upload; it does not prove who built the file.

There is no way back to the Geekmagic firmware from here unless you kept your own copy of it: we do not
distribute the manufacturer's image.
