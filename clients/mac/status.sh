#!/bin/sh
# Show what the device is running: version, mode, address, network, memory and uptime.
#
#   sh status.sh [--host HOST] [--json]
#
#   --json   print the raw answers of /api/status and /api/app/health instead of the summary
#
# Read-only: it changes nothing on the device. The session token is never printed.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
RAW=0
for a in "$@"; do
  case "$a" in --json) RAW=1 ;; -h|--help) usage ;; *) echo "unknown argument: $a" >&2; usage ;; esac
done
need_curl; require_host
read_status

if [ "$RAW" = 1 ]; then
  printf '%s\n' "$STATUS" | sed -E 's/"token":"[^"]*"/"token":"<hidden>"/'
else
  g() { printf '%s' "$STATUS" | json_get "$1"; }
  echo "device:        $SMALLTV_HOST"
  echo "firmware:      $VERSION"
  echo "mode:          $MODE$( [ "$MODE" = rescue ] && echo '  (rescue: only the web page and firmware updates work)')"
  echo "state:         $(g state)"
  echo "network:       $(g ssid)   ip $(g ip)"
  echo "access point:  $(g ap)"
  echo "last reset:    $(g resetReason)"
  echo "uptime:        $(g uptime) s"
  echo "max firmware:  $MAXFW bytes"
fi

# Application health: only exists in app mode.
[ "$MODE" = app ] || exit 0
RESP=$(http GET /api/app/health); split_response
if [ "$CODE" != 200 ]; then
  echo "health:        $(explain_code "$CODE" "$BODY")"
  exit 0
fi
if [ "$RAW" = 1 ]; then
  printf '%s\n' "$BODY"
else
  h() { printf '%s' "$BODY" | json_get "$1"; }
  echo "free heap:     $(h heap) bytes   (lowest seen $(h heapMin), largest block $(h maxBlock))"
  echo "slowest loop:  $(h tickMax) ms"
  echo "clock synced:  $(h ntp)"
  echo "on screen:     $(h screen)"
fi
