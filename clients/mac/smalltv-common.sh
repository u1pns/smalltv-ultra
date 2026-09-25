# Shared helpers for the SmallTV shell clients. Sourced by the other scripts; not meant to be run directly.
#
# Configuration (all optional except the host):
#   --host HOST          device address, e.g. 10.0.0.42 or smalltv.local (a ":port" suffix is allowed)
#   SMALLTV_HOST         same, from the environment (the --host option wins)
#                        With neither, the scripts find the device on the network (UDP discovery, see below).
#   SMALLTV_USER         web user      (default: admin)
#   SMALLTV_PASSWORD     web password  (default: 12345678, the same on every unit)
#
# Discovery (optional overrides; the defaults are what the device uses):
#   SMALLTV_DISCOVERY_WAIT        seconds to listen for answers (default 2)
#   SMALLTV_DISCOVERY_ADDR        comma-separated addresses to ask (default: every broadcast address)
#   SMALLTV_DISCOVERY_PORT        where the device listens (default 7778)
#   SMALLTV_DISCOVERY_REPLY_PORT  where it answers (default 7779)
#
# Requirements: POSIX sh, curl, and perl for discovery (all three come with macOS and most Linux systems).

SMALLTV_USER=${SMALLTV_USER:-admin}
SMALLTV_PASSWORD=${SMALLTV_PASSWORD:-12345678}
SMALLTV_HOST=${SMALLTV_HOST:-}

# Upload time budget, same rule as the device web page: 60 s plus 1 s per KiB (a phone far from the
# access point can be as slow as ~1 KiB/s), capped at 20 minutes. Never a fixed number.
UPLOAD_BASE_S=60
UPLOAD_MIN_BYTES_PER_S=1024
UPLOAD_MAX_S=1200
# Time budget for small requests (status, settings, panels).
REQUEST_MAX_S=15

die() { echo "error: $*" >&2; exit "${EXIT_CODE:-1}"; }

need_curl() { command -v curl >/dev/null 2>&1 || die "curl is required"; }

# parse_common "$@": consumes "--host X" wherever it appears and leaves the other arguments, quoted,
# in SMALLTV_REST.   Usage in a script:   parse_common "$@"; eval "set -- $SMALLTV_REST"
parse_common() {
  SMALLTV_REST=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --host) [ $# -ge 2 ] || die "--host needs a value"; SMALLTV_HOST=$2; shift 2 ;;
      --host=*) SMALLTV_HOST=${1#--host=}; shift ;;
      *) SMALLTV_REST="$SMALLTV_REST $(quote "$1")"; shift ;;
    esac
  done
}

# quote ARG: single-quotes an argument so it survives `eval "set -- ..."`.
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# discover_devices: asks the network which devices are there. Prints one line per device, tab-separated:
#   IP  NAME  MAC  VERSION  MODE        (MODE is "app" or "rescue")
# Nothing is printed if nobody answered. The device answers any UDP datagram on 7778 with one broadcast line on
# 7779:  "M 21:43:07 [HERE] smalltv-a1b2c3 mac=aa:bb:... ip=10.0.0.42 v=0.6.4 mode=app" (mode "app" or "rescue").
# Firmware 0.6.3 and older answer "[AQUI] ... modo=app|rescate"; both forms are accepted, and the mode is always
# reported as "app" or "rescue". Written in perl because sh has no sockets.
discover_devices() {
  command -v perl >/dev/null 2>&1 || die "perl is needed for discovery; pass the address with --host instead"
  perl -MIO::Socket::INET -MSocket -e '
    use strict; use warnings; use Time::HiRes qw(time);
    my ($ask, $reply, $wait, $addrs) = @ARGV;
    my $s = IO::Socket::INET->new(Proto => "udp", LocalPort => $reply, ReuseAddr => 1, Broadcast => 1)
      or do { print STDERR "cannot listen on UDP port $reply: $!\n"; exit 3 };
    eval { setsockopt($s, SOL_SOCKET, SO_REUSEPORT, 1) };   # others may listen on the same port
    my @to = $addrs ne "" ? split(/\s*,\s*/, $addrs) : ("255.255.255.255");
    if ($addrs eq "") {                                       # plus the broadcast address of each interface
      my $cfg = `ifconfig 2>/dev/null`;
      while ($cfg =~ /broadcast (\d+\.\d+\.\d+\.\d+)/g) { push @to, $1 unless grep { $_ eq $1 } @to }
      $cfg = `ip -4 addr 2>/dev/null`;
      while ($cfg =~ /brd (\d+\.\d+\.\d+\.\d+)/g) { push @to, $1 unless grep { $_ eq $1 } @to }
    }
    for my $a (@to) { my $d = sockaddr_in($ask, inet_aton($a) // next); send($s, "SMALLTV?\n", 0, $d) }
    my %seen; my $end = time + $wait; my $rin = ""; vec($rin, fileno($s), 1) = 1;
    while ((my $left = $end - time) > 0) {
      select(my $r = $rin, undef, undef, $left) or next;
      recv($s, my $buf, 1024, 0);
      next unless $buf =~ /\[(?:HERE|AQUI)\]\s+(\S+)\s+mac=(\S+)\s+ip=([0-9.]+)\s+v=(\S+)\s+(?:mode|modo)=(\S+)/;
      my $m = $5 eq "rescate" ? "rescue" : $5;
      $seen{lc $2} = join("\t", $3, $1, lc $2, $4, $m);
    }
    print "$_\n" for values %seen;
  ' "${SMALLTV_DISCOVERY_PORT:-7778}" "${SMALLTV_DISCOVERY_REPLY_PORT:-7779}" \
    "${SMALLTV_DISCOVERY_WAIT:-2}" "${SMALLTV_DISCOVERY_ADDR:-}"
}

# format_devices: the tab-separated lines of discover_devices, aligned for people.
format_devices() {
  awk -F '\t' '{ printf "%-16s %-16s %-18s v%-8s %s\n", $1, $2, $3, $4, $5 }'
}

# discover_host: sets SMALLTV_HOST when exactly one device answers; otherwise explains and exits.
discover_host() {
  _found=$(discover_devices) || exit 1
  _n=$(printf '%s' "$_found" | grep -c .)
  if [ "$_n" = 1 ]; then
    SMALLTV_HOST=$(printf '%s' "$_found" | cut -f 1)
    printf '%s\n' "$_found" | awk -F '\t' '{ printf "found %s at %s (firmware %s, %s mode)\n", $2, $1, $4, $5 }' >&2
  elif [ "$_n" = 0 ]; then
    die "no device answered the discovery in ${SMALLTV_DISCOVERY_WAIT:-2} s. It may be off, on another network, or \
running firmware without discovery (older than 0.5.23); guest networks often block broadcasts. Pass the address \
with --host HOST or SMALLTV_HOST (the Status screen of the device shows it)."
  else
    echo "error: several devices answered; choose one with --host HOST (or SMALLTV_HOST):" >&2
    printf '%s\n' "$_found" | format_devices >&2
    exit 1
  fi
}

require_host() {
  [ -n "$SMALLTV_HOST" ] || discover_host
  SMALLTV_HOST=${SMALLTV_HOST#http://}
  SMALLTV_HOST=${SMALLTV_HOST%/}
  BASE="http://$SMALLTV_HOST"
}

# json_get KEY < json : value of a flat string or number field ("" if absent). Enough for the device
# responses, which are small and flat; not a general JSON parser.
json_get() {
  sed -n -E "s/.*\"$1\":(\"([^\"]*)\"|([^,}\"]*)).*/\2\3/p" | head -n 1
}

# http METHOD PATH [curl args...]: prints the body, then a last line "HTTP <code>".
# Never prints the password or the token.
http() {
  _m=$1; _p=$2; shift 2
  curl -s -m "${HTTP_MAX_S:-$REQUEST_MAX_S}" -u "$SMALLTV_USER:$SMALLTV_PASSWORD" -X "$_m" \
       -w '\nHTTP %{http_code}' "$@" "$BASE$_p"
}

# split_response: after RESP=$(http ...), sets BODY and CODE.
split_response() {
  CODE=$(printf '%s\n' "$RESP" | tail -n 1 | sed 's/^HTTP //')
  BODY=$(printf '%s\n' "$RESP" | sed '$d')
}

# explain_code CODE BODY: human hint for the error codes the device uses.
explain_code() {
  case "$1" in
    000) echo "no answer from $SMALLTV_HOST (wrong address, device off, or not on this network)" ;;
    401) echo "wrong user or password (401)" ;;
    403) echo "missing or expired token (403): the device probably restarted; run the command again" ;;
    404) echo "not available (404): the device is in rescue mode, or its firmware is older than this feature" ;;
    409) echo "a firmware update is in progress (409): try again when it finishes" ;;
    507) echo "not enough space in the device storage (507): delete something first" ;;
    *) _e=$(printf '%s' "$2" | json_get error)
       echo "device answered HTTP $1${_e:+: $_e}" ;;
  esac
}

# read_status: GET /api/status. Sets STATUS (raw JSON), MODE, VERSION, TOKEN, MAXFW. Exits on failure.
read_status() {
  RESP=$(http GET /api/status); split_response
  [ "$CODE" = 200 ] || die "$(explain_code "$CODE" "$BODY")"
  STATUS=$BODY
  MODE=$(printf '%s' "$STATUS" | json_get mode)
  VERSION=$(printf '%s' "$STATUS" | json_get version)
  TOKEN=$(printf '%s' "$STATUS" | json_get token)
  MAXFW=$(printf '%s' "$STATUS" | json_get maxFirmware)
  [ -n "$TOKEN" ] || die "the device did not return a session token"
}

# post_token PATH [curl args...]: POST with the session token read by read_status. Sets BODY and CODE.
post_token() {
  _p=$1; shift
  RESP=$(http POST "$_p" -H "X-Rescue-Token: $TOKEN" "$@"); split_response
}

require_app_mode() {
  [ "$MODE" = app ] || die "the device is in '$MODE' mode: this only works in normal (app) mode"
}

file_size() { wc -c < "$1" | tr -d ' '; }

file_md5() {
  if command -v md5 >/dev/null 2>&1; then md5 -q "$1"
  elif command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d ' ' -f 1
  else die "neither md5 nor md5sum is available"; fi
}

# upload_budget BYTES: seconds allowed for an upload of that size.
upload_budget() {
  _s=$(( UPLOAD_BASE_S + $1 / UPLOAD_MIN_BYTES_PER_S ))
  [ "$_s" -gt "$UPLOAD_MAX_S" ] && _s=$UPLOAD_MAX_S
  echo "$_s"
}

# Resource names accepted by the device storage: letters, digits, dot, dash, underscore; max 30; no leading dot.
valid_resource_name() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9_-][A-Za-z0-9._-]{0,29}$'
}
