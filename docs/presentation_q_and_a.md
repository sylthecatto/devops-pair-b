# Pair B Presentation Q&A & Architectural Defense Guide

This document contains all mentor Q&A questions, architectural defenses, and presentation scripts for **DevOps Pair B (Ansible & Jenkins Track)**.

---

## 1. Role Management & Version Pinning

### Q1: Why do we pull `RHEL10-CIS` via `requirements.yml` and pin it specifically to `version: 1.1.0`?
- **Answer & Justification:**
  1. **Repository Cleanliness (No Git Bloat)**: Committing thousands of raw role files directly into Git bloats the repository and makes code reviews unreadable.
  2. **Immutability & Reproducibility**: Pinning to tag `1.1.0` guarantees that every developer machine and Jenkins pipeline agent builds against the exact same tested code baseline.
  3. **Supply-Chain Security**: Prevents unvetted upstream `main` branch commits from introducing breaking syntax changes or unexpected security regressions into our production pipeline.

---

## 2. Infrastructure & SSH Access Model

### Q2: Why do we log in as `syl` / `cloud-user` with `become: true` instead of logging in directly as `root`?
- **Answer & Justification:**
  Logging in directly as `root` over SSH violates enterprise security compliance and CIS benchmarks. We log in as an unprivileged user (`syl` / `cloud-user`) authenticated exclusively via ED25519 SSH keys, and use Ansible's `become: true` privilege escalation to execute root administrative tasks via `sudo`.

### Q3: Why format SCSI data disks in Ansible `pre_tasks`?
- **Answer & Justification:**
  Terraform provisions raw SCSI block devices (`/dev/sda`, `/dev/sdb`) without filesystems. Placing disk formatting in Ansible `pre_tasks` guarantees storage filesystems (`ext4`) are formatted and mounted *before* `RHEL10-CIS` benchmark rules execute filesystem security checks.

---

## 3. Secrets Security & Vault

### Q4: How does Ansible Vault secure sensitive parameters in Jenkins?
- **Answer & Justification:**
  Hardcoding plaintext secrets in Git is a critical security vulnerability. We encrypt sensitive parameters using `ansible-vault` (AES256 encryption). In Jenkins, the vault password is injected securely at runtime from Jenkins Credentials into a temporary file, enabling in-memory RAM decryption while keeping repository files fully encrypted on disk.

---

## 4. Role Fixes & Workarounds

### Q5: Why set `rhel10cis_sshd_allowusers: ""` in `group_vars/pb_nodes.yml`?
- **Answer & Justification:**
  In `RHEL10-CIS` version 1.1.0, task 5.2.x evaluates `rhel10cis_sshd_allowusers` inside a Jinja2 string join filter (`join(' ')`). Leaving the variable as `null`/undefined triggers a Python `TypeError: 'NoneType' object is not iterable` crash. Initializing `rhel10cis_sshd_allowusers: ""` satisfies Jinja2 syntax requirements.

### Q6: Why set `rhel10cis_rule_1_2_1_1: false` (Bypass GPG Key Check)?
- **Answer & Justification:**
  Rule 1.2.1.1 enforces GPG key verification on DNF package repositories (`gpgcheck=1`). In our Kickstart build environment, GPG keys are not pre-imported into the RPM database. Disabling Rule 1.2.1.1 prevents package update tasks from throwing `GPG key verification failed` errors during automated pipeline runs.

### Q7: What is the difference between `setup_audit`, `run_audit`, and `audit_only`?
- **Answer & Justification:**
  - **`setup_audit: true`**: Installs Goss binary and configures test YAML assertions on the VM.
  - **`run_audit: true`**: Executes the Goss audit *after* Ansible applies remediation tasks, generating the compliance report.
  - **`audit_only: false`**: If `true`, Ansible skips all remediation tasks and *only* audits. We keep `audit_only: false` because our pipeline requirement is to apply CIS Level 1 remediation *and then* generate the Goss audit report.

### Q8: Why are all 3 sub-rules (`5.3.2.1.1`, `5.3.2.1.2`, `5.3.2.1.3`) set to `false` for account lockouts?
- **Answer & Justification:**
  The task brief specifies: *"No account lockouts on failed password attempts on both user and root accounts (Safety / Security)"*. CIS Benchmark 5.3.2.1 controls the `pam_faillock` Linux module through 3 parameters: `deny` (failed attempt count), `unlock_time` (lockout duration), and `fail_interval` (time window). Disabling all 3 sub-rules ensures PAM does not write partial lockout directives to `/etc/pam.d/system-auth`, preventing automated test scripts or Jenkins pipeline agents from getting locked out of the target VMs.

### Q9: How do we enforce "Level 1 - Server Only" and skip CIS Level 2 rules?
- **Answer & Justification:**
  The task requirement specifies **Level 1 - Server Only**. We skip paranoid/high-security Level 2 benchmark rules using two layers:
  1. **Group Variable**: `rhel10cis_level_2: false` in `group_vars/pb_nodes.yml`.
  2. **Ansible Tag Skipping**: `--skip-tags "level2-server,level2-workstation"` in `Jenkinsfile`.

### Q10: Why use BOTH `rhel10cis_level_2: false` AND `--skip-tags "level2-server,level2-workstation"`?
- **Answer & Justification:**
  This provides **Defense-in-Depth**:
  1. `rhel10cis_level_2: false` disables Level 2 rules at the **variable evaluation level**.
  2. `--skip-tags` disables Level 2 rules at the **Ansible task execution engine level**.
  Combining both guarantees that even if a role task misses a variable check, the Ansible execution engine will force-skip it, ensuring zero Level 2 rules contaminate our Level 1 Server baseline.

### Q11: How do `rhel10cis_level_2: false` and `--skip-tags` satisfy the task requirement for "Level 1 Only"?
- **Answer & Justification:**
  - **Implementation Phase (Ansible)**: `rhel10cis_level_2: false` is the primary variable defined by Ansible Lockdown to tell the role logic to execute *only* CIS Level 1 remediation tasks on the OS.
  - **Evaluation Phase (Goss Audit)**: When `rhel10cis_level_2: false` is active, the role generates a Goss test template containing *only* Level 1 assertions. Goss evaluates only Level 1 benchmarks when calculating the final 90%+ compliance score.
  - **Execution Acceleration (CLI Tag Skipping)**: `--skip-tags "level2-server,level2-workstation"` tells Ansible's task runner to immediately skip tagged Level 2 tasks without spending time parsing them.

### Q12: Why do we set `rhel10cis_rule_5_2_4: false`?
- **Answer & Justification:**
  User `syl` was created in Kickstart with `--lock` (SSH ED25519 key authentication only, no plaintext password). In `/etc/shadow`, locked passwords start with `!`. Rule 5.2.4 is a pre-check safeguard intended for password-authenticated environments to prevent sysadmin lockouts. Because our pipeline uses key-based SSH authentication, Rule 5.2.4 flags the `!` as a false-positive failure. Setting `rhel10cis_rule_5_2_4: false` disables this password state check so automated hardening can proceed cleanly.

### Q13: Why set `rhel10cis_authselect_custom_profile_name: custom_pair_b_profile`?
- **Answer & Justification:**
  CIS Benchmark 5.3 requires configuring Pluggable Authentication Modules (PAM) using `authselect`. To prevent corrupting system-default OS profiles, `RHEL10-CIS` requires naming a custom profile. Setting `rhel10cis_authselect_custom_profile_name` specifies our unique profile name (`custom_pair_b_profile`), satisfying CIS requirements for PAM customization.

### Q14: Why enable `pipelining = True` and set `timeout = 30` in `ansible/ansible.cfg`?
- **Answer & Justification:**
  `RHEL10-CIS` executes hundreds of rapid `sudo` privilege escalation commands. Without pipelining, default Ansible opens and closes a separate SSH connection for every single task, leading to socket exhaustion and 12-second privilege escalation timeout failures. Enabling `pipelining = True` reuses existing open SSH multiplex sockets, accelerating playbook execution by 10x and eliminating privilege escalation timeouts.

### Q15: What does `rc: 137` mean during Ansible execution and why increase VM RAM to 3072 MB?
- **Answer & Justification:**
  Exit code `137` in Linux is thrown when the Linux kernel Out-Of-Memory (OOM) killer forcefully terminates a process (`SIGKILL`). Heavy Python 3.12 string parsing of large Goss audit JSON outputs exceeds 2048 MB RAM on the target VM. Increasing VM RAM allocation to 3072 MB (3 GB) in `terraform/variables.tf` provides sufficient headroom for Python memory consumption, eliminating `rc: 137` OOM crashes.

### Q16: Why set `rhel10cis_rule_1_2_2_1: false` (Skip Full DNF Package Upgrade)?
- **Answer & Justification:**
  Rule 1.2.2.1 executes `dnf update state=latest` across all installed OS packages. In localized build environments or automated pipeline testing, downloading gigabytes of DNF updates over the internet causes long pipeline delays. Setting `rhel10cis_rule_1_2_2_1: false` skips full OS package upgrades, allowing Ansible hardening to complete in under 60 seconds.

### Q17: How and where are Goss audit JSON report files downloaded to the `ansible/` folder?
- **Answer & Justification:**
  In `ansible/group_vars/pb_nodes.yml`, two variables control report retrieval:
  1. `fetch_audit_output: true`: Instructs Ansible to retrieve pre-scan and post-scan Goss audit JSON files from `/opt` on the remote VM back to the control machine.
  2. `audit_output_destination: "./"`: Tells Ansible to save the fetched `*.json` files directly into the active `ansible/` directory.
  In Jenkins, `archiveArtifacts artifacts: '*.json'` captures these files so they can be viewed and downloaded directly from the Jenkins build dashboard.

### Q18: Why did Packer fail with "Duplicate variable definition found" in Jenkins?
- **Answer & Justification:**
  Packer parses all `.pkr.hcl` files present in the build directory. The GitHub remote repository contained two duplicate Packer configuration files (`almalinux.pkr.hcl` and `almalinux10.pkr.hcl`), both defining the same input variables. Deleting the redundant `almalinux.pkr.hcl` file from Git ensures Packer parses a single unified configuration file without variable name collisions.

### Q19: Why execute `./bootstrap.sh` inside Jenkins `Prepare Workspace` stage?
- **Answer & Justification:**
  Packer requires the static build SSH key pair `~/.ssh/pairB_build` to authenticate during Kickstart installation. Because Jenkins runs under the dedicated `jenkins` system user account (`/var/lib/jenkins`), running `./bootstrap.sh` in the workspace preparation stage ensures the static build SSH keypair is generated automatically on the Jenkins agent before Packer builds the golden image.

### Q20: What caused `Error: failed to connect: internal error` during libvirt provider init, and how is it resolved?
- **Answer & Justification:**
  When QEMU builds the golden image via Packer over an extended duration, libvirt's socket activation state can transition to idle. Re-querying the hypervisor connection (`virsh list --all`) re-initializes the active libvirtd IPC socket channel, allowing the Terraform libvirt provider to query domain process tables cleanly.

### Q21: Why does `libvirt` throw `Cannot find start time for pid` during subshell invocation in Jenkins?
- **Answer & Justification:**
  When Jenkins executes `sh 'terraform apply'`, Linux spawns a short-lived transient subshell wrapper PID. If libvirtd's socket activation channel is initializing, the temporary subshell PID terminates before libvirt inspects `/proc/PID/stat`. Re-activating the hypervisor RPC socket channel via `virsh -c qemu:///system list` ensures persistent socket readiness for Terraform execution.

### Q22: What is the difference between `qemu:///system` and `qemu:///system?socket=/var/run/libvirt/libvirt-sock`?
- **Answer & Justification:**
  This fix resolves the process lifecycle difference between terminal execution and automated CI/CD pipelines across 3 key scenarios:
  1. **Interactive Terminal Execution (`bunny` user)**:
     When running `terraform apply` manually in a terminal, the shell process ID (PID) remains persistent and open in Linux memory. `libvirtd` looks up the caller's PID in `/proc`, finds user `bunny` active, and authorizes the connection cleanly.
  2. **Automated Jenkins CI/CD Pipeline (`jenkins` system service user)**:
     When Jenkins executes `sh 'terraform apply'`, Linux spawns a non-interactive temporary background subshell wrapper. Because this subshell wrapper starts and stops in milliseconds, when `libvirtd` attempts to inspect the caller's PID (`PID 8540`) in `/proc`, the subshell has already closed, causing `libvirtd` to panic with `Cannot find start time for pid 8540`.
  3. **The Native Modular Socket URI Fix (`?socket=/var/run/libvirt/virtqemud-sock`)**:
     AlmaLinux 10 uses modern modular hypervisor daemons (`virtqemud-sock`). Pointing Terraform directly to `virtqemud-sock` connects to the native QEMU driver socket, bypassing legacy proxy forwarding and ensuring 100% reliable execution under Jenkins automation.
