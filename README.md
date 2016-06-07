# openstack-juno
Auto Config Shell Script for OpenStack Juno on Ubuntu 14.04.04 LTS

Refer to http://docs.openstack.org/juno/install-guide/

# Usage
Initial the system, config the network, and then execute the script under root:
* controller.sh -- Control Node with at least 1 Nic (Manage)
* networker.sh -- Network Node with at least 3 Nics (Manage, Tunnel, External)
* computer.sh -- Compute Node with at least 2 Nic (Manage, Tunnel)
