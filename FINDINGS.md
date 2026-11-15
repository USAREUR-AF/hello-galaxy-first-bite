# Findings — behaviours a script driving these tools has to know

Each one shaped a script here.

| # | What | How the demo handles it |
|---|---|---|
| 1 | A record carries each value as the type its field declares (`"buoy_number":7`, `"lamp_on":false`, `"latitude":44.5012345`); `FIRST_BITE_RECORD_VERSION=1` publishes every value as text instead (`"lamp_on":"false"`). | `tools/compare-records.py` takes a decoded value as it is and accepts either form; numbers are compared to nine significant digits, as first-bite's own vectors do; step 5 matches the leading digits of `lat` and `lon` |
| 2 | `mind` delivers what its sinks were given before it exits: on a stop signal or at the end of a capture file it waits up to `--drain-seconds` (default 30) and logs `sink <name>: <n> delivered, <n> failed, <n> abandoned`. | step 4 stops the tap with `docker stop -t 40` and checks the goat sink's line |
| 3 | `mind` replaying a file starts reading half a second after it binds the record socket. A subscriber started later than that misses records; ZeroMQ PUB does not keep them. | steps 1 and 5 start the subscriber first, in the same container |
| 4 | The `goat` sink joins the router, announces and reads its own sample back before the first record can be published. Datagrams sent before the log line `goat: the router delivers` are decoded and not published to the fabric. | step 4 waits for that line before the buoy sends |
| 5 | `goat sub` shows the first eight digits of a slot UUID unless given `--uuid`, and prints `listening on …`, on stderr, when the subscription is live. | step 4 passes `--uuid` and waits for `listening on` |
| 6 | The stored heartbeat is the last one put. With the default 30 s interval, a read just after a burst shows the count from before it. | step 4 sets `health_interval_seconds: 2` and waits three seconds |
| 7 | Capture in a container needs `--network host`, `NET_RAW`, `NET_ADMIN` and root inside; the bridge interface must have promiscuous mode on for forwarded frames to reach the capture socket, which `mind` sets unless `--no-promiscuous` is given. | `hb_tap_start` in `lib/hello-bite.sh` |
