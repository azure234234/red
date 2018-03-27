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

##############

chmod u+x /etc/init.d/redis_7000

echo 'export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin' >> ~/.bashrc
source ~/.bashrc

#/etc/init.d/redis_7000 start
#/etc/init.d/redis_7000 stop

##################################################################
########################-sentinel-################################


chmod +x /etc/init.d/redis-sentinel
chkconfig --add redis-sentinel
chkconfig --level 3 redis-sentinel on

#/etc/init.d/redis-sentinel start
#/etc/init.d/redis-sentinel stop



if [ $(hostname -I) = $ip2 ]; then
sudo sed -i 's/# slaveof.*/slaveof '$ip1' 7000/' /etc/redis/7000.conf
fi

if [ $(hostname -I) = $ip3 ]; then
sudo sed -i 's/# slaveof.*/slaveof '$ip1' 7000/' /etc/redis/7000.conf
fi


#####
if [ $(hostname -I) = $ip1 ]; then

iptables -N REDIS
iptables -A REDIS -s 127.0.0.1 -j ACCEPT
iptables -A REDIS -s $ip1 -j ACCEPT
iptables -A REDIS -s $ip2 -j ACCEPT
iptables -A REDIS -s $ip3 -j ACCEPT
iptables -A REDIS -j LOG --log-prefix "unauth-redis-access"
iptables -A REDIS -j REJECT --reject-with icmp-port-unreachable
iptables -I INPUT -p tcp --dport 7000 -j REDIS

fi
#####
sudo sed -i 's/sentinel monitor cache.*/sentinel monitor cache '$ip1' 7000 2/' /etc/redis/sentinel.conf


###################



/etc/init.d/redis-sentinel start
/etc/init.d/redis-sentinel stop
/etc/init.d/redis_7000 start
/etc/init.d/redis_7000 stop



