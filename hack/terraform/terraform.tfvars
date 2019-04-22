# Vsphere configurations
vsphere_user = "administrator@vsphere.local"
vsphere_password = ""
vsphere_server = "100.115.254.129"

datastore = "HOST3-DATASTORE1"
datacenter = "GKE-DATACENTER"
cluster = "GKE-CLUSTER"
resource_pool = "ygui"
network = "100-115-222-128-25-STATIC"
vm_template = "ubuntu-bionic-18.04-cloudimg-20190402"

# Seesaw configurations
netmask = "25"
ipv4_gateway = "100.115.222.254"
master_ipv4_address = "100.115.222.236"
standby_ipv4_address = "100.115.222.237"
cluster_vipv4_address = "100.115.222.238"
vserver_ipv4_address = "100.115.222.239"
vlan_ipv4_address = "100.115.222.240"
