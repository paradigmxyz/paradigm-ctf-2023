FROM rust:1.73-buster AS foundry-builder

COPY patches /workdir/patches

RUN true && \
    apt-get update && \
    apt-get install -y clang && \
    cd /workdir && \
    git clone https://github.com/foundry-rs/foundry.git && \
    (cd foundry && git checkout 619f3c56302b5a665164002cb98263cd9812e4d5 && git apply ../patches/foundry.patch) && \
    git clone https://github.com/bluealloy/revm.git && \
    (cd revm && git checkout v26 && git apply ../patches/revm.patch) && \
    true

RUN true && \
    cd /workdir/foundry && \
    cargo build -p anvil && \
    true

FROM ghcr.io/foundry-rs/foundry:latest

COPY --from=foundry-builder /workdir/foundry/target/debug/anvil /usr/local/bin/anvil