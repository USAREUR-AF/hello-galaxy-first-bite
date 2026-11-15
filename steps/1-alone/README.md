# Step 1 — first-bite alone

**A dictionary, a capture file, and decoded records on a ZeroMQ socket.** No
goat, no network, nothing to configure.

first-bite is two programs. `bite` is the decoder and the dictionary tool: it
has no network code. `mind` is the pipeline: it reads frames from an interface
or a capture file, finds the dictionary's interface by UDP or TCP port,
decodes the payload and publishes one JSON record per packet on a ZeroMQ PUB
socket, `tcp://127.0.0.1:12000` unless configured otherwise.

The dictionary here is first-bite's own `ntp` example: the Network Time
Protocol header of RFC 5905, 48 bytes on UDP port 123.

```bash
bin/hello-bite 1-alone
```

## What you should see

```text
[1] Check the dictionary and run its test vectors
    $ bite check --strict /usr/share/first-bite/dictionaries/ntp
    │ 1 interfaces, 5 messages, 0 errors, 0 warnings (1 allowed in dictionary.json), 10/10 vectors passed

[2] Decode one payload by hand: a reply from a time server
    $ bite decode /usr/share/first-bite/dictionaries/ntp --port 123 240206e90000060000000a80c0000201ed135500c0000000ed13554040000000ed13554043000000ed13554043800000
    │ {
    │   "fields": {
    │     "leap_indicator": "no warning",
    │     "mode": "server",
    │     …
    │     "stratum": 2,
    │     "transmit_timestamp_fraction": 0.263671875,
    │     "transmit_timestamp_seconds": 3977467200,
    │     "version_number": 4
    │   },
    │   "interface": "NTP",
    │   "message_type": "server"
    │ }

[3] Replay a capture through the whole pipeline and read the record socket
    $ tools/zmq-sub.py tcp://127.0.0.1:12000 --count 10 --field message &
    $ mind --pcap-file /usr/share/first-bite/examples/ntp.pcap --dictionary /usr/share/first-bite/dictionaries/ntp
    │ NTP/broadcast  {"leap_indicator":"no warning","mode":"broadcast","origin_timestamp_fraction":"0",…
    │ NTP/client  {"leap_indicator":"no warning","mode":"client","origin_timestamp_fraction":"0",…
    │ NTP/NTP control message  {}
    │ NTP/7  {}
    │ NTP/server  {"leap_indicator":"unknown (clock unsynchronized)","mode":"server",…
    │ …
    │ done: 10 frames, 10 records, 10 decoded, 0 not UDP or TCP, 0 malformed

[4] Verify
    ✓ the dictionary loads and all ten of its vectors pass
    ✓ the payload decodes to a server reply at stratum 2
    ✓ mind decoded every frame of the capture
    ✓ ten records arrived on the ZeroMQ socket
    ✓ a record is published on <interface>/<message>
    ✓ its fields carry the dictionary's labels
```

Each message on the socket is `<topic>|<JSON>`, and the topic is
`<interface>/<message>`, so a subscriber takes `NTP/server` and nothing else
by subscribing to that prefix. `NTP/NTP control message` is a message the
dictionary names and does not define: identified, no field decoded. `NTP/7` is
an identifier the dictionary does not name. The record also carries the
packet's addresses, ports and capture time and the frame itself in base64;
`tools/zmq-sub.py` without `--field` prints all of it.

## Live, on your own network

```bash
bin/hello-bite 1-alone --live eth0      # the interface that carries your traffic: ip -br link
```

The same decoder on traffic the machine already carries. The step starts
`mind` on the interface with the filter `udp port 123`, sends one request to
`pool.ntp.org` to provoke a reply, and prints the two records:

```text
[5] Live: NTP on interface eno1
    $ mind eno1 --dictionary /usr/share/first-bite/dictionaries/ntp --filter "udp port 123"
    │ NTP/client  {"leap_indicator":"no warning","mode":"client","origin_timestamp_fraction":"0",…
    │ NTP/server  {"leap_indicator":"no warning","mode":"server","origin_timestamp_fraction":"0","origin_timestamp_seconds":"0","poll":"3","precision":"-25",…
    │ done: 2 frames, 2 records, 2 decoded, 0 not UDP or TCP, 0 malformed
    ✓ the request was seen on the wire and decoded
    ✓ the server's reply was seen on the wire and decoded
```

Capture needs the host's network namespace, the capabilities `NET_RAW` and
`NET_ADMIN`, and root in the container; the step passes exactly those. It
needs a route to the internet for the one request. CI does not run it.

first-bite's [`dictionaries/ntp`](https://github.com/USAREUR-AF/first-bite/tree/main/dictionaries/ntp)
says how to read the values: the timestamps count from 1900, the reference
identifier is an address or a clock name depending on the stratum.

## Without the container

The image is a convenience. first-bite builds with `make build` on Linux and
macOS, given a Rust toolchain, a C compiler, CMake and the libpcap headers;
its [README](https://github.com/USAREUR-AF/first-bite#try-it) has the same
three commands against a local build. `v1.0.1-rc.1` is a release candidate;
for a published release,
[deployment.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/deployment.md)
is how to install it.
