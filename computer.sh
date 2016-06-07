#/bin/sh

. ./common.sh

echo -n "Enter the IP address of the instance tunnels network:"
read INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS

BACKUP_DIR=backup/computer
CONFIG_DIR=config/computer

hostnamectl set-hostname computer
ifdown --exclude=lo -a && ifup --exclude=lo -a

cp /etc/ntp.conf $BACKUP_DIR/
cp $CONFIG_DIR/ntp.conf /etc/ntp.conf
service ntp restart

######## COMPUTE ########

apt-get install -y nova-compute sysfsutils

#/etc/nova/nova.conf
cp /etc/nova/nova.conf $BACKUP_DIR/
sed 's/%RABBIT_PASS%/'$RABBIT_PASS'/g;s/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%NOVA_PASS%/'$NOVA_PASS'/g;s/%MANAGEMENT_INTERFACE_IP_ADDRESS%/'$COMPUTER_IP'/g' $CONFIG_DIR/nova.conf > /etc/nova/nova.conf

cp /etc/nova/nova-compute.conf $BACKUP_DIR/
cp $CONFIG_DIR/nova-compute.conf /etc/nova/nova-compute.conf

service nova-compute restart

rm -f /var/lib/nova/nova.sqlite

######## NETWORK ########

# /etc/sysctl.conf
echo '
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
' >> /etc/sysctl.conf

sysctl -p

apt-get install -y neutron-plugin-ml2 neutron-plugin-openvswitch-agent

# /etc/neutron/neutron.conf
cp /etc/neutron/neutron.conf $BACKUP_DIR/
sed 's/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%RABBIT_PASS%/'$RABBIT_PASS'/g' $CONFIG_DIR/neutron.conf > /etc/neutron/neutron.conf

# /etc/neutron/plugins/ml2/ml2_conf.ini
cp /etc/neutron/plugins/ml2/ml2_conf.ini $BACKUP_DIR/
sed 's/%INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS%/'$INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS'/g' $CONFIG_DIR/ml2_conf.ini > /etc/neutron/plugins/ml2/ml2_conf.ini

service openvswitch-switch restart

# /etc/nova/nova.conf

service nova-compute restart
service neutron-plugin-openvswitch-agent restart





