# Step 2 — a tap on a link you cannot change

**Two systems exchange fixed-layout binary datagrams. first-bite reads a copy
and publishes every field. Neither system is changed, reconfigured or aware
of it.**

The two systems are containers. `device/buoy.py` is a harbour buoy that sends
the three messages of [`icd/HB-ICD-001-A.md`](../../icd/HB-ICD-001-A.md) to
its shore station, `device/shore.py`, which binds UDP port 47200 and counts
what arrives. Both are written from the interface document with Python's
`struct` and `socket`; neither imports or mentions first-bite. They share a
Docker bridge network with documentation addresses.

```text
 hb-buoy 198.51.100.10 ──UDP 47200──▶ hb-shore 198.51.100.20
                  └──── bridge hblink0 ────┘
                              │ copy of every frame
                         hb-tap: mind hblink0   ──▶ ZeroMQ PUB 127.0.0.1:12000 ──▶ hb-sub
```

```bash
bin/hello-bite 2-tap
```

## What the tap is, and what it is not

`mind` runs in a third container that shares the host's network namespace and
opens a capture socket on the bridge's interface, `hblink0`, in promiscuous
mode. The kernel hands such a socket a copy of every frame the bridge
forwards. That is what a mirror port of a switch gives: the copy is made by
the device doing the forwarding.

| | Here | A passive tap | A switch mirror port |
|---|---|---|---|
| Who copies the frames | the Linux bridge, to a capture socket | optics or a hub, with no software | the switch |
| Can first-bite's host put a frame on the link | yes: the host has an address on the bridge. `mind` opens a capture socket and never writes to it | no: there is no transmit path | depends on the switch's configuration |
| Is either end configured for it | no | no | no |
| Can copies be lost without the link noticing | yes, when the capture buffer overflows; `mind` reports the count | no | yes, the switch drops mirrored frames first |

So this step reproduces "reads a copy, changes neither end" and it reproduces
"sends nothing" as behaviour, not as a physical guarantee. On real equipment
the guarantee comes from the tap; first-bite's
[tap.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/tap.md)
covers taps, mirror ports and tunnelled mirrors.

The step proves what it claims from three independent places: the shore
station's own count and the source address of each datagram, `mind`'s count
of frames seen and decoded, and a comparison of every decoded value with the
value the buoy printed when it encoded it.

## What you should see

```text
[1] The link: a Docker bridge, a buoy and a shore station
    network hb-link (198.51.100.0/24, internal), bridge interface hblink0
    buoy 198.51.100.10  →  shore station 198.51.100.20, UDP port 47200
    $ device/shore.py --listen 0.0.0.0:47200 --count 9        (container hb-shore)

[2] The tap: first-bite captures on the bridge's interface
    mind opens a capture socket on hblink0 in promiscuous mode, so it is handed a copy of every
    frame the bridge forwards. It binds no port of the link and is the address of no datagram.
    $ mind hblink0 --dictionary dictionaries/harbour-buoy --filter "udp port 47200"        (container hb-tap, host network)
    $ tools/zmq-sub.py tcp://127.0.0.1:12000 --count 9 --field message        (container hb-sub)

[3] The buoy sends 9 datagrams
    $ device/buoy.py --to 198.51.100.20:47200 --count 9        (container hb-buoy)
    │ {"sent": 1, "message": "Status", "sequence_number": 100, "bytes": "010470644cec05a0", "operating_mode": "Reporting", "lamp_on": false, "mooring_alarm"
    │ {"sent": 2, "message": "Sea State", "sequence_number": 101, "bytes": "02067065ff833ad18e992730", "water_temperature": -1.25, "significant_wave_height"
    │ {"sent": 3, "message": "Position", "sequence_number": 102, "bytes": "030870661a865979edf78e9643879ff1", "latitude": 44.5012345, "longitude": -30.25432
    │ {"sent": 4, "message": "Status", "sequence_number": 103, "bytes": "010470676ce905a1", "operating_mode": "Reporting", "lamp_on": true, "mooring_alarm":
    │ {"sent": 5, "message": "Sea State", "sequence_number": 104, "bytes": "02067068ffab3c92911a272c", "water_temperature": -0.85, "significant_wave_height"
    │ {"sent": 6, "message": "Position", "sequence_number": 105, "bytes": "030870691a86539dedf796ca43889ff2", "latitude": 44.5010845, "longitude": -30.25411
    │ {"sent": 7, "message": "Status", "sequence_number": 106, "bytes": "0104706a5ce605a2", "operating_mode": "Reporting", "lamp_on": false, "mooring_alarm"
    │ {"sent": 8, "message": "Sea State", "sequence_number": 107, "bytes": "0206706bffd33e53939b2728", "water_temperature": -0.45, "significant_wave_height"
    │ {"sent": 9, "message": "Position", "sequence_number": 108, "bytes": "0308706c1a864dc1edf79efe43899ff3", "latitude": 44.5009345, "longitude": -30.25390

[4] What the shore station received
    │ shore: datagram 7: 8 bytes from 198.51.100.10
    │ shore: datagram 8: 12 bytes from 198.51.100.10
    │ shore: datagram 9: 16 bytes from 198.51.100.10
    │ shore: received 9 of 9 datagrams: 9 from 198.51.100.10

[5] What first-bite published
    │ BUOY/Status  {"battery_voltage":12.6,"buoy_number":7,"lamp_on":false,"message_id":1,"message_length":4,"mooring_alarm":false,"operating_mode":"Reporti
    │ BUOY/Sea State  {"air_pressure":1003.2,"buoy_number":7,"message_id":2,"message_length":6,"sequence_number":101,"significant_wave_height":2.35,"water_t
    │ BUOY/Position  {"antenna_height":-1.5,"buoy_number":7,"drift_course":135,"drift_speed":0.35,"latitude":44.5012345,"longitude":-30.254321,"message_id":
    │ BUOY/Status  {"battery_voltage":12.57,"buoy_number":7,"lamp_on":true,"message_id":1,"message_length":4,"mooring_alarm":false,"operating_mode":"Reporti
    │ BUOY/Sea State  {"air_pressure":1002.8,"buoy_number":7,"message_id":2,"message_length":6,"sequence_number":104,"significant_wave_height":2.42,"water_t
    │ BUOY/Position  {"antenna_height":-1.4,"buoy_number":7,"drift_course":135,"drift_speed":0.4,"latitude":44.5010845,"longitude":-30.254111,"message_id":3
    │ BUOY/Status  {"battery_voltage":12.54,"buoy_number":7,"lamp_on":false,"message_id":1,"message_length":4,"mooring_alarm":true,"operating_mode":"Reporti
    │ BUOY/Sea State  {"air_pressure":1002.4,"buoy_number":7,"message_id":2,"message_length":6,"sequence_number":107,"significant_wave_height":2.49,"water_t
    │ BUOY/Position  {"antenna_height":-1.3,"buoy_number":7,"drift_course":135,"drift_speed":0.45,"latitude":44.5009345,"longitude":-30.253901,"message_id":
    │ capture hblink0: 11 seen by kernel, 0 dropped by kernel, 0 by interface, 0 in queue
    │ done: 9 frames, 9 records, 9 decoded, 0 not UDP or TCP, 0 malformed

[6] Compare each decoded record with what the buoy encoded
    $ tools/compare-records.py .run/2-buoy.jsonl .run/2-records.txt
    │ sequence 100 BUOY/Status: 6 values equal
    │ sequence 101 BUOY/Sea State: 6 values equal
    │ sequence 102 BUOY/Position: 6 values equal
    │ sequence 103 BUOY/Status: 6 values equal
    │ sequence 104 BUOY/Sea State: 6 values equal
    │ sequence 105 BUOY/Position: 6 values equal
    │ sequence 106 BUOY/Status: 6 values equal
    │ sequence 107 BUOY/Sea State: 6 values equal
    │ sequence 108 BUOY/Position: 6 values equal
    │ 9 of 9 records match what the buoy encoded

[7] Verify
    ✓ the shore station received every datagram, all from the buoy
    ✓ first-bite saw the same 9 frames and decoded each
    ✓ nothing was dropped on the way to the decoder
    ✓ every record reached the ZeroMQ socket
    ✓ every decoded value is the value the buoy encoded

✓ step complete — every assertion held.
```

A record carries each value as the type its field declares: a scaled value
as the decimal the scale gives (`44.5012345`), a flag as `true` or `false`, a
label as text. The comparison takes numbers to nine significant digits, as
first-bite's own vectors compare. `FIRST_BITE_RECORD_VERSION=1` makes `mind`
publish every value as text instead, and the comparison accepts that form too.

The dictionary that turns the bytes into those names is
`dictionaries/harbour-buoy`. [Step 3](../3-dictionary/) builds it from the
interface document.

This step needs Linux: the bridge's interface has to be visible to the
container that captures. It uses port 12000 of the host's loopback for the
record socket; `HB_ZMQ_PORT=<port>` chooses another.
