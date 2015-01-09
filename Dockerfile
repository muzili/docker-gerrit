FROM muzili/centos-php

MAINTAINER Joshua Lee <muzili@gmail.com>

ENV GERRIT_USER gerrit2
ENV GERRIT_HOME /data/${GERRIT_USER}
ENV GERRIT_WAR ${GERRIT_HOME}/gerrit.war
ENV GERRIT_VERSION 2.9.4

# Install openjdk
RUN yum -y -q install java-1.7.0-openjdk.x86_64 && \
    useradd ${GERRIT_USER} && \
    mkdir -p ${GERRIT_HOME} && \
    chown -R ${GERRIT_USER}:${GERRIT_USER} $GERRIT_HOME

ADD scripts /scripts
ADD http://gerrit-releases.storage.googleapis.com/gerrit-${GERRIT_VERSION}.war ${GERRIT_WAR}

# Expose our web root and log directories log.
VOLUME ["/data", "/var/log"]

USER $GERRIT_USER
WORKDIR $GERRIT_HOME

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64/jre
ENV AUTH_TYPE DEVELOPMENT_BECOME_ANY_ACCOUNT

# Expose the port
EXPOSE 8080 29418

# Kicking in
CMD ["/scripts/start.sh"]

