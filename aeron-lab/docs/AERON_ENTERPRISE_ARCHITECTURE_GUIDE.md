# Aeron's 3-VM Enterprise Hybrid Stack: Master Production Guide & Architecture Summary

A comprehensive architectural reference, operational runbook, and session summary for **Aeron's 3-VM Enterprise Full-Stack Cluster**.

---

## 🏗️ 1. Final System Architecture Map

```text
                                  CLIENT BROWSER / HOST LAPTOP
                                 (HTTP Port 80 / HTTPS Port 443)
                                                │
                     ┌──────────────────────────┴──────────────────────────┐
                     │                                                     │
                     ▼                                                     ▼
      [ VM 1: web-node-1 ]                                  [ VM 2: web-node-2 ]
      IP: 192.168.122.48                                    IP: 192.168.122.205
      ├── FirewallD (Port 80 Open)                          ├── FirewallD (Port 80 Open)
      ├── SELinux (httpd_can_network_connect)               ├── SELinux (httpd_can_network_connect)
      ├── Native Nginx Reverse Proxy (Port 80)              ├── Native Nginx Reverse Proxy (Port 80)
      │   (proxy_pass -> 127.0.0.1:8000)                    │   (proxy_pass -> 127.0.0.1:8000)
      └── Podman Container Box                              └── Podman Container Box
          (bunnywkwk/aeron-app:v2.0)                            (bunnywkwk/aeron-app:v2.0)
          (Non-Root UID 10001, Port 8000)                       (Non-Root UID 10001, Port 8000)
                     │                                                     │
                     └──────────────────────────┬──────────────────────────┘
                                                │
                                                ▼ (TCP/IP Port 5432)
                                       [ VM 3: db-node-1 ]
                                       IP: 192.168.122.103
                                       ├── FirewallD (Port 5432/tcp Open)
                                       └── PostgreSQL 16 Container Box
                                           (aeron_postgres_db:5432)
                                           Persistent Volume: /var/lib/postgres/data
```

---

## 📂 2. Project File Structure (`aeron-lab/`)

```text
aeron-lab/
├── AERON_ENTERPRISE_ARCHITECTURE_GUIDE.md   <-- Master Production Guide
├── app/
│   ├── app.py                                <-- Flask CRUD API (PostgreSQL + SQLite fallback)
│   ├── requirements.txt                      <-- flask==3.0.2, psycopg2-binary==2.9.9
│   ├── Dockerfile                            <-- Non-root UID 10001 container build script
│   └── templates/
│       └── index.html                        <-- Dark-mode Bootstrap 5 Web Interface
├── packer/
│   └── output/
│       └── alma10-golden.qcow2               <-- Base AlmaLinux 10 QCOW2 image
├── terraform/
│   ├── main.tf                               <-- Provisions 3 Libvirt VMs & outputs inventory
│   ├── variables.tf                          <-- Dedicated aeron_pool storage pool config
│   └── .ssh/aeron_deploy                     <-- Private ED25519 deploy key
└── ansible/
    ├── inventory/hosts.yml                   <-- Generated YAML inventory (webservers & dbservers)
    ├── playbook.yml                          <-- Multi-play master playbook
    └── roles/
        ├── app_container/                    <-- Installs Podman & deploys Python app box
        ├── webserver/                        <-- Installs Nginx, deploys proxy.j2, FirewallD & SELinux
        └── db_container/                     <-- Installs Podman, FirewallD 5432, & Postgres 16 box
```

---

## 🛠️ 3. Complete Step-by-Step Build Runbook

### Step 1: Full-Stack App Build & Docker Hub Push
1. Built Flask CRUD application with Bootstrap 5 web UI (`templates/index.html`).
2. Built and pushed container images to Docker Hub:
   ```bash
   cd ~/devops-pair-b/aeron-lab/app
   docker build -t bunnywkwk/aeron-app:v2.0 .
   docker push bunnywkwk/aeron-app:v2.0
   ```

### Step 2: Infrastructure Provisioning (Terraform)
1. Provisioned 3 AlmaLinux 10 VMs (`web-node-1`, `web-node-2`, `db-node-1`) inside `aeron-lab/terraform/`:
   ```bash
   cd ~/devops-pair-b/aeron-lab/terraform
   terraform init
   terraform apply
   ```

### Step 3: Automated Ansible Playbook Deployment
1. Deployed database tier and webserver tier across all 3 VMs:
   ```bash
   cd ~/devops-pair-b/aeron-lab/ansible
   ansible-playbook -i inventory/hosts.yml playbook.yml
   ```

---

## 🛡️ 4. Security & Architecture Deep-Dive Summary

1. **Non-Root Container Security (`UID 10001`)**:
   - App containers run under unprivileged user `appuser (10001)`. If an attacker breaches Flask, they are trapped inside the container with 0 root privileges.
2. **Daemonless Container Engine (Podman)**:
   - Replaced Docker daemon with Red Hat's Podman, eliminating background root service vulnerability vectors.
3. **SELinux Proxy Authorization (`httpd_can_network_connect`)**:
   - Configured SELinux booleans allowing Nginx reverse proxy sockets to forward traffic to internal containers cleanly.
4. **FirewallD Strict Network Locking**:
   - Web nodes open ONLY Port 80 HTTP; Database node opens ONLY Port 5432 TCP for internal cluster traffic.
5. **Centralized Data Persistence**:
   - Database records are stored on `db-node-1`'s persistent host disk (`/var/lib/postgres/data`). Both web nodes share 1 single centralized source of truth.
6. **Full-Stack Data Lifecycle**:
   - **`POST /add`** $\rightarrow$ HTTP POST payload $\rightarrow$ `request.form` in Flask $\rightarrow$ `INSERT INTO items` in PostgreSQL!

---

## 🏆 5. Summary of Accomplishments
* ✅ Built an isolated 3-VM Enterprise Hybrid Stack from scratch in `aeron-lab/`.
* ✅ Containerized a custom Python Flask CRUD application with Bootstrap 5 frontend.
* ✅ Pushed OCI container images to Docker Hub (`bunnywkwk/aeron-app:v2.0`).
* ✅ Provisioned 3 virtual machines using Terraform & Libvirt/KVM.
* ✅ Configured 3 modular Ansible roles (`app_container`, `webserver`, `db_container`).
* ✅ Inspected PostgreSQL database records via `podman exec` and Chrome DevTools Network POST payloads!
