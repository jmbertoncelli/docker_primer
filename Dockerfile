FROM adoptopenjdk/openjdk8:jdk8u275-b01-alpine

LABEL Description="SDC-500"

# Note: libidn is required as a workaround for addressing AWS Kinesis Producer issue
# (https://github.com/awslabs/amazon-kinesis-producer/issues/86).
# nsswitch.conf is based on jeanblanchard's alpine base image and used for configuring DNS resolution priority
# protobuf is included to enable testing of the protobuf record format.
RUN apk add --update --no-cache apache2-utils \
    bash \
    curl \
    grep \
    krb5-libs \
    krb5 \
    libidn \
    libstdc++ \
    libuuid \
    protobuf \
    sed \
    sudo && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# We set a UID/GID for the SDC user because certain test environments require these to be consistent throughout
# the cluster. We use 20159 because it's above the default value of YARN's min.user.id property.
ARG SDC_UID=20159
ARG SDC_GID=20159

# Begin Data Collector installation
ARG SDC_VERSION=5.0.0-SNAPSHOT
#ARG SDC_URL=http://nightly.streamsets.com.s3-us-west-2.amazonaws.com/datacollector/latest/tarball/streamsets-datacollector-core-${SDC_VERSION}.tgz
ARG SDC_USER=sdc
# SDC_HOME is where executables and related files are installed. Used in setup_mapr script.
ARG SDC_ROOT="/opt"
ARG SDC_HOME="${SDC_ROOT}/streamsets-datacollector-${SDC_VERSION}"

# The paths below should generally be attached to a VOLUME for persistence.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
# USER_LIBRARIES_DIR is where custom stage libraries are installed.
ENV SDC_CONF=/etc/sdc \
    SDC_DATA=/data \
    SDC_DIST=${SDC_HOME} \
    SDC_HOME=${SDC_HOME} \
    SDC_LOG=/logs \
    SDC_RESOURCES=/resources \
    USER_LIBRARIES_DIR=/opt/streamsets-datacollector-user-libs
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/streamsets-libs-extras"

ENV SDC_JAVA_OPTS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

######################################################################################################################
######################################################################################################################
######################################################################################################################

ADD /tgz/streamsets-datacollector-all-"${SDC_VERSION}".tgz "${SDC_ROOT}"
ADD /tgz/streamsets-datacollector-databricks-lib-1.6.0-SNAPSHOT.tgz "${SDC_HOME}"
ADD /tgz/streamsets-datacollector-snowflake-lib-1.11.0-SNAPSHOT.tgz "${SDC_HOME}"

RUN mv "${SDC_HOME}/etc" "${SDC_CONF}"

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN addgroup --system --gid ${SDC_GID} ${SDC_USER} && adduser --system --disabled-password -u ${SDC_UID} -G ${SDC_USER} ${SDC_USER}
RUN addgroup ${SDC_USER} root && chgrp -R 0 "${SDC_DIST}" "${SDC_CONF}" && chmod -R g=u "${SDC_DIST}" "${SDC_CONF}" && chmod g+s "${SDC_CONF}" && chmod g=u /etc/passwd
RUN echo "${SDC_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN mkdir -p /mnt \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}" \
    "${USER_LIBRARIES_DIR}"

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN chgrp -R 0 "${SDC_RESOURCES}" "${USER_LIBRARIES_DIR}" "${SDC_LOG}" "${SDC_DATA}" && chmod -R g=u "${SDC_RESOURCES}" "${USER_LIBRARIES_DIR}" "${SDC_LOG}" "${SDC_DATA}"    

######################################################################################################################
######################################################################################################################
######################################################################################################################

COPY conf_01.sh /tmp/
RUN /tmp/conf_01.sh

######################################################################################################################
######################################################################################################################
######################################################################################################################

COPY resources/ ${SDC_RESOURCES}/
RUN sudo chown -R sdc:sdc ${SDC_RESOURCES}/

######################################################################################################################
######################################################################################################################
######################################################################################################################

COPY sdc-extras/ ${STREAMSETS_LIBRARIES_EXTRA_DIR}/
RUN sudo chown -R sdc:sdc ${STREAMSETS_LIBRARIES_EXTRA_DIR}/

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN sed -i 's/http.realm.file.permission.check=true/http.realm.file.permission.check=false/' ${SDC_CONF}/sdc.properties

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN sed -i 's|--status|-s|' "/opt/streamsets-datacollector-${SDC_VERSION}/libexec/_stagelibs"

######################################################################################################################
######################################################################################################################
######################################################################################################################

RUN echo "${SDC_VERSION}" > "${SDC_DIST}/VERSION"

######################################################################################################################
######################################################################################################################
######################################################################################################################

USER ${SDC_USER}
EXPOSE 18630
ENTRYPOINT ["/opt/streamsets-datacollector-5.0.0-SNAPSHOT/bin/streamsets"]
CMD ["dc"]