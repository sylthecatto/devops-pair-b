# DevOps Pair B: User Runbook & Testing Guide

This document provides a detailed walkthrough for engineers and evaluators running the **DevOps Pair B** repository manually in CLI or automatically in Jenkins.

---

## 1. Quick Start Execution Matrix

| Track | Primary Command / Workflow | Duration | Output / Artifacts |
| :--- | :--- | :--- | :--- |
| **Track A (Manual CLI)** | `./bootstrap.sh` $\rightarrow$ `packer build` $\rightarrow$ `terraform apply` $\rightarrow$ `ansible-playbook` | ~3–10 mins | Live VMs + `ansible/*.json` reports |
| **Track B (Jenkins CI/CD)** | Jenkins Pipeline UI $\rightarrow$ **Build with Parameters** | ~2 mins *(cached)* | Jenkins Dashboard Artifacts + Live VMs |

---

## 2. Directory & Folder Map

* **`./bootstrap.sh`**: One-time host environment setup script. Generates static SSH build key `~/.ssh/pairB_build`.
* **`packer/`**: Contains `almalinux10.pkr.hcl` and `kickstart.cfg`. Builds the AlmaLinux 10 golden QCOW2 image.
* **`terraform/`**: Contains `main.tf` and `variables.tf`. Provisions Libvirt virtual machines (`pb-node-1`, `pb-node-2`), 4GB RAM per node, 2 vCPUs, 2 SCSI data disks, and generates `ansible/inventory/hosts`.
* **`ansible/`**: Contains CIS security hardening playbooks (`playbook.yml`), group variables (`group_vars/pb_nodes.yml`), vault secrets (`group_vars/vault.yml`), and configuration (`ansible.cfg`).
* **`Jenkinsfile`**: Declarative 5-stage Jenkins pipeline automating workspace prep, Packer, Terraform, Ansible hardening, and Goss audit report archiving.
* **`docs/`**: Project documentation, implementation journal, presentation Q&A defense items, and this user runbook guide.

---

## 3. Step-by-Step CLI Execution Track

### Step 3.1: Initialize Host Environment
Run from project root:
```bash
./bootstrap.sh
```

### Step 3.2: Build Golden Image (Packer)
```bash
cd packer
packer init .
packer build .
cd ..
```

### Step 3.3: Provision Virtual Infrastructure (Terraform)
```bash
cd terraform
terraform init
terraform apply -auto-approve
cd ..
```

### Step 3.4: Apply Security Hardening (Ansible)
```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventory/hosts playbook.yml \
  --vault-password-file vaultpass.txt \
  -e "rhel10cis_pass_max_days=30" \
  --skip-tags "level2-server,level2-workstation"
cd ..
```

---

## 4. Step-by-Step Jenkins Automation Track

1. Navigate to Jenkins: `http://localhost:8080/`
2. Open job: **`Pair-B-Pipeline`**
3. Click **Build with Parameters**:
   - `DESTROY_AND_REBUILD`: `true`
   - `REBUILD_IMAGE`: `false`
4. Click **Build**.

---

## 5. VM Testing & Inspection Commands

### 1. Identify Live VM IP Addresses
```bash
virsh net-dhcp-leases default
```

### 2. SSH into VM
```bash
# If provisioned via CLI:
ssh -i terraform/.ssh/pairB_deploy syl@<node_ip>

# If provisioned via Jenkins:
sudo cp /var/lib/jenkins/workspace/pair-b-pipeline-real/terraform/.ssh/pairB_deploy ~/.ssh/pairB_deploy
sudo chown $USER:$USER ~/.ssh/pairB_deploy
chmod 600 ~/.ssh/pairB_deploy
ssh -i ~/.ssh/pairB_deploy syl@<node_ip>
```

### 3. Run Post-Hardening Inspections Inside VM
```bash
# Check hardened banner:
cat /etc/issue

# Check ext4 formatted SCSI data disks:
lsblk
df -hT /dev/sda /dev/sdb

# Check journald system logging:
journalctl -n 20
```
