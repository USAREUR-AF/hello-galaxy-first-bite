#!/usr/bin/env bash
# Step 5 — Cursor-on-Target: first-bite's cot transform turns the buoy's
# Position message into a CoT event, and a subscriber prints it.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/hello-bite.sh"

hb_banner "Step 5 — Cursor-on-Target out of first-bite" "A mapping in configuration names the fields that give an event its identifier and position."
hb_preflight
SHARE=/usr/share/first-bite

hb_step "A capture file of the buoy's three messages, made from the dictionary's vectors"
hb_cmd "make-example-pcap.py dictionaries/harbour-buoy .run/5-buoy.pcap"
hb_in python3 "$SHARE/tools/make-example-pcap.py" /repo/dictionaries/harbour-buoy /work/5-buoy.pcap | hb_show

hb_step "The mapping"
sed -n '/cot:/,/stale_minutes/p' "$HB_ROOT/config/subpubs.cot.yml" | hb_show
hb_say "A subpub subscribes to BUOY/Position on the record socket, applies the mapping and publishes the"
hb_say "event on a socket of its own. Status and Sea State have no position and are not mapped."

hb_step "Replay the capture with the transform on, and read the event socket"
hb_cmd "tools/zmq-sub.py tcp://127.0.0.1:12001 --count 1 --field cot_xml_string &"
hb_cmd "SUBPUB_CONFIG_PATH=config/subpubs.cot.yml mind --pcap-file .run/5-buoy.pcap --dictionary dictionaries/harbour-buoy --activate-subpubs"
hb_in sh -c "python3 -u /repo/tools/zmq-sub.py tcp://127.0.0.1:12001 --count 1 --seconds 15 --field cot_xml_string >/work/5-events.txt 2>/work/5-sub.log &
  SUBPUB_CONFIG_PATH=/repo/config/subpubs.cot.yml mind --pcap-file /work/5-buoy.pcap --dictionary /repo/dictionaries/harbour-buoy --activate-subpubs >/work/5-mind.log 2>&1; wait" || true
EVENTS="$(cat "$HB_RUN/5-events.txt" 2>/dev/null)"
printf '%s\n' "$EVENTS" | hb_show
grep -o 'done: .*' "$HB_RUN/5-mind.log" | hb_show

hb_step "Verify"
hb_assert_contains "three frames were decoded" "$(cat "$HB_RUN/5-mind.log")" "done: 3 frames, 3 records, 3 decoded"
hb_assert_contains "one event was published, on the Position topic" "$EVENTS" "BUOY/Position/CoT  <event version=\"2.0\""
hb_assert_contains "its identifier is the buoy number" "$EVENTS" 'uid="7"'
hb_assert_contains "its point is the latitude of the document's example A.3" "$EVENTS" '<point lat="44.50123'
hb_assert_contains "and its longitude and antenna height" "$EVENTS" 'lon="-30.25432'
hb_assert_contains "the height above the ellipsoid is the antenna height" "$EVENTS" 'hae="-1.5"'
hb_done
