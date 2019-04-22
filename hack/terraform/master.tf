
variable "vsphere_user" { default = "" }
variable "vsphere_password" { default = "" }
variable "vsphere_server" { default = "" }
variable "network" { default = "VM Network"}
variable "datacenter" { default = "" }
variable "datastore" { default = "" }
variable "cluster" { default =  "" }
variable "resource_pool" { default = "" }
variable "vm_template" { default = "" }

variable "netmask" { default = "" }
variable "ipv4_gateway" { default = "" }
variable "master_ipv4_address" { default = "" }
variable "standby_ipv4_address" { default = "" }
variable "cluster_vipv4_address" { default = "" }
variable "vlan_vipv4_address" { default = "" }
variable "vserver_vipv4_address" { default = "" }

variable "dns_nameservers" { default = "" }

provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  allow_unverified_ssl = true
}

data "template_file" "master_user_data" {
  template = "${file("cloud-config.yaml")}"
  vars = {
    startup_script = "${base64encode(file("startup.sh"))}"
    gateway = "${var.ipv4_gateway}"
    netmask = "${var.netmask}"
    node_ip = "${var.master_ipv4_address}"
    peer_ip = "${var.standby_ipv4_address}"
    vip_ip = "${var.cluster_vipv4_address}"
    vserver_ip = "${var.vserver_vipv4_address}"
    vlan_ip = "${var.vlan_vipv4_address}"
  }
}

data "template_file" "standby_user_data" {
  template = "${file("cloud-config.yaml")}"
  vars = {
    startup_script = "${base64encode(file("startup.sh"))}"
    gateway = "${var.ipv4_gateway}"
    netmask = "${var.netmask}"
    node_ip = "${var.standby_ipv4_address}"
    peer_ip = "${var.master_ipv4_address}"
    vip_ip = "${var.cluster_vipv4_address}"
    vserver_ip = "${var.vserver_vipv4_address}"
    vlan_ip = "${var.vlan_vipv4_address}"
  }
}

data "vsphere_datastore" "datastore" {
  name          = "${var.datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datacenter" "dc" {
  name = "${var.datacenter}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.cluster}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template_from_ovf" {
  name          = "${var.vm_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "master" {
  name             = "master"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = "2"
  memory   = "1024"
  guest_id = "${data.vsphere_virtual_machine.template_from_ovf.guest_id}"
  wait_for_guest_net_timeout = 10

  #enable_disk_uuid = "true"
  #scsi_type = "${data.vsphere_virtual_machine.template_from_ovf.scsi_type}"

  nested_hv_enabled = true
  cpu_performance_counters_enabled = true

  cdrom {
    client_device = true
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template_from_ovf.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template_from_ovf.disks.0.thin_provisioned}"
  }

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template_from_ovf.network_interface_types[0]}"
  }

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template_from_ovf.network_interface_types[1]}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template_from_ovf.id}"
  }

  vapp {
    properties {
      hostname      = "master"
      password      = "pass"
      "user-data"   = "${base64encode(data.template_file.master_user_data.rendered)}"
    }
  }
}

resource "vsphere_virtual_machine" "standby" {
  name             = "stanby"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = "2"
  memory   = "1024"
  guest_id = "${data.vsphere_virtual_machine.template_from_ovf.guest_id}"
  wait_for_guest_net_timeout = 10

  #enable_disk_uuid = "true"
  #scsi_type = "${data.vsphere_virtual_machine.template_from_ovf.scsi_type}"

  nested_hv_enabled = true
  cpu_performance_counters_enabled = true

  cdrom {
    client_device = true
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template_from_ovf.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template_from_ovf.disks.0.thin_provisioned}"
  }

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template_from_ovf.network_interface_types[0]}"
  }

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template_from_ovf.network_interface_types[1]}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template_from_ovf.id}"
  }

  vapp {
    properties {
      hostname      = "standby"
      password      = "pass"
      "user-data"   = "${base64encode(data.template_file.standby_user_data.rendered)}"
    }
  }
}

