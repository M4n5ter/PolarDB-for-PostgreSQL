# mst1208/postgres:15-polardb

FROM mst1208/polardb-binary:ubuntu-24.04

SHELL ["/bin/bash", "-c"]

# ensure clean cargo build cache
RUN cargo clean-all --yes

RUN install --verbose --directory --owner postgres --group postgres --mode 1777 /var/lib/postgresql

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.19
RUN set -eux; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

ENV LANG en_US.utf8

RUN mkdir /docker-entrypoint-initdb.d

ENV PG_MAJOR=15
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:/u01/polardb_pg/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
	mkdir -p /usr/lib/postgresql; \
	rm -rf /usr/lib/postgresql/$PG_MAJOR; \
	mkdir -p /usr/lib/postgresql/$PG_MAJOR; \
	cp -a /u01/polardb_pg/. /usr/lib/postgresql/$PG_MAJOR/; \
	printf '/usr/lib/postgresql/%s/lib\n' "$PG_MAJOR" > /etc/ld.so.conf.d/polardb.conf; \
	ldconfig; \
	postgres --version

RUN chown -R postgres:postgres /u01/polardb_pg

# Drop leftover source tree from base image to keep runtime lean
RUN rm -rf /home/postgres/polardb_pg

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	POLARDB_SHARE=/u01/polardb_pg/share/postgresql; \
	POSTGRES_SHARE=/usr/share/postgresql; \
	PG_SHARE=/usr/lib/postgresql/$PG_MAJOR/share/postgresql; \
	cat "$POLARDB_SHARE/polardb.conf.sample" >> "$POLARDB_SHARE/postgresql.conf.sample"; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" "$POLARDB_SHARE/postgresql.conf.sample"; \
	sed -ri "s!^shared_preload_libraries\s*=.*!shared_preload_libraries = 'age,pg_duckdb,vchord,pg_tokenizer,vchord_bm25,pg_net,pg_cron,pgaudit,safeupdate,\$libdir/polar_vfs,\$libdir/polar_io_stat,\$libdir/polar_monitor_preload,\$libdir/polar_worker'!" "$POLARDB_SHARE/postgresql.conf.sample"; \
	sed -ri "s!^#?search_path\s*=.*!search_path = '\"\$user\", public, ag_catalog, tokenizer_catalog, bm25_catalog'!" "$POLARDB_SHARE/postgresql.conf.sample"; \
	echo "polar_enable_shared_storage_mode = off" >> "$POLARDB_SHARE/postgresql.conf.sample"; \
	install -d $POSTGRES_SHARE/$PG_MAJOR; \
	cp -fv "$POLARDB_SHARE/postgresql.conf.sample" $POSTGRES_SHARE/postgresql.conf.sample; \
	install -d $PG_SHARE; \
	cp -fv "$POLARDB_SHARE/postgresql.conf.sample" $PG_SHARE/postgresql.conf.sample; \
	ln -sf ../postgresql.conf.sample "$POSTGRES_SHARE/$PG_MAJOR/postgresql.conf.sample"; \
	grep -F "listen_addresses = '*'" "$POLARDB_SHARE/postgresql.conf.sample"

RUN install --verbose --directory --owner postgres --group postgres --mode 3777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# this 1777 will be replaced by 0700 at runtime (allows semi-arbitrary "--user" values)
RUN install --verbose --directory --owner postgres --group postgres --mode 1777 "$PGDATA"
VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh docker-ensure-initdb.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-ensure-initdb.sh && \
    ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# We set the default STOPSIGNAL to SIGINT, which corresponds to what PostgreSQL
# calls "Fast Shutdown mode" wherein new connections are disallowed and any
# in-progress transactions are aborted, allowing PostgreSQL to stop cleanly and
# flush tables to disk.
#
# See https://www.postgresql.org/docs/current/server-shutdown.html for more details
# about available PostgreSQL server shutdown signals.
#
# See also https://www.postgresql.org/docs/current/server-start.html for further
# justification of this as the default value, namely that the example (and
# shipped) systemd service files use the "Fast Shutdown mode" for service
# termination.
#
STOPSIGNAL SIGINT
#
# An additional setting that is recommended for all users regardless of this
# value is the runtime "--stop-timeout" (or your orchestrator/runtime's
# equivalent) for controlling how long to wait between sending the defined
# STOPSIGNAL and sending SIGKILL.
#
# The default in most runtimes (such as Docker) is 10 seconds, and the
# documentation at https://www.postgresql.org/docs/current/server-start.html notes
# that even 90 seconds may not be long enough in many instances.

EXPOSE 5432
CMD ["postgres"]
