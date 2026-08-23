terraform {
  required_version = ">= 1.5.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system?socket=/var/run/libvirt/virtqemud-sock"
}

resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "deploy_key" {
  filename        = "${path.module}/.ssh/aeron_deploy"
  content         = tls_private_key.deploy.private_key_openssh
  file_permission = "0600"
}

resource "libvirt_pool" "aeron_pool" {
  name = var.pool_name
  type = "dir"
  target {
    path = var.pool_path
  }
}

resource "libvirt_volume" "golden" {
  name   = "aeron-golden.qcow2"
  pool   = libvirt_pool.aeron_pool.name
  source = var.golden_image_path
}

locals {
  node_names = ["web-node-1", "web-node-2", "db-node-1"]
}

resource "libvirt_volume" "os_disk" {
  count          = 3
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.aeron_pool.name
  base_volume_id = libvirt_volume.golden.id
}

resource "libvirt_cloudinit_disk" "seed" {
  count = 3
  name  = "${local.node_names[count.index]}-seed.iso"
  pool  = libvirt_pool.aeron_pool.name

  user_data = <<-EOT
    #cloud-config
    hostname: ${local.node_names[count.index]}
    ssh_pwauth: true
    users:
      - name: sysadmin
        sudo: ALL=(ALL) NOPASSWD:ALL
        groups: wheel
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(tls_private_key.deploy.public_key_openssh)}
  EOT
}

resource "libvirt_domain" "node" {
  count   = 3
  name    = local.node_names[count.index]
  memory  = var.memory_mb
  vcpu    = var.vcpu
  running = true
  machine = "q35"

  cpu {
    mode = "host-passthrough"
  }

  firmware = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
  nvram {
    file     = "${var.pool_path}/${local.node_names[count.index]}_VARS.fd"
    template = "/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd"
  }

  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  disk {
    volume_id = split(";", libvirt_cloudinit_disk.seed[count.index].id)[0]
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"
  content         = <<-EOT
    ---
    all:
      children:
        webservers:
          hosts:
            web-node-1:
              ansible_host: ${libvirt_domain.node[0].network_interface[0].addresses[0]}
            web-node-2:
              ansible_host: ${libvirt_domain.node[1].network_interface[0].addresses[0]}
        dbservers:
          hosts:
            db-node-1:
              ansible_host: ${libvirt_domain.node[2].network_interface[0].addresses[0]}
      vars:
        ansible_user: sysadmin
        ansible_ssh_private_key_file: ${abspath(local_sensitive_file.deploy_key.filename)}
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
  EOT
}
