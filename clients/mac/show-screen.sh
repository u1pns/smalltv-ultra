#!/bin/sh
# Jump to a screen right now.
#
#   sh show-screen.sh [--host HOST] SCREEN
#
# SCREEN is one of:
#   clock, weather, forecast, status, album, panels
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
[ $# -eq 1 ] || usage
case "$1" in clock|weather|forecast|status|album|panels) ;; *) usage ;; esac
need_curl; require_host
read_status
require_app_mode
post_token "/api/app/show?screen=$1"
[ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
echo "showing: $1"
