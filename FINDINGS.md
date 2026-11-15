# Findings — behaviours a script driving these tools has to know

Each one shaped a script here.

| # | What | How the demo handles it |
|---|---|---|
| 1 | first-bite publishes a scaled value as a binary floating-point number: `44.5012345` arrives as `44.501234499999995`, `0.35` as `0.35000000000000003`. | `tools/compare-records.py` compares numbers to nine significant digits, as first-bite's own vectors do; step 5 matches the leading digits of `lat` and `lon` |
| 2 | Values in a published record are text (`"buoy_number":"7"`, `"lamp_on":"false"`); `bite decode` prints typed JSON. | the comparison reads booleans and labels as text |
| 3 | `mind` replaying a file starts reading half a second after it binds the record socket. A subscriber started later than that misses records; ZeroMQ PUB does not keep them. | steps 1 and 5 start the subscriber first, in the same container |
| 4 | The `goat` sink joins the router, announces and reads its own sample back before the first record can be published. Datagrams sent before the log line `goat: the router delivers` are decoded and not published to the fabric. | step 4 waits for that line before the buoy sends |
| 5 | `goat sub` shows the first eight digits of a slot UUID unless given `--uuid`, and prints `listening on …`, on stderr, when the subscription is live. | step 4 passes `--uuid` and waits for `listening on` |
| 6 | The stored heartbeat is the last one put. With the default 30 s interval, a read just after a burst shows the count from before it. | step 4 sets `health_interval_seconds: 2` and waits three seconds |
| 7 | Capture in a container needs `--network host`, `NET_RAW`, `NET_ADMIN` and root inside; the bridge interface must have promiscuous mode on for forwarded frames to reach the capture socket, which `mind` sets unless `--no-promiscuous` is given. | `hb_tap_start` in `lib/hello-bite.sh` |
