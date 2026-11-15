#!/usr/bin/env python3
"""Compare what the buoy says it sent with what first-bite decoded.

    tools/compare-records.py <buoy output> <subscriber output>

<buoy output> is the JSON lines of device/buoy.py; <subscriber output> is the
`<topic>  <fields>` lines of tools/zmq-sub.py --field message. Records are
matched by sequence number, and every value the buoy encoded must be the value
decoded: numbers to nine significant digits, booleans and labels equal. A
version 2 record carries numbers and booleans as JSON numbers and booleans; a
version 1 record (FIRST_BITE_RECORD_VERSION=1) carries them as text, and is
compared the same way.
Prints one line per record and a count; exit status 1 on any difference.
Python standard library only.
"""
import json
import sys


def same(sent, decoded) -> bool:
    if isinstance(sent, bool):
        return decoded is sent or decoded == ("true" if sent else "false")
    if isinstance(sent, (int, float)):
        if isinstance(decoded, bool):
            return False
        try:
            return float(f"{float(decoded):.9g}") == float(f"{float(sent):.9g}")
        except (TypeError, ValueError):
            return False
    return decoded == sent


def main() -> int:
    sent = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.startswith("{")]
    decoded = {}
    for line in open(sys.argv[2], encoding="utf-8"):
        topic, _, fields = line.rstrip("\n").partition("  ")
        if fields.startswith("{"):
            record = json.loads(fields)
            decoded[int(record["sequence_number"])] = (topic, record)
    matched = 0
    for message in sent:
        number = message["sequence_number"]
        if number not in decoded:
            print(f"sequence {number} {message['message']}: sent, not decoded")
            continue
        topic, record = decoded[number]
        values = {k: v for k, v in message.items() if k not in ("sent", "message", "bytes", "sequence_number")}
        wrong = [f"{k}: sent {v!r}, decoded {record.get(k)!r}" for k, v in values.items() if not same(v, record.get(k))]
        if topic != f"BUOY/{message['message']}":
            wrong.insert(0, f"topic {topic}")
        if wrong:
            print(f"sequence {number} {message['message']}: " + "; ".join(wrong))
        else:
            matched += 1
            print(f"sequence {number} {topic}: {len(values)} values equal")
    print(f"{matched} of {len(sent)} records match what the buoy encoded")
    return 0 if sent and matched == len(sent) else 1


if __name__ == "__main__":
    sys.exit(main())
