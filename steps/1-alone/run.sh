#!/usr/bin/env bash
# Step 1 — first-bite alone: check a dictionary, decode one payload by hand,
# replay a capture through the whole pipeline and read the records from the
# ZeroMQ socket. With --live <interface>: the same on NTP traffic of your own
# network.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/hello-bite.sh"
LIVE=""
while [ "$#" -gt 0 ]; do case "$1" in --live) LIVE="${2:-}"; shift 2;; --live=*) LIVE="${1#--live=}"; shift;; *) shift;; esac; done

hb_banner "Step 1 — first-bite alone" "A dictionary, a capture file, and decoded records on a ZeroMQ socket. No goat, no network."
hb_preflight
SHARE=/usr/share/first-bite

hb_step "Check the dictionary and run its test vectors"
hb_cmd "bite check --strict $SHARE/dictionaries/ntp"
CHECK="$(hb_in bite check --strict "$SHARE/dictionaries/ntp" 2>&1)"
printf '%s\n' "$CHECK" | tail -n 1 | hb_show

hb_step "Decode one payload by hand: a reply from a time server"
PAYLOAD=240206e90000060000000a80c0000201ed135500c0000000ed13554040000000ed13554043000000ed13554043800000
hb_cmd "bite decode $SHARE/dictionaries/ntp --port 123 $PAYLOAD"
DECODE="$(hb_in bite decode "$SHARE/dictionaries/ntp" --port 123 "$PAYLOAD" 2>&1)"
printf '%s\n' "$DECODE" | hb_show

hb_step "Replay a capture through the whole pipeline and read the record socket"
hb_say "mind reads each frame of the file, finds the dictionary's interface by UDP port, decodes the"
hb_say "payload and publishes one record on a ZeroMQ PUB socket. A subscriber prints topic and fields."
hb_cmd "tools/zmq-sub.py tcp://127.0.0.1:12000 --count 10 --field message &"
hb_cmd "mind --pcap-file $SHARE/examples/ntp.pcap --dictionary $SHARE/dictionaries/ntp"
# One container, so the two share a loopback and nothing touches the host's ports.
hb_in sh -c "python3 -u /repo/tools/zmq-sub.py tcp://127.0.0.1:12000 --count 10 --seconds 15 --field message >/work/1-records.txt 2>/work/1-sub.log &
  mind --pcap-file $SHARE/examples/ntp.pcap --dictionary $SHARE/dictionaries/ntp >/work/1-mind.log 2>&1; wait" || true
RECORDS="$(cat "$HB_RUN/1-records.txt" 2>/dev/null)"
MIND="$(cat "$HB_RUN/1-mind.log" 2>/dev/null)"
printf '%s\n' "$RECORDS" | cut -c1-150 | hb_show
grep -o 'done: .*' "$HB_RUN/1-mind.log" | hb_show

hb_step "Verify"
hb_assert_contains "the dictionary loads and all ten of its vectors pass" "$CHECK" "10/10 vectors passed"
hb_assert_contains "the payload decodes to a server reply at stratum 2" "$DECODE" '"stratum": 2'
hb_assert_contains "mind decoded every frame of the capture" "$MIND" "done: 10 frames, 10 records, 10 decoded"
hb_assert_contains "ten records arrived on the ZeroMQ socket" "$(cat "$HB_RUN/1-sub.log")" "10 message(s)"
hb_assert_contains "a record is published on <interface>/<message>" "$RECORDS" "NTP/server  {"
hb_assert_contains "its fields carry the dictionary's labels" "$RECORDS" '"leap_indicator":"no warning"'

if [ -n "$LIVE" ]; then
  hb_step "Live: NTP on interface $LIVE"
  hb_say "The same decoder on traffic this machine already carries. Capture needs the host's network,"
  hb_say "two capabilities and root in the container; first-bite opens a capture socket and sends nothing."
  hb_publishers_file
  hb_cmd "mind $LIVE --dictionary $SHARE/dictionaries/ntp --filter \"udp port 123\""
  hb_start hb-tap --network host --cap-add NET_RAW --cap-add NET_ADMIN --user 0:0 \
    -v "$HB_RUN:/work:ro" -e RUST_LOG=info -e PUBLISHER_CONFIG_PATH=/work/publishers.yml \
    "$HB_IMAGE" mind "$LIVE" --dictionary "$SHARE/dictionaries/ntp" --filter "udp port 123"
  hb_wait_log hb-tap "reading from interface $LIVE" 20 || { "$HB_ENGINE" logs hb-tap 2>&1 | tail -n 5 >&2; hb_die "capture did not start on $LIVE"; }
  hb_start hb-sub --network host -v "$HB_ROOT/tools:/tools:ro" "$HB_IMAGE" \
    python3 -u /tools/zmq-sub.py "tcp://127.0.0.1:$HB_ZMQ_PORT" --count 2 --seconds 20 --field message
  hb_wait_log hb-sub "subscribed to" 10 || true
  sleep 1
  hb_say "One request to a public time server, to provoke a reply:"
  hb_cmd "python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(b\"\\x23\" + bytes(47), (\"pool.ntp.org\", 123))'"
  hb_host python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(5); s.sendto(b"\x23" + bytes(47), ("pool.ntp.org", 123)); s.recvfrom(512)' ||
    hb_note "no reply from pool.ntp.org within 5 s"
  hb_wait_exit hb-sub 25 || true
  LIVE_RECORDS="$("$HB_ENGINE" logs hb-sub 2>/dev/null)"
  printf '%s\n' "$LIVE_RECORDS" | cut -c1-150 | hb_show
  "$HB_ENGINE" stop -t 5 hb-tap >/dev/null 2>&1 || true
  "$HB_ENGINE" logs hb-tap 2>&1 | grep -o 'done: .*' | hb_show
  hb_assert_contains "the request was seen on the wire and decoded" "$LIVE_RECORDS" "NTP/client  {"
  hb_assert_contains "the server's reply was seen on the wire and decoded" "$LIVE_RECORDS" "NTP/server  {"
fi
hb_done
