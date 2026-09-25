# Panels: sending the device a ready-made screen

> **Images wear out the flash; text does not.** A 240×240 image is about 115 KB and a text panel about 0.5 KB —
> some 230 times less. Rewriting an image every minute is about 165 MB a day, roughly 80 rewrites of the whole
> storage per day: that kills a NOR flash within months. The same rate in text is about 3 MB a day, sustainable for
> years. **If the data changes often, send it as text, not as an image**, and upload only when it really changed.

> **The device has no schedule.** It never asks anyone for data, does not know how often a panel should be
> refreshed and never retries: it draws what it has, stops drawing it when it expires, and marks it "not updated"
> when more than half of its life has passed without a refresh. **Every schedule is yours.** Any interval in this
> document is a recommendation for whoever writes the client, never a device parameter. Keep in mind: **if your
> script stops working, the expiry time you set decides what stays on screen** — a panel without `V` stays forever,
> and one with `V` disappears and deletes itself.

A **panel** is a screen that **your program** composes and the device only draws: a few lines of text, a gauge, or
an image. It is for everything the device does not know and should not have to know — stock prices, tides, your
computer's CPU, a boiler alert, a quote of the day — without teaching it that topic or adding a new built-in
screen each time.

> **The rule behind everything: the device does not learn topics, it draws files.** It does no TLS, parses no
> third-party APIs and has about 40 KB of memory. Your program knows about stocks; the device only knows about
> rows, gauges and expiry. The album works the same way ([ALBUM-API.md](ALBUM-API.md)).

Panels exist only in **application mode**. In rescue mode these routes return `404`.

---

## 1. Two channels

|  | **Volatile** | **Stored** |
|---|---|---|
| How it is sent | `POST /api/app/panel`, panel in the body | a file `p-<slug>.jpp` uploaded with `POST /api/app/files` |
| Where it lives | a slot in memory | the internal storage (flash) |
| Survives a restart | **no** | yes |
| Expires and **deletes itself** | not needed: it disappears after its display time | yes, if it has `V` |
| Shown | **as soon as it arrives**, jumping to the foreground | when its turn comes |
| Good for | instant messages, fast-changing data | slow data: stocks, tides, a calendar as an image |

Both use **the same format** and **the same parser**. Several panels at once is the normal case: they all rotate
inside a single screen of the carousel, *Panels*, which you enable on the web page.

---

## 2. Access

Same as the rest of the API ([API.md](API.md) §1):

- **Address**: the device's IP on your network, or `192.168.4.1` from its own access point `SmallTV-Setup-<id>`.
- **HTTP Basic**, user `admin`, password `12345678`. To keep it out of your shell history you can use a netrc file
  with mode 600:

  ```sh
  printf 'machine <device-address> login admin password 12345678\n' > ~/.smalltv-netrc && chmod 600 ~/.smalltv-netrc
  ```
- **Session token** on every request that changes something: header `X-Rescue-Token`, taken from `GET /api/status`
  (field `token`). **It changes at every boot**: fetch it right before sending, do not store it.

---

## 3. The `PANEL1` format

**UTF-8** text, lines ending in `\n` **without `\r`**, fields separated by **ONE** tab. Everything is optional
except the first line.

```
PANEL1
T	<title>
S	<seconds 5..120>
C	<1..20>
V	<expiry: UTC epoch seconds>
G	<generated: UTC epoch seconds>
X	every|first
--- body, 8 lines at most ---
L	<row 0..7>	<large|normal|small>	<normal|accent|alert>	<text>
K	<row 0..7>	<label>	<value>
B	<row 0..7>	<0..100>	<text>
F	p-<slug>.jpb
```

The keywords (`large`, `normal`, `small`, `accent`, `alert`, `every`, `first`) must be written exactly like this
(lowercase).

### Header

| Field | What it is | Range | If missing |
|---|---|---|---|
| `T` | Title, top left | 1-24 bytes | no title |
| `S` | **Display time**: seconds it is shown each time | 5-120 | **8 s** (volatile) · the device's rotation time (stored) |
| `C` | **Every how many visits** to the panels screen it is shown | 1-20 | 1 (every visit) |
| `V` | **Expiry**, UTC epoch. After it, the panel is no longer shown **and its file is deleted** | 1-10 digits | never expires |
| `G` | When you **generated** it, UTC epoch. Only used for the "not updated" mark | 1-10 digits | no mark |
| `X` | **Alert**: a white flash at full brightness when it appears, and full brightness while it is shown. `every` = every time, `first` = the first time only | `every` \| `first` | no alert |

> **`V` on a volatile panel does not keep it alive; it can only remove it earlier.** A volatile panel is shown once
> and disappears after its display time `S`. `V` is an **additional** limit that can retire it even sooner — and
> its only way out if it was never shown.

> **The display time wins over the device's rotation.** If you ask for `S=40` and the device rotates every 15 s,
> your panel is shown for its full 40 s and only then does the carousel move on.

### Body

| Line | Fields | What it draws |
|---|---|---|
| `L` | row, size, tone, text | a line of text. `large` is two rows high |
| `K` | row, label, value | label on the left and value on the right, on the same row |
| `B` | row, percentage, text | a **gauge**: a bar with that percentage and the text next to it. The text may be empty |
| `F` | `p-<slug>.jpb` | the panel **IS** that image. **Excludes all other body lines** |

- **Rows**: 0 to 7, top to bottom. Gaps are allowed. Two lines on the same row are both drawn, in order (the
  second covers the first): not an error, but your problem.
- **Tones**: `normal` (white), `accent` (orange — the device's colour), `alert` (red).
- **Sizes**: `large` (two rows high), `normal`, `small`.

### Five examples

A calendar as an image, regenerated by your program four times a day:

```
PANEL1
T	Agenda
C	1
V	1789862400
G	1789833600
F	p-agenda.jpb
```

A birthday reminder, every second visit, until the end of the day:

```
PANEL1
T	Birthday
C	2
V	1789855140
L	1	large	accent	Birthday today
L	3	normal	normal	Martha
```

A conversion rate with a gauge, refreshed twice a day:

```
PANEL1
T	Web
C	3
V	1789884000
G	1789833600
K	1	Conversion	3.8 %
B	3	38	target 10 %
```

A boiler alarm that flashes every time it appears:

```
PANEL1
T	Alert
X	every
C	1
V	1789855140
L	1	large	alert	Boiler
L	3	normal	normal	Low pressure
```

An instant message, no file and no parameters: shown as soon as it arrives, for 8 s, then gone without a trace:

```
PANEL1
L	2	large	normal	Lunch is ready
L	4	normal	normal	Come down
```

---

## 4. Volatile channel: `POST /api/app/panel`

```
POST /api/app/panel[?t=…&s=…&c=…&ttl=…&x=…]
Content-Type: text/plain; charset=utf-8
X-Rescue-Token: <token>

<the panel as text, 1 to 512 bytes>
```

**Query parameters override the header lines in the body.** The short case is a POST with two body lines and
nothing else, and adding parameters does not require rebuilding the text:

| Parameter | Same as | Range |
|---|---|---|
| `t` | `T` | 1-24 bytes |
| `s` | `S` | 5-120 |
| `c` | `C` | 1-20 |
| `ttl` | `V` | 1-10 digits |
| `x` | `X` | `every` \| `first` |

### Responses

| Code | When | Body |
|---|---|---|
| `200` | accepted, and already on screen | `{"ok":true,"rows":2,"invalid":0,"durationS":8}` (rows, discarded lines, display time) |
| `400` | empty body | `{"error":"Empty panel"}` |
| `400` | body larger than 512 B | `{"error":"Panel too large: 512 bytes max"}` |
| `400` | does not start with `PANEL1`, or no usable row is left | `{"error":"Invalid panel","key":"body"}` |
| `400` | a query parameter out of range | `{"error":"Invalid value","key":"s"}` — `key` names the parameter |
| `401` | missing credentials | |
| `403` | token missing or expired (did the device restart?) | |
| `409` | a **firmware upload is in progress** | `{"error":"…"}` |
| `404` | the device is in **rescue mode** | |

The `error` text is a short human-readable message; rely on the code and on `key`.

> **With a body over 4 KB the device closes the connection without answering.** That is the web server's own
> limit, not this route: above 4 096 B it cuts the request. Between 513 and 4 096 B you get a clear `400`.

> **Set `Content-Type: text/plain`.** `curl --data` sends `application/x-www-form-urlencoded` by default, and then
> the device also tries to read your panel as `key=value` pairs. It works, but it is messy; with `text/plain` the
> body arrives as is. Use `--data-binary` so that tabs and newlines are kept.

---

## 5. Stored channel: a `p-<slug>.jpp` file

Uploaded through the usual storage route ([ALBUM-API.md](ALBUM-API.md) §2), nothing new:

```
POST /api/app/files      multipart/form-data, field `file`, file name = final name
```

### Names

| Thing | Pattern | Notes |
|---|---|---|
| Panel | `p-<slug>.jpp` | 30 characters in total at most |
| Image of a panel (`F`) | `p-<slug>.jpb` | **its own prefix**: never mixed with album images (`a-*.jpb`) |

- `<slug>`: **letters, digits, `_` and `-`**. Dots work (`p-stocks.v2.jpp` is shown), **but a name with dots is
  never deleted on expiry**: the automatic deletion rule is strict on purpose (`^p-[A-Za-z0-9_-]+\.jpp$`). If you
  use `V`, use a slug without dots.
- Uploading a name that already exists **replaces it**. The upload goes to a temporary file and replaces the old
  one at the end: an interrupted upload never leaves half a panel.
- A panel image is **JPB1**, the album format: convert it as described in [ALBUM-API.md](ALBUM-API.md) §6. The
  device **does not decode JPG, PNG or GIF**.

### Turning them on

The *Panels* screen is **off by default**. Turn it on in the web page, *Which screens are shown*, or through the
API:

```sh
curl -s --netrc-file ~/.smalltv-netrc -X POST -H "X-Rescue-Token: $TOKEN" \
     --data 'screens=clock,weather,panels' "$DEV/api/app/settings"
```

---

## 6. Runnable examples

```sh
DEV=http://<device-address>
TOKEN=$(curl -s --netrc-file ~/.smalltv-netrc "$DEV/api/status" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
```

### Instant message (the shortest possible)

```sh
printf 'PANEL1\nL\t2	large\tnormal\tLunch is ready\nL\t4\tnormal\tnormal\tCome down\n' |
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -H 'Content-Type: text/plain; charset=utf-8' --data-binary @- "$DEV/api/app/panel"
```

### With query parameters (15 s, with a title)

```sh
printf 'PANEL1\nL\t3\tnormal	accent\tWashing machine done\n' |
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -H 'Content-Type: text/plain; charset=utf-8' --data-binary @- \
     "$DEV/api/app/panel?t=Home&s=15&c=1"
```

### A gauge with the macOS CPU load, every minute

```sh
while :; do
  CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%d", s/'"$(sysctl -n hw.ncpu)"'}')
  printf 'PANEL1\nT\tMac\nS\t10\nK\t1\tCPU\t%s %%\nB\t3\t%s\t\n' "$CPU" "$CPU" |
  curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
       -H 'Content-Type: text/plain; charset=utf-8' --data-binary @- "$DEV/api/app/panel" > /dev/null
  sleep 60
done
```

(After a device restart the token changes: a long-running client should fetch it again when it gets a `403`.)

### Alert with a flash

```sh
printf 'PANEL1\nT\tAlert\nX	every\nL\t1	large	alert\tBoiler\nL\t3\tnormal\tnormal\tLow pressure\n' |
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -H 'Content-Type: text/plain; charset=utf-8' --data-binary @- "$DEV/api/app/panel?s=30"
```

### Stored panel that expires in 8 hours

```sh
TTL=$(( $(date +%s) + 8*3600 ))
{ printf 'PANEL1\nT\tStocks\nC\t2\nV\t%s\nG\t%s\n' "$TTL" "$(date +%s)"
  printf 'K\t1\tIBEX\t11842\nK\t2\tEURUSD\t1.0913\nB\t4\t62\tsince January\n'; } > p-stocks.jpp

curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -F "file=@p-stocks.jpp;type=text/plain" "$DEV/api/app/files"
```

### A panel that IS an image

```sh
# 1. the image, already converted to JPB1
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -F "file=@p-agenda.jpb;type=application/octet-stream" "$DEV/api/app/files"
# 2. the panel that points to it
TTL=$(( $(date +%s) + 8*3600 ))
printf 'PANEL1\nT\tAgenda\nC\t1\nV\t%s\nG\t%s\nF\tp-agenda.jpb\n' "$TTL" "$(date +%s)" > p-agenda.jpp
curl -s --netrc-file ~/.smalltv-netrc -H "X-Rescue-Token: $TOKEN" \
     -F "file=@p-agenda.jpp;type=text/plain" "$DEV/api/app/files"
```

### What the device thinks

```sh
curl -s --netrc-file ~/.smalltv-netrc "$DEV/api/app/health" |
python3 -c 'import sys,json;print(json.load(sys.stdin)["panels"])'
# {'active': 3, 'volatile': 0, 'invalid': 0, 'deleted': 1, 'stale': 1}
```

| Field | Meaning |
|---|---|
| `active` | stored panels currently valid. **`null` = the device has not counted them** (see below) |
| `volatile` | 1 if a volatile panel is alive |
| `invalid` | lines the device **discarded** from the panel it is showing. **If it is not 0, your format and the device's do not match** |
| `deleted` | expired panels the device has deleted since boot |
| `stale` | valid panels marked "not updated". **`null` just like `active`** |

> **`active` and `stale` can be `null`, which is not the same as 0.** The device only counts stored panels when
> the *Panels* screen takes its turn in the carousel; if that screen is off, nobody counts and the value is `null`.
> A client that adds or compares these values must treat `null` as "no data", not as zero. Volatile panels do
> **not** depend on this: they are shown even with the screen off, and `volatile` is always a number.

---

## 7. Limits

| Thing | Limit | What happens beyond it |
|---|---|---|
| Stored panels | 8 | the rest are not shown |
| Volatile slot | 1 | a new one replaces the previous |
| `POST` body | **512 B** | `400`; above 4 KB the connection is closed without an answer |
| `p-*.jpp` file | 2 048 B read; **512 B of useful content** | what does not fit is counted in `invalid` |
| Line | **96 B** including `\n` | discarded whole, and counted |
| Body rows | **8** | the ninth is discarded and counted |
| Title | 24 bytes | the `T` line is invalid |
| File name | 30 characters | the upload fails |

**Characters:** the device's fonts contain printable ASCII (32-126) plus the Spanish accented letters (A, E, I, O,
U with acute accent, U with diaeresis and N with tilde, upper and lower case), the inverted question and
exclamation marks, the degree sign and the middle dot. Anything else is replaced by `?`. This matters: an emoji in
a line would change the width of the whole row.

**Without the time** (the device has just started and has not synchronised yet): panels **without `V`** are shown
as usual; panels **with `V`** are not shown, and **nothing is deleted**. Without a clock, "expired" cannot be
decided.

**`first`** is remembered in memory: after a restart, a panel with `X first` alerts once more. Uploading or
deleting any file also re-arms `first` on every panel.

---

## 8. What the device does NOT do — and why it is your job

**It does not moderate the upload rate, and it has no schedule of its own.** You can upload a panel every second
and the device will accept it. That is deliberate: a rate limit on the device would be a new guard that could one
day reject something legitimate, and on a device whose only way back is the over-the-air update, that is not a
risk worth taking. **You are the moderator**, and the numbers are those of the warning at the top:

| What | Cost per write | Every minute would be | Verdict |
|---|---|---|---|
| Text panel (2 KB) | 2 KB | ~3 MB/day over a 2 MB filesystem with wear levelling | sustainable for **years** |
| Image (115 KB) | 115 KB | ~165 MB/day = **80 rewrites of the whole filesystem a day** | **kills the flash in months** |

Practical rules:

1. **Upload only if the content changed** (compare a digest on your side). Reasonable exception: with a slow
   schedule and a panel that carries `G`, uploading EVERY time is right — skipping an upload would age it into the
   "not updated" mark. A calendar every 3 hours is about 8 uploads of ~0.5 KB a day.
2. **Text: recommended minimum interval of 5 minutes.** For anything that changes every second, use the
   **volatile** channel: it never writes to flash.
3. **Images: do not regenerate them every minute.** Four times a day is the case this was designed for.
4. Watch `invalid` and `deleted` in `/api/app/health`: it is the only way to see misuse or a mismatch when it
   happens.

**Nor does it**, on purpose: delete album images, format, retry anything, keep history, interpret your data or
warn you if you stop uploading. And it **never deletes** anything that does not exactly match
`^p-[A-Za-z0-9_-]+\.jpp$` (plus its `p-*.jpb`, if no other live panel refers to it).

---

## 9. Troubleshooting

| Symptom | Most likely cause |
|---|---|
| `403` | the token expired: the device restarted. Ask `/api/status` again |
| `409` | a firmware upload is in progress. Wait |
| `404` on `/api/app/…` | the device is in **rescue mode**: the application is not running |
| The connection closes without an answer | body over 4 KB |
| `200` but nothing appears on a stored panel | the *Panels* screen is off: turn it on (§5) |
| `invalid` > 0 | you used `\r\n` instead of `\n`, spaces instead of tabs, or a keyword that does not exist |
| `?` appears where you wrote a letter | that character is not in the fonts (§7) |
| A panel with `V` does not appear | the device has no time yet, or `V` has already passed |
| An expired panel is still in the storage | its name has dots: it does not match the deletion pattern (§5) |
| It says "not updated" | more than half of the time between `G` and `V` passed without a refresh |
