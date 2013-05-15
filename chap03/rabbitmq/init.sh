#!/bin/bash
set -e
set -o xtrace

TOP_DIR=$(cd $(dirname "$0") && pwd)
TEMP=`mktemp`; rm -rfv $TEMP >/dev/null; mkdir -p $TEMP;
DEST=/opt/stack
source $TOP_DIR/tools/function

#---------------------------------------------
# Check for apt.
#---------------------------------------------
apt-get update
DEBIAN_FRONTEND=noninteractive \
apt-get --option \
"Dpkg::Options::=--force-confold" --assume-yes \
install -y --force-yes openssh-server 
#---------------------------------------------
# Kill process by Name
#---------------------------------------------

cp -rf $TOP_DIR/tools/nkill /usr/bin/
chmod +x /usr/bin/

#---------------------------------------------
# Set up iptables.
#---------------------------------------------

setup_iptables
set +o xtrace