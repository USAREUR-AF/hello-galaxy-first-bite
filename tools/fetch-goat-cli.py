#!/usr/bin/env python3
"""Download the released goat CLI named in fabric/goat-cli.pin and verify it.

    tools/fetch-goat-cli.py <pin file> <output file>

Fetches goat-linux-<arch> of the pinned release from the public goatcore
repository, refuses it unless its SHA-256 is the pinned one, and writes it
executable. Does nothing when the output file already has the pinned digest.
Python standard library only.
"""
import hashlib
import os
import platform
import sys
import urllib.request

REPOSITORY = "https://github.com/USAREUR-AF/goatcore"


def main() -> int:
    pin_file, output = sys.argv[1], sys.argv[2]
    release, digests = "", {}
    for line in open(pin_file, encoding="utf-8"):
        words = line.split()
        if words[:1] == ["release"]:
            release = words[1]
        elif words[:1] == ["sha256"]:
            digests[words[1]] = words[2]
    arch = {"x86_64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(platform.machine())
    name = f"goat-linux-{arch}"
    if name not in digests:
        print(f"no pinned goat CLI for {platform.machine()}", file=sys.stderr)
        return 1
    if os.path.isfile(output) and hashlib.sha256(open(output, "rb").read()).hexdigest() == digests[name]:
        print(f"{name} of {release}: already here, digest verified")
        return 0
    url = f"{REPOSITORY}/releases/download/{release}/{name}"
    with urllib.request.urlopen(url, timeout=120) as response:
        data = response.read()
    found = hashlib.sha256(data).hexdigest()
    if found != digests[name]:
        print(f"{url}: SHA-256 is {found}, the pin says {digests[name]}; not written", file=sys.stderr)
        return 1
    with open(output, "wb") as out:
        out.write(data)
    os.chmod(output, 0o755)
    print(f"{name} of {release}: downloaded, SHA-256 {found[:16]}… verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
