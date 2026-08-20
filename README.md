# DevOps Pair B: Enterprise Infrastructure & CIS Security Hardening Pipeline

An end-to-end automated DevOps pipeline for building, provisioning, hardening, and auditing **AlmaLinux 10** virtual infrastructure.

---

## 🏗️ Architecture Overview

```text
[ Host Bootstrap ] ---> [ Packer Golden Image ] ---> [ Terraform Infrastructure ] ---> [ Ansible CIS Hardening ] ---> [ Jenkins CI/CD ]
  (bootstrap.sh)        (AlmaLinux 10 QCOW2)       (Libvirt q35 + Cloud-Init)      (RHEL10-CIS Benchmark)      (Declarative Pipeline)
```

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Image Builder** | **Packer 1.10+** | Compiles headless AlmaLinux 10 QCOW2 golden image with Kickstart automation |
| **Infrastructure** | **Terraform 1.5+** | Provisions 2 Libvirt q35 VMs (`pb-node-1`, `pb-node-2`) with 4GB RAM & SCSI data disks |
| **Security Engine**| **Ansible 2.15+** | Remediates CIS RHEL 10 Level 1 benchmark to **93.30% compliance** using Ansible Vault |
| **Audit Framework**| **Goss Audit** | Executes 711 pre-scan & post-scan security rule assertions |
| **CI/CD Pipeline** | **Jenkins** | Automates end-to-end build, terraform apply, hardening, and artifact archiving |

---

## 📁 Repository Directory Structure

```text
devops-pair-b/
├── Jenkinsfile                      # Declarative 5-stage Jenkins CI/CD pipeline
├── README.md                        # Master repository documentation & runbook
├── bootstrap.sh                     # Host prep script & static build key generator
├── .gitignore                       # Ignored secrets, state memory, and build artifacts
│
├── packer/                          # Golden Image Build
│   ├── almalinux10.pkr.hcl          # Packer HCL build template
│   └── kickstart.cfg                # Automated AlmaLinux 10 OS installer configuration
│
├── terraform/                       # Infrastructure Provisioning
│   ├── main.tf                      # Libvirt q35 domains, network, pool & disk resources
│   └── variables.tf                 # 4096MB RAM, 2 vCPU & pool configuration variables
│
├── ansible/                         # Security Hardening & Audit
│   ├── ansible.cfg                  # SSH pipelining & multiplexing configuration
│   ├── playbook.yml                 # Playbook with Level 2 vars & ext4 SCSI formatting
│   ├── requirements.yml             # Lockdown RHEL10-CIS role dependency (v1.1.0)
│   ├── vaultpass.txt                # Local vault password file (Git-ignored)
│   ├── group_vars/
│   │   ├── pb_nodes.yml             # Level 1 precedence variables & audit flags
│   │   └── vault.yml                # AES256 encrypted root password store
│   └── inventory/
│       └── hosts                    # Dynamically generated inventory (Git-ignored)
│
└── docs/                            # Project Documentation & Q&A
    ├── pair_b_implementation_journal.md  # Step-by-step implementation journal
    ├── presentation_q_and_a.md           # 24 presentation & mentor defense items
    └── user_runbook_guide.md             # Complete user runbook & testing guide
```

---

## 🚀 Execution Guide: Track A (Manual CLI Execution)

Follow these step-by-step commands to run the entire pipeline manually in your terminal:

### Step 1: Bootstrap Host Environment
```bash
./bootstrap.sh
```
*Generates static build SSH keys (`~/.ssh/pairB_build`) required by Packer.*

### Step 2: Build Packer Golden Image
```bash
cd packer
packer init .
packer build .
cd ..
```
*Creates `/home/bunny/devops-pair-b/packer/output/alma10-golden.qcow2` (2.9 GB).*

### Step 3: Provision Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform apply -auto-approve
cd ..
```
*Provisions `pb-node-1` & `pb-node-2` with 4GB RAM, generates ED25519 deploy key (`terraform/.ssh/pairB_deploy`), and writes `ansible/inventory/hosts`.*

### Step 4: Execute Ansible Hardening & Audit
```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventory/hosts playbook.yml \
  --vault-password-file vaultpass.txt \
  -e "rhel10cis_pass_max_days=30" \
  --skip-tags "level2-server,level2-workstation"
cd ..
```
*Applies 411 security tasks across both VMs and generates Goss JSON audit reports.*

---

## ⚙️ Execution Guide: Track B (Jenkins Automated CI/CD)

### 1. Configure Jenkins Pipeline Job
1. In Jenkins UI, click **New Item** $\rightarrow$ Name: `Pair-B-Pipeline` $\rightarrow$ Select **Pipeline**.
2. Scroll to **Pipeline** section $\rightarrow$ Definition: **Pipeline script from SCM**.
3. SCM: **Git** $\rightarrow$ Repository URL: `https://github.com/sylthecatto/devops-pair-b.git` $\rightarrow$ Branch: `*/main` $\rightarrow$ Script Path: `Jenkinsfile`.

### 2. Add Vault Credential to Jenkins
1. Go to **Jenkins Dashboard** $\rightarrow$ **Manage Jenkins** $\rightarrow$ **Credentials** $\rightarrow$ **System** $\rightarrow$ **Global credentials**.
2. Click **+ Add Credentials**:
   - Kind: **Secret text**
   - Secret: `pairB_vault_secret_123`
   - ID: **`ANSIBLE_VAULT_PASS_REAL`**

### 3. Trigger Pipeline Build
Click **Build with Parameters**:
- `DESTROY_AND_REBUILD`: `true`
- `REBUILD_IMAGE`: `false` *(reuses existing QCOW2 image for fast build)*

---

## 🧪 Verification & VM Testing Guide

### 1. View Live Node IP Addresses
```bash
virsh net-dhcp-leases default
```

### 2. Access VMs Provisioned by Manual CLI
```bash
ssh -i terraform/.ssh/pairB_deploy syl@<node_ip>
```

### 3. Access VMs Provisioned by Jenkins Pipeline
```bash
# Copy Jenkins deploy key to local user:
sudo cp /var/lib/jenkins/workspace/pair-b-pipeline-real/terraform/.ssh/pairB_deploy ~/.ssh/pairB_deploy
sudo chown $USER:$USER ~/.ssh/pairB_deploy
chmod 600 ~/.ssh/pairB_deploy

# SSH into node:
ssh -i ~/.ssh/pairB_deploy syl@<node_ip>
```

### 4. Verify Hardening Features inside VM
Once logged into the VM, execute these verification checks:

```bash
# A. Verify Hardened Banner:
cat /etc/issue

# B. Verify Formatted SCSI Data Disks (ext4):
lsblk
df -hT /dev/sda /dev/sdb

# C. Verify Journald System Logging:
journalctl -n 20

# D. Verify PAM Security Authselect Profile:
authselect current
```

---

## 📊 Final Goss Audit Compliance Results

```text
PLAY RECAP *********************************************************************
pb-node-1                  : ok=411  changed=160  unreachable=0    failed=0    skipped=250
pb-node-2                  : ok=411  changed=160  unreachable=0    failed=0    skipped=250
```

* **Pre-Remediation Score:** 451 / 701 Passed (64.3%)
* **Post-Remediation Score:** **654 / 701 Passed (93.30%)** 🏆 *(Exceeds 90% benchmark target!)*
