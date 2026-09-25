#!/usr/bin/env node
// agenda-ics.mjs - publish your upcoming calendar events on the SmallTV, from an iCalendar (.ics) file or URL.
//
//   node agenda-ics.mjs --ics FILE-OR-URL [--host HOST] [--hours 48] [--title Agenda]
//                       [--refresh-min 180] [--watch] [--volatile] [--dry-run] [--out FILE] [--now EPOCH]
//
//   --ics          a .ics file, or an http(s) URL (e.g. the "secret address in iCal format" of your calendar).
//                  You can also set SMALLTV_ICS instead, which keeps a private URL out of your shell history.
//   --hours N      how far ahead to look (default 48)
//   --title TEXT   panel title (default "Agenda")
//   --refresh-min  how often you plan to run it, in minutes (default 180). The panel expires after 4 refreshes:
//                  if this program stops running, the device marks the agenda "not updated" and later deletes
//                  it, instead of showing an old agenda forever.
//   --watch        keep running and refresh every --refresh-min minutes
//   --volatile     show it once right now (memory only) instead of saving it as the p-agenda.jpp panel
//   --dry-run      print the panel instead of sending it (no device needed)
//   --out FILE     write the panel to FILE instead of sending it (no device needed)
//   --now EPOCH    pretend the current time is this (seconds since 1970, UTC): useful for testing
//
// The device does no TLS and has about 40 KB of memory: the calendar is read and digested HERE, and the
// device only receives a text panel of at most 512 bytes. It is saved as a file so it survives restarts and
// rotates with your other panels (turn on the "panels" screen in the device web page).
//
// Privacy: this program never prints the calendar URL. It prints event titles only with --dry-run.
//
// Supported iCalendar subset (no dependencies, so not everything): VEVENT with DTSTART/DTEND/DURATION, all-day
// events, UTC, floating and TZID times (IANA zone names such as Europe/Madrid), RRULE with FREQ=DAILY/WEEKLY/
// MONTHLY/YEARLY + INTERVAL + COUNT + UNTIL + BYDAY (weekly), EXDATE, RECURRENCE-ID overrides, STATUS:CANCELLED.
// Not supported: BYMONTHDAY, BYSETPOS, BYDAY with ordinals ("2nd Tuesday"), RDATE, Windows zone names.
// For full RRULE support, parse with a library such as ical.js and feed the result to the Panel builder.
import {readFile, writeFile} from 'node:fs/promises';
import {SmallTV, Panel, parseArgs, DeviceError, LIMITS} from './smalltv.mjs';

const HOURS_DEFAULT = 48;
const REFRESH_MIN_DEFAULT = 180;          // every 3 h: ~8 small writes a day, easy on the flash
const REFRESH_MIN_MIN = 5;                // faster only wears the device flash for nothing
const LIVES_PER_REFRESH = 4;              // expiry = 4 refreshes: "not updated" after 2 missed runs, deleted after 4
const FETCH_TIMEOUT_MS = 30_000;
const ICS_MAX_BYTES = 50 * 1024 * 1024;   // refuse absurd downloads
const EXPANSION_CAP = 100_000;            // safety cap on generated occurrences per event
const PANEL_SLUG = 'agenda';              // p-agenda.jpp (no dots: the device only auto-deletes p-<slug>.jpp)
const DAY_MS = 86_400_000;
const LOCAL_ZONE = Intl.DateTimeFormat().resolvedOptions().timeZone;

// ---------------------------------------------------------------------------------------------------------
// iCalendar parsing
// ---------------------------------------------------------------------------------------------------------

/** Unfolds lines and returns [{name, params, value}] for every content line. */
function contentLines(text) {
  const unfolded = text.replace(/\r\n/g, '\n').replace(/\n[ \t]/g, '');
  const out = [];
  for (const raw of unfolded.split('\n')) {
    if (!raw) continue;
    const colon = findValueColon(raw);
    if (colon < 0) continue;
    const [name, ...rest] = raw.slice(0, colon).split(';');
    const params = {};
    for (const p of rest) { const eq = p.indexOf('='); if (eq > 0) params[p.slice(0, eq).toUpperCase()] = p.slice(eq + 1).replace(/^"|"$/g, ''); }
    out.push({name: name.toUpperCase(), params, value: raw.slice(colon + 1)});
  }
  return out;
}
function findValueColon(line) {   // the first colon that is not inside a quoted parameter
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === '"') quoted = !quoted;
    else if (line[i] === ':' && !quoted) return i;
  }
  return -1;
}
const unescapeText = v => v.replace(/\\([\\;,nN])/g, (_, c) => (c === 'n' || c === 'N' ? ' ' : c));

/** Offset (ms) of `zone` at the UTC instant `ms`. */
function zoneOffset(ms, zone) {
  const f = new Intl.DateTimeFormat('en-US', {timeZone: zone, hourCycle: 'h23', year: 'numeric', month: 'numeric',
    day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric'});
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map(x => [x.type, x.value]));
  return Date.UTC(+p.year, p.month - 1, +p.day, +p.hour, +p.minute, +p.second) - Math.floor(ms / 1000) * 1000;
}
/** Wall-clock time in `zone` (given as a naive UTC number) -> real UTC instant. */
function wallToUtc(naive, zone) {
  if (zone === 'UTC') return naive;
  let guess = naive - zoneOffset(naive, zone);
  guess = naive - zoneOffset(guess, zone);     // second pass settles DST edges
  return guess;
}
function validZone(z) { try { new Intl.DateTimeFormat('en-US', {timeZone: z}); return true; } catch { return false; } }

/** Parses a DATE or DATE-TIME value. Returns {naive, zone, allDay} ("naive" = wall clock as a UTC number). */
function parseTime(value, params) {
  const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(value.trim());
  if (!m) return null;
  const naive = Date.UTC(+m[1], m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0));
  if (!m[4]) return {naive, zone: LOCAL_ZONE, allDay: true};
  if (m[7]) return {naive, zone: 'UTC', allDay: false};
  const tz = params.TZID;
  return {naive, zone: tz && validZone(tz) ? tz : LOCAL_ZONE, allDay: false};
}
const instant = t => wallToUtc(t.naive, t.zone);

/** ISO 8601 duration (P1D, PT1H30M, P1W) in ms. */
function parseDuration(v) {
  const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v.trim());
  if (!m) return 0;
  const ms = (((+(m[2] || 0) * 7 + +(m[3] || 0)) * 24 + +(m[4] || 0)) * 60 + +(m[5] || 0)) * 60000 + +(m[6] || 0) * 1000;
  return m[1] === '-' ? -ms : ms;
}

/** Collects the VEVENTs of a calendar. */
function parseEvents(text) {
  const events = [];
  let ev = null;
  for (const {name, params, value} of contentLines(text)) {
    if (name === 'BEGIN' && value.toUpperCase() === 'VEVENT') { ev = {exdates: new Set()}; continue; }
    if (name === 'END' && value.toUpperCase() === 'VEVENT') { if (ev && ev.start) events.push(ev); ev = null; continue; }
    if (!ev) continue;
    switch (name) {
      case 'UID': ev.uid = value; break;
      case 'SUMMARY': ev.summary = unescapeText(value); break;
      case 'STATUS': ev.cancelled = value.toUpperCase() === 'CANCELLED'; break;
      case 'DTSTART': ev.start = parseTime(value, params); break;
      case 'DTEND': ev.end = parseTime(value, params); break;
      case 'DURATION': ev.duration = parseDuration(value); break;
      case 'RRULE': ev.rrule = Object.fromEntries(value.split(';').map(kv => kv.split('=')).map(([k, v]) => [k.toUpperCase(), v])); break;
      case 'EXDATE': for (const v of value.split(',')) { const t = parseTime(v, params); if (t) ev.exdates.add(instant(t)); } break;
      case 'RECURRENCE-ID': ev.recurrenceId = parseTime(value, params); break;
    }
  }
  return events;
}

// ---------------------------------------------------------------------------------------------------------
// Expansion into occurrences inside a window
// ---------------------------------------------------------------------------------------------------------

const WEEKDAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

/** Yields naive wall-clock starts of an event, in order. */
function* naiveStarts(ev) {
  const r = ev.rrule;
  if (!r) { yield ev.start.naive; return; }
  const interval = Math.max(1, parseInt(r.INTERVAL || '1', 10));
  const d0 = new Date(ev.start.naive);
  const [Y, M, D, h, mi, s] = [d0.getUTCFullYear(), d0.getUTCMonth(), d0.getUTCDate(), d0.getUTCHours(), d0.getUTCMinutes(), d0.getUTCSeconds()];
  const freq = (r.FREQ || '').toUpperCase();
  if (freq === 'WEEKLY' && r.BYDAY) {
    const days = r.BYDAY.split(',').map(x => WEEKDAYS.indexOf(x.trim().toUpperCase())).filter(x => x >= 0).sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7));
    const monday = ev.start.naive - ((d0.getUTCDay() + 6) % 7) * DAY_MS;    // weeks start on Monday (WKST default)
    for (let w = 0; ; w += interval) {
      for (const wd of days) {
        const t = monday + (w * 7 + (wd + 6) % 7) * DAY_MS;
        if (t >= ev.start.naive) yield t;
      }
    }
  }
  for (let k = 0; ; k += interval) {
    let t;
    switch (freq) {
      case 'DAILY': t = ev.start.naive + k * DAY_MS; break;
      case 'WEEKLY': t = ev.start.naive + k * 7 * DAY_MS; break;
      case 'MONTHLY': t = Date.UTC(Y, M + k, D, h, mi, s); if (new Date(t).getUTCDate() !== D) continue; break;   // no 31st in June: skipped (RFC 5545)
      case 'YEARLY': t = Date.UTC(Y + k, M, D, h, mi, s); if (new Date(t).getUTCMonth() !== M) continue; break;    // Feb 29 only in leap years
      default: yield ev.start.naive; return;     // unsupported frequency: keep the first occurrence only
    }
    yield t;
  }
}

/** Occurrences {start, end, allDay, title} of all events that overlap [from, to). */
export function occurrences(events, from, to) {
  const overrides = new Map();   // uid -> set of original starts that were moved or cancelled
  for (const ev of events) {
    if (ev.recurrenceId && ev.uid) {
      if (!overrides.has(ev.uid)) overrides.set(ev.uid, new Set());
      overrides.get(ev.uid).add(instant(ev.recurrenceId));
    }
  }
  const out = [];
  for (const ev of events) {
    const length = ev.end ? instant(ev.end) - instant(ev.start) : ev.duration || (ev.start.allDay ? DAY_MS : 0);
    const until = ev.rrule?.UNTIL ? parseTime(ev.rrule.UNTIL, {}) : null;
    const untilMs = until ? instant(until) : Infinity;
    const count = ev.rrule?.COUNT ? parseInt(ev.rrule.COUNT, 10) : Infinity;
    const moved = !ev.recurrenceId && ev.uid ? overrides.get(ev.uid) : null;
    let n = 0, guard = 0;
    for (const naive of naiveStarts(ev)) {
      if (++guard > EXPANSION_CAP) break;
      const start = wallToUtc(naive, ev.start.zone);
      if (start > untilMs || n >= count || start >= to) break;
      n++;
      if (ev.cancelled || ev.exdates.has(start) || (moved && moved.has(start))) continue;
      const end = start + Math.max(length, 0);
      if (end > from || start >= from) out.push({start, end, allDay: ev.start.allDay, title: ev.summary || '(no title)'});
    }
  }
  return out.sort((a, b) => a.start - b.start || a.title.localeCompare(b.title));
}

// ---------------------------------------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------------------------------------

function dayKey(ms) { return new Intl.DateTimeFormat('en-CA', {timeZone: LOCAL_ZONE}).format(new Date(ms)); }
function dayLabel(ms, nowMs) {
  const k = dayKey(ms);
  if (k === dayKey(nowMs)) return 'Today';
  if (k === dayKey(nowMs + DAY_MS)) return 'Tomorrow';
  return new Intl.DateTimeFormat('en-GB', {timeZone: LOCAL_ZONE, weekday: 'short', day: 'numeric', month: 'short'}).format(new Date(ms));
}
const clock = ms => new Intl.DateTimeFormat('en-GB', {timeZone: LOCAL_ZONE, hour: '2-digit', minute: '2-digit', hourCycle: 'h23'}).format(new Date(ms));

/**
 * One day header (accent colour) followed by its events, until the 8 rows are used. If some events do not
 * fit, the last row says how many were left out.
 */
export function buildAgendaPanel(list, {nowMs, title, refreshMin, persistent}) {
  const panel = new Panel().title(title);
  if (persistent) {
    const now = Math.floor(nowMs / 1000);
    panel.generated(now).expires(now + refreshMin * 60 * LIVES_PER_REFRESH);
  }
  if (!list.length) return panel.line('Nothing planned', {tone: 'accent'});
  // Plan the rows first: [kind, text] with kind "day" or "event".
  const rows = [];
  let lastDay = null;
  for (const o of list) {
    const shownDay = o.start < nowMs ? nowMs : o.start;        // an event already running counts as today
    const key = dayKey(shownDay);
    if (key !== lastDay) { rows.push(['day', dayLabel(shownDay, nowMs)]); lastDay = key; }
    const when = o.allDay ? 'all day' : o.start < nowMs ? 'now' : clock(o.start);
    rows.push(['event', `${when} ${o.title}`]);
  }
  let shown = rows;
  if (rows.length > LIMITS.ROWS) {
    shown = rows.slice(0, LIMITS.ROWS - 1);
    if (shown[shown.length - 1][0] === 'day') shown.pop();      // never end on a header without events
    const left = rows.slice(shown.length).filter(r => r[0] === 'event').length;
    shown.push(['more', `+${left} more`]);
  }
  for (const [kind, text] of shown) panel.line(text, kind === 'day' ? {tone: 'accent'} : kind === 'more' ? {size: 'small'} : {});
  return panel;
}

async function loadIcs(source) {
  if (/^https?:\/\//i.test(source)) {
    let res;
    try { res = await fetch(source, {signal: AbortSignal.timeout(FETCH_TIMEOUT_MS)}); }
    catch { throw new Error('could not download the calendar (network error or timeout)'); }   // never echo the URL
    if (!res.ok) throw new Error(`could not download the calendar: HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length > ICS_MAX_BYTES) throw new Error('the calendar is too big');
    return buf.toString('utf8');
  }
  return readFile(source, 'utf8');
}

async function runOnce(a, tv) {
  const nowMs = a.now ? Number(a.now) * 1000 : Date.now();
  const text = await loadIcs(a.ics);
  if (!/BEGIN:VCALENDAR/i.test(text)) throw new Error('that is not an iCalendar file');
  const list = occurrences(parseEvents(text), nowMs, nowMs + Number(a.hours ?? HOURS_DEFAULT) * 3_600_000);
  const refreshMin = Number(a['refresh-min'] ?? REFRESH_MIN_DEFAULT);
  const panel = buildAgendaPanel(list, {nowMs, title: a.title || 'Agenda', refreshMin, persistent: !a.volatile});
  if (a['dry-run']) { process.stdout.write(String(panel)); return; }
  if (a.out) { await writeFile(a.out, String(panel)); console.log(`written to ${a.out}: ${list.length} events`); return; }
  const stamp = new Date().toLocaleTimeString();
  if (a.volatile) { await tv.sendPanel(panel); console.log(`${stamp} shown now: ${list.length} events`); }
  else { await tv.savePanel(PANEL_SLUG, panel); console.log(`${stamp} saved p-${PANEL_SLUG}.jpp: ${list.length} events`); }
}

async function main() {
  const a = parseArgs(process.argv.slice(2), ['watch', 'volatile', 'dry-run', 'help']);
  a.ics = a.ics || process.env.SMALLTV_ICS;
  if (a.help || !a.ics) {
    console.log('usage: node agenda-ics.mjs --ics FILE-OR-URL [--host HOST] [--hours 48] [--title Agenda] ' +
                '[--refresh-min 180] [--watch] [--volatile] [--dry-run] [--out FILE] [--now EPOCH]');
    process.exit(a.help ? 0 : 2);
  }
  const refreshMin = Number(a['refresh-min'] ?? REFRESH_MIN_DEFAULT);
  if (!Number.isFinite(refreshMin) || refreshMin < REFRESH_MIN_MIN) throw new Error(`--refresh-min must be at least ${REFRESH_MIN_MIN}`);
  const tv = a['dry-run'] || a.out ? null : await SmallTV.locate(a.host);
  for (;;) {
    try {
      await runOnce(a, tv);
    } catch (e) {
      if (!a.watch || (e instanceof DeviceError && !e.isTemporary)) throw e;
      console.log(`${new Date().toLocaleTimeString()} skipped: ${e.message}`);
    }
    if (!a.watch || a['dry-run'] || a.out) return;
    await new Promise(r => setTimeout(r, refreshMin * 60_000));
  }
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('agenda-ics.mjs')) {
  main().catch(e => { console.error(`error: ${e.message}`); process.exit(1); });
}
export {parseEvents};
