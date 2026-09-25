#!/bin/sh
# Upload resources to the device storage: a resource pack (.res) or single files.
#
#   sh upload-resources.sh [--host HOST] [--force] FILE [FILE...]
#
#   FILE      a resource pack (.res: fonts, icons...) or any single resource file
#             (fonts .jpf, icons .jpi, converted images .jpb, panels .jpp)
#   --force   upload even the files that are already on the device with the same size
#
# A pack ADDS and REPLACES files by name: your photos and panels stay where they are. Files already
# present with the same size are skipped, so an interrupted run can simply be started again.
# Only works in normal (app) mode. The device never decodes JPG/PNG/GIF: convert photos first
# with the album page of the device web (/api/app/album).
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
parse_common "$@"; eval "set -- $SMALLTV_REST"
FORCE=0
for a in "$@"; do case "$a" in --force) FORCE=1 ;; -h|--help) usage ;; esac; done
FILES=""
for a in "$@"; do
  case "$a" in --force|-h|--help) ;; -*) echo "unknown option: $a" >&2; usage ;;
    *) [ -f "$a" ] || die "file not found: $a"; FILES="$FILES $(quote "$a")" ;; esac
done
[ -n "$FILES" ] || usage
need_curl; require_host

WORK=$(mktemp -d "${TMPDIR:-/tmp}/smalltv-res.XXXXXX") || die "cannot create a temporary folder"
trap 'rm -rf "$WORK"' EXIT INT TERM
: > "$WORK/queue"      # lines: <path>\t<name>

# ver_lt A B: true if version A (X.Y.Z) is older than B.
ver_lt() {
  _a=$(printf '%s' "$1" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  [ "$_a" = "$2" ] && return 1
  _first=$(printf '%s\n%s\n' "$_a" "$2" | sort -t . -k1,1n -k2,2n -k3,3n | head -n 1)
  [ "$_first" = "$_a" ]
}

# unpack_res FILE: extracts a JPR1 pack into $WORK and appends its files to the queue.
# Layout: "JPR1\n" + one line of JSON manifest + "\n\n" + the files, raw, in manifest order.
unpack_res() {
  _f=$1
  [ "$(head -n 1 "$_f")" = JPR1 ] || die "$_f is not a resource pack"
  _manifest=$(sed -n 2p "$_f")
  [ -z "$(sed -n 3p "$_f")" ] || die "$_f: broken pack header"
  PACK_MIN=$(printf '%s' "$_manifest" | json_get minimo)
  _hdr=$(( $(head -n 2 "$_f" | wc -c) + 1 ))
  printf '%s' "$_manifest" | grep -o '{"nombre":"[^"]*","bytes":[0-9]*,"md5":"[0-9a-f]*"}' > "$WORK/entries"
  _declared=$(printf '%s' "$_manifest" | grep -o '"nombre":' | wc -l | tr -d ' ')
  _parsed=$(wc -l < "$WORK/entries" | tr -d ' ')
  [ "$_parsed" -gt 0 ] && [ "$_parsed" = "$_declared" ] || die "$_f: unreadable manifest"
  _off=$_hdr; _total=0
  mkdir -p "$WORK/pack"
  while IFS= read -r _e; do
    _n=$(printf '%s' "$_e" | json_get nombre); _b=$(printf '%s' "$_e" | json_get bytes); _m=$(printf '%s' "$_e" | json_get md5)
    valid_resource_name "$_n" || die "$_f: invalid file name in the pack: $_n"
    tail -c +$(( _off + 1 )) "$_f" | head -c "$_b" > "$WORK/pack/$_n"
    [ "$(file_size "$WORK/pack/$_n")" = "$_b" ] || die "$_f: the pack is cut short (at $_n)"
    [ -z "$_m" ] || [ "$(file_md5 "$WORK/pack/$_n")" = "$_m" ] || die "$_f: $_n is corrupted (MD5 mismatch)"
    printf '%s\t%s\n' "$WORK/pack/$_n" "$_n" >> "$WORK/queue"
    _off=$(( _off + _b )); _total=$(( _total + _b ))
  done < "$WORK/entries"
  [ "$_off" = "$(file_size "$_f")" ] || die "$_f: size mismatch (pack is cut or has extra data)"
  echo "pack $(basename "$_f"): $_parsed files, $_total bytes, for firmware $PACK_MIN or later"
}

PACK_MIN=""
eval "set -- $FILES"
for f in "$@"; do
  if [ "$(head -c 4 "$f")" = JPR1 ]; then
    unpack_res "$f"
  else
    n=$(basename "$f")
    valid_resource_name "$n" || die "invalid resource name '$n': letters, digits, dot, dash, underscore; max 30"
    case "$n" in *.jpg|*.jpeg|*.png|*.gif|*.webp|*.heic|*.bmp|*.JPG|*.JPEG|*.PNG|*.GIF)
      die "$n is a normal image: the device cannot show it. Convert it with the album page first" ;; esac
    printf '%s\t%s\n' "$f" "$n" >> "$WORK/queue"
  fi
done

read_status
require_app_mode
if [ -n "$PACK_MIN" ] && ver_lt "$VERSION" "$PACK_MIN"; then
  echo "WARNING: this pack needs firmware $PACK_MIN or later; the device runs $VERSION." >&2
fi

# What is already there (name and size). If the list is truncated or unreadable, upload everything.
RESP=$(http GET /api/app/files); split_response
[ "$CODE" = 200 ] || die "cannot list the storage: $(explain_code "$CODE" "$BODY")"
MOUNTED=$(printf '%s' "$BODY" | json_get mounted)
[ -n "$MOUNTED" ] || die "unexpected answer from the device: no 'mounted' field (firmware older than 0.6.0?)"
[ "$MOUNTED" = false ] && \
  die "the device storage is not formatted: format it once from the device web page"
printf '%s' "$BODY" | grep -q '"files":\[' || die "unexpected answer from the device: no 'files' list"
TAB=$(printf '\t')
printf '%s' "$BODY" | grep -o '"name":"[^"]*","bytes":[0-9]*' \
  | sed -E "s/\"name\":\"([^\"]*)\",\"bytes\":([0-9]*)/\\1$TAB\\2/" > "$WORK/present"
[ "$(printf '%s' "$BODY" | json_get truncated)" = true ] && { echo "storage list truncated: uploading everything"; : > "$WORK/present"; }

TOTAL=$(wc -l < "$WORK/queue" | tr -d ' ')
DONE=0; SKIP=0; i=0
while IFS="$TAB" read -r path name; do
  i=$((i + 1)); size=$(file_size "$path")
  if [ "$FORCE" != 1 ] && grep -qx "$name$TAB$size" "$WORK/present"; then
    SKIP=$((SKIP + 1)); continue
  fi
  RESP=$(HTTP_MAX_S=$(upload_budget "$size") http POST /api/app/files -H "X-Rescue-Token: $TOKEN" \
          -F "file=@$path;filename=$name;type=application/octet-stream" < /dev/null)
  split_response
  if [ "$CODE" != 200 ]; then
    echo "stopped at $i of $TOTAL ($name): $(explain_code "$CODE" "$BODY")" >&2
    echo "The $DONE files before it ARE installed; run the same command again to continue." >&2
    exit 3
  fi
  DONE=$((DONE + 1))
  echo "[$i/$TOTAL] $name  $size bytes"
done < "$WORK/queue"
echo "done: $DONE uploaded, $SKIP already there with the same size"
