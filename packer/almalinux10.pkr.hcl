# ────────────────
# packer plugins 
# ────────────────
packer {
  required_plugins {
    qemu = {
      version = "1.1.6"
      source  = "github.com/hashicorp/qemu"
    }
  }
}


# ────────────
# variables 
# ────────────

variable "alma_version" {
  type    = string
  default = "10.2"
}

# relative to packer/, gitignored. terraform reads it from ../packer/output
variable "output_directory" {
  type    = string
  default = "output"
}

variable "efi_firmware_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "efi_firmware_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

variable "build_ssh_private_key" {
  type    = string
  default = "~/.ssh/pairB_build"
}

variable "build_ssh_public_key" {
  type    = string
  default = "~/.ssh/pairB_build.pub"
}


# ────────
# source 
# ────────
source "qemu" "almalinux10" {
  iso_url = "https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/AlmaLinux-${var.alma_version}-x86_64-minimal.iso"

  # point at the published CHECKSUM file instead of hardcoding a SHA256
  iso_checksum = "file:https://repo.almalinux.org/almalinux/${var.alma_version}/isos/x86_64/CHECKSUM"

  # q35 = modern chipset, REQUIRED for UEFI boot (the older i440fx has
  # no UEFI support at all)
  machine_type = "q35"
  accelerator  = "kvm"
  cpus         = 2
  memory       = 2048
  disk_size    = "20G"
  format       = "qcow2"

  # no VNC window
  headless = true

  # pass the real host CPU through instead of QEMU's generic CPU 
  qemuargs = [["-cpu", "host"]]

  efi_boot          = true
  efi_firmware_code = var.efi_firmware_code
  efi_firmware_vars = var.efi_firmware_vars

  # packer spins up a tiny local HTTP server for the build and serves
  # this rendered file from it. templatefile() fills kickstart.cfg's
  # ${build_ssh_public_key} placeholder with the real key content
  # before anything is served 
  http_content = {
    "/kickstart.cfg" = templatefile("${path.root}/kickstart.cfg", {
      build_ssh_public_key = trimspace(file(pathexpand(var.build_ssh_public_key)))
    })
  }

  boot_wait = "5s"
  boot_command = [
    "e<wait2>",          # 'e' edits the highlighted GRUB entry
    "<down><down><end>", # navigate to the kernel command line, go to its end
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kickstart.cfg inst.text",
    "<wait2>",
    "<leftCtrlOn>x<leftCtrlOff>" # Ctrl+X boots the edited entry
  ]

  # "syl" — the account kickstart.cfg's `user --name=syl` actually
  # creates. Must match exactly or Packer has no account to connect as.
  ssh_username         = "syl"
  ssh_private_key_file = pathexpand(var.build_ssh_private_key)
  ssh_timeout          = "60m"
  shutdown_command     = "sudo shutdown -P now"

  output_directory = var.output_directory
  vm_name          = "alma10-golden.qcow2"
}


# ───────
# build 
# ───────

build {
  sources = ["source.qemu.almalinux10"]

  # wipe the build ssh key, if not removed the build key 
  #would stay valid on every clone made from this image forever
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /home/syl/.ssh/authorized_keys",
      "sync"
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
