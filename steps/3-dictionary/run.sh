#!/usr/bin/env bash
# Step 3 — an interface document becomes checked data: build the harbour-buoy
# dictionary from icd/HB-ICD-001-A.md with the bite commands, and compare the
# result with dictionaries/harbour-buoy byte for byte.
#
#   --record   replace dictionaries/harbour-buoy with the result instead of comparing
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/hello-bite.sh"
RECORD=""
for a in "$@"; do [ "$a" = --record ] && RECORD=1; done

hb_banner "Step 3 — from an interface document to a dictionary" "icd/HB-ICD-001-A.md, four tables typed from it, and the bite commands that check them."
hb_preflight
WORK="$HB_RUN/3"; rm -rf "$WORK"; mkdir -p "$WORK"
cp -R "$HB_ROOT/icd/tables" "$WORK/tables"
# Every bite command runs in the work directory, as the reader would type it.
bite() { "$HB_ENGINE" run --rm --network none --user "$(id -u):$(id -g)" -v "$WORK:/work" -w /work "$HB_IMAGE" bite "$@"; }
# run <label for the reader> <bite arguments...>: print the command, run it, keep the output in OUT.
OUT=""
run() { hb_cmd "bite $1"; shift; OUT="$(bite "$@" 2>&1)"; RC=$?; printf '%s\n' "$OUT" | hb_show; return 0; }

hb_step "Scaffold: one interface, BUOY, on UDP port 47200 (document section 2)"
run "new harbour-buoy --name harbour-buoy --interface BUOY --port 47200" \
  new harbour-buoy --name harbour-buoy --interface BUOY --port 47200

hb_step "The document's numbering, tried on two fields before any is typed (section 3.1)"
hb_say "16-bit words numbered from 1, bit 15 the most significant. Battery Voltage is word 3, bits 10-0;"
hb_say "Latitude is words 3-4. bite range converts each to the bit range a dictionary holds."
run "range --word-bits 16 --bit0 lsb --first-word 1 --word 3 --bits 10-0" \
  range --word-bits 16 --bit0 lsb --first-word 1 --word 3 --bits 10-0
RANGE1="$OUT"
run "range --word-bits 16 --bit0 lsb --first-word 1 --word 3-4 --bits 15-0" \
  range --word-bits 16 --bit0 lsb --first-word 1 --word 3-4 --bits 15-0
RANGE2="$OUT"

hb_step "dictionary.json: the name, the version and the document transcribed"
cat >"$WORK/harbour-buoy/dictionary.json" <<'JSON'
{
    "name": "harbour-buoy",
    "version": "1.0.0",
    "description": "Synthetic example: a harbour buoy reporting to its shore station, transcribed from the invented document HB-ICD-001 in icd/.",
    "source": {
        "document": "HB-ICD-001",
        "revision": "A"
    }
}
JSON
hb_show <"$WORK/harbour-buoy/dictionary.json"

hb_step "Import the four tables typed from the document"
hb_say "icd/tables/fields.csv holds each field as the document prints it (word 3, bits 10-0); the importer"
hb_say "does the arithmetic and writes one JSON file per message."
run "import-csv tables --into harbour-buoy" import-csv tables --into harbour-buoy
IMPORT="$OUT"

hb_step "The gates, before there is a vector"
run "fmt --check harbour-buoy" fmt --check harbour-buoy; FMT="$OUT"
run "check --strict harbour-buoy" check --strict harbour-buoy
run "lint harbour-buoy" lint harbour-buoy
run "coverage --strict harbour-buoy" coverage --strict harbour-buoy
EARLY="$OUT"; EARLY_RC=$RC
hb_note "coverage --strict fails (exit $EARLY_RC): no message has a vector yet, so no field's meaning is tested."

hb_step "One vector per message, from the document's appendix A"
hb_say "The bytes and the values are the document's own example, never the decoder's output."
run 'vectors new harbour-buoy --interface BUOY --message Status --payload 010470646cec05a0 --note "HB-ICD-001 revision A, appendix A.1." --set …' \
  vectors new harbour-buoy --interface BUOY --message Status \
  --payload 010470646cec05a0 --note "HB-ICD-001 revision A, appendix A.1." \
  --set message_id=1 --set message_length=4 --set buoy_number=7 --set sequence_number=100 \
  --set operating_mode=Reporting --set lamp_on=true --set mooring_alarm=false --set position_fix=true \
  --set battery_voltage=12.60 --set uptime=1440
run 'vectors new harbour-buoy --interface BUOY --message "Sea State" --payload 02067065ff833ad18e992730 --note "HB-ICD-001 revision A, appendix A.2." --set …' \
  vectors new harbour-buoy --interface BUOY --message "Sea State" \
  --payload 02067065ff833ad18e992730 --note "HB-ICD-001 revision A, appendix A.2." \
  --set message_id=2 --set message_length=6 --set buoy_number=7 --set sequence_number=101 \
  --set water_temperature=-1.25 --set significant_wave_height=2.35 --set wave_period=8.5 \
  --set wind_direction=285 --set wind_speed=12.5 --set air_pressure=1003.2
run 'vectors new harbour-buoy --interface BUOY --message Position --payload 030870661a865979edf78e9643879ff1 --note "HB-ICD-001 revision A, appendix A.3." --set …' \
  vectors new harbour-buoy --interface BUOY --message Position \
  --payload 030870661a865979edf78e9643879ff1 --note "HB-ICD-001 revision A, appendix A.3." \
  --set message_id=3 --set message_length=8 --set buoy_number=7 --set sequence_number=102 \
  --set latitude=44.5012345 --set longitude=-30.2543210 --set drift_course=135 --set drift_speed=0.35 \
  --set satellites_in_view=9 --set antenna_height=-1.5

hb_step "The cross-check in the other direction: build the bytes from the stated values"
hb_say "bite vectors encode packs the values of a vector with the dictionary and compares the result"
hb_say "with the document's bytes. A field at the wrong bits shows here as a differing byte."
run "vectors encode harbour-buoy --vector position" vectors encode harbour-buoy --vector position
ENCODE="$OUT"

hb_step "The gates again"
run "fmt --check harbour-buoy" fmt --check harbour-buoy
run "check --strict harbour-buoy" check --strict harbour-buoy; CHECK="$OUT"
run "lint harbour-buoy" lint harbour-buoy; LINT="$OUT"
run "coverage --strict harbour-buoy" coverage --strict harbour-buoy; COVERAGE="$OUT"; COVERAGE_RC=$RC

if [ -n "$RECORD" ]; then
  rm -rf "$HB_ROOT/dictionaries/harbour-buoy"; mkdir -p "$HB_ROOT/dictionaries"
  cp -R "$WORK/harbour-buoy" "$HB_ROOT/dictionaries/harbour-buoy"
  hb_note "recorded: dictionaries/harbour-buoy replaced with this run's result"
fi
hb_step "Compare with the dictionary the other steps use"
hb_cmd "diff -r .run/3/harbour-buoy dictionaries/harbour-buoy"
DIFF="$(diff -r "$WORK/harbour-buoy" "$HB_ROOT/dictionaries/harbour-buoy" 2>&1)"; DIFF_RC=$?
if [ "$DIFF_RC" -eq 0 ]; then hb_note "(no difference)"; else printf '%s\n' "$DIFF" | head -n 20 | hb_show; fi

hb_step "Verify"
hb_assert_contains "word 3, bits 10-0 is bits [37, 48) of the payload" "$RANGE1" "start 37"
hb_assert_contains "words 3-4 are 32 bits from bit 32" "$RANGE2" "width 32 bits"
hb_assert_contains "the importer wrote three message files" "$IMPORT" "messages/Position.json"
hb_assert_contains "the imported files are already in canonical form" "$FMT" "0 not canonical"
hb_assert_contains "without vectors, coverage names the gap (rule C010)" "$EARLY" "C010"
hb_assert_contains "the dictionary's bytes equal the document's bytes" "$ENCODE" "matches the vector's payload_hex"
hb_assert_contains "check: no error, no warning, three vectors pass" "$CHECK" "0 errors, 0 warnings, 3/3 vectors passed"
hb_assert_contains "lint: no finding" "$LINT" "0 findings"
hb_assert_contains "coverage --strict: nothing failing" "$COVERAGE" "0 findings failing"
hb_assert_ok "coverage --strict exits 0" test "$COVERAGE_RC" -eq 0
hb_assert_ok "the result is dictionaries/harbour-buoy, byte for byte" test "$DIFF_RC" -eq 0
hb_done
