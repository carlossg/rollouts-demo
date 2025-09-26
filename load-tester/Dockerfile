FROM ubuntu:22.04

RUN echo "===> Installing  tools..."  && \
    apt-get -y update && \
    apt-get --no-install-recommends -y install build-essential curl jq ca-certificates unzip && \
    \
    echo "===> Installing wrk" && \
    WRK_VERSION="4.2.0" && \
    echo $WRK_VERSION  && \
    mkdir /opt/wrk && \
    cd /opt/wrk && \
    curl -L -k https://github.com/wg/wrk/archive/$WRK_VERSION.tar.gz | \
       tar zx --strip 1 && \
    make && \
    cp wrk /usr/local/bin/ && \
    \
    echo "===> Cleaning the system" && \
    apt-get -f -y --auto-remove remove build-essential curl unzip && \
    apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /opt/wrk \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

ADD report.lua .
