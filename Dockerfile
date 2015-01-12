FROM muzili/centos-php

MAINTAINER Joshua Lee <muzili@gmail.com>

ENV GERRIT_USER gerrit2
ENV GERRIT_HOME /data/${GERRIT_USER}
ENV GERRIT_WAR /tmp/gerrit.war
ENV GERRIT_VERSION 2.9.4

# Install openjdk
RUN yum -y -q install java-1.7.0-openjdk.x86_64 git && \
    useradd ${GERRIT_USER} && \
    mkdir -p ${GERRIT_HOME} && \
    touch /first_run

ADD scripts /scripts
ADD http://gerrit-releases.storage.googleapis.com/gerrit-${GERRIT_VERSION}.war ${GERRIT_WAR}
RUN chown -R ${GERRIT_USER}:${GERRIT_USER} $GERRIT_HOME


# Expose our web root and log directories log.
VOLUME ["/data", "/var/log"]

WORKDIR /home/${GERRIT_USER}

ENV JAVA_HOME /usr/lib/jvm/jre
ENV AUTH_TYPE DEVELOPMENT_BECOME_ANY_ACCOUNT

# Expose the port
EXPOSE 80 29418

# Kicking in
CMD ["/scripts/start.sh"]

