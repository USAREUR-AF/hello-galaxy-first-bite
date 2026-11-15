# The image every step runs: first-bite's two binaries (mind, bite) built from
# the commit in FIRST_BITE_REF, its example dictionaries and captures, and the
# Python the demo's device, shore station and subscribers need.
#
#   bin/hello-bite build          the default build of first-bite
#   bin/hello-bite build --goat   with the cargo feature `goat` (Zenoh client), for step 4
#
# Base images are the ones first-bite's own Dockerfile uses, pinned by tag and
# digest; change both together.

FROM rust:1.100.0-trixie@sha256:e19840879045c951c905d0eaa9887f3439c62000e429963371b376bac8d38c31 AS builder
ENV RUSTUP_TOOLCHAIN=1.100.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpcap-dev cmake clang git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ARG FIRST_BITE_REPO=https://github.com/USAREUR-AF/first-bite
ARG FIRST_BITE_REF
WORKDIR /src
RUN test -n "$FIRST_BITE_REF" \
    && git init -q . \
    && git remote add origin "$FIRST_BITE_REPO" \
    && git fetch -q --depth 1 origin "$FIRST_BITE_REF" \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$FIRST_BITE_REF"
# Empty for the default build; "mind/goat" adds the goat feature.
ARG FEATURES=""
ARG JOBS=8
RUN cargo build --release --locked -j "$JOBS" -p mind -p bite ${FEATURES:+--features "$FEATURES"}

FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        libpcap0.8 ca-certificates openssl python3 python3-zmq \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /src/target/release/mind /src/target/release/bite /usr/local/bin/
COPY --from=builder /src/dictionaries /usr/share/first-bite/dictionaries
COPY --from=builder /src/examples /usr/share/first-bite/examples
COPY --from=builder /src/tools/make-example-pcap.py /src/tools/extract-udp-payloads.py /usr/share/first-bite/tools/
COPY --from=builder /src/LICENSE /src/NOTICE /src/INTENT.md /usr/share/doc/first-bite/
ARG FIRST_BITE_REF
ARG FEATURES=""
LABEL org.opencontainers.image.source="https://github.com/USAREUR-AF/hello-galaxy-first-bite" \
      org.opencontainers.image.licenses="Apache-2.0" \
      first-bite.ref="$FIRST_BITE_REF" \
      first-bite.features="$FEATURES"
WORKDIR /work
