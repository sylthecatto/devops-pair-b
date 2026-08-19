# Pair B Enterprise Implementation Journal & Production Walkthrough

This document records the step-by-step end-to-end execution lifecycle for **DevOps Pair B**, aligning Ansible hardening and Jenkins pipeline orchestration with teammate `sylthecatto`'s infrastructure setup.

---

## 1. Executive Summary & Workflow Architecture

```text
[Host Preparation] ---> [Packer Golden Image] ---> [Terraform Infrastructure] ---> [Ansible Hardening] ---> [Jenkins CI/CD]
   (bootstrap.sh)        (AlmaLinux 10 QEMU)       (Libvirt q35 + Cloud-Init)     (RHEL10-CIS Role)      (End-to-End Pipeline)
```

---

## 2. Infrastructure Setup (Teammate's Track)

### Step 2.1: Host Environment Preparation (`./bootstrap.sh`)
- Executed workspace-relative environment bootstrap (`./bootstrap.sh`).
- Pre-generated static build key `~/.ssh/pairB_build` for Packer SSH communicator.
- Eliminates `sudo` requirement during build execution.

### Step 2.2: Packer Golden Image Build (`packer/`)
- Compiled fresh AlmaLinux 10 golden image via headless QEMU builder:
  `cd packer && packer init . && packer build .`
- Output artifact: `/home/bunny/devops-pair-b/packer/output/alma10-golden.qcow2` (2.9 GB).
- Image Sanitization: Provisioner cleanup executed `cloud-init clean` and truncated `/home/syl/.ssh/authorized_keys` to remove temporary build keys.

### Step 2.3: Terraform Provisioning & Dynamic Inventory (`terraform/`)
- Initialized and applied Libvirt infrastructure:
  `cd terraform && terraform init && terraform apply -auto-approve`
- Generated dynamic ED25519 deploy key (`terraform/.ssh/pairB_deploy`).
- Created Libvirt q35 virtual machines (`pb-node-1`, `pb-node-2`).
- Dynamically generated Ansible inventory file at **`ansible/inventory/hosts`**.

---

## 3. Ansible Security Hardening Implementation (My Track)

### Step 3.1: Live Connectivity Verification
- Verified SSH ping connectivity across generated `pb_nodes` inventory:
  - `pb-node-1` (`192.168.122.70`) -> **SUCCESS (`ping: pong`)**
  - `pb-node-2` (`192.168.122.137`) -> **SUCCESS (`ping: pong`)**

### Step 3.2: Dynamic Role Management (`ansible/requirements.yml`)
- Created `ansible/requirements.yml` to pull `RHEL10-CIS` dynamically:

```yaml
---
roles:
  - name: RHEL10-CIS
    src: https://github.com/ansible-lockdown/RHEL10-CIS.git
    scm: git
    version: 1.1.0
```

### Step 3.3: Downloading Role Dependencies
- Executed `ansible-galaxy install -r requirements.yml -p roles/` to pull release tag `1.1.0`.

### Step 3.4: Ansible Vault Secrets Setup (`ansible/group_vars/vault.yml`)
- Generated local vault password file `ansible/vaultpass.txt`.
- Created encrypted variable store `ansible/group_vars/vault.yml` holding sensitive parameters (`vault_root_password`).
- Encrypted secrets using AES256:
  `ansible-vault encrypt group_vars/vault.yml --vault-password-file vaultpass.txt`

### Step 3.5: Precedence Level 1 Group Variables (`ansible/group_vars/pb_nodes.yml`)
- Configured baseline group variables:
  - Enabled Goss auditing (`setup_audit: true`, `run_audit: true`, `fetch_audit_output: true`).
  - Configured logging strategy (`rhel10cis_syslog: journald`).
  - Set Level 1 baseline (`rhel10cis_level_2: false`).
  - Disabled password state assertion failure (`rhel10cis_rule_5_2_4: false`) for key-authenticated user `syl`.
  - Configured custom authselect profile (`rhel10cis_authselect_custom_profile_name: custom_pair_b_profile`).

### Step 3.6: Precedence Level 2 & Data Disk Pre-Tasks (`ansible/playbook.yml`)
- Configured `ansible/playbook.yml` with Level 2 playbook variables (`rhel10cis_warning_banner`, safety rule account lockout overrides `rhel10cis_rule_5_3_2_1_1-3: false`).
- Implemented `pre_tasks` block formatting the 2 SCSI data disks (`/dev/sda`, `/dev/sdb`) to `ext4` filesystem.

### Step 3.7: Ansible Engine Performance & SSH Pipelining (`ansible/ansible.cfg`)
- Configured `ansible/ansible.cfg` with `pipelining = True` and `timeout = 30` to reuse multiplexed SSH connections and prevent privilege escalation timeouts.

### Step 3.8: Execution & Final Goss Audit Verification
- Executed hardening playbook:
  `ansible-playbook -i inventory/hosts playbook.yml --vault-password-file vaultpass.txt -e "rhel10cis_pass_max_days=30" --skip-tags "level2-server,level2-workstation"`

---

## 4. Final Goss Audit Audit Results & Compliance Score

```text
PLAY RECAP *********************************************************************
pb-node-1                  : ok=411  changed=160  unreachable=0    failed=0    skipped=250
pb-node-2                  : ok=411  changed=160  unreachable=0    failed=0    skipped=250
```

### Audit Breakdown:
- **Pre-Remediation Failed Tests:** 231 / 711
- **Post-Remediation Failed Tests:** 47 / 711
- **Active Tests Evaluated:** 654 / 701
- **Final Level 1 Compliance Score:** **93.30%** (Exceeds the 90% requirement target!) 🏆
