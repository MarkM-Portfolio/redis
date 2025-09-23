###################################################################
#	IBM Confidential
#
#	OCO Source Materials
#
#	Copyright IBM Corp. 2016, 2017
#
#	The source code for this program is not published or otherwise
#	divested of its trade secrets, irrespective of what has been
#	deposited with the U.S. Copyright Office.
###################################################################

FROM connections-docker.artifactory.cwp.pnp-hcl.com/base/alpine
MAINTAINER squad:starboard (pipeline) - https://github.ibm.com/connections/connections-planning/labels

ENV REDIS_VERSION 3.2.12

LABEL name="Redis" \
    version="$REDIS_VERSION" \
    bin-origin="http://download.redis.io/releases/redis-3.2.12.tar.gz"

ADD redis-$REDIS_VERSION.tar.gz.sha1 /tmp/

COPY redis-master.conf /redis-master/redis.conf
COPY redis-slave.conf /redis-slave/redis.conf
COPY run.sh /usr/bin/run.sh
COPY readiness.sh /usr/bin/readiness.sh
COPY liveness.sh /usr/bin/liveness.sh
COPY tools/runRedisTools.sh /usr/bin/runRedisTools.sh


# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -g 1000 -S redis && adduser -u 1000 -S -G redis redis

RUN apk add --no-cache bash \
        && apk add --no-cache curl coreutils \
        && apk update \
        && apk upgrade \
        && rm -rf /var/cache/apk/*

# Install python libraries for new-relic
RUN apk add --update \
    python3-dev \
    py-pip

RUN cd /tmp/; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		gcc \
		linux-headers \
		make \
		musl-dev \
	; \
	\
	curl -SLOk "https://artifactory.cwp.pnp-hcl.com/artifactory/connections-3rd-party/redis/$REDIS_VERSION/redis-$REDIS_VERSION.tar.gz"; \
        sha1sum -c redis-$REDIS_VERSION.tar.gz.sha1; \
	mkdir -p /usr/src/redis; \
	tar -xzf redis-$REDIS_VERSION.tar.gz -C /usr/src/redis --strip-components=1; \
	rm redis-$REDIS_VERSION.tar.gz.sha1; \
        rm redis-$REDIS_VERSION.tar.gz; \
	\
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h; \
	sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h; \
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
	make -C /usr/src/redis -j "$(nproc)"; \
	make -C /usr/src/redis install; \
	\
	rm -r /usr/src/redis; \
	\
	apk del .build-deps

RUN mkdir -p /opt && chown redis:redis /opt

RUN mkdir -p /etc/newrelic /var/log/newrelic /var/run/newrelic /etc/service/newrelic-plugin-agent \
    && chown -R redis:redis /etc/newrelic /var/log/newrelic /var/run/newrelic /etc/service/newrelic-plugin-agent

RUN mkdir /data && chown redis:redis /data \
    && chmod +x /usr/bin/*.sh \
    && chown -R redis:redis /redis-master \
    && chown -R redis:redis /redis-slave \
    && mkdir /redis-master-data && chown redis:redis /redis-master-data

# cleanup packages
RUN apk del curl \
    && rm /usr/bin/nc

VOLUME /data
WORKDIR /data

USER redis

# install newrelic
RUN pip install --user newrelic-plugin-agent

ENV PATH="/home/redis/.local/bin:${PATH}"

ADD newrelic-plugin-agent.cfg /etc/newrelic/newrelic-plugin-agent.cfg

EXPOSE 6379

CMD [ "run.sh" ]
ENTRYPOINT ["bash","-c"]
