# Photo album: uploading images without the web page

> **Images wear out the flash; text does not.** A 240×240 image is about 115 KB and a text panel about 0.5 KB —
> some 230 times less. Rewriting an image every minute is about 165 MB a day, roughly 80 rewrites of the whole
> storage per day: that kills a NOR flash within months. **If the data changes often, send it as text**, and
> upload images only for things that change a few times a day.
>
> For data that refreshes itself (stocks, CPU, calendar), use a **text panel**: see [PANEL-API.md](PANEL-API.md).

The album page on the device (`http://<device-address>/api/app/album`) is the comfortable way: choose a photo or a
GIF on your phone, it is converted right there and uploaded. This document is for **a program** — a script, another
app — that wants to do the same without the page.

> **The rule you cannot skip: the device does NOT decode images.** It does not accept JPG, PNG or GIF: only
> **JPB1**, its own format with the pixels already converted to the panel's format (RGB565), which the device copies
> as is. Whoever uploads must convert first (§6). The reason: an image decoder on the device would be third-party
> code with buffers of several KB, on a device whose only way back is the over-the-air update.

The album exists only in **application mode**. In rescue mode these routes return `404`, and the album page does not
exist either.

## 1. Access

- **Address**: the device's IP on your network (shown on its **Status** screen and on its home page), or
  `192.168.4.1` from its own access point `SmallTV-Setup-<id>`, which stays available in application mode too.
- **HTTP Basic authentication**, user `admin`, password `12345678`, on EVERY route. For `curl`, a netrc file with
  mode 600 keeps the password out of `ps` and your shell history:

  ```sh
  printf 'machine <device-address> login admin password 12345678\n' > ~/.smalltv-netrc && chmod 600 ~/.smalltv-netrc
  ```
- **Session token**: every request that changes something (`POST`) also carries the `X-Rescue-Token` header. It
  comes from `GET /api/status` (field `token`) and **changes at every boot**: fetch it right before sending, do not
  store it. The same JSON gives the mode (`"mode":"app"` or `"rescue"`).

## 2. Routes

| Method and route | What it does | Good response |
|---|---|---|
| `GET /api/status` | Device status; includes `token` and `mode` | `200` JSON |
| `GET /api/app/files` | Lists the whole storage (album, fonts, icons…) | `200` `{"mounted":true,"total":…,"used":…,"files":[{"name","bytes"}],"truncated":false}` |
| `POST /api/app/files` | Uploads a file: `multipart/form-data`, **field `file`**, and the **file name is the final name** | `200` `{"ok":true,"name":"a-cat.jpb","bytes":115216}` |
| `GET /api/app/files/get?name=…` | Returns the file as is, to verify an upload byte by byte | `200` the bytes |
| `POST /api/app/files/delete?name=…` | Deletes a file | `200` `{"ok":true}` |
| `GET /api/app/album` | The album page | `200` HTML |

JSON keys: `mounted`, `total` / `used` (bytes), `files` (each with `name` and `bytes`), `truncated`.

- `total` and `used` are present only when `mounted` is `true`. The listing contains **64 files at most** from
  the WHOLE storage — fonts and icons count too — and says so with `"truncated":true`. A file missing from the list
  may still exist: `files/get` finds it by name, and the album on the device does not depend on this listing.
- Uploading a name that already exists **replaces it**. The upload is written to a temporary file and replaces the
  old one at the end, so an interrupted upload never leaves half an image.
- There is also `POST /api/app/files/format`: it **erases the WHOLE storage** (fonts and icons included). It is not
  meant for the album.

## 3. Complete example with curl

```sh
DEV=http://<device-address>
TOKEN=$(curl -s --netrc-file ~/.smalltv-netrc "$DEV/api/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')

# Upload (the local file name IS the name on the device; otherwise add ;filename=a-other.jpb)
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -F "file=@a-cat.jpb;type=application/octet-stream" "$DEV/api/app/files"

# List, keeping only the album images and the free space
curl -s --netrc-file ~/.smalltv-netrc "$DEV/api/app/files" | python3 -c \
  'import sys,json;d=json.load(sys.stdin);print([a for a in d["files"] if a["name"].startswith("a-")], "free", d["total"]-d["used"])'

# Verify: the MD5 of what the device stores must match the local file
curl -s --netrc-file ~/.smalltv-netrc "$DEV/api/app/files/get?name=a-cat.jpb" | md5
md5 -q a-cat.jpb

# Delete
curl -s --netrc-file ~/.smalltv-netrc -X POST -H "X-Rescue-Token: $TOKEN" "$DEV/api/app/files/delete?name=a-cat.jpb"
```

(On Linux, use `md5sum` instead of `md5`.)

## 4. Names

- `a-<name>.jpb`: the `a-` prefix and the `.jpb` extension are what the album recognises; anything else in the
  storage is not part of the album.
- **30 characters at most in total**, only letters, digits, dot, hyphen and underscore, and not starting with a
  dot. The storage is flat: no folders.
- The album shows images in **alphabetical order**: use `a-01-…`, `a-02-…` if you want a fixed order. The album
  page generates `<name>` using `[a-z0-9-]` only.

## 5. The JPB1 format

A **16-byte little-endian** header, then the pixels.

| Offset | Size | Field | Value |
|---|---|---|---|
| 0 | 4 | magic | `"JPB1"` |
| 4 | 1 | version | `1` |
| 5 | 1 | flags | **`0`** (any other value is rejected) |
| 6 | 2 | width | 1-240 |
| 8 | 2 | height | 1-240 |
| 10 | 2 | frames | 1-32 |
| 12 | 2 | delay in ms | **clamped** (not rejected) to 20-5000 |
| 14 | 2 | reserved | **`0`** (same) |
| 16 | … | pixels | frame after frame, rows top to bottom, RGB565 in **big-endian** (high byte first) |

- The file size must be **exactly** `16 + frames × width × height × 2`. The device validates everything before
  drawing the first pixel; if anything is wrong, **it skips the image** (it never draws half of it).
- Images are drawn **centred** on the 240×240 panel, on black: a 120×120 animation appears in the middle with a
  black border.
- An animation has ONE delay for all its frames. A still photo uses the maximum (5000): it does not animate.
- The album page caps each file at **400 KiB of pixels** (a limit of the page, not of the device). At 80 px that
  allows 32 frames; at 120, 14; at 160, 8; at 240, 3.

## 6. Converting without the page

**Python.** The packing function below produces the same bytes as the album page for the same pixels, and the
device's validator accepts its output. The Pillow part (open, crop, scale) has not been tested by this project.

```python
import struct

def to565(r, g, b):   # ROUNDING, like the album page (truncating darkens by up to 7/255 per channel)
    return ((r * 31 + 127) // 255) << 11 | ((g * 63 + 127) // 255) << 5 | ((b * 31 + 127) // 255)

def jpb1(width, height, delay_ms, frames):   # frames: lists of width*height (r, g, b) tuples
    if not (1 <= width <= 240 and 1 <= height <= 240 and 1 <= len(frames) <= 32 and 20 <= delay_ms <= 5000):
        raise ValueError("outside the device limits")
    out = bytearray(struct.pack('<4sBBHHHHH', b'JPB1', 1, 0, width, height, len(frames), delay_ms, 0))
    for f in frames:
        for (r, g, b) in f:
            out += struct.pack('>H', to565(r, g, b))   # pixels in big-endian
    return bytes(out)

# NOT TESTED: a photo at 240x240 with a centred crop. If it has transparency, composite it on black first
# (convert('RGB') drops it without compositing; the screen would draw it black).
from PIL import Image, ImageOps
photo = ImageOps.fit(ImageOps.exif_transpose(Image.open('cat.jpg')).convert('RGB'), (240, 240), Image.LANCZOS)
open('a-cat.jpb', 'wb').write(jpb1(240, 240, 5000, [list(photo.getdata())]))
```

**GIF delays.** The album page uses the **median** of a GIF's frame delays (so one long pause does not slow down
every frame), treats delays of 0-1 hundredths as 100 ms (as browsers do) and, if not all frames fit, spreads the
kept frames evenly and lengthens the delay so the animation lasts the same.

## 7. Space

`free = total − used`, from `GET /api/app/files`. The filesystem (LittleFS) uses **whole 8 KiB blocks** plus a few
bytes of pointers per block, and the final rename rewrites metadata. The album page does not start an upload if
`(⌈bytes / 8128⌉ + 2) × 8192` does not fit in the free space: a photo (115 216 B) needs 17 blocks (136 KB) and the
largest file (409 616 B), 53. It is an **estimate**: the device has the last word and answers `507` if it runs out
of space. When **replacing** an image, the old one keeps its space until the new one has finished uploading.

## 8. Errors

The `error` text returned by these routes is a short human-readable message; rely on the status code.

| Code | What happened and what to do |
|---|---|
| 401 | Basic authentication missing or wrong password (during an upload this shows up as 403: see below) |
| 403 | On an upload: token expired, wrong password, or a firmware update in progress (the device checks all of these together, before accepting the body). Get a new token and retry |
| 403 | On other requests: token expired (the device restarted). Get a new one |
| 400 | Invalid name (see §4), or the multipart field is not called `file` |
| 400 | The multipart request arrived without a file |
| 400 | On `get` and `delete`: invalid name, or the storage is not formatted |
| 404 | The file does not exist; or the device is in **rescue mode**, where these routes do not exist |
| 409 | A firmware update is in progress: wait and retry |
| 409 | The storage is not formatted: format it once (web page, *Advanced → Internal storage*) |
| 507 | Not enough space: delete something |
| 500 | The final step failed. Retry |

- When it **rejects an upload**, the device answers and **closes the connection** so it does not keep receiving a
  body it no longer wants. Depending on timing, the client may see the answer or only a reset (`curl`:
  `Connection reset by peer`). After any network error, **read the listing before retrying**.
- The device's web server handles **one request at a time**: during a firmware update, other requests normally wait
  until they time out. When the update ends the device restarts, and the token changes.
- A reasonable timeout for an upload: 60 s + 1 s per KiB, up to 20 minutes.
