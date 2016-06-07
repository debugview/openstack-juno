#/bin/sh

. ./common.sh


echo -n "Enter the physical external network interface:"
read INTERFACE_NAME

echo -n "Enter the IP address of the instance tunnels network:"
read INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS

BACKUP_DIR=backup/networker
CONFIG_DIR=config/networker

hostnamectl set-hostname networker
ifdown --exclude=lo -a && ifup --exclude=lo -a

cp /etc/ntp.conf $BACKUP_DIR/
cp $CONFIG_DIR/ntp.conf /etc/ntp.conf
service ntp restart

#vi /etc/sysctl.conf
echo '
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
' >> /etc/sysctl.conf

sysctl -p

apt-get install -y neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent

#vi /etc/neutron/neutron.conf 
cp /etc/neutron/neutron.conf  $BACKUP_DIR/
sed 's/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%RABBIT_PASS%/'$RABBIT_PASS'/g' $CONFIG_DIR/neutron.conf > /etc/neutron/neutron.conf

#vi /etc/neutron/plugins/ml2/ml2_conf.ini
cp /etc/neutron/plugins/ml2/ml2_conf.ini $BACKUP_DIR/
sed 's/%INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS%/'$INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS'/g' $CONFIG_DIR/ml2_conf.ini > /etc/neutron/plugins/ml2/ml2_conf.ini

# /etc/neutron/l3_agent.ini
cp /etc/neutron/l3_agent.ini $BACKUP_DIR/
cp $CONFIG_DIR/l3_agent.ini /etc/neutron/l3_agent.ini

# /etc/neutron/dhcp_agent.ini
cp /etc/neutron/dhcp_agent.ini $BACKUP_DIR/
cp $CONFIG_DIR/dhcp_agent.ini /etc/neutron/dhcp_agent.ini

#vi /etc/neutron/metadata_agent.ini
cp /etc/neutron/metadata_agent.ini $BACKUP_DIR/
sed 's/%NEUTRON_PASS%/'$NEUTRON_PASS'/g;s/%METADATA_SECRET%/'$METADATA_SECRET'/g' $CONFIG_DIR/metadata_agent.ini > /etc/neutron/metadata_agent.ini

service openvswitch-switch restart
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $INTERFACE_NAME
ethtool -K $INTERFACE_NAME gro off
service neutron-plugin-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart



