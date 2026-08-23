variable "pool_name" {
  type    = string
  default = "aeron_pool"
}

variable "pool_path" {
  type    = string
  default = "/var/lib/libvirt/images/aeron_pool"
}

variable "golden_image_path" {
  type    = string
  default = "../packer/output/alma10-golden.qcow2"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "memory_mb" {
  type    = number
  default = 1536
}

variable "vcpu" {
  type    = number
  default = 2
}
