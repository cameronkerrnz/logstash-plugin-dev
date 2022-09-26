FROM centos:7

RUN \
  yum install -y centos-release-scl.noarch \
  && yum install -y \
    rh-git227-git \
    java-1.8.0-openjdk-devel \
    which \
    patch make \
    gcc \
  && yum clean all

RUN groupadd --gid 1000 builder && \
    adduser --uid 1000 --gid 1000 \
      --home-dir /src --create-home \
      builder

RUN  install -d -o builder -g builder -m 0775 /src \
  && install -d -o builder -g builder -m 0775 /opt/jruby

# Visual Studio Code prefers git >= 2.27
# We've installed it from SCL with yum above; just need do
# make that permanent so we don't go crazy prefixing
# everything with 'scl enable rh-git227 -- '
#
# However, you only get the effect of this in a shell, and
# NOT inside a RUN command, which is a bit vexing...
# and there's no sane way around that, so we just duplicate
# what that enable script does with a bunch of ENVs
#
RUN cat /opt/rh/rh-git227/enable > /etc/profile.d/git-version.sh
#
ENV PATH=/opt/rh/rh-git227/root/usr/bin:${PATH}
ENV MANPATH=/opt/rh/rh-git227/root/usr/share/man:${MANPATH}
ENV PERL5LIB=/opt/rh/rh-git227/root/usr/share/perl5/vendor_perl:${PERL5LIB}
ENV LD_LIBRARY_PATH=/opt/rh/httpd24/root/usr/lib64:${LD_LIBRARY_PATH}
#
RUN git --version

# Note: While the official logstash Docker container runs logstash in Java 11,
# the plugin eco-system is still built with Java 8, because Java 8 is still
# supported. Indeed, you'll find a number of issues (mostly relating to
# gradle wrapper and build.gradle files) that will require updating to work
# with Java 11

USER builder
WORKDIR /src

# Ensure Logstash gets a UTF-8 locale by default.
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8'

ENV LS_HOME=/src/logstash

# Build logstash for the Open Source version; shouldn't
# affect plugins.
#
ENV OSS=true

# This was in the master branch, but not the 7.9 branch...
ENV LOGSTASH_SOURCE=1
ENV LOGSTASH_PATH=${LS_HOME}

# Get logstash and assemble its Java bits
# We do this before installing JRuby, because
# the Logstash source tells us which version
# of JRuby it wants.

RUN git clone --branch 7.9 --single-branch https://github.com/elastic/logstash.git

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

RUN \
  mkdir -p /opt/jruby; \
  jruby_version=$(cat ${LS_HOME}/.ruby-version | sed -e 's/^jruby-//'); \
  tar -C /opt/jruby -zxf /tmp/jruby-dist-${jruby_version}-bin.tar.gz --strip-components=1 --no-same-owner;

# NOTE: I've found (same as https://github.com/elastic/logstash-devutils/issues/68)
# that if logstash/bin is in the PATH before jruby/bin, then you'll get problems
# resolving dependencies (notably logstash-devutils). But if jruby/bin is in the
# PATH before logstash/bin, then it works.
#
#ENV PATH=/src/logstash/bin/:/opt/jruby/bin:${PATH}
# Actually, that might be wrong; had issues with belzebuth dependencies (and then
# more)
ENV PATH=/opt/jruby/bin:/src/logstash/bin:/src/bin:${PATH}

RUN jruby --version

RUN gem install bundler rake

# Now that we have 'rake' available, we need to bootstrap the logstash source
# to provide ... jruby (a vendored version of it) and more besides.

RUN cd ${LS_HOME}; rake bootstrap

# It would be useful to have the usual plugins available, as
# they are not installed by default; they take ages to install too,
# for some reason.

RUN cd ${LS_HOME}; rake plugin:install-default

# When we compile a new plugin, we invoke 'bundle install' and it will go away
# and pull down yet more stuff from the internet; which sucks if you're offline.
# So let's generate a simple filter plugin with the minimal bits it needs,
# compile it and test it to ensure that it works.

RUN logstash-plugin generate --type=filter --name=buildtest --path=/src/
COPY logstash-filter-buildtest/logstash-filter-buildtest.gemspec \
    /src/logstash-filter-buildtest/logstash-filter-buildtest.gemspec
RUN cd /src/logstash-filter-buildtest && bundle install
RUN cd /src/logstash-filter-buildtest && bundle exec rspec

# TODO: Should build a Java plugin too...

# Support the use of 'Drip' to make dealing with long startup times more pleasant.
# This will really help with running tests quickly and often.
# Drip works by keeping another JVM ready in the background, with the same classpath
# and startup options, ready to go. It's been around for years now, and the master
# branch was last updated a few years ago, which is rather newer than the last release.
#
# Keep an occassional eye on https://github.com/ninjudd/drip/network to see if this
# moves to somewhere else.
#
# You'll need to set JAVACMD=`which drip` for this to be used... I don't see much
# difference (if any) though, so not sure if that's working as it should.
# Also, the checksum is not so useful; it downloads other things too.
#
RUN mkdir -p ~/bin/ && \
    rm -f ~/bin/drip && \
    curl -sL https://raw.githubusercontent.com/ninjudd/drip/master/bin/drip > ~/bin/drip && \
    sha256sum ~/bin/drip | tee /dev/stderr | grep -q acffc2af7385af993949d2fc406c456d1edf1a542fb72d2f2c7758251226c89c && \
    chmod +x ~/bin/drip && \
    echo "Drip downloaded and matches expected checksum"

WORKDIR /work

ENTRYPOINT ["/bin/bash"]
