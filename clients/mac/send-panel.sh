#!/bin/sh
# Show a text panel on the device, composed from the command line.
#
#   sh send-panel.sh [--host HOST] [options] ITEM [ITEM...]
#
# Items, drawn top to bottom in the order given (at most 8 rows):
#   "some text"          a line of normal text
#   --big "text"         a line of big text (takes two rows)
#   --accent "text"      a line in the accent colour (orange)
#   --warn "text"        a line in the warning colour (red)
#   --small "text"       a line of small text
#   --kv "Label=Value"   label on the left, value on the right
#   --bar "42:text"      a gauge filled to 42 % with a text next to it
#
# Options:
#   --title "T"          title, top left (up to 24 bytes)
#   --seconds N          how long it stays on screen, 5..120 (default 8)
#   --alert              white flash and full brightness when it appears
#   --save NAME          instead of showing it once, store it as panel p-NAME.jpp: it survives restarts
#                        and rotates with the other panels (turn on the "panels" screen in the web page)
#   --ttl HOURS          with --save: the panel expires and is deleted after HOURS (needs the clock set)
#   --file FILE          send an already written PANEL1 file as it is (use - for stdin)
#
# Examples:
#   sh send-panel.sh --title Home --big "Dinner ready" "Come down"
#   sh send-panel.sh --kv "CPU=42 %" --bar "42:" --seconds 15
#   sh send-panel.sh --save stocks --ttl 8 --title Stocks --kv "ACME=12.40" --kv "EURUSD=1.09"
#
# A one-off panel (the default) is kept in memory only: it never writes the flash. Saved panels do,
# so do not re-save one every minute: save only when its content has really changed.
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/smalltv-common.sh"

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
# Panel limits (they are the device's, from the panel API): 512 bytes per panel, 96 bytes per line
# including the newline, 8 body rows, 24-byte title.
PANEL_MAX_BYTES=512
LINE_MAX_BYTES=96
MAX_ROWS=8

parse_common "$@"; eval "set -- $SMALLTV_REST"
TITLE=""; SECONDS_ON=""; ALERT=""; SAVE=""; TTL_H=""; FILE=""
TAB=$(printf '\t')
BODYF=$(mktemp "${TMPDIR:-/tmp}/smalltv-panel.XXXXXX") || die "cannot create a temporary file"
trap 'rm -f "$BODYF" "$BODYF.jpp"' EXIT INT TERM
ROW=0

clean() { printf '%s' "$1" | tr '\t\r\n' '   '; }
add_row() {   # add_row HEIGHT LINE-WITHOUT-ROW-PREFIX-FORMAT...
  _h=$1; shift
  [ $((ROW + _h)) -le $MAX_ROWS ] || die "too many rows: a panel has $MAX_ROWS rows (big text takes two)"
  _line=$(printf "$@")
  [ "$(printf '%s\n' "$_line" | wc -c)" -le $LINE_MAX_BYTES ] || die "line too long (max $LINE_MAX_BYTES bytes): $_line"
  printf '%s\n' "$_line" >> "$BODYF"
  ROW=$((ROW + _h))
}
text_row() { add_row "$1" 'L\t%s\t%s\t%s\t%s' "$ROW" "$2" "$3" "$(clean "$4")"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --title) TITLE=$(clean "${2:?--title needs a value}"); shift 2 ;;
    --seconds) SECONDS_ON=${2:?--seconds needs a value}; shift 2 ;;
    --alert) ALERT=every; shift ;;
    --save) SAVE=${2:?--save needs a name}; shift 2 ;;
    --ttl) TTL_H=${2:?--ttl needs hours}; shift 2 ;;
    --file) FILE=${2:?--file needs a path}; shift 2 ;;
    # Size and tone keywords of the PANEL1 protocol: large/normal/small, normal/accent/alert.
    --big) text_row 2 large normal "${2:?--big needs text}"; shift 2 ;;
    --accent) text_row 1 normal accent "${2:?--accent needs text}"; shift 2 ;;
    --warn) text_row 1 normal alert "${2:?--warn needs text}"; shift 2 ;;
    --small) text_row 1 small normal "${2:?--small needs text}"; shift 2 ;;
    --kv) _kv=${2:?--kv needs Label=Value}; case "$_kv" in *=*) ;; *) die "--kv expects Label=Value" ;; esac
          add_row 1 'K\t%s\t%s\t%s' "$ROW" "$(clean "${_kv%%=*}")" "$(clean "${_kv#*=}")"; shift 2 ;;
    --bar) _b=${2:?--bar needs PERCENT:text}; _p=${_b%%:*}; _t=""; case "$_b" in *:*) _t=${_b#*:} ;; esac
           case "$_p" in ''|*[!0-9]*) die "--bar expects PERCENT:text, e.g. 42:disk" ;; esac
           [ "$_p" -le 100 ] || _p=100
           add_row 1 'B\t%s\t%s\t%s' "$ROW" "$_p" "$(clean "$_t")"; shift 2 ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) text_row 1 normal normal "$1"; shift ;;
  esac
done

if [ -n "$SECONDS_ON" ]; then
  case "$SECONDS_ON" in ''|*[!0-9]*) die "--seconds must be a number between 5 and 120" ;; esac
  [ "$SECONDS_ON" -ge 5 ] && [ "$SECONDS_ON" -le 120 ] || die "--seconds must be between 5 and 120"
fi
[ -z "$TTL_H" ] || [ -n "$SAVE" ] || die "--ttl only makes sense with --save"
if [ -n "$SAVE" ]; then
  printf '%s' "$SAVE" | grep -Eq '^[A-Za-z0-9_-]{1,23}$' || die "--save: use letters, digits, - and _ (max 23)"
fi

# Build the panel text: PANEL1, header, then the body rows.
PANEL="$BODYF.jpp"
if [ -n "$FILE" ]; then
  if [ "$FILE" = - ]; then cat > "$PANEL"; else [ -f "$FILE" ] || die "file not found: $FILE"; cp "$FILE" "$PANEL"; fi
  [ "$(head -n 1 "$PANEL")" = PANEL1 ] || die "a panel file must start with the line PANEL1"
else
  [ -s "$BODYF" ] || usage
  {
    echo PANEL1
    [ -z "$TITLE" ] || printf 'T\t%s\n' "$TITLE"
    [ -z "$SECONDS_ON" ] || printf 'S\t%s\n' "$SECONDS_ON"
    [ -z "$ALERT" ] || printf 'X\t%s\n' "$ALERT"
    if [ -n "$SAVE" ]; then
      NOW=$(date +%s)
      printf 'G\t%s\n' "$NOW"
      [ -z "$TTL_H" ] || printf 'V\t%s\n' "$(( NOW + TTL_H * 3600 ))"
    fi
    cat "$BODYF"
  } > "$PANEL"
fi
[ "$(file_size "$PANEL")" -le $PANEL_MAX_BYTES ] || die "the panel is $(file_size "$PANEL") bytes; the limit is $PANEL_MAX_BYTES"

need_curl; require_host
read_status
require_app_mode

if [ -n "$SAVE" ]; then
  post_token /api/app/files -F "file=@$PANEL;filename=p-$SAVE.jpp;type=text/plain"
  [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
  echo "saved as p-$SAVE.jpp (shown on the 'panels' screen; turn it on in the web page if it is off)"
else
  post_token /api/app/panel -H 'Content-Type: text/plain; charset=utf-8' --data-binary "@$PANEL"
  [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
  echo "shown: $(printf '%s' "$BODY" | json_get rows) rows, $(printf '%s' "$BODY" | json_get durationS) s on screen"
  INVALID=$(printf '%s' "$BODY" | json_get invalid)
  [ "${INVALID:-0}" = 0 ] || echo "WARNING: the device discarded $INVALID line(s) of this panel" >&2
fi
