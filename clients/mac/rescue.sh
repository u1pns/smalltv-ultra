#!/bin/sh
# Enter or leave rescue mode without cutting the power.
#
#   sh rescue.sh [--host HOST] enter     restart into rescue mode (only the web page and updates run)
#   sh rescue.sh [--host HOST] exit      leave rescue mode and restart into the normal app
#
# If the device does not answer at all, use the power-cut gesture instead (see the recovery guide).
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
[ $# -eq 1 ] || usage
case "$1" in enter|exit) ;; *) usage ;; esac
need_curl; require_host
read_status
if [ "$1" = enter ] && [ "$MODE" = rescue ]; then echo "already in rescue mode"; exit 0; fi
if [ "$1" = exit ] && [ "$MODE" != rescue ]; then echo "not in rescue mode (mode: $MODE)"; exit 0; fi
post_token "/api/rescue/$1"
case "$CODE" in 200|202) ;; *) die "$(explain_code "$CODE" "$BODY")" ;; esac
echo "accepted: the device is restarting. Give it about 30 seconds."
[ "$1" = enter ] && echo "If it cannot join your network in rescue mode, connect to its own Wi-Fi (SmallTV-Setup-...): see the recovery guide."
exit 0
