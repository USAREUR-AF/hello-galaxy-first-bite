#!/usr/bin/env bash
# Step 2 — a tap on a link you cannot change: a simulated buoy sends binary
# datagrams to its shore station across a Docker bridge, and first-bite
# decodes a copy of them from the bridge's interface. Neither end knows.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/hello-bite.sh"
COUNT=9
while [ "$#" -gt 0 ]; do case "$1" in --count) COUNT="$2"; shift 2;; *) shift;; esac; done

hb_banner "Step 2 — a tap on a link you cannot change" "Two containers exchange fixed-layout datagrams. first-bite reads a copy from the bridge between them."
hb_preflight
[ "$(uname -s)" = Linux ] || hb_note "not Linux: the bridge's interface is inside Docker's virtual machine; this step is not run on macOS."

hb_step "The link: a Docker bridge, a buoy and a shore station"
hb_link_up
hb_note "network $HB_LINK_NET ($HB_LINK_SUBNET, internal), bridge interface $HB_LINK_IF"
hb_note "buoy $HB_BUOY_IP  →  shore station $HB_SHORE_IP, UDP port $HB_BUOY_PORT"
hb_cmd "device/shore.py --listen 0.0.0.0:$HB_BUOY_PORT --count $COUNT        (container hb-shore)"
hb_shore_start "$COUNT"

hb_step "The tap: first-bite captures on the bridge's interface"
hb_say "mind opens a capture socket on $HB_LINK_IF in promiscuous mode, so it is handed a copy of every"
hb_say "frame the bridge forwards. It binds no port of the link and is the address of no datagram."
hb_publishers_file
hb_cmd "mind $HB_LINK_IF --dictionary dictionaries/harbour-buoy --filter \"udp port $HB_BUOY_PORT\"        (container hb-tap, host network)"
hb_tap_start hb-tap -e PUBLISHER_CONFIG_PATH=/work/publishers.yml --
hb_cmd "tools/zmq-sub.py tcp://127.0.0.1:$HB_ZMQ_PORT --count $COUNT --field message        (container hb-sub)"
hb_start hb-sub --network host -v "$HB_ROOT/tools:/tools:ro" "$HB_IMAGE" \
  python3 -u /tools/zmq-sub.py "tcp://127.0.0.1:$HB_ZMQ_PORT" --count "$COUNT" --seconds 40 --field message
hb_wait_log hb-sub "subscribed to" 10 || hb_die "the subscriber did not start"
sleep 1

hb_step "The buoy sends $COUNT datagrams"
hb_cmd "device/buoy.py --to $HB_SHORE_IP:$HB_BUOY_PORT --count $COUNT        (container hb-buoy)"
hb_buoy_run "$COUNT" "$HB_RUN/2-buoy.jsonl" 2>"$HB_RUN/2-buoy.log" || hb_die "the buoy failed: $(cat "$HB_RUN/2-buoy.log")"
cut -c1-150 "$HB_RUN/2-buoy.jsonl" | hb_show

hb_step "What the shore station received"
hb_wait_exit hb-shore 20 || true
SHORE="$("$HB_ENGINE" logs hb-shore 2>&1)"
printf '%s\n' "$SHORE" | tail -n 4 | hb_show

hb_step "What first-bite published"
hb_wait_exit hb-sub 20 || true
"$HB_ENGINE" logs hb-sub >"$HB_RUN/2-records.txt" 2>"$HB_RUN/2-sub.log"
cut -c1-150 "$HB_RUN/2-records.txt" | hb_show
"$HB_ENGINE" stop -t 10 hb-tap >/dev/null 2>&1 || true
TAP="$("$HB_ENGINE" logs hb-tap 2>&1)"
printf '%s\n' "$TAP" | grep -o 'capture .*\|done: .*' | hb_show

hb_step "Compare each decoded record with what the buoy encoded"
hb_cmd "tools/compare-records.py .run/2-buoy.jsonl .run/2-records.txt"
COMPARE="$(hb_in python3 /repo/tools/compare-records.py /work/2-buoy.jsonl /work/2-records.txt 2>&1)"
printf '%s\n' "$COMPARE" | hb_show

hb_step "Verify"
hb_assert_contains "the shore station received every datagram, all from the buoy" "$SHORE" "received $COUNT of $COUNT datagrams: $COUNT from $HB_BUOY_IP"
hb_assert_contains "first-bite saw the same $COUNT frames and decoded each" "$TAP" "done: $COUNT frames, $COUNT records, $COUNT decoded"
hb_assert_contains "nothing was dropped on the way to the decoder" "$TAP" "0 dropped by kernel"
hb_assert_contains "every record reached the ZeroMQ socket" "$(cat "$HB_RUN/2-sub.log")" "$COUNT message(s)"
hb_assert_contains "every decoded value is the value the buoy encoded" "$COMPARE" "$COUNT of $COUNT records match what the buoy encoded"
hb_done
