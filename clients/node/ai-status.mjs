#!/usr/bin/env node
// ai-status.mjs - show what your AI coding agent is doing (working, idle, waiting for you) on the SmallTV.
//
//   node ai-status.mjs [--host HOST] [--file FILE] [--watch] [--seconds 15] [--every 120] [--dry-run] [--out FILE]
//   node ai-status.mjs --set working|idle|waiting [--task TEXT] [--agent NAME] [--from-hook] [--file FILE]
//
// Two halves, joined by a small JSON file (default ~/.smalltv/ai-status.json, or SMALLTV_AI_STATUS_FILE):
//
//   {"agent": "Claude Code", "state": "working", "task": "my-project", "updated": 1790000000}
//
//   state    "working" | "idle" | "waiting" (waiting = the agent needs you: a question or a permission)
//   updated  epoch seconds (an ISO date is accepted too)
//
// --set writes that file (atomically) and exits: call it from your agent's hooks. Without --set the program
// reads the file and sends a VOLATILE panel: it lives in the device memory and never writes the flash, so it can
// be refreshed as often as you like. No credentials and no network access other than the device.
//
//   --watch        keep running: send a panel whenever the file changes, and repeat it every --every seconds
//                  while the state is "working" or "waiting" (so it comes back in the screen rotation)
//   --seconds N    time on screen each time, 5..120 (default 15)
//   --every N      repeat interval with --watch, at least 5 seconds (default 120)
//   --stale-min N  after N minutes without an update the panel says so (default 30)
//   --from-hook    with --set: read the hook's JSON from stdin and use the project folder name as the task
//                  (or, for a notification, its message)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {SmallTV, Panel, parseArgs, DeviceError} from './smalltv.mjs';

const STATES = ['working', 'idle', 'waiting'];
const SECONDS_DEFAULT = 15;
const EVERY_DEFAULT_S = 120;
const EVERY_MIN_S = 5;             // the shortest time a panel can stay on screen
const STALE_MIN_DEFAULT = 30;
const POLL_MS = 2000;              // how often --watch looks at the file
const FILE_MAX_BYTES = 4096;       // the status file is tiny; anything bigger is not ours
const TASK_MAX_CHARS = 120;        // kept in the file; the panel shows what fits
const WIDTH = 28;                  // characters per normal row
const TASK_ROWS = 3;

export function defaultFile() {
  return process.env.SMALLTV_AI_STATUS_FILE || path.join(os.homedir(), '.smalltv', 'ai-status.json');
}

/** Reads and validates the status file. Returns {agent, state, task, updated} or throws a readable error. */
export function readStatus(file) {
  const st = fs.statSync(file);
  if (st.size > FILE_MAX_BYTES) throw new Error(`${file} is larger than ${FILE_MAX_BYTES} bytes`);
  let j;
  try { j = JSON.parse(fs.readFileSync(file, 'utf8')); } catch { throw new Error(`${file} is not valid JSON`); }
  if (!j || typeof j !== 'object' || Array.isArray(j)) throw new Error(`${file} must hold a JSON object`);
  if (!STATES.includes(j.state)) throw new Error(`"state" must be one of ${STATES.join(', ')}`);
  const updated = typeof j.updated === 'number' ? j.updated : Date.parse(j.updated) / 1000;
  return {
    agent: typeof j.agent === 'string' && j.agent.trim() ? j.agent.trim() : 'AI agent',
    state: j.state,
    task: typeof j.task === 'string' ? j.task.trim().slice(0, TASK_MAX_CHARS) : '',
    updated: Number.isFinite(updated) ? Math.floor(updated) : Math.floor(st.mtimeMs / 1000),
  };
}

/** Writes the status file atomically (temporary file + rename), creating its folder if needed. */
export function writeStatus(file, status) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(status) + '\n');
  fs.renameSync(tmp, file);
}

function wrap(text, width, rows) {
  const out = [];
  let line = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    const w = [...word].length > width ? [...word].slice(0, width).join('') : word;
    if (!line) line = w;
    else if ([...line].length + 1 + [...w].length <= width) line += ' ' + w;
    else { out.push(line); line = w; }
    if (out.length === rows) break;
  }
  if (line && out.length < rows) out.push(line);
  return out;
}

function ago(seconds) {
  if (seconds < 90) return `${Math.max(0, seconds)} s`;
  if (seconds < 5400) return `${Math.round(seconds / 60)} min`;
  if (seconds < 172_800) return `${Math.round(seconds / 3600)} h`;
  return `${Math.round(seconds / 86_400)} days`;
}

export function buildPanel(s, {seconds = SECONDS_DEFAULT, staleMin = STALE_MIN_DEFAULT, nowS = Date.now() / 1000} = {}) {
  const age = Math.floor(nowS - s.updated);
  const stale = age > staleMin * 60;
  const panel = new Panel().title(s.agent).seconds(seconds);
  if (s.state === 'waiting' && !stale) panel.alert('first');    // a flash the first time, not on every repeat
  const word = {working: 'Working', idle: 'Idle', waiting: 'Needs you'}[s.state];
  panel.big(stale ? `${word}?` : word, stale ? 'normal' : s.state === 'waiting' ? 'alert' : s.state === 'working' ? 'accent' : 'normal');
  for (const row of wrap(s.task, WIDTH, TASK_ROWS)) panel.line(row);
  panel.keyValue(stale ? 'No update for' : 'Updated', `${ago(age)}${stale ? '' : ' ago'}`);
  return panel;
}

async function setStatus(a) {
  if (!STATES.includes(a.set)) throw new Error(`--set must be one of ${STATES.join(', ')}`);
  let task = typeof a.task === 'string' ? a.task : '';
  if (a['from-hook']) {
    // Claude Code passes the hook's details as JSON on stdin (cwd, and for notifications a message).
    let hook = {};
    try { hook = JSON.parse(fs.readFileSync(0, 'utf8') || '{}'); } catch { hook = {}; }
    if (!task && a.set === 'waiting' && typeof hook.message === 'string') task = hook.message;
    if (!task && typeof hook.cwd === 'string') task = path.basename(hook.cwd);
  }
  writeStatus(a.file, {
    agent: typeof a.agent === 'string' ? a.agent : 'Claude Code',
    state: a.set, task: task.slice(0, TASK_MAX_CHARS), updated: Math.floor(Date.now() / 1000),
  });
}

async function main() {
  const a = parseArgs(process.argv.slice(2), ['watch', 'dry-run', 'from-hook', 'help']);
  if (a.help) {
    console.log('usage: node ai-status.mjs [--host HOST] [--file FILE] [--watch] [--seconds 15] [--every 120] ' +
                '[--stale-min 30] [--dry-run] [--out FILE]\n' +
                '       node ai-status.mjs --set working|idle|waiting [--task TEXT] [--agent NAME] [--from-hook] [--file FILE]');
    return;
  }
  a.file = a.file || defaultFile();
  if (a.set !== undefined) return setStatus(a);

  const seconds = Number(a.seconds ?? SECONDS_DEFAULT);
  const every = Number(a.every ?? EVERY_DEFAULT_S);
  const staleMin = Number(a['stale-min'] ?? STALE_MIN_DEFAULT);
  if (!Number.isFinite(every) || every < EVERY_MIN_S) throw new Error(`--every must be at least ${EVERY_MIN_S} seconds`);
  if (!Number.isFinite(staleMin) || staleMin <= 0) throw new Error('--stale-min must be a positive number');
  const make = () => buildPanel(readStatus(a.file), {seconds, staleMin});

  if (a['dry-run']) { process.stdout.write(String(make())); return; }
  if (a.out) { fs.writeFileSync(a.out, String(make())); console.log(`written to ${a.out}`); return; }

  const tv = await SmallTV.locate(a.host);
  const send = async why => {
    try {
      const s = readStatus(a.file);
      await tv.sendPanel(buildPanel(s, {seconds, staleMin}));
      console.log(`${new Date().toLocaleTimeString()} sent: ${s.state} (${why})`);
      return s;
    } catch (e) {
      if (!a.watch || (e instanceof DeviceError && !e.isTemporary)) throw e;
      console.log(`${new Date().toLocaleTimeString()} skipped: ${e.message}`);
      return null;
    }
  };
  let last = await send('start');
  if (!a.watch) return;

  let lastMtime = fs.existsSync(a.file) ? fs.statSync(a.file).mtimeMs : 0;
  let lastSent = Date.now();
  for (;;) {
    await new Promise(r => setTimeout(r, POLL_MS));
    const m = fs.existsSync(a.file) ? fs.statSync(a.file).mtimeMs : 0;
    if (m !== lastMtime) { lastMtime = m; last = await send('changed'); lastSent = Date.now(); continue; }
    if (last && last.state !== 'idle' && Date.now() - lastSent >= every * 1000) { last = await send('repeat'); lastSent = Date.now(); }
  }
}

if (process.argv[1]?.endsWith('ai-status.mjs')) {
  main().catch(e => { console.error(`error: ${e.message}`); process.exit(1); });
}
