FROM mst1208/polardb-pg-devel:ubuntu-24.04 AS building
LABEL maintainer="m4n5terrr@gmail.com"

# Copy source code
WORKDIR /home/postgres/
COPY . ./polardb_pg

USER root

# rustup
RUN bash -lc "rustup self update && rustup update"

# Compile and install PolarDB-PG
WORKDIR /home/postgres/polardb_pg
# include cargo binaries for extensions that run cargo during make
ENV PATH=/root/.cargo/bin:/u01/polardb_pg/bin:$PATH
ENV PG_CONFIG=/u01/polardb_pg/bin/pg_config
# pg_duckdb Makefile
ENV ERROR_ON_WARNING=0
# Release/ReleaseStatic
ENV DUCKDB_BUILD=Release

RUN ./build.sh --ec="--prefix=/u01/polardb_pg/" --debug=off --quiet=off --ni --port=5432

# Build cargo-based extensions that require cargo/pgrx manually
WORKDIR /home/postgres/polardb_pg
RUN make -C external/VectorChord build
RUN make -C external/VectorChord install

WORKDIR /home/postgres/polardb_pg/external/VectorChord-bm25
RUN cargo pgrx install --sudo --release --pg-config /u01/polardb_pg/bin/pg_config

WORKDIR /home/postgres/polardb_pg/external/pg_tokenizer.rs
RUN cargo pgrx install --sudo --release --pg-config /u01/polardb_pg/bin/pg_config

WORKDIR /home/postgres/polardb_pg

# Install PostGIS
# WORKDIR /home/postgres
RUN wget --no-verbose https://download.osgeo.org/postgis/source/postgis-3.5.2.tar.gz && \
    tar -zxf postgis-3.5.2.tar.gz && \
    cd postgis-3.5.2 && \
    ./configure -q && \
    make -s -j$(nproc) && \
    make -s install

FROM mst1208/polardb-pg-devel:ubuntu-24.04
LABEL maintainer="m4n5terrr@gmail.com"

# Copy binary
COPY --from=building /u01/polardb_pg/ /u01/polardb_pg/

RUN sudo chown -R postgres:postgres /u01/polardb_pg/
RUN sudo chmod -R 700 /u01/polardb_pg/

# merge
# RUN cp -a /u01/polardb_pg/* /usr/local/ && rm -rf /u01/polardb_pg
