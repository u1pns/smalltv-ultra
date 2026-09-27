// smalltv.mjs - a small, dependency-free client for the SmallTV firmware HTTP API, plus a panel builder.
//
// Node 18 or newer (uses the built-in fetch, FormData and Blob). Import it from your own scripts:
//
//   import {SmallTV, Panel} from './smalltv.mjs';
//   const tv = SmallTV.fromEnv();                       // SMALLTV_HOST, SMALLTV_USER, SMALLTV_PASSWORD
//   await tv.sendPanel(new Panel().title('Home').big('Dinner ready').line('Come down'));
//
// What the device expects is documented in the panel API (docs/api/PANEL-API.md). The device is the
// authority: if this file and the device disagree, the device is right.

/** Panel limits, from the panel API. */
export const LIMITS = Object.freeze({
  PANEL_BYTES: 512,      // whole panel, volatile or file
  LINE_BYTES: 96,        // one line, including its newline
  ROWS: 8,               // body rows 0..7 ("big" text takes two)
  TITLE_BYTES: 24,
  SECONDS_MIN: 5,        // time on screen
  SECONDS_MAX: 120,
  EVERY_MAX: 20,         // "show on every Nth visit"
  NAME_CHARS: 30,        // resource file name
});

/** Upload time budget, as the device web page does it: 60 s + 1 s per KiB, at most 20 min. */
export function uploadBudgetMs(bytes) {
  return Math.min(60_000 + Math.floor(bytes / 1024) * 1000, 1_200_000);
}
const REQUEST_TIMEOUT_MS = 15_000;

/**
 * Characters the device fonts can draw: ASCII 32..126 plus a short list of Spanish letters and
 * symbols (written as escapes to keep this file ASCII). Anything else is drawn as "?" by the device;
 * we replace it here so you can see it before sending.
 */
const EXTRA = '\u00C1\u00C9\u00CD\u00D3\u00DA\u00DC\u00D1\u00E1\u00E9\u00ED\u00F3\u00FA\u00FC\u00F1\u00BF\u00A1\u00B0\u00B7';

/** Makes a text safe for a panel field: device charset, no tabs or newlines. */
export function sanitize(text) {
  let out = '';
  for (const ch of String(text ?? '').normalize('NFC')) {
    const c = ch.codePointAt(0);
    if (c === 9 || c === 10 || c === 13) out += ' ';
    else if ((c >= 32 && c <= 126) || EXTRA.includes(ch)) out += ch;
    else out += '?';
  }
  return out;
}

/** Cuts a text to at most `max` UTF-8 bytes without splitting a character. */
export function cutBytes(text, max) {
  if (Buffer.byteLength(text) <= max) return text;
  let out = '', n = 0;
  for (const ch of text) {
    const b = Buffer.byteLength(ch);
    if (n + b > max) break;
    out += ch; n += b;
  }
  return out;
}

export class PanelError extends Error {}

const SIZES = ['normal', 'large', 'small'];
const TONES = ['normal', 'accent', 'alert'];

/**
 * Builds a PANEL1 text. Rows are placed top to bottom in the order you add them.
 * Sizes and tones are the PANEL1 protocol words.
 */
export class Panel {
  #header = [];
  #rows = [];
  #row = 0;

  title(t) { return this.#head('T', cutBytes(sanitize(t), LIMITS.TITLE_BYTES)); }
  /** Seconds on screen each time it is shown (5..120). */
  seconds(s) { return this.#head('S', intIn(s, LIMITS.SECONDS_MIN, LIMITS.SECONDS_MAX, 'seconds')); }
  /** Show it only on every Nth visit of the panels screen (1..20). */
  every(n) { return this.#head('C', intIn(n, 1, LIMITS.EVERY_MAX, 'every')); }
  /** Expiry, as a Date or epoch seconds: after it the panel is hidden and, if it is a file, deleted. */
  expires(when) { return this.#head('V', epoch(when)); }
  /** When the data was generated: lets the device mark the panel "not updated" at half its life. */
  generated(when) { return this.#head('G', epoch(when)); }
  /** Flash and full brightness: 'every' time it appears, or only the 'first' time. */
  alert(mode = 'every') {
    if (mode !== 'every' && mode !== 'first') throw new PanelError(`unknown alert mode: ${mode}`);
    return this.#head('X', mode);
  }

  /** A line of text. size: 'normal' | 'large' | 'small'; tone: 'normal' | 'accent' | 'alert'. */
  line(text, {size = 'normal', tone = 'normal'} = {}) {
    if (!SIZES.includes(size) || !TONES.includes(tone)) throw new PanelError(`unknown size or tone: ${size}/${tone}`);
    return this.#body(size === 'large' ? 2 : 1, ['L', null, size, tone], sanitize(text));
  }
  /** A line of large text (two rows high). */
  big(text, tone) { return this.line(text, {size: 'large', tone}); }
  /** Label on the left, value on the right. */
  keyValue(label, value) { return this.#body(1, ['K', null, sanitize(label)], sanitize(value)); }
  /** A gauge filled to `percent` with an optional text. */
  bar(percent, text = '') {
    const p = Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
    return this.#body(1, ['B', null, String(p)], sanitize(text));
  }

  get rowsUsed() { return this.#row; }

  toString() {
    if (!this.#rows.length) throw new PanelError('the panel has no rows');
    const text = ['PANEL1', ...this.#header.map(([k, v]) => `${k}\t${v}`), ...this.#rows].join('\n') + '\n';
    const bytes = Buffer.byteLength(text);
    if (bytes > LIMITS.PANEL_BYTES) throw new PanelError(`the panel is ${bytes} bytes; the limit is ${LIMITS.PANEL_BYTES}`);
    return text;
  }

  #head(key, value) {
    this.#header = this.#header.filter(([k]) => k !== key);
    this.#header.push([key, String(value)]);
    return this;
  }
  #body(height, fields, lastText) {
    if (this.#row + height > LIMITS.ROWS) throw new PanelError(`too many rows: a panel has ${LIMITS.ROWS}`);
    fields[1] = String(this.#row);
    const fixed = fields.join('\t') + '\t';
    const room = LIMITS.LINE_BYTES - 1 - Buffer.byteLength(fixed);   // -1: the newline
    this.#rows.push(fixed + cutBytes(lastText, room));
    this.#row += height;
    return this;
  }
}

function intIn(v, min, max, what) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new PanelError(`${what} must be an integer ${min}..${max}`);
  return n;
}
function epoch(when) {
  const s = when instanceof Date ? Math.floor(when.getTime() / 1000) : Math.floor(Number(when));
  if (!Number.isFinite(s) || s < 1 || s > 9_999_999_999) throw new PanelError(`not a valid time: ${when}`);
  return s;
}

/** An HTTP error from the device, with a readable hint. `status` 0 means no answer. */
export class DeviceError extends Error {
  constructor(status, body, host) {
    const hints = {
      0: `no answer from ${host} (wrong address, device off, or not on this network)`,
      401: 'wrong user or password (401)',
      403: 'missing or expired token (403): the device probably restarted',
      404: 'not available (404): the device is in rescue mode, or its firmware is older than this feature',
      409: 'a firmware update is in progress (409): try again later',
      507: 'not enough space in the device storage (507)',
    };
    let detail = '';
    try { detail = JSON.parse(body).error || ''; } catch { /* not JSON */ }
    super(hints[status] ?? `device answered HTTP ${status}${detail ? ': ' + detail : ''}`);
    this.status = status;
    this.body = body;
  }
  /** 404 and 409 are normal states (rescue mode, update running): retry later, do not crash. */
  get isTemporary() { return this.status === 0 || this.status === 404 || this.status === 409; }
}

export class SmallTV {
  #auth;
  #token = '';

  constructor({host, user = 'admin', password = '12345678'} = {}) {
    if (!host) throw new Error('no device address: pass --host HOST, set SMALLTV_HOST, or use SmallTV.locate() to discover it');
    this.host = String(host).replace(/^http:\/\//, '').replace(/\/$/, '');
    this.base = `http://${this.host}`;
    this.#auth = 'Basic ' + Buffer.from(`${user}:${password}`).toString('base64');
  }

  /**
   * Like fromEnv, but when no address is given (argument or SMALLTV_HOST) it asks the network with
   * discover(): one device answering -> that one (said on stderr); several -> error listing them; none -> error.
   * With `name` (or SMALLTV_NAME) only the devices called that way count (their label, set in the device web
   * page, or their host name smalltv-xxxxxx): two with the same name are an error, never "the first one".
   */
  static async locate(host, {log = msg => console.error(msg), name, ...discoverOpts} = {}) {
    const given = host || process.env.SMALLTV_HOST;
    if (given) return SmallTV.fromEnv(given);
    const wanted = name ?? process.env.SMALLTV_NAME ?? '';
    const all = await discover(discoverOpts);
    const found = wanted ? byName(all, wanted) : all;
    if (found.length === 1) {
      const d = found[0];
      log(`found ${d.label ? `"${d.label}" (${d.name})` : d.name} at ${d.ip} (firmware ${d.version}, ${d.mode} mode)`);
      return SmallTV.fromEnv(d.ip);
    }
    if (found.length === 0 && wanted && all.length)
      throw new Error(`no device is called "${wanted}" (a device in rescue mode answers without its name). These answered:\n` +
        all.map(formatDevice).join('\n'));
    if (found.length === 0) throw new Error(noDeviceMessage(discoverOpts));
    throw new Error((wanted ? `several devices are called "${wanted}"` : 'several devices answered') +
      '; choose one with --host (or SMALLTV_HOST):\n' + found.map(formatDevice).join('\n'));
  }

  static fromEnv(host) {
    return new SmallTV({
      host: host || process.env.SMALLTV_HOST,
      user: process.env.SMALLTV_USER || undefined,
      password: process.env.SMALLTV_PASSWORD || undefined,
    });
  }

  async #request(path, {method = 'GET', body, headers = {}, token = false, timeoutMs = REQUEST_TIMEOUT_MS} = {}) {
    const h = {Authorization: this.#auth, ...headers};
    if (token) h['X-Rescue-Token'] = this.#token;
    let res;
    try {
      res = await fetch(this.base + path, {method, body, headers: h, signal: AbortSignal.timeout(timeoutMs)});
    } catch {
      throw new DeviceError(0, '', this.host);
    }
    const text = await res.text();
    if (!res.ok) throw new DeviceError(res.status, text, this.host);
    try { return JSON.parse(text); } catch { return text; }
  }

  /** GET /api/status. Also refreshes the session token (it changes on every boot). */
  async status() {
    const s = await this.#request('/api/status');
    this.#token = s.token || '';
    return s;
  }

  /** GET /api/app/health: heap, loop time, clock, current screen, panel counters. App mode only. */
  health() { return this.#request('/api/app/health'); }

  /** POST with a fresh token; if the device restarted in between (403), read the token once more. */
  async #mutate(path, opts) {
    if (!this.#token) await this.status();
    try {
      return await this.#request(path, {...opts, method: 'POST', token: true});
    } catch (e) {
      if (!(e instanceof DeviceError) || e.status !== 403) throw e;
      await this.status();
      return this.#request(path, {...opts, method: 'POST', token: true});
    }
  }

  /** Volatile panel: shown right away, kept in memory only (never writes the flash). */
  sendPanel(panel) {
    return this.#mutate('/api/app/panel', {
      body: String(panel), headers: {'Content-Type': 'text/plain; charset=utf-8'},
    });
  }

  /** Stores a file in the device storage (replaces a file with the same name). */
  uploadFile(name, data, type = 'application/octet-stream') {
    if (!/^[A-Za-z0-9_-][A-Za-z0-9._-]{0,29}$/.test(name)) throw new Error(`invalid resource name: ${name}`);
    const bytes = typeof data === 'string' ? Buffer.from(data, 'utf8') : data;
    // Rebuilt on each attempt: a FormData body cannot be sent twice.
    const opts = {timeoutMs: uploadBudgetMs(bytes.length)};
    Object.defineProperty(opts, 'body', {enumerable: true, get() {
      const form = new FormData();
      form.append('file', new Blob([bytes], {type}), name);
      return form;
    }});
    return this.#mutate('/api/app/files', opts);
  }

  /** Persistent panel: stored as p-<slug>.jpp, survives restarts, rotates on the "panels" screen. */
  savePanel(slug, panel) {
    if (!/^[A-Za-z0-9_-]{1,23}$/.test(slug)) throw new Error('panel slug: letters, digits, - and _ (max 23)');
    return this.uploadFile(`p-${slug}.jpp`, String(panel), 'text/plain');
  }

  /** Changes settings, e.g. {brightness: 40}. All-or-nothing on the device side. */
  setSettings(values) {
    return this.#mutate('/api/app/settings', {
      body: new URLSearchParams(Object.entries(values).map(([k, v]) => [k, String(v)])),
    });
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Discovery. Any UDP datagram to port 7778 makes the device broadcast one line on port 7779, in both modes:
//   M 21:43:07 [HERE] smalltv-a1b2c3 mac=aa:bb:cc:dd:ee:ff ip=10.0.0.42 v=0.6.4 mode=app
// The mode is "app" or "rescue". Firmware 0.6.3 and older answer "[AQUI] ... modo=app|rescate"; both forms are
// accepted, and the mode is always reported as "app" or "rescue". The device reads nothing from the question and never answers the sender directly.
// Firmware 0.6.8 and newer may end the line with " name=<label>": the name the owner gave the device in its web page
// (settings key `name`, up to 15 ASCII characters, may contain spaces, never "="). Only in app mode and only if set.
// It is reported as `label` ("" when there is none). The identity is still the MAC: two devices may share a label.

/** Discovery defaults. Each one can be overridden by the environment variable in the comment. */
export const DISCOVERY = Object.freeze({
  ASK_PORT: 7778,          // SMALLTV_DISCOVERY_PORT: where the device listens
  REPLY_PORT: 7779,        // SMALLTV_DISCOVERY_REPLY_PORT: where it answers (broadcast)
  WAIT_MS: 2000,           // SMALLTV_DISCOVERY_WAIT (seconds): how long to listen for answers
  WAIT_MAX_MS: 30_000,
});
const DISCOVERY_LINE =
  /\[(?:HERE|AQUI)\]\s+(\S+)\s+mac=(\S+)\s+ip=([0-9.]+)\s+v=(\S+)\s+(?:mode|modo)=(\S+)(?:[ \t]+name=([ -~]+))?/;

function envNumber(name, fallback) {
  const v = process.env[name];
  if (v === undefined || v === '') return fallback;
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) throw new Error(`${name} must be a positive number`);
  return n;
}

/** Broadcast addresses to ask: the global one and the one of every IPv4 interface. */
async function broadcastAddresses() {
  const {networkInterfaces} = await import('node:os');
  const out = new Set(['255.255.255.255']);
  for (const list of Object.values(networkInterfaces())) {
    for (const n of list ?? []) {
      if (n.family !== 'IPv4' && n.family !== 4) continue;
      if (n.internal) continue;
      const ip = n.address.split('.').map(Number), mask = n.netmask.split('.').map(Number);
      out.add(ip.map((b, i) => (b | (~mask[i] & 255)) & 255).join('.'));
    }
  }
  return [...out];
}

/** Parses one discovery answer; null if the datagram is not one. Exported for tests. */
export function parseDiscovery(text) {
  const m = DISCOVERY_LINE.exec(String(text));
  if (!m) return null;
  const [, name, mac, ip, version, mode, label] = m;
  return {name, mac: mac.toLowerCase(), ip, version, mode: mode === 'rescate' ? 'rescue' : mode,
    label: (label ?? '').trim()};
}

/** One line per device, the same layout as the shell and PowerShell clients. */
export function formatDevice(d) {
  return `${d.ip.padEnd(16)} ${d.name.padEnd(16)} ${d.mac.padEnd(18)} v${d.version.padEnd(8)} ` +
    (d.label ? `${d.mode.padEnd(6)}  "${d.label}"` : d.mode);
}

/** The devices called `name`: their label or their host name (smalltv-xxxxxx), ignoring case. "" matches none. */
export function byName(found, name) {
  const n = String(name ?? '').trim().toLowerCase();
  if (!n) return [];
  return found.filter(d => d.label.toLowerCase() === n || d.name.toLowerCase() === n);
}

function noDeviceMessage({waitMs} = {}) {
  const s = ((waitMs ?? envNumber('SMALLTV_DISCOVERY_WAIT', DISCOVERY.WAIT_MS / 1000) * 1000) / 1000).toFixed(1);
  return `no device answered the discovery in ${s} s. It may be off, on another network, or running firmware ` +
    'without discovery (older than 0.5.23); some networks (guest Wi-Fi, "client isolation") block broadcasts. ' +
    'Pass the address with --host HOST or SMALLTV_HOST (the Status screen of the device shows it).';
}

/**
 * Asks the local network which devices are there. Resolves to [{name, mac, ip, version, mode, label}], one per MAC
 * (empty if nobody answered). Never throws for "nobody answered"; throws if the reply port cannot be opened.
 * Options (for tests and odd networks): addresses (array), askPort, replyPort, waitMs.
 */
export async function discover({addresses, askPort, replyPort, waitMs} = {}) {
  const dgram = await import('node:dgram');
  const ask = askPort ?? envNumber('SMALLTV_DISCOVERY_PORT', DISCOVERY.ASK_PORT);
  const reply = replyPort ?? envNumber('SMALLTV_DISCOVERY_REPLY_PORT', DISCOVERY.REPLY_PORT);
  const wait = Math.min(waitMs ?? envNumber('SMALLTV_DISCOVERY_WAIT', DISCOVERY.WAIT_MS / 1000) * 1000,
    DISCOVERY.WAIT_MAX_MS);
  const targets = addresses ?? (process.env.SMALLTV_DISCOVERY_ADDR
    ? process.env.SMALLTV_DISCOVERY_ADDR.split(',').map(s => s.trim()).filter(Boolean)
    : await broadcastAddresses());
  // reuseAddr: other tools may be listening on the reply port at the same time.
  const sock = dgram.createSocket({type: 'udp4', reuseAddr: true});
  const seen = new Map();
  sock.on('message', buf => {
    const d = parseDiscovery(buf.toString('utf8'));
    if (d) seen.set(d.mac, d);
  });
  await new Promise((resolve, reject) => {
    sock.once('error', reject);
    sock.bind(reply, () => { sock.off('error', reject); resolve(); });
  }).catch(e => { sock.close(); throw new Error(`cannot listen on UDP port ${reply} for discovery: ${e.message}`); });
  sock.on('error', () => {});      // a send error to one address must not end the whole search
  sock.setBroadcast(true);
  const question = Buffer.from('SMALLTV?\n');
  for (const t of targets) sock.send(question, ask, t, () => {});
  await new Promise(r => setTimeout(r, wait));
  sock.close();
  return [...seen.values()];
}

/** Tiny argument parser for the example apps: --name value, --name=value and --flag. */
export function parseArgs(argv, flags = []) {
  const out = {_: []};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { out._.push(a); continue; }
    const eq = a.indexOf('=');
    const key = a.slice(2, eq < 0 ? undefined : eq);
    if (eq >= 0) out[key] = a.slice(eq + 1);
    else if (flags.includes(key)) out[key] = true;
    else if (i + 1 < argv.length) out[key] = argv[++i];
    else throw new Error(`--${key} needs a value`);
  }
  return out;
}
