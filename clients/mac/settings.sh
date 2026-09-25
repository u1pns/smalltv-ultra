#!/bin/sh
# Read or change the device settings.
#
#   sh settings.sh [--host HOST]                      print all settings (JSON)
#   sh settings.sh [--host HOST] KEY=VALUE [...]      change one or more settings
#
# Common keys:
#   brightness=0..100      screen brightness
#   screens=LIST           screens that rotate, comma separated: clock, weather, forecast, status,
#                          album, panels
#   rotate_s=5..3600       seconds per screen
#   tz=POSIX-TZ            time zone, e.g. CET-1CEST,M3.5.0,M10.5.0/3 or EST5EDT,M3.2.0,M11.1.0
#   h12=0|1                12-hour clock
#   night=0|1  night_start=0..23  night_end=0..23  night_brightness=0..100    night dimming
#   city=NAME  lat=..  lon=..  temp=C|F  wind=kmh|ms|mph                weather
#   log_udp=0|1            debug log over UDP port 7777 (off by default)
#
# Changes are all-or-nothing: if one value is rejected, nothing is saved and the device says which key.
# Examples:
#   sh settings.sh brightness=40
#   sh settings.sh screens=clock,weather,panels rotate_s=20
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
for a in "$@"; do
  case "$a" in -h|--help) usage ;; *=*) ;; *) echo "expected KEY=VALUE, got: $a" >&2; usage ;; esac
done
need_curl; require_host
read_status
require_app_mode

if [ $# -eq 0 ]; then
  RESP=$(http GET /api/app/settings); split_response
  [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
  printf '%s\n' "$BODY" | awk '{ gsub(/,"/, ",\n\""); print }'
  exit 0
fi

ARGS=""
for a in "$@"; do ARGS="$ARGS --data-urlencode $(quote "$a")"; done
eval "post_token /api/app/settings $ARGS"
if [ "$CODE" != 200 ]; then
  KEY=$(printf '%s' "$BODY" | json_get key)
  die "$(explain_code "$CODE" "$BODY")${KEY:+ (key: $KEY)}. Nothing was changed."
fi
echo "saved: $*"
