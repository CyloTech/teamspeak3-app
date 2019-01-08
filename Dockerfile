FROM debian:jessie

MAINTAINER aheil

ENV SERVERADMIN_PASSWORD Letmein123
ENV TS_VERSION 3.5.1
ENV LANG C.UTF-8
ENV VOICE_PORT 10001
ENV QUERY_PORT 10002
ENV FILE_PORT 10003

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install bzip2 wget ca-certificates netcat curl nginx php5-fpm git supervisor nano \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -M -s /bin/false --uid 1000 teamspeak3

COPY start-teamspeak3.sh /start-teamspeak3

ADD default.conf /default.conf

RUN groupmod -g 9999 nogroup
RUN usermod -g 9999 nobody
RUN usermod -u 9999 nobody
RUN usermod -g 9999 sync

#EXPOSE 9987/udp 10011 30033

CMD ["/start-teamspeak3"]

