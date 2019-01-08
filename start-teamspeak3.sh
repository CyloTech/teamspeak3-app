#!/bin/bash

export LD_LIBRARY_PATH=".:/data:/data/redist"

if [ ! -f /app/ts_installed ]; then

    mkdir /data
    mkdir /app

    cd /data

    TARFILE=teamspeak3-server_linux_amd64-${TS_VERSION}.tar.bz2

    download=0
    if [ ! -e version ]; then
      download=1
    else
      read version <version
      if [ "$version" != "$TS_VERSION" ]; then
        download=1
      fi
    fi

    if [ "$download" -eq 1 ]; then
      echo "Downloading ${TARFILE} ..."
      wget -q http://dl.4players.de/ts/releases/${TS_VERSION}/${TARFILE} \
      && tar -j -x -f ${TARFILE} --strip-components=1 \
      && rm -f ${TARFILE} \
      && echo $TS_VERSION >version
    fi

    TS3ARGS=""
    if [ -e /data/ts3server.ini ]; then
      TS3ARGS="inifile=/data/ts3server.ini"
    else
      TS3ARGS="createinifile=1"
    fi

    if [ -n "$SERVERADMIN_PASSWORD" ]; then
      TS3ARGS="$TS3ARGS serveradmin_password=$SERVERADMIN_PASSWORD"
    fi

    touch /data/.ts3server_license_accepted

    touch /data/tsoutput

    chown -R teamspeak3:teamspeak3 /data
    chown -R teamspeak3:teamspeak3 /app

    exec su -c "./ts3server license_accepted=1 query_port=${QUERY_PORT} default_voice_port=${VOICE_PORT} filetransfer_port=${FILE_PORT} $TS3ARGS > /data/tsoutput" -s /bin/sh teamspeak3 &

    while ! nc -z localhost ${QUERY_PORT}; do
      echo "Sleeping for 1 second whilst we wait for it to come online..."
      sleep 1
    done

    TOKEN=$(cat /data/tsoutput | grep token= | awk '{print $5}')
    TOKEN=$(echo "${TOKEN/|token=/}")

    echo "*******************************************************************"
    echo "The Token is ${TOKEN}"
    echo "*******************************************************************"

    echo ${TOKEN} >> /ts3key

    touch /app/ts_installed
    curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST "https://api.cylo.io/v1/apps/installed/$INSTANCE_ID"

fi

cd /data
exec su -c "./ts3server license_accepted=1 query_port=${QUERY_PORT} default_voice_port=${VOICE_PORT} filetransfer_port=${FILE_PORT} $TS3ARGS" -s /bin/sh teamspeak3 &

tail -f /data/tsoutput