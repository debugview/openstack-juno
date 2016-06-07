#!/bin/sh

##Ubuntu 14.04.04 LTS

DB_PASS=123456					#Root password for the database
KEYSTONE_DBPASS=123456          #Database password of Identity service 
GLANCE_DBPASS=123456            #Database password for Image Service 
NOVA_DBPASS=123456              #Database password for Compute service 
DASH_DBPASS=123456              #Database password for the dashboard
CINDER_DBPASS=123456            #Database password for the Block Storage service 
NEUTRON_DBPASS=123456           #Database password for the Networking service 
HEAT_DBPASS=123456              #Database password for the Orchestration service 
CEILOMETER_DBPASS=123456        #Database password for the Telemetry service 
TROVE_DBPASS=123456             #Database password of Database service 

RABBIT_PASS=123456		#Password of user guest of RabbitMQ
DEMO_PASS=123456		#Password of user demo
ADMIN_PASS=123456		#Password of user admin
GLANCE_PASS=123456		#Password of Image Service user glance
NOVA_PASS=123456		#Password of Compute service user nova
CINDER_PASS=123456		#Password of Block Storage service user cinder
NEUTRON_PASS=123456		#Password of Networking service user neutron
HEAT_PASS=123456		#Password of Orchestration service user heat
CEILOMETER_PASS=123456	#Password of Telemetry service user ceilometer
TROVE_PASS=123456		#Password of Database Service user trove
SWIFT_PASS=123456		#Password of Object Storage Service user swift

METADATA_SECRET=123456	#Secret for the Metadata Proxy

BACKUP_DIR=backup
CONFIG_DIR=config

echo -n "Enter Controller Node IP:"
read CONTROLLER_IP

echo -n "Enter Network Node IP:"
read NETWORKER_IP

echo -n "Enter First Compute Node IP:"
read COMPUTER_IP

mkdir -p $BACKUP_DIR

cp /etc/network/interfaces $BACKUP_DIR/
cp /etc/hosts $BACKUP_DIR/

#cp $CONFIG_DIR/hosts /etc/hosts
sed 's/%CONTROLLER_IP%/'$CONTROLLER_IP'/g;s/%NETWORKER_IP%/'$NETWORKER_IP'/g;s/%COMPUTER_IP%/'$COMPUTER_IP'/g' $CONFIG_DIR/hosts > /etc/hosts

add-apt-repository -y cloud-archive:juno
apt-get install -y ntp software-properties-common

apt-get update -y
apt-get dist-upgrade -y

