# 5. Sending screens from your computer

The firmware does not grow new built-in screens for every kind of data. Instead, **a program on your computer
composes a screen and sends it**; the device only draws it. This is how you show your computer's CPU usage, a
calendar, a stock price, a home-automation alert or a message — without the device knowing anything about those
topics.

The device has no schedule of its own: it never asks anyone for data and never retries. **Your program decides how
often to send**, and the expiry time you put in a panel decides what stays on screen if your program stops.

## The two ways to send something

| | **Volatile panel** | **Stored panel** |
|---|---|---|
| How | `POST /api/app/panel` with the panel in the body | upload a file `p-<name>.jpp` to the internal storage |
| Shown | immediately, then it disappears (8 s by default) | in turn, among the other panels |
| Survives a restart | no | yes |
| Writes to flash | no | yes |
| Good for | instant messages, anything that changes often | slow data: a calendar, market data a few times a day |

Both use the same small text format, `PANEL1`: a few header lines (title, how long it stays, expiry) and up to
8 rows of text, label/value pairs or gauges — or a single image. Stored panels are shown on the **Panels** screen,
which is off by default: enable it in *Which screens are shown*. Volatile panels are shown even when it is off.

A minimal example (replace the address; the token comes from `GET /api/status`):

```sh
DEV=http://<device-address>
TOKEN=$(curl -s -u admin:12345678 "$DEV/api/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
printf 'PANEL1\nL\t2\tlarge\tnormal\tLunch is ready\n' |
  curl -s -u admin:12345678 -H "X-Rescue-Token: $TOKEN" \
       -H 'Content-Type: text/plain; charset=utf-8' --data-binary @- "$DEV/api/app/panel"
```

Full format, limits and error codes: [api/PANEL-API.md](api/PANEL-API.md). All other endpoints:
[api/API.md](api/API.md). Album images from a script: [api/ALBUM-API.md](api/ALBUM-API.md).

## Ready-made clients

The [`clients/`](../clients/) folder contains example programs:

- [`clients/mac/`](../clients/mac/) — shell scripts for macOS.
- [`clients/windows/`](../clients/windows/) — PowerShell scripts for Windows.
- [`clients/node/`](../clients/node/) — Node.js programs: CPU, memory and disk use, a calendar agenda, news
  headlines from an RSS feed, and the status of your AI coding agent (working, idle, waiting for you).
- [`clients/node/mcp/`](../clients/node/mcp/) — an MCP server, so an AI assistant on your computer (Claude Code,
  Claude Desktop, Cursor, Codex...) can find the device, read its status, show panels and change settings.

What the Node.js examples look like on the device (sample data; none of these screens is built into the firmware):

| `pc-stats.mjs` | `agenda-ics.mjs` | `news-rss.mjs` | your own, with `smalltv.mjs` |
|---|---|---|---|
| ![PC stats panel](images/panel-pc-stats.png) | ![Agenda panel](images/panel-agenda.png) | ![News panel](images/panel-news.png) | ![Server monitor panel](images/panel-server.png) |

Each folder has its own instructions. None of them hardcodes the device's address. **Without an address they find
the device by themselves** with UDP discovery: if exactly one device answers they use it and say so; if several
answer they list them and ask you to choose; if none answers they tell you why that can happen. To choose, pass the
address as an argument or set the `SMALLTV_HOST` environment variable. Each folder also has a `discover` command
that just lists the devices it finds.

Discovery is a broadcast on your local network: it does not cross routers, and guest networks or "client
isolation" usually block it. In those cases set the address by hand (the device's *Status* screen shows it).

## Rules for well-behaved clients

1. **Prefer text to images for anything that changes often.** A 240×240 image is about 115 KB; a text panel is
   about 0.5 KB — some 230 times less flash wear. Rewriting an image every minute is about 165 MB a day, roughly 80
   rewrites of the whole storage per day: that wears out the flash within months. The same rate as text is about
   3 MB a day, sustainable for years.
2. **Upload only when the content has changed** (compare a digest on your side). For data that changes every few
   seconds, use volatile panels: they never touch the flash.
3. **Do not rely on a fixed IP address.** Use discovery (every client here does it) or the hostname
   ([03-features.md](03-features.md)).
4. **Treat `404` and `409` as normal states**: `404` on `/api/app/...` means the device is in rescue mode, `409`
   means a firmware update is in progress. Try again later.
5. **Fetch the token again after a `403`**: the device restarted and the token changed.
