#!/bin/bash
set -e
set +o xtrace


TOPDIR=$(cd $(dirname "$0") && pwd)
source /root/localrc

ADMIN_PASSWORD=$KEYSTONE_GLANCE_SERVICE_PASSWORD
ADMIN_USER=glance
ADMIN_TENANT=service
KEYSTONE_HOST=$KEYSTONE_HOST

TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASSWORD\"}, \"tenantName\": \"$ADMIN_TENANT\"}}" -H "Content-type: application/json" http://$KEYSTONE_HOST:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`
echo $TOKEN

old_path=`pwd`
cd /tmp/; rm -rf cirros*
tar zxf $TOPDIR/cirros-0.3.0-x86_64-uec.tar.gz
cd $old_path

KERNEL_FILE=/tmp/cirros-0.3.0-x86_64-vmlinuz
RAMDISK_FILE=/tmp/cirros-0.3.0-x86_64-initrd
IMAGE_FILE=/tmp/cirros-0.3.0-x86_64-blank.img
IMAGE_NAME=cirros

KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOST:9292 image-create --name "${IMAGE_NAME%.kernel}" --public --container-format aki --disk-format aki < "${KERNEL_FILE}" | grep ' id ' | awk '{print $4}')

RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOST:9292 image-create --name "${IMAGE_NAME%.ramdisk}" --public --container-format ari --disk-format ari < "${RAMDISK_FILE}" | grep ' id ' | awk '{print $4}')


glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOST:9292 image-create --name "${IMAGE_NAME%.img}" --public --container-format ami --disk-format ami ${KERNEL_ID:+--property kernel_id=$KERNEL_ID} ${RAMDISK_ID:+--property ramdisk_id=$RAMDISK_ID} < "${IMAGE_FILE}"

glance image-update --property hw_disk_bus=ide `glance index | grep "cirros.img" | awk '{print $1}'`

set -o xtrace
