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
  default = 3072
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

# relative to terraform/, must match packer's output_directory + vm_name
variable "golden_image_path" {
  type    = string
  default = "../packer/output/alma10-golden.qcow2"
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

# confirmed with: rpm -ql edk2-ovmf
variable "ovmf_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

# outside the pool dir, otherwise destroy fails on a non-empty pool
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

# gitignored, terraform writes the generated keypair here
variable "ssh_key_dir" {
  type    = string
  default = ".ssh"
}

variable "network_name" {
  type    = string
  default = "default"
}
