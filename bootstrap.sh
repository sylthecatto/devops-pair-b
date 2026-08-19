#!/usr/bin/env bash
# one-time host prep. safe to re-run, no-op if already done. no sudo needed.
set -euo pipefail

BUILD_KEY=~/.ssh/pairB_build

# packer build key. packer cannot generate this itself: the kickstart is
# served from http_content in the source block, which is evaluated before
# the ssh communicator exists, so build.SSHPublicKey is not available yet.
#
# the deploy key is NOT created here, terraform generates it on apply.
# state and the golden image are workspace-relative, so nothing else to set up.
if [ ! -f "$BUILD_KEY" ]; then
  echo "==> generating $BUILD_KEY"
  ssh-keygen -t ed25519 -f "$BUILD_KEY" -N "" -q
else
  echo "==> $BUILD_KEY already exists"
fi

cat <<'EOF'

ready. next:
  cd packer    && packer init . && packer build .
  cd terraform && terraform init && terraform apply
EOF
