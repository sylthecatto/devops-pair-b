# ────────────────────
# provider + backend
# ────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # 0.9.x is a breaking schema rewrite
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

  # workspace-relative, so the same config works from a local clone and
  # from the jenkins workspace with no per-machine setup. the jenkinsfile
  # excludes *.tfstate* from git clean so builds do not wipe it
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}


# ────────────
# deploy key
# ────────────

# generated here so a fresh clone needs no ssh-keygen step
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

# base_volume_id gives a copy-on-write clone instead of a full copy
resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.pool_b.name
  base_volume_id = libvirt_volume.golden.id
}

# blank disks, ansible formats them ext4
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
  machine = "q35"

  # almalinux 10 needs x86-64-v2, qemu's generic cpu does not provide it
  cpu {
    mode = "host-passthrough"
  }

  firmware = var.ovmf_code
  nvram {
    file     = "${var.nvram_dir}/${local.node_names[count.index]}_VARS.fd"
    template = var.ovmf_vars
  }

  # os disk, virtio -> vda
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # seed as a virtio disk, not via `cloudinit =`. that attaches an IDE
  # cdrom, which q35 has no controller for and cloud-init cannot see
  # during init-local anyway. split() drops the ";uuid" id suffix
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

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

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
  # the interface also reports ipv6 link-local, keep only ipv4
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

# tracked, so destroy removes it instead of leaving a stale file
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts"
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
