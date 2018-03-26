#!/bin/bash

ip1=$1  
ip2=$2 
ip3=$3 
id1=$4
id2=$5
id3=$6

yum -y update
yum -y groupinstall 'development tools'

cd /opt/
tar xvfz redis-3.2.3.tar.gz
cd redis-3.2.3

make
make install

cp -R /opt/redis-3.2.3 /var/lib

#################

sudo -s <<EOF

cat <<EOL >> /etc/init.d/redis_7000
#!/bin/sh
#
# Simple Redis init.d script conceived to work on Linux systems
# as it does use of the /proc filesystem.

REDISPORT=7000
EXEC=/usr/local/bin/redis-server
CLIEXEC=/usr/local/bin/redis-cli

PIDFILE=/var/run/redis_${REDISPORT}.pid
CONF="/etc/redis/${REDISPORT}.conf"

case "$1" in
    start)
        if [ -f $PIDFILE ]
        then
                echo "$PIDFILE exists, process is already running or crashed"
        else
                echo "Starting Redis server..."
                $EXEC $CONF
        fi
        ;;
    stop)
        if [ ! -f $PIDFILE ]
        then
                echo "$PIDFILE does not exist, process is not running"
        else
                PID=$(cat $PIDFILE)
                echo "Stopping ..."
                $CLIEXEC -p $REDISPORT shutdown
                while [ -x /proc/${PID} ]
                do
                    echo "Waiting for Redis to shutdown ..."
                    sleep 1
                done
                echo "Redis stopped"
        fi
        ;;
    *)
        echo "Please use start or stop as first argument"
        ;;
esac

EOL
EOF
##############

chmod u+x /etc/init.d/redis_7000

if [ $(hostname -I) = $ip2 ]; then
sudo sed -i 's/# slaveof.*/slaveof '$ip1' 7000/' /etc/redis/7000.conf
fi

if [ $(hostname -I) = $ip3 ]; then
sudo sed -i 's/# slaveof.*/slaveof '$ip1' 7000/' /etc/redis/7000.conf
fi

export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
/etc/init.d/redis_7000 start
/etc/init.d/redis_7000 stop

##################################################################
########################-sentinel-################################

#####
sudo -s <<EOF

cat <<EOL >> /etc/init.d/redis-sentinel

#!/bin/sh
#
# Simple Sentinel init.d script conceived to work on Linux systems
# as it does use of the /proc filesystem.

SENTINELPORT=26379
EXEC=/usr/local/bin/redis-sentinel
CLIEXEC=/usr/local/bin/redis-cli

#PIDFILE=/var/run/sentinel_${SENTINELPORT}.pid
PIDFILE=/var/run/redis-sentinel.pid
CONF="/etc/redis/sentinel.conf"

###############
# SysV Init Information
# chkconfig: - 58 74
# description: sentinel is the sentinel daemon.
### BEGIN INIT INFO
# Provides: sentinel
# Required-Start: $network $local_fs $remote_fs
# Required-Stop: $network $local_fs $remote_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Should-Start: $syslog $named
# Should-Stop: $syslog $named
# Short-Description: start and stop sentinel
# Description: Sentinel daemon
### END INIT INFO


case "$1" in
    start)
        if [ -f $PIDFILE ]
        then
                echo "$PIDFILE exists, process is already running or crashed"
        else
                echo "Starting Sentinel server..."
                nohup $EXEC $CONF >> /var/log/redis-sentinel.log 2>&1 &
                echo $! > "${PIDFILE}";
        fi
        ;;
    stop)
        if [ ! -f $PIDFILE ]
        then
                echo "$PIDFILE does not exist, process is not running"
        else
                PID=$(cat $PIDFILE)
                echo "Stopping ..."
                $CLIEXEC -p $SENTINELPORT shutdown
                while [ -x /proc/${PID} ]
                do
                    echo "Waiting for Sentinel to shutdown ..."
                    sleep 1
                done
                rm -rf $PIDFILE
                echo "Sentinel stopped"
        fi
        ;;
    *)
        echo "Please use start or stop as first argument"
        ;;
esac

EOL
EOF
#####

chmod +x /etc/init.d/redis-sentinel
chkconfig --add redis-sentinel
chkconfig --level 3 redis-sentinel on

/etc/init.d/redis-sentinel start
/etc/init.d/redis-sentinel stop

#####
if [ $(hostname -I) = $ip1 ]; then

iptables -N REDIS
iptables -A REDIS -s 127.0.0.1 -j ACCEPT
iptables -A REDIS -s $ip2 -j ACCEPT
iptables -A REDIS -s $ip3 -j ACCEPT
iptables -A REDIS -j LOG --log-prefix "unauth-redis-access"
iptables -A REDIS -j REJECT --reject-with icmp-port-unreachable
iptables -I INPUT -p tcp --dport 7000 -j REDIS

fi
#####

/etc/init.d/redis-sentinel start
/etc/init.d/redis_7000 start








