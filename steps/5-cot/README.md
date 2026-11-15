# Step 5 — Cursor-on-Target out of first-bite

**A mapping in configuration turns the buoy's Position message into a
Cursor-on-Target event. The step prints the event.**

Cursor-on-Target (CoT) is the XML event format TAK and other map displays
read. first-bite's `cot` transform knows no message format: a mapping names
the fields of a decoded message that give the event its identifier, its type
and its position. The mapping for the buoy is in
[`config/subpubs.cot.yml`](../../config/subpubs.cot.yml):

```yaml
cot:
  uid: [buoy_number]
  type:
    value: "a-n-S-X"
  position:
    geodetic: [latitude, longitude, antenna_height]
  stale_minutes: 3
```

A subpub subscribes to `BUOY/Position` on the record socket, applies the
mapping and publishes the event on a second ZeroMQ socket, port 12001, as
`{"cot_datetime", "cot_xml_string"}`. It runs only when `mind` is started
with `--activate-subpubs`.

```bash
bin/hello-bite 5-cot
```

## What you should see

```text
[1] A capture file of the buoy's three messages, made from the dictionary's vectors
    $ make-example-pcap.py dictionaries/harbour-buoy .run/5-buoy.pcap
    │ /work/5-buoy.pcap: 3 packets

[3] Replay the capture with the transform on, and read the event socket
    $ tools/zmq-sub.py tcp://127.0.0.1:12001 --count 1 --field cot_xml_string &
    $ SUBPUB_CONFIG_PATH=config/subpubs.cot.yml mind --pcap-file .run/5-buoy.pcap --dictionary dictionaries/harbour-buoy --activate-subpubs
    │ BUOY/Position/CoT  <event version="2.0" uid="7" type="a-n-S-X" time="2026-11-15T12:56:59.247910689+00:00" start="2026-11-15T12:56:59.247910689+00:00" stale="2026-11-15T12:59:59.247910689+00:00" how="m-g"><point lat="44.501234499999995" lon="-30.254320999999997" hae="-1.5" ce="9999999" le="9999999"/><detail/></event>
    │ done: 3 frames, 3 records, 3 decoded, 0 not UDP or TCP, 0 malformed

[4] Verify
    ✓ three frames were decoded
    ✓ one event was published, on the Position topic
    ✓ its identifier is the buoy number
    ✓ its point is the latitude of the document's example A.3
    ✓ and its longitude and antenna height
    ✓ the height above the ellipsoid is the antenna height
```

Three frames go in and one event comes out: Status and Sea State carry no
position and the subpub does not subscribe to them.

## What the event holds, and what it does not

| Attribute | Value |
|---|---|
| `uid` | the fields listed under `uid`, joined with `_`: here the buoy number |
| `type` | the constant in the mapping; a lookup from a field's label is the other form |
| `time`, `start` | when the event was built, not a time read from the message |
| `stale` | `stale_minutes` after `time` |
| `point` | `lat`, `lon`, `hae` from the three named fields; `ce` and `le` are always `9999999`, the CoT value for an error that is not known |
| `detail` | empty |

The event goes to a ZeroMQ socket. None of the Hello Galaxy repositories has
a Cursor-on-Target consumer to send it to, so this step prints it. first-bite's
`udp` and `tcp` outputs deliver the same event to a TAK server or to TAK
clients: [cot-to-tak.md](https://github.com/USAREUR-AF/first-bite/blob/v1.1.0/docs/cot-to-tak.md). On a node that runs Open Billie for the same sensor, leave
this transform off for that sensor's track message: both would draw a marker.
[docs/00-which-tool.md](../../docs/00-which-tool.md) has the comparison.
