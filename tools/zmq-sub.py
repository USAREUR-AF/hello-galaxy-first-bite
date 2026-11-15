#!/usr/bin/env python3
"""Subscribe to a first-bite publisher socket and print what arrives.

    tools/zmq-sub.py tcp://127.0.0.1:12000 [--count N] [--seconds S] [--topic PREFIX] [--field NAME]

first-bite publishes each record as one ZeroMQ message, `<topic>|<JSON>`. Each
is printed as `<topic>  <JSON>`; with --field, only that member of the JSON is
printed (for example `message`, the decoded fields, or `cot_xml_string`).
Ends after --count messages or --seconds seconds; exit status 1 when fewer than
--count arrived. Needs pyzmq.
"""
import argparse
import json
import sys
import time

import zmq


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("address")
    parser.add_argument("--count", type=int, default=0)
    parser.add_argument("--seconds", type=float, default=10)
    parser.add_argument("--topic", default="")
    parser.add_argument("--field", default="")
    args = parser.parse_args()
    socket = zmq.Context.instance().socket(zmq.SUB)
    socket.setsockopt_string(zmq.SUBSCRIBE, args.topic)
    socket.connect(args.address)
    print(f"subscribed to {args.address}", file=sys.stderr, flush=True)
    deadline = time.monotonic() + args.seconds
    seen = 0
    while not args.count or seen < args.count:
        left = deadline - time.monotonic()
        if left <= 0 or not socket.poll(int(left * 1000)):
            break
        topic, _, payload = socket.recv_string().partition("|")
        seen += 1
        if args.field:
            value = json.loads(payload).get(args.field)
            payload = value if isinstance(value, str) else json.dumps(value, separators=(",", ":"))
        print(f"{topic}  {payload}", flush=True)
    print(f"{seen} message(s) from {args.address}", file=sys.stderr, flush=True)
    return 1 if args.count and seen < args.count else 0


if __name__ == "__main__":
    sys.exit(main())
