#!/bin/sh
# Install a firmware image (.bin) over Wi-Fi, the same way the device web page does.
#
#   sh update-firmware.sh [--host HOST] [--yes] [--no-wait] FIRMWARE.bin
#
#   --yes       do not ask for confirmation
#   --no-wait   do not wait for the device to come back after the restart
#
# DO NOT CUT THE POWER while the update runs or while the device restarts. The device checks the
# whole image (size, MD5, structure) before it replaces anything; a rejected or interrupted upload
# leaves the old firmware in place and you can simply try again.
#
# Works in both modes: normal (app) and rescue.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
YES=0; WAIT=1; BIN=""
for a in "$@"; do
  case "$a" in
    --yes) YES=1 ;; --no-wait) WAIT=0 ;; -h|--help) usage ;;
    -*) echo "unknown option: $a" >&2; usage ;;
    *) [ -z "$BIN" ] || usage; BIN=$a ;;
  esac
done
[ -n "$BIN" ] || usage
[ -f "$BIN" ] || die "file not found: $BIN"
need_curl; require_host

# 1. Is it a firmware image? ESP8266 images start with the byte 0xE9. A resource pack starts with JPR1.
MAGIC=$(head -c 4 "$BIN" | od -An -tx1 | tr -d ' \n')
case "$MAGIC" in
  e9*) ;;
  4a505231) die "$BIN is a resource pack (.res), not firmware: use upload-resources.sh" ;;
  *) die "$BIN is not an ESP8266 firmware image (it does not start with 0xE9)" ;;
esac
SIZE=$(file_size "$BIN")
MD5=$(file_md5 "$BIN")

# 2. Device state, token and the space it declares for a new image.
read_status
[ -n "$MAXFW" ] && [ "$SIZE" -gt "$MAXFW" ] && die "the image is $SIZE bytes; the device accepts at most $MAXFW"

echo "device:     $SMALLTV_HOST  (running $VERSION, $MODE mode)"
echo "firmware:   $(basename "$BIN")  $SIZE bytes  md5 $MD5"
echo
echo "Do NOT cut the power until the device is back (about a minute)."
if [ "$YES" != 1 ]; then
  printf 'Install it now? [y/N] '
  read -r ANSWER
  case "$ANSWER" in y|Y|yes|YES) ;; *) echo "cancelled, nothing was sent"; exit 1 ;; esac
fi

# 3. Upload. The device verifies size and MD5 before it touches the flash.
BUDGET=$(upload_budget "$SIZE")
echo "uploading (up to ${BUDGET}s)..."
OLD_TOKEN=$TOKEN
RESP=$(HTTP_MAX_S=$BUDGET http POST /update -H "X-Rescue-Token: $TOKEN" \
        -H "X-Firmware-Size: $SIZE" -H "X-Firmware-MD5: $MD5" \
        -F "firmware=@$BIN;type=application/octet-stream")
split_response
if [ "$CODE" = 000 ]; then
  echo "Contact was lost during the upload. The update has NOT been confirmed." >&2
  echo "Check the version with status.sh before trying again." >&2
  exit 3
fi
OK=$(printf '%s' "$BODY" | json_get ok)
if [ "$CODE" != 200 ] || [ "$OK" != true ]; then
  echo "rejected: $(explain_code "$CODE" "$BODY")" >&2
  echo "The old firmware is still installed. You can try again." >&2
  exit 3
fi
# The field is "warning" since firmware 0.6.4; 0.6.3 and older call it "aviso".
WARN=$(printf '%s' "$BODY" | json_get warning)
[ -n "$WARN" ] || WARN=$(printf '%s' "$BODY" | json_get aviso)
echo "image verified; the device is restarting."
[ -n "$WARN" ] && echo "WARNING from the device: $WARN"

[ "$WAIT" = 1 ] || exit 0

# 4. Wait for a NEW boot: the session token changes on every boot. 3 minutes is generous: the
# copy plus the restart usually take well under a minute.
echo "waiting for the device to come back..."
i=0
while [ $i -lt 90 ]; do
  sleep 2; i=$((i + 1))
  RESP=$(HTTP_MAX_S=3 http GET /api/status 2>/dev/null); split_response
  [ "$CODE" = 200 ] || continue
  T=$(printf '%s' "$BODY" | json_get token)
  [ -n "$T" ] && [ "$T" != "$OLD_TOKEN" ] || continue
  echo "back: firmware $(printf '%s' "$BODY" | json_get version), $(printf '%s' "$BODY" | json_get mode) mode"
  exit 0
done
echo "the device has not answered after 3 minutes. If it changed network address, find it again;" >&2
echo "if it does not come back at all, see the recovery guide (rescue mode)." >&2
exit 4
