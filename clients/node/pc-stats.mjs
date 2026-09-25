#!/usr/bin/env node
// pc-stats.mjs - show this computer's CPU, memory and disk use on the SmallTV.
//
//   node pc-stats.mjs [--host HOST] [--every 30] [--seconds 10] [--name "My PC"] [--once] [--dry-run] [--out FILE]
//
//   --every N     send a fresh panel every N seconds (default 30, minimum 5)
//   --seconds N   how long it stays on screen each time, 5..120 (default 10)
//   --name TEXT   title of the panel (default: this computer's host name)
//   --once        send one panel and exit
//   --dry-run     print the panel instead of sending it (no device needed)
//   --out FILE    write the panel to FILE instead of sending it (no device needed)
//
// It uses the VOLATILE panel channel: the panel lives in the device memory and never writes its flash,
// so a short interval is fine. Each panel jumps to the front for --seconds and then the normal rotation
// continues. With --every equal to --seconds the device shows only this panel while the script runs.
//
// Works on macOS, Windows and Linux (only Node's `os` module). Stop it with Ctrl+C.
import os from 'node:os';
import fs from 'node:fs';
import {SmallTV, Panel, parseArgs, DeviceError} from './smalltv.mjs';

const EVERY_DEFAULT_S = 30;
const EVERY_MIN_S = 5;           // the shortest time a panel can stay on screen: sending faster is pointless
const SECONDS_DEFAULT = 10;
const CPU_SAMPLE_MS = 1000;      // CPU use is measured over this window when there is no previous sample

function cpuTimes() {
  let idle = 0, total = 0;
  for (const c of os.cpus()) {
    const t = c.times;
    idle += t.idle;
    total += t.user + t.nice + t.sys + t.irq + t.idle;
  }
  return {idle, total};
}

let previous = null;
async function cpuPercent() {
  if (!previous) { previous = cpuTimes(); await new Promise(r => setTimeout(r, CPU_SAMPLE_MS)); }
  const now = cpuTimes();
  const total = now.total - previous.total, idle = now.idle - previous.idle;
  previous = now;
  return total > 0 ? Math.round(100 * (1 - idle / total)) : 0;
}

/** Used share of the disk that holds `path` (the system disk by default), or null if Node cannot tell. */
function diskUse(path = os.platform() === 'win32' ? 'C:\\' : '/') {
  try {
    const s = fs.statfsSync(path);          // Node 18.15+
    const total = s.blocks * s.bsize, free = s.bavail * s.bsize;
    return total > 0 ? {used: total - free, total} : null;
  } catch { return null; }
}

function gib(bytes) { return (bytes / 1024 ** 3).toFixed(1); }

function uptimeText(s) {
  const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
  return d ? `${d}d ${h}h` : `${h}h ${m}m`;
}

async function buildPanel({name, seconds}) {
  const cpu = await cpuPercent();
  const total = os.totalmem(), used = total - os.freemem();
  const mem = Math.round(100 * used / total);
  const panel = new Panel().title(name).seconds(seconds)
    .keyValue('CPU', `${cpu} %`)
    .bar(cpu, `${os.cpus().length} cores`)
    .keyValue('Memory', `${mem} %`)
    .bar(mem, `${gib(used)} of ${gib(total)} GB`);
  const disk = diskUse();
  if (disk) {
    const pct = Math.round(100 * disk.used / disk.total);
    panel.keyValue('Disk', `${pct} %`).bar(pct, `${Math.round(disk.total / 1024 ** 3 - disk.used / 1024 ** 3)} GB free`);
  }
  panel.keyValue('Uptime', uptimeText(os.uptime()));
  // Load average is meaningful on macOS and Linux; Windows always reports zeros. Only if a row is left.
  if (os.platform() !== 'win32' && panel.rowsUsed < 8) panel.keyValue('Load', os.loadavg().map(n => n.toFixed(2)).join(' '));
  return panel;
}

async function main() {
  const a = parseArgs(process.argv.slice(2), ['once', 'dry-run', 'help']);
  if (a.help) { console.log('usage: node pc-stats.mjs [--host HOST] [--every 30] [--seconds 10] [--name TEXT] [--once] [--dry-run] [--out FILE]'); return; }
  const every = Number(a.every ?? EVERY_DEFAULT_S);
  if (!Number.isFinite(every) || every < EVERY_MIN_S) throw new Error(`--every must be at least ${EVERY_MIN_S} seconds`);
  const opts = {name: a.name || os.hostname().split('.')[0], seconds: Number(a.seconds ?? SECONDS_DEFAULT)};

  if (a['dry-run']) { process.stdout.write(String(await buildPanel(opts))); return; }
  if (a.out) { fs.writeFileSync(a.out, String(await buildPanel(opts))); console.log(`written to ${a.out}`); return; }
  const tv = await SmallTV.locate(a.host);
  const s = await tv.status();
  if (s.mode !== 'app') throw new Error(`the device is in '${s.mode}' mode: panels only work in normal (app) mode`);

  for (;;) {
    try {
      const r = await tv.sendPanel(await buildPanel(opts));
      console.log(`${new Date().toLocaleTimeString()} sent (${r.rows} rows${r.invalid ? `, ${r.invalid} discarded by the device` : ''})`);
    } catch (e) {
      if (!(e instanceof DeviceError) || !e.isTemporary) throw e;
      console.log(`${new Date().toLocaleTimeString()} skipped: ${e.message}`);   // rescue mode, update, or offline
    }
    if (a.once) return;
    await new Promise(r => setTimeout(r, every * 1000));
  }
}

main().catch(e => { console.error(`error: ${e.message}`); process.exit(1); });
