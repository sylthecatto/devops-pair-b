# ────────────
# variables
# ────────────

variable "node_count" {
  type    = number
  default = 2
}

variable "hostname_prefix" {
  type    = string
  default = "pb-node"
}

variable "vcpu" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}


# ────────────
# storage
# ────────────

# pair b's own pool, the task forbids using the default pool
variable "pool_name" {
  type    = string
  default = "pool_b"
}

variable "pool_path" {
  type    = string
  default = "/var/lib/libvirt/pools/pool_b"
}

# must match packer's output_directory + vm_name exactly
variable "golden_image_path" {
  type    = string
  default = "/var/lib/devops-pair-b/images/alma10-golden/alma10-golden.qcow2"
}

# 2 blank data disks per node, ansible formats these ext4 later
variable "data_disk_count" {
  type    = number
  default = 2
}

variable "data_disk_size_gb" {
  type    = number
  default = 2
}


# ────────
# uefi
# ────────

# same firmware packer built with, confirmed via: rpm -ql edk2-ovmf
variable "ovmf_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

# each domain gets its own nvram copy, never a shared file
variable "nvram_dir" {
  type    = string
  default = "/var/lib/libvirt/qemu/nvram"
}


# ────────
# access
# ────────

# the account kickstart.cfg creates, must match everywhere
variable "ssh_user" {
  type    = string
  default = "syl"
}

# DEPLOY key, deliberately different from packer's build key
variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/pairB_deploy.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/pairB_deploy"
}

variable "network_name" {
  type    = string
  default = "default"
}
