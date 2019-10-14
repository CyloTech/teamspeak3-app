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
      wget -q https://files.teamspeak-services.com/releases/server/${TS_VERSION}/${TARFILE} \
      && tar -j -x -f ${TARFILE} --strip-components=1 \
      && rm -f ${TARFILE} \
      && echo $TS_VERSION >version
    fi

    TS3ARGS=""
    #if [ -e /data/ts3server.ini ]; then
    #  TS3ARGS="inifile=/data/ts3server.ini"
    #else
    #  TS3ARGS="createinifile=1"
    #fi

    #TODO: Escape passwords so they can contain '.

    if [ -n "$SERVERADMIN_PASSWORD" ]; then
      TS3ARGS="$TS3ARGS serveradmin_password=$SERVERADMIN_PASSWORD"
    fi

    touch /data/.ts3server_license_accepted

    touch /data/tsoutput

    chown -R teamspeak3:teamspeak3 /data
    chown -R teamspeak3:teamspeak3 /app

cat << EOF >> /data/ts3server.ini
machine_id=
default_voice_port=${VOICE_PORT}
voice_ip=
licensepath=
filetransfer_port=${FILE_PORT}
filetransfer_ip=0.0.0.0
query_port=${QUERY_PORT}
query_ip=0.0.0.0, ::
query_ip_whitelist=query_ip_whitelist.txt
query_ip_blacklist=query_ip_blacklist.txt
dbplugin=ts3db_sqlite3
dbpluginparameter=
dbsqlpath=sql/
dbsqlcreatepath=create_sqlite/
dbconnections=10
logpath=logs
logquerycommands=0
dbclientkeepdays=30
logappend=0
query_skipbruteforcecheck=0
query_buffer_mb=20
http_proxy=
license_accepted=1
serverquerydocs_path=serverquerydocs/
query_ssh_ip=0.0.0.0, ::
query_ssh_port=10022
query_protocols=raw,ssh
query_ssh_rsa_host_key=ssh_host_rsa_key
query_timeout=300
EOF

    exec su -c "./ts3server license_accepted=1 inifile=ts3server.ini $TS3ARGS > /data/tsoutput" -s /bin/sh teamspeak3 &

#    while ! nc -z localhost ${QUERY_PORT}; do
#      echo "Sleeping for 1 second whilst we wait for it to come online..."
#      sleep 1
#    done

#    TOKEN=$(cat /data/tsoutput | grep token= | awk '{print $5}')
#    TOKEN=$(echo "${TOKEN/|token=/}")

#    echo "*******************************************************************"
#    echo "The Token is ${TOKEN}"
#    echo "*******************************************************************"

#    echo ${TOKEN} >> /ts3key

    cd /data
    git clone https://github.com/CyloTech/ts3web.git
    mkdir /data/ts3web/temp
    chmod 777 /data/ts3web/icons
    chmod 777 /data/ts3web/templates_c
    chmod -R 777 /data/ts3web/site/backups
    chmod 777 /data/ts3web/temp

    rm -fr /etc/nginx/sites-available/default
    mv /default.conf /etc/nginx/sites-available/default

cat << EOF >> /data/ts3web/config.php
<?php
if(!defined("SECURECHECK")) {die(\$lang['error_file_alone']);}

\$server[0]['alias']= "TS3Server";
\$server[0]['ip']= "127.0.0.1";
\$server[0]['tport']= ${QUERY_PORT};

\$cfglang = "en";
\$duration = "100";
\$fastswitch=true;
\$showicons="left";
\$style="new";
\$msgsend_name="TS3Server";
\$show_motd=false;
\$show_version=true;
?>
EOF

# Install Nginx Supervisor Config
cat << EOF >> /etc/supervisor/conf.d/nginx.conf
[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
priority=10
stdout_events_enabled=true
stderr_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Install PHP-FPM Supervisor Config
cat << EOF >> /etc/supervisor/conf.d/phpfpm.conf
[program:php-fpm]
command = /usr/sbin/php5-fpm --nodaemonize
autostart=true
autorestart=true
priority=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Install PHP-FPM Supervisor Config
cat << EOF >> /etc/supervisor/conf.d/teamspeak3.conf
[program:ts3server]
command = /runts.sh
autostart=true
autorestart=false
priority=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

cat << EOF >> /runts.sh
#!/bin/bash
export LD_LIBRARY_PATH=".:/data:/data/redist"
cd /data
exec su -c "./ts3server inifile=ts3server.ini" -s /bin/sh teamspeak3 &
EOF
chmod +x /runts.sh

# Shut down teamspeak and start it using the ini file.
#pkill -9 ts3server
#rm -f /data/ts3server.ini
#rm -fr /data/*.sqlitedb*

    #Set app as installed
    touch /app/ts_installed
    curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST "https://api.cylo.io/v1/apps/installed/$INSTANCE_ID"
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
