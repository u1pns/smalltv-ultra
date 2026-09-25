# SmallTV Node.js apps

Four ready-to-run apps, the small client library they share, and an MCP server for AI assistants. Node.js 18 or newer, **no dependencies**
(no `npm install`): they use Node's built-in `fetch`, `FormData` and `os`.

This is a personal experiment, not a product. No warranty. You can brick your device. Recovery requires the
built-in web updater; if the device does not boot, you need to open it and use a UART adapter.

| File | What it is |
|---|---|
| `pc-stats.mjs` | shows this computer's CPU, memory and disk use on the device, refreshed every few seconds |
| `agenda-ics.mjs` | publishes your upcoming calendar events from an `.ics` file or URL |
| `news-rss.mjs` | publishes the latest headlines of an RSS or Atom feed |
| `ai-status.mjs` | shows what your AI coding agent is doing: working, idle or waiting for you |
| `discover.mjs` | lists the devices on this network (address, name, MAC, firmware, mode) |
| `mcp/` | an MCP server so an AI assistant can use the device — see [mcp/README.md](mcp/README.md) |
| `smalltv.mjs` | the client library: device API calls plus a `Panel` builder that enforces the device limits |
| `examples/sample.ics` | a synthetic calendar to try `agenda-ics.mjs` without your own |
| `examples/sample-feed.xml` | a synthetic feed (invented headlines) to try `news-rss.mjs` offline |

**Without an address the apps find the device on your network** (UDP discovery, about two seconds): if exactly one
device answers they use it and say so; if several answer they list them and ask you to choose with `--host`; if none
answers they say why that can happen. `node discover.mjs` just lists them (`--ip` prints the first address,
`--json` the whole list). To choose, set the address once (`export SMALLTV_HOST=10.0.0.42`, or
`$env:SMALLTV_HOST='10.0.0.42'` on Windows) or pass `--host` on every call. Discovery is a broadcast: guest networks
and "client isolation" block it. User and password default to `admin` / `12345678`; override them
with `SMALLTV_USER` and `SMALLTV_PASSWORD`. Every app has `--dry-run`, which prints the panel, and `--out FILE`,
which writes it to a file; neither needs a device.

Screenshots of what each app draws: [docs/05-pc-apps.md](../../docs/05-pc-apps.md).

## pc-stats.mjs

```sh
node pc-stats.mjs --dry-run                  # see what it would send
node pc-stats.mjs                            # every 30 s, 10 s on screen each time
node pc-stats.mjs --every 10 --seconds 10    # keeps the stats on screen while it runs
node pc-stats.mjs --once --name "Office PC"
```

It uses the **volatile** panel channel: the panel lives in the device memory and never writes the flash,
so frequent updates are fine. Each panel jumps to the front for `--seconds` and then the normal rotation
continues. Memory use is what the operating system reports; macOS counts file cache as used, so the number
looks high there.

## agenda-ics.mjs

```sh
node agenda-ics.mjs --ics examples/sample.ics --now 1791439200 --dry-run    # the sample, on a fixed date
node agenda-ics.mjs --ics ~/calendar.ics                                    # saves the p-agenda.jpp panel
SMALLTV_ICS='https://calendar.example.invalid/private-XXXX/basic.ics' node agenda-ics.mjs --watch
```

- Reads the calendar here and sends the device a text panel of at most 512 bytes: the device does no TLS and
  has about 40 KB of memory, so it never sees the calendar itself.
- By default it **saves** the panel as `p-agenda.jpp`: it survives restarts and rotates with the other panels
  (turn on the "panels" screen in the web page). `--volatile` shows it once instead.
- The panel expires after 4 refresh periods (`--refresh-min`, default 180 minutes). If the program stops, the
  device first marks the agenda "not updated" and later deletes it: it never shows an old agenda as current.
  Run it from cron, launchd or Task Scheduler at that cadence, or leave it running with `--watch`.
- A private calendar URL is a secret (anyone with it can read your calendar). Prefer the `SMALLTV_ICS`
  variable over `--ics` so it stays out of your shell history. The app never prints it.
- Supported iCalendar subset: VEVENT, DTSTART/DTEND/DURATION, all-day events, UTC, floating and TZID times
  (IANA names like `Europe/Madrid`), RRULE with FREQ DAILY/WEEKLY/MONTHLY/YEARLY plus INTERVAL, COUNT, UNTIL and
  weekly BYDAY, EXDATE, RECURRENCE-ID and cancelled events. Not supported: BYMONTHDAY, BYSETPOS, ordinal BYDAY
  ("second Tuesday"), RDATE, Windows time-zone names. If you need those, parse with a library such as `ical.js`
  and pass the result to the `Panel` builder.

## news-rss.mjs

```sh
node news-rss.mjs --feed examples/sample-feed.xml --title News --dry-run     # the sample, offline
SMALLTV_FEED='https://news.example.invalid/rss.xml' node news-rss.mjs --title News --watch
```

- Downloads and reads the feed here (RSS 2.0 `<item>` or Atom `<entry>` titles) and sends the device only the
  headlines, each cut to one row (`--width`, default 28 characters). The first one is highlighted.
- By default it **saves** the panel as `p-news.jpp`, expiring after 4 refresh periods (`--refresh-min`, default
  60); `--volatile` shows it once instead.
- The feed is untrusted input: only headline text is kept (tags and entities stripped), and the download is
  capped at 2 MB and 20 s. The title fits about 9 characters: pass a short `--title`.

## ai-status.mjs

Shows the state of an AI coding agent on the device: **Working**, **Idle** or **Needs you** (a question or a
permission prompt), with the task or project name and how long ago it changed. It uses the **volatile** panel
channel, so it never writes the flash however often it updates. It needs no credentials and calls no API: it reads a
small JSON file that your agent's hooks write.

```json
{"agent": "Claude Code", "state": "working", "task": "my-project", "updated": 1790000000}
```

`state` is `working`, `idle` or `waiting`; `updated` is epoch seconds (an ISO date also works). The file lives in
`~/.smalltv/ai-status.json` unless you set `SMALLTV_AI_STATUS_FILE` or pass `--file`.

```sh
node ai-status.mjs --set working --task "Fix the login test"    # write the file by hand
node ai-status.mjs --dry-run                                     # see the panel
node ai-status.mjs --watch                                       # send it whenever the file changes
```

With `--watch` it sends a panel each time the file changes and repeats it every `--every` seconds (default 120)
while the agent is working or waiting, so it comes back in the screen rotation; `--seconds` (default 15) is how
long it stays each time. "Needs you" flashes the first time it appears. After `--stale-min` minutes (default 30)
without an update the panel says so instead of pretending the agent is still busy.

**Claude Code hooks.** Add this to `~/.claude/settings.json` (or a project's `.claude/settings.json`), with the
absolute path of `ai-status.mjs`. `--from-hook` reads the details Claude Code passes on stdin and uses the project
folder name as the task, or the notification text when Claude is waiting for you:

```json
{
  "hooks": {
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "node /path/to/ai-status.mjs --set working --from-hook"}]}],
    "Notification":     [{"hooks": [{"type": "command", "command": "node /path/to/ai-status.mjs --set waiting --from-hook"}]}],
    "Stop":             [{"hooks": [{"type": "command", "command": "node /path/to/ai-status.mjs --set idle --from-hook"}]}]
  }
}
```

Then leave `node ai-status.mjs --watch` running in a terminal. Any other agent or tool works the same way: whatever
can write that JSON file (or run `--set`) can drive the panel. The prompt text itself is never written to the
file, only the project name, so nothing you type ends up on the screen.

## Writing your own

```js
import {SmallTV, Panel} from './smalltv.mjs';

const tv = await SmallTV.locate();             // SMALLTV_HOST, or discovery; or new SmallTV({host: '10.0.0.42'})
const panel = new Panel().title('Stocks').seconds(15)
  .keyValue('ACME', '12.40')
  .bar(62, 'since January');
await tv.sendPanel(panel);                     // shown now, memory only
await tv.savePanel('stocks', panel.generated(new Date()).expires(Date.now() / 1000 + 8 * 3600));
await tv.setSettings({brightness: 40});
```

`Panel` replaces characters the device fonts cannot draw with `?`, cuts long lines and refuses panels that
would break the device limits (8 rows, 96 bytes per line, 512 bytes in total), so a mistake shows up on your
computer instead of as a silently discarded line. Errors from the device are `DeviceError`s; `isTemporary` is
true for "rescue mode" (404), "update in progress" (409) and "no answer", which are normal states to retry later.

Two rules that keep the device healthy:

1. **Text, not images, for anything that changes often.** A panel is about 0.5 KB; an image is about 115 KB.
2. **Saved panels are flash writes: save only when the content changes.** The volatile channel never writes
   the flash.

**A saved panel does not appear at once.** It joins the normal rotation and waits its turn, so if the device is
showing the clock you may not see it for a while. A volatile panel jumps to the front straight away: use
`--volatile` when you want to check that a panel looks right.
