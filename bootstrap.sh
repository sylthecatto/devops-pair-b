#!/usr/bin/env bash
# one-time host prep. safe to re-run, every step is a no-op if already done.
set -euo pipefail

STATE_DIR=/var/lib/devops-pair-b
BUILD_KEY=~/.ssh/pairB_build
SHARED_GROUP=libvirt

# shared state dir, deliberately not $HOME and not the repo.
#
# not the repo: jenkins wipes its workspace, which would leave
# DESTROY_AND_REBUILD with no state and orphaned vms on the hypervisor.
#
# not $HOME: jenkins runs as its own user, so per-user paths give jenkins
# and your shell two different state files that both think they own
# pool_b.
#
# owned by the libvirt group instead of one user, because both you and
# the jenkins service account are already in it (jenkins needs libvirt
# access for virsh regardless). setgid so anything created later
# inherits the group instead of reverting to the creator's.
if [ -d "$STATE_DIR" ] && [ "$(stat -c %G "$STATE_DIR")" = "$SHARED_GROUP" ] && [ -g "$STATE_DIR" ]; then
  echo "==> $STATE_DIR already set up"
else
  echo "==> $STATE_DIR (needs sudo, /var/lib is root-owned)"
  sudo mkdir -p "$STATE_DIR"/{images,tfstate/pair-b}
  sudo chgrp -R "$SHARED_GROUP" "$STATE_DIR"
  sudo chmod -R g+rwX "$STATE_DIR"
  sudo find "$STATE_DIR" -type d -exec chmod g+s {} +
fi

# packer build key. packer cannot generate this itself: the kickstart is
# served from http_content in the source block, which is evaluated before
# the ssh communicator exists, so build.SSHPublicKey is not available yet.
if [ ! -f "$BUILD_KEY" ]; then
  echo "==> generating $BUILD_KEY"
  ssh-keygen -t ed25519 -f "$BUILD_KEY" -N "" -q
else
  echo "==> $BUILD_KEY already exists"
fi

# the deploy key is NOT created here, terraform generates it on apply

cat <<'EOF'

ready. next:
  cd packer    && packer init . && packer build .
  cd terraform && terraform init && terraform apply
EOF
