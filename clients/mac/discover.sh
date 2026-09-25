#!/bin/sh
# Find the SmallTV devices on this network: one line per device (address, name, MAC, firmware, mode).
#
#   sh discover.sh [--wait SECONDS] [--ip]
#
#   --wait N   listen N seconds for answers (default 2)
#   --ip       print only the address of the first device, e.g.  export SMALLTV_HOST=$(sh discover.sh --ip)
#
# The device answers in rescue mode too. Exit code 0 if at least one device answered, 1 if none.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
ONLY_IP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) [ $# -ge 2 ] || usage; SMALLTV_DISCOVERY_WAIT=$2; shift 2 ;;
    --ip) ONLY_IP=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
case "${SMALLTV_DISCOVERY_WAIT:-2}" in ''|*[!0-9.]*) die "--wait must be a number of seconds" ;; esac

FOUND=$(discover_devices) || exit 2
if [ -z "$FOUND" ]; then
  [ "$ONLY_IP" = 1 ] || echo "no device answered. It may be off, on another network, or running firmware without \
discovery; guest networks often block broadcasts." >&2
  exit 1
fi
if [ "$ONLY_IP" = 1 ]; then printf '%s\n' "$FOUND" | head -n 1 | cut -f 1
else printf '%s\n' "$FOUND" | format_devices; fi
