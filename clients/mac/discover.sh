#!/bin/sh
# Find the SmallTV devices on this network: one line per device (address, name, MAC, firmware, mode).
#
#   sh discover.sh [--wait SECONDS] [--name NAME] [--ip]
#
#   --wait N     listen N seconds for answers (default 2)
#   --name NAME  only the device(s) called NAME (the name set in its web page, or its host name smalltv-xxxxxx)
#   --ip         print only the address of the first device, e.g.  export SMALLTV_HOST=$(sh discover.sh --ip)
#                With --name, two devices with that name are an error (exit 1) instead of "the first one".
#
# The device answers in rescue mode too (without its name). Exit code 0 if at least one device answered, 1 if none.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
ONLY_IP=0
NAME=
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) [ $# -ge 2 ] || usage; SMALLTV_DISCOVERY_WAIT=$2; shift 2 ;;
    --ip) ONLY_IP=1; shift ;;
    --name) [ $# -ge 2 ] || usage; NAME=$2; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
case "${SMALLTV_DISCOVERY_WAIT:-2}" in ''|*[!0-9.]*) die "--wait must be a number of seconds" ;; esac

FOUND=$(discover_devices) || exit 2
if [ -n "$NAME" ]; then
  ALL=$FOUND
  FOUND=$(printf '%s\n' "$ALL" | filter_by_name "$NAME")
  if [ -z "$FOUND" ] && [ -n "$ALL" ]; then echo "no device is called \"$NAME\"." >&2; exit 1; fi
  if [ "$ONLY_IP" = 1 ] && [ "$(printf '%s\n' "$FOUND" | grep -c .)" -gt 1 ]; then
    echo "several devices are called \"$NAME\"; choose one by its address:" >&2
    printf '%s\n' "$FOUND" | format_devices >&2
    exit 1
  fi
fi
if [ -z "$FOUND" ]; then
  [ "$ONLY_IP" = 1 ] || echo "no device answered. It may be off, on another network, or running firmware without \
discovery; guest networks often block broadcasts." >&2
  exit 1
fi
if [ "$ONLY_IP" = 1 ]; then printf '%s\n' "$FOUND" | head -n 1 | cut -f 1
else printf '%s\n' "$FOUND" | format_devices; fi
