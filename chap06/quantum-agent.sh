#!/bin/bash

set -e
set -o xtrace

TOPDIR=$(cd $(dirname "$0") && pwd)
TEMP=`mktemp`;
rm -rfv $TEMP >/dev/null;
mkdir -p $TEMP;
source $TOPDIR/localrc
source $TOPDIR/tools/function
DEST=/opt/stack/

#---------------------------------------------------
# Clear Front installation
#---------------------------------------------------

DEBIAN_FRONTEND=noninteractive \
apt-get --option \
"Dpkg::Options::=--force-confold" --assume-yes \
install -y --force-yes mysql-client

nkill quantum-openvswitch-agent

[[ -d $DEST/quantum ]] && cp -rf $TOPDIR/openstacksource/quantum/etc/* $DEST/quantum/etc/



############################################################
#
# Install some basic used debs.
#
############################################################

apt-get install -y --force-yes openssh-server build-essential git \
python-dev python-setuptools python-pip \
libxml2-dev libxslt-dev python-pam python-lxml \
python-iso8601 python-sqlalchemy python-migrate \
python-routes  python-passlib \
python-greenlet python-eventlet unzip python-prettytable \
python-mysqldb mysql-client memcached openssl expect \
python-netifaces python-netifaces-dbg \
make fakeroot dkms openvswitch-switch openvswitch-datapath-dkms \
ebtables iptables iputils-ping iputils-arping sudo python-boto \
python-iso8601 python-routes python-suds python-netaddr \
 python-greenlet python-eventlet \
python-sqlalchemy python-mysqldb python-pyudev python-qpid dnsmasq-base \
dnsmasq-utils vlan python-requests alembic


#---------------------------------------------------
# Copy source code to DEST Dir
#---------------------------------------------------

[[ ! -d $DEST ]] && mkdir -p $DEST
install_keystone
install_quantum


#################################################
#
# Change configuration file.
#
#################################################

scp -pr $QUANTUM_HOST:/etc/quantum/* /etc/quantum/

############################################################
#
# SYNC the DataBase.
#
############################################################

cnt=`ovs-vsctl show | grep "br-int" | wc -l`
if [[ $cnt -eq 0 ]]; then
    ovs-vsctl add-br br-eth1
    ovs-vsctl add-port br-eth1 eth1
    ovs-vsctl add-br br-int
    ovs-vsctl add-br br-ex
fi


############################################################
#
# Create a script to kill all the services with the name.
#
############################################################


cat <<"EOF" > /root/quantum-agent.sh
#!/bin/bash

nkill quantum-openvswitch-agent
mkdir -p /var/log/quantum/
rm -rf /var/log/quantum/quantum*

nohup python /opt/stack/quantum/bin/quantum-openvswitch-agent --config-file /etc/quantum/quantum.conf --config-file=/etc/quantum/l3_agent.ini > /var/log/quantum/quantum-openvswitch-agent.log 2>&1 &

EOF

chmod +x /root/quantum-agent.sh
nohup /root/quantum-agent.sh >/dev/null 2>&1 &

rm -rf /tmp/pip*; rm -rf /tmp/tmp*

set +o xtrace
