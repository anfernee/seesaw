#!/bin/bash

# VARIABLES
ROOT=$PWD
NETMASK=${NETMASK:-24}

# Install Dependencies
apt update
apt -y install make golang-go libnl-3-dev libnl-genl-3-dev

# Tools
apt -y install ipvsadm

# [Dev] enable ssh
sed -i /etc/ssh/sshd_config -e 's/PasswordAuthentication .*/PasswordAuthentication yes/g'
service sshd restart

# Download seesaw source
mkdir -p $ROOT/go/src/github.com/google
git clone https://github.com/anfernee/seesaw.git $ROOT/go/src/github.com/google/seesaw

# Seesaw dependencies
export GOPATH=$ROOT/go
go get -u golang.org/x/crypto/ssh
go get -u github.com/dlintw/goconf
go get -u github.com/golang/glog
go get -u github.com/miekg/dns
go get -u github.com/kylelemons/godebug/pretty
go get -u golang.org/x/crypto/ssh/terminal
go get -u github.com/golang/protobuf/proto

apt -y install protobuf-compiler
go get -u github.com/golang/protobuf/{proto,protoc-gen-go}

# Build and install seesaw
mkdir -p /usr/local/seesaw
pushd $ROOT/go/src/github.com/google/seesaw && make install && popd
mv $GOPATH/bin/seesaw_* /usr/local/seesaw/

# Configure seesaw
mkdir /etc/seesaw
mkdir /var/log/seesaw

# Module
modprobe ip_vs
modprobe nf_conntrack_ipv4
modprobe dummy numdummies=1
echo options ip_vs > /etc/modprobe.d/ip_vs.conf
echo options nf_conntrack_ipv4 > /etc/modprobe.d/nf_conntrack_ipv4.conf
echo options dummy numdummies=1 > /etc/modprobe.d/dummy.conf

# Configuration
cat > /etc/seesaw/watchdog.cfg <<EOF
[ecu]
binary = /usr/local/seesaw/seesaw_ecu
args = -log_dir=/var/log/seesaw
dependency = engine

[engine]
binary = /usr/local/seesaw/seesaw_engine
args = -log_dir=/var/log/seesaw
dependency = ncc
priority = -10
term_timeout = 10s

[ha]
binary = /usr/local/seesaw/seesaw_ha
args = -log_dir=/var/log/seesaw
dependency = engine
priority = -15

[healthcheck]
binary = /usr/local/seesaw/seesaw_healthcheck
args = -log_dir=/var/log/seesaw
dependency = engine

[ncc]
binary = /usr/local/seesaw/seesaw_ncc
args = -log_dir=/var/log/seesaw
priority = -10
EOF

cat > /etc/seesaw/seesaw.cfg <<EOF
[cluster]
anycast_enabled = false
name = au-syd
node_ipv4 = $NODE_IP
peer_ipv4 = $PEER_IP
vip_ipv4 = $VIP_IP

[config_server]
primary = seesaw-config1.example.com
secondary = seesaw-config2.example.com
tertiary = seesaw-config3.example.com

[interface]
node = ens192
lb = ens224
EOF

cat > /etc/seesaw/cluster.pb <<EOF
seesaw_vip: <
  fqdn: "seesaw-vip1.example.com."
  ipv4: "$VIP_IP/$NETMASK"
  status: PRODUCTION
>
node: <
  fqdn: "seesaw1-1.example.com."
  ipv4: "$NODE_IP/$NETMASK"
  status: PRODUCTION
>
node: <
  fqdn: "seesaw1-2.example.com."
  ipv4: "$PEER_IP/$NETMASK"
  status: PRODUCTION
>
vserver: <
  name: "windows.ad.dc@au-syd"
  entry_address: <
    fqdn: "ad-ds-anycast.example.com."
    ipv4: "$VSERVER_IP/$NETMASK"
    status: PRODUCTION
  >
  rp: "windows-team@example.com"
  vserver_entry: <
    protocol: TCP
    port: 80
    scheduler: WRR
    persistence: 3600
    healthcheck: <
      type: TCP
      port: 80
      tls_verify: false
    >
  >
  backend: <
    host: <
      fqdn: "win-dc-1.example.com."
      ipv4: "100.115.222.121/25"
      status: PRODUCTION
    >
    weight: 1
  >
  access_grant: <
    grantee: "windows-admin"
    role: ADMIN
    type: GROUP
  >
>
vlan: <
  vlan_id: 515
  host: <
    fqdn: "seesaw1-vlan515.example.com."
    ipv4: "100.115.222.124/25"
  >
>
metadata: <
  last_updated: 1447906527
>
dedicated_vip_subnet: "192.168.100.0/26"
dedicated_vip_subnet: "2015:cafe:100::/64"
EOF

echo startup > /tmp/startup

