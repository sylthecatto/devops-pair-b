# ────────────────────
# provider + backend
# ────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      # pinned exactly, 0.9.x is a breaking schema rewrite
      version = "0.8.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # state lives OUTSIDE the repo, a wiped jenkins workspace would
  # otherwise leave a destroy button with nothing to destroy
  backend "local" {
    path = "/var/lib/devops-pair-b/tfstate/pair-b/terraform.tfstate"
  }
}

# system-wide libvirtd, not a per-user session, so jenkins and your
# own shell see the same domains and pools
provider "libvirt" {
  uri = "qemu:///system"
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

# uploads packer's golden image into the pool so it can be cloned
resource "libvirt_volume" "golden" {
  name   = "alma10-golden.qcow2"
  pool   = libvirt_pool.pool_b.name
  source = var.golden_image_path
}

# base_volume_id IS the copy-on-write clone, each os disk only stores
# what diverges from the golden image
resource "libvirt_volume" "os_disk" {
  count          = var.node_count
  name           = "${local.node_names[count.index]}-os.qcow2"
  pool           = libvirt_pool.pool_b.name
  base_volume_id = libvirt_volume.golden.id
}

# blank 2G disks, no base_volume_id, ansible formats them ext4
# flat list of node_count * data_disk_count, index math below maps
# each one back to its owning node
resource "libvirt_volume" "data_disk" {
  count = var.node_count * var.data_disk_count
  name = format("%s-data%d.qcow2",
    local.node_names[floor(count.index / var.data_disk_count)],
    (count.index % var.data_disk_count) + 1
  )
  pool = libvirt_pool.pool_b.name
  size = var.data_disk_size_gb * 1024 * 1024 * 1024
}

# native provider resource, no xorriso or null_resource needed, and it
# is tracked state so terraform destroy removes it cleanly
resource "libvirt_cloudinit_disk" "seed" {
  count = var.node_count
  name  = "${local.node_names[count.index]}-seed.iso"
  pool  = libvirt_pool.pool_b.name

  user_data = templatefile("${path.module}/templates/cloud_init.yml.tftpl", {
    hostname   = local.node_names[count.index]
    ssh_user   = var.ssh_user
    ssh_pubkey = trimspace(file(pathexpand(var.ssh_public_key_path)))
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
  count  = var.node_count
  name   = local.node_names[count.index]
  memory = var.memory_mb
  vcpu   = var.vcpu

  running = true

  # machine type deliberately NOT overridden to q35 here, even though
  # packer built on q35. libvirt_cloudinit_disk attaches its iso as an
  # IDE cdrom, and q35 has no IDE controller, so the two are mutually
  # exclusive. libvirt's i440fx default still boots this image under
  # UEFI/OVMF fine, verified on a real apply.

  # REQUIRED. same reason packer passes -cpu host: almalinux 10 needs
  # x86-64-v2 instructions, and qemu's generic simulated cpu does not
  # provide them. without this the kernel boots then glibc dies with
  # "Fatal glibc error: CPU does not support x86-64-v2"
  cpu {
    mode = "host-passthrough"
  }

  # uefi, set explicitly per the task. per-domain nvram file so one
  # vm's boot variables never leak into another
  firmware = var.ovmf_code
  nvram {
    file     = "${var.nvram_dir}/${local.node_names[count.index]}_VARS.fd"
    template = var.ovmf_vars
  }

  # os disk, virtio (default) so the guest sees it as vda, matching
  # what kickstart installed onto
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # seed iso attached as a plain VIRTIO disk (vdb), NOT via the
  # `cloudinit =` attribute. that attribute attaches it as an IDE
  # cdrom, and IDE is not probed yet when cloud-init runs its
  # init-local stage, so `blkid -tLABEL=cidata` returns nothing and
  # cloud-init silently falls back to the None datasource. verified in
  # /var/log/cloud-init.log on a real boot. virtio is ready in time.
  #
  # split() strips the ";<uuid>" suffix: this resource's terraform id is
  # a composite "path;uuid", but volume_id needs the bare libvirt volume
  # key, which for a dir pool is just the path
  disk {
    volume_id = split(";", libvirt_cloudinit_disk.seed[count.index].id)[0]
  }

  # 2 data disks on the SCSI bus, pair b's assigned bus. scsi = true
  # sets a virtio-scsi controller, guest sees these as sda / sdb
  dynamic "disk" {
    for_each = range(var.data_disk_count)
    content {
      volume_id = libvirt_volume.data_disk[count.index * var.data_disk_count + disk.value].id
      scsi      = true
    }
  }

  # block apply until dhcp actually hands out a lease, so the inventory
  # below has real IPs instead of empty strings
  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  # serial console, this is what makes `virsh console pb-node-1` work
  # for the live demo
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
  # the interface reports ipv6 link-local too, keep only ipv4
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

# a tracked resource, so terraform destroy deletes the generated
# inventory instead of leaving a stale one behind
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    nodes    = local.nodes
    ssh_user = var.ssh_user
    # deliberately NOT pathexpand()'d. pathexpand would resolve to the
    # home dir of whoever runs terraform, which is correct on that
    # machine but wrong the moment the file is read anywhere else.
    # ansible expands ~ itself, per-user, so the raw path always works
    ssh_private_key = var.ssh_private_key_path
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
    "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${n.ip}"
  ]
}
