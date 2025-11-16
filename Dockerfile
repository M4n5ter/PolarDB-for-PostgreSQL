FROM mst1208/polardb-pg-devel:ubuntu-24.04 AS building
LABEL maintainer="m4n5terrr@gmail.com"

# Copy source code
WORKDIR /home/postgres/
COPY . ./PolarDB-for-PostgreSQL

USER root
# external plugins
RUN bash -lc "rm -rf ./PolarDB-for-PostgreSQL/external/{pgvector,age,pg_duckdb}" && \
    git clone --depth 1 --recurse-submodules https://github.com/duckdb/pg_duckdb ./PolarDB-for-PostgreSQL/external/pg_duckdb && \
    git clone --depth 1 -b release/PG15/1.5.0 https://github.com/apache/age ./PolarDB-for-PostgreSQL/external/age && \
    git clone --depth 1 -b v0.8.1 https://github.com/pgvector/pgvector ./PolarDB-for-PostgreSQL/external/pgvector && \
    sed -i '/endif # enable_minimal/i SUBDIRS += age\
SUBDIRS += pg_duckdb' ./PolarDB-for-PostgreSQL/external/Makefile

# rustup
RUN bash -lc "cargo self update && rustup update"

# Compile and install PolarDB-PG
WORKDIR /home/postgres/PolarDB-for-PostgreSQL
RUN COPT="-Wno-error ${COPT-}" \
    ./build.sh --ec="--prefix=/u01/polardb_pg/" --debug=off --quiet=off --ni --port=5432

# Install PostGIS
WORKDIR /home/postgres
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
RUN cp -a /u01/polardb_pg/* /usr/local/ && rm -rf /u01/polardb_pg