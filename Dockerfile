FROM centos:7

RUN \
  yum install -y \
    git \
    java-1.8.0-openjdk-devel.x86_64 \
    which \
    patch make \
  && yum clean all

RUN groupadd --gid 1000 builder && \
    adduser --uid 1000 --gid 1000 \
      --home-dir /src --create-home \
      builder

# Ensure Logstash gets a UTF-8 locale by default.
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8'

# Note: While the official logstash Docker container runs logstash in Java 11,
# the plugin eco-system is still built with Java 8, because Java 8 is still
# supported. Indeed, you'll find a number of issues (mostly relating to
# gradle wrapper and build.gradle files) that will require updating to work
# with Java 11

USER builder
WORKDIR /src

RUN git clone --branch 7.8 --single-branch https://github.com/elastic/logstash.git

ENV LS_HOME=/src/logstash

RUN cd ${LS_HOME} && ./gradlew assemble

# For Ruby stuff, we want a copy of jruby that matches what Logstash uses for
# whichever version we're building.
#
# We could use tools like RVM, but that will end up building Ruby/Jruby from
# source, with lots of dependencies; so we just download the binary tar.gz
# package made from jruby.org, and be sure to check compare the checksum
# to what is expected for that version.
#
# https://www.jruby.org/download

RUN \
  set -x; set -u; set -e; \
  cd ${LS_HOME}; \
  jruby_version=$(cat .ruby-version | sed -e 's/^jruby-//'); \
  tarball="/tmp/jruby-dist-${jruby_version}-bin.tar.gz"; \
  curl -s -o "${tarball}" \
      https://repo1.maven.org/maven2/org/jruby/jruby-dist/${jruby_version}/jruby-dist-${jruby_version}-bin.tar.gz;

COPY CHECKSUMS-jruby /tmp

# Checksumming with sha1sum etc. is a pain in RHEL7, as that version
# of coreutils doesn't support --ignore-missing, so instead we filter
# the CHECKSUMS-jruby file to contain only the version we have
# downloaded.

RUN \
  set -x; set -u; set -e; \
  cd ${LS_HOME}; \
  jruby_version=$(cat .ruby-version | sed -e 's/^jruby-//'); \
  cd /tmp; \
  awk -v f="jruby-dist-${jruby_version}-bin.tar.gz" '$2 == f' < CHECKSUMS-jruby | tee /dev/stderr | sha1sum -c -

# At this point, we need to have the plugin code point to the logstash-core jar that
# was just produced.

USER root

RUN \
  mkdir -p /opt/jruby; \
  jruby_version=$(cat ${LS_HOME}/.ruby-version | sed -e 's/^jruby-//'); \
  tar -C /opt/jruby -zxf /tmp/jruby-dist-${jruby_version}-bin.tar.gz --strip-components=1 --no-same-owner;

ENV PATH=/opt/jruby/bin:${PATH}

RUN jruby --version

RUN gem install bundler

# Now that we have 'rake' available, we need to bootstrap the logstash source
# to provide ... jruby (a vendored version of it) and more besides.

USER builder

RUN cd ${LS_HOME}; rake bootstrap

ENTRYPOINT ["/bin/bash"]
