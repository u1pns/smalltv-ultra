#!/bin/sh
# List, download or delete files in the device storage.
#
#   sh files.sh [--host HOST] list
#   sh files.sh [--host HOST] get NAME [OUTPUT]
#   sh files.sh [--host HOST] delete NAME
#
# To upload, use upload-resources.sh. Formatting the storage is only offered in the device web page,
# on purpose: it deletes fonts, icons and photos at once.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
[ $# -ge 1 ] || usage
ACTION=$1; shift
case "$ACTION" in
  list) [ $# -eq 0 ] || usage ;;
  get) [ $# -ge 1 ] && [ $# -le 2 ] || usage ;;
  delete) [ $# -eq 1 ] || usage ;;
  *) usage ;;
esac
[ "$ACTION" = list ] || valid_resource_name "$1" || die "invalid name: $1"
need_curl; require_host
read_status
require_app_mode

case "$ACTION" in
  list)
    RESP=$(http GET /api/app/files); split_response
    [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
    MOUNTED=$(printf '%s' "$BODY" | json_get mounted)
    [ -n "$MOUNTED" ] || die "unexpected answer from the device: no 'mounted' field (firmware older than 0.6.0?)"
    [ "$MOUNTED" = false ] && { echo "storage not formatted"; exit 0; }
    printf '%s' "$BODY" | grep -q '"files":\[' || die "unexpected answer from the device: no 'files' list"
    printf '%s' "$BODY" | grep -o '"name":"[^"]*","bytes":[0-9]*' \
      | sed -E 's/"name":"([^"]*)","bytes":([0-9]*)/\2 \1/' | awk '{ printf "%10d  %s\n", $1, $2 }'
    echo "used $(printf '%s' "$BODY" | json_get used) of $(printf '%s' "$BODY" | json_get total) bytes"
    [ "$(printf '%s' "$BODY" | json_get truncated)" = true ] && echo "(list truncated by the device: more files exist)"
    ;;
  get)
    OUT=${2:-$1}
    [ ! -e "$OUT" ] || die "$OUT already exists"
    CODE=$(curl -s -m "$(upload_budget 2097152)" -u "$SMALLTV_USER:$SMALLTV_PASSWORD" -o "$OUT" \
           -w '%{http_code}' "$BASE/api/app/files/get?name=$1")
    [ "$CODE" = 200 ] || { rm -f "$OUT"; die "$(explain_code "$CODE" "")"; }
    echo "saved $OUT ($(file_size "$OUT") bytes)"
    ;;
  delete)
    post_token "/api/app/files/delete?name=$1"
    [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
    echo "deleted $1"
    ;;
esac
