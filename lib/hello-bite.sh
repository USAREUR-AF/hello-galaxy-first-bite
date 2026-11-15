# shellcheck shell=bash
# hello-bite.sh — shared library for "Hello Galaxy: first-bite".
#
# Sourced by every step driver: which image holds first-bite, how a command is
# run in it, the simulated link, narration, assertions and clean-up. Adapted
# from hello-galaxy-legacy-feed's lib so the series reads the same way.
#
# Execution model: every first-bite command, the simulated buoy, the shore
# station and every subscriber run in containers of one image, built by
# `bin/hello-bite build` from the first-bite commit in FIRST_BITE_REF. The host
# needs bash and Docker and nothing else. State goes under .run/.

set -o pipefail

HB_LIB="${BASH_SOURCE[0]}"
HB_ROOT="$(cd "$(dirname "$HB_LIB")/.." && pwd)"
export HB_ROOT
HB_RUN="$HB_ROOT/.run"
mkdir -p "$HB_RUN"

HB_REF="$(tr -d '[:space:]' < "$HB_ROOT/FIRST_BITE_REF")"
HB_IMAGE_BASE="${HB_IMAGE_BASE:-hello-galaxy-first-bite}"
HB_IMAGE_PLAIN="$HB_IMAGE_BASE:${HB_REF:0:12}"
HB_IMAGE_GOAT="$HB_IMAGE_BASE:${HB_REF:0:12}-goat"
HB_ENGINE="${CONTAINER_ENGINE:-docker}"

# The stock Zenoh router goat runs, by digest (the one hello-galaxy-zagros-pod pins).
HB_ROUTER_IMAGE="eclipse/zenoh:1.9.0@sha256:157965d71e0bfd0a044d76a985ff0e5c306ad3968929168fb9678cd2a7fec23f"

# Ports on the host's loopback. Change them when something else holds one.
HB_ZMQ_PORT="${HB_ZMQ_PORT:-12000}"        # first-bite's record socket
HB_COT_PORT="${HB_COT_PORT:-12001}"        # the Cursor-on-Target socket of step 5
HB_ROUTER_PORT="${HB_ROUTER_PORT:-17447}"  # the stand-in router of step 4

# The simulated link of steps 2 and 4: a Docker bridge with documentation
# addresses (RFC 5737). The bridge's interface gets a fixed name so that
# first-bite can be pointed at it.
HB_LINK_NET="hb-link"
HB_LINK_IF="hblink0"
HB_LINK_SUBNET="198.51.100.0/24"
HB_BUOY_IP="198.51.100.10"
HB_SHORE_IP="198.51.100.20"
HB_BUOY_PORT=47200

# --- presentation -----------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_CYAN=$'\033[36m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_GREEN=""; C_RED=""; C_CYAN=""; C_BLUE=""
fi
HB_STEP=0
hb_banner() {
  printf '\n%s%s== %s ==%s\n' "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"
  [ -n "${2:-}" ] && printf '%s%s%s\n' "$C_DIM" "$2" "$C_RESET"
}
hb_step() { HB_STEP=$((HB_STEP + 1)); printf '\n%s%s[%d] %s%s\n' "$C_BOLD" "$C_CYAN" "$HB_STEP" "$1" "$C_RESET"; }
hb_say()  { printf '    %s\n' "$1"; }
hb_note() { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
hb_cmd()  { printf '    %s$ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
hb_show() { sed 's/^/    │ /'; }
hb_die()  { printf '%s%s%s\n' "$C_RED" "$1" "$C_RESET" >&2; exit 1; }

# --- the image --------------------------------------------------------------
hb_have_image() { "$HB_ENGINE" image inspect "$1" >/dev/null 2>&1; }

# hb_preflight [goat]: choose the image in HB_IMAGE, or say how to build it.
# The goat build holds everything the default build does, so it serves every step.
hb_preflight() {
  command -v "$HB_ENGINE" >/dev/null 2>&1 || hb_die "$HB_ENGINE is not installed. See README, Prerequisites."
  "$HB_ENGINE" info >/dev/null 2>&1 || hb_die "the $HB_ENGINE daemon is not reachable."
  if [ "${1:-}" = goat ]; then
    hb_have_image "$HB_IMAGE_GOAT" || hb_die "this step needs first-bite built with the goat feature: bin/hello-bite build --goat"
    HB_IMAGE="$HB_IMAGE_GOAT"
  elif hb_have_image "$HB_IMAGE_PLAIN"; then
    HB_IMAGE="$HB_IMAGE_PLAIN"
  elif hb_have_image "$HB_IMAGE_GOAT"; then
    HB_IMAGE="$HB_IMAGE_GOAT"
  else
    hb_die "no first-bite image yet: bin/hello-bite build"
  fi
  export HB_IMAGE
  printf '%simage: %s · first-bite %s%s\n' "$C_DIM" "$HB_IMAGE" "${HB_REF:0:12}" "$C_RESET"
}

# hb_in <command...>: one command in a throwaway container as the calling user,
# with no network, the repository read-only at /repo and .run/ at /work.
hb_in() {
  "$HB_ENGINE" run --rm --network none --user "$(id -u):$(id -g)" \
    -v "$HB_ROOT:/repo:ro" -v "$HB_RUN:/work" -w /work "$HB_IMAGE" "$@"
}

# hb_host <command...>: the same on the host's network, to reach a loopback port.
hb_host() {
  "$HB_ENGINE" run --rm --network host --user "$(id -u):$(id -g)" \
    -v "$HB_ROOT:/repo:ro" -v "$HB_RUN:/work" -w /work "$HB_IMAGE" "$@"
}

# --- containers and networks this run started --------------------------------
HB_CONTAINERS=()
HB_NETWORKS=()
# hb_start <name> <docker run arguments...>: a detached container, removed at exit.
hb_start() {
  local name="$1"; shift
  "$HB_ENGINE" rm -f "$name" >/dev/null 2>&1 || true
  "$HB_ENGINE" run -d --name "$name" "$@" >/dev/null || hb_die "could not start $name"
  HB_CONTAINERS+=("$name")
}
# hb_wait_log <container> <fixed text> <seconds>
hb_wait_log() {
  local name="$1" text="$2" secs="${3:-20}" i=0
  while [ "$i" -lt $((secs * 5)) ]; do
    "$HB_ENGINE" logs "$name" 2>&1 | grep -qF -- "$text" && return 0
    sleep 0.2; i=$((i + 1))
  done
  return 1
}
# hb_wait_exit <container> <seconds>: wait for a container to end.
hb_wait_exit() {
  local name="$1" secs="${2:-30}" i=0
  while [ "$i" -lt $((secs * 5)) ]; do
    [ "$("$HB_ENGINE" inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" = true ] || return 0
    sleep 0.2; i=$((i + 1))
  done
  return 1
}
# hb_wait_port <address> <port> <seconds>: wait until a TCP connection is accepted.
hb_wait_port() {
  "$HB_ENGINE" run --rm --network host "$HB_IMAGE" python3 -c '
import socket, sys, time
deadline = time.monotonic() + float(sys.argv[3])
while time.monotonic() < deadline:
    try:
        socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=1).close()
        sys.exit(0)
    except OSError:
        time.sleep(0.2)
sys.exit(1)' "$1" "$2" "$3"
}
hb_cleanup() {
  local name
  for name in ${HB_CONTAINERS[@]+"${HB_CONTAINERS[@]}"}; do "$HB_ENGINE" rm -f "$name" >/dev/null 2>&1 || true; done
  for name in ${HB_NETWORKS[@]+"${HB_NETWORKS[@]}"}; do "$HB_ENGINE" network rm "$name" >/dev/null 2>&1 || true; done
}
trap hb_cleanup EXIT

# --- the simulated link -------------------------------------------------------
# A Docker bridge is the cable and the switch between the buoy and the shore
# station. It is --internal: nothing on it is routed anywhere else.
hb_link_up() {
  "$HB_ENGINE" network rm "$HB_LINK_NET" >/dev/null 2>&1 || true
  "$HB_ENGINE" network create --driver bridge --internal --subnet "$HB_LINK_SUBNET" \
    -o "com.docker.network.bridge.name=$HB_LINK_IF" "$HB_LINK_NET" >/dev/null ||
    hb_die "could not create the network $HB_LINK_NET"
  HB_NETWORKS+=("$HB_LINK_NET")
}
# hb_shore_start <count>: the shore station, waiting for <count> datagrams.
hb_shore_start() {
  hb_start hb-shore --network "$HB_LINK_NET" --ip "$HB_SHORE_IP" -v "$HB_ROOT/device:/device:ro" \
    "$HB_IMAGE" python3 -u /device/shore.py --listen "0.0.0.0:$HB_BUOY_PORT" --count "$1" --timeout 60
  hb_wait_log hb-shore "listening on udp" 15 || hb_die "the shore station did not start"
}
# hb_buoy_run <count> <output file>: the buoy sends <count> datagrams and ends.
hb_buoy_run() {
  "$HB_ENGINE" run --rm --name hb-buoy --network "$HB_LINK_NET" --ip "$HB_BUOY_IP" \
    -v "$HB_ROOT/device:/device:ro" "$HB_IMAGE" \
    python3 -u /device/buoy.py --to "$HB_SHORE_IP:$HB_BUOY_PORT" --count "$1" --interval 0.2 >"$2"
}
# hb_tap_start <name> <docker run arguments...> -- <mind arguments...>
# first-bite capturing on the bridge's interface. Capture needs the host's
# network namespace, the two capture capabilities and root in the container.
hb_tap_start() {
  local name="$1"; shift
  local docker_args=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do docker_args+=("$1"); shift; done
  shift
  hb_start "$name" --network host --cap-add NET_RAW --cap-add NET_ADMIN --user 0:0 \
    -v "$HB_ROOT:/repo:ro" -v "$HB_RUN:/work:ro" -e RUST_LOG=info \
    ${docker_args[@]+"${docker_args[@]}"} "$HB_IMAGE" mind "$HB_LINK_IF" \
    --dictionary /repo/dictionaries/harbour-buoy --filter "udp port $HB_BUOY_PORT" "$@"
  hb_wait_log "$name" "reading from interface $HB_LINK_IF" 20 || {
    "$HB_ENGINE" logs "$name" 2>&1 | tail -n 20 >&2
    hb_die "first-bite did not start capturing on $HB_LINK_IF"
  }
}
# The record socket on a port of this run's choosing.
hb_publishers_file() {
  cat >"$HB_RUN/publishers.yml" <<YAML
publishers:
  - name: "records"
    publisher_type: PUB
    address: "tcp://127.0.0.1:$HB_ZMQ_PORT"
    topic: "subsystem/message_type"
YAML
}

# --- assertions -------------------------------------------------------------
HB_FAILS=0
hb_assert_contains() {
  local what="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$what"
  else printf '    %s✗%s %s (expected: %s)\n' "$C_RED" "$C_RESET" "$what" "$needle" >&2; HB_FAILS=$((HB_FAILS + 1)); fi
}
hb_assert_lacks() {
  local what="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then printf '    %s✗%s %s (did NOT expect: %s)\n' "$C_RED" "$C_RESET" "$what" "$needle" >&2; HB_FAILS=$((HB_FAILS + 1))
  else printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$what"; fi
}
# hb_assert_ok <what> <command...>: the command must succeed.
hb_assert_ok() {
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$what"
  else printf '    %s✗%s %s\n' "$C_RED" "$C_RESET" "$what" >&2; HB_FAILS=$((HB_FAILS + 1)); fi
}
hb_done() {
  if [ "$HB_FAILS" -eq 0 ]; then printf '\n%s%s✓ step complete — every assertion held.%s\n' "$C_BOLD" "$C_GREEN" "$C_RESET"; return 0; fi
  printf '\n%s%s✗ %d assertion(s) failed.%s\n' "$C_BOLD" "$C_RED" "$HB_FAILS" "$C_RESET" >&2; return 1
}
