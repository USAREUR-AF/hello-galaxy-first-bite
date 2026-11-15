# Step 4 — onto a goat fabric

**The tap of step 2 joins a Zenoh router as a goat publisher, under a
certificate, and the released `goat` CLI receives the decoded records.**

goat is the data fabric: the mesh, the certificate authority, the Zenoh
routers and their access rules. first-bite is one of the ways data gets onto
it. Built with the cargo feature `goat`, `mind` reads a goatnet's onboarding
archive, checks the certificate, connects as a Zenoh client over mutual TLS,
and publishes each record on a key under the prefix the certificate is
granted, with a schema declaration, a service announcement and a heartbeat.
first-bite's [joining.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/goat/joining.md)
is the operator's procedure and
[contract.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/goat/contract.md)
lists what goat requires and where goat says so.

```bash
bin/hello-bite build --goat     # once
bin/hello-bite 4-fabric
```

## What this runs against

A stand-in, not a goatnet.

| Piece | Here | On a goatnet |
|---|---|---|
| Router | the stock `eclipse/zenoh:1.9.0` image, pinned by digest, the image goat runs | the same image |
| Router configuration | [`fabric/router.json5.tmpl`](../../fabric/router.json5.tmpl): the shape goat renders for a slot-pool router, with two slots and memory storage | rendered by goatcore's `goat-zenoh` role, with the whole slot pool and persistent storage |
| Certificate authority | [`fabric/make-certs.sh`](../../fabric/make-certs.sh): a throwaway root, valid two days | the goatnet's own; its portal mints your certificate |
| Onboarding archive | a directory with the four files `mind goat init` reads | a `goat-onboarding-<prefix>-<stamp>.tar.gz` from the portal |
| Reaching the router | port 17447 of this machine's loopback, by address: `tls/127.0.0.1:17447` | over the goatnet's mesh only; the host must be enrolled first |
| Subscriber | the released `goat` CLI, with a second slot's certificate in a profile directory | the same CLI, with a context collected from the goatnet |

What it shows is therefore what first-bite does toward a router with goat's
access rules. It does not show mesh enrolment, the portal, federation between
routers or anything a goatnet's operators run. goatcore's
[goatlite tutorial](https://github.com/USAREUR-AF/goatcore/blob/main/docs/tutorials/00-goatlite.md)
stands up a real one on one machine; `mind` has not been run against a real
goatnet.

## What you should see

```text
[2] What a goatnet's administrator hands over: the onboarding archive
    │ NOTES.md
    │ ca-root.pem
    │ d0d9ed2b5013cdcb04f987773f51d77f-cert.pem
    │ d0d9ed2b5013cdcb04f987773f51d77f-key.pem
    $ mind goat init --bundle .run/4/bundle --format harbour-buoy --site harbour-3 --instance tap-1 --out .run/4/goat.yml
    │ wrote /work/4/goat.yml; next: mind goat check --config /work/4/goat.yml

[3] Check it offline: nothing is sent
    $ mind goat check --config .run/4/goat.yml --dictionary dictionaries/harbour-buoy
    │ goat configuration /work/4/goat.yml
    │   ok    configuration      slot d0d9ed2b5013cdcb04f987773f51d77f
    │   ok    private key        /work/4/bundle/d0d9ed2b5013cdcb04f987773f51d77f-key.pem is readable by its owner only
    │   ok    certificate name   common name d0d9ed2b5013cdcb04f987773f51d77f
    │   ok    certificate dates  valid until 2026-11-17 12:56 UTC (1 days from now)
    │   ok    root certificate   /work/4/bundle/ca-root.pem verifies the certificate
    │
    │ router        tls/127.0.0.1:17447 (client mode, mutual TLS, host name verified)
    │ session       identifier d0d9ed2b5013cdcb04f987773f51d77f (the slot UUID)
    │
    │ the router must grant the certificate common name d0d9ed2b5013cdcb04f987773f51d77f:
    │   put  d0d9ed2b5013cdcb04f987773f51d77f/**
    │   put  attest/schema/**
    │
    │ would publish:
    │   announcement  d0d9ed2b5013cdcb04f987773f51d77f/services/shims/harbour-buoy/tap-1/announce  (at startup)
    │   health        d0d9ed2b5013cdcb04f987773f51d77f/health/shims/harbour-buoy/tap-1  (every 30 s)
    │   records of dictionary harbour-buoy 1.0.0, each with its schema:
    │     BUOY/Position
    │       record  d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/position
    │       schema  attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/position
    │     …
    │ all checks passed; nothing was sent

[4] Confirm the router delivers what this certificate writes
    $ mind goat probe --config .run/4/goat.yml
    │ delivered: a sample put on d0d9ed2b5013cdcb04f987773f51d77f/health/shims/harbour-buoy/tap-1 came back through the router after 251 ms

[5] A subscriber on the fabric: the released goat CLI, with the reader's certificate
    $ tools/fetch-goat-cli.py fabric/goat-cli.pin .run/4/goat
    │ goat-linux-amd64 of goat-cli-v0.5.14: downloaded, SHA-256 d47966d9fc3b15e3… verified
    $ goat sub 'd0d9ed2b5013cdcb04f987773f51d77f/telemetry/**' --uuid --count 9

[6] The link of step 2, with first-bite publishing to the fabric
    $ GOAT_CONFIG_PATH=.run/4/goat.yml SUBSCRIBER_CONFIG_PATH=.run/4/subscribers.yml mind hblink0 --dictionary dictionaries/harbour-buoy --filter "udp port 47200"
    │ goat: joined tls/127.0.0.1:17447 as d0d9ed2b5013cdcb04f987773f51d77f; Zenoh session d0d9ed2b5013cdcb04f987773f51d77f
    │ goat: announced on d0d9ed2b5013cdcb04f987773f51d77f/services/shims/harbour-buoy/tap-1/announce and declared 3 schema(s) under attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/**
    │ goat: the router delivers this publisher's samples (read back on d0d9ed2b5013cdcb04f987773f51d77f/health/shims/harbour-buoy/tap-1 after 0 ms)
    $ device/buoy.py --to 198.51.100.20:47200 --count 9
    buoy 7: sent 9 datagrams to 198.51.100.20:47200

[7] What the goat CLI received
    │ listening on `d0d9ed2b5013cdcb04f987773f51d77f/telemetry/**` via tls/127.0.0.1:17447 — stopping after 9 event(s). Ctrl-C to stop.
    │ d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/status {"timestamp":{"secs_since_epoch":1794747409,…
    │ d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/sea_state {"timestamp":{"secs_since_epoch":1794747409,…
    │ d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/position {"timestamp":{"secs_since_epoch":1794747409,…
    │ …
    │ done after 3s — 9 event(s) on `d0d9ed2b5013cdcb04f987773f51d77f/telemetry/**` (the requested 9)

[8] The announcement, the heartbeat and the schema declarations, read from the router's storage
    $ mind goat watch 'd0d9ed2b5013cdcb04f987773f51d77f/services/**' --stored --payload --config .run/4/reader.yml
    │ d0d9ed2b5013cdcb04f987773f51d77f/services/shims/harbour-buoy/tap-1/announce  application/json  325 bytes
    │ {"capabilities":["publish"],"class":"harbour-buoy","config_digest":"sha256:9d09…","instance":"tap-1","site":"harbour-3","translates_from":"harbour-buoy 1.0.0","translates_to":["d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/**"],"version":"0.1.0"}
    $ mind goat watch 'd0d9ed2b5013cdcb04f987773f51d77f/health/**' --stored --payload --config .run/4/reader.yml
    │ d0d9ed2b5013cdcb04f987773f51d77f/health/shims/harbour-buoy/tap-1  application/json  252 bytes
    │ {"class":"harbour-buoy","instance":"tap-1","records_failed":0,"records_not_decoded":0,"records_published":9,"site":"harbour-3","started":"…","status":"ok","time":"…","version":"0.1.0"}
    $ mind goat watch 'attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/**' --stored --config .run/4/reader.yml
    │ attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/position  application/json  4104 bytes
    │ attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/status  application/json  3995 bytes
    │ attest/schema/d0d9ed2b5013cdcb04f987773f51d77f/telemetry/harbour-buoy/harbour-3/buoy/sea_state  application/json  4137 bytes

[9] Verify
    ✓ offline, the certificate, its name, its dates and its root are in order
    ✓ check lists the key each message will be published on
    ✓ the router delivers this certificate's writes
    ✓ the sink joined as the slot
    ✓ the shore station still received every datagram from the buoy
    ✓ the goat CLI received a Status record from the fabric
    ✓ the goat CLI received a Sea State record
    ✓ the goat CLI received a Position record
    ✓ the announcement is stored under the slot
    ✓ the heartbeat counts the records published
    ✓ a schema is declared for each record key
```

## What to read in that output

| Line | Says |
|---|---|
| `d0d9ed2b…` everywhere | the slot UUID. It is the certificate's common name, the router's access-control subject, the first chunk of every key the holder may write, and the Zenoh session identifier. The two UUIDs of this step are `sha256("hello-galaxy-first-bite:<n>")` cut to 32 digits, the way goat derives a slot pool from a salt |
| `…/telemetry/harbour-buoy/harbour-3/buoy/position` | `<prefix>/telemetry/<format>/<site>/<interface>/<message>`: one key per message of the dictionary, never one per packet |
| `attest/schema/<record key>` | a JSON Schema for each record key, made from the dictionary, so a consumer can read a topic it has never seen |
| `…/services/shims/…/announce`, `…/health/shims/…` | the service says what it translates and that it is alive, as goat asks of a shim |
| `mind goat probe`: `delivered` | a goat router drops a write its rules do not grant and returns success. Reading the sample back is the only check a publisher has |
| the subscriber is `goat sub` | the consumer needs no first-bite: it reads the fabric with goat's own tool and a certificate of its own |

`mind goat check` prints the two grants the router must hold for the
certificate. On a goatnet, those two lines are what to send the administrator
when the probe says `not delivered`.

The heartbeat is every 30 s by default; this step writes
`health_interval_seconds: 2` into the generated configuration so the count can
be read without a wait. The step uses ports 12000 and 17447 of the host's
loopback; `HB_ZMQ_PORT` and `HB_ROUTER_PORT` choose others. It downloads the
`goat` CLI of the release named in [`fabric/goat-cli.pin`](../../fabric/goat-cli.pin)
and refuses a binary whose SHA-256 is not the pinned one.
