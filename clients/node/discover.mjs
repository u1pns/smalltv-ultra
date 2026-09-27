#!/usr/bin/env node
// discover.mjs - find the SmallTV devices on this network (UDP 7778 -> answer on 7779).
//
//   node discover.mjs [--wait SECONDS] [--name NAME] [--ip] [--json]
//
//   --wait N     listen N seconds for answers (default 2)
//   --name NAME  only the device(s) called NAME: the name set in the device web page (firmware 0.6.8+), or the
//                host name smalltv-xxxxxx; case does not matter. In rescue mode a device answers without its name.
//   --ip         print only the address of the first device (handy in scripts). With --name, two devices with
//                that name are an error (exit 1) instead of "the first one"
//   --json       print the list as JSON (each device has "label": its name, or "" if it has none)
//
// Exit code 0 if at least one device answered, 1 if none. Works in rescue mode too.
import {byName, discover, formatDevice, parseArgs} from './smalltv.mjs';

async function main() {
  const a = parseArgs(process.argv.slice(2), ['ip', 'json', 'help']);
  if (a.help) { console.log('usage: node discover.mjs [--wait SECONDS] [--name NAME] [--ip] [--json]'); return 0; }
  const wait = a.wait === undefined ? undefined : Number(a.wait);
  if (wait !== undefined && !(wait > 0 && wait <= 30)) throw new Error('--wait must be between 0 and 30 seconds');
  const all = await discover(wait === undefined ? {} : {waitMs: wait * 1000});
  const found = a.name === undefined ? all : byName(all, a.name);
  if (a.name !== undefined && a.ip && found.length > 1) {
    console.error(`several devices are called "${a.name}"; choose one by its address:`);
    for (const d of found) console.error(formatDevice(d));
    return 1;
  }
  if (a.json) console.log(JSON.stringify(found, null, 2));
  else if (a.ip) { if (found.length) console.log(found[0].ip); }
  else for (const d of found) console.log(formatDevice(d));
  if (!found.length && a.name !== undefined && all.length) console.error(`no device is called "${a.name}".`);
  else if (!found.length && !a.ip) console.error('no device answered. It may be off, on another network, or running ' +
    'firmware without discovery; guest networks often block broadcasts.');
  return found.length ? 0 : 1;
}

main().then(code => process.exit(code), e => { console.error(`error: ${e.message}`); process.exit(2); });
