#!/usr/bin/env python3
"""The shore station: the peer the buoy sends to. It binds the UDP port,
counts what arrives and from whom, and never looks inside a datagram.

    device/shore.py --listen 0.0.0.0:47200 --count 9 [--timeout 30]

It prints one line per datagram and ends with a summary once --count
datagrams have arrived or --timeout seconds have passed. Python standard
library only.
"""
import argparse
import socket
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--listen", default="0.0.0.0:47200")
    parser.add_argument("--count", type=int, default=9)
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args()
    host, port = args.listen.rsplit(":", 1)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, int(port)))
    print(f"shore: listening on udp {args.listen}", flush=True)
    deadline = time.monotonic() + args.timeout
    received, senders = 0, {}
    while received < args.count:
        sock.settimeout(max(0.05, deadline - time.monotonic()))
        try:
            payload, (address, _) = sock.recvfrom(65535)
        except socket.timeout:
            break
        received += 1
        senders[address] = senders.get(address, 0) + 1
        print(f"shore: datagram {received}: {len(payload)} bytes from {address}", flush=True)
    by = ", ".join(f"{count} from {address}" for address, count in sorted(senders.items())) or "none"
    print(f"shore: received {received} of {args.count} datagrams: {by}", flush=True)
    return 0 if received == args.count else 1


if __name__ == "__main__":
    sys.exit(main())
