# hello-galaxy-first-bite

**Two systems exchange binary messages in a format of their own, and neither
can be changed. How do you get what they say onto a goatnet? Five runnable
steps: decode a capture, tap a link, turn the interface document into a
dictionary, publish to a goat fabric, and make Cursor-on-Target.**

This is a repo in the **Hello Galaxy** series: small, self-contained, runnable
examples of best practice in one dimension. Like the rest of the series, it is
a short runbook per step plus one driver script that narrates what happens.
The equipment is simulated and the goat router is a stand-in; everything else
runs for real: [first-bite](https://github.com/USAREUR-AF/first-bite) built
from a pinned commit, the stock Zenoh router goat runs, and the released
`goat` CLI. Where something here is not what a deployment has, the step says
so.

---

## The question this repo answers

A great deal of fielded equipment speaks a one-off binary wire format, defined
in an interface document and compiled into both ends. Changing either end
means re-qualifying it, so the data stays sealed between the two machines
built to exchange it.

first-bite does not change them. It reads a copy of what is already on the
wire, decodes it from a description of the format kept as data, and publishes
one JSON record per message. With goat's optional feature it publishes those
records on a goatnet under the identity and the rules the goatnet gives it,
and any consumer reads them with goat's own tools.

Read [`docs/00-which-tool.md`](docs/00-which-tool.md) to decide whether
first-bite is the tool: Open Billie, octo-pod and a native Zenoh publisher
take other parts of the same job.

## The five steps

| Step | What it shows | Runs | Ends by proving |
|---|---|---|---|
| [**1 alone**](steps/1-alone/) | `bite` checks a dictionary and decodes a payload; `mind` replays a capture and publishes records on a ZeroMQ socket. With `--live`, NTP on your own network | offline; `--live` needs an interface and the internet | 10 of 10 frames decoded and received by a subscriber |
| [**2 tap**](steps/2-tap/) | a simulated buoy sends fixed-layout datagrams to its shore station; first-bite decodes a copy from the bridge between them | offline, Linux | the shore station received all 9 from the buoy; 9 of 9 decoded values equal what the buoy encoded |
| [**3 dictionary**](steps/3-dictionary/) | the buoy's interface document becomes a dictionary with `bite new`, `range`, `import-csv`, `fmt`, `check`, `lint`, `coverage`, `vectors` | offline | every gate passes and the result equals `dictionaries/harbour-buoy` byte for byte |
| [**4 fabric**](steps/4-fabric/) | `mind goat init`, `check`, `probe`; the tap publishes to a router with goat's access rules; `goat sub` receives the records; the announcement, heartbeat and schemas are read back | a stand-in router on loopback; downloads the `goat` CLI | the `goat` CLI received a record of each message; 9 published; 3 schemas declared |
| [**5 cot**](steps/5-cot/) | first-bite's `cot` transform turns the buoy's Position into a Cursor-on-Target event | offline | one event with the buoy's number and position |

## Run it

Prerequisites: Linux, `bash` and Docker. Nothing else is installed on the
host: first-bite, the simulated equipment and every subscriber run in
containers of one image.

```bash
bin/hello-bite build --goat     # first-bite at the pinned commit, with the goat feature
bin/hello-bite all              # the five steps in order
```

`bin/hello-bite <step>` runs one; `bin/hello-bite list` names them;
`bin/hello-bite clean` removes the containers, the network, the images and
`.run/`. Steps 1, 2, 3 and 5 also run on the default build,
`bin/hello-bite build`.

CI builds the image with the goat feature and runs the five steps on a
GitHub-hosted Ubuntu runner; `--live` of step 1 is run by hand only.

| Measured on one machine (16 cores, `-j 8`, Docker 29.6) | |
|---|---|
| `bin/hello-bite build`, base images cached: first-bite cloned and compiled | 2 min 2 s |
| `bin/hello-bite build --goat`, base images cached: first-bite compiled with the Zenoh client | 2 min 18 s |
| image size | 54 MB default, 59 MB with goat |
| `bin/hello-bite all`, router image and `goat` CLI already downloaded | 42 s |

### On macOS

Not run. Steps 1 (without `--live`), 3 and 5 are plain containers with no
network and need only Docker. Steps 2 and 4 capture on the interface of a
Docker bridge, and `--live` captures on a host interface; under Docker Desktop
those interfaces belong to Docker's virtual machine, not to the Mac.
first-bite itself builds and captures on macOS; its
[README](https://github.com/USAREUR-AF/first-bite#try-it) has the commands.

## What is pinned

| What | Pin | Change it in |
|---|---|---|
| first-bite | commit `d65b0389013ca36e14d27b5e802d16e9390f7f5f`, which is the release `v1.1.0` | [`FIRST_BITE_REF`](FIRST_BITE_REF) holds the commit, not the tag name, so a moved tag cannot change what is built; put the commit of the next release there |
| Build and runtime base images | `rust:1.100.0-trixie` and `debian:trixie-slim` by digest, the two first-bite's own Dockerfile uses | [`image/Dockerfile`](image/Dockerfile) |
| Zenoh router | `eclipse/zenoh:1.9.0` by digest, the image goat runs and hello-galaxy-zagros-pod pins | `HB_ROUTER_IMAGE` in [`lib/hello-bite.sh`](lib/hello-bite.sh) |
| `goat` CLI | release `goat-cli-v0.5.14` of goatcore, by SHA-256 | [`fabric/goat-cli.pin`](fabric/goat-cli.pin) |
| GitHub Actions | by commit SHA | [`.github/workflows/`](.github/workflows) |

## What is deliberately simplified, and what to copy

The link of steps 2 and 4 is a Docker bridge and the tap is a capture socket
on it. That reproduces "reads a copy, changes neither end"; it does not
reproduce a passive tap's physical inability to transmit.
[Step 2](steps/2-tap/#what-the-tap-is-and-what-it-is-not) has the table.

The fabric of step 4 is one stock router with goat's slot-pool access rules
and a throwaway certificate authority. It is not a goatnet: no mesh, no
portal, no federation. [Step 4](steps/4-fabric/#what-this-runs-against) has
the table. `mind` has not been run against a real goatnet.

**Copy the dictionary method, the gates, the `mind goat` sequence (init,
check, probe, then publish) and the key shapes; replace the bridge with a tap
and the stand-in with your goatnet.** [`docs/do-it-for-real.md`](docs/do-it-for-real.md)
says where each procedure is.

## Repo layout

```
bin/hello-bite            dispatcher: build, <step>, all, list, clean
lib/hello-bite.sh         shared narration / assertion / container library
FIRST_BITE_REF            the first-bite commit every step runs
image/Dockerfile          first-bite's mind and bite built from that commit, plus Python for the demo's tools
steps/                    1-alone, 2-tap, 3-dictionary, 4-fabric, 5-cot: README + run.sh each
icd/HB-ICD-001-A.md       the invented interface document of the harbour buoy
icd/tables/               the four CSV tables typed from it
dictionaries/harbour-buoy the dictionary step 3 builds; steps 2, 4 and 5 decode with it
device/buoy.py            the simulated buoy: the document's three messages over UDP, written with struct
device/shore.py           the shore station: binds the port, counts datagrams and their sources
tools/zmq-sub.py          subscriber for first-bite's record socket
tools/compare-records.py  what the buoy encoded against what first-bite decoded
tools/fetch-goat-cli.py   download the pinned goat CLI and verify its SHA-256
fabric/                   the stand-in goatnet: certificate script, router configuration, goat CLI pin
config/subpubs.cot.yml    the Cursor-on-Target mapping of step 5
docs/                     00-which-tool, do-it-for-real
FINDINGS.md               behaviours of first-bite and the goat CLI a script driving them has to know
```

## How this maps to first-bite and goat

| Here | In first-bite | In goat |
|---|---|---|
| step 1 | `README.md` "Try it"; `dictionaries/ntp` | |
| step 2 | `docs/tap.md`; `docs/architecture.md` | |
| step 3 | `docs/icd-to-dictionary/`, `docs/dictionary-format.md` | |
| step 4 | `docs/goat-integration.md`, `docs/goat/joining.md`, `docs/goat/contract.md`, `tools/goat-selftest.sh` | goatcore `ops/ansible/roles/goat-zenoh/templates/config.json5.j2` (the router configuration), `docs/adr/1025-zenoh-dynamic-tenant-authz-slot-pool.md` (slots), `docs/tutorials/00-goatlite.md` |
| step 5 | `cotify/README.md`, `flow/config/subpubs.example.yml` | |
| `docs/00-which-tool.md` | `docs/related-projects.md` | |

One of the Hello Galaxy series of runnable goat demonstrations.

## Licence

`hello-galaxy-first-bite` was written by U.S. Federal government employees. In the U.S. it is not subject to copyright and is in the public domain; in countries where copyright is recognized, it is released under the [Apache License 2.0](LICENSE). See [INTENT.md](INTENT.md).
