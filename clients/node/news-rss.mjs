#!/usr/bin/env node
// news-rss.mjs - show the latest headlines of an RSS or Atom feed on the SmallTV.
//
//   node news-rss.mjs --feed FILE-OR-URL [--host HOST] [--title News] [--count 8] [--width 28]
//                     [--refresh-min 60] [--watch] [--volatile] [--dry-run] [--out FILE]
//
//   --feed         an RSS 2.0 or Atom feed: a local file or an http(s) URL. You can also set SMALLTV_FEED.
//   --title TEXT   panel title (default: the feed's own title, or "News"; about 9 characters fit)
//   --count N      how many headlines, 1..8 (default: as many as fit under the title, 8)
//   --width N      cut each headline to N characters with "..." (default 28, what fits on one row)
//   --refresh-min  how often you plan to run it, in minutes (default 60). The saved panel expires after
//                  4 refreshes, so a stopped script never leaves old news on screen as if it were current.
//   --watch        keep running and refresh every --refresh-min minutes
//   --volatile     show it once right now (memory only) instead of saving it as the p-news.jpp panel
//   --dry-run      print the panel instead of sending it (no device needed)
//   --out FILE     write the panel to FILE instead of sending it (no device needed)
//
// The device does no TLS and has about 40 KB of memory: the feed is downloaded and digested HERE, and the
// device only receives a text panel of at most 512 bytes. The feed is untrusted input: only the headline
// text is kept, tags and entities are stripped, and the download is capped in size and time.
//
// Node 18 or newer, no dependencies. The parser is deliberately small: it reads <item><title> (RSS) and
// <entry><title> (Atom). For anything fancier, parse with a library and pass the result to the Panel builder.
import {readFile, writeFile} from 'node:fs/promises';
import {SmallTV, Panel, parseArgs, DeviceError, LIMITS} from './smalltv.mjs';

const PANEL_SLUG = 'news';
const REFRESH_MIN_DEFAULT = 60;
const REFRESH_MIN_MIN = 5;
const LIVES_PER_REFRESH = 4;        // same rule as agenda-ics.mjs: expire after 4 missed refreshes
const WIDTH_DEFAULT = 28;           // characters of the normal font that fit on one 240 px row
const FETCH_TIMEOUT_MS = 20_000;
const FEED_MAX_BYTES = 2 * 1024 * 1024;

const ENTITIES = {amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
                  lsquo: "'", rsquo: "'", ldquo: '"', rdquo: '"', ndash: '-', mdash: '-', hellip: '...'};

/** Text of an XML element body: CDATA unwrapped, tags removed, entities decoded, spaces collapsed. */
export function cleanText(raw) {
  let t = String(raw).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
  t = t.replace(/<[^>]*>/g, ' ');
  t = t.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
    if (e[0] === '#') {
      const n = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : ' ';
    }
    return ENTITIES[e.toLowerCase()] ?? ' ';
  });
  // Typographic quotes and dashes the device fonts do not have: plain ASCII reads better than "?".
  t = t.replace(/[\u2018\u2019]/g, "'").replace(/[\u201C\u201D]/g, '"').replace(/[\u2013\u2014]/g, '-').replace(/\u2026/g, '...');
  return t.replace(/\s+/g, ' ').trim();
}

/** {title, headlines[]} from an RSS 2.0 or Atom document. */
export function parseFeed(xml) {
  const text = String(xml);
  const blocks = [...text.matchAll(/<(item|entry)\b[\s\S]*?<\/\1\s*>/gi)].map(m => m[0]);
  const titleOf = block => {
    const m = block.match(/<title\b[^>]*>([\s\S]*?)<\/title\s*>/i);
    return m ? cleanText(m[1]) : '';
  };
  // The feed title is the first <title> outside any item/entry.
  const head = text.split(/<(?:item|entry)\b/i)[0];
  return {title: titleOf(head), headlines: blocks.map(titleOf).filter(Boolean)};
}

/** Cuts a text to `width` characters, ending in "..." if it was longer. */
function ellipsis(text, width) {
  const chars = [...text];
  return chars.length <= width ? text : chars.slice(0, Math.max(1, width - 3)).join('').trimEnd() + '...';
}

export function buildNewsPanel(feed, {title, count, width, nowMs, refreshMin, persistent}) {
  const panel = new Panel().title(title || feed.title || 'News');
  if (persistent) {
    const now = Math.floor(nowMs / 1000);
    panel.generated(now).expires(now + refreshMin * 60 * LIVES_PER_REFRESH);
  }
  if (!feed.headlines.length) return panel.line('No headlines', {tone: 'accent'});
  feed.headlines.slice(0, count).forEach((h, i) =>
    panel.line(ellipsis(h, width), {tone: i === 0 ? 'accent' : 'normal'}));
  return panel;
}

async function loadFeed(source) {
  if (/^https?:\/\//i.test(source)) {
    let res;
    try { res = await fetch(source, {signal: AbortSignal.timeout(FETCH_TIMEOUT_MS)}); }
    catch { throw new Error('could not download the feed (network error or timeout)'); }
    if (!res.ok) throw new Error(`could not download the feed: HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length > FEED_MAX_BYTES) throw new Error('the feed is too big');
    return buf.toString('utf8');
  }
  return readFile(source, 'utf8');
}

function intArg(v, def, min, max, what) {
  const n = Number(v ?? def);
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(`--${what} must be an integer ${min}..${max}`);
  return n;
}

async function runOnce(a, tv) {
  const feed = parseFeed(await loadFeed(a.feed));
  const panel = buildNewsPanel(feed, {
    title: a.title,
    count: intArg(a.count, LIMITS.ROWS, 1, LIMITS.ROWS, 'count'),
    width: intArg(a.width, WIDTH_DEFAULT, 8, 60, 'width'),
    nowMs: Date.now(),
    refreshMin: Number(a['refresh-min'] ?? REFRESH_MIN_DEFAULT),
    persistent: !a.volatile,
  });
  if (a['dry-run']) { process.stdout.write(String(panel)); return; }
  if (a.out) { await writeFile(a.out, String(panel)); console.log(`written to ${a.out}: ${feed.headlines.length} headlines`); return; }
  const stamp = new Date().toLocaleTimeString();
  if (a.volatile) { await tv.sendPanel(panel); console.log(`${stamp} shown now`); }
  else { await tv.savePanel(PANEL_SLUG, panel); console.log(`${stamp} saved p-${PANEL_SLUG}.jpp`); }
}

async function main() {
  const a = parseArgs(process.argv.slice(2), ['watch', 'volatile', 'dry-run', 'help']);
  a.feed = a.feed || process.env.SMALLTV_FEED;
  if (a.help || !a.feed) {
    console.log('usage: node news-rss.mjs --feed FILE-OR-URL [--host HOST] [--title News] [--count 8] [--width 28] ' +
                '[--refresh-min 60] [--watch] [--volatile] [--dry-run] [--out FILE]');
    process.exit(a.help ? 0 : 2);
  }
  const refreshMin = Number(a['refresh-min'] ?? REFRESH_MIN_DEFAULT);
  if (!Number.isFinite(refreshMin) || refreshMin < REFRESH_MIN_MIN) throw new Error(`--refresh-min must be at least ${REFRESH_MIN_MIN}`);
  const offline = a['dry-run'] || a.out;
  const tv = offline ? null : await SmallTV.locate(a.host);
  for (;;) {
    try {
      await runOnce(a, tv);
    } catch (e) {
      if (!a.watch || (e instanceof DeviceError && !e.isTemporary)) throw e;
      console.log(`${new Date().toLocaleTimeString()} skipped: ${e.message}`);
    }
    if (!a.watch || offline) return;
    await new Promise(r => setTimeout(r, refreshMin * 60_000));
  }
}

if (process.argv[1]?.endsWith('news-rss.mjs')) {
  main().catch(e => { console.error(`error: ${e.message}`); process.exit(1); });
}
