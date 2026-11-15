#!/usr/bin/env bash
# Step 4 — onto a goat fabric: the tap of step 2 publishes its records on a
# Zenoh router configured as goat configures one, under a certificate, and the
# released goat CLI receives them. The router and the certificate authority
# are stand-ins built here; no goatnet is contacted.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/hello-bite.sh"
COUNT=9

hb_banner "Step 4 — onto a goat fabric" "mind with the goat feature joins a router as a goat publisher; the goat CLI reads what it publishes."
hb_preflight goat
hb_note "run against: a stand-in. A stock Zenoh 1.9.0 router with goat's slot-pool configuration and a throwaway authority."
WORK="$HB_RUN/4"; rm -rf "$WORK"; mkdir -p "$WORK"
slot() { printf 'hello-galaxy-first-bite:%s' "$1" | "$HB_ENGINE" run --rm -i "$HB_IMAGE" sha256sum | cut -c1-32; }
PUB="$(slot 0)"; READER="$(slot 1)"
# The address, not the name localhost: the router's port is published on
# 127.0.0.1 only, and where localhost resolves to ::1 first a Zenoh client
# tries that address alone. The router's certificate carries the address.
ENDPOINT="tls/127.0.0.1:$HB_ROUTER_PORT"

hb_step "The stand-in goatnet: an authority, two slots and a router"
hb_say "A slot is a certificate common name with a write rule on <uuid>/** already in the router."
hb_note "publisher slot $PUB"
hb_note "reader slot    $READER"
hb_cmd "fabric/make-certs.sh .run/4/tls $PUB $READER"
hb_in sh /repo/fabric/make-certs.sh /work/4/tls "$PUB" "$READER" | hb_show
sed "s/__PUBLISHER__/$PUB/g; s/__READER__/$READER/g" "$HB_ROOT/fabric/router.json5.tmpl" >"$WORK/tls/router.json5"
hb_cmd "docker run -d --name hb-router -p 127.0.0.1:$HB_ROUTER_PORT:7447 -v .run/4/tls:/tls:ro eclipse/zenoh:1.9.0@sha256:1579… -c /tls/router.json5"
hb_start hb-router -p "127.0.0.1:$HB_ROUTER_PORT:7447" -v "$WORK/tls:/tls:ro" "$HB_ROUTER_IMAGE" -c /tls/router.json5
hb_wait_port 127.0.0.1 "$HB_ROUTER_PORT" 30 || {
  "$HB_ENGINE" logs hb-router 2>&1 | tail -n 20 >&2; hb_die "the router is not accepting connections on 127.0.0.1:$HB_ROUTER_PORT"; }
hb_note "the router accepts connections on 127.0.0.1:$HB_ROUTER_PORT"

hb_step "What a goatnet's administrator hands over: the onboarding archive"
mkdir -p "$WORK/bundle"
cp "$WORK/tls/$PUB-cert.pem" "$WORK/tls/$PUB-key.pem" "$WORK/tls/ca-root.pem" "$WORK/bundle/"
printf '# Onboarding notes\n\nYour slot: %s\nRouter endpoint: %s\n' "$PUB" "$ENDPOINT" >"$WORK/bundle/NOTES.md"
(cd "$WORK/bundle" && printf '%s\n' *) | hb_show
hb_cmd "mind goat init --bundle .run/4/bundle --format harbour-buoy --site harbour-3 --instance tap-1 --out .run/4/goat.yml"
hb_in mind goat init --bundle /work/4/bundle --format harbour-buoy --site harbour-3 --instance tap-1 --out /work/4/goat.yml 2>&1 | hb_show
# The heartbeat is every 30 s unless the configuration says otherwise; 2 s here,
# so that the count of published records can be read without a wait.
printf '  health_interval_seconds: 2\n' >>"$WORK/goat.yml"
hb_show <"$WORK/goat.yml"
hb_note "health_interval_seconds was added by this step (default 30) so that the heartbeat can be read at once."
# The reader's own archive and configuration, made the same way.
mkdir -p "$WORK/reader"
cp "$WORK/tls/$READER-cert.pem" "$WORK/tls/$READER-key.pem" "$WORK/tls/ca-root.pem" "$WORK/reader/"
hb_in mind goat init --bundle /work/4/reader --endpoint "$ENDPOINT" --format harbour-buoy --site harbour-3 \
  --instance reader-1 --out /work/4/reader.yml >/dev/null 2>&1 || hb_die "could not write the reader's configuration"

hb_step "Check it offline: nothing is sent"
hb_cmd "mind goat check --config .run/4/goat.yml --dictionary dictionaries/harbour-buoy"
CHECK="$(hb_in mind goat check --config /work/4/goat.yml --dictionary /repo/dictionaries/harbour-buoy 2>&1)"
printf '%s\n' "$CHECK" | hb_show

hb_step "Confirm the router delivers what this certificate writes"
hb_say "A goat router drops a write its rules do not grant and reports nothing. The probe puts one"
hb_say "sample and waits for it on a second session."
hb_cmd "mind goat probe --config .run/4/goat.yml"
PROBE="$(hb_host mind goat probe --config /work/4/goat.yml 2>&1)"
printf '%s\n' "$PROBE" | hb_show

hb_step "A subscriber on the fabric: the released goat CLI, with the reader's certificate"
hb_cmd "tools/fetch-goat-cli.py fabric/goat-cli.pin .run/4/goat"
hb_host python3 /repo/tools/fetch-goat-cli.py /repo/fabric/goat-cli.pin /work/4/goat 2>&1 | hb_show
[ -x "$WORK/goat" ] || hb_die "the goat CLI could not be downloaded"
PROFILE="$WORK/goat-profile/contexts/stand-in"; mkdir -p "$PROFILE"
cp "$WORK/tls/$READER-cert.pem" "$PROFILE/mtls.cert.pem"
cp "$WORK/tls/$READER-key.pem" "$PROFILE/mtls.key.pem"
cp "$WORK/tls/ca-root.pem" "$PROFILE/ca-roots.pem"
printf 'router_endpoint = "%s"\ndevice_id = "hello-galaxy-reader"\n' "$ENDPOINT" >"$PROFILE/profile.toml"
printf 'current_context = "stand-in"\n' >"$WORK/goat-profile/config.toml"
hb_cmd "goat sub '$PUB/telemetry/**' --uuid --count $COUNT"
hb_start hb-goat-sub --network host --user "$(id -u):$(id -g)" -v "$HB_RUN:/work" -e HOME=/work/4 \
  -e GOAT_PROFILE_DIR=/work/4/goat-profile -e GOAT_TIMEOUT=90 "$HB_IMAGE" \
  /work/4/goat --context stand-in sub "$PUB/telemetry/**" --uuid --count "$COUNT"
hb_wait_log hb-goat-sub "listening on" 20 || { "$HB_ENGINE" logs hb-goat-sub 2>&1 | tail -n 10 >&2; hb_die "goat sub did not subscribe"; }

hb_step "The link of step 2, with first-bite publishing to the fabric"
hb_link_up
hb_shore_start "$COUNT"
hb_publishers_file
cat >"$WORK/subscribers.yml" <<YAML
subscribers:
  - name: fabric
    subscriber_type: "goat"
    zmq_url: "127.0.0.1"
    zmq_port: $HB_ZMQ_PORT
    topics: ["*"]
YAML
hb_show <"$WORK/subscribers.yml"
hb_cmd "GOAT_CONFIG_PATH=.run/4/goat.yml SUBSCRIBER_CONFIG_PATH=.run/4/subscribers.yml mind $HB_LINK_IF --dictionary dictionaries/harbour-buoy --filter \"udp port $HB_BUOY_PORT\""
hb_tap_start hb-tap -e PUBLISHER_CONFIG_PATH=/work/publishers.yml -e GOAT_CONFIG_PATH=/work/4/goat.yml \
  -e SUBSCRIBER_CONFIG_PATH=/work/4/subscribers.yml --
hb_wait_log hb-tap "goat: the router delivers" 30 || { "$HB_ENGINE" logs hb-tap 2>&1 | grep -v '"message_type"' | tail -n 15 >&2; hb_die "the goat sink did not join the router"; }
"$HB_ENGINE" logs hb-tap 2>&1 | grep -o 'goat: .*' | hb_show
hb_cmd "device/buoy.py --to $HB_SHORE_IP:$HB_BUOY_PORT --count $COUNT"
hb_buoy_run "$COUNT" "$WORK/buoy.jsonl" 2>"$WORK/buoy.log" || hb_die "the buoy failed: $(cat "$WORK/buoy.log")"
hb_note "$(cat "$WORK/buoy.log")"

hb_step "What the goat CLI received"
hb_wait_exit hb-goat-sub 30 || true
GOATSUB="$("$HB_ENGINE" logs hb-goat-sub 2>&1)"
printf '%s\n' "$GOATSUB" | cut -c1-170 | hb_show
hb_wait_exit hb-shore 10 || true
SHORE="$("$HB_ENGINE" logs hb-shore 2>&1 | tail -n 1)"

hb_step "The announcement, the heartbeat and the schema declarations, read from the router's storage"
hb_cmd "mind goat watch '$PUB/services/**' --stored --payload --config .run/4/reader.yml"
sleep 3
ANNOUNCE="$(hb_host mind goat watch "$PUB/services/**" --stored --seconds 5 --payload --config /work/4/reader.yml 2>&1)"
printf '%s\n' "$ANNOUNCE" | cut -c1-400 | hb_show
hb_cmd "mind goat watch '$PUB/health/**' --stored --payload --config .run/4/reader.yml"
HEALTH="$(hb_host mind goat watch "$PUB/health/**" --stored --seconds 5 --payload --config /work/4/reader.yml 2>&1)"
printf '%s\n' "$HEALTH" | cut -c1-400 | hb_show
hb_cmd "mind goat watch 'attest/schema/$PUB/**' --stored --config .run/4/reader.yml"
SCHEMAS="$(hb_host mind goat watch "attest/schema/$PUB/**" --stored --seconds 5 --config /work/4/reader.yml 2>&1)"
printf '%s\n' "$SCHEMAS" | hb_show
"$HB_ENGINE" stop -t 10 hb-tap >/dev/null 2>&1 || true
TAP="$("$HB_ENGINE" logs hb-tap 2>&1)"

hb_step "Verify"
PREFIX="$PUB/telemetry/harbour-buoy/harbour-3/buoy"
hb_assert_contains "offline, the certificate, its name, its dates and its root are in order" "$CHECK" "all checks passed; nothing was sent"
hb_assert_contains "check lists the key each message will be published on" "$CHECK" "record  $PREFIX/sea_state"
hb_assert_contains "the router delivers this certificate's writes" "$PROBE" "delivered: a sample put on $PUB/health/shims/harbour-buoy/tap-1"
hb_assert_contains "the sink joined as the slot" "$TAP" "goat: joined $ENDPOINT as $PUB"
hb_assert_contains "the shore station still received every datagram from the buoy" "$SHORE" "received $COUNT of $COUNT datagrams: $COUNT from $HB_BUOY_IP"
hb_assert_contains "the goat CLI received a Status record from the fabric" "$GOATSUB" "$PREFIX/status"
hb_assert_contains "the goat CLI received a Sea State record" "$GOATSUB" "$PREFIX/sea_state"
hb_assert_contains "the goat CLI received a Position record" "$GOATSUB" "$PREFIX/position"
hb_assert_contains "the announcement is stored under the slot" "$ANNOUNCE" "$PUB/services/shims/harbour-buoy/tap-1/announce"
hb_assert_contains "the heartbeat counts the records published" "$HEALTH" "\"records_published\":$COUNT"
hb_assert_contains "a schema is declared for each record key" "$SCHEMAS" "attest/schema/$PREFIX/position"
hb_done
