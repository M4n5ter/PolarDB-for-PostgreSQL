# mst1208/polardb-binary:ubuntu-24.04

FROM mst1208/polardb-pg-devel:ubuntu-24.04 AS building
LABEL maintainer="m4n5terrr@gmail.com"

# Copy source code
WORKDIR /home/postgres/
COPY . ./polardb_pg

USER root

SHELL ["/bin/bash", "-c"]

# rustup
RUN (rustup self update || RUSTUP_DIST_SERVER=https://static.rust-lang.org RUSTUP_UPDATE_ROOT=https://static.rust-lang.org/rustup rustup self update) && (rustup update || RUSTUP_DIST_SERVER=https://static.rust-lang.org RUSTUP_UPDATE_ROOT=https://static.rust-lang.org/rustup rustup update)

# Compile and install PolarDB-PG
WORKDIR /home/postgres/polardb_pg
# include cargo binaries for extensions that run cargo during make
ENV PATH=/root/.cargo/bin:/u01/polardb_pg/bin:$PATH
ENV PGRX_HOME=/root/.pgrx
RUN mkdir -p $PGRX_HOME
ENV PG_CONFIG=/u01/polardb_pg/bin/pg_config
# pg_duckdb Makefile
ENV ERROR_ON_WARNING=0
# Release/ReleaseStatic
ENV DUCKDB_BUILD=Release

# Patch pg_net(v0.8.0) worker to avoid deprecated CURLOPT usage on newer libcurl
RUN sed -i 's/CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS/CURLOPT_PROTOCOLS_STR, "http,https"/' external/pg_net/src/worker.c
# Remove duplicate BackgroundWorkerHandle definition in pg_cron (PG15 already provides it)
RUN sed -i '/struct BackgroundWorkerHandle/,/};/d' external/pg_cron/include/task_states.h

RUN ./build.sh --ec="--prefix=/u01/polardb_pg/" --debug=off --quiet=off --ni --port=5432

RUN set -euo pipefail && \
    install_default() { cargo install --locked cargo-pgrx; } && \
    install_alt_home() { CARGO_HOME=/tmp/cargo-official cargo install cargo-pgrx; } && \
    install_binstall() { cargo install cargo-binstall && cargo binstall cargo-pgrx --no-confirm; } && \
    (install_default || install_alt_home || install_binstall) && \
    command -v cargo-pgrx >/dev/null && cargo pgrx --version

# Initialize cargo-pgrx config so later installs can find pg_config
RUN cargo pgrx init --pg15=$PG_CONFIG

# Build cargo-based extensions that require cargo/pgrx manually
WORKDIR /home/postgres/polardb_pg
RUN (PG_CONFIG=$PG_CONFIG make -C external/VectorChord build || \
    CARGO_HOME=/tmp/cargo-official PG_CONFIG=$PG_CONFIG make -C external/VectorChord build) && \
    PG_CONFIG=$PG_CONFIG make -C external/VectorChord install

WORKDIR /home/postgres/polardb_pg/external/VectorChord-bm25
RUN cargo pgrx install --sudo --release --features "pg15" --pg-config $PG_CONFIG || CARGO_HOME=/tmp/cargo-official cargo pgrx install --sudo --release --features "pg15" --pg-config $PG_CONFIG

WORKDIR /home/postgres/polardb_pg/external/pg_tokenizer.rs
RUN cargo pgrx install --sudo --release --features "pg15 lindera-ipadic" --pg-config $PG_CONFIG || CARGO_HOME=/tmp/cargo-official cargo pgrx install --sudo --release --features "pg15 lindera-ipadic" --pg-config /u01/polardb_pg/bin/pg_config

WORKDIR /home/postgres/polardb_pg

# Install PostGIS
# WORKDIR /home/postgres
RUN wget --no-verbose https://download.osgeo.org/postgis/source/postgis-3.5.2.tar.gz && \
    tar -zxf postgis-3.5.2.tar.gz && \
    cd postgis-3.5.2 && \
    ./configure -q && \
    make -s -j$(nproc) && \
    make -s install

# Build and install pg_net extension separately
WORKDIR /home/postgres/polardb_pg/external/pg_net
RUN PG_CONFIG=$PG_CONFIG make clean && \
    PG_CONFIG=$PG_CONFIG make -j$(nproc) && \
    PG_CONFIG=$PG_CONFIG make install
