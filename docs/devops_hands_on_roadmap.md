# Enterprise Hardened DevOps Pipeline & Container Delivery Roadmap

An enterprise-grade, security-hardened hands-on project designed for 1-click CI/CD automation on a local VM host.

---

## 🛡️ Enterprise Security & Architecture Matrix

```text
[ Developer Push ] ──> [ Jenkins CI/CD ] ──> [ Container Build ] ──> [ Ansible Hardened Deploy ] ──> [ Live Secure Stack ]
                       - Vault Secret        - Non-Root User (10001)   - CIS Level 1 OS Hardening    - Hardened Nginx (80/443)
                       - Pipeline Audit      - Healthcheck Probe       - FirewallD Port Locking       - App Container (8000)
```

| Security Layer | Technology | Enterprise Implementation |
| :--- | :--- | :--- |
| **Container Hardening** | **Docker Security** | Non-Root execution (`user: 10001:10001`), read-only root filesystems, healthchecks |
| **Network Hardening** | **Nginx & FirewallD** | Security headers (`X-Frame-Options`), SSL TLSv1.3, rate-limiting, ports 80/443 locking |
| **Host OS Hardening** | **Ansible & CIS** | RHEL 10 CIS Benchmark (Level 1), disabled unneeded services, PAM password rules |
| **Secret Protection** | **Ansible Vault** | AES256 encrypted credentials (`group_vars/vault.yml`) with zero plaintext secrets |
| **Automated Delivery** | **Jenkins CI/CD** | 1-click pipeline automating Packer image build, Terraform apply, and Ansible deployment |

---

## 🗺️ Hands-On Build Plan

### 📍 Step 1: Secure App & Container Building
1. Build Python web application (`app.py`) with DB connection check & health endpoint `/health`.
2. Write a hardened multi-stage `Dockerfile`:
   - Uses non-root user `appuser (UID 10001)`.
   - Defines container `HEALTHCHECK --interval=5s CMD curl -f http://localhost:8000/health || exit 1`.

### 📍 Step 2: Infrastructure & OS Hardening (Packer & Terraform)
1. Build `alma10-golden.qcow2` OS image with Packer.
2. Terraform provisions 1 Libvirt VM (`secure-web-1`) with 2048MB RAM & dynamic SSH deploy keys.

### 📍 Step 3: Ansible Host Hardening & Container Delivery
1. **Host Hardening**: Apply `RHEL10-CIS` benchmark role & configure `firewalld` (locks all ports except 80, 443, 22).
2. **Nginx Security**: Deploy Nginx reverse proxy with security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `rate_limit` zone).
3. **Container Delivery**: Use `community.docker.docker_container` to deploy the app container with non-root security & volume mounts.
4. **Health Verification**: Ansible verifies container health status before reloading Nginx!

### 📍 Step 4: Full Jenkins Automation
1. Create `Jenkinsfile` automating all steps with credential secret injection.
