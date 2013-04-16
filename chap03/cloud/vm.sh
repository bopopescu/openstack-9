#!/bin/bash
set -e
set -o xtrace

if [[ $# -eq 0 ]]; then
    echo "There must be one parameters"
    exit 0
fi

if [[ $# -gt 1 ]]; then
    echo "There must be just one parameters: such as ./vm.sh keystone"
    exit 0
fi

[[ `dpkg -l kpartx | wc -l` -eq 0 ]] && apt-get install -y --force-yes kpartx
mkdir -p $1
qemu-img create -f qcow2 -o cluster_size=2M,backing_file=/cloud/_base/ubuntu-12.10.raw $1/ubuntu-$1.qcow2 40G

cp _base/back $1/$1
HOST_NAME=$1
uuid=`uuidgen`
sed -i "s,%UUID%,$uuid,g" $1/$1
sed -i "s,%VM_NAME%,$1,g" $1/$1

machine=`qemu-system-x86_64 -M ? | grep default | awk '{print $1}'`
sed -i "s,pc-0.14,$machine,g" $1/$1

# Gen MAC address
MACADDR="fa:92:$(dd if=/dev/urandom count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4/')";
echo $MACADDR
sed -i "s,%MAC%,$MACADDR,g" $1/$1

MACADDR2="52:54:$(dd if=/dev/urandom count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4/')";
echo $MACADDR
sed -i "s,%MAC2%,$MACADDR2,g" $1/$1

sed -i "s,%IMAGE_PATH%,/cloud/$1/ubuntu-$1.qcow2,g" $1/$1

modprobe nbd  max_part=63

dev_number=`find . -name "*.qcow2"| xargs -i qemu-img info {}| grep backing| uniq | wc -l`
qemu-nbd -c  /dev/nbd${dev_number} /cloud/$1/ubuntu-$1.qcow2
kpartx -a /dev/nbd${dev_number}
sleep 1

temp_file=`mktemp`; rm -rf $temp_file; mkdir -p $temp_file
sleep 1
mount /dev/mapper/ubuntu--12-root $temp_file
echo $temp_file

# Change network configuration.
#----------------------------------------------
file=$temp_file/etc/udev/rules.d/70-persistent-net.rules
cat <<"EOF" >$temp_file/etc/udev/rules.d/70-persistent-net.rules
# This file was automatically generated by the /lib/udev/write_net_rules
# program, run by the persistent-net-generator.rules rules file.
#
# You can modify it, as long as you keep each rule on a single
# line, and change only the value of the NAME= key.
# PCI device 0x10ec:0x8139 (8139cp)
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%MAC%", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%MAC2%", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"
EOF

sed -i "s,%MAC%,$MACADDR,g" $file
sed -i "s,%MAC2%,$MACADDR2,g" $file


file=$temp_file/etc/network/interfaces
cat <<"EOF">$file
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    gateway 10.239.82.1
auto eth1
iface eth1 inet static
    address 192.168.111.%IP%
    netmask 255.255.255.0
    broadcast 192.168.111.1
    gateway 192.168.111.1
EOF

IP=`ls -al | wc -l`
sed -i "s,%IP%,$IP,g" $file
sed -i "s,127.0.1.1.*,127.0.1.1    $HOST_NAME,g"  $temp_file/etc/hosts
sed -i "/exit/d" $temp_file/etc/rc.local
echo "route add default gw 10.239.82.1 eth0" > $temp_file/etc/rc.local
echo "exit 0" >> $temp_file/etc/rc.local
echo "$HOST_NAME" > $temp_file/etc/hostname
#----------------------------------------------
umount $temp_file
qemu-nbd -d /dev/nbd${dev_number}


set +o xtrace