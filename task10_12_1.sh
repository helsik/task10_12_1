#!/bin/bash
dir_pwd=$(dirname "$0")
dir_pwd=$(cd "$dir_pwd" && pwd)
source ${dir_pwd}/config
# external network
MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
sed -i "s@br_ip@$EXTERNAL_NET_HOST_IP@" ${dir_pwd}/networks/external.xml
sed -i "s@net_name@$EXTERNAL_NET_NAME@" ${dir_pwd}/networks/external.xml
sed -i "s@net_mask@$EXTERNAL_NET_MASK@" ${dir_pwd}/networks/external.xml
sed -i "s@vm1_ip@$VM1_EXTERNAL_IP@" ${dir_pwd}/networks/external.xml
sed -i "s@vm1_name@$VM1_NAME@" ${dir_pwd}/networks/external.xml
sed -i "s@mac_id@$MAC@" ${dir_pwd}/networks/external.xml
# internal network
sed -i "s@network_name@$INTERNAL_NET_NAME@" ${dir_pwd}/networks/internal.xml
# management network
sed -i "s@network_name@$MANAGEMENT_NET_NAME@" ${dir_pwd}/networks/management.xml
sed -i "s@br_ip@$MANAGEMENT_HOST_IP@" ${dir_pwd}/networks/management.xml
sed -i "s@net_mask@$MANAGEMENT_NET_MASK@" ${dir_pwd}/networks/management.xml
# VM1 meta-data
sed -i "s@vm_name@$VM1_NAME@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@ext_int@$VM1_EXTERNAL_IF@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@inter_int@$VM1_INTERNAL_IF@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@inter_ip@$VM1_INTERNAL_IP@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@inter_net@${INTERNAL_NET}.0@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@inter_mask@$INTERNAL_NET_MASK@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@inter_broad@${INTERNAL_NET}.255@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@manag_int@$VM1_MANAGEMENT_IF@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@manag_ip@$VM1_MANAGEMENT_IP@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@manag_net@${MANAGEMENT_NET}.0@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@manag_mask@$MANAGEMENT_NET_MASK@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@manag_broad@${MANAGEMENT_NET}.255@" ${dir_pwd}/config-drives/vm1-config/meta-data
sed -i "s@dns_vm@$VM_DNS@" ${dir_pwd}/config-drives/vm1-config/meta-data
# VM1 user-data
pub_key=$(cat $SSH_PUB_KEY)
cat << EOF > ${dir_pwd}/config-drives/vm1-config/user-data
#cloud-config
password: qwerty
chpasswd: { expire: False }
ssh_authorized_keys:
 - $pub_key
runcmd:
 - sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
 - sysctl -p > /dev/null
 - iptables -t nat -A POSTROUTING --out-interface $VM1_EXTERNAL_IF -j MASQUERADE
 - iptables -A FORWARD --in-interface $VM1_INTERNAL_IF -j ACCEPT
 - apt-get update
 - apt-get install apt-transport-https ca-certificates curl software-properties-common -y
 - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 - apt-key fingerprint 0EBFCD88
 - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
 - apt-get update
 - apt-get install docker-ce -y
 - ip link add $VXLAN_IF type vxlan id $VID remote $VM2_INTERNAL_IP local $VM1_INTERNAL_IP dstport 4789
 - ip link set $VXLAN_IF up
 - ip addr add ${VM1_VXLAN_IP}/24 dev $VXLAN_IF
EOF
# VM2 meta-data
sed -i "s@vm_name@$VM2_NAME@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@inter_int@$VM2_INTERNAL_IF@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@inter_ip@$VM2_INTERNAL_IP@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@inter_net@${INTERNAL_NET}.0@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@inter_mask@$INTERNAL_NET_MASK@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@inter_broad@${INTERNAL_NET}.255@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@manag_int@$VM2_MANAGEMENT_IF@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@manag_ip@$VM2_MANAGEMENT_IP@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@manag_net@${MANAGEMENT_NET}.0@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@manag_mask@$MANAGEMENT_NET_MASK@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@manag_broad@${MANAGEMENT_NET}.255@" ${dir_pwd}/config-drives/vm2-config/meta-data
sed -i "s@dns_vm@$VM_DNS@" ${dir_pwd}/config-drives/vm2-config/meta-data
# VM2 user-data
cat << EOF > ${dir_pwd}/config-drives/vm2-config/user-data
#cloud-config
password: qwerty
chpasswd: { expire: False }
ssh_authorized_keys:
 - $pub_key
runcmd:
 - ip route add default via $VM1_INTERNAL_IP dev $VM2_INTERNAL_IF
 - apt-get update
 - apt-get install apt-transport-https ca-certificates curl software-properties-common -y
 - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 - apt-key fingerprint 0EBFCD88
 - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
 - apt-get update
 - apt-get install docker-ce -y
 - ip link add $VXLAN_IF type vxlan id $VID remote $VM1_INTERNAL_IP local $VM2_INTERNAL_IP dstport 4789
 - ip link set $VXLAN_IF up
 - ip addr add ${VM2_VXLAN_IP}/24 dev $VXLAN_IF
EOF
# Chek folder
mkdir -p $(echo "$VM1_HDD" |rev| cut -d / -f2- | rev)
mkdir -p $(echo "$VM2_HDD" |rev| cut -d / -f2- | rev)
mkdir -p $(echo "$VM1_CONFIG_ISO" |rev| cut -d / -f2- | rev)
mkdir -p $(echo "$VM2_CONFIG_ISO" |rev| cut -d / -f2- | rev)
# Download Ubuntu cloud image
wget -O "$VM1_HDD" "$VM_BASE_IMAGE"
cp "$VM1_HDD" "$VM2_HDD"
# Create two disks from image
mkisofs -o "$VM1_CONFIG_ISO" -V cidata -r -J --quiet ${dir_pwd}/config-drives/vm1-config/
mkisofs -o "$VM2_CONFIG_ISO" -V cidata -r -J --quiet ${dir_pwd}/config-drives/vm2-config/
# Create network
virsh net-define ${dir_pwd}/networks/external.xml
virsh net-define ${dir_pwd}/networks/internal.xml
virsh net-define ${dir_pwd}/networks/management.xml
virsh net-start external
virsh net-start internal
virsh net-start management
# Create  VM1
virt-install \
--connect qemu:///system \
--name $VM1_NAME \
--import \
--ram $VM1_MB_RAM --vcpus=$VM1_NUM_CPU --$VM_TYPE \
--os-type=linux --os-variant=ubuntu16.04 \
--disk path="$VM1_HDD",format=qcow2,bus=virtio,cache=none \
--disk path="$VM1_CONFIG_ISO",device=cdrom \
--network network=$EXTERNAL_NET_NAME,mac=$MAC \
--network network=$INTERNAL_NET_NAME \
--network network=$MANAGEMENT_NET_NAME \
--graphics vnc,port=-1 \
--noautoconsole --quiet --virt-type $VM_VIRT_TYPE

# Create  VM2
virt-install \
--connect qemu:///system \
--name $VM2_NAME \
--import \
--ram $VM2_MB_RAM --vcpus=$VM2_NUM_CPU --$VM_TYPE \
--os-type=linux --os-variant=ubuntu16.04 \
--disk path="$VM2_HDD",format=qcow2,bus=virtio,cache=none \
--disk path="$VM2_CONFIG_ISO",device=cdrom \
--network network=$INTERNAL_NET_NAME \
--network network=$MANAGEMENT_NET_NAME \
--graphics vnc,port=-1 \
--noautoconsole --quiet --virt-type $VM_VIRT_TYPE
