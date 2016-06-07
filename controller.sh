#/bin/sh

. ./common.sh

BACKUP_DIR=backup/controller
CONFIG_DIR=config/controller

hostnamectl set-hostname controller
ifdown --exclude=lo -a && ifup --exclude=lo -a

cp /etc/ntp.conf $BACKUP_DIR/
cp $CONFIG_DIR/ntp.conf /etc/ntp.conf
service ntp restart

echo mysql-server mysql-server/root_password password $DB_PASS | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $DB_PASS | sudo debconf-set-selections

apt-get install -y mysql-server python-mysqldb rabbitmq-server 

#cp $CONFIG_DIR/openstack_mysql.cnf		/etc/mysql/conf.d/openstack_mysql.cnf
sed 's/%CONTROLLER_IP%/'$CONTROLLER_IP'/g;s/%NETWORKER_IP%/'$NETWORKER_IP'/g;s/%COMPUTER_IP%/'$COMPUTER_IP'/g' $CONFIG_DIR/openstack_mysql.cnf > /etc/mysql/conf.d/openstack_mysql.cnf

service mysql restart
#mysql_secure_installation

rabbitmqctl change_password guest $RABBIT_PASS
service rabbitmq-server restart

######## KEYSTONE ########
mysql -uroot -p$DB_PASS -e "
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%'  IDENTIFIED BY '$KEYSTONE_DBPASS';
"

apt-get install -y keystone python-keystoneclient
cp /etc/keystone/keystone.conf $BACKUP_DIR/

#cp $CONFIG_DIR/keystone.conf                    /etc/keystone/keystone.conf
ADMIN_TOKEN=`openssl rand -hex 10`
sed 's/%ADMIN_TOKEN%/'$ADMIN_TOKEN'/g;s/%KEYSTONE_DBPASS%/'$KEYSTONE_DBPASS'/g' $CONFIG_DIR/keystone.conf > /etc/keystone/keystone.conf

sh -c "keystone-manage db_sync" keystone

rm -f /var/lib/keystone/keystone.db

service keystone restart

sleep 3

export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0

keystone tenant-create --name admin --description "Admin Tenant"
keystone tenant-create --name demo --description "Demo Tenant"
keystone tenant-create --name service --description "Service Tenant"

keystone user-create --name admin --pass $ADMIN_PASS
keystone user-create --name demo --tenant demo --pass $DEMO_PASS

keystone role-create --name admin
keystone user-role-add --user admin --tenant admin --role admin

keystone service-create --name keystone --type identity --description "OpenStack Identity"
keystone endpoint-create --service-id $(keystone service-list | awk '/ identity / {print $2}') --publicurl http://controller:5000/v2.0 --internalurl http://controller:5000/v2.0 --adminurl http://controller:35357/v2.0 --region regionOne

unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

sed 's/%ADMIN_PASS%/'$ADMIN_PASS'/g' admin-openrc.sh > ~/admin-openrc.sh
sed 's/%DEMO_PASS%/'$DEMO_PASS'/g' demo-openrc.sh > ~/demo-openrc.sh

. ~/admin-openrc.sh

######## GLANCE ########

keystone user-create --name glance --pass $GLANCE_PASS
keystone user-role-add --user glance --tenant service --role admin
keystone service-create --name glance --type image --description "OpenStack Image Service"
keystone endpoint-create --service-id $(keystone service-list | awk '/ image / {print $2}') --publicurl http://controller:9292 --internalurl http://controller:9292 --adminurl http://controller:9292 --region regionOne

mysql -uroot -p$DB_PASS -e "
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
"

apt-get install -y glance python-glanceclient

cp /etc/glance/glance-api.conf $BACKUP_DIR/
cp /etc/glance/glance-registry.conf $BACKUP_DIR/

#cp $CONFIG_DIR/glance-api.conf                  /etc/glance/glance-api.conf
sed 's/%GLANCE_DBPASS%/'$GLANCE_DBPASS'/g;s/%GLANCE_PASS%/'$GLANCE_PASS'/g' $CONFIG_DIR/glance-api.conf > /etc/glance/glance-api.conf
#cp $CONFIG_DIR/glance-registry.conf             /etc/glance/glance-registry.conf
sed 's/%GLANCE_DBPASS%/'$GLANCE_DBPASS'/g;s/%GLANCE_PASS%/'$GLANCE_PASS'/g' $CONFIG_DIR/glance-registry.conf > /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance

rm -f /var/lib/glance/glance.sqlite

service glance-registry restart
service glance-api restart

######## NOVA ########

keystone user-create --name nova --pass $NOVA_PASS
keystone user-role-add --user nova --tenant service --role admin
keystone service-create --name nova --type compute --description "OpenStack Compute"
keystone endpoint-create --service-id $(keystone service-list | awk '/ compute / {print $2}') --publicurl http://controller:8774/v2/%\(tenant_id\)s --internalurl http://controller:8774/v2/%\(tenant_id\)s --adminurl http://controller:8774/v2/%\(tenant_id\)s --region regionOne

mysql -uroot -p$DB_PASS -e "
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
"

apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
  
cp /etc/nova/nova.conf $BACKUP_DIR/
#cp $CONFIG_DIR/nova.conf /etc/nova/nova.conf
sed 's/%NOVA_DBPASS%/'$NOVA_DBPASS'/g;s/%NOVA_PASS%/'$NOVA_PASS'/g;s/%RABBIT_PASS%/'$RABBIT_PASS'/g;s/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%CONTROLLER_IP%/'$CONTROLLER_IP'/g;s/%METADATA_SECRET%/'$METADATA_SECRET'/g' $CONFIG_DIR/nova.conf > /etc/nova/nova.conf

su -s /bin/sh -c "nova-manage db sync" nova

rm -f /var/lib/nova/nova.sqlite

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
service nova-api restart
service nova-scheduler restart
service nova-conductor restart

######## NEUTRON ########

keystone user-create --name neutron --pass $NEUTRON_PASS
keystone user-role-add --user neutron --tenant service --role admin
keystone service-create --name neutron --type network --description "OpenStack Networking"
keystone endpoint-create --service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://controller:9696 --adminurl http://controller:9696 --internalurl http://controller:9696 --region regionOne

mysql -uroot -p$DB_PASS -e "
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
"

apt-get install -y neutron-server neutron-plugin-ml2 python-neutronclient

cp /etc/neutron/plugins/ml2/ml2_conf.ini $BACKUP_DIR/

#cp /etc/neutron/neutron.conf $BACKUP_DIR/
SERVICE_TENANT_ID=`keystone tenant-get service | grep id | awk '{print $4}'`
sed 's/%NEUTRON_DBPASS%/'$NEUTRON_DBPASS'/g;s/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%RABBIT_PASS%/'$RABBIT_PASS'/g;s/%NOVA_PASS%/'$NOVA_PASS'/g;s/%SERVICE_TENANT_ID%/'$SERVICE_TENANT_ID'/g' $CONFIG_DIR/neutron.conf > /etc/neutron/neutron.conf
cp $CONFIG_DIR/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

rm -f /var/lib/neutron/neutron.sqlite

service neutron-server restart

######## HORIZON ########

apt-get install -y openstack-dashboard apache2 libapache2-mod-wsgi memcached python-memcache

cp $CONFIG_DIR/local_settings.py /etc/openstack-dashboard/local_settings.py

service apache2 restart
service memcached restart

######## CINDER ########

keystone user-create --name cinder --pass $CINDER_PASS
keystone user-role-add --user cinder --tenant service --role admin
keystone service-create --name cinder --type volume --description "OpenStack Block Storage"
keystone service-create --name cinderv2 --type volumev2 --description "OpenStack Block Storage"
keystone endpoint-create --service-id $(keystone service-list | awk '/ volume / {print $2}') --publicurl http://controller:8776/v1/%\(tenant_id\)s --internalurl http://controller:8776/v1/%\(tenant_id\)s --adminurl http://controller:8776/v1/%\(tenant_id\)s --region regionOne
keystone endpoint-create --service-id $(keystone service-list | awk '/ volumev2 / {print $2}') --publicurl http://controller:8776/v2/%\(tenant_id\)s --internalurl http://controller:8776/v2/%\(tenant_id\)s --adminurl http://controller:8776/v2/%\(tenant_id\)s --region regionOne

mysql -uroot -p$DB_PASS -e "
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
"
apt-get install -y cinder-api cinder-scheduler python-cinderclient

cp /etc/cinder/cinder.conf $BACKUP_DIR/

#cp $CONFIG_DIR/cinder.conf /etc/cinder/cinder.conf
sed 's/%CINDER_DBPASS%/'$CINDER_DBPASS'/g;s/%RABBIT_PASS%/'$RABBIT_PASS'/g;s/%CINDER_PASS%/'$CINDER_PASS'/g;s/%CONTROLLER_IP%/'$CONTROLLER_IP'/g' $CONFIG_DIR/cinder.conf > /etc/cinder/cinder.conf

su -s /bin/sh -c "cinder-manage db sync" cinder

rm -f /var/lib/cinder/cinder.sqlite

service cinder-scheduler restart
service cinder-api restart

######## SWIFT ########
keystone user-create --name swift --pass $SWIFT_PASS
keystone user-role-add --user swift --tenant service --role admin
keystone service-create --name swift --type object-store --description "OpenStack Object Storage"
keystone endpoint-create --service-id $(keystone service-list | awk '/ object-store / {print $2}') --publicurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' --internalurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' --adminurl http://controller:8080 --region regionOne

apt-get install -y swift swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached
  
mkdir -p /etc/swift/
#cp $CONFIG_DIR/proxy-server.conf                /etc/swift/proxy-server.conf
sed 's/%SWIFT_PASS%/'$SWIFT_PASS'/g' $CONFIG_DIR/proxy-server.conf > /etc/swift/proxy-server.conf



######## NETWORK CONFIG ########

echo "Floating IP start with: (eg: 192.168.1.1)"
read FLOATING_IP_START

echo "Floating IP end with: (eg: 192.168.1.100)"
read FLOATING_IP_END

echo "Floating Gateway IP (eg: 192.168.1.254)"
read EXTERNAL_NETWORK_GATEWAY

echo "Floating IP Network CIDR: (eg: 192.168.1.0/24)"
read EXTERNAL_NETWORK_CIDR

neutron net-create ext-net --router:external True provider:physical_network external --provider:network_type flat
neutron subnet-create ext-net --name ext-subnet --allocation-pool start=$FLOATING_IP_START,end=$FLOATING_IP_END --disable-dhcp --gateway $EXTERNAL_NETWORK_GATEWAY $EXTERNAL_NETWORK_CIDR


echo "Tenant Gateway IP (eg: 192.168.1.254)"
read TENANT_NETWORK_GATEWAY

echo "Tenant Network CIDR: (eg: 192.168.1.0/24)"
read TENANT_NETWORK_CIDR

neutron net-create demo-net
neutron subnet-create demo-net --name demo-subnet --gateway $TENANT_NETWORK_GATEWAY $TENANT_NETWORK_CIDR

neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net