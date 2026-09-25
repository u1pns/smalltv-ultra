# Jailbreak — `smalltv-ultra-jailbreak-v0.1.2.bin`

This is the **only image the Geekmagic stock firmware accepts**. It is the door: you upload it once through the
stock firmware's own update page, and from then on the device runs our rescue bridge, which lets you install the
real firmware over the air. Step-by-step guide: [docs/01-jailbreak.md](../../docs/01-jailbreak.md).

| | |
|---|---|
| Size | 337 984 bytes |
| MD5 | `5db48ee5836ee273a84dcfe2e9de29bd` |
| SHA-256 | `36ed4e4a42a8291a52039d9a5252603a0fbb904132f7feab4d6411174f31c102` |

**What it does:** opens its own Wi-Fi access point with a small web page to join your Wi-Fi network and to upload
the next firmware. It is a bridge, not a resident recovery system: the next image you install replaces it.

**Credentials of the jailbreak image** (shared by every unit that runs it):
Wi-Fi access point password `12345678` · web page user `admin`, password `kapifo`.

**Known limitation:** it rejects uploads whose multipart body does not end with a final CRLF. Browsers and
`curl -F` always add it, so **upload it from a web browser or with `curl -F`**, not with unusual upload tools.

**Frozen:** this image is never rebuilt. The checksums above will never change.
