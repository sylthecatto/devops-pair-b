# ────────────────────
# provider + backend
# ────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # pinned, 0.9.x is a breaking schema rewrite
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

  # state lives outside the repo so a wiped workspace still has
  # something to destroy
  backend "local" {
    path = "/var/lib/devops-pair-b/tfstate/pair-b/terraform.tfstate"
  }
}

# system-wide libvirtd so jenkins and your shell see the same domains
provider "libvirt" {
  uri = "qemu:///system"
}


# ────────────
# deploy key
# ────────────

# generated here rather than by hand, so a fresh clone needs no
# ssh-keygen step. gitignored, and destroyed with everything else
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "deploy_key" {
  filename        = "${path.module}/${var.ssh_key_dir}/pairB_deploy"
  content         = tls_private_key.deploy.private_key_openssh
  file_permission = "0600"
}


# ──────────
# storage
# ──────────

locals {
  node_names = [for i in range(var.node_count) : "${var.hostname_prefix}-${i + 1}"]
}

resource "libvirt_pool" "pool_b" {
  name = var.pool_name
  type = "dir"
  target {
    path = var.pool_path
  }
}

resource "libvirt_volume" "golden" {
  name   = "alma10-golden.qcow2"
  pool   = libvirt_pool.pool_b.name
  source = var.golden_image_path
}

# base_volume_id is the copy-on-write clone
resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.pool_b.name
  base_volume_id = libvirt_volume.golden.id
}

# blank disks, ansible formats them ext4. flat list, index math maps
# each back to its owning node
resource "libvirt_volume" "data_disk" {
  count = var.node_count * var.data_disk_count
  name = format("%s-data%d.qcow2",
    local.node_names[floor(count.index / var.data_disk_count)],
    (count.index % var.data_disk_count) + 1
  )
  pool = libvirt_pool.pool_b.name
  size = var.data_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "seed" {
  count = var.node_count
  name  = "${local.node_names[count.index]}-seed.iso"
  pool  = libvirt_pool.pool_b.name

  user_data = templatefile("${path.module}/templates/cloud_init.yml.tftpl", {
    hostname   = local.node_names[count.index]
    ssh_user   = var.ssh_user
    ssh_pubkey = trimspace(tls_private_key.deploy.public_key_openssh)
  })

  meta_data = <<-EOT
    instance-id: ${local.node_names[count.index]}
    local-hostname: ${local.node_names[count.index]}
  EOT
}


# ──────────
# domains
# ──────────

resource "libvirt_domain" "node" {
  count   = var.node_count
  name    = local.node_names[count.index]
  memory  = var.memory_mb
  vcpu    = var.vcpu
  running = true

  # required: almalinux 10 needs x86-64-v2, qemu's generic cpu does not
  # provide it and glibc dies at boot without this
  cpu {
    mode = "host-passthrough"
  }

  # q35 matches what packer built on. only possible because the seed is
  # attached as a virtio disk below, not via `cloudinit =` (that forces
  # an IDE cdrom, and q35 has no IDE controller)
  machine = "q35"

  firmware = var.ovmf_code
  nvram {
    file     = "${var.nvram_dir}/${local.node_names[count.index]}_VARS.fd"
    template = var.ovmf_vars
  }

  # os disk, virtio -> vda
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # seed as a virtio disk, NOT via `cloudinit =`. that attaches it as an
  # IDE cdrom which is not probed yet when cloud-init runs init-local,
  # so blkid finds no cidata label and it falls back to no datasource.
  # split() strips the ";uuid" suffix off the terraform id
  disk {
    volume_id = split(";", libvirt_cloudinit_disk.seed[count.index].id)[0]
  }

  # data disks on scsi, pair b's assigned bus -> sda / sdb
  dynamic "disk" {
    for_each = range(var.data_disk_count)
    content {
      volume_id = libvirt_volume.data_disk[count.index * var.data_disk_count + disk.value].id
      scsi      = true
    }
  }

  # block until dhcp lands so the inventory gets real IPs
  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  # makes `virsh console pb-node-1` work for the live demo
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}


# ────────────────────
# ansible inventory
# ────────────────────

locals {
  # interface also reports ipv6 link-local, keep only ipv4
  node_ips = [
    for d in libvirt_domain.node :
    try([
      for a in flatten(d.network_interface[*].addresses) :
      a if can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", a))
    ][0], "")
  ]

  nodes = [
    for i, name in libvirt_domain.node[*].name : {
      name = name
      ip   = local.node_ips[i]
    }
  ]
}

# tracked, so destroy removes it instead of leaving a stale file.
# gitignored: it is generated per machine, never shared
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    nodes           = local.nodes
    ssh_user        = var.ssh_user
    ssh_private_key = abspath(local_sensitive_file.deploy_key.filename)
  })
}


# ──────────
# outputs
# ──────────

output "node_ips" {
  value = local.node_ips
}

output "ssh_commands" {
  value = [
    for n in local.nodes :
    "ssh -i ${abspath(local_sensitive_file.deploy_key.filename)} ${var.ssh_user}@${n.ip}"
  ]
}
