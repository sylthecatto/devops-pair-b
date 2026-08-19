# ────────────
# nodes
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

# pair b's own pool, the task forbids the default pool
variable "pool_name" {
  type    = string
  default = "pool_b"
}

variable "pool_path" {
  type    = string
  default = "/var/lib/libvirt/pools/pool_b"
}

# must match packer's output_directory + vm_name
variable "golden_image_path" {
  type    = string
  default = "/var/lib/devops-pair-b/images/alma10-golden/alma10-golden.qcow2"
}

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

# confirmed via: rpm -ql edk2-ovmf
variable "ovmf_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

variable "nvram_dir" {
  type    = string
  default = "/var/lib/libvirt/qemu/nvram"
}


# ────────
# access
# ────────

# the account kickstart.cfg creates
variable "ssh_user" {
  type    = string
  default = "syl"
}

# where terraform writes the deploy key it generates. inside the repo
# dir and gitignored, so no ~/.ssh setup is needed on a fresh machine
variable "ssh_key_dir" {
  type    = string
  default = ".ssh"
}

variable "network_name" {
  type    = string
  default = "default"
}
