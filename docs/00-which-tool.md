# Which tool?

Equipment that speaks its own binary format reaches a goat fabric by one of
four routes. They do different parts of the job, and two of them can run on
the same feed at once. This page is the decision; the detail, with the file
in each project that every statement comes from, is first-bite's
[related-projects.md](https://github.com/USAREUR-AF/first-bite/blob/main/docs/related-projects.md).

| You want | Use | Because |
|---|---|---|
| the equipment's data on the fabric, and you can change the equipment's software | a native Zenoh publisher | nothing stands between the source and the fabric; [hello-galaxy-zenoh-patterns](https://github.com/USAREUR-AF/hello-galaxy-zenoh-patterns) is how to shape its keys |
| to see or record everything two systems say to each other, without touching either | [first-bite](https://github.com/USAREUR-AF/first-bite) | it listens on a tap or mirror port and binds nothing; the message set is a dictionary, so a new one needs no code |
| status, configuration and command messages as well as tracks | first-bite | it publishes every message the dictionary defines, with the source's own field names |
| a sensor's tracks as Cursor-on-Target, ASTERIX CAT062 or SAPIENT, one identity scheme across sensors | [Open Billie](https://github.com/USAREUR-AF/open-billie) | a sensor-specific package (a kid) maps the sensor to a canonical track; a shared translator encodes it |
| a feed carried off a site unchanged, attributed to its source, released only by decision, with a local record | [octo-pod](https://github.com/USAREUR-AF/octo-pod) | it captures bytes without reading them, under a certificate per source, a release gate and an audit record |
| the bytes of a feed visible to others on the goatnet, nobody yet committed to decoding it | the mirror rung of [hello-galaxy-legacy-feed](https://github.com/USAREUR-AF/hello-galaxy-legacy-feed) | bytes stay bytes on a `volatile/` key, with a digest per frame |

## What each does with a datagram

| | Native publisher | first-bite | Open Billie | octo-pod |
|---|---|---|---|---|
| Where the bytes come from | the equipment's own software | frames captured on an interface, or a capture file | a port the sensor sends to | a port the sensor sends to, or a connection the pod dials |
| Does the sensor's configuration change | yes: its software is the publisher | no | yes: it is pointed at the node | yes: it is pointed at the pod |
| Does it read the payload | it made the payload | every field, from a dictionary | the kid's decoder and mapping | no |
| What lands on the fabric | whatever the publisher puts | one JSON record per message, on `<prefix>/telemetry/<format>/<site>/<interface>/<message>` | tracks, as CoT XML, ASTERIX CAT062 or SAPIENT | the bytes that arrived |
| A new message set needs | code | a dictionary: JSON files | a kid: decoder, schemas, mapping | nothing |

## Together

| Combination | Status |
|---|---|
| first-bite beside an Open Billie kid or an octo-pod arm on the same sensor. The kid or arm binds the port the sensor sends to; first-bite captures the same datagrams and binds nothing, and their keys do not collide | follows from each one's code; not run together, and not run here |
| an Open Billie kid whose decoder is the `bite` library and a dictionary, so one dictionary serves the tap and the kid | [open-billie pull request 26](https://github.com/USAREUR-AF/open-billie/pull/26), open, not merged; not run here |
| first-bite publishing into an octo-pod as a peer, so the decoded stream gets the pod's certificate, release gate and audit | designed in related-projects.md; not measured, and not run here |
| first-bite decoding payloads an octo-pod captured | designed, not built |
| Cursor-on-Target from both first-bite and Open Billie for one track | do not: the events differ and a display shows two markers. Produce CoT in one place |

## What this repository ran

Steps 1 to 5 run first-bite by itself, on a simulated link, and against a
stand-in for a goat router, with the released `goat` CLI as the subscriber.
Open Billie, octo-pod and a native publisher were not run here; the rows
above about them are taken from first-bite's related-projects.md and their
own repositories.

## With hello-galaxy-legacy-feed

That repository answers a neighbouring question: a feed in a legacy format
(its example is ASTERIX) is already arriving at a peer of a goatnet, and
there are three things to do with it: carry it, mirror the bytes, or decode
it with an adapter written for the format. first-bite fits where the feed
cannot be pointed at anything: it runs between two systems that will not be
reconfigured, and the copy comes from a tap. Its decode is the dictionary of
step 3, not code, for a format whose messages have a fixed layout. ASTERIX
records are variable in length and are not such a format; first-bite does not
decode them.
