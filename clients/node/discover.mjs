#!/usr/bin/env node
// discover.mjs - find the SmallTV devices on this network (UDP 7778 -> answer on 7779).
//
//   node discover.mjs [--wait SECONDS] [--ip] [--json]
//
//   --wait N   listen N seconds for answers (default 2)
//   --ip       print only the address of the first device (handy in scripts)
//   --json     print the list as JSON
//
// Exit code 0 if at least one device answered, 1 if none. Works in rescue mode too.
import {discover, formatDevice, parseArgs} from './smalltv.mjs';

async function main() {
  const a = parseArgs(process.argv.slice(2), ['ip', 'json', 'help']);
  if (a.help) { console.log('usage: node discover.mjs [--wait SECONDS] [--ip] [--json]'); return 0; }
  const wait = a.wait === undefined ? undefined : Number(a.wait);
  if (wait !== undefined && !(wait > 0 && wait <= 30)) throw new Error('--wait must be between 0 and 30 seconds');
  const found = await discover(wait === undefined ? {} : {waitMs: wait * 1000});
  if (a.json) console.log(JSON.stringify(found, null, 2));
  else if (a.ip) { if (found.length) console.log(found[0].ip); }
  else for (const d of found) console.log(formatDevice(d));
  if (!found.length && !a.ip) console.error('no device answered. It may be off, on another network, or running ' +
    'firmware without discovery; guest networks often block broadcasts.');
  return found.length ? 0 : 1;
}

main().then(code => process.exit(code), e => { console.error(`error: ${e.message}`); process.exit(2); });
